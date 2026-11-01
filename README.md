# dsh-taoyuan-profile

把一台机器上正常工作的 [DeepSeek Harness](https://github.com/deepseek-ai) 桌面端**配置层**搬到另一台机器：
profile 补丁（模型 / 界面 / 工具配置）+ 一份钉死版本的插件清单 + 两个可以重复运行的 PowerShell 脚本。

只动 `%USERPROFILE%\.dsh\profiles\<profile>\`，不碰 DSH 应用本体，也不需要反编译或改 `app.asar`。

## 包含什么 / 不包含什么

| 内容 | 是否在本仓库 |
| --- | --- |
| `cordis.patch.yml`（profile 补丁：默认模型、界面、subagent 白名单、web 搜索/抓取提供方、provider 环境变量名） | ✅ `profile/cordis.patch.yml` |
| 插件清单与精确版本（npm 版本号 / GitHub 提交） | ✅ `plugins.json` |
| 安装与核对脚本 | ✅ `install.ps1`、`verify.ps1` |
| API 凭据、登录态 | ❌ DSH 的 `.credentials.yaml` 是本地密钥库，安装后重新登录 |
| 会话历史、工作区记录、缓存 | ❌ 属于个人数据，不打包 |
| 自定义 agent 预设（`.agent-presets/`） | ❌ 未收录；需要时自行复制整个目录 |
| DSH 应用本体、`node_modules` | ❌ 由官方安装包和 `dsh plugin` 提供 |

## 前置条件

- 已安装 DSH 桌面端，且**至少启动过一次**（这样 `~/.dsh/profiles/desktop` 才会存在——`dsh plugin` 不会替你建 profile）。
- `dsh` 命令在 PATH 中。桌面端自带的 CLI 位于 `<安装目录>\resources\runtime\cli\bin\dsh.cmd`，把它所在目录加进 PATH 即可。
- 能访问 npm 与 GitHub（清单里 18 个从 npm 装，5 个从 GitHub 装）。
- PowerShell 5.1 或更高版本。

## 安装

```powershell
git clone https://github.com/2757657887/dsh-taoyuan-profile.git
cd dsh-taoyuan-profile
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

脚本按顺序做三件事：

1. 检查 `dsh` 与目标 profile 是否存在（缺失直接报错，不做猜测性创建）。
2. 备份已有的 `cordis.patch.yml` 为 `cordis.patch.yml.bak-<时间戳>`，再用本仓库的版本覆盖。
3. 按 `plugins.json` 逐个执行 `dsh plugin --profile desktop add <spec>`，失败的插件收集到末尾汇总，不中断其余安装。

可选参数：`-ProfileName <名字>`（默认 `desktop`）、`-SkipPatch`（只装插件不改配置）、`-DryRun`（只打印命令）。

安装完成后**完全退出并重启 DSH**，配置补丁和插件都在启动时加载。

## 安装后还需要你补的

1. **重新登录**：DSH 的账号与 API 凭据在 `.credentials.yaml`，不在仓库里。
2. **环境变量 `OPENCODE_GO_API_KEY`**：补丁把默认模型设为 `opencode-go / deepseek-v4.1-flash`，该 provider 从环境变量读密钥。想用别的模型请改 `profile/cordis.patch.yml` 里的 `agent-default-model`。
3. **自定义预设（可选）**：原机有 `liangshen`、`router-spec`、`router-standard`、`weneed` 四个预设，位于 `~/.dsh/.agent-presets/`，整目录复制过去即可。
4. **按需微调**：`ui-settings-account` 里的 `developerTools: true`、`usage: detailed` 等开关，进设置页确认一遍最省事。

## 核对安装结果

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1
```

逐行对比「清单版本 vs 实际安装版本」，并检查 `dsh.profile.bundles` 里的 bundle 是否齐全；有不一致时退出码为 1。

### 这套流程实测过

2026-11-01 在一个**全新空 profile**（只含 `@deepseek-ai/dsh-base` 与 `@deepseek-ai/dsh-web-app`，无任何插件）上完整跑了一遍：

- `install.ps1`：23 个插件全部安装成功，版本与 `plugins.json` 完全一致；5 个 GitHub 源在首轮出现 `ECONNRESET` / `ETIMEDOUT` 重试，pnpm 自动重试后成功（网络不佳时可能要重跑脚本）。
- `cordis.patch.yml`：写入后与仓库版本哈希一致。
- `verify.ps1`：输出「插件与清单一致」，退出码 0。
- 唯一差异是三个应用内置的实验特性 bundle（`dsh-experimental-agent-team-profile`、`dsh-experimental-auto-review`、`dsh-experimental-inspector-profile`）不在新 profile 的 bundle 列表里——这些由 DSH 自身开关控制，脚本只提示、不强行写入。

## 插件清单

| 插件 | 版本 / 来源 | 用途 |
| --- | --- | --- |
| `@changfenhuang/dsh-genui` | `0.15.0` | 结构化 UI 渲染 |
| `@linxin666/dsh-client-ui-git-graph` | `0.4.12` | Git 图谱 |
| `@liustack/modsearch` | `5.10.11` | 网页/搜索桥 |
| `@michengai/dsh-archive-manager` | `1.1.22` | 会话归档管理 |
| `@nanmicoder/dsh-agent-teams` | `0.1.28` | 多代理团队 |
| `@sakura12/oh-my-deepseekharness` | `0.7.0` | omd 编排层 |
| `@xmanrui/dsh-im` | `5.8.0` | IM 通道 |
| `beauticode-dsh` | `1.0.30` | 页面背景/主题 |
| `billion-context` | `0.1.209` | 上下文压缩 |
| `dsh-better-sidebar` | `0.28.2` | 侧栏增强 |
| `dsh-collapse-paste` | `0.2.4` | 粘贴折叠 |
| `dsh-context` | `0.78.2` | 上下文面板 |
| `dsh-git-plus` | `0.1.59` | Git 工具增强 |
| `dsh-ops` | `0.4.4` | OPS 工具面（bash/grep 等） |
| `dsh-remote` | `0.8.67` | 远程工作区 |
| `dsh-session-recycle-bin` | `0.5.0` | 会话回收站 |
| `dsh-whale-widget` | `0.4.2` | 桌面挂件 |
| `dshmarket` | `1.73.3` | 插件市场 |
| `@guowenzhang/dsh-claude-compat` | `github:zhang-guo-wen/dsh-claude-compat#2599e56` | Claude 兼容层 |
| `dsh-think-budget` | `github:superSizzzz/dsh-think-budget#fc9f7db` | 思考预算控制 |
| `dsh-chat-perf-css` | `github:Light-EI/dsh-chat-perf-css#a50b57d` | 聊天渲染性能 |
| `dsh-right` | `github:iMankoppai/dsh-right#570116c` | 右侧栏面板 |
| `dsh-scm` | `github:2757657887/dsh-scm#6c9dfb6` | VS Code 风格源代码管理 |

五个插件用 GitHub 提交而不是 npm 版本，原因是原机装的就是仓库快照：`dsh-chat-perf-css`、`dsh-right`、`dsh-think-budget` 没有发布到 npm；`@guowenzhang/dsh-claude-compat` 虽有 npm 版本（1.3.0）但与本地提交不一定一致，所以同样钉死提交；`dsh-scm` 是本仓库作者的插件，仓库自带构建产物，安装后无需再构建。

## 配置补丁说明

`profile/cordis.patch.yml` 是 profile 的补丁层，逐条覆盖 bundle 默认值：

| 条目 | 改了什么 |
| --- | --- |
| `agent-default-model` | 默认模型 `opencode-go / deepseek-v4.1-flash`，`reasoningEffort: high` |
| `ui-chat` | `transcriptView: standard`、`performanceUsage: detailed` |
| `ui-settings-account` | 开发者工具、用量明细、`completion: api-key` |
| `subagent-model-selection-settings` | 子代理可选模型限定为 `deepseek-official/deepseek-flash` 与 `deepseek-account/deepseek-flash` |
| `web` | 搜索走 `deepseek-search-api`，抓取走 `deepseek-fetch-api` |
| `llm-pi-ai` | `providers.opencode-go.apiKeyEnv: OPENCODE_GO_API_KEY` |
| `ui-settings-general` | `welcomeNoticeVersion`（文件末尾有一条重复条目，是原机历史残留，保留以保证逐字一致） |

## 手工安装（不用脚本）

```powershell
dsh plugin --profile desktop add @changfenhuang/dsh-genui@0.15.0
dsh plugin --profile desktop add dsh-scm@github:2757657887/dsh-scm#6c9dfb60066ef4743caed42c2c050735b3024b67
# ……其余条目见 plugins.json
```

注意：`dsh plugin` 背后是 `pnpm -C <profile 目录>`，因此**相对路径会按 profile 目录解析**，本地路径一律写绝对路径；`add` 会自动把包名写进 `dsh.profile.bundles`，不需要手工编辑。

## 回滚

- 配置：把 `cordis.patch.yml.bak-<时间戳>` 复制回 `cordis.patch.yml`，重启 DSH。
- 插件：`dsh plugin --profile desktop remove <包名>`（会同时从 `dsh.profile.bundles` 移除）。

## 已知限制

- 插件版本是**钉死的**，上游更新不会自动跟随；换版本直接改 `plugins.json` 后重跑安装脚本。
- DSH 自身版本变化可能让补丁条目失效（条目 id 来自内置 bundle）。本仓库实测于 `dsh-desktop 0.2.1-rc.5`（electron 44.7.0 / node 24.21.0）。
- 本仓库只覆盖 Windows 路径写法的脚本；插件本身跨平台，但脚本按 PowerShell 编写。

## 许可

脚本与文档为 MIT；各插件版权归各自作者。
