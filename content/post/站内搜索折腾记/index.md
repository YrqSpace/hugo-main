---
title: 给 Hugo 博客装上 Pagefind 站内搜索，中文分词和样式都踩了一遍
date: 2026-09-27
slug: 站内搜索折腾记
image: https://gcore.jsdelivr.net/gh/YrqSpace/hugo-pic-bed@main/2026/09/2026-09-27-cover.jpg
tags:
    - Pagefind
    - 站内搜索
    - Hugo
description: 用 Pagefind 给静态博客加纯前端站内搜索，解决中文分词、标题搜不到、PJAX 白框和异步竞态四个问题。
---

## 为什么不用那些现成的

静态博客加搜索，常见三条路：

| 方案 | 要不要服务 | 中文支持 | 我的判断 |
| --- | --- | --- | --- |
| Algolia | 要注册、有免费额度 | 要自己配 | 依赖外部服务，哪天停服就废了 |
| 主题自带搜索 | 不用 | 基本按空格切词 | 中文等于不可用 |
| Pagefind | 不用 | 原生支持 | 构建时生成索引，纯前端查 |

Pagefind 最吸引我的点是：**它在构建阶段把页面切块建索引，访客搜索时只下载命中的那几块**，不是把整个索引一次性拉下来。对中文站尤其友好，因为它内置了分词处理，不像有些方案把中文当成一大坨无空格字符。

而且它是纯静态的，索引就是一堆文件放在 `public/pagefind/` 里，跟着站点一起发布，没有任何外部依赖。

## 第一步：写配置文件

Pagefind 默认扫 `_site`，Hugo 输出的是 `public`，所以必须显式指定。我在博客根目录建了 `pagefind.yml`：

```yaml
# 要建索引的已构建站点目录
site: "public"

# 索引输出目录：相对运行目录，必须写成 public/pagefind
output_path: "public/pagefind"

# 强制按中文分词
force_language: "zh"

# 索引整篇文章区块（含 h1 标题）
root_selector: ".main-article"

exclude_selectors:
  - ".comments"
  - "#comments"
  - ".post-comments"
  - ".giscus"
  - ".article-footer"
  - ".related-content"
  - ".widget--toc"
  - ".menu-social"
  - ".left-sidebar"
  - ".right-sidebar"
```

几个参数都是踩过才知道要加的，下面逐个说。

### output_path 不能写错

一开始我图省事写成 `pagefind`，结果索引生成到了 `public` 的外面，站点访问 `/pagefind/` 直接 404——文件根本没进发布目录。

必须写成 `public/pagefind`，让它落在构建产物内部。

### force_language 才是中文能搜的关键

不加这一行，Pagefind 会按默认语言处理，中文被当成一个不含空格的长词，搜"人机"匹配不到"人机验证折腾记"。加上 `zh` 之后分词才正常。

### root_selector 选大了会漏标题

这一行我改了两次：

- 一开始用主题的 `.article-content`，只索引正文 → **文章标题搜不到**。因为 `<h1>` 在 `.article-content` 外面，短文章的正文又少，整个页面就显得没什么内容
- 改成 `.main-article` 把标题一起包进来，问题解决

### exclude_selectors 是防噪音

不排除的话，侧栏的标签云、目录、相关推荐、页脚全会被索引进去。搜"友链"，出来一堆侧栏里的标签页，而不是那篇文章。把评论区也排掉，否则读者留言里的文字会污染搜索结果。

## 第二步：构建流程变成两步

Pagefind 是读**已构建的 HTML** 建索引的，所以顺序不能反：

```bash
hugo            # 先出静态站点
npx -y pagefind # 再扫 public 生成索引
```

`npx -y` 省掉全局安装，每次用最新版。索引生成完，`public/pagefind/` 里就是一堆 `.pf_fragment` 之类的文件，随站点一起推上去。

## 第三步：初始化搜索界面

Pagefind 提供了现成的 UI 组件，引两个文件就能用：

```html
<link rel="stylesheet" href="/pagefind/pagefind-ui.css">
<script src="/pagefind/pagefind-ui.js"></script>
<script>
  new PagefindUI({
    element: "#search",
    showSubResults: true,
    showImages: false,
    resetStyles: false,
    translations: {
      placeholder: "搜索文章…",
      zero_results: "没有找到与 “[SEARCH_TERM]” 相关的内容",
      many_results: "找到 [COUNT] 条与 “[SEARCH_TERM]” 相关的结果",
      searching: "搜索中…"
    }
  });
</script>
```

`translations` 能把界面文案全换成中文，不然输入框里写着 "Search"，跟整站风格割裂。

## 第四步：四个坑

