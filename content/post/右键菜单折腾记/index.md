---
title: 给 Hugo 博客加自定义右键菜单：作用域、剪贴板和键盘事件
date: 2026-11-10
slug: 右键菜单折腾记
image: https://image.tinkerlog.dpdns.org/2026/11/2026-11-10-cover.jpg
tags:
    - Hugo
    - 前端
    - JavaScript
description: 全站接管 contextmenu 是个陷阱。记一次自定义右键菜单的实现：作用域怎么分层放行、为什么菜单里的粘贴不可能百分百成功、键盘 Ctrl+C 又该怎么和菜单共存。
---

## 想要一个自己的右键菜单

起因很朴素：看别人的博客右击有自定义菜单，觉得挺帅。

第一版我写得很干脆，在 `document` 上挂 `contextmenu`，上来就 `preventDefault()`，然后弹自己的菜单。全站接管，一步到位，感觉自己赢麻了。

结果用起来处处别扭。在搜索框里想粘贴，弹的是我的菜单；在评论区想检查文字，弹的是我的菜单；想在新标签页打开个链接，还得先在菜单里找一圈。最要命的是手机上，长按也归我管了，那我到底是给人用还是给爬虫用。

后来一点点改，改到最后发现：**这个需求的难点根本不在"画一个菜单"，而在"决定哪些位置不该归我管"**。

## 全站接管的三个陷阱

一开始的问题可以归成三条，都是"过度接管"带来的。

**第一，输入框被抢了。** `input`、`textarea`、`contenteditable` 这些地方，浏览器原生菜单里有"粘贴"、"撤销"、"检查拼写"、"输入法开关"，这些能力我根本没法复刻。抢了之后就只剩一排没用的自定义项。

**第二，链接和图片的操作被吞了。** 原生菜单在 `<a>` 上会给你"在新标签页中打开链接"、"复制链接地址"，在 `<img>` 上会给你"图片另存为"、"复制图片"。这些功能我的菜单里没有，等于我白抢了一个位置还没补上。

**第三，移动端长按。** 手机上 `contextmenu` 事件和长按选择是绑在一起的。拦掉之后，用户长按想选个字都做不到。这个体验破坏得最彻底，因为没有替代方案。

所以我后来的判断标准变成了一句话：**能不接管就不接管，必须接管的地方要把原生的能力补回来**。

## 分层放行：按目标元素决定

实现上其实很简单，就是开一个白名单，命中就 `return`，放行给浏览器。

```javascript
document.addEventListener('contextmenu', function (e) {
  // 触屏设备交给系统长按菜单
  if (window.matchMedia && window.matchMedia('(hover: none)').matches) return;

  var t = e.target;
  if (!t || !t.closest) return;

  // 让原生菜单继续工作的地方
  if (t.closest('input, textarea, select, [contenteditable="true"]')) return;

  e.preventDefault();
  showMenu(e.clientX, e.clientY);
});
```

`matchMedia('(hover: none)')` 这一行是分水岭。它判断的是"这台设备有没有精确的悬停指针"，触屏设备命中，直接放行。比起用 `touchstart` 去猜，这个判断更稳，因为笔记本插了鼠标时它不会误判。

`closest()` 比 `tagName` 判断靠谱得多。因为 `e.target` 往往是深层的 `span` 或者 `code`，真正的输入框在好几层外面。写成 `t.tagName === 'INPUT'` 会漏掉一大半情况。

但只有放行还不够。输入框我放弃了，那链接和图片呢？我不想放弃，因为这两个场景的右键操作我用得最多。于是菜单内容就不能是固定的一串，必须**根据这次点击落点动态生成**。

