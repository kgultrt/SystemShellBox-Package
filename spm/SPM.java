package com.spm;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.Collectors;

public class SPM {
    private static final Config CONFIG = new Config();
    
    public static void main(String[] args) {
        if (args.length == 0) {
            printUsage();
            return;
        }
        
        try {
            String command = args[0];
            String[] commandArgs = Arrays.copyOfRange(args, 1, args.length);
            
            switch (command) {
                case "install":
                    handleInstall(commandArgs);
                    break;
                case "remove":
                    handleRemove(commandArgs);
                    break;
                case "build":
                    handleBuild(commandArgs);
                    break;
                case "list":
                    handleList();
                    break;
                case "clear":
                    handleClear();
                    break;
                default:
                    System.out.println("Unknown command: " + command);
                    printUsage();
            }
        } catch (SPMException e) {
            System.err.println("Error: " + e.getMessage());
            System.exit(1);
        } catch (Exception e) {
            System.err.println("Unexpected error: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
    
    private static void printUsage() {
        System.out.println("Super Package Manager (SPM) - Version 1");
        System.out.println("Usage: java SPM <command> [options]");
        System.out.println();
        System.out.println("Commands:");
        System.out.println("  install <packages...>    Install packages");
        System.out.println("  remove <packages...>     Remove packages");
        System.out.println("  build <source> --name <name> --version <version> --versionCode <code>");
        System.out.println("                           Build a package");
        System.out.println("  list                     List installed packages");
        System.out.println("  clear                    Clear all snapshots");
    }
    
    private static void handleInstall(String[] args) throws SPMException {
        List<String> packages = new ArrayList<>();
        boolean force = false;
        
        for (int i = 0; i < args.length; i++) {
            if ("--force".equals(args[i])) {
                force = true;
            } else {
                packages.add(args[i]);
            }
        }
        
        if (packages.isEmpty()) {
            throw new SPMException("No packages specified");
        }
        
        PackageManager pm = new PackageManager();
        pm.install(packages, force);
    }
    
    private static void handleRemove(String[] args) throws SPMException {
        List<String> packages = new ArrayList<>();
        boolean force = false;
        
        for (int i = 0; i < args.length; i++) {
            if ("--force".equals(args[i])) {
                force = true;
            } else {
                packages.add(args[i]);
            }
        }
        
        if (packages.isEmpty()) {
            throw new SPMException("No packages specified");
        }
        
        PackageManager pm = new PackageManager();
        pm.remove(packages, force);
    }
    
    private static void handleBuild(String[] args) throws SPMException {
        String source = null;
        String name = null;
        String version = null;
        int versionCode = 0;
        String output = ".";
        Map<String, String> deps = new HashMap<>();
        List<String> conflicts = new ArrayList<>();
        
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--name":
                    name = args[++i];
                    break;
                case "--version":
                    version = args[++i];
                    break;
                case "--versionCode":
                    versionCode = Integer.parseInt(args[++i]);
                    break;
                case "--output":
                    output = args[++i];
                    break;
                case "--dep":
                    String dep = args[++i];
                    String[] parts = dep.split("=", 2);
                    deps.put(parts[0], parts.length > 1 ? parts[1] : "*");
                    break;
                case "--conflict":
                    conflicts.add(args[++i]);
                    break;
                default:
                    if (source == null) {
                        source = args[i];
                    }
            }
        }
        
        if (source == null || name == null || version == null) {
            throw new SPMException("Missing required arguments for build");
        }
        
        PackageMetadata meta = new PackageMetadata(name, version, versionCode);
        meta.setDependencies(deps);
        meta.setConflicts(conflicts);
        
        PackageBuilder builder = new PackageBuilder();
        builder.createPackage(source, output, meta);
    }
    
    private static void handleList() throws SPMException {
        Database db = new Database(CONFIG.DB_PATH);
        List<String> packages = db.listPackages();
        
        if (packages.isEmpty()) {
            System.out.println("No packages installed.");
            return;
        }
        
        System.out.println("Installed packages:");
        for (String pkgName : packages) {
            PackageMetadata pkg = db.get(pkgName);
            System.out.println("  " + pkg.getName() + " " + pkg.getVersion());
        }
    }
    
    private static void handleClear() throws SPMException {
        System.out.print("Are you sure you want to delete all snapshots? [y/N] ");
        Scanner scanner = new Scanner(System.in);
        String confirm = scanner.nextLine().trim().toLowerCase();
        
        if ("y".equals(confirm) || "yes".equals(confirm)) {
            SnapshotManager snapMgr = new SnapshotManager(CONFIG.SNAPSHOTS_DIR, CONFIG.MAX_SNAPSHOTS);
            snapMgr.clearAll();
            System.out.println("All snapshots cleared.");
        } else {
            System.out.println("Operation cancelled.");
        }
    }
}