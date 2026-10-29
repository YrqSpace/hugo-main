---
title: 给博客接上 Giscus 评论，结果栽在无刷新跳转上
date: 2026-09-26
slug: 博客评论系统折腾记
image: https://gcore.jsdelivr.net/gh/YrqSpace/hugo-pic-bed@main/2026/09/2026-09-26-cover.jpg
tags:
    - Giscus
    - 评论系统
    - Hugo
    - 独立博客
description: 用 Giscus 给纯静态博客加上评论，踩坑全在 PJAX 无刷新跳转——评论区换页不重新加载。
---

## 为什么选 Giscus

纯静态博客没有后端，评论只能靠第三方。常见的几个方案我都看了一遍：

| 方案 | 数据存在哪 | 要不要后端 | 我的顾虑 |
| --- | --- | --- | --- |
| Giscus | GitHub Discussions | 不用 | 访客得登录 GitHub |
| Waline | 自己的数据库 | 要 | 得买服务器或云函数 |
| Disqus | 厂商服务器 | 不用 | 国内访问慢，还挂广告 |
| 自建评论 | 自己管 | 要 | 维护成本直接翻倍 |

选 Giscus 的理由很直接：**它把评论存进 GitHub Discussions，我不用买任何服务器，数据还留在自己仓库里**，哪天不想用了，评论也不会跟着跑掉。

缺点也认了——访客必须登录 GitHub 才能评论。对技术类博客来说勉强能接受，反正读者大概率本来就有账号。

## 第一步：把仓库和 Discussions 准备好

Giscus 的评论不是存在 issue 里，而是 **Discussions**，这两者别搞混。

1. 新建一个仓库专门放评论，我建的是 `YrqSpace/Giscus`（公开仓库，私有仓库 Giscus 读不到）
2. 进仓库 **Settings → General → Features**，把 **Discussions** 勾上
3. 在这个仓库的 Discussions 里建一个分类，我用的是 `Announcements` 类型

第 3 步的分类很关键，后面配置要引用它的 ID。

## 第二步：装 Giscus App

光有仓库不够，还要让 Giscus 有权限往你的 Discussions 里写。去 [github.com/apps/giscus](https://github.com/apps/giscus) 安装，授权范围选刚才那个评论仓库就行，不用给全账号权限。

## 第三步：在 giscus.app 拿到配置

打开 [giscus.app](https://giscus.app)，填仓库名 `YrqSpace/Giscus`，它会自动校验并给出四个值：

```
data-repo="YrqSpace/Giscus"
data-repo-id="R_kgDOUhG6JA"
data-category="Announcements"
data-category-id="DIC_kwDOUhG6JM4DF78m"
```

`repo-id` 和 `category-id` 这两串看着像乱码的东西别手抄，直接从页面复制，抄错一个字符评论区就是空白。

**映射方式（mapping）**我选了 `pathname`，也就是按 URL 路径区分文章。这样同一篇文章换标题不会丢评论，缺点是改 slug 会变成新的一页。

## 第四步：写进 Hugo 配置

Stack 主题原生支持 Giscus，不用自己拼 HTML，在 `hugo.yaml` 里填就行：

```yaml
comments:
    enabled: true
    provider: giscus
    giscus:
        repo: YrqSpace/Giscus
        repoID: R_kgDOUhG6JA
        category: Announcements
        categoryID: DIC_kwDOUhG6JM4DF78m
        mapping: pathname
        strict: 0
        reactionsEnabled: 1
        emitMetadata: 0
        inputPosition: top
        lightTheme: light
        darkTheme: dark
        lang: zh-CN
```

几个参数值得说一下：

- `strict: 0`：按 pathname 模糊匹配，找不到对应 discussion 时自动新建
- `inputPosition: top`：输入框放最上面。默认在底部，读者看完评论还得往下滚才能说话，体验很差
- `lightTheme` / `darkTheme`：跟着主题的明暗模式自动切换，这里填的是 Giscus 内置主题名
- `lang: zh-CN`：界面文案中文化

改完跑一遍 `hugo`，推上去，评论区就出来了。

## 真正的坑：PJAX 换页后评论不刷新

到这里按理说就完事了。但我的站点开了无刷新跳转（PJAX），第一次点进文章评论区正常，**再点另一篇文章，评论还是上一篇的**，得手动刷新整页才对。

原因不难想：PJAX 换页只是把 `.main-container` 的 HTML 替换掉，**里面的 `<script>` 不会被浏览器重新执行**。Giscus 的客户端脚本是 `<script src="https://giscus.app/client.js">`，它在首次加载时把评论 iframe 注入进去，换页后这段脚本躺在新 HTML 里但没人去跑它，评论区自然一片空白或者残留旧内容。

### 修法：换页后手动重建脚本

思路很笨但有效——**换页时把旧的 giscus 脚本和 iframe 全删掉，再重新插一个新的 `<script>`**，浏览器看到新的 script 元素就会去执行。

我改了主题的 `footer/pjax.html`，大致流程：

1. 首次加载时把 giscus 的配置存到 `window.__giscusConfig`，免得换页后拿不到
2. 监听 `pjax:complete`，检查新页面里还有没有评论区（`.giscus` 或 `#comments`）
3. 有的话，先删掉旧的 iframe、旧 script 节点
4. 新建一个 script，把 `data-repo`、`data-repo-id`、`data-category`、`data-category-id`、`data-mapping` 等属性全挂上去
5. 暗色模式下顺手把 `data-theme` 设成 `dark`，在 `document.documentElement.dataset.scheme === "dark"` 时判断

代码本质就是这段：

```js
function reloadGiscus() {
    var host = document.querySelector('.giscus');
    if (!host) return;                      // 这页没评论区，什么都不做
    host.innerHTML = '';                    // 清掉旧的 iframe
    var old = document.querySelector('script[src*="giscus.app/client.js"]');
    if (old) old.remove();                  // 清掉旧脚本，否则新脚本插进去也不会跑
    var s = document.createElement('script');
    s.src = 'https://giscus.app/client.js';
    s.setAttribute('data-repo', cfg.repo);
    s.setAttribute('data-repo-id', cfg.repoId);
    // ……其余 data-* 属性照抄
    s.setAttribute('data-loading', 'lazy');
    document.body.appendChild(s);
}
document.addEventListener('pjax:complete', reloadGiscus);
```

关键就在**把旧 script 删掉**这一步。只替换 iframe 不删脚本，浏览器会认为这个脚本"已经加载过了"，不会重新执行，白忙一场。

## 顺手解决的两个小问题

调试过程中还发现两件事，一起记下来：

**一是评论区出现重复。** PJAX 回调如果触发了两次，就会插两个 script，页面上出现两个评论框。加一个标记位判断当前是不是已经有实例，重复调用直接 return。

**二是暗色主题不跟随。** Giscus 的主题是在脚本加载那一刻定死的，站点切换暗色它不会自己变。要么监听主题切换再重建一次，要么就在 iframe 上做透明度适配。我选了前者，反正重建的代码已经写好了，复用一下就行。

## 小结

Giscus 本身接起来十分钟的事，配置四个值、写进 `hugo.yaml` 就完事。真正花时间的是 **PJAX 和第三方脚本的兼容**——凡是靠 `<script>` 注入的第三方组件（评论、统计、分享按钮），在无刷新的站点上都要单独处理一遍。

记住那条规则就行：**换页后要重跑脚本，必须先删旧 script 节点，再插新的**。

> 参考：[giscus.app](https://giscus.app) 官方配置页
