# Codex 在 GPT 和 DeepSeek 之间切换

同一个 Codex，按任务换模型：复杂任务走 GPT，批量任务走 DeepSeek。这里有两种方式，按你用的是桌面版还是命令行选一种。

**桌面版**：用随附的程序包，双击切换，Mac 和 Windows 都有。
**命令行**：用 profile，一条 `--profile` 参数选通道。

## 准备

- macOS 13+ 或 Windows 10/11。
- Codex 桌面版已经安装，并用 ChatGPT 账号登录过一次（切回 GPT 要用这个登录态）。
- 一个 DeepSeek API Key，一行，不加引号。
- 能访问 `api.deepseek.com`。
- 不需要 Python、Node.js 或额外运行时：macOS 用 App/系统脚本，Windows 用自带的 PowerShell 5.1。

## 方式一：双击切换（桌面版）

程序包在本仓库根目录，分 `mac/` 和 `windows/`。包本身不带 Key，第一次用要先填自己的。

### macOS

1. 双击 `mac/方案A-一键App/Codex Switch.app`。如果系统提示无法验证开发者，右键点它 → 打开。
2. 第一次打开会要求填入自己的 DeepSeek Key，粘贴后点“保存”。
3. 点“切到 DeepSeek”，等提示完成。
4. `⌘Q` 完全退出 Codex，再重新打开，在模型列表里选 **DeepSeek-Flash**。

App 会常驻菜单栏，以后点菜单栏图标就能切换，不用再找文件夹。切换到 GPT 再切回来，原来的 GPT 模型名会自动恢复。

不想用图形界面的人，可以用同一文件夹里的 `方案B-命令行/`，功能和 App 完全一样，只是用 `.command` 脚本。

### Windows

1. 用记事本打开 `windows\deepseek\deepseek-key.txt`，把 Key 粘到下一行，只留一行，不加引号。
2. 把整个 `windows` 文件夹拷到本机，比如 `D:\Codex-Switch`。
3. 双击 `环境检查.bat`，确认系统、PowerShell、Codex 配置和 Key 都就绪。
4. 完全退出 Codex / ChatGPT（托盘里也退干净），双击 `一键安装.bat`。
5. 重新打开 Codex，在模型列表里选 **DeepSeek-Flash**。

桌面会出现三个图标：切到DeepSeek、切到GPT、一键切换模型。文件夹里另有「查看当前通道」「恢复上次备份」和「逻辑自检」。

### 它到底改了什么

两种系统改的都是 `config.toml` 顶部的三行：

```toml
model = "deepseek-flash"
model_provider = "deepseek"
model_catalog_json = "/绝对路径/.codex/models.json"
```

再加一个常驻的 provider 段：

```toml
[model_providers.deepseek]
name = "DeepSeek"
base_url = "https://api.deepseek.com/"
wire_api = "responses"
experimental_bearer_token = "你的 Key"
```

- 切到 DeepSeek：让这三行生效，并刷新 provider 段。
- 切到 GPT：移除这三行，回到 ChatGPT 登录通道；原来的 GPT 模型名会被记住。
- 每次真正改动前都会备份，放在 `~/.codex/deepseek-switch-backups/`（Windows 在 `%USERPROFILE%\.codex\deepseek-switch-backups\`）。

## 方式二：profile（命令行）

Codex 的 profile 是独立配置文件，放在 `$CODEX_HOME`（默认 `~/.codex`）：

```text
~/.codex/gpt.config.toml
~/.codex/deepseek.config.toml
```

启动时选择：

```bash
codex --profile gpt
codex --profile deepseek
```

`gpt.config.toml` 只需要指定内置的 openai provider 和模型：

```toml
model_provider = "openai"
model = "你的 GPT 模型 ID"
```

`deepseek.config.toml` 定义一个自定义 provider：

```toml
model_provider = "deepseek"
model = "deepseek-flash"

[model_providers.deepseek]
name = "DeepSeek"
base_url = "https://api.deepseek.com/"
env_key = "DEEPSEEK_API_KEY"
wire_api = "responses"
supports_websockets = false
```

Key 放环境变量，不写进文件：

```bash
export DEEPSEEK_API_KEY="你的 Key"
codex --profile deepseek
```

注意：profile 只影响用 `--profile` 启动的命令行会话；桌面版读的是 `config.toml`，所以桌面版请用方式一。

## 验证

两边各开一个新会话，发同一句话：

```text
只回复 OK，并告诉我你是哪个模型
```

能正常回复就说明路由和认证都通了。第一次验证别拿重要的长会话试。

常见问题：

- **模型列表里没有 DeepSeek**：确认 Codex 是完全退出后重开的；用「查看当前通道」检查三行是否存在且没被注释。
- **401**：Key 不对或额度用完。改 `deepseek-key.txt`，再双击一次「切到DeepSeek」。
- **切了没反应**：桌面版要重启；命令行要确认用的是 `--profile` 或正确的 `config.toml`。
- **连不上**：如果你开了全局代理，检查代理规则是否把 `api.deepseek.com` 也代理了；国内一般直连更稳。

## 迁移与安全

换电脑时只复制程序包和说明，Key 重新填。不要复制：

- `auth.json`
- 完整 `config.toml`
- `sessions`、`archived_sessions`、SQLite 数据库

`deepseek-key.txt` 和写进 `config.toml` 的 provider 段都是明文 Key。别把填好 Key 的包发到公开网盘、群聊或仓库；泄露后去 DeepSeek 后台重新生成。

## 官方依据

- [Codex Config Basics](https://learn.chatgpt.com/docs/config-file/config-basic)
- [Codex Advanced Configuration](https://learn.chatgpt.com/docs/config-file/config-advanced)
- [Codex Configuration Reference](https://learn.chatgpt.com/docs/config-file/config-reference)