```javascript
function build(e) {
  var t = e.target;
  var editable = isEditable(t);          // 输入区
  var link = t.closest && t.closest('a[href]');
  var img  = t.closest && t.closest('img');
  var picked = selText();                // 有没有选中文字

  var h = '';
  if (editable) {
    // 撤销 / 重做 / 剪切 / 复制 / 粘贴 / 全选
  } else if (picked) {
    // 复制选中 / 搜索这段文字 / 全选正文
  }
  if (link) { /* 打开链接 / 复制地址 / 复制链接文字 */ }
  if (img)  { /* 查看图片 / 复制地址 / 另存为 */ }
  // 通用项：复制本页链接、随机看一篇、回到顶部、切换深浅色
}
```

这样在正文空白处右键，菜单是"复制本页链接 / 随机看一篇 / 回到顶部"；在链接上右键，多出三项链接操作；在图片上右键，多出三项图片操作。同一份代码，菜单长了眼睛。

## 光标位置会被菜单吃掉

输入区里的剪切、复制、粘贴，绕不开一个具体问题：**点菜单会把焦点拿走**。

正常流程是：鼠标在输入框里选中一段文字 → 右键 → 点"复制"。但你点菜单的那一下，`focus` 已经从输入框移到了菜单上，选区也可能被清掉。这时候去执行 `execCommand('copy')`，复制的是空字符串。

修法是右键的瞬间先把选区记下来，执行动作之前再恢复。

```javascript
function saveEditSel(el) {
  if (typeof el.selectionStart === 'number') {
    ctx.ss = el.selectionStart;
    ctx.se = el.selectionEnd;
  } else {
    var s = window.getSelection();
    ctx.range = (s && s.rangeCount) ? s.getRangeAt(0).cloneRange() : null;
  }
}

function restoreEditSel() {
  var el = ctx.el;
  el.focus({ preventScroll: true });
  if (typeof el.setSelectionRange === 'function' && ctx.ss != null) {
    el.setSelectionRange(ctx.ss, ctx.se);
  } else if (ctx.range) {
    var s = window.getSelection();
    s.removeAllRanges();
    s.addRange(ctx.range);
  }
}
```

`{ preventScroll: true }` 这个参数别省。不加的话，`focus()` 可能会把页面滚动到输入框位置，右键菜单位置就飘了。

`Range` 的 `cloneRange()` 也值得说一句。如果不克隆，直接存 `getRangeAt(0)`，后续 DOM 变化会让这个 Range 失效或者位置跑偏。克隆一份是保留快照。

## 菜单里的"粘贴"不可能百分百成功

这是我最想单独拿出来讲的一段，因为**这是浏览器的硬限制，不是代码写得不好**。

复制好办。`navigator.clipboard.writeText()` 在 HTTPS 下直接可用，失败就降级到 `document.execCommand('copy')` 加一个临时 textarea。

粘贴是另一回事。**浏览器不允许脚本主动往页面里写入剪贴板内容**，因为这是个安全漏洞——想象一个网页能在你不知情的时候把你剪贴板里的密码填进表单。

所以正确姿势是分层降级：

```javascript
function paste() {
  // 一、先试 execCommand('paste')，现代浏览器基本都已禁用
  var ok = false;
  try { ok = document.execCommand('paste'); } catch (e) {}
  if (ok) return;

  // 二、读剪贴板，需要用户授予 clipboard-read 权限
  navigator.clipboard.readText().then(function (text) {
    // 三、拿到文字后自己插入，还是得靠 execCommand('insertText')
    //    不行就手动切字符串插进 value
  }).catch(function () {
    toast('浏览器不给读剪贴板，请按 Ctrl+V');
  });
}
```

三层降级，每一层都可能失败。`execCommand('paste')` 在 Chrome 里早就返回 `false` 了；`readText()` 会弹权限请求，用户点了拒绝就没戏；就算拿到文字，往 `contenteditable` 里插还得靠 `insertText`，而这个命令也在被逐步废弃。

对 `input` / `textarea` 我加了最后一道保险：直接操作 `value` 和 `selectionStart`。这个一定能成，但只对原生表单元素有效，`contenteditable` 没法这么干。

