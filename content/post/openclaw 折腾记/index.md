---
title: openclaw 折腾记
date: 2026-11-19
draft: true
tags:
    - OpenClaw
    - GLM
    - 免费API
image: https://image.tinkerlog.dpdns.org/2026/11/2026-11-19-1742-cover.jpg
---
> **写在前面**：本文记录了我从零配置 OpenClaw 到最终与智谱免费档「并发 1」达成和解的全过程。如果你也是学生、想用免费 API、不想实名，希望这篇能帮你少走十个小时的弯路。

## 一、起因：为什么是 OpenClaw

事情要从一个免费虚拟主机(放在评论区啦)说起。我在 `cpanel.free-hosting.org` 上搭了个 phpBB 论坛，域名是 `xiaowo.yzz.me`（「小窝」的拼音，当时觉得这名字挺温和，不像「折腾空间」那么硬）。论坛搭好后，我想找个 AI 助手帮忙管理——整理帖子、回复常见问题、偶尔写点公告。(好吧,在吃灰)

市面上能选的东西不少：Ollama 本地跑、各种云 API、还有那种「一键接入」的 SaaS。我选 OpenClaw 的原因就两个：**能读我的文件、能执行命令**。这意味着它能真正帮我干活，而不是只能聊天。

但我也知道免费的东西都有代价。只是当时没想到，代价会是「并发 1」。

## 二、第一天晚上：从 8 点到凌晨的限流之战

### 2.1 配置过程（现在看很简单，当时走了两小时）

OpenClaw 的向导比我想象的友好。选 `Custom Provider`，填智谱的 `baseUrl`、粘 API key、选模型 `glm-4.7-flash`。key 是去 `open.bigmodel.cn` 注册的，手机号就行，不用身份证——这一点后来变得很重要。

配置写完，网关启动，我打开 `http://127.0.0.1:18789`，发了一句「你好」。

它回了，中文，流畅。当时我觉得成了。

### 2.2 第一个坑：它说看不到图

我想让它看一张论坛后台的截图，问「这个页面上有什么」。它回：「抱歉，我当前无法直接查看图片内容。」

我以为是图没传上去。查工作目录，发现图确实在 `D:\dev\openclaw-workspace\input-xxx.png`，238 KB，时间戳对得上。

后来才发现：**我忘了切模型**。`glm-4.7-flash` 是纯文本模型，给它图它真的当没看见。智谱的免费视觉模型是 `glm-4.6v-flash`，并发也是 1，要单独在配置里加一个 provider 条目。

加完之后，图能看了，中文描述也准。但新问题来了。

### 2.3 真正的噩梦：Rate-limit recovery stopped after 9 automatic retries

这句话我大概见了二十次。意思是：它自动重试了 9 次，每次都撞在限流上，于是放弃。

智谱免费档的并发是 **1**。不是每分钟 60 次，不是每天 1000 次，是**同一时刻只能有一个请求正在处理**。而 OpenClaw 的 Agent 任务一轮要往返三四次——问工具、拿结果、再问、再总结。每一轮都得等前一轮彻底结束。

我当时在晚八点，正是高峰期。平台上还有 `1305` 过载保护，跟你无关，纯粹是人多。

我试过重启网关、关掉所有标签页、清会话历史，甚至把 `BOOTSTRAP.md` 都挪走了。预算从 45% 降到 40%，但并发还是 1。

## 三、换平台：一条条路被堵死

### 3.1 硅基流动：要实名，由于某些原因我无法实名

硅基流动注册送 2000 万 token，`Qwen/Qwen3-8B` 永久免费，并发是千级 RPM。看起来完美。

但它从 2026 年 5 月 15 日起强制实名认证。我用不了，支付宝扫脸和身份证核验都走不通。这不是技术问题，是硬性规定。

### 3.2 Groq：地区封锁，连注册页都进不去

Groq 的免费档更夸张：30 RPM、日 14400 次请求，LPU 芯片跑出来每秒几百 token。注册只要邮箱，不要手机，不要卡。

但我连 `console.groq.com` 都打不开。`api.groq.com` 和官网 `groq.com` 是两套 CDN 规则，官网能开，API 和控制台一律 403。测试命令跑出来：

```powershell
Test-NetConnection api.groq.com -Port 443
# TcpTestSucceeded : True
```

能连上，但返回 `{"error":{"message":"Forbidden"}}`。Cloudflare 在 API 之前就拦了，请求根本没到 Groq 的业务层。

### 3.3 Cloudflare Workers AI：额度太小，同样有地区问题

每天 1 万 Neurons，约 4.9 万输出 token。看起来够用，但 `api.cloudflare.com` 在国内访问不稳定，而且额度对于 Agent 任务来说还是太紧。

## 四、本地模型：兜了一圈又回来

既然云端都走不通，我想起机器上那套 llama.cpp。之前装过 Holo 3.1 4B 用来识图，跑出来 5.6 t/s，纯 CPU。

