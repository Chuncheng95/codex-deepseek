#!/bin/bash
set -e
cd -- "$(dirname -- "$0")"
source ./_lib.sh

echo "=========================================="
echo " Codex 通道切换器 · macOS 安装"
echo "=========================================="
echo "Codex 目录：$CODEX_DIR"

ensure_dirs

if [ ! -f "$CONFIG" ]; then
  echo
  echo "没有找到 config.toml。"
  echo "请先安装并打开一次 Codex 桌面版，用 ChatGPT 账号登录后再运行本安装。"
  pause_exit
  exit 1
fi

key=$(read_key_file)
if [ -z "$key" ]; then
  echo
  echo "还没有填写 DeepSeek API Key。"
  echo "可以直接把 Key 粘贴到这里（输入不回显），会写进本机的 deepseek-key.txt："
  read -r -s -p "Key: " key
  echo
  if [ -z "$key" ]; then
    echo "没有输入 Key，安装中止。"
    pause_exit
    exit 1
  fi
  printf '%s\n' "$key" > "$PKG_DIR/deepseek/deepseek-key.txt"
fi

if [ "$(current_channel)" = "GPT" ]; then
  model=$(top_value model)
  if [ -n "$model" ] && [ "$model" != "deepseek-flash" ]; then
    printf '%s\n' "$model" > "$STATE_DIR/gpt-model"
  fi
fi

bak=$(backup_config install)
echo "已备份配置：$bak"

if [ -f "$PKG_DIR/deepseek/models.json" ]; then
  [ -f "$CATALOG" ] && cp "$CATALOG" "$BACKUP_DIR/models.json.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$PKG_DIR/deepseek/models.json" "$CATALOG"
  echo "已安装模型目录：$CATALOG"
fi

upsert_provider "$key"
apply_deepseek

desktop="$HOME/Desktop"
if [ -d "$desktop" ]; then
  ln -sf "$PKG_DIR/切到DeepSeek.command" "$desktop/切到DeepSeek.command"
  ln -sf "$PKG_DIR/切到GPT.command" "$desktop/切到GPT.command"
  ln -sf "$PKG_DIR/查看当前通道.command" "$desktop/查看当前通道.command"
  echo "已在桌面创建 3 个快捷方式。"
fi

echo
echo "安装完成，当前通道：$(current_channel)"
echo "请完全退出并重新打开 Codex 应用后生效。"
pause_exit
