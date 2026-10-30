---
title: Waline 评论系统折腾记：自托管、字体和 PJAX 的三重坑
date: 2026-10-30
slug: Waline评论系统折腾记
image: https://gcore.jsdelivr.net/gh/YrqSpace/hugo-pic-bed@main/2026/10/2026-10-30-waline-cover.jpg
description: 把评论从 Giscus 换成 Waline，服务端跑在 Vercel 上。真正花时间的不是部署，而是自托管客户端、10px 的评论字号，以及 PJAX 换页后评论框集体失联。
tags:
    - Waline
    - 评论系统
    - Hugo
    - PJAX
    - 独立博客
---

## 为什么从 Giscus 换过来

上一篇写的是 Giscus，那篇文章结论还挺满意：评论存 GitHub Discussions，不用买服务器，数据在自家仓库里。

用了一段时间，问题慢慢浮出来——**门槛全在读者那边**。想留句话，得先有 GitHub 账号，还得授权一个 App，中间但凡卡一步就放弃了。我自己拿手机试了一遍，光是登录那一段就想关掉页面。

Waline 的路子不一样：评论存在自己的数据库里，访客只需要填个昵称，想匿名也行。代价是得有个后端，这对纯静态博客来说是笔额外开销，所以第一轮选型时我把它排掉了。

后来还是绕回来了。原因很朴素——**评论区如果没人愿意留言，那它再"优雅"也没意义**。

| 对比项 | Giscus | Waline |
| --- | --- | --- |
| 访客门槛 | 必须有 GitHub 账号 | 填昵称即可 |
| 数据在哪 | GitHub Discussions | 自己的数据库 |
| 要不要后端 | 不用 | 要（我用 Vercel） |
| 挂掉风险 | 跟 GitHub 共存亡 | 看自己维护 |

## 第一步：把服务端立起来

Waline 是前后端分离的，`@waline/client` 只是那个评论框，真正存数据的是服务端 `@waline/vercel`。

部署本身没什么可说的，Vercel 一键模板导入，连上数据库，环境变量填完就起来了。我给它绑了个自己的域名，也就是现在配置里那个 `serverURL`：

```yaml
waline:
    serverURL: https://yrq1622.cc.cd
    lang: zh-CN
```

这一步唯一想提醒的是：**`serverURL` 千万别带结尾斜杠**。带上了也能跑，但请求路径会拼出双斜杠，某些环境下会被 CDN 或反向代理吃掉，症状是评论能读、写不进去，排查起来非常折磨。

服务端起来之后，第一件事是用浏览器直接打开那个地址——正常的话会看到一个 Waline 自带的欢迎页，说明后端活着、数据库也连上了。**先确认后端，再动前端**，这个顺序能省掉后面一大半的怀疑。

## 第二步：客户端不引 CDN，改成自托管

常规做法是在页面里引一段 CDN 的 `waline.js`。我没这么做，原因是这站的评论区本来就依赖 JS 加载，如果 CDN 抽风，评论框就是一块空白，还不报错，用户只会以为"这站没评论功能"。

所以我把客户端整个搬进了站内：

```text
static/vendor/waline/
├── waline.css   22 KB
└── waline.js   257 KB
```

代价是仓库多了 280KB，好处是**评论框的加载不再依赖任何第三方**，跟正文、样式同源同域，一次握手全解决。

引的时候用动态 `import()` 而不是 `<script>` 标签：

```js
window.__walineModulePromise = import(WALINE_URL);
```

这一行的关键在于**只初始化一次**。`import()` 对同一 URL 是天然幂等的（模块只求值一次），把 Promise 存在全局，PJAX 换页时直接复用，既不会重复下载，也不会重复求值。

## 坑一：评论字号只有 10px

这是最莫名其妙的一个。评论框装上去之后，正文是 16px，评论区却小得离谱，像浏览器缩放过一样。

原因藏在主题的 CSS 里：

```css
html { font-size: 62.5%; }   /* 1rem = 10px */
```

主题为了好算尺寸，把根字号压到了 62.5%。而 Waline 的默认值是 `--waline-font-size: 1rem`——于是评论字号老老实实跟着变成了 10px。

修法不是去改主题（改了就等着下次更新被覆盖），而是**在评论容器上把变量重新指回正文的字号**：

```css
.waline-container {
    --waline-font-size: var(--article-font-size, 1.6rem);
}
```

`--article-font-size` 是主题给正文用的变量，窄屏 16px、宽屏 17px，Waline 跟着它走，就再也不会脱节。

顺便说一句，我这里是**用自己的 partial 覆盖主题模板**，而不是直接动 `themes/` 里的文件。这个习惯很重要——主题一升级，所有改在 `themes/` 里的东西都会被打回原形，而覆盖文件是站点的资产，不会被冲掉。

## 坑二：输入框和按钮的字体不对

字号修好之后，问题变成了"字体看着别扭"。

Waline 自身的 CSS 只给 `.wl-editor`、`.wl-btn` 这些配置了颜色和间距，**没配 `font-family`**。而 `<input>`、`<textarea>`、`<button>`、`<select>` 这类表单控件在浏览器里有个天然特性：**它们不会从父元素继承字体**，不给就退回系统默认的 UI 字体。

