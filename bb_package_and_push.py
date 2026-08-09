#!/usr/bin/env python3

import os,sys
import base64
import hashlib
import hmac
import json
import subprocess
import time
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
PROJECT_ALIAS = "godothey"
PROJECT_TAG = "godothey"
DEVICE_TYPE = "android"
BUILDED_CLIENT_UUID = ""

SPACE_ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = SPACE_ROOT / "project"
OUTPUT_PATH = SPACE_ROOT / "docs/releases"
PRIVATE_KEY_PEM = os.path.join(SPACE_ROOT, "docs/signing/private_key.pem")

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
SERVER_BASE_URL = "https://godot.yongit.com"
SERVER_BASE_MDT = "a2ae121c048ed7d04126fe41a687a141"

# =========================================================
# 核心业务逻辑
# =========================================================

def get_cmd_version_name():
    now = datetime.now()
    major = int(now.year - 2000)*1
    minor = int(now.month*100 + now.day)*1
    patch = int(now.hour * 100 + now.minute)*1
    return f"{major}.{minor}.{patch}"

def get_cmd_version_code(version_name):
    parts = version_name.split(".")
    if len(parts) != 3:
        raise ValueError("Invalid version name format")
    return int(parts[0]) * 100000000 + int(parts[1]) * 10000 + int(parts[2])


def build_godot_pck(preset, pckPath):
    """使用 Godot 直接导出 PCK 包（不再导出/签名 APK）"""
    print("\n" + "=" * 60 + "\nBuilding Godot PCK...\n" + "=" * 60)
    cmd = [GODOT_BIN, "--headless", "--export-pack", preset, str(pckPath)]
    p = subprocess.Popen(cmd, cwd=PROJECT_ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in p.stdout:
        print(line, end="")
    p.wait()
    if p.returncode != 0:
        raise RuntimeError("Godot export-pack failed!")

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

def upload_to_oss(localFile, objectName, contentType="application/octet-stream"):
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

def check_submit_allow(versionName, sha256:str=None) -> bool:
    payload = {
        "project_tag": PROJECT_TAG,
        "device_type": DEVICE_TYPE,
        "version_name": versionName,
        "hash": sha256,
    }
    return httppost("/zzmdt/builded/allowpck", payload)

def create_pck_record(versionName, pckInfo):
    payload = {
        "title": f"Godot Auto Build {versionName}",
        "intro": "",
        "project_tag": PROJECT_TAG,
        "device_type": DEVICE_TYPE,
        "version_name": versionName,

        "pck_url": pckInfo["url"],
        "pck_name": pckInfo["name"],
        "pck_size": pckInfo["size"],
        "pck_hash": pckInfo["sha256"],
        "pck_sign": pckInfo["sign"],

        "gray_target": BUILDED_CLIENT_UUID,
        "remark": "Auto Build",
    }
    return httppost("/zzmdt/builded/uploadpck", payload)


def httppost(path, data, headers=None):
    ts = str(int(time.time()))
    m1 = hashlib.md5((SERVER_BASE_MDT + ts).encode()).hexdigest()
    m2 = hashlib.md5(m1.encode()).hexdigest()
    token = base64.b64encode(f"{m2},{ts}".encode()).decode()
    headerNew = {
        "Authorization": f"Token {token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
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
        rid = resp.json().get("rid", "")
    except json.JSONDecodeError:
        return resp.status_code, {}, "Invalid JSON response", resp.headers.get("X-Request-ID", "")
    return code, data, msg, rid



if __name__ == "__main__":
    startTimestamp = time.time()
    print(f"SPACE_ROOT: {SPACE_ROOT}")
    print(f"PROJECT_ROOT: {PROJECT_ROOT}")
    print(f"OUTPUT_PATH: {OUTPUT_PATH}")

    versionName = get_cmd_version_name()
    versionCode = get_cmd_version_code(versionName)

    OUTPUT_PATH.mkdir(parents=True, exist_ok=True)

    # 检查服务器是否允许当前project_tag-device_type-version_name的版本上报
    print(f"Checking version allow for: {versionName}")
    code, data, msg, rid = check_submit_allow(versionName)
    if code != 200:
        print(f"responseError: {versionName} notValidForUpload:" + msg)
        sys.exit(1)

    # 3. Godot 导出 PCK
    pckName = f"{PROJECT_ALIAS}-{versionName}.pck"
    pckPath = OUTPUT_PATH / pckName
    print(f"Exporting Godot PCK to: {pckPath}")
    build_godot_pck("AndroidHello", pckPath)
    print(f"✔ Godot PCK Exported: {pckPath}, Size: {pckPath.stat().st_size / (1024 * 1024):.2f} Mb")

    # 4. 哈希计算 & 签名
    sha256 = sha256_file(pckPath)
    pckSign = sign_file_rsa(pckPath)
    pckSize = pckPath.stat().st_size
    print(f"Checking version allow for hash: {sha256}")
    code, data, msg, rid = check_submit_allow(versionName, sha256)
    if code != 200:
        print(f"responseError:" + msg)
        sys.exit(1)


    # 5. 上传至阿里云 OSS (原生 PUT 请求，免 SDK)
    print("=" * 60)
    print("Uploading pck to OSS: {}".format(pckName))
    objectPckFull = f"{PROJECT_ALIAS}/{pckName}"
    downloadPckUrl = upload_to_oss(pckPath, objectPckFull, contentType="application/octet-stream")

    print("\n" + "=" * 60)
    print(f"Version  : {versionName} (Code: {versionCode})")
    print(f"PCK      : {pckName}")
    print(f"PCK URL  : {downloadPckUrl}")
    print(f"SHA256   : {sha256}")
    print("=" * 60)

    # 6. 上报版本服务记录
    code, data, msg, rid = create_pck_record(versionName, pckInfo={
        "url": downloadPckUrl,
        "name": pckName,
        "sha256": sha256,
        "size": pckSize,
        "sign": pckSign,
    })
    print(f"Create Version Record: code={code}, data={data}, msg={msg}, rid={rid}")
    if code != 200:
        print(f"responseError:" + msg)
        sys.exit(1)

    print(f"Total Elapsed: {time.time() - startTimestamp:.2f}s")


