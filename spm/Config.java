package com.spm;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.List;

public class Config {
    public static final String ROOT = "./";
    public static final String DB_PATH = "./var/lib/spm/db";
    public static final String TMP_PATH = "./tmp";
    public static final String SNAPSHOTS_DIR = "./var/lib/spm/snaps";
    public static final String PKG_CACHE = "./var/cache/spm/pkg";
    public static final String REPO_DIR = "./repo";
    public static final String CONFIG_DIR = "./etc/spm";
    public static final String REPO_CONFIG = "./etc/spm/repos.json";
    public static final int MAX_SNAPSHOTS = 10;
    public static final String BUILD_DIR = "./spm_build";
    
    public static final List<String> PROTECTED_PATHS = Arrays.asList(
        "./dev", "./proc", "./sys", "./run"
    );
    
    public final boolean PACMAN_STYLE_PROGRESS = true;
    
    public static Path getRootPath() {
        return Paths.get(ROOT);
    }
    
    public static Path getDbPath() {
        return Paths.get(DB_PATH);
    }
    
    public static Path getTmpPath() {
        return Paths.get(TMP_PATH);
    }
    
    public static Path getSnapshotsPath() {
        return Paths.get(SNAPSHOTS_DIR);
    }
    
    public static Path getRepoPath() {
        return Paths.get(REPO_DIR);
    }
}