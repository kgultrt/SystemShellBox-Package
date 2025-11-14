package com.spm;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.regex.*;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

public class DependencyResolver {
    private final Database db;
    private final Path repoDir;
    private final Set<String> visited;
    
    public DependencyResolver(Database db, String repoDir) {
        this.db = db;
        this.repoDir = Paths.get(repoDir);
        this.visited = new HashSet<>();
        
        try {
            Files.createDirectories(this.repoDir);
        } catch (IOException e) {
            throw new RuntimeException("Failed to create repo directory", e);
        }
    }
    
    public void clearVisited() {
        visited.clear();
    }
    
    public List<PackageMetadata> resolve(String pkgName, String versionReq) throws SPMException {
        String key = pkgName + ":" + versionReq;
        if (visited.contains(key)) {
            return new ArrayList<>();
        }
        visited.add(key);
        
        // Check if already installed with satisfied version
        PackageMetadata installed = db.get(pkgName);
        if (installed != null && versionSatisfies(installed.getVersionCode(), versionReq)) {
            return new ArrayList<>();
        }
        
        // Find package in local repo
        List<Path> candidateFiles = findLocalPackages(pkgName, versionReq);
        
        if (candidateFiles.isEmpty()) {
            // Try remote sources (simplified - in real implementation, you'd fetch from remote)
            System.out.println("Package " + pkgName + " not found in local repo. Remote fetching not implemented.");
            throw new SPMException("Package " + pkgName + " not found");
        }
        
        // Let user choose if multiple candidates
        Path pkgFile;
        if (candidateFiles.size() > 1) {
            pkgFile = letUserChoosePackage(pkgName, candidateFiles);
        } else {
            pkgFile = candidateFiles.get(0);
        }
        
        // Read package metadata
        PackageMetadata pkg = readPackageMetadata(pkgFile);
        
        if (!versionSatisfies(pkg.getVersionCode(), versionReq)) {
            throw new SPMException(
                "Required version " + versionReq + " not found for " + pkgName + 
                " (found " + pkg.getVersionCode() + ")"
            );
        }
        
        // Resolve dependencies recursively
        List<PackageMetadata> depsToInstall = new ArrayList<>();
        depsToInstall.add(pkg);
        
        for (Map.Entry<String, String> dep : pkg.getDependencies().entrySet()) {
            depsToInstall.addAll(resolve(dep.getKey(), dep.getValue()));
        }
        
        return depsToInstall;
    }
    
    public List<PackageMetadata> resolve(String pkgName) throws SPMException {
        return resolve(pkgName, "*");
    }
    
    public boolean versionSatisfies(int versionCode, String requirement) {
        if ("*".equals(requirement) || requirement == null || requirement.isEmpty()) {
            return true;
        }
        
        Pattern pattern = Pattern.compile("(>=|<=|>|<|=)?\\s*(\\d+)");
        Matcher matcher = pattern.matcher(requirement);
        
        if (!matcher.find()) {
            return false;
        }
        
        String op = matcher.group(1);
        int target = Integer.parseInt(matcher.group(2));
        
        if (op == null) {
            return versionCode == target;
        }
        
        switch (op) {
            case ">=": return versionCode >= target;
            case "<=": return versionCode <= target;
            case ">": return versionCode > target;
            case "<": return versionCode < target;
            case "=": return versionCode == target;
            default: return false;
        }
    }
    
    private List<Path> findLocalPackages(String pkgName, String versionReq) throws SPMException {
        List<Path> candidates = new ArrayList<>();
        
        try {
            Files.list(repoDir)
                .filter(path -> path.toString().endsWith(".spm"))
                .filter(path -> {
                    String filename = path.getFileName().toString();
                    return filename.contains(pkgName);
                })
                .forEach(candidates::add);
        } catch (IOException e) {
            throw new SPMException("Failed to search local packages", e);
        }
        
        // Filter by version requirement if specified
        if (!"*".equals(versionReq)) {
            List<Path> filtered = new ArrayList<>();
            for (Path candidate : candidates) {
                try {
                    PackageMetadata pkg = readPackageMetadata(candidate);
                    if (versionSatisfies(pkg.getVersionCode(), versionReq)) {
                        filtered.add(candidate);
                    }
                } catch (SPMException e) {
                    // Skip invalid packages
                    System.err.println("Warning: Skipping invalid package " + candidate + ": " + e.getMessage());
                }
            }
            return filtered;
        }
        
        return candidates;
    }
    
