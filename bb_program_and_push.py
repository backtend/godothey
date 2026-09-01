#!/usr/bin/env python3

import os,sys
import base64
import hashlib
import hmac
import json
import subprocess
import time
import zipfile
from email.utils import formatdate
from pathlib import Path
from urllib.parse import quote
from datetime import datetime, timezone
import re
import configparser

import requests

# =========================================================
# 项目 & 环境配置
# =========================================================
GODOT_BIN = "/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_ALIAS = "godothey"
PROJECT_TAG = "godothey"
DEVICE_TYPE = "android"
# BUILDED_CLIENT_UUID = "e3748630-3877-4f5e-a4db-91a5cd90bf42"
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

def get_app_version_name():
    now = datetime.now()
    major = int(now.year - 2025)*1
    minor = int(now.month*100 + now.day)*1
    patch = int(now.hour * 10 + now.minute//6)*1
    return f"{major}.{minor}.{patch}"

def get_app_version_code(version_name):
    parts = version_name.split(".")
    if len(parts) != 3:
        raise ValueError("Invalid version name format")
    return int(parts[0]) * 10000000 + int(parts[1]) * 1000 + int(parts[2])

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

def create_export_presets(config_name: str, resource: str):
    file = PROJECT_ROOT / "export_presets.cfg"
    content = file.read_text(encoding="utf-8")
    content = re.sub(
        rf'{config_name}="([^"]*)"',
        lambda m: f'{config_name}="{m.group(1) + "," if m.group(1) else ""}{resource}"',
        content
    )
    file.write_text(content, encoding="utf-8")

def remove_export_presets(config_name: str, resource: str):
    file = PROJECT_ROOT / "export_presets.cfg"
    content = file.read_text(encoding="utf-8")
    content = re.sub(
        rf'{config_name}="([^"]*)"',
        lambda m: f'{config_name}="{",".join(x for x in m.group(1).split(",") if x != resource)}"',
        content
    )
    file.write_text(content, encoding="utf-8")

def building_setup(pckVersionName):
    file = PROJECT_ROOT / "configuration.ini"

    now_utc = datetime.now(timezone.utc)
    now_local = now_utc.astimezone()
    config = configparser.ConfigParser()

    # 1. 改为普通分组名 "BUILDED"（避开保留字 DEFAULT）
    config["BUILDED"] = {
        "build_utc_timestamp": str(int(now_utc.timestamp())),
        "build_utc_datetime": f'"{now_utc.strftime("%Y-%m-%d %H:%M:%S%z")}"',
        "build_local_datetime": f'"{now_local.strftime("%Y-%m-%d %H:%M:%S%z")}"',
        "build_local_timezone": f'"{now_local.tzname()}"',
    }

    # 2. 包版本分组
    config["PACKAGE"] = {
        "build_pck_vname": f'"{pckVersionName}"',
        "build_pck_vcode": get_cmd_version_code(pckVersionName),
    }

    # 3. 写入文件（显式指定 newline="\n" 保证跨平台统一换行符）
    with open(file, "w", encoding="utf-8", newline="\n") as f:
        config.write(f)
    return



def update_project_godot(versionName):
    file = PROJECT_ROOT / "project.godot"
    content = file.read_text(encoding="utf-8")
    if re.search(r'config/version=".*?"', content):
        content = re.sub(r'config/version=".*?"', f'config/version="{versionName}"', content)
    else:
        content += ("\n[application]\n"f'config/version="{versionName}"\n')
    file.write_text(content, encoding="utf-8")


def update_export_presets(versionName):
    versionCode = get_app_version_code(versionName)
    file = PROJECT_ROOT / "export_presets.cfg"
    content = file.read_text(encoding="utf-8")
    content = re.sub(r'version/name=".*?"', f'version/name="{versionName}"', content)
    content = re.sub(r'version/code=\d+', f'version/code={versionCode}', content)
    file.write_text(content, encoding="utf-8")


def build_godot_app(preset, distPath):
    print("\n" + "=" * 60 + "\nBuilding Godot...\n" + "=" * 60)
    cmd = [GODOT_BIN, "--headless", "--export-release", preset, str(distPath)]
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

def check_submit_allow(appVersionName, sha256:str=None) -> bool:
    payload = {
        "project_tag": PROJECT_TAG,
        "device_type": DEVICE_TYPE,
        "version_name": appVersionName,
        "hash": sha256,
    }
    return httppost("/zzmdt/builded/allowapp",payload)

def create_version_record(appVersionName, zipInfo, distInfo):
    payload = {
        "title": f"Godot Auto Build {appVersionName}",
        "intro": "",
        "project_tag": PROJECT_TAG,
        "device_type": DEVICE_TYPE,
        "version_name": appVersionName,

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
    return httppost("/zzmdt/builded/uploadapp", payload)


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

    appVersionName = get_app_version_name()
    appVersionCode = get_app_version_code(appVersionName)
    pckVersionName = get_cmd_version_name()
    pckVersionCode = get_cmd_version_code(pckVersionName)

    # x. 更新 program_config.json
    building_setup(pckVersionName)

    # appVersionName = get_app_version_name()
    # print(f"Version Name: {appVersionName}, Version Code: {get_app_version_code(appVersionName)}")
    # print(60//6)
    OUTPUT_PATH.mkdir(parents=True, exist_ok=True)

    # 检查服务器是否允许当前project_tag-device_type-version_name的版本上报
    # 这里可以添加一个请求到服务器的检查逻辑，如果不允许，则直接退出
    code, data, msg, rid = check_submit_allow(appVersionName)
    if code != 200:
        print(f"Version {appVersionName} notAllow:" + msg)
        sys.exit(1)

    # 1. 更新 project.godot 和 export_presets.cfg
    update_project_godot(appVersionName)
    # 2. 更新 export_presets.cfg 中的 version/name 和 version/code
    update_export_presets(appVersionName)


    # 1. Godot 导出 APK
    distName = f"{PROJECT_ALIAS}-{appVersionName}.apk"
    distPath = OUTPUT_PATH / distName
    print(f"Exporting Godot APK to: {distPath}")
    create_export_presets("include_filter", "configuration.ini")
    try:
        build_godot_app("AndroidHello", distPath)
    finally:
        remove_export_presets("include_filter", "configuration.ini")
        
    print(f"✔ Godot APK Exported: {distPath}, Size: {distPath.stat().st_size / (1024 * 1024):.2f} Mb")

    # 2. 压缩成 ZIP
    zipName = f"{PROJECT_ALIAS}-{appVersionName}.zip"
    zipPath = OUTPUT_PATH / zipName
    zip_file(distPath, zipPath)

    # 3. 签名与哈希计算
    sha256 = sha256_file(zipPath)
    distSign = sign_file_rsa(distPath)
    zipSize = zipPath.stat().st_size
    distSize = distPath.stat().st_size
    print(f"Checking version allow for hash: {sha256}")
    code, data, msg, rid = check_submit_allow(appVersionName, sha256)
    if code != 200:
        print(f"responseError:" + msg)
        sys.exit(1)

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
    print(f"APP Version      : {appVersionName} (Code: {appVersionCode})")
    print(f"APP ZIP          : {zipName}")
    print(f"APP ZIP URL      : {downloadZipUrl}")
    print(f"APP SHA256       : {sha256}")
    print(f"PCK Version      : {pckVersionName} (Code: {pckVersionCode})")
    print("=" * 60)

    # 5. 上报版本服务记录
    code, data, msg, rid = create_version_record(appVersionName, zipInfo={
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
    print(f"Create Version Record: code={code}, data={data}, msg={msg}, rid={rid}")

    print(f"Total Elapsed: {time.time() - startTimestamp:.2f}s")