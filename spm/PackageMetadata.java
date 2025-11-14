package com.spm;

import java.util.*;

public class PackageMetadata {
    private String name;
    private String version;
    private int versionCode;
    private List<String> files;
    private Map<String, String> dependencies;
    private List<String> conflicts;
    private long size;
    
    public PackageMetadata(String name, String version, int versionCode) {
        this.name = name;
        this.version = version;
        this.versionCode = versionCode;
        this.files = new ArrayList<>();
        this.dependencies = new HashMap<>();
        this.conflicts = new ArrayList<>();
        this.size = 0;
    }
    
    // Getters and Setters
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getVersion() { return version; }
    public void setVersion(String version) { this.version = version; }
    
    public int getVersionCode() { return versionCode; }
    public void setVersionCode(int versionCode) { this.versionCode = versionCode; }
    
    public List<String> getFiles() { return files; }
    public void setFiles(List<String> files) { this.files = files; }
    
    public Map<String, String> getDependencies() { return dependencies; }
    public void setDependencies(Map<String, String> dependencies) { this.dependencies = dependencies; }
    
    public List<String> getConflicts() { return conflicts; }
    public void setConflicts(List<String> conflicts) { this.conflicts = conflicts; }
    
    public long getSize() { return size; }
    public void setSize(long size) { this.size = size; }
    
    public void addFile(String file) {
        this.files.add(file);
    }
    
    public void addDependency(String name, String version) {
        this.dependencies.put(name, version);
    }
    
    public void addConflict(String name) {
        this.conflicts.add(name);
    }
    
    @Override
    public String toString() {
        return String.format("%s-%s (v%d)", name, version, versionCode);
    }
}