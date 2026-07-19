#!/usr/bin/env python3
"""构建 Release APK -> 备份 -> SHA256+RSA 签名 -> 上传 R2 -> 同步版本信息到服务器
依赖: pip install boto3 requests"""
import base64, hashlib, subprocess, sys, time
from datetime import datetime
from pathlib import Path
import requests

# ===== 路径配置 =====
PROJECT_DIR = Path(__file__).resolve().parent
GRADLEW = PROJECT_DIR / "gradlew"
APK_PATH = PROJECT_DIR / "app/build/outputs/apk/release/app-release.apk"
BACKUP_DIR = PROJECT_DIR / "docs/apksbak"
PRIVATE_KEY_PEM = PROJECT_DIR / "docs/sign/private_key.pem"
APK_ALIAS = "yitbox"
WAIT_SECONDS = 5

# ===== R2 凭据 =====
R2_BUCKET = "otossbox"
R2_ENDPOINT = "https://2e2955b79a05a5dd7fb9eb82fc9be4ad.r2.cloudflarestorage.com"
R2_ACCESS_KEY = "f460028ed1459d6e244386888e4aca12"
R2_SECRET_KEY = "e1edd80380a312d64ba994605f352227d19c57284531911bc965d1545a2960ef"
R2_REGION = "auto"
R2_PUBLIC_BASE_URL = "https://otossbox.vaehub.com"

# ===== 服务器同步配置 =====
SERVER_URL = "https://apix.yongit.com/programer/create"
SERVER_SECRET = "ce137c47b32e37dce807756b92ccbx" + str(datetime.now().strftime("%y%m")) # 最后6位是UTC年月
PROJECT_TAG = "yongitbox"
DEVICE_TYPE = "android"


def generate_version(now=None) -> str:
    now = now or datetime.now()
    return f"{now.year % 100 - 20}.{now.month * 100 + now.day}.{now.hour * 100 + now.minute}"


def countdown(seconds: int) -> None:
    print(f"==> Building release APK in {seconds} seconds... Press Ctrl+C to cancel.")
    for i in range(seconds, 0, -1):
        print(f"==> 发射倒计时： {i} 秒...")
        time.sleep(1)


def build_apk() -> None:
    if not GRADLEW.exists():
        raise FileNotFoundError(f"gradlew not found at {GRADLEW}")
    print("==> Building release APK...")
    subprocess.run([str(GRADLEW), "assembleRelease"], cwd=str(PROJECT_DIR), check=True)


def backup_apk(version: str) -> Path:
    if not APK_PATH.exists():
        raise FileNotFoundError(f"APK not found at {APK_PATH}")
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    backup_path = BACKUP_DIR / f"{APK_ALIAS}-{version}.apk"
    backup_path.write_bytes(APK_PATH.read_bytes())
    print(f"✔ Backup created: {backup_path}")
    return backup_path


def sha256_file(file_path: Path) -> str:
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sign_file_rsa(file_path: Path) -> str:
    result = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(PRIVATE_KEY_PEM), str(file_path)],
        check=True, stdout=subprocess.PIPE)
    return base64.b64encode(result.stdout).decode().strip()


def upload_to_r2(file_path: Path, object_path: str, content_type="application/vnd.android.package-archive") -> str:
    import boto3
    print("==> Uploading to R2...")
    client = boto3.client("s3", endpoint_url=R2_ENDPOINT, aws_access_key_id=R2_ACCESS_KEY,
                           aws_secret_access_key=R2_SECRET_KEY, region_name=R2_REGION)
    with open(file_path, "rb") as f:
        client.put_object(Bucket=R2_BUCKET, Key=object_path.lstrip("/"), Body=f, ContentType=content_type)
    print("✔ Upload successful!")
    return f"{R2_ENDPOINT}/{R2_BUCKET}/{object_path.lstrip('/')}"


def build_authorization(secret: str) -> str:
    timestamp = str(int(time.time()))
    md5_1 = hashlib.md5((secret + timestamp).encode()).hexdigest()
    md5_2 = hashlib.md5(md5_1.encode()).hexdigest()
    token = base64.b64encode(f"{md5_2},{timestamp}".encode()).decode()
    return "Token " + token


def create_version_record(version: str, download_url: str, apk_name: str, sha256: str, dist_sign: str, size: int) -> requests.Response:
    payload = {
        "title": f"自动打包 {APK_ALIAS} {version}", "intro": "", "project_tag": PROJECT_TAG,
        "device_type": DEVICE_TYPE, "version_name": version, "zip_url": download_url, "zip_name": apk_name,
        "zip_hash": sha256, "zip_size": size, "dist_name": apk_name, "dist_size": size,
        "dist_sign": dist_sign, "remark": "自动上传"
    }
    headers = {"Authorization": build_authorization(SERVER_SECRET), "Content-Type": "application/json", "Accept": "application/json"}
    return requests.post(SERVER_URL, json=payload, headers=headers, timeout=15)


def main() -> None:
    start_ts = time.time()
    if WAIT_SECONDS > 0:
        countdown(WAIT_SECONDS)
    version = generate_version()
    print(f"==> Generated version: {version}")
    build_apk()
    backup_path = backup_apk(version)
    apk_name = backup_path.name
    sha256 = sha256_file(backup_path)
    sign_base64 = sign_file_rsa(backup_path)
    file_size = backup_path.stat().st_size
    object_path = f"/{APK_ALIAS}/{apk_name}"
    upload_to_r2(backup_path, object_path)
    download_url = f"{R2_PUBLIC_BASE_URL}{object_path}"
    print("********************************************")
    print(f"Version: {version}")
    print(f"✔ Download URL: {download_url}")
    print(f"SHA256: {sha256}")
    print()
    print("        ////=====================================")
    print("        $versionOptions = ['only_device_ids' => []];")
    print(f"        $versionLast = '{version}';")
    print(f"        $distSign = '{sign_base64}';")
    print(f"        $distSize = {file_size};")
    print("        ////=====================================")
    print()
    print("********************************************")
    resp = create_version_record(version, download_url, apk_name, sha256, sign_base64, file_size)
    print(f"==> 服务器同步状态: {resp.status_code}")
    print(resp.text)
    end_ts = time.time()
    print(f"💥 打包开始时间 {datetime.fromtimestamp(start_ts).strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"💥 打包完成时间 {datetime.fromtimestamp(end_ts).strftime('%Y-%m-%d %H:%M:%S')} (总耗时: {int(end_ts - start_ts)} 秒)")


if __name__ == "__main__":
    main()