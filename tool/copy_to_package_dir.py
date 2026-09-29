import os
import shutil
import sys

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    release_dir = os.path.join(base_dir, "release", "1.5.1")
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
    for f in os.listdir(release_dir):
        src_path = os.path.join(release_dir, f)
        dest_path = os.path.join(target_dir, f)
        if os.path.isfile(src_path):
            shutil.copy2(src_path, dest_path)
            copied.append(f)

    print(f"Successfully copied {len(copied)} files to 'đóng gói tool': {copied}")

if __name__ == "__main__":
    main()
