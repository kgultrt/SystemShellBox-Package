// 测试，完全重写为cpp，不稳定，bug多
// Test, completely rewritten to CPP, unstable, buggy
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <filesystem>
#include <chrono>
#include <ctime>
#include <iomanip>
#include <sstream>
#include <algorithm>
#include <memory>
#include <cstdlib>
#include <functional>
#include <regex>
#include <numeric>
#include <cmath>
#include <cstdint>
#include <stdexcept>
#include <system_error>
#include <curl/curl.h>
#include <nlohmann/json.hpp>
#include <archive.h>
#include <archive_entry.h>
#include <openssl/evp.h>

namespace fs = std::filesystem;
namespace chrono = std::chrono;
using json = nlohmann::json;

// ========================
// Configuration
// ========================
struct Config {
    std::string ROOT = "./";
    std::string DB_PATH = "./var/lib/spm/db";
    std::string SNAPSHOTS_DIR = "./var/lib/spm/snaps";
    std::string PKG_CACHE = "./var/cache/spm/pkg";
    std::string REPO_DIR = "./";
    std::string CONFIG_DIR = "./etc/spm";
    std::string REPO_CONFIG = "./etc/spm/repos.json";
    int MAX_SNAPSHOTS = 10;
    std::string BUILD_DIR = "./spm_build";
    std::vector<std::string> PROTECTED_PATHS = {"./dev", "./proc", "./sys", "./run"};
    bool PACMAN_STYLE_PROGRESS = true;
};

Config config;

// ========================
// Utility Functions
// ========================
class SPMException : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

std::string colored(const std::string& text, const std::string& color) {
    // Simplified color output - in real implementation would use ANSI codes
    return text;
}

std::string format_size(double size_kb) {
    if (size_kb < 1024) {
        return std::to_string(size_kb) + " KB";
    } else if (size_kb < 1024 * 1024) {
        return std::to_string(size_kb / 1024) + " MB";
    } else {
        return std::to_string(size_kb / (1024 * 1024)) + " GB";
    }
}

std::string get_current_timestamp() {
    auto now = chrono::system_clock::now();
    auto in_time_t = chrono::system_clock::to_time_t(now);
    std::tm tm_buf;
    localtime_r(&in_time_t, &tm_buf);
    std::stringstream ss;
    ss << std::put_time(&tm_buf, "%Y%m%d%H%M%S");
    return ss.str();
}

std::string sha256_file(const fs::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        throw SPMException("Cannot open file for hashing: " + path.string());
    }

    EVP_MD_CTX* mdctx = EVP_MD_CTX_new();
    if (mdctx == nullptr) {
        throw SPMException("Failed to create EVP context");
    }

    if (EVP_DigestInit_ex(mdctx, EVP_sha256(), nullptr) != 1) {
        EVP_MD_CTX_free(mdctx);
        throw SPMException("Failed to initialize SHA256 digest");
    }

    char buffer[4096];
    while (file.read(buffer, sizeof(buffer))) {
        if (EVP_DigestUpdate(mdctx, buffer, file.gcount()) != 1) {
            EVP_MD_CTX_free(mdctx);
            throw SPMException("Failed to update SHA256 digest");
        }
    }
    if (EVP_DigestUpdate(mdctx, buffer, file.gcount()) != 1) {
        EVP_MD_CTX_free(mdctx);
        throw SPMException("Failed to update SHA256 digest");
    }

    unsigned char hash[EVP_MAX_MD_SIZE];
    unsigned int length;
    if (EVP_DigestFinal_ex(mdctx, hash, &length) != 1) {
        EVP_MD_CTX_free(mdctx);
        throw SPMException("Failed to finalize SHA256 digest");
    }

    EVP_MD_CTX_free(mdctx);

    std::stringstream ss;
    for (unsigned int i = 0; i < length; i++) {
        ss << std::hex << std::setw(2) << std::setfill('0') << (int)hash[i];
    }

    return ss.str();
}

// ========================
// Package Class
// ========================
struct Package {
    std::string name;
    std::string version;
    int version_code = 0;
    std::vector<std::string> files;
    std::map<std::string, std::string> deps;
    std::vector<std::string> conflicts;
    double size = 0;

    json to_json() const {
        return {
            {"name", name},
            {"version", version},
            {"versionCode", version_code},
            {"files", files},
            {"dependencies", deps},
            {"conflicts", conflicts},
            {"size", size}
        };
    }

    static Package from_json(const json& data) {
        Package pkg;
        pkg.name = data["name"];
        pkg.version = data["version"];
        pkg.version_code = data.value("versionCode", 0);
        pkg.files = data.value("files", std::vector<std::string>());
        pkg.deps = data.value("dependencies", std::map<std::string, std::string>());
        pkg.conflicts = data.value("conflicts", std::vector<std::string>());
        pkg.size = data.value("size", 0.0);
        return pkg;
    }
};

// ========================
// Database Class
// ========================
class Database {
    fs::path db_path;
public:
    Database(const std::string& path) : db_path(path) {
        fs::create_directories(db_path);
    }

    fs::path get_package_path(const std::string& pkg_name) const {
        return db_path / (pkg_name + ".json");
    }

    void add(const Package& package) {
        std::ofstream f(get_package_path(package.name));
        f << package.to_json().dump(2);
    }

    void remove(const std::string& pkg_name) {
        fs::path path = get_package_path(pkg_name);
        if (fs::exists(path)) {
            fs::remove(path);
        }
    }

    std::unique_ptr<Package> get(const std::string& pkg_name) const {
        fs::path path = get_package_path(pkg_name);
        if (!fs::exists(path)) {
            return nullptr;
        }

        std::ifstream f(path);
        json data;
        f >> data;
        return std::make_unique<Package>(Package::from_json(data));
    }

