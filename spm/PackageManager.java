package com.spm;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.zip.*;
import java.security.*;
import java.util.stream.Collectors;

public class PackageManager {
    private final Config CONFIG = new Config();
    private final Database db;
    private final SnapshotManager snapMgr;
    private final DependencyResolver resolver;
    
    private int fileCount = 0;
    private long totalSize = 0;
    private long startTime = 0;
    
    public PackageManager() {
        this.db = new Database(CONFIG.DB_PATH);
        this.snapMgr = new SnapshotManager(CONFIG.SNAPSHOTS_DIR, CONFIG.MAX_SNAPSHOTS);
        this.resolver = new DependencyResolver(db, CONFIG.REPO_DIR);
    }
    
    public void install(List<String> pkgNames, boolean force) throws SPMException {
        List<PackageMetadata> allPkgs = new ArrayList<>();
        for (String pkgName : pkgNames) {
            resolver.clearVisited();
            allPkgs.addAll(resolver.resolve(pkgName));
        }
        
        // Remove duplicates
        List<PackageMetadata> uniquePkgs = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (PackageMetadata pkg : allPkgs) {
            if (!seen.contains(pkg.getName())) {
                uniquePkgs.add(pkg);
                seen.add(pkg.getName());
            }
        }
        
        if (!force) {
            for (PackageMetadata pkg : uniquePkgs) {
                checkConflicts(pkg);
            }
        }
        
        showInstallPreview(uniquePkgs);
        
        if (!force) {
            System.out.print("\nDo you want to continue? [Y/n] ");
            Scanner scanner = new Scanner(System.in);
            String resp = scanner.nextLine().trim().toLowerCase();
            if (!resp.isEmpty() && !"y".equals(resp) && !"yes".equals(resp)) {
                System.out.println("Operation cancelled.");
                return;
            }
        }
        
        String snapName = snapMgr.createSnapshot(
            "install-" + String.join(",", pkgNames),
            uniquePkgs.stream().map(PackageMetadata::getName).collect(Collectors.toList())
        );
        
        try {
            startTime = System.currentTimeMillis();
            for (int i = 0; i < uniquePkgs.size(); i++) {
                PackageMetadata pkg = uniquePkgs.get(i);
                System.out.println("\n[" + (i + 1) + "/" + uniquePkgs.size() + "] " + 
                                 "Installing " + pkg.getName() + "-" + pkg.getVersion() + "...");
                
                Path pkgFile = Paths.get(CONFIG.REPO_DIR).resolve(pkg.getName() + "-" + pkg.getVersion() + ".spm");
                installPackage(pkg, pkgFile);
            }
            
            long elapsed = System.currentTimeMillis() - startTime;
            double speed = (totalSize / 1024.0) / (elapsed / 1000.0); // MB/s
            
            System.out.println("\nSuccessfully installed packages:");
            for (PackageMetadata pkg : uniquePkgs) {
                System.out.println("  " + pkg.getName() + "-" + pkg.getVersion());
            }
            
            System.out.println("\nTotal files: " + fileCount);
            System.out.println("Total size: " + formatSize(totalSize));
            System.out.println("Time: " + (elapsed / 1000.0) + "s");
            System.out.println("Speed: " + String.format("%.2f", speed) + " MB/s");
            
        } catch (Exception e) {
            System.out.println("\nInstallation failed: " + e.getMessage() + ", rolling back...");
            snapMgr.restoreSnapshot(snapName);
            throw new SPMException("Installation rolled back due to error");
        } finally {
            snapMgr.pruneOldSnapshots();
            fileCount = 0;
            totalSize = 0;
        }
    }
    
