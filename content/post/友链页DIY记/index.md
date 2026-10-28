---
title: 友链页 DIY 记
date: 2026-10-26T23:00:00+08:00
slug: 友链页 DIY 记
tags:
    - 友链
    - 独立博客
    - Hugo
image: https://gcore.jsdelivr.net/gh/YrqSpace/hugo-pic-bed@main/2026/10/2026-10-28-cover.jpg
---

友链页是独立博客的脸面之一，但我一开始只有一张孤零零的 GitHub 卡片。这篇记录我怎么把它改造成一个「自助交换站」：交换须知、本站信息一键复制、友链随机排序、按名字搜索。

## 起点：一张孤零零的卡片

Stack 主题自带友链支持，只要在页面的 front matter 里写 `links:` 数组，主题就会渲染成卡片列表。我最早的友链页就是这样：三条友链、一片空白，访客来了也不知道该不该申请、怎么申请。

## 参考对象：UpXuu 的友链页

翻别人的博客时看到 UpXuu 的友链页，结构很清爽：

- 顶部友链列表
- 下面一块交换须知和「本站信息」：站点名称、域名、头像、简介，每行都能单独复制

这个结构的好处是——访客不用问你，自己就能把该复制的东西复制走、该走的流程走完。于是我照着这个思路重做了一版。

## 交换须知：把规则写在明面上

须知部分列了五条要求，都用小勾号呈现，一眼能扫完：

- 全站 HTTPS
- 内容健康，无采集
- 半年内有更新
- 独立域名可访问
- 先加本站友链，再提交申请

最后一条最关键——独立博客圈换友链是双向的，先把规则讲清楚，能省掉大量来回沟通。

## 本站信息：一键复制

访客要加你的友链，得先知道你的站点名称、域名、头像地址、简介。以前这些信息要靠翻源码或者问你，现在做成了一张复制卡：

| 项目 | 内容 |
| --- | --- |
| 站点名称 | 爱玩win11的me |
| 站点域名 | https://yrqspace.github.io |
| 头像 | https://yrqspace.github.io/img/avatar.png |
| 站点简介 | 欢迎来到我的博客 |

每行右边一个「复制」按钮，最下面还有一个「一键复制本站信息 YAML」，点一下就把四行信息按 YAML 格式一次性拿到剪贴板——访客直接粘进自己的 front matter 就能用。

## 列表优化：随机排序 + 按名称搜索

友链一多，两个问题就冒出来了：**凭什么我总排在最后**、**访客怎么找到自己的站**。

解决办法是一段纯前端的脚本，不动 Markdown、不动主题：

**随机排序**，用 Fisher-Yates 洗牌，每次进入页面顺序都不一样：

```js
function shuffle(arr) {
  for (var i = arr.length - 1; i > 0; i--) {
    var j = Math.floor(Math.random() * (i + 1));
    var t = arr[i]; arr[i] = arr[j]; arr[j] = t;
  }
  return arr;
}
shuffle(cards).forEach(function (card) {
  list.appendChild(card);
});
```

**按名称搜索**，输入关键词即时过滤，还会显示「找到 3 / 8 个友链」：

```js
cards.forEach(function (card) {
  var hit = !kw || (card.dataset.name || '').indexOf(kw) !== -1;
  card.style.display = hit ? '' : 'none';
});
```

因为站点开了 PJAX（切页不刷新），脚本挂在 `pjax:complete` 上重新执行一次，切回来依然生效；同时用了个小标记防止重复插入第二个搜索框。

## 踩的坑：搜索框太大

第一版搜索框铺满整行，宽度拉满、字号偏大，看着特别笨重。改法是收窄到 `max-width: 22rem`、字号降到 `1.2rem`、内边距缩小，容器用 `align-items: flex-end` 让它靠右——这样它像列表上方的一个小工具，而不是又一条横幅。

```css
.friend-search-wrap {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
}
.friend-search-box {
  position: relative;
  width: 100%;
  max-width: 22rem;
}
```

## 小结

现在这个友链页，访客进来能看懂规则、能一键复制本站信息、能搜到自己的站，友链顺序也不再固化。整套东西没有碰主题源码，样式和脚本都追加在页脚模板里，想改想删都很轻松。

友链交换的门槛，很多时候就卡在「对方不知道怎么申请」这一步。把这些做成页面，比在评论区来回解释高效多了。