    std::vector<std::string> list_packages() const {
        std::vector<std::string> packages;
        for (const auto& entry : fs::directory_iterator(db_path)) {
            if (entry.path().extension() == ".json") {
                packages.push_back(entry.path().stem().string());
            }
        }
        return packages;
    }

    std::vector<std::string> get_reverse_deps(const std::string& pkg_name) const {
        std::vector<std::string> reverse_deps;
        for (const auto& pkg : list_packages()) {
            auto pkg_data = get(pkg);
            if (pkg_data && pkg_data->deps.count(pkg_name)) {
                reverse_deps.push_back(pkg);
            }
        }
        return reverse_deps;
    }
};

// ========================
// HTTP Downloader
// ========================
size_t write_data(void* ptr, size_t size, size_t nmemb, std::string* data) {
    data->append((char*)ptr, size * nmemb);
    return size * nmemb;
}

size_t write_file(void* ptr, size_t size, size_t nmemb, FILE* stream) {
    return fwrite(ptr, size, nmemb, stream);
}

std::string http_get(const std::string& url) {
    CURL* curl = curl_easy_init();
    if (!curl) {
        throw SPMException("Failed to initialize CURL");
    }

    std::string response;
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "spm/1.0");

    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
        curl_easy_cleanup(curl);
        throw SPMException("HTTP request failed: " + std::string(curl_easy_strerror(res)));
    }

    curl_easy_cleanup(curl);
    return response;
}

void download_file(const std::string& url, const fs::path& dest_path) {
    CURL* curl = curl_easy_init();
    if (!curl) {
        throw SPMException("Failed to initialize CURL");
    }

    FILE* fp = fopen(dest_path.c_str(), "wb");
    if (!fp) {
        curl_easy_cleanup(curl);
        throw SPMException("Failed to open file for writing: " + dest_path.string());
    }

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_file);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "spm/1.0");
    curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0L);

    CURLcode res = curl_easy_perform(curl);
    fclose(fp);

    if (res != CURLE_OK) {
        fs::remove(dest_path);
        curl_easy_cleanup(curl);
        throw SPMException("Download failed: " + std::string(curl_easy_strerror(res)));
    }

    curl_easy_cleanup(curl);
}

// ========================
// Repo Manager
// ========================
class RepoManager {
    std::map<std::string, std::string> repos;
    std::map<std::string, std::map<std::string, json>> index_cache;
    fs::path config_path;

    void load_repos() {
        if (!fs::exists(config_path)) {
            std::cerr << colored("[WARN] Repo config not found: " + config_path.string(), "red") << std::endl;
            return;
        }

        std::ifstream f(config_path);
        json data;
        f >> data;
        repos = data.get<std::map<std::string, std::string>>();
    }

    void load_indexes() {
        for (const auto& [name, base_url] : repos) {
            try {
                std::string index_url = base_url + "/index.json";
                std::cout << "Fetching index from " << index_url << "..." << std::endl;
                std::string response = http_get(index_url);
                json index_data = json::parse(response);
                index_cache[name] = index_data;
            } catch (const std::exception& e) {
                std::cerr << colored("[WARN] Failed to load index from " + name + ": " + e.what(), "red") << std::endl;
            }
        }
    }

public:
    bool version_satisfies(int version_code, const std::string& requirement) {
        if (requirement == "*" || requirement.empty()) {
            return true;
        }

        std::regex pattern(R"((>=|<=|>|<|=)?\s*(\d+))");
        std::smatch match;
        if (!std::regex_match(requirement, match, pattern)) {
            return false;
        }

        std::string op = match[1];
        int target = std::stoi(match[2]);

        if (op == ">=") {
            return version_code >= target;
        } else if (op == "<=") {
            return version_code <= target;
        } else if (op == ">") {
            return version_code > target;
        } else if (op == "<") {
            return version_code < target;
        } else if (op == "=" || op.empty()) {
            return version_code == target;
        }
        return false;
    }

    RepoManager(const std::string& path = "") : config_path(path.empty() ? config.REPO_CONFIG : path) {
        load_repos();
        load_indexes();
    }

    void fetch_indexes() {
        for (const auto& [name, base_url] : repos) {
            std::string index_url = base_url + "/index.json";
            std::cout << colored("Fetching index from " + index_url, "cyan") << std::endl;
            try {
                std::string response = http_get(index_url);
                json index = json::parse(response);
                index_cache[name] = index;
            } catch (const std::exception& e) {
                std::cerr << colored("Failed to fetch index from " + name + ": " + e.what(), "red") << std::endl;
            }
        }
    }

    std::vector<std::pair<std::string, json>> find_package(const std::string& pkg_name, const std::string& version_req = "*") {
        std::vector<std::pair<std::string, json>> candidates;
        for (const auto& [repo_name, index] : index_cache) {
            if (index.count(pkg_name)) {
                const auto& meta = index.at(pkg_name);
                if (version_satisfies(meta.value("versionCode", 0), version_req)) {
                    candidates.emplace_back(repo_name, meta);
                }
            }
        }

        // Sort by versionCode descending
        std::sort(candidates.begin(), candidates.end(), [](const auto& a, const auto& b) {
            return a.second.value("versionCode", 0) > b.second.value("versionCode", 0);
        });

        return candidates;
    }
};

// ========================
// Snapshot Manager
// ========================
class SnapshotManager {
    fs::path snap_dir;
    int max_snaps;

