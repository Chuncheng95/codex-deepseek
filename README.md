<p align="center">
  <img src="assets/icon.png" width="160" alt="Codex Switch">
</p>

<h1 align="center">Codex Switch</h1>

<p align="center">在 GPT（ChatGPT 登录）和 DeepSeek API 之间切换 Codex 的小工具。</p>

支持 macOS 和 Windows。仓库里不含任何 API Key，第一次使用时填自己的。

## 它解决什么问题

Codex 默认只走 ChatGPT 登录的 GPT 通道。想用 DeepSeek，通常要手动改 `config.toml` 里的模型、provider、模型目录，还要自己维护 API Key。切回 GPT 时又得改回来，容易漏项。

Codex Switch 把这些操作收成两个动作：

- **切到 DeepSeek**：写入 DeepSeek 的模型和 provider。
- **切回 GPT**：恢复 ChatGPT 登录通道，记住你原来的 GPT 模型名。

每次真正改动前都会自动备份，切错了可以一键恢复。

## 两套使用方式

| 平台 | 方式 | 适合谁 |
|---|---|---|
| macOS | 方案 A：`Codex Switch.app` | 大多数人，双击切换，不打开终端 |
| macOS | 方案 B：`.command` 脚本 | 喜欢终端、远程 SSH、想排查每一步的人 |
| Windows | 双击 `.bat` | 所有人，安装后桌面有三个图标 |

两种 Mac 方案改的是同一份配置，效果一样，任选一套即可。

## 运行环境

**不需要 Python、Node.js、Docker。** 两个平台用的都是系统自带能力：macOS 用 App 或 bash，Windows 用 PowerShell 5.1。

| 项目 | macOS | Windows |
|---|---|---|
| 操作系统 | macOS 13 Ventura 或更新 | Windows 10 / 11（64 位） |
| 运行环境 | 系统自带，无额外依赖 | 系统自带 PowerShell 5.1，无需安装 |
| Codex | 已安装 Codex 桌面版，并用 ChatGPT 账号登录过至少一次 | 同上 |
| 客户端版本 | 建议较新版本；`models.json` 要求 ≥ 0.144.0 | 同左 |
| API Key | 自己的 DeepSeek API Key | 同左 |
| 网络 | 能访问 `api.deepseek.com`（切换本身不联网） | 同左 |
| 磁盘 | 写入 `~/.codex` 和 `~/.codex/deepseek-switch-backups` | 写入 `%USERPROFILE%\.codex` |
| 权限 | 首次打开 App 需右键 → 打开（未做 Apple 公证） | 首次运行 `.bat` 可能需“解除锁定” |

### 使用前请确认

1. Codex 桌面版已经打开过一次，并完成 ChatGPT 登录。
   这样 `~/.codex/config.toml`（Windows 为 `%USERPROFILE%\.codex\config.toml`）才会存在。
2. 你有一个 DeepSeek API Key。
3. Key 是**一行**，不加引号、不加空格，通常以 `sk-` 开头。
4. 切换完成后，Codex 必须**完全退出再重新打开**。

## 下载

- macOS：[Codex-Switch-mac.zip](Codex-Switch-mac.zip)
- Windows：[Codex-Switch-windows.zip](Codex-Switch-windows.zip)

## macOS 使用

### 方案 A：一键 App（推荐）

1. 解压，打开 `mac/方案A-一键App/Codex Switch.app`。
2. 第一次打开会要求填入自己的 DeepSeek Key，粘贴后点“保存”。
3. 点“切到 DeepSeek”。
4. `⌘Q` 完全退出 Codex，再重新打开。
5. 在模型列表里选择 **DeepSeek-Flash**。

日常：

- 菜单栏常驻图标，点一下切换。
- `⌘1` 切 DeepSeek，`⌘2` 切回 GPT。
- “恢复上次备份”可以回滚。
- 换 Key 后点“刷新 DeepSeek 配置”。

如果 macOS 提示“无法验证开发者”：右键 App → **打开** → 再点一次“打开”。只需做一次。

### 方案 B：命令行

1. 进入 `mac/方案B-命令行/`。
2. 用文本编辑打开 `deepseek/deepseek-key.txt`，把 Key 粘到下一行。
3. `⌘Q` 完全退出 Codex。
4. 双击 `一键安装.command`。
5. 重新打开 Codex，选择 **DeepSeek-Flash**。

第一次运行 `.command` 如果被拦，右键 → 打开。

## Windows 使用

1. 解压，进入 `windows/`。
2. 用记事本打开 `deepseek\deepseek-key.txt`，把 Key 粘到下一行。
3. 双击 **`环境检查.bat`**。确认系统、PowerShell、Codex 配置目录和 Key 都已就绪。
4. 完全退出 Codex / ChatGPT（托盘里也退干净）。
5. 双击 **`一键安装.bat`**。
6. 重新打开 Codex，在模型列表里选择 **DeepSeek-Flash**。

安装后会生成桌面图标：

