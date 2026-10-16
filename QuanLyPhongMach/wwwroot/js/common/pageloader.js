// pageloader.js - Component PageLoader lấy 100% chuẩn HisSoft
let pageLoaderDepth = 0;

function showPageloader() {
    pageLoaderDepth += 1;

    var $loader = $("#page-loader-body");
    if ($loader.length) {
        $loader.addClass("show");
        $loader.css("z-index", "1070");
    }
}

function hidePageloader() {
    pageLoaderDepth = Math.max(0, pageLoaderDepth - 1);
    if (pageLoaderDepth > 0) return;

    var $loader = $("#page-loader-body");
    if ($loader.length) {
        $loader.removeClass("show");
        $loader.css("z-index", "-1");
    }
}

async function withPageloader(action) {
    showPageloader();
    try {
        return await action();
    } finally {
        hidePageloader();
    }
}

window.showPageloader = showPageloader;
window.hidePageloader = hidePageloader;
window.withPageloader = withPageloader;
