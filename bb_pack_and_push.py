#!/usr/bin/env python3

import base64
import hashlib
import hmac
import json
import subprocess
import sys
import time
import zipfile
from datetime import datetime
from email.utils import formatdate
from pathlib import Path
from urllib.parse import quote

import requests

# =========================================================
# 项目 & 环境配置
# =========================================================
GODOT_BIN = "/Applications/Godot.app/Contents/MacOS/Godot"
EXPORT_PRESET = "AndroidHello"
PROJECT_ALIAS = "godothey"
PROJECT_TAG = "godothey"
DEVICE_TYPE = "android"

PROJECT_ROOT = Path(__file__).resolve().parent
OUTPUT_DIR = PROJECT_ROOT / "docs/releases"
PRIVATE_KEY_PEM = PROJECT_ROOT / "docs/signing/private_key.pem"

# =========================================================
# 阿里云 OSS 配置
# =========================================================
TESTAID = "XXXXXXXXXXLTAI5t5bTvMz5HyN34px6G68"
TESTAKY = "XXXXXXXXXXKIb6xcnxCbnhMCsYF3bLGOGvcn6Zi8"
OSS_BUCKET = "yongit"
OSS_ENDPOINT = "oss-cn-beijing.aliyuncs.com"
OSS_BASE_URL = f"https://{OSS_BUCKET}.{OSS_ENDPOINT}"

# =========================================================
# API 服务端配置
# =========================================================
SERVER_URL = "https://apix.yongit.com/programer/create"
SERVER_SECRET_PREFIX = "ce137c47b32e37dce807756b92ccbx"

# =========================================================
# 核心业务逻辑
# =========================================================

def gen_version():
    now = datetime.now()
    return f"{now.year % 100}.{now.month * 100 + now.day}.{now.hour * 100 + now.minute}"

def build_godot(apk_path):
    print("\n" + "=" * 60 + "\nBuilding Godot...\n" + "=" * 60)
    cmd = [GODOT_BIN, "--headless", "--export-release", EXPORT_PRESET, str(apk_path)]
    p = subprocess.Popen(cmd, cwd=PROJECT_ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in p.stdout:
        print(line, end="")
    p.wait()
    if p.returncode != 0:
        raise RuntimeError("Godot export failed!")

def zip_file(src, dst):
    print("==> Compressing ZIP...")
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(src, src.name)
    print(f"✔ ZIP Done: {dst}")

def sha256_file(file_path):
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()

def sign_file_rsa(file_path):
    res = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(PRIVATE_KEY_PEM), str(file_path)],
        stdout=subprocess.PIPE, check=True
    )
    return base64.b64encode(res.stdout).decode()

def upload_to_oss(local_file, object_name, content_type="application/zip"):
    print("==> Uploading to Aliyun OSS...")
    date_str = formatdate(usegmt=True)
    clean_object_path = object_name.lstrip('/')
    canonicalized_resource = f"/{OSS_BUCKET}/{clean_object_path}"
    string_to_sign = f"PUT\n\n{content_type}\n{date_str}\n{canonicalized_resource}"

    signature = base64.b64encode(
        hmac.new(
            TESTAKY.encode('utf-8'),
            string_to_sign.encode('utf-8'),
            hashlib.sha1
        ).digest()
    ).decode('utf-8')

    headers = {
        'Authorization': f'OSS {TESTAID}:{signature}',
        'Content-Type': content_type,
        'Date': date_str,
    }

    url = f"https://{OSS_BUCKET}.{OSS_ENDPOINT}/{quote(clean_object_path)}"
    
    with open(local_file, 'rb') as f:
        resp = requests.put(url, headers=headers, data=f, timeout=120)

    if resp.status_code == 200:
        print("✔ OSS Upload OK")
        return f"{OSS_BASE_URL}/{clean_object_path}"
    else:
        raise RuntimeError(f"OSS Upload failed [{resp.status_code}]: {resp.text}")

def create_version_record(version, download_url, zip_name, sha256_hash, dist_sign, size):
    secret = SERVER_SECRET_PREFIX + datetime.now().strftime("%y%m")
    ts = str(int(time.time()))
    m1 = hashlib.md5((secret + ts).encode()).hexdigest()
    m2 = hashlib.md5(m1.encode()).hexdigest()
    token = base64.b64encode(f"{m2},{ts}".encode()).decode()

    payload = {
        "title": f"Godot Auto Build {version}",
        "intro": "",
        "project_tag": PROJECT_TAG,
        "device_type": DEVICE_TYPE,
        "version_name": version,
        "zip_url": download_url,
        "zip_name": zip_name,
        "zip_hash": sha256_hash,
        "zip_size": size,
        "dist_name": zip_name,
        "dist_size": size,
        "dist_sign": dist_sign,
        "gray_target": "testphone",
        "remark": "Auto Build",
    }
    headers = {
        "Authorization": f"Token {token}",
        "Content-Type": "application/json",
    }
    return requests.post(SERVER_URL, headers=headers, json=payload, timeout=20)

def main():
    start_time = time.time()
    version = gen_version()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Godot 导出 APK
    apk_name = f"{PROJECT_ALIAS}-{version}.apk"
    apk_path = OUTPUT_DIR / apk_name
    build_godot(apk_path)

    # 2. 压缩成 ZIP
    zip_name = f"{PROJECT_ALIAS}-{version}.zip"
    zip_path = OUTPUT_DIR / zip_name
    zip_file(apk_path, zip_path)

    # 3. 签名与哈希计算
    sha256 = sha256_file(zip_path)
    sign = sign_file_rsa(zip_path)
    size = zip_path.stat().st_size

    # 4. 上传至阿里云 OSS (原生 PUT 请求，免 SDK)
    object_path = f"{PROJECT_ALIAS}/{zip_name}"
    download_url = upload_to_oss(zip_path, object_path)

    print("\n" + "=" * 60)
    print(f"Version  : {version}")
    print(f"ZIP      : {zip_name}")
    print(f"URL      : {download_url}")
    print(f"SHA256   : {sha256}")
    print("=" * 60)

    # 5. 上报版本服务记录
    resp = create_version_record(version, download_url, zip_name, sha256, sign, size)

    print(f"\nServer Response [{resp.status_code}]:\n{resp.text}\n")
    print(f"Total Elapsed: {time.time() - start_time:.2f}s")

if __name__ == "__main__":
    main()