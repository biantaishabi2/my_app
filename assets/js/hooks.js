// 定义所有LiveView钩子
const Hooks = {};

// 表单系统按钮钩子
Hooks.FormButtons = {
  mounted() {
    console.log("FormButtons钩子已挂载", this.el.id);
    
    // 提供视觉反馈但不干扰事件传播
    this.handleEvent("phx:click", () => {
      console.log("按钮被点击（通过phx:click）:", this.el.id);
      
      // 添加视觉反馈
      this.el.disabled = true;
      this.el.style.opacity = "0.7";
      
      // 1秒后恢复
      setTimeout(() => {
        this.el.disabled = false;
        this.el.style.opacity = "";
      }, 1000);
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

// 省份选择钩子
Hooks.RegionSelectProvince = {
  mounted() {
    console.log("RegionSelectProvince钩子已挂载", this.el.id);
    
    const select = this.el;
    const fieldId = select.getAttribute('data-field-id');
    
    // 设置下拉列表高度
    select.size = 10;
    
    // 监听选择变化
    select.addEventListener('change', (e) => {
      e.preventDefault();
      
      const province = select.value;
      console.log(`选择省份: ${fieldId} -> ${province}`);
      
      // 获取/更新城市列表
      const citySelect = document.getElementById(`${fieldId}_city`);
      const districtSelect = document.getElementById(`${fieldId}_district`);
      const hiddenInput = document.getElementById(fieldId);
      
      if (citySelect) {
        // 清空城市和区县选择
        this.clearOptions(citySelect);
        this.addOption(citySelect, "", "市", true, true);
        
        // 发送请求获取城市列表
        this.pushEvent("handle_province_change", {
          field_id: fieldId,
          province: province
        });
        
        // 启用城市选择框
        citySelect.disabled = false;
      }
      
      if (districtSelect) {
        this.clearOptions(districtSelect);
        this.addOption(districtSelect, "", "区/县", true, true);
        districtSelect.disabled = true;
      }
      
      // 更新隐藏字段值
      if (hiddenInput) {
        hiddenInput.value = province;
      }
    });
  },
  
  // 处理服务器响应
  handleEvent(event, payload) {
    if (event === "update_cities") {
      const field_id = payload.field_id;
      const cities = payload.cities;
      const citySelect = document.getElementById(`${field_id}_city`);
      if (!citySelect) return;
      
      // 清空城市选择
      this.clearOptions(citySelect);
      
      // 添加默认选项
      this.addOption(citySelect, "", "市", true, true);
      
      // 添加城市选项
      if (cities && Array.isArray(cities)) {
        cities.forEach(city => {
          this.addOption(citySelect, city.name, city.name);
        });
      }
      
      // 启用城市选择
      citySelect.disabled = false;
    }
  },
  
  // 清空选择框选项
  clearOptions(select) {
    while (select.options.length > 0) {
      select.remove(0);
    }
  },
  
  // 添加选择框选项
  addOption(select, value, text, disabled = false, selected = false) {
    const option = document.createElement('option');
    option.value = value;
    option.text = text;
    option.disabled = disabled;
    option.selected = selected;
    select.add(option);
  }
};

// 城市选择钩子
Hooks.RegionSelectCity = {
  mounted() {
    console.log("RegionSelectCity钩子已挂载", this.el.id);
    
    const select = this.el;
    const fieldId = select.getAttribute('data-field-id');
    
    // 设置下拉列表高度
    select.size = 10;
    
    // 监听选择变化
    select.addEventListener('change', (e) => {
      e.preventDefault();
      
      const city = select.value;
      console.log(`选择城市: ${fieldId} -> ${city}`);
      
      // 获取省份和更新区县列表
      const provinceSelect = document.getElementById(`${fieldId}_province`);
      const districtSelect = document.getElementById(`${fieldId}_district`);
      const hiddenInput = document.getElementById(fieldId);
      
      if (provinceSelect && districtSelect) {
        const province = provinceSelect.value;
        
        // 清空区县选择
        while (districtSelect.options.length > 0) {
          districtSelect.remove(0);
        }
        
        // 添加默认选项
        const defaultOption = document.createElement('option');
        defaultOption.value = "";
        defaultOption.text = "区/县";
        defaultOption.disabled = true;
        defaultOption.selected = true;
        districtSelect.add(defaultOption);
        
        // 发送请求获取区县列表
        this.pushEvent("handle_city_change", {
          field_id: fieldId,
          province: province,
          city: city
        });
        
        // 启用区县选择框
        districtSelect.disabled = false;
      }
      
      // 更新隐藏字段值
      if (hiddenInput && provinceSelect) {
        const province = provinceSelect.value;
        hiddenInput.value = `${province}-${city}`;
      }
    });
  },
  
  // 处理服务器响应
  handleEvent(event, payload) {
    if (event === "update_districts") {
      const { field_id, districts } = payload;
      const districtSelect = document.getElementById(`${field_id}_district`);
      if (!districtSelect) return;
      
      // 清空区县选择
      while (districtSelect.options.length > 0) {
        districtSelect.remove(0);
      }
      
      // 添加默认选项
      const defaultOption = document.createElement('option');
      defaultOption.value = "";
      defaultOption.text = "区/县";
      defaultOption.disabled = true;
      defaultOption.selected = true;
      districtSelect.add(defaultOption);
      
      // 添加区县选项
      districts.forEach(district => {
        const option = document.createElement('option');
        option.value = district.name;
        option.text = district.name;
        districtSelect.add(option);
      });
      
      // 启用区县选择
      districtSelect.disabled = false;
    }
  }
};

// 拖拽排序钩子 (表单模板编辑)
Hooks.Sortable = {
  mounted() {
    console.log("Sortable钩子已挂载", this.el.id);
    
    // 记录项目变化
    let itemsChanged = false;
    
    // 创建占位元素
    const createPlaceholder = () => {
      const placeholder = document.createElement('div');
      placeholder.className = 'drag-placeholder';
      placeholder.id = 'drag-placeholder';
      return placeholder;
    };
    
    // 删除任何现有占位符
    const removePlaceholder = () => {
      const placeholder = document.getElementById('drag-placeholder');
      if (placeholder) {
        placeholder.remove();
      }
    };
    
    // 清除所有拖拽指示器
    const clearDragIndicators = () => {
      document.querySelectorAll('.drag-over-top, .drag-over-bottom').forEach(el => {
        el.classList.remove('drag-over-top', 'drag-over-bottom');
      });
    };
    
    // 找到所有子项目
    const items = Array.from(this.el.children).filter(child => !child.classList.contains('text-gray-500'));
    
    // 确保每个项目有 data-id 属性和拖拽能力
    items.forEach((item) => {
      if (!item.getAttribute('data-id')) {
        console.warn('Sortable项目缺少data-id属性:', item);
        // 尝试从ID中提取
        const itemId = item.id && item.id.replace('item-', '');
        if (itemId) {
          item.setAttribute('data-id', itemId);
        }
      }
      
      // 只有非空项目才需要拖拽
      if (!item.classList.contains('text-gray-500')) {
        // 确保可拖拽
        item.setAttribute('draggable', 'true');
        
        // 设置鼠标样式
        const handle = item.querySelector('.drag-handle');
        if (handle) {
          handle.style.cursor = 'move';
        } else {
          item.style.cursor = 'move';
        }
      }
    });
    
    // 跟踪被拖拽的元素
    let draggedItem = null;
    
    // 添加拖拽事件监听器
    this.el.addEventListener('dragstart', (e) => {
      // 获取目标元素 (可能是handle或整个项目)
      const target = e.target.closest('[draggable="true"]');
      if (!target) return;
      
      draggedItem = target;
      
      // 设置拖放效果和数据
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', target.getAttribute('data-id') || '');
      
      // 延迟添加视觉效果，以确保拖拽开始
      setTimeout(() => {
        draggedItem.classList.add('dragging');
      }, 0);
    });
    
    this.el.addEventListener('dragend', () => {
      if (draggedItem) {
        // 清理视觉反馈
        draggedItem.classList.remove('dragging');
        removePlaceholder();
        clearDragIndicators();
        
        // 如果项目顺序改变，则通知服务器
        if (itemsChanged) {
          this.pushOrderChangesToServer();
          itemsChanged = false;
        }
        
        draggedItem = null;
      }
    });
    
    this.el.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      
      if (!draggedItem) return;
      
      // 找到当前鼠标悬停的项目 (不包括占位符)
      const hoverItem = e.target.closest('[draggable="true"]');
      if (!hoverItem || hoverItem === draggedItem || hoverItem.id === 'drag-placeholder') return;
      
      // 清除所有指示器
      clearDragIndicators();
      
      // 确定放置位置 (在目标之前或之后)
      const hoverRect = hoverItem.getBoundingClientRect();
      const hoverMiddle = (hoverRect.bottom - hoverRect.top) / 2;
      const relativeMousePos = e.clientY - hoverRect.top;
      const moveAfter = relativeMousePos > hoverMiddle;
      
      // 添加视觉指示
      if (moveAfter) {
        hoverItem.classList.add('drag-over-bottom');
      } else {
        hoverItem.classList.add('drag-over-top');
      }
      
      // 根据放置位置重新排序
      if ((moveAfter && hoverItem.nextElementSibling !== draggedItem) || 
          (!moveAfter && hoverItem.previousElementSibling !== draggedItem)) {
        
        if (moveAfter) {
          // 放置在目标之后
          if (hoverItem.nextElementSibling) {
            this.el.insertBefore(draggedItem, hoverItem.nextElementSibling);
          } else {
            this.el.appendChild(draggedItem);
          }
        } else {
          // 放置在目标之前
          this.el.insertBefore(draggedItem, hoverItem);
        }
        
        itemsChanged = true;
      }
    });
    
    this.el.addEventListener('drop', (e) => {
      e.preventDefault();
      // 清理视觉指示
      clearDragIndicators();
      removePlaceholder();
    });
    
    // 处理空列表特殊情况
    if (items.length === 0) {
      const emptyMessage = this.el.querySelector('.text-gray-500.italic');
      if (emptyMessage) {
        emptyMessage.style.pointerEvents = 'none';
      }
    }
  },
  
  pushOrderChangesToServer() {
    // 获取所有项目的ID并按当前DOM顺序排列
    const orderedIds = Array.from(this.el.children)
      .filter(item => item.hasAttribute('data-id')) // 只考虑有data-id的项目
      .map(item => item.getAttribute('data-id'))
      .filter(id => id); // 过滤掉任何null或undefined
    
    console.log("发送新的排序:", orderedIds);
    
    // 发送更新事件到服务器
    this.pushEvent("update_structure_order", { ordered_ids: orderedIds });
  }
};

// 区县选择钩子
Hooks.RegionSelectDistrict = {
  mounted() {
    console.log("RegionSelectDistrict钩子已挂载", this.el.id);
    
    const select = this.el;
    const fieldId = select.getAttribute('data-field-id');
    
    // 设置下拉列表高度
    select.size = 10;
    
    // 监听选择变化
    select.addEventListener('change', (e) => {
      e.preventDefault();
      
      const district = select.value;
      console.log(`选择区县: ${fieldId} -> ${district}`);
      
      // 获取省份和城市
      const provinceSelect = document.getElementById(`${fieldId}_province`);
      const citySelect = document.getElementById(`${fieldId}_city`);
      const hiddenInput = document.getElementById(fieldId);
      
      // 更新隐藏字段值
      if (hiddenInput && provinceSelect && citySelect) {
        const province = provinceSelect.value;
        const city = citySelect.value;
        hiddenInput.value = `${province}-${city}-${district}`;
      }
      
      // 发送事件给服务器
      this.pushEvent("handle_district_change", {
        field_id: fieldId,
        district: district
      });
    });
  }
};

// 新增：用于触发隐藏文件输入的Hook
Hooks.FileInputTrigger = {
  mounted() {
    const fileInputId = this.el.dataset.fileInputId;
    if (!fileInputId) {
      console.error("FileInputTrigger: data-file-input-id attribute is missing on", this.el);
      return;
    }
    console.log(`FileInputTrigger mounted for button [${this.el.id || 'no id'}], targeting input #${fileInputId}`);

    this.el.addEventListener("click", (e) => {
      const fileInput = document.getElementById(fileInputId);
      if (fileInput) {
        console.log(`FileInputTrigger: Triggering click on #${fileInputId}`);
        fileInput.click(); // 触发隐藏文件输入的点击
      } else {
        console.error(`FileInputTrigger: Could not find file input with ID: #${fileInputId}`);
      }
    });
  }
};

// 新增：文件上传拖放区域钩子
Hooks.FileUploadDropzone = {
  mounted() {
    console.log("FileUploadDropzone钩子已挂载", this.el.id);
    this.setupDragAndDrop();
  },

  setupDragAndDrop() {
    const dropzone = this.el;
    
    // 阻止浏览器默认拖放行为
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      dropzone.addEventListener(eventName, preventDefaults, false);
      document.body.addEventListener(eventName, preventDefaults, false);
    });
    
    // 处理拖放状态的视觉反馈
    ['dragenter', 'dragover'].forEach(eventName => {
      dropzone.addEventListener(eventName, () => {
        dropzone.classList.add('dragover', 'active-drag');
      }, false);
    });
    
    ['dragleave', 'drop'].forEach(eventName => {
      dropzone.addEventListener(eventName, () => {
        dropzone.classList.remove('dragover', 'active-drag');
      }, false);
    });
    
    // 处理文件拖放
    dropzone.addEventListener('drop', (e) => {
      if (!e.dataTransfer.files || e.dataTransfer.files.length === 0) return;
      
      // 如果有关联的上传按钮，则模拟点击
      const uploadLink = dropzone.querySelector('.file-upload-button');
      if (uploadLink) {
        uploadLink.click();
      }
    }, false);

    function preventDefaults(e) {
      e.preventDefault();
      e.stopPropagation();
    }
  }
};

export default Hooks;