    void clean_system_files(const std::vector<std::string>& packages) {
        Database db(config.DB_PATH);
        for (const auto& pkg_name : packages) {
            auto pkg = db.get(pkg_name);
            if (!pkg) continue;

            for (const auto& file_path : pkg->files) {
                fs::path abs_path = fs::path(config.ROOT) / file_path.substr(1);
                if (std::any_of(config.PROTECTED_PATHS.begin(), config.PROTECTED_PATHS.end(),
                    [&abs_path](const std::string& p) {
                        return abs_path.string().find(p) == 0;
                    })) {
                    continue;
                }

                if (fs::exists(abs_path)) {
                    if (fs::is_directory(abs_path)) {
                        fs::remove_all(abs_path);
                    } else {
                        fs::remove(abs_path);
                    }
                }
            }
        }
    }

    void restore_files(const fs::path& state_dir) {
        for (const auto& entry : fs::recursive_directory_iterator(state_dir)) {
            if (!entry.is_regular_file()) continue;

            fs::path rel_path = fs::relative(entry.path(), state_dir);
            fs::path target_path = fs::path(config.ROOT) / rel_path;

            fs::create_directories(target_path.parent_path());
            fs::copy_file(entry.path(), target_path, fs::copy_options::overwrite_existing);
        }
    }

public:
    SnapshotManager(const std::string& dir, int max) : snap_dir(dir), max_snaps(max) {
        fs::create_directories(snap_dir);
    }

    std::string create_snapshot(const std::string& operation, const std::vector<std::string>& packages) {
        std::string timestamp = get_current_timestamp();
        std::string snap_name = timestamp + "-" + operation;
        fs::path snap_path = snap_dir / snap_name;

        fs::path state_dir = snap_path / "state";
        fs::create_directories(state_dir);

        std::ofstream packages_file(snap_path / "packages.json");
        packages_file << json(packages).dump();

        fs::path db_snap = snap_path / "db";
        if (fs::exists(config.DB_PATH)) {
            fs::create_directories(db_snap);
            for (const auto& entry : fs::directory_iterator(config.DB_PATH)) {
                fs::copy(entry.path(), db_snap / entry.path().filename());
            }
        }

        return snap_name;
    }

    void restore_snapshot(const std::string& snap_name) {
        fs::path snap_path = snap_dir / snap_name;
        if (!fs::exists(snap_path)) {
            throw SPMException("Snapshot " + snap_name + " not found");
        }

        fs::path db_snap = snap_path / "db";
        if (fs::exists(db_snap)) {
            fs::remove_all(config.DB_PATH);
            fs::create_directories(config.DB_PATH);
            for (const auto& entry : fs::directory_iterator(db_snap)) {
                fs::copy(entry.path(), config.DB_PATH + "/" + entry.path().filename().string());
            }
        }

        std::ifstream packages_file(snap_path / "packages.json");
        json packages_json;
        packages_file >> packages_json;
        auto packages = packages_json.get<std::vector<std::string>>();

        clean_system_files(packages);

        fs::path state_dir = snap_path / "state";
        if (fs::exists(state_dir)) {
            restore_files(state_dir);
        }

        fs::remove_all(snap_path);
    }

    void prune_old_snapshots() {
        std::vector<fs::path> snaps;
        for (const auto& entry : fs::directory_iterator(snap_dir)) {
            snaps.push_back(entry.path());
        }

        std::sort(snaps.begin(), snaps.end());
        if (snaps.size() > max_snaps) {
            for (size_t i = 0; i < snaps.size() - max_snaps; i++) {
                fs::remove_all(snaps[i]);
            }
        }
    }
};

// ========================
// Dependency Resolver
// ========================
class DependencyResolver {
    Database& db;
    fs::path repo_dir;
    std::set<std::string> visited;
    RepoManager repo_manager;

public:
    DependencyResolver(Database& db, const std::string& repo_dir) 
        : db(db), repo_dir(repo_dir), repo_manager() {}

    bool version_satisfies(int version_code, const std::string& requirement) {
        if (requirement == "*" || requirement.empty()) {
            return true;
        }

        std::regex pattern(R"((>=|<=|>|<|=)?\s*(\d+))");
        std::smatch match;
        if (!std::regex_match(requirement, match, pattern)) {
            return false;
        }

        std::string op = match[1];
        int target = std::stoi(match[2]);

        if (op == ">=") {
            return version_code >= target;
        } else if (op == "<=") {
            return version_code <= target;
        } else if (op == ">") {
            return version_code > target;
        } else if (op == "<") {
            return version_code < target;
        } else if (op == "=" || op.empty()) {
            return version_code == target;
        }
        return false;
    }
    
