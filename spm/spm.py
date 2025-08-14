import os
import sys
import json
import shutil
import tarfile
import argparse
import textwrap
import time
import hashlib
import tempfile
import atexit
import fnmatch
import re
import urllib.request
from pathlib import Path
from datetime import datetime
import subprocess
import math
    
from termcolor import colored

# ========================
# 用户可配置区域
# ========================
CONFIG = {
    "ROOT": "./",
    "DB_PATH": "./var/lib/spm/db",
    "SNAPSHOTS_DIR": "./var/lib/spm/snaps",
    "PKG_CACHE": "./var/cache/spm/pkg",
    "REPO_DIR": "./",
    "CONFIG_DIR": "./etc/spm",
    "REPO_CONFIG": "./etc/spm/repos.json",
    "MAX_SNAPSHOTS": 10,
    "BUILD_DIR": "./spm_build",
    "PROTECTED_PATHS": ["./"],
    "PACMAN_STYLE_PROGRESS": True  # 启用进度条
}

# ========================
# 核心实现
# ========================
class SPMException(Exception):
    pass

class Package:
    def __init__(self, name, version, version_code=0, files=None, deps=None, conflicts=None, size=0):
        self.name = name
        self.version = version
        self.version_code = version_code
        self.files = files or []
        self.deps = deps or {}
        self.conflicts = conflicts or []
        self.size = size
    
    def to_dict(self):
        return {
            "name": self.name,
            "version": self.version,
            "versionCode": self.version_code,
            "files": self.files,
            "dependencies": self.deps,
            "conflicts": self.conflicts,
            "size": self.size
        }
    
    @classmethod
    def from_dict(cls, data):
        return cls(
            data["name"],
            data["version"],
            version_code=data.get("versionCode", 0),
            files=data.get("files", []),
            deps=data.get("dependencies", {}),
            conflicts=data.get("conflicts", []),
            size=data.get("size", 0)
        )

class Database:
    def __init__(self, db_path):
        self.db_path = Path(db_path)
        self.db_path.mkdir(parents=True, exist_ok=True)
    
    def get_package_path(self, pkg_name):
        return self.db_path / f"{pkg_name}.json"
    
    def add(self, package):
        with open(self.get_package_path(package.name), "w") as f:
            json.dump(package.to_dict(), f, indent=2)
    
    def remove(self, pkg_name):
        path = self.get_package_path(pkg_name)
        if path.exists():
            path.unlink()
    
    def get(self, pkg_name):
        path = self.get_package_path(pkg_name)
        if not path.exists():
            return None
        with open(path) as f:
            return Package.from_dict(json.load(f))
    
    def list_packages(self):
        return [f.stem for f in self.db_path.glob("*.json")]
    
    def get_reverse_deps(self, pkg_name):
        reverse_deps = []
        for pkg in self.list_packages():
            pkg_data = self.get(pkg)
            if pkg_name in pkg_data.deps:
                reverse_deps.append(pkg)
        return reverse_deps
        
class RepoManager:
    def __init__(self, config_path=None):
        self.repos = {}         # 源名 → URL
        self.index_cache = {}   # 源名 → {pkg_name: meta}
        self.config_path = config_path or CONFIG["REPO_CONFIG"]
        self._load_repos()
        self._load_indexes()
    
    
    def _load_indexes(self):
        for name, base_url in self.repos.items():
            try:
                index_url = f"{base_url}/index.json"
                print(f"Fetching index from {index_url}...")
                resp = urllib.request.urlopen(index_url)
                index_data = json.load(resp)
                self.index_cache[name] = index_data
            except Exception as e:
                print(colored(f"[WARN] Failed to load index from {name}: {e}", "red"))

    def _load_repos(self):
        config_file = Path(self.config_path)
        if not config_file.exists():
            print(colored(f"[WARN] Repo config not found: {config_file}", "red"))
            return
        
        with open(config_file) as f:
            self.repos = json.load(f)

    def fetch_indexes(self):
        for name, base_url in self.repos.items():
            index_url = f"{base_url}/index.json"
            print(colored(f"Fetching index from {index_url}", "cyan"))
            try:
                with urllib.request.urlopen(index_url) as response:
                    data = response.read()
                    index = json.loads(data.decode())
                    self.index_cache[name] = index
            except Exception as e:
                print(colored(f"Failed to fetch index from {name}: {e}", "red"))

    def find_package(self, pkg_name, version_req="*"):
        candidates = []
        for repo_name, index in self.index_cache.items():
            if pkg_name in index:
                meta = index[pkg_name]
                if self._version_satisfies(meta["version"], version_req):
                    candidates.append((repo_name, meta))
        # 按 versionCode 降序
        return sorted(candidates, key=lambda x: -x[1].get("versionCode", 0))
    
    def _version_satisfies(self, version_code, requirement):
        if requirement in ("*", ""):
            return True

        match = re.match(r"(>=|<=|>|<|=)?\s*(\d+)", requirement)
        if not match:
            return False
        op, target = match.groups()
        target = int(target)

        if op == ">=":
            return version_code >= target
        elif op == "<=":
            return version_code <= target
        elif op == ">":
            return version_code > target
        elif op == "<":
            return version_code < target
        elif op == "=" or op is None:
            return version_code == target
        return False


