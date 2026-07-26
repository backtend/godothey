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
TESTAID = "XXXXXXXXXXLTAI5t5bTvMz5HyN34px6G68".strip('XXXXXXXXXX')
TESTAKY = "XXXXXXXXXXKIb6xcnxCbnhMCsYF3bLGOGvcn6Zi8".strip('XXXXXXXXXX')
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

def upload_to_oss(localFile, objectName, contentType="application/zip"):
    print("==> Uploading to Aliyun OSS...")
    date_str = formatdate(usegmt=True)
    clean_object_path = objectName.lstrip('/')
    canonicalized_resource = f"/{OSS_BUCKET}/{clean_object_path}"
    string_to_sign = f"PUT\n\n{contentType}\n{date_str}\n{canonicalized_resource}"

    signature = base64.b64encode(
        hmac.new(
            TESTAKY.encode('utf-8'),
            string_to_sign.encode('utf-8'),
            hashlib.sha1
        ).digest()
    ).decode('utf-8')

    headers = {
        'Authorization': f'OSS {TESTAID}:{signature}',
        'Content-Type': contentType,
        'Date': date_str,
    }

    url = f"https://{OSS_BUCKET}.{OSS_ENDPOINT}/{quote(clean_object_path)}"
    
    with open(localFile, 'rb') as f:
        resp = requests.put(url, headers=headers, data=f, timeout=120)

    if resp.status_code == 200:
        print("✔ OSS Upload OK")
        return f"{OSS_BASE_URL}/{clean_object_path}"
    else:
        raise RuntimeError(f"OSS Upload failed [{resp.status_code}]: {resp.text}")

def create_version_record(version, zipInfo, distInfo):
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

        "zip_url": zipInfo["url"],
        "zip_name": zipInfo["name"],
        "zip_hash": zipInfo["sha256"],
        "zip_size": zipInfo["size"],

        "dist_url": distInfo["url"],
        "dist_name": distInfo["name"],
        "dist_size": distInfo["size"],
        "dist_sign": distInfo["sign"],

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
    distName = f"{PROJECT_ALIAS}-{version}.apk"
    distPath = OUTPUT_DIR / distName
    build_godot(distPath)

    # 2. 压缩成 ZIP
    zipName = f"{PROJECT_ALIAS}-{version}.zip"
    zipPath = OUTPUT_DIR / zipName
    zip_file(distPath, zipPath)

    # 3. 签名与哈希计算
    sha256 = sha256_file(zipPath)
    distSign = sign_file_rsa(distPath)
    zipSize = zipPath.stat().st_size
    distSize = distPath.stat().st_size

    # 4. 上传至阿里云 OSS (原生 PUT 请求，免 SDK)
    print("=" * 60)
    print("Uploading zip to OSS:{}".format(zipName))
    objectZipFull = f"{PROJECT_ALIAS}/{zipName}"
    downloadZipUrl = upload_to_oss(zipPath, objectZipFull)

    downloadDistUrl = 'https://baidu.com/app.apk'
    if True:
        objectDistFull = f"{PROJECT_ALIAS}/{distName}"
        print(f"Uploading APK to OSS: {objectDistFull}")
        downloadDistUrl = upload_to_oss(distPath, objectDistFull, contentType="application/vnd.android.package-archive")
        print(f"APK Download URL: {downloadDistUrl}")

    print("\n" + "=" * 60)
    print(f"Version  : {version}")
    print(f"ZIP      : {zipName}")
    print(f"ZIP URL  : {downloadZipUrl}")
    print(f"SHA256   : {sha256}")
    print("=" * 60)

    # 5. 上报版本服务记录
    resp = create_version_record(version, zipInfo={
        "url": downloadZipUrl,
        "name":zipName,
        "sha256":sha256,
        "size":zipSize,
    },distInfo={
        "url": downloadDistUrl,
        "name":distName,
        "sign":distSign,
        "size":distSize,
    })

    print(f"\nServer Response [{resp.status_code}]:\n{resp.text}\n")
    print(f"Total Elapsed: {time.time() - start_time:.2f}s")

if __name__ == "__main__":
    main()