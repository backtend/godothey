import requests
import hmac
import hashlib
from urllib.parse import quote
import base64
from email.utils import formatdate

# 替换为你的参数 
access_key_id = ''
access_key_secret = ''
bucket_name = 'yongit'
endpoint = 'oss-cn-beijing.aliyuncs.com'  # OSS Endpoint
file_path = 'assets/coder.jpg'                     # 本地文件路径
object_name = 'assets/coder2.jpg'                   # 上传到OSS的文件名

http_method = 'PUT'
content_type = 'image/jpeg'

# OSS 需要 RFC 1123 / GMT 格式的 Date
date = formatdate(usegmt=True)

canonicalized_resource = f'/{bucket_name}/{object_name}'
string_to_sign = f"{http_method}\n\n{content_type}\n{date}\n{canonicalized_resource}"

signature = base64.b64encode(
    hmac.new(
        access_key_secret.encode('utf-8'),
        string_to_sign.encode('utf-8'),
        hashlib.sha1
    ).digest()
).decode('utf-8')

headers = {
    'Authorization': f'OSS {access_key_id}:{signature}',
    'Content-Type': content_type,
    'Date': date,
}

with open(file_path, 'rb') as f:
    file_data = f.read()

url = f'https://{bucket_name}.{endpoint}/{quote(object_name)}'
response = requests.put(url, headers=headers, data=file_data)
print("==================================")
print(f'Status Code: {response.status_code}')
print(f'Response: {str(response.content, "utf-8")}')
print(response.text)