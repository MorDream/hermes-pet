#!/usr/bin/env bash
# import_codex_pet.sh — 从 Codex Pets CDN 绕过导入宠物（墙内友好）
#
# Usage:
#   bash import_codex_pet.sh <petId>
#
# Examples:
#   bash import_codex_pet.sh maodie
#   bash import_codex_pet.sh sakuraha-emma
#
# 工作流：
#   1. 抓 share 页 → 从 og:image 提取 CDN 版本号
#   2. 下载 pet.json + spritesheet.webp 到 /mnt/f/下载/{petId}/
#   3. 通过 OpenPet /api/import/local 本地导入
#
# 依赖：curl, grep, python3

set -euo pipefail


if [ $# -ne 1 ]; then
  echo "用法: bash import_codex_pet.sh <petId>"
  echo "示例: bash import_codex_pet.sh maodie"
  exit 1
fi

PET_ID="$1"
SHARE_URL="https://codex-pets.net/share/${PET_ID}"
DEST_DIR="/mnt/f/下载/${PET_ID}"
OPENPET_API="http://127.0.0.1:17321"

echo "🦖 [1/5] 抓取 share 页: ${SHARE_URL}"

SHARE_HTML=$(curl -sL "${SHARE_URL}")
OG_IMAGE=$(echo "${SHARE_HTML}" | grep -oP 'og:image.*?content="\K[^"]+' | head -1)

if [ -z "${OG_IMAGE}" ]; then
  echo "❌ 无法从 share 页提取 og:image URL"
  exit 1
fi

echo "   → og:image: ${OG_IMAGE}"

# 从 CDN 路径提取版本号: .../v/{version}/{petId}/share.png
VERSION=$(echo "${OG_IMAGE}" | grep -oP '/v/\K\d+')
if [ -z "${VERSION}" ]; then
  echo "❌ 无法从 og:image 提取版本号"
  exit 1
fi

CDN_BASE="https://codex-pets.net/assets/pets/v/${VERSION}/${PET_ID}"
echo "   → 版本号: ${VERSION}"
echo "   → CDN 基础路径: ${CDN_BASE}"

echo ""
echo "📦 [2/5] 获取 pet.json..."
PET_JSON=$(curl -sL "${CDN_BASE}/pet.json")
if [ -z "${PET_JSON}" ]; then
  echo "❌ 下载 pet.json 失败"
  exit 1
fi

DISPLAY_NAME=$(echo "${PET_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('displayName','?'))")
echo "   → 宠物名称: ${DISPLAY_NAME}"

echo ""
echo "🖼️  [3/5] 下载 spritesheet.webp..."
mkdir -p "${DEST_DIR}"
curl -sL -o "${DEST_DIR}/spritesheet.webp" "${CDN_BASE}/spritesheet.webp"
SPRITE_SIZE=$(ls -lh "${DEST_DIR}/spritesheet.webp" | awk '{print $5}')
echo "   → 雪碧图大小: ${SPRITE_SIZE}"

echo ""
echo "✏️  [4/5] 写入 pet.json（含来源信息）..."
echo "${PET_JSON}" | python3 -c "
import sys, json
pet = json.load(sys.stdin)
pet['sourceName'] = 'Codex Pets'
pet['sourceUrl'] = 'https://codex-pets.net/#/pets/${PET_ID}'
json.dump(pet, sys.stdout, ensure_ascii=False, indent=2)
" > "${DEST_DIR}/pet.json"
echo "   → 已写入 ${DEST_DIR}/pet.json"

echo ""
echo "🚀 [5/5] 通过 OpenPet API 本地导入..."
IMPORT_RESULT=$(curl -s -X POST "${OPENPET_API}/api/import/local" \
  -H "Content-Type: application/json" \
  -d "{\"source\":\"F:\\\\下载\\\\${PET_ID}\"}")

IMPORTED=$(echo "${IMPORT_RESULT}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('activePet',{}).get('imported'):
    print('✅ 导入成功！当前活跃: ' + d['activePet']['displayName'] + ' (' + d['activePet']['id'] + ')')
else:
    print('❌ 导入失败: ' + json.dumps(d))
")

echo "${IMPORTED}"
echo ""
echo "✨ 完成！桌面已是 ${DISPLAY_NAME} 啦～"