    public void remove(List<String> pkgNames, boolean force) throws SPMException {
        List<PackageMetadata> pkgs = new ArrayList<>();
        for (String pkgName : pkgNames) {
            PackageMetadata pkg = db.get(pkgName);
            if (pkg == null) {
                throw new SPMException("Package " + pkgName + " not installed");
            }
            pkgs.add(pkg);
        }
        
        if (!force) {
            for (PackageMetadata pkg : pkgs) {
                List<String> reverseDeps = db.getReverseDeps(pkg.getName());
                if (!reverseDeps.isEmpty()) {
                    throw new SPMException(
                        "Cannot remove " + pkg.getName() + ": required by " + String.join(", ", reverseDeps) +
                        "\nUse --force to override"
                    );
                }
            }
        }
        
        showRemovePreview(pkgs);
        
        if (!force) {
            System.out.print("\nDo you want to continue? [Y/n] ");
            Scanner scanner = new Scanner(System.in);
            String resp = scanner.nextLine().trim().toLowerCase();
            if (!resp.isEmpty() && !"y".equals(resp) && !"yes".equals(resp)) {
                System.out.println("Operation cancelled.");
                return;
            }
        }
        
        String snapName = snapMgr.createSnapshot(
            "remove-" + String.join(",", pkgNames),
            pkgs.stream().map(PackageMetadata::getName).collect(Collectors.toList())
        );
        
        try {
            startTime = System.currentTimeMillis();
            for (int i = 0; i < pkgs.size(); i++) {
                PackageMetadata pkg = pkgs.get(i);
                System.out.println("\n[" + (i + 1) + "/" + pkgs.size() + "] " + 
                                 "Removing " + pkg.getName() + "-" + pkg.getVersion() + "...");
                
                db.remove(pkg.getName());
                
                int removedCount = 0;
                long removedSize = 0;
                
                for (String filePath : pkg.getFiles()) {
                    Path absPath = CONFIG.getRootPath().resolve(filePath.startsWith("/") ? 
                        filePath.substring(1) : filePath);
                    
                    if (isProtectedPath(absPath)) {
                        continue;
                    }
                    
                    if (Files.exists(absPath)) {
                        if (Files.isRegularFile(absPath)) {
                            removedSize += Files.size(absPath);
                            removedCount++;
                            Files.delete(absPath);
                            cleanupEmptyParents(absPath.getParent());
                        } else if (Files.isDirectory(absPath)) {
                            deleteDirectory(absPath);
                            cleanupEmptyParents(absPath);
                        }
                    }
                }
                
                System.out.println("  Removed " + removedCount + " files (" + formatSize(removedSize / 1024) + ")");
            }
            
            long elapsed = System.currentTimeMillis() - startTime;
            
            System.out.println("\nSuccessfully removed packages:");
            for (PackageMetadata pkg : pkgs) {
                System.out.println("  " + pkg.getName());
            }
            
            System.out.println("\nTime: " + (elapsed / 1000.0) + "s");
            
        } catch (Exception e) {
            System.out.println("\nRemoval failed: " + e.getMessage() + ", rolling back...");
            snapMgr.restoreSnapshot(snapName);
            throw new SPMException("Removal rolled back due to error");
        } finally {
            snapMgr.pruneOldSnapshots();
        }
    }
    
    private void installPackage(PackageMetadata pkg, Path pkgFile) throws SPMException {
        checkDependencies(pkg);
        Path tempDir = verifyPackageIntegrity(pkgFile);
        installFilesFromDir(pkg, tempDir);
        db.add(pkg);
        
        // Cleanup temp directory
        try {
            deleteDirectory(tempDir);
        } catch (IOException e) {
            System.err.println("Warning: Failed to cleanup temp directory: " + e.getMessage());
        }
    }
    
    private void installFilesFromDir(PackageMetadata pkg, Path srcDir) throws SPMException {
        List<Path> members = pkg.getFiles().stream()
            .map(Paths::get)
            .collect(Collectors.toList());
        
        int totalFiles = members.size();
        int installedCount = 0;
        int skippedCount = 0;
        
        for (int i = 0; i < members.size(); i++) {
            Path relPath = members.get(i);
            Path srcPath = srcDir.resolve(relPath);
            Path destPath = CONFIG.getRootPath().resolve(relPath);
            
            if (Files.isDirectory(srcPath)) {
                try {
                    Files.createDirectories(destPath);
                } catch (IOException e) {
                    throw new SPMException("Failed to create directory: " + destPath);
                }
                continue;
            }
            
            String conflict = checkFileConflict(destPath, pkg.getName());
            if (conflict != null) {
                skippedCount++;
                continue;
            }
            
            try {
                Files.createDirectories(destPath.getParent());
                Files.copy(srcPath, destPath, StandardCopyOption.REPLACE_EXISTING);
                
                installedCount++;
                fileCount++;
                totalSize += Files.size(srcPath) / 1024;
                
                if (CONFIG.PACMAN_STYLE_PROGRESS) {
                    showPacmanProgress(i + 1, totalFiles, relPath.toString());
                }
                
            } catch (IOException e) {
                throw new SPMException("Failed to install file: " + relPath, e);
            }
        }
        
        if (skippedCount > 0) {
            System.out.println("  Skipped " + skippedCount + " files due to conflicts");
        }
        System.out.println("  Installed " + installedCount + " files");
    }
    