def download_with_progress(url, dest_path):
    def report(block_num, block_size, total_size):
        downloaded = block_num * block_size
        percent = downloaded / total_size * 100 if total_size else 0
        bar = f"[{'=' * int(percent/5):20}] {percent:5.1f}%"
        sys.stdout.write(f"\rDownloading: {bar}")
        sys.stdout.flush()
    urllib.request.urlretrieve(url, dest_path, reporthook=report)
    print()

def download_package(meta, base_url, dest_path):
    url = f"{base_url}/{meta['filename']}"
    print(f"Downloading {meta['filename']} ...")
    download_with_progress(url, dest_path)
    
    # 校验 sha256
    with open(dest_path, "rb") as f:
        data = f.read()
    sha256 = hashlib.sha256(data).hexdigest()
    if sha256 != meta["sha256"]:
        raise SPMException(f"SHA256 mismatch: {meta['filename']}")

class SnapshotManager:
    def __init__(self, snap_dir, max_snaps):
        self.snap_dir = Path(snap_dir)
        self.max_snaps = max_snaps
        self.snap_dir.mkdir(parents=True, exist_ok=True)
    
    def create_snapshot(self, operation, packages):
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        snap_name = f"{timestamp}-{operation}"
        snap_path = self.snap_dir / snap_name
        
        state_dir = snap_path / "state"
        state_dir.mkdir(parents=True)
        
        with open(snap_path / "packages.json", "w") as f:
            json.dump(packages, f)
        
        db_snap = snap_path / "db"
        if Path(CONFIG["DB_PATH"]).exists():
            shutil.copytree(CONFIG["DB_PATH"], db_snap)
        
        return snap_name
    
    def restore_snapshot(self, snap_name):
        snap_path = self.snap_dir / snap_name
        if not snap_path.exists():
            raise SPMException(f"Snapshot {snap_name} not found")
        
        db_snap = snap_path / "db"
        if db_snap.exists():
            shutil.rmtree(CONFIG["DB_PATH"])
            shutil.copytree(db_snap, CONFIG["DB_PATH"])
        
        with open(snap_path / "packages.json") as f:
            packages = json.load(f)
        
        self._clean_system_files(packages)
        
        state_dir = snap_path / "state"
        if state_dir.exists():
            self._restore_files(state_dir)
        
        shutil.rmtree(snap_path)
    
    def _clean_system_files(self, packages):
        db = Database(CONFIG["DB_PATH"])
        for pkg_name in packages:
            pkg = db.get(pkg_name)
            if pkg:
                for file_path in pkg.files:
                    abs_path = Path(CONFIG["ROOT"]) / file_path.lstrip("/")
                    if any(str(abs_path).startswith(p) for p in CONFIG["PROTECTED_PATHS"]):
                        continue
                    if abs_path.exists():
                        if abs_path.is_dir():
                            shutil.rmtree(abs_path)
                        else:
                            abs_path.unlink()
    
    def _restore_files(self, state_dir):
        for root, _, files in os.walk(state_dir):
            rel_root = Path(root).relative_to(state_dir)
            target_root = Path(CONFIG["ROOT"]) / rel_root
            
            target_root.mkdir(parents=True, exist_ok=True)
            
            for file in files:
                src = Path(root) / file
                dest = target_root / file
                shutil.copy2(src, dest)
    
    def prune_old_snapshots(self):
        snaps = sorted(self.snap_dir.iterdir())
        if len(snaps) > self.max_snaps:
            for snap in snaps[:len(snaps) - self.max_snaps]:
                shutil.rmtree(snap)