| 图标 | 作用 |
|---|---|
| 切到DeepSeek | 切到 DeepSeek 通道 |
| 切到GPT | 切回 ChatGPT 登录通道 |
| 一键切换模型 | 自动判断当前通道，切到另一边 |

文件夹里还有：

- `查看当前通道.bat`：只看状态，不改文件。
- `恢复上次备份.bat`：回到上一次切换前。
- `逻辑自检.bat`：用样例文本跑一遍切换逻辑，不碰你的配置。
- `环境检查.bat`：只读检查运行环境。

如果 Windows 提示“来自网络的文件”：右键压缩包或解压后的文件夹 → 属性 → 勾选“解除锁定”。

### 卸载（Windows）

```powershell
powershell -ExecutionPolicy Bypass -File .\CodexSwitch.ps1 -Mode uninstall
```

会停用 DeepSeek 配置并删除桌面图标，`models.json` 保留。

## 第一次使用后的检查

1. Codex 已完全退出并重开。
2. 模型列表里能看到 **DeepSeek-Flash**。
3. 发一句“只回复 OK”，能正常回复。
4. 切回 GPT 后，原来的 GPT 模型名仍然在。
5. 再看一次当前通道，确认状态正确。

## 它到底改了什么

只动 Codex 的用户级配置 `config.toml`：

```toml
model = "deepseek-flash"
model_provider = "deepseek"
model_catalog_json = "/Users/你的用户名/.codex/models.json"
```

以及一段 provider：

```toml
[model_providers.deepseek]
name = "DeepSeek"
base_url = "https://api.deepseek.com/"
wire_api = "responses"
experimental_bearer_token = "你的 Key"
```

切回 GPT 时会移除这三行，并恢复你原来的 GPT 模型名。

它还会：

- 把 `models.json` 安装到 `~/.codex/models.json`，让 Codex 认识 DeepSeek 模型。
- 把每次切换前的配置备份到 `~/.codex/deepseek-switch-backups/`。
- 不修改 `auth.json`，不影响你的 ChatGPT 登录。
- 不修改会话记录、SQLite 数据库或聊天历史。

## 安全说明

- 仓库里没有真实 API Key，只有提示文字。
- 切换工具不会把你的 Key 上传到任何服务器；它只写本机配置。
- 但 Codex 本身需要读取 Key 才能调用 DeepSeek，所以本机 `config.toml` 的 provider 段里是明文。
- 不要把 `~/.codex/config.toml`、`auth.json` 或填好 Key 的程序包发给别人。
- Key 泄露后，去 DeepSeek 后台重新生成一个。

## 常见问题

**切了，但模型列表没有 DeepSeek**

1. 确认 Codex 是 `⌘Q` / 完全退出后重开的，不是只关窗口。
2. 打开“查看当前通道”或 App，确认 `model_provider` 是 `deepseek`。
3. 确认 `~/.codex/models.json` 存在。
4. Codex 客户端版本太旧时可能不认这个模型目录，升级后再试。

**DeepSeek 报 401**

Key 不对、额度用完，或者 Key 里混进了空格/引号。重新填一次 Key，再切一次 DeepSeek。

**macOS 提示无法验证开发者**

右键 App → 打开。未做 Apple 公证，首次需要手动放行一次。

**Windows 双击没反应**

右键文件夹 → 属性 → 解除锁定；或者右键 `.bat` → 以管理员身份运行一次。也可以先跑 `环境检查.bat` 看哪项失败。

**切换后没生效**

Codex 会缓存配置，必须完全退出再打开。Windows 注意托盘里也要退出。

**DeepSeek 连不上**

如果你开了全局代理，检查代理规则是否把 `api.deepseek.com` 也代理了；国内一般直连更稳。

**想彻底恢复**

macOS 用 App 的“恢复上次备份”，或双击 `恢复上次备份.command`。Windows 双击 `恢复上次备份.bat`。

## 目录结构

```text
mac/
├── 使用说明.md
├── 方案A-一键App/
│   └── Codex Switch.app
└── 方案B-命令行/
    ├── 一键安装.command
    ├── 切到DeepSeek.command
    ├── 切到GPT.command
    ├── 查看当前通道.command
    ├── 恢复上次备份.command
    └── deepseek/
        ├── models.json
        └── deepseek-key.txt

windows/
├── 使用说明.md
├── 环境检查.bat
├── 一键安装.bat
├── 一键切换.bat
├── 切到DeepSeek.bat
├── 切到GPT.bat
├── 查看当前通道.bat
├── 恢复上次备份.bat
├── 逻辑自检.bat
├── CodexSwitch.ps1
└── deepseek/
    ├── models.json
    └── deepseek-key.txt
```

## 兼容性与状态

- macOS App 在 macOS 13+ 构建，已在 macOS 26 上实测；切换逻辑覆盖连续往返、备份恢复和模型目录安装。
- Windows 包已在真实 Windows 机器上长期使用，首次安装即可切换。
- 第三方供应商的模型名、接口能力和请求体限制可能变化，发布新版本前应重新验证。

## 许可证

当前未指定开源许可证。如需商用、二次分发或修改后发布，请先联系作者确认。
