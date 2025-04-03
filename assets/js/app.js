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

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// --- Define Hooks --- 
let Hooks = {}
Hooks.MessageInput = {
  mounted(){
    // Adjust height on mount and on input
    this.adjustHeight();
    this.el.addEventListener("input", () => {
      this.adjustHeight();
    });

    // 在移动设备上优化键盘体验
    if (window.matchMedia("(max-width: 768px)").matches) {
      // 获取相关元素
      const inputContainer = document.querySelector('.input-container');
      const messagesContainer = document.querySelector('.messages-container');
      
      // 输入框获得焦点时
      this.el.addEventListener('focus', () => {
        // 在iOS上，禁用缩放以防止输入时的布局跳动
        document.querySelector('meta[name=viewport]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
        
        // 添加样式表示键盘已弹出
        if (inputContainer) inputContainer.classList.add('keyboard-active');
        if (messagesContainer) {
          messagesContainer.scrollTop = messagesContainer.scrollHeight;
          // 短暂延迟后再次滚动到底部，解决某些设备上键盘弹出后滚动位置重置的问题
          setTimeout(() => {
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
          }, 100);
        }
      });
      
      // 输入框失去焦点时
      this.el.addEventListener('blur', () => {
        // 恢复正常缩放设置
        document.querySelector('meta[name=viewport]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=5.0');
        
        // 移除键盘样式
        if (inputContainer) inputContainer.classList.remove('keyboard-active');
      });
      
      // iOS 键盘弹起时的特殊处理
      window.visualViewport.addEventListener('resize', () => {
        if (document.activeElement === this.el) {
          const viewportHeight = window.visualViewport.height;
          const windowHeight = window.innerHeight;
          
          if (viewportHeight < windowHeight) {
            // 键盘已弹出
            if (inputContainer) {
              // 调整输入容器位置
              inputContainer.style.position = 'absolute';
              inputContainer.style.bottom = `${windowHeight - viewportHeight}px`;
            }
          } else {
            // 键盘已收起
            if (inputContainer) {
              // 恢复输入容器位置
              inputContainer.style.position = 'fixed';
              inputContainer.style.bottom = '0';
            }
          }
        }
      });
    }

    // Listen for the clear event from the server
    this.handleEvent("clear_message_input", () => {
      this.el.value = ""; // Clear the textarea
      this.adjustHeight(); // Adjust height after clearing
    });
  },
  adjustHeight() {
    this.el.style.height = 'auto';
    
    // 在移动设备上限制最大高度
    const maxHeight = window.matchMedia("(max-width: 768px)").matches ? 80 : 120;
    this.el.style.height = Math.min(this.el.scrollHeight, maxHeight) + 'px';
  }
}

// 添加一个页面级别的Hook来处理侧边栏事件
Hooks.PageHook = {
  mounted() {
    // 监听侧边栏切换事件
    this.handleEvent("sidebar_toggled", (data) => {
      const isMobile = window.matchMedia("(max-width: 768px)").matches;
      const sidebar = document.getElementById('sidebar');
      const backdrop = document.getElementById('sidebar-backdrop');
      
      if (sidebar) {
        if (isMobile) {
          if (data.show) {
            sidebar.classList.add('show');
            if (backdrop) backdrop.classList.add('show');
          } else {
            sidebar.classList.remove('show');
            if (backdrop) backdrop.classList.remove('show');
          }
        } else {
          // 桌面端
          if (data.show) {
            sidebar.classList.remove('hidden');
          } else {
            sidebar.classList.add('hidden');
          }
        }
        
        console.log(`侧边栏状态已更新: ${data.show ? '显示' : '隐藏'}`);
      }
    });
  }
}
// --- End Define Hooks ---

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks // Pass hooks to LiveSocket
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