    std::vector<Package> resolve(const std::string& pkg_name, const std::string& version_req = "*") {
        std::string key = pkg_name + ":" + version_req;
        if (visited.count(key)) {
            return {};
        }
        visited.insert(key);

        auto installed = db.get(pkg_name);
        if (installed && repo_manager.version_satisfies(installed->version_code, version_req)) {
            return {};
        }

        // Local loose matching
        std::vector<fs::path> candidate_files;
        for (const auto& entry : fs::directory_iterator(repo_dir)) {
            if (entry.path().extension() == ".spm" && 
                entry.path().filename().string().find(pkg_name) != std::string::npos) {
                candidate_files.push_back(entry.path());
            }
        }

        if (candidate_files.empty()) {
            // Not found locally, try remote
            auto results = repo_manager.find_package(pkg_name, version_req);
            if (!results.empty()) {
                const auto& [repo, meta] = results[0];
                fs::path pkg_file = repo_dir / meta["filename"].get<std::string>();
                if (!fs::exists(pkg_file)) {
                    download_file(repo_manager.find_package(pkg_name, version_req)[0].second["url"], pkg_file);
                }
                candidate_files.push_back(pkg_file);
            } else {
                throw SPMException("Package " + pkg_name + " not found in local or remote sources");
            }
        }

        // Multiple candidates - let user choose
        fs::path pkg_file;
        if (candidate_files.size() > 1) {
            std::cout << colored("\nMultiple candidates found for '" + pkg_name + "':", "yellow") << std::endl;
            for (size_t i = 0; i < candidate_files.size(); i++) {
                std::cout << "  [" << i << "] " << candidate_files[i].filename().string() << std::endl;
            }
            std::cout << "Select package index [0-" << candidate_files.size() - 1 << "]: ";
            std::string choice;
            std::getline(std::cin, choice);
            try {
                size_t index = std::stoul(choice);
                if (index >= candidate_files.size()) {
                    throw SPMException("Invalid selection.");
                }
                pkg_file = candidate_files[index];
            } catch (...) {
                throw SPMException("Invalid selection.");
            }
        } else {
            pkg_file = candidate_files[0];
        }

        // Read package metadata
        Package pkg;
        try {
            struct archive* a = archive_read_new();
            archive_read_support_format_tar(a);
            archive_read_support_filter_gzip(a);

            if (archive_read_open_filename(a, pkg_file.c_str(), 10240) != ARCHIVE_OK) {
                archive_read_free(a);
                throw SPMException("Failed to open package file: " + pkg_file.string());
            }

            struct archive_entry* entry;
            while (archive_read_next_header(a, &entry) == ARCHIVE_OK) {
                std::string entry_name = archive_entry_pathname(entry);
                if (entry_name == "package.json") {
                    size_t size = archive_entry_size(entry);
                    std::vector<char> buf(size);
                    archive_read_data(a, buf.data(), size);
                    json meta_data = json::parse(buf.begin(), buf.end());
                    pkg = Package::from_json(meta_data);
                    break;
                }
            }
            archive_read_free(a);
        } catch (const std::exception& e) {
            throw SPMException("Failed to read package metadata: " + std::string(e.what()));
        }

        if (!repo_manager.version_satisfies(pkg.version_code, version_req)) {
            throw SPMException("Required version_code " + version_req + " not found for " + 
                             pkg_name + " (found " + std::to_string(pkg.version_code) + ")");
        }

        std::vector<Package> deps_to_install = {pkg};
        for (const auto& [dep, dep_version] : pkg.deps) {
            auto resolved = resolve(dep, dep_version);
            deps_to_install.insert(deps_to_install.end(), resolved.begin(), resolved.end());
        }

        return deps_to_install;
    }
};

// ========================
// Package Manager
// ========================
class PackageManager {
    Database db;
    SnapshotManager snap_mgr;
    fs::path repo_dir;
    fs::path pkg_cache;
    std::unique_ptr<DependencyResolver> resolver;
    int file_count = 0;
    double total_size = 0;
    chrono::time_point<chrono::system_clock> start_time;

    void check_dependencies(const Package& pkg) {
        for (const auto& [dep, version_req] : pkg.deps) {
            auto installed = db.get(dep);
            if (!installed) {
                throw SPMException("Missing dependency: " + dep + " required by " + pkg.name);
            }

            if (!resolver->version_satisfies(installed->version_code, version_req)) {
                throw SPMException("Dependency version mismatch: " + dep + " requires " + 
                                 version_req + " but found " + installed->version);
            }
        }
    }

    void check_conflicts(const Package& pkg) {
        for (const auto& conflict : pkg.conflicts) {
            if (db.get(conflict)) {
                throw SPMException("Conflicts with installed package: " + conflict);
            }
        }
    }

    std::string check_file_conflict(const fs::path& file_path, const std::string& installing_pkg) {
        if (!fs::exists(file_path)) {
            return "";
        }

        if (fs::is_directory(file_path)) {
            return "";
        }

        for (const auto& pkg_name : db.list_packages()) {
            auto pkg = db.get(pkg_name);
            if (!pkg) continue;

            auto rel_path = fs::relative(file_path, config.ROOT).string();
            if (std::find(pkg->files.begin(), pkg->files.end(), rel_path) != pkg->files.end()) {
                return pkg_name;
            }
        }

        return "system (unmanaged)";
    }