    private Path verifyPackageIntegrity(Path pkgFile) throws SPMException {
        Path tempDir;
        try {
            tempDir = Files.createTempDirectory(Config.getTmpPath(), "spm_");
        } catch (IOException e) {
            throw new SPMException("Failed to create temp directory", e);
        }
        
        // Extract package
        try (ZipInputStream zis = new ZipInputStream(Files.newInputStream(pkgFile))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                Path outputPath = tempDir.resolve(entry.getName());
                if (entry.isDirectory()) {
                    Files.createDirectories(outputPath);
                } else {
                    Files.createDirectories(outputPath.getParent());
                    Files.copy(zis, outputPath, StandardCopyOption.REPLACE_EXISTING);
                }
                zis.closeEntry();
            }
        } catch (IOException e) {
            throw new SPMException("Failed to extract package", e);
        }
        
        // Verify integrity
        Path sfFile = tempDir.resolve("META-INF/SPM.SF");
        if (!Files.exists(sfFile)) {
            throw new SPMException("Missing integrity metadata: META-INF/SPM.SF");
        }
        
        try {
            List<String> lines = Files.readAllLines(sfFile);
            int total = lines.size();
            for (int i = 0; i < lines.size(); i++) {
                String line = lines.get(i).trim();
                if (line.isEmpty()) continue;
                
                String[] parts = line.split("SHA256:", 2);
                if (parts.length != 2) continue;
                
                String fileRel = parts[0].trim();
                String expected = parts[1].trim();
                Path filePath = tempDir.resolve(fileRel);
                
                if (!Files.exists(filePath)) {
                    throw new SPMException("Missing file during verification: " + fileRel);
                }
                
                String actual = calculateSHA256(filePath);
                if (!actual.equals(expected)) {
                    throw new SPMException("Hash mismatch: " + fileRel);
                }
                
                showPacmanProgress(i + 1, total, fileRel);
            }
        } catch (IOException e) {
            throw new SPMException("Failed to verify package integrity", e);
        }
        
