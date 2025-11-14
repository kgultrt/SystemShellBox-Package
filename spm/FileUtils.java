package com.spm;

import java.io.*;
import java.nio.file.*;
import java.util.*;

public class FileUtils {
    
    public static void copyDirectory(Path source, Path target) throws IOException {
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
    
    public static void deleteDirectory(Path path) throws IOException {
        if (Files.isDirectory(path)) {
            try (DirectoryStream<Path> entries = Files.newDirectoryStream(path)) {
                for (Path entry : entries) {
                    deleteDirectory(entry);
                }
            }
        }
        Files.deleteIfExists(path);
    }
    
    public static void createDirectories(Path path) throws IOException {
        Files.createDirectories(path);
    }
    
    public static boolean isProtectedPath(Path path, List<String> protectedPaths) {
        String pathStr = path.toString();
        for (String protectedPath : protectedPaths) {
            if (pathStr.startsWith(protectedPath)) {
                return true;
            }
        }
        return false;
    }
    
    public static List<Path> findFiles(Path dir, String pattern) throws IOException {
        List<Path> result = new ArrayList<>();
        Files.walk(dir)
            .filter(path -> path.getFileName().toString().matches(pattern))
            .forEach(result::add);
        return result;
    }
    
    public static long calculateDirectorySize(Path dir) throws IOException {
        final long[] size = {0};
        Files.walk(dir)
            .filter(Files::isRegularFile)
            .forEach(path -> {
                try {
                    size[0] += Files.size(path);
                } catch (IOException e) {
                    throw new UncheckedIOException(e);
                }
            });
        return size[0];
    }
}