    fs::path verify_package_integrity(const fs::path& pkg_file) {
        fs::path temp_dir = fs::temp_directory_path() / ("spm_pkg_" + get_current_timestamp());
        fs::create_directories(temp_dir);

        try {
            struct archive* a = archive_read_new();
            archive_read_support_format_tar(a);
            archive_read_support_filter_gzip(a);

            if (archive_read_open_filename(a, pkg_file.c_str(), 10240) != ARCHIVE_OK) {
        archive_read_free(a);
        throw SPMException("Failed to open package file: " + pkg_file.string());
    }

    struct archive_entry* entry;
    while (archive_read_next_header(a, &entry) == ARCHIVE_OK) {
        std::string entry_name = archive_entry_pathname(entry);
        fs::path dest_path = temp_dir / entry_name;
        fs::create_directories(dest_path.parent_path());

        if (archive_entry_size(entry) > 0) {
            std::ofstream out(dest_path, std::ios::binary);
            const void* buff;
            size_t size;
            int64_t offset;
            while (archive_read_data_block(a, &buff, &size, &offset) == ARCHIVE_OK) {
                out.write(static_cast<const char*>(buff), size);
            }
        }
    }
    archive_read_free(a);
} catch (const std::exception& e) {
    fs::remove_all(temp_dir);
    throw SPMException("Failed to extract package: " + std::string(e.what()));
}

fs::path sf_file = temp_dir / "META-INF/SPM.SF";
if (!fs::exists(sf_file)) {
    fs::remove_all(temp_dir);
    throw SPMException("Missing integrity metadata: META-INF/SPM.SF");
}

std::ifstream sf(sf_file);
std::string line;
int total = 0;
std::vector<std::string> lines;
while (std::getline(sf, line)) {
    if (!line.empty()) {
        lines.push_back(line);
    }
}
total = lines.size();

for (int i = 0; i < total; i++) {
    const auto& line = lines[i];
    size_t sep = line.find(" SHA256: ");
    if (sep == std::string::npos) {
        fs::remove_all(temp_dir);
        throw SPMException("Invalid hash line: " + line);
    }

    std::string file_rel = line.substr(0, sep);
    std::string expected = line.substr(sep + 9);
    fs::path file_path = temp_dir / file_rel;

    if (!fs::exists(file_path)) {
        fs::remove_all(temp_dir);
        throw SPMException("Missing file during verification: " + file_rel);
    }

    std::string actual = sha256_file(file_path);
    if (actual != expected) {
        fs::remove_all(temp_dir);
        throw SPMException("Hash mismatch: " + file_rel);
    }

    if (config.PACMAN_STYLE_PROGRESS) {
        show_pacman_progress(i + 1, total, file_rel);
    }
}

std::cout << colored("  Integrity OK", "green") << std::endl;
return temp_dir;
    }

    void install_files_from_dir(const Package& pkg, const fs::path& src_dir) {
        int installed_count = 0;
        int skipped_count = 0;

        for (size_t i = 0; i < pkg.files.size(); i++) {
            const auto& rel_path = pkg.files[i];
            fs::path src_path = src_dir / rel_path;
            fs::path dest_path = fs::path(config.ROOT) / rel_path;

            if (fs::is_directory(src_path)) {
                fs::create_directories(dest_path);
                continue;
            }

            std::string conflict = check_file_conflict(dest_path, pkg.name);
            if (!conflict.empty()) {
                skipped_count++;
                continue;
            }

            fs::create_directories(dest_path.parent_path());
            fs::copy_file(src_path, dest_path, fs::copy_options::overwrite_existing);

            installed_count++;
            file_count++;
            total_size += fs::file_size(src_path) / 1024.0;

            if (config.PACMAN_STYLE_PROGRESS) {
                show_pacman_progress(i + 1, pkg.files.size(), rel_path);
            }
        }

        if (skipped_count > 0) {
            std::cout << colored("  Skipped " + std::to_string(skipped_count) + 
                                " files due to conflicts", "yellow") << std::endl;
        }

        std::cout << colored("  Installed " + std::to_string(installed_count) + " files", "green") << std::endl;
    }

    void cleanup_empty_parents(fs::path path) {
        fs::path root_path = fs::path(config.ROOT);
        std::vector<fs::path> protected_paths;
        for (const auto& p : config.PROTECTED_PATHS) {
            protected_paths.push_back(fs::path(p));
        }

        while (path != root_path) {
            bool is_protected = false;
            for (const auto& p : protected_paths) {
                if (path.string().find(p.string()) == 0) {
                    is_protected = true;
                    break;
                }
            }
            if (is_protected) break;

            try {
                fs::remove(path);
            } catch (const fs::filesystem_error&) {
                break;  // Non-empty or no permission
            }
            path = path.parent_path();
        }
    }

    void show_pacman_progress(int current, int total, const std::string& filename) {
        float percent = static_cast<float>(current) / total;
        int bar_length = 20;
        int filled_length = static_cast<int>(std::round(bar_length * percent));

        std::string bar = "[";
        bar += colored(std::string(filled_length, '='), "green");
        bar += ">";
        bar += std::string(bar_length - filled_length - 1, ' ');
        bar += "]";

        std::string display_name = filename;
        if (filename.length() > 30) {
            display_name = "..." + filename.substr(filename.length() - 27);
        }

        std::cout << "\r  " << bar << " " << display_name;
        std::cout.flush();

        if (current == total) {
            std::cout << std::endl;
        }
    }

    void show_install_preview(const std::vector<Package>& pkgs) {
        std::cout << colored("\nPackages to install:", "yellow") << std::endl;
        for (const auto& pkg : pkgs) {
            std::string status = db.get(pkg.name) ? colored("upgrade", "cyan") : colored("new", "green");
            std::cout << "  " << pkg.name << "-" << pkg.version << " (" << status << ")" << std::endl;
        }

        double total_size = 0;
        for (const auto& pkg : pkgs) {
            total_size += pkg.size;
        }
        std::string size_str = format_size(total_size);

        int new_pkgs = std::count_if(pkgs.begin(), pkgs.end(), [this](const Package& p) {
            return !db.get(p.name);
        });
        int upgrade_pkgs = pkgs.size() - new_pkgs;

        std::cout << colored("\nSummary:", "yellow") << std::endl;
        std::cout << "  New packages: " << colored(std::to_string(new_pkgs), "green") << std::endl;
        std::cout << "  Upgrades: " << colored(std::to_string(upgrade_pkgs), "cyan") << std::endl;
        std::cout << "  Total download size: " << colored(size_str, "cyan") << std::endl;
        std::cout << "  Disk space required: " << colored(size_str, "cyan") << std::endl;
    }