**结论是：菜单里的"粘贴"是个尽力而为的功能，键盘 `Ctrl+V` 才永远可靠。** 我在菜单项的失败提示里就写"请按 Ctrl+V"，不装作能成。

## 键盘和右键不能互相打架

这一点是我最初差点搞砸的地方。

自定义菜单做出来之后，很自然的一个念头是："我把 `Ctrl+C` 也接管一下吧，统一走我的复制逻辑，这样提示也统一。" 这是个坏主意。

因为**键盘复制比菜单复制重要得多**，而且原生行为已经足够好。一旦 `preventDefault()`，你就得自己处理富文本选区、图片复制、表格结构，全是坑。为了一个"提示文案统一"，代价太大。

我的处理方式是：**不拦截，只旁听**。

```javascript
document.addEventListener('copy', function () {
  if (isEditable(document.activeElement)) return;  // 输入区不打扰
  if (!selText()) return;
  toast('已复制');
});
document.addEventListener('paste', function (e) {
  if (!isEditable(e.target)) return;
  toast('已粘贴');
});
```

这两个监听里没有一行 `preventDefault()`。浏览器该做的事一件不少，我只是在旁边看一眼，顺手弹一个"已复制"的小提示。

这样做的效果反而更好：用户按 `Ctrl+C` 和点菜单里的"复制"，看到的反馈是一样的，但底层走的是完全不同的两条路——一条是浏览器原生的，一条是我自己实现的。**表面统一，底层各管各的，互不牵连**。

输入区里我特意跳过不提示，因为系统自带的光标反馈已经足够，再叠一个 toast 就吵了。

## 位置计算：越界自动翻转

菜单弹出来之后有个必须处理的问题：**靠近屏幕右边或者底部右键，菜单会跑出可视区域**。

做法很简单，先显示出来量尺寸，再决定位置。

```javascript
function place(m, x, y) {
  m.hidden = false;
  m.style.left = '0px';
  m.style.top = '0px';
  var r = m.getBoundingClientRect();   // 先量
  var pad = 8;
  var left = x, top = y;
  if (left + r.width + pad > window.innerWidth)  left = window.innerWidth - r.width - pad;
  if (top + r.height + pad > window.innerHeight) top = window.innerHeight - r.height - pad;
  if (left < pad) left = pad;
  if (top < pad)  top  = pad;
  m.style.left = left + 'px';
  m.style.top = top + 'px';
}
```

关键在 `hidden = false` 必须在量尺寸之前。`display: none` 的元素 `getBoundingClientRect()` 全是 0，量出来没用。

先把 `left/top` 归零再量，是为了避开上一次定位留下的残留，否则量到的尺寸可能受旧位置影响。这个细节踩过一次就知道了。

## 顺手踩的坑：jsonify 把引号带进了 URL

菜单里有个"随机看一篇"，数据由模板注入：

```go-html-template
window.__POSTS__ = [{{ range $i, $p := $posts }}{{ if $i }},{{ end }}{{ $p.RelPermalink | jsonify }}{{ end }}];
```

看着没问题，实际跳转全是 404。看地址栏才发现，跳到了 `/p/站点名/` 加上 `"/p/另一篇/"`——**多了一层引号，浏览器把 `"` 编码成 `%22` 拼进了路径**。

原因是 `jsonify` 输出的字符串自带双引号，而我又在外面手写了逗号拼接，于是数组元素变成了 `"/p/a/","/p/b/"` 这种形式被当成纯文本，`location.href` 赋值时整串都进了 URL。

修法有两种。要么模板里不加引号，让 `jsonify` 自己负责：

```go-html-template
window.__POSTS__ = [{{ range $i, $p := $posts }}{{ if $i }},{{ end }}{{ $p.RelPermalink | jsonify }}{{ end }}];
```

要么外面写好引号，里面不用 `jsonify`：

```go-html-template
window.__POSTS__ = [{{ range $i, $p := $posts }}{{ if $i }},{{ end }}"{{ $p.RelPermalink }}"{{ end }}];
```