class DependencyResolver:
    def __init__(self, db, repo_dir):
        self.db = db
        self.repo_dir = Path(repo_dir)
        self.visited = set()
        self.repo_manager = RepoManager()
    
    def resolve(self, pkg_name, version_req="*"):
        key = f"{pkg_name}:{version_req}"
        if key in self.visited:
            return []
        self.visited.add(key)

        installed = self.db.get(pkg_name)
        if installed and self._version_satisfies(installed.version_code, version_req):
            return []

        # 本地宽松匹配
        candidate_files = list(self.repo_dir.glob(f"*{pkg_name}*.spm"))

        if not candidate_files:
            # 本地没有匹配，尝试从远程获取 index 并下载
            results = self.repo_manager.find_package(pkg_name, version_req)
            if results:
                repo, meta = results[0]
                pkg_file = self.repo_dir / meta["filename"]
                if not pkg_file.exists():
                    download_package(meta, self.repo_manager.repos[repo], pkg_file)
                candidate_files.append(pkg_file)  # 放入候选列表
            else:
                raise SPMException(f"Package {pkg_name} not found in local or remote sources")

        # 多候选文件让用户选择
        if len(candidate_files) > 1:
            print(colored(f"\nMultiple candidates found for '{pkg_name}':", "yellow", attrs=["bold"]))
            for i, f in enumerate(candidate_files):
                print(f"  [{i}] {f.name}")
            choice = input(f"Select package index [0-{len(candidate_files)-1}]: ").strip()
            try:
                index = int(choice)
                pkg_file = candidate_files[index]
            except (ValueError, IndexError):
                raise SPMException("Invalid selection.")
        else:
            pkg_file = candidate_files[0]

        # 读取包元数据
        with tarfile.open(pkg_file, "r:gz") as tar:
            try:
                meta_member = tar.getmember("package.json")
            except KeyError:
                raise SPMException(f"{pkg_file.name} is missing package.json")
            meta_data = json.load(tar.extractfile(meta_member))
            pkg = Package.from_dict(meta_data)

        if not self._version_satisfies(pkg.version_code, version_req):
            raise SPMException(
                f"Required version_code {version_req} not found for {pkg_name} (found {pkg.version_code})"
            )

        deps_to_install = [pkg]
        for dep, dep_version in pkg.deps.items():
            deps_to_install.extend(self.resolve(dep, dep_version))

        return deps_to_install

    
    def _version_satisfies(self, version_code, requirement):
        if requirement in ("*", ""):
            return True

        match = re.match(r"(>=|<=|>|<|=)?\s*(\d+)", requirement)
        if not match:
            return False
        op, target = match.groups()
        target = int(target)

        if op == ">=":
            return version_code >= target
        elif op == "<=":
            return version_code <= target
        elif op == ">":
            return version_code > target
        elif op == "<":
            return version_code < target
        elif op == "=" or op is None:
            return version_code == target
        return False

