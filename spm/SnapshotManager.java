package com.spm;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.Collectors;

public class SnapshotManager {
    private final Path snapDir;
    private final int maxSnaps;
    
    public SnapshotManager(String snapDir, int maxSnaps) {
        this.snapDir = Paths.get(snapDir);
        this.maxSnaps = maxSnaps;
        try {
            Files.createDirectories(this.snapDir);
        } catch (IOException e) {
            throw new RuntimeException("Failed to create snapshots directory", e);
        }
    }
    
    public String createSnapshot(String operation, List<String> packages) throws SPMException {
        String timestamp = String.valueOf(System.currentTimeMillis());
        String snapName = timestamp + "-" + operation;
        Path snapPath = snapDir.resolve(snapName);
        
        try {
            Files.createDirectories(snapPath);
            
            Path stateDir = snapPath.resolve("state");
            Files.createDirectories(stateDir);
            
            // Save package list
            Path packagesFile = snapPath.resolve("packages.json");
            String packagesJson = "[\"" + String.join("\", \"", packages) + "\"]";
            Files.write(packagesFile, packagesJson.getBytes());
            
            // Backup database
            Path dbSource = Config.getDbPath();
            Path dbSnap = snapPath.resolve("db");
            if (Files.exists(dbSource)) {
                copyDirectory(dbSource, dbSnap);
            }
            
            // Backup files from packages
            Database db = new Database(Config.DB_PATH);
            for (String pkgName : packages) {
                PackageMetadata pkg = db.get(pkgName);
                if (pkg != null) {
                    for (String filePath : pkg.getFiles()) {
                        Path absPath = Config.getRootPath().resolve(filePath.startsWith("/") ? 
                            filePath.substring(1) : filePath);
                        if (Files.exists(absPath) && Files.isRegularFile(absPath)) {
                            Path destPath = stateDir.resolve(filePath);
                            Files.createDirectories(destPath.getParent());
                            Files.copy(absPath, destPath, StandardCopyOption.REPLACE_EXISTING);
                        }
                    }
                }
            }
            
            return snapName;
            
        } catch (IOException e) {
            throw new SPMException("Failed to create snapshot", e);
        }
    }
    
    public void restoreSnapshot(String snapName) throws SPMException {
        Path snapPath = snapDir.resolve(snapName);
        if (!Files.exists(snapPath)) {
            throw new SPMException("Snapshot " + snapName + " not found");
        }
        
        try {
            // Restore database
            Path dbSnap = snapPath.resolve("db");
            Path dbTarget = Config.getDbPath();
            if (Files.exists(dbSnap)) {
                if (Files.exists(dbTarget)) {
                    deleteDirectory(dbTarget);
                }
                copyDirectory(dbSnap, dbTarget);
            }
            
            // Read package list
            Path packagesFile = snapPath.resolve("packages.json");
            List<String> packages = readPackageList(packagesFile);
            
            // Clean system files
            cleanSystemFiles(packages);
            
            // Restore files
            Path stateDir = snapPath.resolve("state");
            if (Files.exists(stateDir)) {
                restoreFiles(stateDir);
            }
            
            // Remove snapshot
            deleteDirectory(snapPath);
            
        } catch (IOException e) {
            throw new SPMException("Failed to restore snapshot", e);
        }
    }
    
    public void pruneOldSnapshots() throws SPMException {
        try {
            List<Path> snaps = Files.list(snapDir)
                .sorted()
                .collect(Collectors.toList());
            
            if (snaps.size() > maxSnaps) {
                for (int i = 0; i < snaps.size() - maxSnaps; i++) {
                    deleteDirectory(snaps.get(i));
                }
            }
        } catch (IOException e) {
            throw new SPMException("Failed to prune old snapshots", e);
        }
    }
    
    public void clearAll() throws SPMException {
        try {
            if (Files.exists(snapDir)) {
                deleteDirectory(snapDir);
                Files.createDirectories(snapDir);
            }
        } catch (IOException e) {
            throw new SPMException("Failed to clear snapshots", e);
        }
    }
    
    private List<String> readPackageList(Path packagesFile) throws IOException {
        if (!Files.exists(packagesFile)) {
            return Collections.emptyList();
        }
        
        String json = new String(Files.readAllBytes(packagesFile));
        // Simple JSON array parsing
        if (json.startsWith("[") && json.endsWith("]")) {
            String content = json.substring(1, json.length() - 1);
            return Arrays.stream(content.split(","))
                .map(s -> s.trim().replace("\"", ""))
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toList());
        }
        return Collections.emptyList();
    }
    
    private void cleanSystemFiles(List<String> packages) throws SPMException {
        Database db = new Database(Config.DB_PATH);
        Config config = new Config();
        
        for (String pkgName : packages) {
            PackageMetadata pkg = db.get(pkgName);
            if (pkg != null) {
                for (String filePath : pkg.getFiles()) {
                    Path absPath = config.getRootPath().resolve(filePath.startsWith("/") ? 
                        filePath.substring(1) : filePath);
                    
                    if (isProtectedPath(absPath)) {
                        continue;
                    }
                    
                    try {
                        if (Files.exists(absPath)) {
                            if (Files.isDirectory(absPath)) {
                                deleteDirectory(absPath);
                            } else {
                                Files.delete(absPath);
                            }
                        }
                    } catch (IOException e) {
                        // Continue with other files
                        System.err.println("Warning: Failed to delete " + absPath + ": " + e.getMessage());
                    }
                }
            }
        }
    }
    
    private void restoreFiles(Path stateDir) throws IOException {
        Files.walk(stateDir)
            .filter(Files::isRegularFile)
            .forEach(source -> {
                try {
                    Path relative = stateDir.relativize(source);
                    Path target = Config.getRootPath().resolve(relative);
                    Files.createDirectories(target.getParent());
                    Files.copy(source, target, StandardCopyOption.REPLACE_EXISTING);
                } catch (IOException e) {
                    System.err.println("Warning: Failed to restore " + source + ": " + e.getMessage());
                }
            });
    }
    
    private boolean isProtectedPath(Path path) {
        String pathStr = path.toString();
        List<String> protectedPaths = Config.PROTECTED_PATHS;
        for (String protectedPath : protectedPaths) {
            if (pathStr.startsWith(protectedPath)) {
                return true;
            }
        }
        return false;
    }
    
    private void copyDirectory(Path source, Path target) throws IOException {
        Files.walk(source)
            .forEach(sourcePath -> {
                try {
                    Path targetPath = target.resolve(source.relativize(sourcePath));
                    if (Files.isDirectory(sourcePath)) {
                        Files.createDirectories(targetPath);
                    } else {
                        Files.copy(sourcePath, targetPath, StandardCopyOption.REPLACE_EXISTING);
                    }
                } catch (IOException e) {
                    throw new UncheckedIOException(e);
                }
            });
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