    void show_remove_preview(const std::vector<Package>& pkgs) {
        std::cout << colored("\nPackages to remove:", "yellow") << std::endl;
        for (const auto& pkg : pkgs) {
            std::cout << "  " << pkg.name << "-" << pkg.version << std::endl;
        }

        double total_size = 0;
        for (const auto& pkg : pkgs) {
            total_size += pkg.size;
        }
        std::string size_str = format_size(total_size);

        std::set<std::string> affected;
        for (const auto& pkg : pkgs) {
            auto reverse_deps = db.get_reverse_deps(pkg.name);
            affected.insert(reverse_deps.begin(), reverse_deps.end());
        }

        std::cout << colored("\nSummary:", "yellow") << std::endl;
        std::cout << "  Packages to remove: " << colored(std::to_string(pkgs.size()), "red") << std::endl;
        if (!affected.empty()) {
            std::string affected_str;
            for (const auto& p : affected) {
                if (!affected_str.empty()) affected_str += ", ";
                affected_str += p;
            }
            std::cout << "  Affected packages: " << colored(affected_str, "yellow") << std::endl;
        }
        std::cout << "  Disk space freed: " << colored(size_str, "cyan") << std::endl;
    }

public:
    PackageManager() 
        : db(config.DB_PATH), 
          snap_mgr(config.SNAPSHOTS_DIR, config.MAX_SNAPSHOTS),
          repo_dir(config.REPO_DIR),
          pkg_cache(config.PKG_CACHE),
          resolver(std::make_unique<DependencyResolver>(db, config.REPO_DIR)) {
        fs::create_directories(pkg_cache);
    }

    void install(const std::vector<std::string>& pkg_names, bool force = false) {
        std::vector<Package> all_pkgs;
        for (const auto& pkg_name : pkg_names) {
            resolver = std::make_unique<DependencyResolver>(db, config.REPO_DIR);
            auto resolved = resolver->resolve(pkg_name);
            all_pkgs.insert(all_pkgs.end(), resolved.begin(), resolved.end());
        }

        // Remove duplicates
        std::vector<Package> unique_pkgs;
        std::set<std::string> seen;
        for (const auto& pkg : all_pkgs) {
            if (!seen.count(pkg.name)) {
                unique_pkgs.push_back(pkg);
                seen.insert(pkg.name);
            }
        }

        if (!force) {
            for (const auto& pkg : unique_pkgs) {
                check_conflicts(pkg);
            }
        }

        show_install_preview(unique_pkgs);

        if (!force) {
            std::cout << "\nDo you want to continue? [Y/n] ";
            std::string resp;
            std::getline(std::cin, resp);
            if (!resp.empty() && resp != "y" && resp != "yes") {
                std::cout << "Operation cancelled." << std::endl;
                return;
            }
        }

        std::string snap_name = snap_mgr.create_snapshot(
            "install-" + std::accumulate(pkg_names.begin(), pkg_names.end(), std::string(),
                [](const std::string& a, const std::string& b) {
                    return a + (a.empty() ? "" : ",") + b;
                }),
            std::vector<std::string>(seen.begin(), seen.end())
        );

        try {
            start_time = chrono::system_clock::now();
            for (size_t i = 0; i < unique_pkgs.size(); i++) {
                const auto& pkg = unique_pkgs[i];
                std::cout << colored("\n[" + std::to_string(i + 1) + "/" + 
                                   std::to_string(unique_pkgs.size()) + "] ", "cyan")
                          << colored("Installing " + pkg.name + "-" + pkg.version + "...", "yellow")
                          << std::endl;

                fs::path pkg_file = repo_dir / (pkg.name + "-" + pkg.version + ".spm");
                install_package(pkg, pkg_file);
            }

            double elapsed = chrono::duration<double>(chrono::system_clock::now() - start_time).count();
            double speed = total_size / elapsed / 1024;  // MB/s

            std::cout << colored("\nSuccessfully installed packages:", "green") << std::endl;
            for (const auto& pkg : unique_pkgs) {
                std::cout << "  " << pkg.name << "-" << pkg.version << std::endl;
            }

            std::cout << colored("\nTotal files: " + std::to_string(file_count), "cyan") << std::endl;
            std::cout << colored("Total size: " + format_size(total_size), "cyan") << std::endl;
            std::cout << colored("Time: " + std::to_string(elapsed) + "s", "cyan") << std::endl;
            std::cout << colored("Speed: " + std::to_string(speed) + " MB/s", "cyan") << std::endl;

        } catch (const std::exception& e) {
            std::cerr << colored("\nInstallation failed: " + std::string(e.what()) + ", rolling back...", "red") << std::endl;
            snap_mgr.restore_snapshot(snap_name);
            throw SPMException("Installation rolled back due to error");
        }

        snap_mgr.prune_old_snapshots();
        file_count = 0;
        total_size = 0;
    }

    void install_package(const Package& pkg, const fs::path& pkg_file) {
        check_dependencies(pkg);
        fs::path temp_dir = verify_package_integrity(pkg_file);
        install_files_from_dir(pkg, temp_dir);
        db.add(pkg);
        fs::remove_all(temp_dir);
    }

