// 表单构建器功能模块

// 表单构建器钩子
const FormBuilder = {
  mounted() {
    console.log("FormBuilder hook mounted");
    this.initSortable();
    this.setupEventListeners();
  },

  updated() {
    console.log("FormBuilder hook updated");
    this.initSortable();
  },

  // 初始化表单项拖拽排序功能
  initSortable() {
    // 这里将在后续实现实际的拖拽排序功能
    // 可能会使用HTML5拖放API或第三方库
    this.formItems = this.el.querySelectorAll('.form-builder-item');
    
    // 为每个表单项添加拖拽事件
    this.formItems.forEach((item, index) => {
      item.setAttribute('draggable', 'true');
      item.dataset.index = index;
      
      // 清除之前可能存在的事件监听器
      item.removeEventListener('dragstart', this.handleDragStart);
      item.removeEventListener('dragover', this.handleDragOver);
      item.removeEventListener('drop', this.handleDrop);
      
      // 添加新的事件监听器
      item.addEventListener('dragstart', this.handleDragStart.bind(this));
      item.addEventListener('dragover', this.handleDragOver.bind(this));
      item.addEventListener('drop', this.handleDrop.bind(this));
    });
  },
  
  // 设置其他事件监听
  setupEventListeners() {
    // 添加表单项的类型选择事件
    const typeSelector = this.el.querySelector('.form-item-type-selector');
    if (typeSelector) {
      typeSelector.addEventListener('change', (e) => {
        this.pushEvent('select-item-type', { type: e.target.value });
      });
    }
    
    // 添加表单项的必填项切换事件
    this.el.addEventListener('click', (e) => {
      if (e.target.matches('.toggle-required')) {
        const itemId = e.target.closest('.form-builder-item').dataset.itemId;
        this.pushEvent('toggle-required', { item_id: itemId });
      }
    });
  },
  
  // 拖拽开始处理
  handleDragStart(e) {
    e.dataTransfer.setData('text/plain', e.target.dataset.index);
    e.target.classList.add('dragging');
  },
  
  // 拖拽经过处理
  handleDragOver(e) {
    e.preventDefault();
    const dragging = this.el.querySelector('.dragging');
    if (!dragging) return;
    
    const notDragging = [...this.formItems].filter(item => item !== dragging);
    const nextItem = notDragging.find(item => {
      const rect = item.getBoundingClientRect();
      const midY = rect.top + rect.height / 2;
      return e.clientY < midY;
    });
    
    if (nextItem) {
      this.el.querySelector('.form-builder-items').insertBefore(dragging, nextItem);
    } else {
      this.el.querySelector('.form-builder-items').appendChild(dragging);
    }
  },
  
  // 拖拽放置处理
  handleDrop(e) {
    e.preventDefault();
    const draggedIndex = e.dataTransfer.getData('text/plain');
    const droppedIndex = e.target.closest('.form-builder-item').dataset.index;
    
    if (draggedIndex !== droppedIndex) {
      // 通知服务器更新顺序
      this.pushEvent('reorder-items', {
        from_index: parseInt(draggedIndex),
        to_index: parseInt(droppedIndex)
      });
    }
    
    // 清除拖拽状态
    this.el.querySelector('.dragging')?.classList.remove('dragging');
  }
};

// 表单提交钩子
const FormSubmit = {
  mounted() {
    console.log("FormSubmit hook mounted");
    this.setupValidation();
  },
  
  // 设置表单验证
  setupValidation() {
    const form = this.el;
    
    form.addEventListener('submit', (e) => {
      // 阻止表单默认提交行为，由LiveView处理
      e.preventDefault();
      
      // 执行客户端验证
      if (this.validateForm()) {
        // 验证通过，推送提交事件到LiveView
        this.pushEvent('submit-form', this.getFormData());
      }
    });
    
    // 为必填字段添加实时验证
    const requiredInputs = form.querySelectorAll('input[required], select[required], textarea[required]');
    requiredInputs.forEach(input => {
      input.addEventListener('blur', () => {
        this.validateField(input);
      });
    });
  },
  
  // 验证整个表单
  validateForm() {
    let isValid = true;
    const form = this.el;
    
    // 验证所有必填字段
    const requiredInputs = form.querySelectorAll('input[required], select[required], textarea[required]');
    requiredInputs.forEach(input => {
      if (!this.validateField(input)) {
        isValid = false;
      }
    });
    
    return isValid;
  },
  
  // 验证单个字段
  validateField(field) {
    const errorElement = field.parentElement.querySelector('.form-error');
    
    // 检查字段值是否为空
    if (!field.value.trim()) {
      if (errorElement) {
        errorElement.textContent = '此字段为必填项';
        errorElement.style.display = 'block';
      }
      field.classList.add('error');
      return false;
    } 
    
    // 检查单选按钮组是否选择了选项
    if (field.type === 'radio') {
      const name = field.name;
      const checked = this.el.querySelector(`input[name="${name}"]:checked`);
      if (!checked) {
        if (errorElement) {
          errorElement.textContent = '请选择一个选项';
          errorElement.style.display = 'block';
        }
        return false;
      }
    }
    
    // 验证通过，清除错误信息
    if (errorElement) {
      errorElement.textContent = '';
      errorElement.style.display = 'none';
    }
    field.classList.remove('error');
    
    return true;
  },
  
  // 获取表单数据
  getFormData() {
    const form = this.el;
    const formData = new FormData(form);
    const data = {};
    
    for (let [key, value] of formData.entries()) {
      data[key] = value;
    }
    
    return data;
  }
};

// 导出所有钩子
export default {
  FormBuilder,
  FormSubmit
};