#!/bin/bash

# ====== 配置区域 ======
# 请自行替换为你自己的API_KEY和HOST地址
API_KEY="YOUR_API_KEY_HERE"                  # 你的API密钥，切勿泄露
HOST="http://127.0.0.1:26888​"                 # 面板服务器地址+端口（本例是本机地址）
CHECK_ENDPOINT="/api/v1/dashboard/base/os"   # 用于Token鉴权检测的接口
UPLOAD_ENDPOINT="/websites/ssl/upload"       # SSL上传接口

# ====== 获取当前时间戳（秒） ======
TIMESTAMP=$(date +%s)

# ====== 生成Token ======
# Token生成规则：md5("1panel" + API_KEY + TIMESTAMP)
TOKEN=$(echo -n "1panel${API_KEY}${TIMESTAMP}" | md5sum | awk '{print $1}')

# ====== Token鉴权测试 ======
# 通过GET请求验证Token是否有效
AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "${HOST}${CHECK_ENDPOINT}" \
  -H "1Panel-Token: ${TOKEN}" \
  -H "1Panel-Timestamp: ${TIMESTAMP}" \
  -H "Content-Type: application/json")

if [[ "$AUTH_RESPONSE" != "200" ]]; then
  echo "❌ Token鉴权失败，状态码: $AUTH_RESPONSE"
  exit 1
fi

# ====== 读取证书文件路径（请替换为你的实际路径） ======
PRIVATE_KEY_PATH="/path/to/your/privkey.pem"       # 私钥文件路径
CERTIFICATE_PATH="/path/to/your/fullchain.pem"     # 证书文件路径
DESCRIPTION="你的证书描述，例如：example.com证书"   # 证书描述信息

# ====== 读取证书内容并转义换行符 ======
# awk 将每行追加 \n，sed 删除最后一个多余换行
PRIVATE_KEY_CONTENT=$(awk '{printf "%s\\n", $0}' "$PRIVATE_KEY_PATH" | sed 's/\\n$//')
CERTIFICATE_CONTENT=$(awk '{printf "%s\\n", $0}' "$CERTIFICATE_PATH" | sed 's/\\n$//')

# ====== 构建上传的JSON数据 ======
# 注意certificate和privateKey使用转义后的换行符，type固定为paste
UPLOAD_DATA=$(cat <<EOF
{
  "certificate": "$CERTIFICATE_CONTENT",
  "privateKey": "$PRIVATE_KEY_CONTENT",
  "certificatePath": "",
  "privateKeyPath": "",
  "description": "$DESCRIPTION",
  "sslID": 0,
  "type": "paste"
}
EOF
)

# ====== 发起上传请求 ======
# -s 静默模式，-w %{http_code} 获取状态码，拼接响应内容和状态码
UPLOAD_RESPONSE=$(curl -s -w "%{http_code}" -X POST "${HOST}${UPLOAD_ENDPOINT}" \
  -H "1Panel-Token: ${TOKEN}" \
  -H "1Panel-Timestamp: ${TIMESTAMP}" \
  -H "Content-Type: application/json" \
  -d "$UPLOAD_DATA")

# ====== 解析HTTP状态码和响应体 ======
HTTP_CODE="${UPLOAD_RESPONSE: -3}"
BODY="${UPLOAD_RESPONSE::-3}"

# ====== 根据状态码判断上传是否成功 ======
if [[ "$HTTP_CODE" == "200" ]]; then
  echo "✅ SSL证书上传成功"
else
  echo "❌ SSL证书上传失败，状态码: $HTTP_CODE，响应内容: $BODY"
  exit 1
fi