    private Path letUserChoosePackage(String pkgName, List<Path> candidates) throws SPMException {
        System.out.println("\nMultiple candidates found for '" + pkgName + "':");
        for (int i = 0; i < candidates.size(); i++) {
            System.out.println("  [" + i + "] " + candidates.get(i).getFileName());
        }
        
        System.out.print("Select package index [0-" + (candidates.size() - 1) + "]: ");
        Scanner scanner = new Scanner(System.in);
        String input = scanner.nextLine().trim();
        
        try {
            int index = Integer.parseInt(input);
            if (index >= 0 && index < candidates.size()) {
                return candidates.get(index);
            }
        } catch (NumberFormatException e) {
            // Fall through to error
        }
        
        throw new SPMException("Invalid selection: " + input);
    }
    
    private PackageMetadata readPackageMetadata(Path pkgFile) throws SPMException {
        try (ZipInputStream zis = new ZipInputStream(Files.newInputStream(pkgFile))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                if ("package.json".equals(entry.getName())) {
                    // Read package.json content
                    ByteArrayOutputStream baos = new ByteArrayOutputStream();
                    byte[] buffer = new byte[1024];
                    int len;
                    while ((len = zis.read(buffer)) > 0) {
                        baos.write(buffer, 0, len);
                    }
                    
                    String json = baos.toString("UTF-8");
                    return parsePackageMetadata(json);
                }
                zis.closeEntry();
            }
        } catch (IOException e) {
            throw new SPMException("Failed to read package metadata from " + pkgFile, e);
        }
        
        throw new SPMException("package.json not found in " + pkgFile);
    }
    
    private PackageMetadata parsePackageMetadata(String json) {
        // Simple JSON parsing - extract basic fields
        String name = extractJsonString(json, "name");
        String version = extractJsonString(json, "version");
        int versionCode = extractJsonInt(json, "versionCode");
        
        PackageMetadata pkg = new PackageMetadata(name, version, versionCode);
        
        // Extract files
        List<String> files = extractJsonStringArray(json, "files");
        pkg.setFiles(files);
        
        // Extract dependencies
        Map<String, String> deps = extractJsonStringMap(json, "dependencies");
        pkg.setDependencies(deps);
        
        // Extract conflicts
        List<String> conflicts = extractJsonStringArray(json, "conflicts");
        pkg.setConflicts(conflicts);
        
        // Extract size
        long size = extractJsonLong(json, "size");
        pkg.setSize(size);
        
        return pkg;
    }
    
    private String extractJsonString(String json, String field) {
        Pattern pattern = Pattern.compile("\"" + field + "\":\\s*\"([^\"]+)\"");
        Matcher matcher = pattern.matcher(json);
        return matcher.find() ? matcher.group(1) : "";
    }
    
    private int extractJsonInt(String json, String field) {
        Pattern pattern = Pattern.compile("\"" + field + "\":\\s*(\\d+)");
        Matcher matcher = pattern.matcher(json);
        return matcher.find() ? Integer.parseInt(matcher.group(1)) : 0;
    }
    
    private long extractJsonLong(String json, String field) {
        Pattern pattern = Pattern.compile("\"" + field + "\":\\s*(\\d+)");
        Matcher matcher = pattern.matcher(json);
        return matcher.find() ? Long.parseLong(matcher.group(1)) : 0;
    }
    
    private List<String> extractJsonStringArray(String json, String field) {
        List<String> result = new ArrayList<>();
        Pattern pattern = Pattern.compile("\"" + field + "\":\\s*\\[([^\\]]+)\\]");
        Matcher matcher = pattern.matcher(json);
        
        if (matcher.find()) {
            String content = matcher.group(1);
            String[] items = content.split(",");
            for (String item : items) {
                String cleaned = item.trim().replace("\"", "");
                if (!cleaned.isEmpty()) {
                    result.add(cleaned);
                }
            }
        }
        
        return result;
    }
    
    private Map<String, String> extractJsonStringMap(String json, String field) {
        Map<String, String> result = new HashMap<>();
        Pattern pattern = Pattern.compile("\"" + field + "\":\\s*\\{([^}]+)\\}");
        Matcher matcher = pattern.matcher(json);
        
        if (matcher.find()) {
            String content = matcher.group(1);
            String[] pairs = content.split(",");
            for (String pair : pairs) {
                String[] keyValue = pair.split(":");
                if (keyValue.length == 2) {
                    String key = keyValue[0].trim().replace("\"", "");
                    String value = keyValue[1].trim().replace("\"", "");
                    result.put(key, value);
                }
            }
        }
        
        return result;
    }
}