class PackageManager:
    def __init__(self):
        self.db = Database(CONFIG["DB_PATH"])
        self.snap_mgr = SnapshotManager(CONFIG["SNAPSHOTS_DIR"], CONFIG["MAX_SNAPSHOTS"])
        self.repo_dir = Path(CONFIG["REPO_DIR"])
        self.pkg_cache = Path(CONFIG["PKG_CACHE"])
        self.pkg_cache.mkdir(parents=True, exist_ok=True)
        self.resolver = DependencyResolver(self.db, self.repo_dir)
        self.file_count = 0
        self.total_size = 0
        self.start_time = 0
    
    def install(self, pkg_names, force=False):
        all_pkgs = []
        for pkg_name in pkg_names:
            self.resolver.visited = set()
            all_pkgs.extend(self.resolver.resolve(pkg_name))
        
        unique_pkgs = []
        seen = set()
        for pkg in all_pkgs:
            if pkg.name not in seen:
                unique_pkgs.append(pkg)
                seen.add(pkg.name)
        
        if not force:
            for pkg in unique_pkgs:
                self._check_conflicts(pkg)
        
        self._show_install_preview(unique_pkgs)
        
        if not force:
            resp = input("\nDo you want to continue? [Y/n] ").strip().lower()
            if resp not in ['', 'y', 'yes']:
                print("Operation cancelled.")
                return
        
        snap_name = self.snap_mgr.create_snapshot(
            f"install-{','.join(pkg_names)}", 
            [pkg.name for pkg in unique_pkgs]
        )
        
        try:
            self.start_time = time.time()
            for i, pkg in enumerate(unique_pkgs):
                print(colored(f"\n[{i+1}/{len(unique_pkgs)}] ", "cyan") + 
                      colored(f"Installing {pkg.name}-{pkg.version}...", "yellow", attrs=["bold"]))
                
                pkg_file = self.repo_dir / f"{pkg.name}-{pkg.version}.spm"
                self._install_package(pkg, pkg_file)
            
            elapsed = time.time() - self.start_time
            speed = self.total_size / elapsed / 1024 if elapsed > 0 else 0  # MB/s
            
            print(colored("\nSuccessfully installed packages:", "green", attrs=["bold"]))
            for pkg in unique_pkgs:
                print(f"  {pkg.name}-{pkg.version}")
            
            print(colored(f"\nTotal files: {self.file_count}", "cyan"))
            print(colored(f"Total size: {self._format_size(self.total_size)}", "cyan"))
            print(colored(f"Time: {elapsed:.2f}s", "cyan"))
            print(colored(f"Speed: {speed:.2f} MB/s", "cyan"))
        
        except Exception as e:
            print(colored(f"\nInstallation failed: {e}, rolling back...", "red"))
            self.snap_mgr.restore_snapshot(snap_name)
            raise SPMException("Installation rolled back due to error")
        
        finally:
            self.snap_mgr.prune_old_snapshots()
            self.file_count = 0
            self.total_size = 0
    
    def remove(self, pkg_names, force=False):
        pkgs = []
        for pkg_name in pkg_names:
            pkg = self.db.get(pkg_name)
            if not pkg:
                raise SPMException(f"Package {pkg_name} not installed")
            pkgs.append(pkg)
        
        if not force:
            for pkg in pkgs:
                reverse_deps = self.db.get_reverse_deps(pkg.name)
                if reverse_deps:
                    raise SPMException(
                        f"Cannot remove {pkg.name}: required by {', '.join(reverse_deps)}"
                    + "\nUse --force to override")
        
        self._show_remove_preview(pkgs)
        
        if not force:
            resp = input("\nDo you want to continue? [Y/n] ").strip().lower()
            if resp not in ['', 'y', 'yes']:
                print("Operation cancelled.")
                return
        
        snap_name = self.snap_mgr.create_snapshot(
            f"remove-{','.join(pkg_names)}", 
            [pkg.name for pkg in pkgs]
        )
        
        try:
            self.start_time = time.time()
            for i, pkg in enumerate(pkgs):
                print(colored(f"\n[{i+1}/{len(pkgs)}] ", "cyan") + 
                      colored(f"Removing {pkg.name}-{pkg.version}...", "yellow", attrs=["bold"]))
                
                self.db.remove(pkg.name)
                
                # 统计删除的文件
                removed_count = 0
                removed_size = 0
                
                for file_path in pkg.files:
                    abs_path = Path(CONFIG["ROOT"]) / file_path.lstrip("/")
                    if any(str(abs_path).startswith(p) for p in CONFIG["PROTECTED_PATHS"]):
                        continue
                    if abs_path.exists():
                        if abs_path.is_file():
                            removed_size += abs_path.stat().st_size
                            removed_count += 1
                            abs_path.unlink()
                            self._cleanup_empty_parents(abs_path.parent)
                        elif abs_path.is_dir():
                            shutil.rmtree(abs_path)
                            self._cleanup_empty_parents(abs_path)

                
                # 显示删除统计
                print(colored(f"  Removed {removed_count} files ({self._format_size(removed_size/1024)})", "magenta"))
            
            elapsed = time.time() - self.start_time
            
            print(colored("\nSuccessfully removed packages:", "green", attrs=["bold"]))
            for pkg in pkgs:
                print(f"  {pkg.name}")
            
            print(colored(f"\nTime: {elapsed:.2f}s", "cyan"))
        
        except Exception as e:
            print(colored(f"\nRemoval failed: {e}, rolling back...", "red"))
            self.snap_mgr.restore_snapshot(snap_name)
            raise SPMException("Removal rolled back due to error")
        
        finally:
            self.snap_mgr.prune_old_snapshots()
    
    def _install_package(self, pkg, pkg_file):
        self._check_dependencies(pkg)
        # 校验并解压到临时路径
        temp_dir = self._verify_package_integrity(pkg_file)
        # 安装文件（从解压后的路径中复制）
        self._install_files_from_dir(pkg, temp_dir)
        self.db.add(pkg)
        atexit.register(lambda: shutil.rmtree(temp_dir))

    def _install_files_from_dir(self, pkg, src_dir):
        members = [Path(f) for f in pkg.files]
        total_files = len(members)

        installed_count = 0
        skipped_count = 0

        for i, rel_path in enumerate(members):
            src_path = src_dir / rel_path
            dest_path = Path(CONFIG["ROOT"]) / rel_path

            if src_path.is_dir():
                dest_path.mkdir(parents=True, exist_ok=True)
                continue
        
            # 冲突检测
            conflict = self._check_file_conflict(dest_path, pkg.name)
            if conflict:
                skipped_count += 1
                continue
        
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_path, dest_path)

            installed_count += 1
            self.file_count += 1
            self.total_size += src_path.stat().st_size / 1024

            if CONFIG["PACMAN_STYLE_PROGRESS"]:
                self._show_pacman_progress(i+1, total_files, str(rel_path))
    
        if skipped_count > 0:
            print(colored(f"  Skipped {skipped_count} files due to conflicts", "yellow"))
            
        print(colored(f"  Installed {installed_count} files", "green"))
            
            
    def _verify_package_integrity(self, pkg_file):
        """解压到临时目录并进行校验，返回临时路径"""
        temp_dir = Path(tempfile.mkdtemp(prefix="spm_pkg_"))
        file_list = []

        with tarfile.open(pkg_file, "r:gz") as tar:
            tar.extractall(path=temp_dir, filter='data')
    
        sf_file = temp_dir / "META-INF/SPM.SF"
        if not sf_file.exists():
            raise SPMException("Missing integrity metadata: META-INF/SPM.SF")

        # 读取校验清单
        lines = sf_file.read_text().splitlines()
        total = len(lines)
        for i, line in enumerate(lines, 1):
            if not line.strip():
                continue
            try:
                file_rel, _, expected = line.partition("SHA256:")
                file_rel = file_rel.strip()
                expected = expected.strip()
                file_path = temp_dir / file_rel

                if not file_path.exists():
                    raise SPMException(f"Missing file during verification: {file_rel}")
            
                actual = hashlib.sha256(file_path.read_bytes()).hexdigest()
                if actual != expected:
                    raise SPMException(f"Hash mismatch: {file_rel}")

                self._show_pacman_progress(i, total, file_rel)
            except Exception as e:
                raise SPMException(f"Integrity check failed: {e}")
    
        print(colored("  Integrity OK", "green"))
        return temp_dir
    
    def _cleanup_empty_parents(self, path):
        """
        从 path 向上递归删除空目录，直到遇到非空或受保护目录
        """
        path = Path(path)

        root_path = Path(CONFIG["ROOT"]).resolve()
        protected_paths = [Path(p).resolve() for p in CONFIG["PROTECTED_PATHS"]]


        while path != root_path:
            if any(str(path).startswith(str(p)) for p in protected_paths):
                break
            try:
                path.rmdir()
            except OSError:
                break  # 非空或无权限
            path = path.parent
    
    def _show_pacman_progress(self, current, total, filename):
        """显示Pacman风格的进度条"""
        # 计算进度百分比
        percent = current / total
        
        # Pacman风格进度条
        bar_length = 20
        filled_length = int(round(bar_length * percent))
        bar = '[' + colored('=' * filled_length, 'green') + '>' + ' ' * (bar_length - filled_length - 1) + ']'
        
        # 格式化文件名显示
        display_name = filename
        if len(filename) > 30:
            display_name = "..." + filename[-27:]
        
        # 构建进度行
        progress_line = f"  {bar}"
        
        # 输出到控制台（覆盖当前行）
        sys.stdout.write('\r' + progress_line)
        sys.stdout.flush()
        
        # 如果是最后一个文件，换行
        if current == total:
            print()
    
    def _check_file_conflict(self, file_path, installing_pkg):
        """检查文件冲突，只检查文件（忽略目录）"""
        # 如果路径不存在，没有冲突
        if not file_path.exists():
            return None
        
        # 如果是目录，不检查冲突（多个包可以共享目录）
        if file_path.is_dir():
            return None
        
        # 在数据库中查找文件所有者
        for pkg_name in self.db.list_packages():
            pkg = self.db.get(pkg_name)
            if str(file_path.relative_to(CONFIG["ROOT"])) in pkg.files:
                return pkg_name
        
        # 文件存在但未被任何包管理
        return "system (unmanaged)"
    
    def _check_dependencies(self, pkg):
        for dep, version_req in pkg.deps.items():
            installed = self.db.get(dep)
            if not installed:
                raise SPMException(f"Missing dependency: {dep} required by {pkg.name}")
            
            if not self.resolver._version_satisfies(installed.version, version_req):
                raise SPMException(
                    f"Dependency version mismatch: {dep} requires {version_req} but found {installed.version}"
                )
    
    def _check_conflicts(self, pkg):
        for conflict in pkg.conflicts:
            if self.db.get(conflict):
                raise SPMException(f"Conflicts with installed package: {conflict}")
    
    def _show_install_preview(self, pkgs):
        print(colored("\nPackages to install:", "yellow", attrs=["bold"]))
        for pkg in pkgs:
            status = colored("new", "green") if not self.db.get(pkg.name) else colored("upgrade", "cyan")
            print(f"  {pkg.name}-{pkg.version} ({status})")
        
        total_size = sum(pkg.size for pkg in pkgs)
        size_str = self._format_size(total_size)
        
        new_pkgs = [pkg for pkg in pkgs if not self.db.get(pkg.name)]
        upgrade_pkgs = [pkg for pkg in pkgs if self.db.get(pkg.name)]
        
        print(colored("\nSummary:", "yellow", attrs=["bold"]))
        print(f"  New packages: {colored(len(new_pkgs), 'green')}")
        print(f"  Upgrades: {colored(len(upgrade_pkgs), 'cyan')}")
        print(f"  Total download size: {colored(size_str, 'cyan')}")
        print(f"  Disk space required: {colored(size_str, 'cyan')}")
    
    def _show_remove_preview(self, pkgs):
        print(colored("\nPackages to remove:", "yellow", attrs=["bold"]))
        for pkg in pkgs:
            print(f"  {pkg.name}-{pkg.version}")
        
        total_size = sum(pkg.size for pkg in pkgs)
        size_str = self._format_size(total_size)
        
        affected = set()
        for pkg in pkgs:
            affected.update(self.db.get_reverse_deps(pkg.name))
        
        print(colored("\nSummary:", "yellow", attrs=["bold"]))
        print(f"  Packages to remove: {colored(len(pkgs), 'red')}")
        if affected:
            print(f"  Affected packages: {colored(', '.join(affected), 'yellow')}")
        print(f"  Disk space freed: {colored(size_str, 'cyan')}")
    
    def _format_size(self, size_kb):
        if size_kb < 1024:
            return f"{size_kb:.1f} KB"
        elif size_kb < 1024 * 1024:
            return f"{size_kb/1024:.1f} MB"
        else:
            return f"{size_kb/(1024*1024):.1f} GB"

