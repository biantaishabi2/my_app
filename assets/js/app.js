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
      const mainContent = document.querySelector('.main-content');
      const sidebar = document.getElementById('sidebar');
      
      // 输入框获得焦点时
      this.el.addEventListener('focus', () => {
        // 在iOS上，禁用缩放以防止输入时的布局跳动
        document.querySelector('meta[name=viewport]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
        
        // 添加样式表示键盘已弹出
        if (inputContainer) {
          inputContainer.classList.add('keyboard-active');
          
          // 确保侧边栏关闭，避免遮挡问题
          if (sidebar && sidebar.classList.contains('show')) {
            // 触发侧边栏关闭事件
            const event = new CustomEvent('phx:sidebar-toggle', { detail: { show: false } });
            window.dispatchEvent(event);
          }
        }
        
        // 滚动到底部，确保最新消息可见
        if (messagesContainer) {
          messagesContainer.scrollTop = messagesContainer.scrollHeight;
          
          // 短暂延迟后再次滚动到底部，解决某些设备上键盘弹出后滚动位置重置的问题
          setTimeout(() => {
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
          }, 300);
        }
      });
      
      // 输入框失去焦点时
      this.el.addEventListener('blur', () => {
        // 恢复正常缩放设置
        document.querySelector('meta[name=viewport]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=5.0');
        
        // 移除键盘样式
        if (inputContainer) inputContainer.classList.remove('keyboard-active');
        
        // 再次确保滚动到底部
        if (messagesContainer) {
          setTimeout(() => {
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
          }, 100);
        }
      });
      
      // iOS 键盘弹起时的特殊处理
      if (window.visualViewport) {
        window.visualViewport.addEventListener('resize', () => {
          if (document.activeElement === this.el) {
            const viewportHeight = window.visualViewport.height;
            const windowHeight = window.innerHeight;
            
            if (viewportHeight < windowHeight) {
              // 键盘已弹出
              if (inputContainer) {
                // 确保输入容器固定在视口底部
                inputContainer.style.position = 'fixed';
                inputContainer.style.bottom = '0';
                inputContainer.style.left = mainContent ? mainContent.offsetLeft + 'px' : '0';
                inputContainer.style.width = mainContent ? mainContent.offsetWidth + 'px' : '100%';
                
                // 调整消息容器的内边距，确保所有内容可见
                if (messagesContainer) {
                  const keyboardHeight = windowHeight - viewportHeight;
                  messagesContainer.style.paddingBottom = (170 + keyboardHeight) + 'px';
                }
                
                // 确保滚动到最新消息
                setTimeout(() => {
                  if (messagesContainer) messagesContainer.scrollTop = messagesContainer.scrollHeight;
                }, 100);
              }
            } else {
              // 键盘已收起
              if (inputContainer) {
                // 恢复输入容器默认样式
                inputContainer.style.position = 'fixed';
                inputContainer.style.bottom = '0';
                inputContainer.style.left = mainContent ? mainContent.offsetLeft + 'px' : '0';
                inputContainer.style.width = mainContent ? mainContent.offsetWidth + 'px' : '100%';
              }
              
              if (messagesContainer) {
                messagesContainer.style.paddingBottom = '170px';
                
                // 确保滚动到最新消息
                setTimeout(() => {
                  messagesContainer.scrollTop = messagesContainer.scrollHeight;
                }, 100);
              }
            }
          }
        });
      }
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

// 设置页面布局钩子
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

