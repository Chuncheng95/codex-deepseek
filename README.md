<p align="center">
  <img src="assets/icon.png" width="150" alt="Codex Switch">
</p>

<h1 align="center">Codex Switch</h1>

<p align="center">在 Codex 的模型供应商之间切换。</p>

<p align="center">
  <a href="README.md">中文</a> · <a href="README.en.md">English</a>
</p>

---

Codex Switch 是一个面向 Codex 桌面版的供应商/模型切换器。当前版本支持 **GPT（ChatGPT 登录）** 和 **DeepSeek API**，后续会按同样结构加入更多供应商。

它不是一个通用 API 代理，也不会替你转发请求。它只负责把 Codex 的本地配置切换到你选的供应商，并保留可回滚的备份。

## 当前支持

| 供应商 | 状态 | 说明 |
|---|---|---|
| GPT / ChatGPT 登录 | 已支持 | 使用 Codex 内置的 openai provider |
| DeepSeek API | 已支持 | 写入 DeepSeek provider、模型和模型目录 |
| MiniMax | 计划中 | 需要确认是否提供 Responses 兼容接口 |
| 自定义 provider | 计划中 | 手动填写 base_url、模型和 Key |

> Codex 目前只支持 `wire_api = "responses"`。如果某个供应商只有 Chat Completions 接口，需要中间加一个 Responses 兼容网关，Codex 才能使用。

## 运行环境

**不需要 Python、Node.js 或 Docker。**

| 项目 | macOS | Windows |
|---|---|---|
| 操作系统 | macOS 13 Ventura 或更新 | Windows 10 / 11（64 位） |
| 运行环境 | 系统自带，无额外依赖 | 系统自带 PowerShell 5.1，无需安装 |
| Codex | 已安装桌面版，并用 ChatGPT 登录过至少一次 | 同上 |
| 客户端版本 | 建议较新版本；模型目录要求 ≥ 0.144.0 | 同左 |
| API Key | 自己的 DeepSeek API Key | 同左 |
| 网络 | 能访问 `api.deepseek.com`；切换动作本身不联网 | 同左 |
| 磁盘 | 写入 `~/.codex` 与 `~/.codex/deepseek-switch-backups` | 写入 `%USERPROFILE%\.codex` |
| 权限 | App 未公证，首次右键 → 打开 | 首次运行可能需“解除锁定” |

Key 必须是一行，不加引号、不加空格，通常以 `sk-` 开头。

## 下载

- macOS：[Codex-Switch-mac.zip](Codex-Switch-mac.zip)
- Windows：[Codex-Switch-windows.zip](Codex-Switch-windows.zip)

## macOS：两套方案

### 方案 A：一键 App（推荐）

1. 解压，打开 `mac/方案A-一键App/Codex Switch.app`。
2. 第一次打开，填入自己的 DeepSeek Key，点“保存”。
3. 点“切到 DeepSeek”。
4. `⌘Q` 完全退出 Codex，再重新打开。
5. 在模型列表里选择 **DeepSeek-Flash**。

日常可以点菜单栏图标切换，或按 `⌘1` / `⌘2`。切错了用“恢复上次备份”。

首次打开如果提示“无法验证开发者”：右键 App → **打开** → 再点一次“打开”。

### 方案 B：命令行

1. 进入 `mac/方案B-命令行/`。
2. 把 Key 粘到 `deepseek/deepseek-key.txt` 的下一行。
3. `⌘Q` 完全退出 Codex。
4. 双击 `一键安装.command`。
5. 重新打开 Codex，选择 **DeepSeek-Flash**。

详细说明见 [mac/使用说明.md](mac/使用说明.md)。

## Windows

1. 解压，进入 `windows/`。
2. 用记事本把 Key 粘到 `deepseek\deepseek-key.txt` 的下一行。
3. 双击 `环境检查.bat`，确认系统、PowerShell、Codex 配置和 Key 就绪。
4. 完全退出 Codex / ChatGPT（托盘里也退干净）。
5. 双击 `一键安装.bat`。
6. 重新打开 Codex，选择 **DeepSeek-Flash**。

安装后桌面会有：切到DeepSeek、切到GPT、一键切换模型。

如果提示“来自网络的文件”：右键文件夹 → 属性 → 勾选“解除锁定”。

详细说明见 [windows/使用说明.md](windows/使用说明.md)。

## 第一次使用后的检查

1. Codex 已完全退出并重开。
2. 模型列表里能看到 **DeepSeek-Flash**。
3. 发一句“只回复 OK”，能正常回复。
4. 切回 GPT 后，原来的 GPT 模型名仍然在。
5. 再看一次当前通道，确认状态正确。

## 它改了什么

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

- 安装对应供应商的模型目录。
- 每次改动前备份到 `~/.codex/deepseek-switch-backups/`。
- 不修改 `auth.json`、会话记录或数据库。

## 安全

- 仓库里没有真实 Key，只有提示文字。
- 切换器不会上传 Key；它只写本机配置。
- Codex 本身要读取 Key 才能调用 API，所以本机 `config.toml` 里会是明文。
- 不要把 `config.toml`、`auth.json` 或填好 Key 的包发给别人。

## 常见问题

**切了但模型列表没有 DeepSeek**

确认 Codex 是完全退出后重开的；确认当前 provider 是 deepseek；确认 `~/.codex/models.json` 存在；客户端太旧就升级。

**DeepSeek 报 401**

Key 不对、额度用完，或混进了空格/引号。重新填 Key 再切一次。

**macOS 提示无法验证开发者**

右键 App → 打开。未做 Apple 公证，首次需要放行一次。

**Windows 双击没反应**

右键文件夹 → 属性 → 解除锁定；或先跑 `环境检查.bat` 看哪项失败。

**切换后没生效**

必须完全退出 Codex 再打开。Windows 注意托盘里也要退出。

**DeepSeek 连不上**

如果开了全局代理，检查是否把 `api.deepseek.com` 也代理了；国内一般直连更稳。

## 后续多供应商结构

下一版会把写死的 DeepSeek 逻辑拆成 provider 清单：

```text
providers/
├── deepseek.toml
├── minimax.toml
└── custom.toml

catalogs/
├── deepseek.json
└── minimax.json
```

每个 provider 描述自己的 `base_url`、`wire_api`、模型、catalog 和 Key 字段。App 和 Windows 脚本都从清单读取，不再为每个供应商写一套逻辑。

本机状态会集中到：

```text
~/.codex/codex-switch/
├── state.json
├── keys/<provider>
├── catalogs/<provider>.json
└── backups/
```

## 目录结构

```text
mac/
├── 使用说明.md
├── 方案A-一键App/
└── 方案B-命令行/
windows/
├── 使用说明.md
├── 一键安装.bat
├── 一键切换.bat
├── 环境检查.bat
└── CodexSwitch.ps1
Codex-GPT-DeepSeek-切换指南.md
README.en.md
assets/icon.png
```

## 兼容性与状态

- macOS App 在 macOS 13+ 构建，已在 macOS 26 上实测。
- Windows 包已在真实 Windows 机器上长期使用，首次安装即可切换。
- 第三方供应商的模型名、接口能力和请求体限制可能变化，发布新版本前应重新验证。

## 许可证

当前未指定开源许可证。如需商用、二次分发或修改后发布，请先联系作者确认。
