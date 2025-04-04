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
// 导入钩子定义
import Hooks from "./hooks"
// 导入表单构建器钩子
import FormHooks from "./form-builder"

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

// 合并钩子，但保持钩子对象独立（不互相影响）
const AllHooks = {
  ...Hooks,  // 聊天和应用相关钩子
  ...FormHooks  // 表单系统相关钩子
};

// 初始化LiveView
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: AllHooks // 传入合并后的钩子
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