    void remove(const std::vector<std::string>& pkg_names, bool force = false) {
        std::vector<Package> pkgs;
        for (const auto& pkg_name : pkg_names) {
            auto pkg = db.get(pkg_name);
            if (!pkg) {
                throw SPMException("Package " + pkg_name + " not installed");
            }
            pkgs.push_back(*pkg);
        }

        if (!force) {
            for (const auto& pkg : pkgs) {
                auto reverse_deps = db.get_reverse_deps(pkg.name);
                if (!reverse_deps.empty()) {
                    std::string deps_str;
                    for (const auto& dep : reverse_deps) {
                        if (!deps_str.empty()) deps_str += ", ";
                        deps_str += dep;
                    }
                    throw SPMException("Cannot remove " + pkg.name + ": required by " + deps_str + 
                                     "\nUse --force to override");
                }
            }
        }

        show_remove_preview(pkgs);

        if (!force) {
            std::cout << "\nDo you want to continue? [Y/n] ";
            std::string resp;
            std::getline(std::cin, resp);
            if (!resp.empty() && resp != "y" && resp != "yes") {
                std::cout << "Operation cancelled." << std::endl;
                return;
            }
        }

        std::string snap_name = snap_mgr.create_snapshot(
            "remove-" + std::accumulate(pkg_names.begin(), pkg_names.end(), std::string(),
                [](const std::string& a, const std::string& b) {
                    return a + (a.empty() ? "" : ",") + b;
                }),
            pkg_names
        );

        try {
            start_time = chrono::system_clock::now();
            for (size_t i = 0; i < pkgs.size(); i++) {
                const auto& pkg = pkgs[i];
                std::cout << colored("\n[" + std::to_string(i + 1) + "/" + 
                                   std::to_string(pkgs.size()) + "] ", "cyan")
                          << colored("Removing " + pkg.name + "-" + pkg.version + "...", "yellow")
                          << std::endl;

                db.remove(pkg.name);

                int removed_count = 0;
                double removed_size = 0;

                for (const auto& file_path : pkg.files) {
                    fs::path abs_path = fs::path(config.ROOT) / file_path.substr(1);
                    bool is_protected = false;
                    for (const auto& p : config.PROTECTED_PATHS) {
                        if (abs_path.string().find(p) == 0) {
                            is_protected = true;
                            break;
                        }
                    }
                    if (is_protected) continue;

                    if (fs::exists(abs_path)) {
                        if (fs::is_regular_file(abs_path)) {
                            removed_size += fs::file_size(abs_path);
                            removed_count++;
                            fs::remove(abs_path);
                            cleanup_empty_parents(abs_path.parent_path());
                        } else if (fs::is_directory(abs_path)) {
                            fs::remove_all(abs_path);
                            cleanup_empty_parents(abs_path);
                        }
                    }
                }

                std::cout << colored("  Removed " + std::to_string(removed_count) + 
                                   " files (" + format_size(removed_size / 1024) + ")", "magenta")
                          << std::endl;
            }

            double elapsed = chrono::duration<double>(chrono::system_clock::now() - start_time).count();

            std::cout << colored("\nSuccessfully removed packages:", "green") << std::endl;
            for (const auto& pkg : pkgs) {
                std::cout << "  " << pkg.name << std::endl;
            }

            std::cout << colored("\nTime: " + std::to_string(elapsed) + "s", "cyan") << std::endl;

        } catch (const std::exception& e) {
            std::cerr << colored("\nRemoval failed: " + std::string(e.what()) + ", rolling back...", "red") << std::endl;
            snap_mgr.restore_snapshot(snap_name);
            throw SPMException("Removal rolled back due to error");
        }

        snap_mgr.prune_old_snapshots();
    }
};

// ========================
// Package Builder
// ========================
class PackageBuilder {
    fs::path build_dir;

    void copy_source(const fs::path& source_dir) {
        for (const auto& entry : fs::directory_iterator(source_dir)) {
            if (entry.path().filename() == ".git" || 
                entry.path().filename() == "build" || 
                entry.path().filename() == ".gitignore") {
                continue;
            }

            fs::path dest = build_dir / entry.path().filename();
            if (fs::is_directory(entry)) {
                fs::create_directories(dest);
                fs::copy(entry.path(), dest, fs::copy_options::recursive);
            } else {
                fs::copy_file(entry.path(), dest);
            }
        }
    }

public:
    PackageBuilder() : build_dir(config.BUILD_DIR) {
        if (fs::exists(build_dir)) {
            fs::remove_all(build_dir);
        }
        fs::create_directories(build_dir);
    }

    fs::path create_package(const fs::path& source_dir, const fs::path& output_dir, json meta_data) {
        std::string pkg_name = meta_data["name"];
        std::string pkg_version = meta_data["version"];
        fs::path output_path = output_dir / (pkg_name + "-" + pkg_version + ".spm");

        copy_source(source_dir);

        double total_size = 0;
        int file_count = 0;

        // Create META-INF directory
        fs::path meta_inf_dir = build_dir / "META-INF";
        fs::create_directories(meta_inf_dir);

        // Collect file list
        std::vector<std::string> file_list;
        for (const auto& entry : fs::recursive_directory_iterator(build_dir)) {
            if (entry.is_regular_file()) {
                fs::path rel_path = fs::relative(entry.path(), build_dir);
                file_list.push_back(rel_path.string());
                total_size += entry.file_size();
                file_count++;
            }
        }

        meta_data["files"] = file_list;
        meta_data["size"] = total_size / 1024;  // KB

        // Add metadata file
        std::ofstream meta_file(build_dir / "package.json");
        meta_file << meta_data.dump(2);

        // Build hash manifest
        fs::path sf_path = meta_inf_dir / "SPM.SF";
        std::ofstream sf(sf_path);
        for (const auto& file : file_list) {
            fs::path file_path = build_dir / file;
            if (fs::is_regular_file(file_path)) {
                std::string sha256 = sha256_file(file_path);
                sf << file << " SHA256: " << sha256 << "\n";
            }
        }

        // Create package
        struct archive* a = archive_write_new();
        archive_write_set_format_pax_restricted(a);
        archive_write_add_filter_gzip(a);
        archive_write_open_filename(a, output_path.c_str());

        for (const auto& file : file_list) {
            fs::path file_path = build_dir / file;
            struct archive_entry* entry = archive_entry_new();
            archive_entry_set_pathname(entry, file.c_str());
            archive_entry_set_size(entry, fs::file_size(file_path));
            archive_entry_set_filetype(entry, fs::is_directory(file_path) ? AE_IFDIR : AE_IFREG);
            archive_entry_set_perm(entry, 0644);

            archive_write_header(a, entry);
            if (fs::is_regular_file(file_path)) {
                std::ifstream f(file_path, std::ios::binary);
                char buffer[4096];
                while (f.read(buffer, sizeof(buffer))) {
                    archive_write_data(a, buffer, f.gcount());
                }
                archive_write_data(a, buffer, f.gcount());
            }
            archive_entry_free(entry);
        }

        archive_write_close(a);
        archive_write_free(a);

        std::cout << colored("\nPackage created: " + output_path.string(), "green") << std::endl;
        std::cout << "  Files: " << file_count << std::endl;
        std::cout << "  Size: " << format_size(total_size / 1024) << std::endl;
        return output_path;
    }
};