我试了 Ollama 的 `qwen3:4b`，中文原生，速度能到 8-15 t/s。它不需要实名、不需要联网、没有并发限制、不花钱。

但它做不了 Agent 任务。工具调用对模型的要求比聊天高得多，4B 模型在这种场景下会自信地做错——它不会说「我不确定」，而是生成一个看起来合理的命令，然后执行。在 Windows 上，一条写错的 `Remove-Item` 也能把东西删掉。

更麻烦的是上下文。4B 模型的上下文窗口通常是 32K，而 OpenClaw 的 `coding` 档光工具定义就占几万 token——模型还没看到你的问题，预算就用完了。

所以我把它定位成**纯聊天通道**，不给文件读写和命令执行权限。需要动手时，还是用云端的 4.7。

## 五、最终和解：与并发 1 共处的三条习惯

折腾到最后，我发现真正能用的还是智谱那条路。免费、不实名、200K 上下文、中文流利。并发 1 绕不开，但可以和它共处。

### 5.1 自己跑命令，只让它判断

列目录、看文件前几十行这类事，我自己 PowerShell 跑完贴给它，一轮请求就能拿到答案。让它自己去 `tool_search` → `exec` → 总结，三轮都得排队。

```powershell
Get-ChildItem "D:\dev\openclaw-workspace" | Select-Object Name, Length
```

把输出粘进对话框，问「这些文件分别是干什么的」。它不用调工具、只做一轮文本生成，几乎不会撞限流。

### 5.2 一件事一个会话

上下文越大，每次请求越慢。`BOOTSTRAP.md` 跑完后我就把它挪走了，清掉旧会话，开新的。`tools.profile` 平时设成 `messaging`，要读文件时再临时调回 `coding`。

### 5.3 避开高峰时段

中午和晚八点是真的挤。同样的操作，早上九点或者晚上十点半之后会顺很多。这不是安慰话，`1305` 的出现频率确实随负载波动。

## 六、配置清单（直接抄）

### 6.1 openclaw.json 核心段落

```json
{
  "models": {
    "providers": {
      "custom-open-bigmodel-cn": {
        "baseUrl": "https://open.bigmodel.cn/api/paas/v4",
        "api": "openai-completions",
        "timeoutSeconds": 180,
        "models": [
          {
            "id": "glm-4.7-flash",
            "name": "glm-4.7-flash (Custom Provider)",
            "contextWindow": 128000,
            "maxTokens": 32768,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "reasoning": false
          },
          {
            "id": "glm-4.6v-flash",
            "name": "GLM-4.6V-Flash (vision)",
            "contextWindow": 128000,
            "maxTokens": 32768,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "reasoning": false
          }
        ]
      }
    }
  },
  "tools": {
    "profile": "coding"
  },
  "agents": {
    "defaults": {
      "workspace": "D:\\dev\\openclaw-workspace",
      "model": "custom-open-bigmodel-cn/glm-4.7-flash@custom-open-bigmodel-cn:setup-xxxxx"
    }
  }
}
```

### 6.2 USER.md（我的偏好）

```md
# USER.md - User Model

<!-- observed: 2026-11-18 | status: active -->

- Always respond in Simplified Chinese unless asked otherwise.
- Prefer short, direct answers over lengthy explanations.
- Always ask a clarifying question when the request is ambiguous rather than guessing.
- Never delete files outside `D:\dev\openclaw-workspace` without explicit confirmation.

<!-- observed: 2026-11-18 | status: active -->

- The user is a student learning AI tooling on a Windows machine.
- Prefer PowerShell 5.1 compatible commands.
- Prefer commands that work without administrator privileges.
```

## 七、一些数字

| 项目 | 数值 |
| --- | --- |
| 智谱 glm-4.7-flash 并发 | 1 |
| 智谱 glm-4.6v-flash 并发 | 1 |
| 硅基流动 Qwen3-8B 并发 | 1000+ RPM（要实名） |
| Groq 免费档 TPM | 6000（地区封锁） |
| 本地 qwen3:4b 速度 | 8-15 t/s（纯聊天） |
| 我的会话上下文预算 | 48.6k / 108k（清理后） |
| 折腾总时长 | 约 16 小时 |

## 八、结论

如果你也是不想实名、在国内，**智谱是目前(可能)唯一能走通的路**。并发 1 是硬约束，但可以通过用法优化来规避。

真正有价值的不是一套完美的配置，而是**拿一件具体的小事让它做**。我让它整理过论坛后台的 DLL 文件列表，它准确说出了每个文件的用途；让它读课件 PDF，它能提取要点。做成之后，你就知道这套工具值不值得继续投入。

至于那些「更好的平台」——要么实名、要么封锁、要么额度太小。**免费资源的供给就这样，承认这一点，才能开始真正用它干活。**

> **最后**：感谢读到这里的你。如果这篇帮你少走了弯路，或者你找到了我没发现的免费通道，欢迎在评论区告诉我。
