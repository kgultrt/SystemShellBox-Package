package com.spm;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.Collectors;

public class Database {
    private final Path dbPath;
    
    public Database(String dbPath) {
        this.dbPath = Paths.get(dbPath);
        try {
            Files.createDirectories(this.dbPath);
        } catch (IOException e) {
            throw new RuntimeException("Failed to create database directory", e);
        }
    }
    
    private Path getPackagePath(String pkgName) {
        return dbPath.resolve(pkgName + ".json");
    }
    
    public void add(PackageMetadata pkg) throws SPMException {
        try {
            String json = toJson(pkg);
            Files.write(getPackagePath(pkg.getName()), json.getBytes());
        } catch (IOException e) {
            throw new SPMException("Failed to add package to database", e);
        }
    }
    
    public void remove(String pkgName) throws SPMException {
        try {
            Files.deleteIfExists(getPackagePath(pkgName));
        } catch (IOException e) {
            throw new SPMException("Failed to remove package from database", e);
        }
    }
    
    public PackageMetadata get(String pkgName) throws SPMException {
        Path path = getPackagePath(pkgName);
        if (!Files.exists(path)) {
            return null;
        }
        
        try {
            String json = new String(Files.readAllBytes(path));
            return fromJson(json);
        } catch (IOException e) {
            throw new SPMException("Failed to read package from database", e);
        }
    }
    
    public List<String> listPackages() throws SPMException {
        try {
            return Files.list(dbPath)
                .filter(path -> path.toString().endsWith(".json"))
                .map(path -> path.getFileName().toString().replace(".json", ""))
                .collect(Collectors.toList());
        } catch (IOException e) {
            throw new SPMException("Failed to list packages", e);
        }
    }
    
    public List<String> getReverseDeps(String pkgName) throws SPMException {
        List<String> reverseDeps = new ArrayList<>();
        for (String pkg : listPackages()) {
            PackageMetadata pkgData = get(pkg);
            if (pkgData.getDependencies().containsKey(pkgName)) {
                reverseDeps.add(pkg);
            }
        }
        return reverseDeps;
    }
    
    // Simple JSON serialization
    private String toJson(PackageMetadata pkg) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\n");
        sb.append("  \"name\": \"").append(pkg.getName()).append("\",\n");
        sb.append("  \"version\": \"").append(pkg.getVersion()).append("\",\n");
        sb.append("  \"versionCode\": ").append(pkg.getVersionCode()).append(",\n");
        sb.append("  \"files\": ").append(listToJson(pkg.getFiles())).append(",\n");
        sb.append("  \"dependencies\": ").append(mapToJson(pkg.getDependencies())).append(",\n");
        sb.append("  \"conflicts\": ").append(listToJson(pkg.getConflicts())).append(",\n");
        sb.append("  \"size\": ").append(pkg.getSize()).append("\n");
        sb.append("}");
        return sb.toString();
    }
    
    private PackageMetadata fromJson(String json) {
        // Simple JSON parsing - for production use a proper JSON library
        String name = extractString(json, "name");
        String version = extractString(json, "version");
        int versionCode = extractInt(json, "versionCode");
        
        PackageMetadata pkg = new PackageMetadata(name, version, versionCode);
        
        // Parse files array
        List<String> files = extractStringList(json, "files");
        pkg.setFiles(files);
        
        // Parse dependencies object
        Map<String, String> deps = extractStringMap(json, "dependencies");
        pkg.setDependencies(deps);
        
        // Parse conflicts array
        List<String> conflicts = extractStringList(json, "conflicts");
        pkg.setConflicts(conflicts);
        
        pkg.setSize(extractLong(json, "size"));
        
        return pkg;
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
    
    private String extractString(String json, String field) {
        String pattern = "\"" + field + "\":\\s*\"([^\"]+)\"";
        java.util.regex.Pattern p = java.util.regex.Pattern.compile(pattern);
        java.util.regex.Matcher m = p.matcher(json);
        if (m.find()) {
            return m.group(1);
        }
        return "";
    }
    
    private int extractInt(String json, String field) {
        String pattern = "\"" + field + "\":\\s*(\\d+)";
        java.util.regex.Pattern p = java.util.regex.Pattern.compile(pattern);
        java.util.regex.Matcher m = p.matcher(json);
        if (m.find()) {
            return Integer.parseInt(m.group(1));
        }
        return 0;
    }
    
    private long extractLong(String json, String field) {
        String pattern = "\"" + field + "\":\\s*(\\d+)";
        java.util.regex.Pattern p = java.util.regex.Pattern.compile(pattern);
        java.util.regex.Matcher m = p.matcher(json);
        if (m.find()) {
            return Long.parseLong(m.group(1));
        }
        return 0;
    }
    
    private List<String> extractStringList(String json, String field) {
        List<String> result = new ArrayList<>();
        String pattern = "\"" + field + "\":\\s*\\[([^\\]]+)\\]";
        java.util.regex.Pattern p = java.util.regex.Pattern.compile(pattern);
        java.util.regex.Matcher m = p.matcher(json);
        if (m.find()) {
            String content = m.group(1);
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
    
    private Map<String, String> extractStringMap(String json, String field) {
        Map<String, String> result = new HashMap<>();
        String pattern = "\"" + field + "\":\\s*\\{([^}]+)\\}";
        java.util.regex.Pattern p = java.util.regex.Pattern.compile(pattern);
        java.util.regex.Matcher m = p.matcher(json);
        if (m.find()) {
            String content = m.group(1);
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