于是正文是思源、输入框是系统 UI 字体，一眼就能看出是两套东西。

解法很土但有效，把这四类控件统一强制继承：

```css
.waline-container,
.waline-container input,
.waline-container textarea,
.waline-container button,
.waline-container select {
    font-family: var(--article-font-family, var(--base-font-family));
}
```

`.waline-container` 自己也要写上——因为评论内容区的正文是它渲染的。

## 坑三：PJAX 换页后评论框失踪

这站开了 PJAX，点站内链接不整页刷新，只替换 `.main-container`。

对评论系统来说这是灾难：**新页面的 HTML 里确实有 `<div id="waline">`，但没有任何脚本去初始化它**。整页加载时走的 `DOMContentLoaded` 早就过去了，PJAX 换页不会重新触发。结果就是——第一篇文章有评论框，点进第二篇就没了，必须手动刷新才回来。

修法是暴露一个幂等的启动函数，让它能在两个时机被调用：

```js
window.__walineBoot = function () {
    var el = document.getElementById('waline');
    if (!el) return;                          // 容器还没来，先退出
    if (el.dataset.wlMounted === '1') return;  // 已经挂过，别重复 init
    ...
};
```

然后挂两个入口：

```js
// 入口一：整页加载
document.addEventListener('DOMContentLoaded', () => window.__walineBoot());

// 入口二：PJAX 换页完成
document.addEventListener('pjax:complete', () => window.__walineBoot());
```

## 坑四：刷新之后评论框也不见了

坑三修完，冒出一个更阴的：**偶尔刷新页面，评论区空白**。

问题出在标记"已挂载"的时机。我最初写的是这样：

```js
el.dataset.wlMounting = '1';
loadModule().then(() => {
    init(cfg);
});
```

标记在**发起**时就打上了，`init` 却要等模块下载完才真正执行。中间如果 PJAX 替换了 DOM、或者模块加载失败，那个"已挂载"的标记就永远留在了新元素上，后续所有 `__walineBoot` 调用都会被这行 `return` 挡回去——**评论框等于被永久判了死刑，只能刷新重来**。

改法是把标记挪到 `init` 成功之后，并且失败时把状态和缓存一起清干净：

```js
el.dataset.wlMounting = '1';
loadModule().then((m) => {
    var mountEl = document.getElementById('waline');  // PJAX 可能已换 DOM，重取
    if (!mountEl) { el.dataset.wlMounting = ''; return; }

    mountEl.innerHTML = '';
    m.init(window.__walineCfg);

    mountEl.dataset.wlMounted = '1';    // 成功之后才标记
    mountEl.dataset.wlMounting = '';
}).catch(() => {
    window.__walineModulePromise = null;   // 清缓存，下次能重试
    el.dataset.wlMounting = '';
});
```

两个细节值得单独说：

- **`init` 之前要重新 `getElementById` 一次**。PJAX 可能已经把整个容器换成了新的节点，手里那个 `el` 是个已经脱离文档的孤儿，往它身上打标记没人看得见。
- **容器不存在时要重试，别直接放弃**。PJAX 是异步替换的，`pjax:complete` 触发的那一刻，评论区可能还在路上。我给了 40 次 × 200ms 的兜底重试，差不多 8 秒窗口，实际很少用到 3 次以上，但没有它就会偶发空白。

## 表情包：两个 CDN 就够

Waline 的表情包配置很轻量，`emoji` 塞几个地址就行：

```yaml
emoji:
    - https://unpkg.com/@waline/emojis@1.4.0/bmoji
    - https://unpkg.com/@waline/emojis@1.4.0/bilibili
```

`bmoji` 是 B 站那套小黄脸，`bilibili` 是 B 站的大表情。两个加起来基本覆盖了日常表达，再多反而会让选择面板变得臃肿。

**记得锁版本号**。写成 `@latest` 的话，上游哪天调整了目录结构或图片命名，你这边就会变成一排裂图，而且没有任何报错。

## 必填项：我留了昵称、邮箱、网址

```yaml
requiredMeta:
    - name
    - email
    - url
```

这三项我全设成了必填，但实际体验上有个取舍：

- **昵称必填**，不然一堆匿名评论分不清谁是谁
- **邮箱必填但不会公开展示**，主要用来识别同一个人和收回复提醒
- **网址可选但设了必填**——这条我当时纠结过，因为强制要网址确实会劝退一部分人

真相是 Waline 的 `requiredMeta` 里填 `url` 并不会强制校验格式，留空也能提交，所以实际拦不住人，只是把输入框标成了必填样式。真正想降低门槛的话，把它从列表里删掉更干脆。

## 最后的感受

四个坑，三个都在"加载时机"上——字号是 CSS 变量没接上，字体是表单控件不继承，两个 PJAX 坑是挂载状态没管好。

回头看，最有价值的不是某个具体修法，而是那条原则：**评论框的初始化必须是幂等的、可重入的**。因为在一个开了 PJAX 的站点里，你永远不知道这段代码会被执行几次、在什么时机执行、容器当时在不在。

只要保证"跑多少次结果都一样"，剩下的事就交给重试和标记去兜底。

（评论区就在下面，欢迎试试它到底通不通。）