        System.out.println("  Integrity OK");
        return tempDir;
    }
    
    private String calculateSHA256(Path file) throws SPMException {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] fileBytes = Files.readAllBytes(file);
            byte[] hash = digest.digest(fileBytes);
            
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (Exception e) {
            throw new SPMException("Failed to calculate SHA256", e);
        }
    }
    
    private void showPacmanProgress(int current, int total, String filename) {
        double percent = (double) current / total;
        int barLength = 20;
        int filledLength = (int) Math.round(barLength * percent);
        
        StringBuilder bar = new StringBuilder();
        bar.append("[");
        for (int i = 0; i < barLength; i++) {
            if (i < filledLength) {
                bar.append("=");
            } else if (i == filledLength) {
                bar.append(">");
            } else {
                bar.append(" ");
            }
        }
        bar.append("]");
        
        String displayName = filename;
        if (filename.length() > 30) {
            displayName = "..." + filename.substring(filename.length() - 27);
        }
        
        System.out.print("\r  " + bar.toString());
        System.out.flush();
        
        if (current == total) {
            System.out.println();
        }
    }
    
    private String checkFileConflict(Path filePath, String installingPkg) throws SPMException {
        if (!Files.exists(filePath)) {
            return null;
        }
        
        if (Files.isDirectory(filePath)) {
            return null;
        }
        
        try {
            for (String pkgName : db.listPackages()) {
                PackageMetadata pkg = db.get(pkgName);
                String relativePath = CONFIG.getRootPath().relativize(filePath).toString();
                if (pkg.getFiles().contains(relativePath)) {
                    return pkgName;
                }
            }
        } catch (SPMException e) {
            // Ignore and return system
        }
        
        return "system (unmanaged)";
    }
    
    private void checkDependencies(PackageMetadata pkg) throws SPMException {
        for (Map.Entry<String, String> dep : pkg.getDependencies().entrySet()) {
            PackageMetadata installed = db.get(dep.getKey());
            if (installed == null) {
                throw new SPMException("Missing dependency: " + dep.getKey() + " required by " + pkg.getName());
            }
            
            if (!resolver.versionSatisfies(installed.getVersionCode(), dep.getValue())) {
                throw new SPMException(
                    "Dependency version mismatch: " + dep.getKey() + " requires " + 
                    dep.getValue() + " but found " + installed.getVersion()
                );
            }
        }
    }
    
    private void checkConflicts(PackageMetadata pkg) throws SPMException {
        for (String conflict : pkg.getConflicts()) {
            if (db.get(conflict) != null) {
                throw new SPMException("Conflicts with installed package: " + conflict);
            }
        }
    }
    
    private void showInstallPreview(List<PackageMetadata> pkgs) throws SPMException {
        System.out.println("\nPackages to install:");
        for (PackageMetadata pkg : pkgs) {
            boolean isNew = false;
            try {
                isNew = (db.get(pkg.getName()) == null);
            } catch (SPMException e) {
                // If we can't check, assume it's new
                isNew = true;
            }
            String status = isNew ? "new" : "upgrade";
            System.out.println("  " + pkg.getName() + "-" + pkg.getVersion() + " (" + status + ")");
        }
        
        long totalSize = pkgs.stream().mapToLong(PackageMetadata::getSize).sum();
        String sizeStr = formatSize(totalSize);
        
        // 修复：使用传统循环替代stream来避免lambda中的异常问题
        long newPkgs = 0;
        long upgradePkgs = 0;
        for (PackageMetadata pkg : pkgs) {
            try {
                if (db.get(pkg.getName()) == null) {
                    newPkgs++;
                } else {
                    upgradePkgs++;
                }
            } catch (SPMException e) {
                // 如果检查失败，当作新包处理
                newPkgs++;
            }
        }
        
        System.out.println("\nSummary:");
        System.out.println("  New packages: " + newPkgs);
        System.out.println("  Upgrades: " + upgradePkgs);
        System.out.println("  Total download size: " + sizeStr);
        System.out.println("  Disk space required: " + sizeStr);
    }
    
    private void showRemovePreview(List<PackageMetadata> pkgs) throws SPMException {
        System.out.println("\nPackages to remove:");
        for (PackageMetadata pkg : pkgs) {
            System.out.println("  " + pkg.getName() + "-" + pkg.getVersion());
        }
        
        long totalSize = pkgs.stream().mapToLong(PackageMetadata::getSize).sum();
        String sizeStr = formatSize(totalSize);
        
        Set<String> affected = new HashSet<>();
        for (PackageMetadata pkg : pkgs) {
            try {
                affected.addAll(db.getReverseDeps(pkg.getName()));
            } catch (SPMException e) {
                // 如果获取反向依赖失败，继续处理其他包
                System.err.println("Warning: Failed to get reverse dependencies for " + pkg.getName() + ": " + e.getMessage());
            }
        }
        
        System.out.println("\nSummary:");
        System.out.println("  Packages to remove: " + pkgs.size());
        if (!affected.isEmpty()) {
            System.out.println("  Affected packages: " + String.join(", ", affected));
        }
        System.out.println("  Disk space freed: " + sizeStr);
    }
    
    private String formatSize(long sizeKb) {
        if (sizeKb < 1024) {
            return String.format("%.1f KB", (double) sizeKb);
        } else if (sizeKb < 1024 * 1024) {
            return String.format("%.1f MB", sizeKb / 1024.0);
        } else {
            return String.format("%.1f GB", sizeKb / (1024.0 * 1024.0));
        }
    }
    
    private boolean isProtectedPath(Path path) {
        String pathStr = path.toString();
        for (String protectedPath : CONFIG.PROTECTED_PATHS) {
            if (pathStr.startsWith(protectedPath)) {
                return true;
            }
        }
        return false;
    }
    
    private void cleanupEmptyParents(Path path) throws IOException {
        Path rootPath = CONFIG.getRootPath();
        
        while (!path.equals(rootPath)) {
            if (isProtectedPath(path)) {
                break;
            }
            
            try {
                Files.delete(path);
            } catch (IOException e) {
                break; // Directory not empty or no permission
            }
            path = path.getParent();
        }
    }
    
    private void deleteDirectory(Path path) throws IOException {
        if (Files.isDirectory(path)) {
            try (DirectoryStream<Path> entries = Files.newDirectoryStream(path)) {
                for (Path entry : entries) {
                    deleteDirectory(entry);
                }
            }
        }
        Files.deleteIfExists(path);
    }
}