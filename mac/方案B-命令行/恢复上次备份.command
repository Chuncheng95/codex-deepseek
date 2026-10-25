#!/bin/bash
set -e
cd -- "$(dirname -- "$0")"
source ./_lib.sh

ensure_dirs

latest=$(ls -1t "$BACKUP_DIR"/config.toml.bak-* 2>/dev/null | head -1 || true)
if [ -z "$latest" ]; then
  echo "没有找到备份：$BACKUP_DIR"
  pause_exit
  exit 0
fi

echo "将恢复：$latest"
keep=$(backup_config prerestore)
cp "$latest" "$CONFIG"

echo "恢复完成。"
echo "恢复前的配置已另存：$keep"
echo "请完全退出并重新打开 Codex 应用后生效。"
pause_exit