class PackageBuilder:
    def __init__(self):
        self.build_dir = Path(CONFIG["BUILD_DIR"])
        if self.build_dir.exists():
            shutil.rmtree(self.build_dir)
        self.build_dir.mkdir()
    
    def create_package(self, source_dir, output_dir, meta_data):
        pkg_name = meta_data["name"]
        pkg_version = meta_data["version"]
        output_path = Path(output_dir) / f"{pkg_name}-{pkg_version}.spm"
        
        self._copy_source(source_dir)
        
        total_size = 0
        file_count = 0
        
        # 创建 META-INF 目录
        meta_inf_dir = self.build_dir / "META-INF"
        meta_inf_dir.mkdir(parents=True, exist_ok=True)
        
        # 收集文件列表
        file_list = []
        for root, _, files in os.walk(self.build_dir):
            for file in files:
                file_path = Path(root) / file
                rel_path = file_path.relative_to(self.build_dir)
                file_list.append(str(rel_path))
                
                # 计算大小
                file_size = file_path.stat().st_size
                total_size += file_size
                file_count += 1
        
        meta_data["files"] = file_list
        meta_data["size"] = total_size / 1024  # KB
        
        # 添加元数据文件
        with open(self.build_dir / "package.json", "w") as f:
            json.dump(meta_data, f, indent=2)
        
        # 构建哈希清单
        sf_path = meta_inf_dir / "SPM.SF"
        with open(sf_path, "w") as sf:
            for file in file_list:
                file_path = self.build_dir / file
                if file_path.is_file():
                    sha256 = hashlib.sha256(file_path.read_bytes()).hexdigest()
                    sf.write(f"{file} SHA256: {sha256}\n")
        
        # 创建包
        with tarfile.open(output_path, "w:gz") as tar:
            tar.add(self.build_dir, arcname="")
        
        print(colored(f"\nPackage created: {output_path}", "green"))
        print(f"  Files: {file_count}")
        print(f"  Size: {self._format_size(total_size/1024)}")
        return output_path
    
    def _copy_source(self, source_dir):
        source = Path(source_dir)
        for item in source.glob("*"):
            if item.name in [".git", "build", ".gitignore"]:
                continue
            dest = self.build_dir / item.name
            if item.is_dir():
                shutil.copytree(item, dest)
            else:
                shutil.copy2(item, dest)
    
    def _format_size(self, size_kb):
        if size_kb < 1024:
            return f"{size_kb:.1f} KB"
        return f"{size_kb/1024:.1f} MB"

