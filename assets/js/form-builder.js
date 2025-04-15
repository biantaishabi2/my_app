// 表单构建器功能模块

// 条件逻辑编辑器钩子
const ConditionLogicEditor = {
  mounted() {
    console.log("ConditionLogicEditor hook mounted");
    this.setupEventListeners();
  },

  updated() {
    console.log("ConditionLogicEditor hook updated");
  },

  setupEventListeners() {
    // 添加条件按钮
    this.el.querySelector('.add-condition-btn')?.addEventListener('click', e => {
      this.pushEvent("add_simple_condition", {});
    });

    // 添加条件组按钮
    this.el.querySelector('.add-condition-group-btn')?.addEventListener('click', e => {
      this.pushEvent("add_condition_group", {});
    });

    // 删除条件按钮
    this.el.querySelectorAll('.delete-condition-btn').forEach(btn => {
      btn.addEventListener('click', e => {
        const conditionId = e.currentTarget.dataset.conditionId;
        this.pushEvent("delete_condition", { condition_id: conditionId });
      });
    });

    // 条件类型切换
    this.el.querySelectorAll('.condition-operator-select').forEach(select => {
      select.addEventListener('change', e => {
        const conditionId = e.currentTarget.dataset.conditionId;
        const operator = e.currentTarget.value;
        this.pushEvent("update_condition_operator", { 
          condition_id: conditionId,
          operator: operator
        });
      });
    });

    // 条件源选择
    this.el.querySelectorAll('.condition-source-select').forEach(select => {
      select.addEventListener('change', e => {
        const conditionId = e.currentTarget.dataset.conditionId;
        const sourceId = e.currentTarget.value;
        this.pushEvent("update_condition_source", { 
          condition_id: conditionId,
          source_id: sourceId
        });
      });
    });

    // 条件值输入
    this.el.querySelectorAll('.condition-value-input').forEach(input => {
      input.addEventListener('change', e => {
        const conditionId = e.currentTarget.dataset.conditionId;
        const value = e.currentTarget.value;
        this.pushEvent("update_condition_value", { 
          condition_id: conditionId,
          value: value
        });
      });
    });

    // 组合条件类型切换
    this.el.querySelectorAll('.condition-group-type-select').forEach(select => {
      select.addEventListener('change', e => {
        const groupId = e.currentTarget.dataset.groupId;
        const groupType = e.currentTarget.value;
        this.pushEvent("update_condition_group_type", { 
          group_id: groupId,
          group_type: groupType
        });
      });
    });
  }
};

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

// 表单提交钩子 - 已移除验证逻辑，完全依赖后端验证
// 钩子定义保留在这里，但不再使用
const FormSubmit = {};

// 表单构建器的钩子
const FormBuilderHooks = {
  // 表单构建器侧边栏钩子
  FormBuilderSidebar: {
    mounted() {
      console.log("FormBuilderSidebar钩子已挂载");
      this.setupGroupToggles();
    },
    
    updated() {
      this.setupGroupToggles();
    },
    
    setupGroupToggles() {
      // 获取所有分组标题元素
      const groupToggles = document.querySelectorAll('.sidebar-group-title');
      
      // 为每个分组标题添加点击事件
      groupToggles.forEach(toggle => {
        if (!toggle.hasAttribute('data-toggle-setup')) {
          toggle.setAttribute('data-toggle-setup', 'true');
          
          toggle.addEventListener('click', () => {
            const groupId = toggle.id.replace('-toggle', '');
            const contentList = document.getElementById(`${groupId}-list`);
            
            if (contentList) {
              if (contentList.classList.contains('expanded')) {
                contentList.classList.remove('expanded');
                contentList.classList.add('collapsed');
                
                // 添加图标旋转等视觉效果
                toggle.classList.add('collapsed');
              } else {
                contentList.classList.remove('collapsed');
                contentList.classList.add('expanded');
                
                // 移除图标旋转等视觉效果
                toggle.classList.remove('collapsed');
              }
            }
          });
        }
      });
      
      // 设置控件项的点击事件
      const controlItems = document.querySelectorAll('.control-item:not([style*="cursor: not-allowed"])');
      controlItems.forEach(item => {
        if (!item.hasAttribute('data-control-setup')) {
          item.setAttribute('data-control-setup', 'true');
          
          item.addEventListener('click', () => {
            // 移除其他控件的选中状态
            document.querySelectorAll('.control-item.selected').forEach(selected => {
              if (selected !== item) {
                selected.classList.remove('selected');
              }
            });
            
            // 添加当前控件的选中状态
            item.classList.add('selected');
          });
        }
      });
    }
  },
  
  // 表单项编辑器钩子
  FormItemEditor: {
    mounted() {
      console.log("FormItemEditor钩子已挂载");
    }
  }
};

// 表单页面列表排序钩子
const FormPagesList = {
  mounted() {
    console.log("FormPagesList 钩子已挂载 - 初始化拖拽");
    this.initPagesSortable(); // 只在挂载时初始化
  },

  updated() {
    console.log("FormPagesList 钩子已更新 - 不再重新初始化拖拽");
    // this.initPagesSortable(); // <--- 注释掉或删除这一行
  },
  
  // 初始化页面拖拽排序功能
  initPagesSortable() {
    const container = this.el;
    const pages = container.querySelectorAll('[data-page-id]');
    
    if (!pages.length) return;
    
    // 为每个页面添加拖拽事件
    pages.forEach(page => {
      page.setAttribute('draggable', 'true');
      
      // 清除之前可能存在的事件监听器
      page.removeEventListener('dragstart', this.handleDragStart);
      page.removeEventListener('dragover', this.handleDragOver);
      page.removeEventListener('drop', this.handleDrop);
      page.removeEventListener('dragend', this.handleDragEnd);
      
      // 添加新的事件监听器
      page.addEventListener('dragstart', this.handleDragStart.bind(this));
      page.addEventListener('dragover', this.handleDragOver.bind(this));
      page.addEventListener('drop', this.handleDrop.bind(this));
      page.addEventListener('dragend', this.handleDragEnd.bind(this));
    });
  },
  
  handleDragStart(e) {
    const pageId = e.target.dataset.pageId;
    e.dataTransfer.setData('text/plain', pageId);
    e.target.classList.add('dragging');
  },
  
  handleDragOver(e) {
    e.preventDefault();
    const draggingElement = document.querySelector('.dragging');
    if (!draggingElement) return;
    
    const container = this.el;
    const allPages = [...container.querySelectorAll('[data-page-id]:not(.dragging)')];
    
    const pageAfter = allPages.find(page => {
      const rect = page.getBoundingClientRect();
      return e.clientY < rect.top + rect.height / 2;
    });
    
    if (pageAfter) {
      container.insertBefore(draggingElement, pageAfter);
    } else if (allPages.length > 0) {
      container.appendChild(draggingElement);
    }
  },
  
  handleDrop(e) {
    e.preventDefault();
    const draggedPageId = e.dataTransfer.getData('text/plain');
    
    // 获取所有页面的新顺序
    const pageIds = [...this.el.querySelectorAll('[data-page-id]')]
      .map(page => page.dataset.pageId);
    
    // 发送事件到服务器
    this.pushEvent('pages_reordered', { pageIds });
  },
  
  handleDragEnd(e) {
    e.target.classList.remove('dragging');
  }
};

// 导出所有钩子
export default {
  FormBuilder,
  FormSubmit,
  FormBuilderSidebar: FormBuilderHooks.FormBuilderSidebar,
  FormItemEditor: FormBuilderHooks.FormItemEditor,
  FormPagesList,
  ConditionLogicEditor
};