我选了后者，看着更清楚。另外在 JS 里加了一道清洗，防止以后有别的地方再灌进脏数据：

```javascript
function cleanUrl(u) {
  return String(u == null ? '' : u)
    .trim()
    .replace(/^["'\s]+|["'\s]+$/g, '')   // 去掉首尾引号
    .replace(/\\\//g, '/');              // 还原被转义的斜杠
}
```

这个坑挺有代表性：**模板里拼接字符串，引号要么全交给模板函数，要么全靠手写，混着来必然出事**。

## PJAX 站点要额外处理

这个站开了无刷新跳转，所以还得考虑换页之后的状态。

菜单元素是动态创建的，挂在 `body` 上。PJAX 换页时 `body` 不重建，菜单还在，但它里面缓存的 `dataset.url`、`dataset.title` 全是旧页面的。如果在旧菜单还没关的情况下换页，点"复制本页链接"复制到的是上一页地址。

处理很简单，换页时把菜单关掉、引用清空：

```javascript
document.addEventListener('pjax:send', close);
document.addEventListener('pjax:complete', function () { menu = null; });
```

`menu = null` 而不是只 `close()`，是为了让下次 `ensureMenu()` 重新创建。这样连 `dataset` 里的旧值也一起丢了，不会残留。

`ensureMenu()` 里那句 `document.body.contains(menu)` 也重要。PJAX 如果整体替换了 `body` 内容，旧节点就脱离文档了，这时候直接往旧的 `menu` 变量上操作是没有效果的——它还在内存里，但页面上看不见。

## 几个没写进去的东西

写完之后想过一些加分项，最后都没做，记录一下理由。

**没做"分享到 XX"。** 静态博客没什么可分享的渠道，加了纯摆设。

**没做"复制 Markdown 源码"。** 需要 `fetch` 当前页面再解析 HTML，遇到代码块和表格要特殊处理，成本明显不成比例。

**没做移动端适配菜单。** 前面已经放行给系统长按了，再做一套触屏菜单等于两套逻辑，维护成本翻倍，收益可疑。

**没做菜单动画。** 加了一个 0.12s 的淡入，就这个程度。再多就开始拖慢手感了。

我的判断是：**这类"锦上添花"的功能，功能项的数量要克制，交互的细节要讲究**。五个用着顺手的菜单项，好过十五个看着齐全但一半不好用的。

## 小结

把整篇的问题和解法压成一张表：

| 现象 | 根因 | 修法 |
| --- | --- | --- |
| 输入框没法粘贴 | 全站接管了 contextmenu | 输入区放行给原生 |
| 链接没法新标签打开 | 右键被吞，菜单没补对应项 | 按落点动态生成菜单项 |
| 手机长按不能选字 | 触屏 contextmenu 被拦 | `(hover: none)` 直接放行 |
| 点菜单后复制为空 | 焦点移走，选区丢失 | 右键时存 Range，执行前恢复 |
| 菜单里的粘贴偶尔没反应 | 浏览器不让脚本写剪贴板 | 三层降级，失败就提示按 Ctrl+V |
| 靠近边缘菜单出界 | 位置没做边界检测 | 先显示量尺寸，再翻转 |
| 随机跳转 404 | `jsonify` 的引号被拼进 URL | 模板统一引号来源 + JS 清洗 |
| 换页后复制到旧链接 | 菜单 cache 未失效 | `pjax:complete` 时置 `menu = null` |

真正花时间的不是菜单本身，而是"什么时候该让路"这个判断。全站接管写起来最快，但用起来最难受；分层放行要多写几十行 `closest()` 判断，可每个位置的行为都符合直觉。

如果你也想给自己的站点加一个，我的建议是先从最小可用开始：只在正文区域接管，菜单里就四五项，跑通了再考虑往外扩。往外扩之前，先把"输入框要不要放行"、"链接和图片补不补"这两个问题想清楚，能省掉后面很多返工。
