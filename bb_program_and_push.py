#!/usr/bin/env python3

import os,sys
import base64
import hashlib
import hmac
import json
import subprocess
import time
import zipfile
from datetime import datetime
from email.utils import formatdate
from pathlib import Path
from urllib.parse import quote
import re

import requests

# =========================================================
# 项目 & 环境配置
# =========================================================
GODOT_BIN = "/Applications/Godot.app/Contents/MacOS/Godot"
EXPORT_PRESET = "AndroidHello"
PROJECT_ALIAS = "godothey"
PROJECT_TAG = "godothey"
DEVICE_TYPE = "android"
# BUILDED_CLIENT_UUID = "e3748630-3877-4f5e-a4db-91a5cd90bf42"
BUILDED_CLIENT_UUID = ""

PROJECT_ROOT = Path(__file__).resolve().parent
PROGRAM_ROOT = os.path.join(PROJECT_ROOT, "project")
OUTPUT_DIR = PROJECT_ROOT / "docs/releases"
PRIVATE_KEY_PEM = PROJECT_ROOT / "docs/signing/private_key.pem"

# =========================================================
# 阿里云 OSS 配置
# =========================================================
OSS_ACCID = "XXXXXXXXXXLTAI5t5bTvMz5HyN34px6G68".strip('XXXXXXXXXX')
OSS_ACCKEY = "XXXXXXXXXXKIb6xcnxCbnhMCsYF3bLGOGvcn6Zi8".strip('XXXXXXXXXX')
OSS_BUCKET = "yongit"
OSS_ENDPOINT = "oss-cn-beijing.aliyuncs.com"
OSS_BASE_URL = f"https://{OSS_BUCKET}.{OSS_ENDPOINT}"

# =========================================================
# API 服务端配置
# =========================================================
SERVER_BASE_URL = "https://apix.yongit.com"
SERVER_SECRET_PREFIX = "ce137c47b32e37dce807756b92ccbx"

# =========================================================
# 核心业务逻辑
# =========================================================

def get_version_name():
    now = datetime.now()
    major = int(now.year - 2025)*1
    minor = int(now.month*100 + now.day)*1
    patch = int(now.hour * 10 + now.minute//6)*1
    return f"{major}.{minor}.{patch}"

def get_version_code(version_name):
    parts = version_name.split(".")
    if len(parts) != 3:
        raise ValueError("Invalid version name format")
    return int(parts[0]) * 10000000 + int(parts[1]) * 1000 + int(parts[2])


def update_project_godot(version_name):
    file = PROJECT_ROOT / "project.godot"
    content = file.read_text(encoding="utf-8")
    if re.search(r'config/version=".*?"', content):
        content = re.sub(r'config/version=".*?"', f'config/version="{version_name}"', content)
    else:
        content += ("\n[application]\n"f'config/version="{version_name}"\n')
    file.write_text(content, encoding="utf-8")


def update_export_presets(version_name, version_code):
    file = PROJECT_ROOT / "export_presets.cfg"
    content = file.read_text(encoding="utf-8")
    content = re.sub(r'version/code=\d+', f'version/code={version_code}', content)
    content = re.sub(r'version/name=".*?"', f'version/name="{version_name}"', content)
    file.write_text(content, encoding="utf-8")


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
            OSS_ACCKEY.encode('utf-8'),
            string_to_sign.encode('utf-8'),
            hashlib.sha1
        ).digest()
    ).decode('utf-8')

    headers = {
        'Authorization': f'OSS {OSS_ACCID}:{signature}',
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

def check_version_cangen(versionName) -> bool:
    payload = {
        "project_tag": PROJECT_TAG,
        "device_type": DEVICE_TYPE,
        "version_name": versionName,
    }
    code,data,msg,rid = httppost("/programer/cangen",payload)
    return code == 200

def create_version_record(versionName, zipInfo, distInfo):
    payload = {
        "title": f"Godot Auto Build {versionName}",
        "intro": "",
        "project_tag": PROJECT_TAG,
        "device_type": DEVICE_TYPE,
        "version_name": versionName,

        "zip_url": zipInfo["url"],
        "zip_name": zipInfo["name"],
        "zip_hash": zipInfo["sha256"],
        "zip_size": zipInfo["size"],

        "dist_url": distInfo["url"],
        "dist_name": distInfo["name"],
        "dist_size": distInfo["size"],
        "dist_sign": distInfo["sign"],

        "gray_target": BUILDED_CLIENT_UUID,
        "remark": "Auto Build",
    }
    return httppost("/programer/create", payload)


def httppost(path, data, headers=None):
    secret = SERVER_SECRET_PREFIX + datetime.now().strftime("%y%m")
    ts = str(int(time.time()))
    m1 = hashlib.md5((secret + ts).encode()).hexdigest()
    m2 = hashlib.md5(m1.encode()).hexdigest()
    token = base64.b64encode(f"{m2},{ts}".encode()).decode()
    headerNew = {
        "Authorization": f"Token {token}",
        "Content-Type": "application/json",
    }

    url = SERVER_BASE_URL + path
    headers = headers.update(headerNew) if headers else headerNew
    resp = requests.post(url, json=data, headers=headers, timeout=20)
    if resp.status_code != 200:
        return resp.status_code, {}, resp.text, resp.headers.get("X-Request-ID", "")
    
    try:
        code = resp.json().get("code", 666)
        data = resp.json().get("data", {})
        msg = resp.json().get("msg", "")
        rid = resp.json().get("msg", "")
    except json.JSONDecodeError:
        return resp.status_code, {}, "Invalid JSON response", resp.headers.get("X-Request-ID", "")
    return code, data, msg, rid


def main():
    versionName = get_version_name()
    versionCode = get_version_code(versionName)

    # 检查服务器是否允许当前project_tag-device_type-version_name的版本上报
    # 这里可以添加一个请求到服务器的检查逻辑，如果不允许，则直接退出
    if not check_version_cangen(versionName):
        print(f"Version {versionName} is not valid for upload. Exiting.")
        sys.exit(1)


    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    update_project_godot(versionName)
    update_export_presets(versionName, versionCode)


    # 1. Godot 导出 APK
    distName = f"{PROJECT_ALIAS}-{versionName}.apk"
    distPath = OUTPUT_DIR / distName
    print(f"Exporting Godot APK to: {distPath}")
    build_godot(distPath)

    # 2. 压缩成 ZIP
    zipName = f"{PROJECT_ALIAS}-{versionName}.zip"
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
    print(f"Version  : {versionName} (Code: {versionCode})")
    print(f"ZIP      : {zipName}")
    print(f"ZIP URL  : {downloadZipUrl}")
    print(f"SHA256   : {sha256}")
    print("=" * 60)

    # 5. 上报版本服务记录
    code, data, msg, rid = create_version_record(versionName, zipInfo={
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
    print(f"Create Version Record: code={code}, msg={msg}, rid={rid}")


if __name__ == "__main__":
    startTimestamp = time.time()

    # versionName = get_version_name()
    # print(f"Version Name: {versionName}, Version Code: {get_version_code(versionName)}")
    # print(60//6)
    main()

    print(f"Total Elapsed: {time.time() - startTimestamp:.2f}s")