// ========================
// CLI Interface
// ========================
int main(int argc, char* argv[]) {
    try {
        if (argc < 2) {
            std::cerr << "Usage: spm <command> [options]" << std::endl;
            return 1;
        }

        std::string command = argv[1];

        if (command == "install") {
            if (argc < 3) {
                std::cerr << "Usage: spm install <package> [package...] [--force]" << std::endl;
                return 1;
            }

            std::vector<std::string> packages;
            bool force = false;
            for (int i = 2; i < argc; i++) {
                if (std::string(argv[i]) == "--force") {
                    force = true;
                } else {
                    packages.push_back(argv[i]);
                }
            }

            PackageManager pm;
            pm.install(packages, force);

        } else if (command == "remove") {
            if (argc < 3) {
                std::cerr << "Usage: spm remove <package> [package...] [--force]" << std::endl;
                return 1;
            }

            std::vector<std::string> packages;
            bool force = false;
            for (int i = 2; i < argc; i++) {
                if (std::string(argv[i]) == "--force") {
                    force = true;
                } else {
                    packages.push_back(argv[i]);
                }
            }

            PackageManager pm;
            pm.remove(packages, force);

        } else if (command == "build") {
            if (argc < 6) {
                std::cerr << "Usage: spm build <source> --name <name> --version <version> "
                          << "--versionCode <code> [--dep name=version] [--conflict name] "
                          << "[--output dir]" << std::endl;
                return 1;
            }

            fs::path source_dir = argv[2];
            std::string name, version;
            int version_code = 0;
            std::vector<std::string> deps;
            std::vector<std::string> conflicts;
            fs::path output_dir = ".";

            for (int i = 3; i < argc; i++) {
                std::string arg = argv[i];
                if (arg == "--name" && i + 1 < argc) {
                    name = argv[++i];
                } else if (arg == "--version" && i + 1 < argc) {
                    version = argv[++i];
                } else if (arg == "--versionCode" && i + 1 < argc) {
                    version_code = std::stoi(argv[++i]);
                } else if (arg == "--dep" && i + 1 < argc) {
                    deps.push_back(argv[++i]);
                } else if (arg == "--conflict" && i + 1 < argc) {
                    conflicts.push_back(argv[++i]);
                } else if (arg == "--output" && i + 1 < argc) {
                    output_dir = argv[++i];
                }
            }

            if (name.empty() || version.empty() || version_code == 0) {
                std::cerr << "Missing required fields: name, version, versionCode" << std::endl;
                return 1;
            }

            json meta = {
                {"name", name},
                {"version", version},
                {"versionCode", version_code},
                {"dependencies", {}},
                {"conflicts", conflicts}
            };

            for (const auto& dep : deps) {
                size_t sep = dep.find('=');
                if (sep != std::string::npos) {
                    std::string dep_name = dep.substr(0, sep);
                    std::string dep_version = dep.substr(sep + 1);
                    meta["dependencies"][dep_name] = dep_version;
                } else {
                    meta["dependencies"][dep] = "*";
                }
            }

            PackageBuilder builder;
            builder.create_package(source_dir, output_dir, meta);

        } else if (command == "list") {
            Database db(config.DB_PATH);
            auto packages = db.list_packages();

            if (packages.empty()) {
                std::cout << "No packages installed." << std::endl;
                return 0;
            }

            std::cout << colored("Installed packages:", "cyan") << std::endl;
            for (const auto& pkg_name : packages) {
                auto pkg = db.get(pkg_name);
                if (pkg) {
                    std::cout << "  " << pkg->name << " " << colored(pkg->version, "yellow") << std::endl;
                }
            }

        } else if (command == "clear") {
            SnapshotManager snap_mgr(config.SNAPSHOTS_DIR, config.MAX_SNAPSHOTS);
            std::cout << "Are you sure you want to delete all snapshots? [y/N] ";
            std::string confirm;
            std::getline(std::cin, confirm);
            if (confirm == "y" || confirm == "yes") {
                fs::remove_all(config.SNAPSHOTS_DIR);
                fs::create_directories(config.SNAPSHOTS_DIR);
                std::cout << colored("All snapshots cleared.", "green") << std::endl;
            } else {
                std::cout << "Operation cancelled." << std::endl;
            }

        } else {
            std::cerr << "Unknown command: " << command << std::endl;
            return 1;
        }

    } catch (const SPMException& e) {
        std::cerr << colored("\nError: " + std::string(e.what()), "red") << std::endl;
        return 1;
    } catch (const std::exception& e) {
        std::cerr << colored("\nUnexpected error: " + std::string(e.what()), "red") << std::endl;
        return 1;
    }

    return 0;
}