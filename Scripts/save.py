import os
import shutil
import sys
import zipfile
import subprocess
from datetime import datetime

# === CONFIGURATION ===
PROJECT_NAME = "NeurospLIT"
SNAPSHOT_DIR = "./snapshots"
EXCLUDE_DIRS = {".git", "__pycache__", "DerivedData", ".build", "build", "snapshots"}
EXCLUDE_FILES = {"save.py"}

# === STEP 1: GIT PULL ===
print("[↻] Pulling latest changes from Git...")
subprocess.run(["git", "pull"], check=True)

# === STEP 2: OPTIONAL FINAL AGENT MESSAGE ===
final_message = sys.argv[1] if len(sys.argv) > 1 else None
if final_message:
    with open("last_agent_log.txt", "w", encoding="utf-8") as f:
        f.write(final_message)

# === STEP 3: CREATE SNAPSHOT ZIP ===
timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
snapshot_filename = f"{PROJECT_NAME}_snapshot_{timestamp}.zip"
snapshot_path = os.path.join(SNAPSHOT_DIR, snapshot_filename)
os.makedirs(SNAPSHOT_DIR, exist_ok=True)

def should_include(path):
    parts = path.split(os.sep)
    for part in parts:
        if part in EXCLUDE_DIRS:
            return False
    if os.path.basename(path) in EXCLUDE_FILES:
        return False
    return True

with zipfile.ZipFile(snapshot_path, "w", zipfile.ZIP_DEFLATED) as zipf:
    for foldername, subfolders, filenames in os.walk("."):
        subfolders[:] = [d for d in subfolders if should_include(os.path.join(foldername, d))]
        for filename in filenames:
            filepath = os.path.join(foldername, filename)
            if should_include(filepath):
                arcname = os.path.relpath(filepath, ".")
                zipf.write(filepath, arcname)

print(f"[✓] Snapshot saved to: {snapshot_path}")

# === STEP 4: GIT COMMIT ===
commit_msg = f"📸 Snapshot @ {timestamp}"
if final_message:
    commit_msg += f" — {final_message}"

subprocess.run(["git", "add", "."], check=True)
subprocess.run(["git", "commit", "-m", commit_msg], check=True)

# === STEP 5: GIT PUSH ===
print("[↑] Pushing to remote...")
subprocess.run(["git", "push"], check=True)

print(f"[✅] Snapshot, pull, commit, and push complete.")
