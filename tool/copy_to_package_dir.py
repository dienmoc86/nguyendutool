import json
import os
import shutil
import sys

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    version_file = os.path.join(base_dir, "VERSION.json")
    with open(version_file, "r", encoding="utf-8") as f:
        vdata = json.load(f)
    app_version = vdata.get("version", "1.7.3")

    release_dir = os.path.join(base_dir, "release", app_version)
    target_dir = os.path.join(base_dir, "đóng gói tool")

    # Clean any mojibake directories from earlier PowerShell encoding issues
    for item in os.listdir(base_dir):
        full_item = os.path.join(base_dir, item)
        if os.path.isdir(full_item) and "Ä" in item:
            try:
                shutil.rmtree(full_item)
                print(f"Cleaned mojibake folder: {item}")
            except Exception as e:
                print(f"Warning cleaning {item}: {e}")

    os.makedirs(target_dir, exist_ok=True)
    if not os.path.exists(release_dir):
        print(f"Error: {release_dir} does not exist")
        sys.exit(1)

    copied = []
    # 1. Copy all packaged release files (Installer EXE, Portable ZIP, SHA256 files, SHA256SUMS.txt)
    for f in os.listdir(release_dir):
        src_path = os.path.join(release_dir, f)
        dest_path = os.path.join(target_dir, f)
        if os.path.isfile(src_path):
            try:
                shutil.copy2(src_path, dest_path)
                copied.append(f)
            except Exception as e:
                print(f"Notice: could not copy {f} (may be in use): {e}")

    # 2. Copy loose release binaries so user can run immediately from "đóng gói tool" without setup
    build_release = os.path.join(base_dir, "build", "windows", "x64", "runner", "Release")
    if os.path.exists(build_release):
        for item in os.listdir(build_release):
            src_item = os.path.join(build_release, item)
            dest_item = os.path.join(target_dir, item)
            if os.path.isfile(src_item):
                try:
                    shutil.copy2(src_item, dest_item)
                    copied.append(item)
                except Exception as e:
                    print(f"Notice: could not copy {item} (may be in use): {e}")
            elif os.path.isdir(src_item):
                try:
                    if os.path.exists(dest_item):
                        shutil.rmtree(dest_item)
                    shutil.copytree(src_item, dest_item)
                    copied.append(item)
                except Exception as e:
                    print(f"Notice: could not copy directory {item}: {e}")

    # 3. Copy bin/ directory (ffmpeg, edge_tts_runner, dlls)
    bin_dir = os.path.join(base_dir, "bin")
    if os.path.exists(bin_dir):
        dest_bin = os.path.join(target_dir, "bin")
        try:
            if os.path.exists(dest_bin):
                shutil.rmtree(dest_bin)
            shutil.copytree(bin_dir, dest_bin)
            copied.append("bin")
        except Exception as e:
            print(f"Notice: could not sync bin directory: {e}")

    print(f"Successfully processed items to 'đóng gói tool': {copied}")

if __name__ == "__main__":
    main()
