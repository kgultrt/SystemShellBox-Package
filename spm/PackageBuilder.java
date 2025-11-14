package com.spm;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.zip.*;
import java.security.*;

public class PackageBuilder {
    private final Config CONFIG = new Config();
    private Path buildDir;
    
    public PackageBuilder() {
        this.buildDir = Paths.get(CONFIG.BUILD_DIR);
        cleanupBuildDir();
    }
    
    public void createPackage(String sourceDir, String outputDir, PackageMetadata meta) throws SPMException {
        Path sourcePath = Paths.get(sourceDir);
        Path outputPath = Paths.get(outputDir);
        String pkgFilename = meta.getName() + "-" + meta.getVersion() + ".spm";
        Path pkgFile = outputPath.resolve(pkgFilename);
        
        try {
            // Copy source to build directory
            copySource(sourcePath);
            
            // Collect files and calculate size
            List<String> fileList = new ArrayList<>();
            long totalSize = 0;
            int fileCount = 0;
            
            Files.walk(buildDir)
                .forEach(path -> {
                    if (Files.isRegularFile(path)) {
                        Path relative = buildDir.relativize(path);
                        fileList.add(relative.toString());
                    }
                });
            
            // Calculate file sizes
            for (String file : fileList) {
                Path filePath = buildDir.resolve(file);
                try {
                    totalSize += Files.size(filePath);
                    fileCount++;
                } catch (IOException e) {
                    throw new UncheckedIOException(e);
                }
            }
            
            meta.setFiles(fileList);
            meta.setSize(totalSize / 1024); // Convert to KB
            
            // Create package.json
            Path metaFile = buildDir.resolve("package.json");
            writePackageMetadata(metaFile, meta);
            
            // Create META-INF directory
            Path metaInfDir = buildDir.resolve("META-INF");
            Files.createDirectories(metaInfDir);
            
            // Create integrity manifest
            Path sfFile = metaInfDir.resolve("SPM.SF");
            createIntegrityManifest(sfFile, fileList);
            
            // Create the package file
            createPackageArchive(pkgFile);
            
            System.out.println("\nPackage created: " + pkgFile);
            System.out.println("  Files: " + fileCount);
            System.out.println("  Size: " + formatSize(totalSize / 1024));
            
        } catch (IOException e) {
            throw new SPMException("Failed to create package", e);
        } finally {
            cleanupBuildDir();
        }
    }
    
    private void copySource(Path sourceDir) throws IOException {
        if (!Files.exists(sourceDir)) {
            throw new IOException("Source directory does not exist: " + sourceDir);
        }
        
        Files.walk(sourceDir)
            .forEach(source -> {
                try {
                    Path relative = sourceDir.relativize(source);
                    if (shouldIgnore(relative)) {
                        return;
                    }
                    
                    Path target = buildDir.resolve(relative);
                    if (Files.isDirectory(source)) {
                        Files.createDirectories(target);
                    } else {
                        Files.copy(source, target, StandardCopyOption.REPLACE_EXISTING);
                    }
                } catch (IOException e) {
                    throw new UncheckedIOException(e);
                }
            });
    }
    
    private boolean shouldIgnore(Path path) {
        String filename = path.getFileName().toString();
        return filename.equals(".git") || 
               filename.equals("build") || 
               filename.equals(".gitignore") ||
               path.toString().contains("/.git/");
    }
    
    private void writePackageMetadata(Path metaFile, PackageMetadata meta) throws IOException {
        StringBuilder sb = new StringBuilder();
        sb.append("{\n");
        sb.append("  \"name\": \"").append(meta.getName()).append("\",\n");
        sb.append("  \"version\": \"").append(meta.getVersion()).append("\",\n");
        sb.append("  \"versionCode\": ").append(meta.getVersionCode()).append(",\n");
        sb.append("  \"files\": ").append(listToJson(meta.getFiles())).append(",\n");
        sb.append("  \"dependencies\": ").append(mapToJson(meta.getDependencies())).append(",\n");
        sb.append("  \"conflicts\": ").append(listToJson(meta.getConflicts())).append(",\n");
        sb.append("  \"size\": ").append(meta.getSize()).append("\n");
        sb.append("}");
        
        Files.write(metaFile, sb.toString().getBytes());
    }
    
    private void createIntegrityManifest(Path sfFile, List<String> fileList) throws SPMException, IOException {
        StringBuilder sb = new StringBuilder();
        
        for (String file : fileList) {
            Path filePath = buildDir.resolve(file);
            String sha256 = calculateSHA256(filePath);
            sb.append(file).append(" SHA256: ").append(sha256).append("\n");
        }
        
        Files.write(sfFile, sb.toString().getBytes());
    }
    
    private void createPackageArchive(Path pkgFile) throws IOException {
        try (ZipOutputStream zos = new ZipOutputStream(Files.newOutputStream(pkgFile))) {
            Files.walk(buildDir)
                .forEach(path -> {
                    try {
                        if (Files.isDirectory(path)) {
                            return;
                        }
                        
                        Path relative = buildDir.relativize(path);
                        ZipEntry entry = new ZipEntry(relative.toString());
                        zos.putNextEntry(entry);
                        
                        Files.copy(path, zos);
                        zos.closeEntry();
                        
                    } catch (IOException e) {
                        throw new UncheckedIOException(e);
                    }
                });
        }
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
    
    private String listToJson(List<String> list) {
        if (list == null || list.isEmpty()) {
            return "[]";
        }
        return "[\"" + String.join("\", \"", list) + "\"]";
    }
    
    private String mapToJson(Map<String, String> map) {
        if (map == null || map.isEmpty()) {
            return "{}";
        }
        StringBuilder sb = new StringBuilder();
        sb.append("{");
        boolean first = true;
        for (Map.Entry<String, String> entry : map.entrySet()) {
            if (!first) sb.append(", ");
            sb.append("\"").append(entry.getKey()).append("\": \"").append(entry.getValue()).append("\"");
            first = false;
        }
        sb.append("}");
        return sb.toString();
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
    
    private void cleanupBuildDir() {
        try {
            if (Files.exists(buildDir)) {
                deleteDirectory(buildDir);
            }
            Files.createDirectories(buildDir);
        } catch (IOException e) {
            throw new RuntimeException("Failed to cleanup build directory", e);
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