# ========================
# CLI接口
# ========================
def main():
    parser = argparse.ArgumentParser(prog="spm", description="A lightweight and practical package management program called Super Package Manager, Version 1")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    install_parser = subparsers.add_parser("install", help="Install packages")
    install_parser.add_argument("packages", nargs="+", help="Package names or files")
    install_parser.add_argument("--force", action="store_true", help="Skip dependency checks")
    
    remove_parser = subparsers.add_parser("remove", help="Remove packages")
    remove_parser.add_argument("packages", nargs="+", help="Package names")
    remove_parser.add_argument("--force", action="store_true", help="Ignore reverse dependencies")
    
    build_parser = subparsers.add_parser("build", help="Build a package")
    build_parser.add_argument("source", help="Source directory")
    build_parser.add_argument("--name", required=True, help="Package name")
    build_parser.add_argument("--version", required=True, help="Package version")
    build_parser.add_argument("--versionCode", type=int, required=True, help="Version code (integer)")
    build_parser.add_argument("--dep", action="append", help="Dependency (format: name=version)")
    build_parser.add_argument("--conflict", action="append", help="Conflicting package")
    build_parser.add_argument("--output", default=".", help="Output directory")
    
    list_parser = subparsers.add_parser("list", help="List installed packages")
    
    clear_parser = subparsers.add_parser("clear", help="Clear all snapshots")
    
    args = parser.parse_args()
    
    try:
        if args.command == "install":
            pm = PackageManager()
            pm.install(args.packages, args.force)
        
        elif args.command == "remove":
            pm = PackageManager()
            pm.remove(args.packages, args.force)
        
        elif args.command == "build":
            meta = {
                "name": args.name,
                "version": args.version,
                "versionCode": args.versionCode,
                "dependencies": {},
                "conflicts": args.conflict or []
            }
            
            if "versionCode" not in meta:
                raise SPMException("Missing required field: versionCode")
            
            if args.dep:
                for dep in args.dep:
                    name, _, version = dep.partition("=")
                    meta["dependencies"][name] = version or "*"
            
            builder = PackageBuilder()
            builder.create_package(args.source, args.output, meta)
        
        elif args.command == "list":
            db = Database(CONFIG["DB_PATH"])
            packages = db.list_packages()
            
            if not packages:
                print("No packages installed.")
                return
            
            print(colored("Installed packages:", "cyan", attrs=["bold"]))
            for pkg_name in packages:
                pkg = db.get(pkg_name)
                print(f"  {pkg.name} {colored(pkg.version, 'yellow')}")
        
        elif args.command == "clear":
            snap_mgr = SnapshotManager(CONFIG["SNAPSHOTS_DIR"], CONFIG["MAX_SNAPSHOTS"])
            confirm = input("Are you sure you want to delete all snapshots? [y/N] ").strip().lower()
            if confirm in ["y", "yes"]:
                shutil.rmtree(CONFIG["SNAPSHOTS_DIR"], ignore_errors=True)
                Path(CONFIG["SNAPSHOTS_DIR"]).mkdir(parents=True, exist_ok=True)
                print(colored("All snapshots cleared.", "green"))
            else:
                print("Operation cancelled.")

    
    except SPMException as e:
        print(colored(f"\nError: {e}", "red"), file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()