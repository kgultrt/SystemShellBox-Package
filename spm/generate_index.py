# generate_index.py

import json
import tarfile
import hashlib
from pathlib import Path

def compute_sha256(file_path):
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while True:
            chunk = f.read(8192)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def extract_metadata(spm_file):
    with tarfile.open(spm_file, "r:gz") as tar:
        try:
            member = tar.getmember("package.json")
            f = tar.extractfile(member)
            data = json.load(f)
            return data
        except KeyError:
            print(f"[WARN] {spm_file} missing package.json")
            return None

def generate_index_for_repo(repo_dir):
    index = {}
    for pkg_file in Path(repo_dir).glob("*.spm"):
        meta = extract_metadata(pkg_file)
        if not meta:
            continue

        filename = pkg_file.name
        size = pkg_file.stat().st_size
        sha256 = compute_sha256(pkg_file)

        meta_entry = {
            "version": meta["version"],
            "versionCode": meta.get("versionCode", 0),
            "filename": filename,
            "size": size,
            "sha256": sha256
        }

        index[meta["name"]] = meta_entry
        print(f"[OK] {meta['name']} -> {filename}")

    index_path = Path(repo_dir) / "index.json"
    with open(index_path, "w") as f:
        json.dump(index, f, indent=2)
    print(f"[DONE] Wrote index to {index_path}")

def generate_all():
    base_dir = Path(__file__).resolve().parent / "repo"
    for subdir in base_dir.iterdir():
        if subdir.is_dir():
            print(f"\n== Generating index for {subdir} ==")
            generate_index_for_repo(subdir)

if __name__ == "__main__":
    generate_all()