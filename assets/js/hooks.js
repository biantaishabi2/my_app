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
  handleEvent("update_cities", ({field_id, cities}) => {
    const citySelect = document.getElementById(`${field_id}_city`);
    if (!citySelect) return;
    
    // 清空城市选择
    this.clearOptions(citySelect);
    
    // 添加默认选项
    this.addOption(citySelect, "", "市", true, true);
    
    // 添加城市选项
    cities.forEach(city => {
      this.addOption(citySelect, city.name, city.name);
    });
    
    // 启用城市选择
    citySelect.disabled = false;
  }),
  
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
  handleEvent("update_districts", ({field_id, districts}) => {
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
  })
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

export default Hooks;