到这里功能是通的，但在我这个开了无刷新跳转（PJAX）的站上，问题一个接一个冒出来。

### 坑一：从首页跳进搜索页，搜索框是白框

PJAX 只替换 `.main-container` 里的内容，**`<head>` 不换**。所以 `/pagefind/pagefind-ui.css` 这个 `<link>` 根本没被加载，搜索框出来是裸的 HTML，白底黑字毫无样式。

修法是动态注入 CSS：每次挂载前检查 `<link>` 在不在，不在就用 JS 创建一个插进 `head`。

```js
function ensureCss() {
    if (document.querySelector('link[href="' + PF_CSS + '"]')) return;
    var l = document.createElement('link');
    l.rel = 'stylesheet';
    l.href = PF_CSS;
    document.head.appendChild(l);
}
```

所以这一段 JS 我放在了 `footer/custom.html`，也就是 `.main-container` **外面**——PJAX 不替换这块，脚本能一直活着。

### 坑二：偶发"索引没配置"

现象很怪：刷新几次，有时候正常有时候报错，说找不到索引。

原因是竞态。`pagefind-ui.js` 是异步加载的，脚本执行到 `new PagefindUI(...)` 时，那个文件可能还没下载完，`window.PagefindUI` 还是 undefined。既然不报错也不重试，就直接挂了。

修法是轮询等待：

```js
function whenReady(cb) {
    if (typeof window.PagefindUI !== 'undefined') { cb(true); return; }
    var tries = 0;
    (function loop() {
        if (typeof window.PagefindUI !== 'undefined') { cb(true); return; }
        if (tries++ > 100) { cb(false); return; }   // 最多等 ~10 秒
        setTimeout(loop, 100);
    })();
}
```

100 次 × 100ms，最多等 10 秒。等到了就挂载，等不到就在页面上显示"搜索资源加载失败，请刷新重试"，总比一片空白强。

### 坑三：脚本重复插入

`ensureScript` 里加了个 `data-pf-ui` 属性做标记：

```js
if (!document.querySelector('script[data-pf-ui]')) {
    var s = document.createElement('script');
    s.src = PF_JS;
    s.setAttribute('data-pf-ui', '1');
    // ...
}
```

不加这个标记，PJAX 每次换页都插一个新 script，浏览器会重复执行，页面上叠出好几个搜索框。

### 坑四：重复挂载

这个和上面配套——script 不重复了，但挂载逻辑还是会跑多次。用 `dataset` 记个状态：

```js
if (box.dataset.pfMounted !== '1') {
    box.innerHTML = '';
    new window.PagefindUI({ /* ... */ });
    box.dataset.pfMounted = '1';
}
```

挂载前先清空容器，免得旧搜索框残留。

## 顺手加的一个功能：URL 带关键词

搜索结果页如果能直接分享链接，体验会好很多，比如 `/search/?keyword=Hugo`。

从 URL 读参数，塞进输入框，再手动派发一个 `input` 事件触发搜索：

```js
var term = new URLSearchParams(location.search).get('keyword')
        || new URLSearchParams(location.search).get('q') || '';
if (term) {
    var input = box.querySelector('.pagefind-ui__search-input');
    if (input && input.value !== term) {
        input.value = term;
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.focus();
    }
}
```

这里有个细节：**不能只设 `input.value`**。直接赋值不会触发框架的事件监听，搜索框里显示着关键词但结果区是空的。必须 `dispatchEvent` 一个 `input` 事件，Pagefind 才会真的去查。

## 最后：别忘了 PJAX

所有挂载逻辑都挂在 `pjax:complete` 上，换页后重新走一遍：

```js
document.addEventListener('pjax:complete', function () {
    setTimeout(mount, 0);
});
```

`setTimeout(..., 0)` 是为了等新 DOM 渲染完再操作，不然拿到的还是旧节点。

## 小结

按耗时排一下，真正麻烦的不是 Pagefind 本身，而是**无刷新站点和第三方组件的配合**：

| 问题 | 根因 | 解法 |
| --- | --- | --- |
| 中文搜不到 | 没做分词 | `force_language: zh` |
| 标题搜不到 | 索引范围漏了 h1 | `root_selector: .main-article` |
| 白框无样式 | PJAX 不换 head | 动态注入 CSS |
| 偶发索引报错 | 异步竞态 | 轮询等 PagefindUI |
| 多个搜索框 | 脚本重复插入 | `data-pf-ui` 标记 + 挂载状态位 |

Pagefind 本身配置简单，中文支持也是现成的。真正要花心思的，是让它在**不是整页刷新的环境里**正常工作。

> 参考：[pagefind.app](https://pagefind.app) 官方文档
