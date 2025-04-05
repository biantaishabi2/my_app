// 定义所有LiveView钩子
const Hooks = {};

// 表单系统按钮钩子
Hooks.FormButtons = {
  mounted() {
    console.log("FormButtons钩子已挂载", this.el.id);
    
    this.el.addEventListener("click", (e) => {
      console.log("按钮被点击:", this.el.id);
      
      // 添加视觉反馈
      const originalText = this.el.innerText;
      const originalBg = this.el.style.backgroundColor;
      
      // 禁用按钮防止多次点击
      this.el.disabled = true;
      this.el.style.opacity = "0.7";
      
      // 1秒后恢复，以防事件未能处理
      setTimeout(() => {
        this.el.disabled = false;
        this.el.style.opacity = "";
      }, 1000);
      
      // 根据不同按钮类型进行特殊处理
      if (this.el.id === "new-form-btn") {
        console.log("新建表单按钮被点击");
      } else if (this.el.id === "save-new-form-btn") {
        console.log("保存新表单按钮被点击");
        // 对于提交按钮，不阻止默认行为，让表单正常提交
        return true;
      } else if (this.el.id === "cancel-new-form-btn") {
        console.log("取消按钮被点击");
      } else if (this.el.id.startsWith("publish-form-")) {
        console.log("发布表单按钮被点击");
      } else if (this.el.id.startsWith("delete-form-")) {
        console.log("删除表单按钮被点击");
      }
    });
  }
};

// 表单提交钩子
Hooks.FormHook = {
  mounted() {
    console.log("表单钩子已挂载，确保使用WebSocket通信");
    
    this.el.addEventListener("submit", (e) => {
      // 阻止传统提交
      e.preventDefault();
      console.log("表单提交被钩子捕获");
      
      // 允许LiveView通过WebSocket处理
      return true;
    });
  }
};

// 消息输入框钩子
Hooks.LiveMessageInput = {
  mounted(){
    console.log("LiveMessageInput钩子已挂载");
    
    // 自动调整高度
    this.adjustHeight();
    this.el.addEventListener("input", () => {
      this.adjustHeight();
    });

    // 处理Shift+Enter
    this.el.addEventListener("keydown", e => {
      if (e.key === "Enter" && e.shiftKey) {
        e.stopPropagation();
        e.preventDefault();
        
        const start = this.el.selectionStart;
        const end = this.el.selectionEnd;
        const value = this.el.value;
        this.el.value = value.substring(0, start) + "\n" + value.substring(end);
        this.el.selectionStart = this.el.selectionEnd = start + 1;
      }
    });

    // 处理清除消息事件
    this.handleEvent("clear_message_input", () => {
      console.log("接收到clear_message_input事件");
      this.el.value = "";
      this.adjustHeight();
    });
  },
  
  adjustHeight() {
    this.el.style.height = 'auto';
    const maxHeight = window.matchMedia("(max-width: 768px)").matches ? 80 : 120;
    this.el.style.height = Math.min(this.el.scrollHeight, maxHeight) + 'px';
  }
};

// 编辑输入框钩子
Hooks.EditInput = {
  mounted() {
    console.log("EditInput钩子已挂载");
    
    setTimeout(() => {
      this.el.select();
      try {
        const length = this.el.value.length;
        this.el.setSelectionRange(0, length);
      } catch (e) {
        console.log("无法设置选择范围:", e);
      }
    }, 50);
  }
};

// 页面钩子
Hooks.PageHook = {
  mounted() {
    console.log("PageHook钩子已挂载");
    
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
          if (data.show) {
            sidebar.classList.remove('hidden');
          } else {
            sidebar.classList.add('hidden');
          }
        }
      }
    });
  }
};

export default Hooks;
