#!/bin/bash
# Codex 通道切换器（macOS）公共函数

CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG="$CODEX_DIR/config.toml"
BACKUP_DIR="$CODEX_DIR/deepseek-switch-backups"
STATE_DIR="$CODEX_DIR/deepseek-switch"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="$CODEX_DIR/models.json"

pause_exit() {
  echo
  read -r -p "按回车关闭窗口…" _ || true
}

ensure_dirs() {
  mkdir -p "$CODEX_DIR" "$BACKUP_DIR" "$STATE_DIR"
}

backup_config() {
  local tag="$1" stamp
  [ -f "$CONFIG" ] || return 0
  stamp=$(date +%Y%m%d-%H%M%S)
  cp "$CONFIG" "$BACKUP_DIR/config.toml.bak-$tag-$stamp"
  echo "$BACKUP_DIR/config.toml.bak-$tag-$stamp"
}

# 读取 config.toml 里第一个表之前的顶层键
top_value() {
  local key="$1"
  [ -f "$CONFIG" ] || return 0
  awk -v k="$key" '
    /^\[/ { intable = 1 }
    !intable && $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
      line = $0
      sub(/^[^=]*=[[:space:]]*/, "", line)
      gsub(/^"|"[[:space:]]*$/, "", line)
      print line
      exit
    }
  ' "$CONFIG"
}

# 删掉顶层 model / model_provider / model_catalog_json（含被注释的旧行）
strip_top_keys() {
  awk '
    /^\[/ { intable = 1 }
    {
      if (!intable && $0 ~ /^[[:space:]]*#?[[:space:]]*(model|model_provider|model_catalog_json)[[:space:]]*=/) next
      print
    }
  ' "$1" | awk 'NF { found = 1 } found'
}

apply_deepseek() {
  local tmp
  tmp=$(mktemp)
  {
    echo "model = \"deepseek-flash\""
    echo "model_provider = \"deepseek\""
    echo "model_catalog_json = \"$CATALOG\""
    echo
    strip_top_keys "$CONFIG"
  } > "$tmp"
  mv "$tmp" "$CONFIG"
}

apply_gpt() {
  local saved tmp
  saved=""
  [ -f "$STATE_DIR/gpt-model" ] && saved=$(cat "$STATE_DIR/gpt-model")
  tmp=$(mktemp)
  {
    [ -n "$saved" ] && echo "model = \"$saved\""
    echo "model_provider = \"openai\""
    echo
    strip_top_keys "$CONFIG"
  } > "$tmp"
  mv "$tmp" "$CONFIG"
}

current_channel() {
  local provider
  provider=$(top_value model_provider)
  if [ "$provider" = "deepseek" ]; then
    echo "DeepSeek"
  elif [ -z "$provider" ] || [ "$provider" = "openai" ]; then
    echo "GPT"
  else
    echo "未知（provider=$provider）"
  fi
}

mask_secret() {
  local s="$1"
  if [ ${#s} -le 10 ]; then echo "(已配置)"; else echo "${s:0:6}...${s: -4}"; fi
}

read_key_file() {
  local f="$PKG_DIR/deepseek/deepseek-key.txt"
  [ -f "$f" ] || return 0
  grep -v '^[[:space:]]*#' "$f" | grep -v '^[[:space:]]*$' | head -1 | tr -d '[:space:]'
}

remove_provider_block() {
  awk '
    /^\[/ {
      if ($0 ~ /^\[model_providers\.deepseek\]/) { skip = 1; next }
      skip = 0
    }
    !skip { print }
  ' "$1"
}

upsert_provider() {
  local key="$1" tmp
  tmp=$(mktemp)
  remove_provider_block "$CONFIG" | awk '
    { lines[NR] = $0 }
    END {
      n = NR
      while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
      for (i = 1; i <= n; i++) print lines[i]
    }
  ' > "$tmp"
  printf '\n[model_providers.deepseek]\nname = "DeepSeek"\nbase_url = "https://api.deepseek.com/"\nwire_api = "responses"\nexperimental_bearer_token = "%s"\n' "$key" >> "$tmp"
  mv "$tmp" "$CONFIG"
}
