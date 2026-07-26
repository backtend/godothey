#!/usr/bin/env python3

import datetime
import pathlib
import subprocess
import sys
import time

# ----------------------------
# 配置
# ----------------------------

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"

EXPORT_PRESET = "AndroidHello"

OUTPUT_DIR = pathlib.Path("docs/releases")

PROJECT_ROOT = pathlib.Path(__file__).parent


# ----------------------------
# 版本号
# ----------------------------

def gen_version():
    now = datetime.datetime.now()
    return f"{now.year % 100}.{now.month * 100 + now.day}.{now.hour * 100 + now.minute}"


# ----------------------------
# 主程序
# ----------------------------

def main():
    version = gen_version()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    apk_name = f"godothey-{version}.apk"
    apk_path = OUTPUT_DIR / apk_name

    cmd = [
        GODOT,
        "--headless",
        "--export-release",
        EXPORT_PRESET,
        str(apk_path),
    ]

    print("=" * 70)
    print("🚀 Godot Android Build")
    print("=" * 70)
    print(f"Version : {version}")
    print(f"Preset  : {EXPORT_PRESET}")
    print(f"Output  : {apk_path}")
    print(f"Project : {PROJECT_ROOT}")
    print()

    print("Executing:")
    print(" ".join(cmd))
    print("=" * 70)

    start = time.time()

    process = subprocess.Popen(
        cmd,
        cwd=PROJECT_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    for line in process.stdout:
        print(line, end="")

    process.wait()

    elapsed = time.time() - start

    print()
    print("=" * 70)

    if process.returncode == 0:
        print("✅ Build Success")
        print(f"APK     : {apk_path.resolve()}")
        print(f"Elapsed : {elapsed:.2f}s")
    else:
        print("❌ Build Failed")
        print(f"ExitCode: {process.returncode}")
        sys.exit(process.returncode)


if __name__ == "__main__":
    main()