package com.spm;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.List;

public class Config {
    public static final String ROOT = "/data/data/com.manager.ssb/files/usr/";
    public static final String DB_PATH = "/data/data/com.manager.ssb/files/usr/etc/spm/db";
    public static final String TMP_PATH = "/data/data/com.manager.ssb/files/usr/tmp/spm";
    public static final String SNAPSHOTS_DIR = "/data/data/com.manager.ssb/files/usr/tmp/spm/snaps";
    public static final String PKG_CACHE = "/data/data/com.manager.ssb/files/usr/tmp/spm/cache/pkg";
    public static final String REPO_DIR = "/data/data/com.manager.ssb/files/usr/home/repo";
    public static final String CONFIG_DIR = "/data/data/com.manager.ssb/files/usr/etc/spm";
    public static final String REPO_CONFIG = "/data/data/com.manager.ssb/files/usr/etc/spm/repos.json";
    public static final int MAX_SNAPSHOTS = 10;
    public static final String BUILD_DIR = "./spm_build";
    
    public static final List<String> PROTECTED_PATHS = Arrays.asList(
        "/dev", "/proc", "/sys", "/run"
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