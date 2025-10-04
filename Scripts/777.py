import subprocess
import shutil
import os
from pathlib import Path
import re

# Setup
repo_dir = os.getcwd()
repo_name = os.path.basename(repo_dir)
desktop_path = Path("C:/Users/Amirp/OneDrive/Desktop")  # ✅ Your actual desktop path

# Snapshot counter
counter_file = Path(repo_dir) / ".snapshot_count"
if counter_file.exists():
    with open(counter_file, "r") as f:
        count = int(f.read().strip()) + 1
else:
    count = 1

with open(counter_file, "w") as f:
    f.write(str(count))

# Create snapshot filename
zip_name = f"{repo_name}_{count}"
zip_path = desktop_path / f"{zip_name}.zip"

# Git add
subprocess.run(["git", "add", "."], check=True)

# ✅ Only commit if there are staged changes
diff_result = subprocess.run(['git', 'diff', '--cached', '--quiet'])
if diff_result.returncode == 1:  # 1 means there ARE staged changes
    commit_message = f"autopush: snapshot #{count}"
    subprocess.run(["git", "commit", "-m", commit_message], check=True)
    subprocess.run(["git", "push"], check=True)
    print(f"✅ Git pushed with commit: \"{commit_message}\"")
else:
    print("ℹ️ No staged changes. Skipping commit and push.")

# Create ZIP on Desktop
shutil.make_archive(str(desktop_path / zip_name), 'zip', repo_dir)
print(f"📦 Snapshot created: {zip_path}")

# Limit to last 3 snapshots — prune older ones
pattern = re.compile(rf"{re.escape(repo_name)}_(\d+)\.zip$")
matches = []

for file in desktop_path.glob(f"{repo_name}_*.zip"):
    match = pattern.match(file.name)
    if match:
        snapshot_num = int(match.group(1))
        matches.append((snapshot_num, file))

# Sort and prune if more than 3
matches.sort()
if len(matches) > 3:
    for _, file_to_delete in matches[:-3]:
        try:
            file_to_delete.unlink()
            print(f"🗑️ Deleted old snapshot: {file_to_delete.name}")
        except Exception as e:
            print(f"⚠️ Failed to delete {file_to_delete.name}: {e}")
