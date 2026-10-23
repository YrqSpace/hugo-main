---
title: "第一次给开源项目提 PR"
description: "为了给博客攒一条外链，我人生中第一次给开源项目提了 PR。从 fork、改 CSV、投错仓库到 lint 通过，一路都是坑，也一路都在学。"
date: 2026-10-22T13:00:00+08:00
image: cover.jpg
categories:
    - 随心记
tags:
    - GitHub
    - PR
    - 开源
    - 独立博客
---

建站半个月，Bing 迟迟不收录，查来查去发现我缺一个信号：**外部链接**。搜索引擎发现一个网站靠四个信号——IndexNow、sitemap、站内链接、外链，前三个我都齐了，就缺最后一个。

于是我把目光投向了一个叫 [chinese-independent-blogs](https://github.com/timqian/chinese-independent-blogs) 的仓库：一个专门收集中文独立博客的列表，star 两万多。把我的博客加进去，就等于在一个高权威的页面上留了一条指向我网站的链接——这就是高质量外链。

但问题来了：**这个仓库不是我的，我没权限直接改它。** 这就得用上传说中的 PR（Pull Request，拉取请求）了。

## 第一回合：fork 一份，往 CSV 里加一行

PR 的第一步是 **fork**——把别人的仓库复制一份到自己的账号下，想怎么改都行。

Fork 完，我找到目标文件 `blogs-original.csv`，这是个纯文本表格，每一行是一个博客的信息，格式是"名称, URL, RSS, 标签"。我模仿前面几条的格式，在末尾加了一行：

```
爱玩win11的me, https://yrqspace.github.io, https://yrqspace.github.io/index.xml, 生活; 技术; 随笔
```

改完提交，GitHub 自动给我建了个新分支 `YrqSpace-patch-1`，然后页面上出现了一个绿色的按钮——**Compare & pull request**。我毫不犹豫就点了。

## 第二回合：PR 投错地址了

点完进去，填了句"你好，这是我的个人博客，麻烦审核，谢谢"，又点了一下绿色按钮，PR 就这么发起了。

然后我仔细一看页面，总觉得哪里不对劲：

- 我的头像旁边赫然标着 **Owner**
- 页面上居然有一个 **Merge pull request**（合并）按钮

我反应过来了：**这个 PR 开到了我自己的 fork 仓库里**（`YrqSpace/chinese-independent-blogs`），而不是原仓库。等于我把信写好了，却投到了自己家门口。

原因也简单：GitHub 默认把对比的"目标仓库"设成了我 fork 的那份，而不是原作者那份。我没看清 base 是哪个仓库，就一路点了下去。

## 第三回合：关掉重投

搞清楚了就动手改：先点 **Close pull request** 把投错的 PR 关掉，然后用跨仓库对比的直达链接重新发起：

```
https://github.com/timqian/chinese-independent-blogs/compare/master...YrqSpace:YrqSpace-patch-1
```

这个链接的意思是：**用我 fork 里的分支，向原仓库发起对比**。打开一看，base 显示的是 `timqian/chinese-independent-blogs`，这回对了。确认、点绿色、再点绿色，PR 就到了原仓库，编号 **#2287**。

这次我检查了三个"投对了"的迹象：标题是原仓库的名字、我的头像旁边没有 Owner、页面上没有合并按钮——因为我没权限合并别人的仓库，有那个按钮才奇怪。

## 第四回合：等合并

发起之后，仓库的自动检查跑了起来。几分钟后，页面上出现了我最想看到的一句话：

> All checks have passed · Lint blogs metadata / lint · Successful in 9s

那个 lint 是仓库的格式校验脚本，自动检查我加的那行数据合不合规——9 秒通过，意味着我那行 CSV 写得没问题。加上"No conflicts with base branch"，改动可以干净合并。

剩下的，就是等仓库维护者点一下合并按钮了。快则几小时，慢则一两周，GitHub 会通知我。

## 经验总结

这次折腾下来，几个点挺值得记：

1. **PR 是"申请"，不是"推送"**。push 是往自己的仓库写，PR 是向别人的仓库提交修改申请，方向完全不同。
2. **提 PR 一定要看 base 仓库**。Compare 页面顶部会写清楚"从哪个分支对比到哪个仓库"，投错地址是新手最容易踩的坑。判断投没投对，看 PR 页面上有没有"Merge"按钮、头像旁有没有"Owner"标记就行。
3. **fork 不用删**。删了不影响已发起的 PR，但留着能随时同步原仓库、以后想再提交也方便。
4. **lint 是个好东西**。它自动帮你把关格式，过了就说明你改对了，省去了人工扯皮。
5. **外链也不是非得买**。把博客提交到各种独立博客列表、导航站、聚合平台，都是合法免费的外链来源，比买链接安全一万倍——至少不会被搜索引擎当垃圾。

写到这，PR 还在等合并，Bing 的收录也还在排队。不过无所谓，该做的信号都做了，剩下的就是等。

等哪天 Bing 收录了我，我再写一篇《Bing 收录成功记》——那就真圆满了。
