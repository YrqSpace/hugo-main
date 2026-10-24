// 打字机 slogan
(function () {
    var el = document.querySelector('.profile-description');
    if (!el) return;

    // 要轮播的标语，可以自己增删修改
    var messages = [
        '一个人的自留地',
        '记录折腾电脑的过程',
        '写点生活和随笔'
    ];

    var msgIndex = 0, charIndex = 0, deleting = false;

    function tick() {
        var current = messages[msgIndex];
        if (!deleting) {
            charIndex++;
            el.textContent = current.slice(0, charIndex);
            if (charIndex === current.length) {
                deleting = true;
                setTimeout(tick, 1800);  // 打完后停留 1.8 秒
            } else {
                setTimeout(tick, 120);  // 打字速度
            }
        } else {
            charIndex--;
            el.textContent = current.slice(0, charIndex);
            if (charIndex === 0) {
                deleting = false;
                msgIndex = (msgIndex + 1) % messages.length;
            }
            setTimeout(tick, 60);  // 删除速度
        }
    }

    setTimeout(tick, 800);  // 页面加载后延迟 0.8 秒开始
})();
