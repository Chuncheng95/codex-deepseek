# Codex Switch

在 **GPT（ChatGPT 登录）** 和 **DeepSeek API** 之间切换 Codex 的小工具。

支持 macOS 和 Windows。包里不含任何 API Key，第一次使用时填自己的。

## 直接下载

- macOS：[Codex-Switch-mac.zip](Codex-Switch-mac.zip)
- Windows：[Codex-Switch-windows.zip](Codex-Switch-windows.zip)

## macOS：两套方案，任选一套

### 方案 A：一键 App（推荐）

解压后打开 `mac/方案A-一键App/Codex Switch.app`。

1. 第一次打开，填入自己的 DeepSeek Key，点“保存”。
2. 点“切到 DeepSeek”。
3. `⌘Q` 完全退出 Codex，再重新打开。

之后可以点菜单栏图标切换，或按 `⌘1` / `⌘2`。

第一次打开如果提示“无法验证开发者”：右键 App → 打开。

### 方案 B：命令行

解压后进入 `mac/方案B-命令行/`：

1. 把 Key 粘到 `deepseek/deepseek-key.txt`。
2. 双击 `一键安装.command`。
3. 重启 Codex。

详细说明见 [mac/使用说明.md](mac/使用说明.md)。

## Windows

解压后进入 `windows/`：

1. 用记事本把 Key 粘到 `deepseek/deepseek-key.txt`。
2. 双击 `环境检查.bat`，确认环境就绪。
3. 完全退出 Codex / ChatGPT。
4. 双击 `一键安装.bat`。
5. 重新打开 Codex，模型列表里选 **DeepSeek-Flash**。

桌面会出现“切到DeepSeek”“切到GPT”“一键切换模型”三个图标。

详细说明见 [windows/使用说明.md](windows/使用说明.md)。

## 它改了什么

只改 `~/.codex/config.toml` 顶部的三行：

```toml
model = "deepseek-flash"
model_provider = "deepseek"
model_catalog_json = "/绝对路径/.codex/models.json"
```

再加一段 DeepSeek provider。每次改动前都会自动备份到 `~/.codex/deepseek-switch-backups/`。

## 安全

- 仓库里只有模板和提示文字，**没有任何人的真实 Key**。
- 你填的 Key 只保存在本机。
- Codex 需要读取 Key 才能调用 DeepSeek，所以本机 `config.toml` 的 provider 段里会是明文；这个文件不要发给别人。

## 系统要求

- macOS 13+，或者 Windows 10/11。
- 已安装 Codex 桌面版，并用 ChatGPT 账号登录过一次。
- 自己的 DeepSeek API Key。

## 目录

```text
mac/
├── 使用说明.md
├── 方案A-一键App/Codex Switch.app
└── 方案B-命令行/
windows/
├── 使用说明.md
├── 一键安装.bat / 一键切换.bat / 环境检查.bat
└── CodexSwitch.ps1
Codex-GPT-DeepSeek-切换指南.md
```
