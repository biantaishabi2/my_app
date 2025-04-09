// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Sortable from "sortablejs"; // <--- 导入 sortablejs
// 导入钩子定义
import Hooks from "./hooks"
// 导入表单构建器钩子
import FormHooks from "./form-builder"
// 导入钩子测试 - 查看控制台输出
import "./hooks_test"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// 添加SettingsLayout钩子
Hooks.SettingsLayout = {
  mounted() {
    console.log("SettingsLayout hook mounted in app.js");
    this.handleLayoutChange();
    window.addEventListener('resize', () => this.handleLayoutChange());
  },
  
  updated() {
    console.log("SettingsLayout hook updated");
    this.handleLayoutChange();
  },
  
  handleLayoutChange() {
    const isMobile = window.innerWidth < 768;
    
    // 设置body类，用于CSS选择器
    if (isMobile) {
      document.body.classList.remove('is-settings');
    } else {
      document.body.classList.add('is-settings');
    }
    
    // 选择布局容器
    const container = this.el;
    const desktopLayout = container.querySelector('.hidden.md\\:block');
    const mobileLayout = container.querySelector('.md\\:hidden');
    
    if (!desktopLayout || !mobileLayout) {
      console.log("Settings layouts not found within", container);
      return;
    }
    
    // 根据视口大小切换布局
    if (isMobile) {
      desktopLayout.classList.add('hidden');
      desktopLayout.classList.remove('md:block');
      mobileLayout.classList.remove('hidden');
    } else {
      desktopLayout.classList.remove('hidden');
      mobileLayout.classList.add('hidden');
    }
    
    console.log("Settings layout adjusted:", isMobile ? "mobile" : "desktop", 
                "Desktop visibility:", !desktopLayout.classList.contains('hidden'),
                "Mobile visibility:", !mobileLayout.classList.contains('hidden'));
  }
};

// --- 注释：Sortable Hook 已在 hooks.js 中定义 ---
// 为了避免钩子冲突，这里不再定义 Sortable Hook
// Hooks.Sortable 钩子已经在 hooks.js 中定义，并提供了拖拽排序功能
// --- 结束注释 ---


// --- 修改：正确合并钩子 ---
const AllHooks = {
  ...Hooks,      // 包含 SettingsLayout 和 Sortable
  ...FormHooks   // 包含表单系统的钩子
};

// 初始化LiveView
let liveSocket = new LiveSocket("/live", Socket, {
  // 移除 longPollFallbackMs 设置，但增加调试工具
  params: {_csrf_token: csrfToken},
  hooks: AllHooks, // 传入合并后的钩子
  transport: Socket.WebSocket, // 强制使用 WebSocket
  logger: (kind, msg, data) => { console.log(`${kind}: ${msg}`, data) }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// 添加对所有链接点击的处理
document.addEventListener("click", function(e) {
  if (e.target.tagName === "A" || e.target.closest("a")) {
    // 显示加载状态条
    topbar.show(300);
    
    // 防止重复点击
    const link = e.target.tagName === "A" ? e.target : e.target.closest("a");
    if (!link.dataset.processing) {
      link.dataset.processing = "true";
      link.style.pointerEvents = "none";
      link.style.opacity = "0.7";
      
      // 1秒后恢复，以防导航未成功
      setTimeout(() => {
        link.removeAttribute("data-processing");
        link.style.pointerEvents = "";
        link.style.opacity = "";
      }, 1000);
    }
  }
});

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

