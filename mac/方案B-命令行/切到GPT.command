#!/bin/bash
set -e
cd -- "$(dirname -- "$0")"
source ./_lib.sh

ensure_dirs

if [ ! -f "$CONFIG" ]; then
  echo "找不到 $CONFIG，请先安装并登录 Codex 桌面版。"
  pause_exit
  exit 1
fi

if [ "$(current_channel)" = "GPT" ]; then
  echo "当前已经是 GPT 通道，没有改动。"
  pause_exit
  exit 0
fi

bak=$(backup_config gpt)
apply_gpt

echo "=========================================="
echo " 已切回 GPT 通道（ChatGPT 登录）"
echo " 备份：$bak"
echo " 请完全退出并重新打开 Codex 应用后生效"
echo "=========================================="
pause_exit
