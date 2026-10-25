#!/bin/bash
cd -- "$(dirname -- "$0")"
source ./_lib.sh

echo "=========================================="
echo " Codex 通道状态"
echo "=========================================="
echo "配置目录：$CODEX_DIR"

if [ ! -f "$CONFIG" ]; then
  echo "配置文件：缺失（请先安装并登录 Codex 桌面版）"
  pause_exit
  exit 0
fi

echo "当前通道：$(current_channel)"
echo "model：$(top_value model)"
echo "model_provider：$(top_value model_provider)"
echo "model_catalog_json：$(top_value model_catalog_json)"

if grep -q '^\[model_providers\.deepseek\]' "$CONFIG"; then
  echo "DeepSeek provider 段：已存在"
else
  echo "DeepSeek provider 段：缺失"
fi

key=$(sed -n '/^\[model_providers\.deepseek\]/,/^\[/p' "$CONFIG" | grep 'experimental_bearer_token' | head -1 | sed 's/.*=[[:space:]]*"//; s/"[[:space:]]*$//')
if [ -n "$key" ]; then
  echo "API Key：$(mask_secret "$key")"
else
  echo "API Key：未写入"
fi

echo "模型目录：$CATALOG $([ -f "$CATALOG" ] && echo 已存在 || echo 缺失)"
count=$(ls -1 "$BACKUP_DIR"/config.toml.bak-* 2>/dev/null | wc -l | tr -d ' ')
echo "备份数量：$count"
pause_exit
