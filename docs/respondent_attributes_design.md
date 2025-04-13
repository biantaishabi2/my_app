# 回答者属性及分组统计功能设计方案

## 1. 背景与需求

目前系统的表单回答收集了基本的回答者信息（姓名和邮箱），但缺乏更丰富的回答者属性收集和按属性分组统计的能力。本设计方案旨在扩展回答者属性系统，实现按属性（如性别、部门等）进行分组统计分析的功能。

## 2. 回答者属性系统设计

### 2.1 回答者属性类型

设计一套全面的回答者属性收集系统，包括常见的人口统计和组织属性：

1. **基础个人信息**
   - 姓名 (name) - 已有
   - 邮箱 (email) - 已有
   - 手机号码 (phone)
   - 性别 (gender) - 选项：男/女/其他/不愿透露
   - 出生日期 (birth_date)
   - 年龄段 (age_group) - 选项：18岁以下/18-24/25-34/35-44/45-54/55-64/65岁以上

2. **组织与职业信息**
   - 部门 (department)
   - 职位 (position)
   - 工号 (employee_id)
   - 入职时间 (hire_date)
   - 工作类型 (job_type) - 选项：全职/兼职/合同工/实习生
   - 工作地点 (work_location)
   - 管理级别 (management_level) - 选项：员工/团队负责人/部门经理/高管

3. **学历与教育信息**
   - 最高学历 (education_level) - 选项：高中/专科/本科/硕士/博士
   - 专业领域 (major_field)
   - 毕业院校 (school)

4. **其他分类属性**
   - 用户类型 (user_type) - 选项：客户/员工/合作伙伴/供应商
   - 客户等级 (customer_level) - 选项：普通/VIP/钻石
   - 地区 (region) - 使用现有区域选择控件

### 2.2 数据结构设计

扩展Form模型，添加respondent_attributes字段，用于存储表单需要收集的回答者属性配置：

```elixir
# 数据库结构扩展 - 在form表中添加respondent_attributes字段
field :respondent_attributes, {:array, :map}, default: [
  %{id: "name", label: "姓名", type: :text, required: true},
  %{id: "email", label: "邮箱", type: :email, required: true}
]
```

每个属性定义为具有以下结构的map：
- `id`: 属性唯一标识符
- `label`: 显示标签
- `type`: 控件类型(text, email, phone, select, date等)
- `required`: 是否必填
- `options`: 针对select类型的选项列表
- `description`: 属性描述
- `default_value`: 默认值

数据库迁移脚本：

```elixir
defmodule MyApp.Repo.Migrations.AddRespondentAttributesToForms do
  use Ecto.Migration

  def change do
    alter table(:forms) do
      add :respondent_attributes, {:array, :map}, default: []
    end
  end
end
```

## 3. 用户界面实现

### 3.1 回答者信息收集组件

创建通用回答者信息收集组件，动态根据表单配置渲染属性输入控件：

```heex
<div class="respondent-info-section">
  <h3>回答者信息</h3>
  <%= for attr <- @form.respondent_attributes do %>
    <div class="form-group">
      <label for={attr.id}>
        <%= attr.label %>
        <%= if attr.required do %>
          <span class="required">*</span>
        <% end %>
      </label>
      
      <%= case attr.type do %>
        <% :text -> %>
          <input type="text" 
                 id={attr.id} 
                 name={"respondent_info[#{attr.id}]"} 
                 value={@respondent_info[attr.id] || attr.default_value}
                 class="form-control" 
                 required={attr.required} />
                 
        <% :email -> %>
          <input type="email" 
                 id={attr.id} 
                 name={"respondent_info[#{attr.id}]"} 
                 value={@respondent_info[attr.id] || attr.default_value}
                 class="form-control" 
                 required={attr.required} />
                 
        <% :select -> %>
          <select id={attr.id} 
                  name={"respondent_info[#{attr.id}]"} 
                  class="form-control" 
                  required={attr.required}>
            <option value="">请选择</option>
            <%= for opt <- attr.options do %>
              <option value={opt.value} selected={@respondent_info[attr.id] == opt.value}>
                <%= opt.label %>
              </option>
            <% end %>
          </select>
          
        <% :date -> %>
          <input type="date" 
                 id={attr.id} 
                 name={"respondent_info[#{attr.id}]"} 
                 value={@respondent_info[attr.id] || attr.default_value}
                 class="form-control" 
                 required={attr.required} />
                 
        <% _ -> %>
          <input type="text" 
                 id={attr.id} 
                 name={"respondent_info[#{attr.id}]"} 
                 value={@respondent_info[attr.id] || attr.default_value}
                 class="form-control" 
                 required={attr.required} />
      <% end %>
      
      <%= if attr.description do %>
        <small class="form-text text-muted"><%= attr.description %></small>
      <% end %>
    </div>
  <% end %>
</div>
```

### 3.2 属性字段管理UI

创建表单设计器中的回答者属性配置界面：

```heex
<div class="respondent-attributes-config">
  <h3>回答者信息收集设置</h3>
  
  <div class="attributes-list">
    <%= for {attr, index} <- Enum.with_index(@form.respondent_attributes) do %>
      <div class="attribute-item">
        <div class="attribute-header">
          <h4><%= attr.label %></h4>
          <div class="attribute-actions">
            <button type="button" phx-click="edit_attribute" phx-value-index={index}>
              编辑
            </button>
            <button type="button" phx-click="remove_attribute" phx-value-index={index}>
              删除
            </button>
          </div>
        </div>
        <div class="attribute-details">
          <span class="attribute-type"><%= humanize_attribute_type(attr.type) %></span>
          <%= if attr.required do %>
            <span class="attribute-required">必填</span>
          <% end %>
        </div>
      </div>
    <% end %>
    
    <button type="button" class="add-attribute-btn" phx-click="add_attribute">
      添加回答者属性
    </button>
  </div>
  
  <%= if @show_attribute_form do %>
    <div class="attribute-form-modal">
      <div class="attribute-form">
        <h4><%= if @editing_attribute, do: "编辑属性", else: "添加属性" %></h4>
        
        <form phx-submit={if @editing_attribute, do: "update_attribute", else: "create_attribute"}>
          <input type="hidden" name="attribute_index" value={@editing_attribute_index}>
          
          <div class="form-group">
            <label for="attribute_id">标识符</label>
            <input type="text" id="attribute_id" name="attribute[id]" value={@current_attribute.id} required />
          </div>
          
          <div class="form-group">
            <label for="attribute_label">显示名称</label>
            <input type="text" id="attribute_label" name="attribute[label]" value={@current_attribute.label} required />
          </div>
          
          <div class="form-group">
            <label for="attribute_type">类型</label>
            <select id="attribute_type" name="attribute[type]" phx-change="attribute_type_changed">
              <option value="text" selected={@current_attribute.type == :text}>文本</option>
              <option value="email" selected={@current_attribute.type == :email}>邮箱</option>
              <option value="phone" selected={@current_attribute.type == :phone}>电话</option>
              <option value="select" selected={@current_attribute.type == :select}>下拉选择</option>
              <option value="date" selected={@current_attribute.type == :date}>日期</option>
            </select>
          </div>
          
          <div class="form-group">
            <label for="attribute_description">描述说明</label>
            <textarea id="attribute_description" name="attribute[description]"><%= @current_attribute.description %></textarea>
          </div>
          
          <div class="form-group">
            <label class="checkbox-label">
              <input type="checkbox" name="attribute[required]" checked={@current_attribute.required} />
              必填字段
            </label>
          </div>
          
          <%= if @current_attribute.type == :select do %>
            <div class="options-section">
              <h5>选项列表</h5>
              <%= for {opt, idx} <- Enum.with_index(@current_attribute.options || []) do %>
                <div class="option-row">
                  <input type="text" name={"attribute[options][#{idx}][label]"} placeholder="选项标签" value={opt.label} />
                  <input type="text" name={"attribute[options][#{idx}][value]"} placeholder="选项值" value={opt.value} />
                  <button type="button" phx-click="remove_option" phx-value-index={idx}>删除</button>
                </div>
              <% end %>
              <button type="button" phx-click="add_option">添加选项</button>
            </div>
          <% end %>
          
          <div class="form-actions">
            <button type="button" phx-click="cancel_attribute_form">取消</button>
            <button type="submit">保存</button>
          </div>
        </form>
      </div>
    </div>
  <% end %>
</div>
```

### 3.3 常用属性模板

提供常用回答者属性模板，方便用户快速添加常见属性：

```heex
<div class="attribute-templates">
  <h4>常用属性模板</h4>
  <div class="template-buttons">
    <button type="button" phx-click="add_template_attribute" phx-value-template="gender">
      性别
    </button>
    <button type="button" phx-click="add_template_attribute" phx-value-template="department">
      部门
    </button>
    <button type="button" phx-click="add_template_attribute" phx-value-template="age_group">
      年龄段
    </button>
    <button type="button" phx-click="add_template_attribute" phx-value-template="education">
      学历
    </button>
    <button type="button" phx-click="add_template_attribute" phx-value-template="job_type">
      工作类型
    </button>
    <!-- 更多模板按钮 -->
  </div>
</div>
```

## 4. 分组统计功能实现

### 4.1 后端API扩展

扩展统计导出功能，支持按回答者属性分组统计：

```elixir
def export_statistics_by_respondent_attribute(form_id, attribute_id, options \\ %{}) do
  # 验证表单存在
  case Forms.get_form_with_items(form_id) do
    nil -> 
      {:error, :not_found}
    form ->
      # 获取响应数据
      responses = get_filtered_responses(form_id, options)
      
      # 按指定属性分组
      grouped_responses = group_responses_by_attribute(responses, attribute_id)
      
      # 生成分组统计
      generate_grouped_statistics_csv(form, grouped_responses, attribute_id)
  end
end

# 按属性分组响应
defp group_responses_by_attribute(responses, attribute_id) do
  responses
  |> Enum.group_by(fn response ->
    # 从respondent_info中获取属性值
    get_in(response.respondent_info, [attribute_id]) || "未指定"
  end)
end

# 生成分组统计CSV
defp generate_grouped_statistics_csv(form, grouped_responses, attribute_id) do
  # 获取表单项
  form_items = form.pages |> Enum.flat_map(& &1.items) |> Enum.sort_by(& &1.order)
  
  # 创建CSV头
  csv_data = [
    ["表单标题:", form.title],
    ["分组属性:", attribute_id],
    []
  ]
  
  # 为每个分组生成统计数据
  Enum.reduce(grouped_responses, csv_data, fn {group_value, group_responses}, acc ->
    # 添加分组标题
    group_header = [
      [],
      ["#{attribute_id}:", "#{group_value}"],
      ["回答数量:", "#{length(group_responses)}"],
      []
    ]
    
    # 为该分组内的每个表单项生成统计
    group_stats = Enum.reduce(form_items, [], fn item, item_acc ->
      case item.type do
        :radio -> 
          item_acc ++ generate_choice_statistics_for_group(item, group_responses, "单选题")
        :checkbox -> 
          item_acc ++ generate_choice_statistics_for_group(item, group_responses, "多选题")
        :rating -> 
          item_acc ++ generate_rating_statistics_for_group(item, group_responses)
        :text_input -> 
          item_acc ++ generate_text_statistics_for_group(item, group_responses)
        _ -> 
          item_acc
      end
    end)
    
    # 合并该分组的所有统计数据
    acc ++ group_header ++ group_stats
  end)
  |> (fn data -> 
    # 转换为CSV字符串
    {:ok, CSV.dump_to_iodata(data) |> IO.iodata_to_binary()}
  end).()
end

# 为分组生成选择题统计
defp generate_choice_statistics_for_group(item, group_responses, item_type) do
  # 这里的实现类似于现有generate_choice_statistics函数，但限定在group_responses范围内
  # ...
end

# 为分组生成评分题统计
defp generate_rating_statistics_for_group(item, group_responses) do
  # 这里的实现类似于现有generate_rating_statistics函数，但限定在group_responses范围内
  # ...
end

# 为分组生成文本题统计
defp generate_text_statistics_for_group(item, group_responses) do
  # 这里的实现类似于现有generate_text_statistics函数，但限定在group_responses范围内
  # ...
end
```

### 4.2 统计分析与可视化UI

扩展表单响应分析页面，添加按回答者属性分组的图表和报表：

```heex
<div class="statistics-tabs">
  <button class="tab-button <%= if @active_tab == "summary", do: "active" %>" 
          phx-click="switch_tab" phx-value-tab="summary">
    总体统计
  </button>
  <button class="tab-button <%= if @active_tab == "by_attribute", do: "active" %>" 
          phx-click="switch_tab" phx-value-tab="by_attribute">
    按属性分组
  </button>
</div>

<%= if @active_tab == "by_attribute" do %>
  <div class="attribute-selector">
    <form phx-change="select_grouping_attribute">
      <label for="grouping_attribute">选择分组属性:</label>
      <select id="grouping_attribute" name="attribute_id">
        <%= for attr <- @form.respondent_attributes do %>
          <option value={attr.id} <%= if @selected_attribute == attr.id, do: "selected" %>>
            <%= attr.label %>
          </option>
        <% end %>
      </select>
    </form>
  </div>
  
  <!-- 分组统计图表和表格 -->
  <div class="grouped-statistics">
    <%= for item <- @form_items do %>
      <div class="item-statistics-card">
        <h3><%= item.label %></h3>
        
        <%= case item.type do %>
          <% type when type in [:radio, :checkbox] -> %>
            <div class="grouped-chart-container" id={"grouped_chart_#{item.id}"} phx-hook="GroupedBarChart" 
                 data-item-id={item.id} data-groups={Jason.encode!(@grouped_stats[item.id])}>
            </div>
            
          <% :rating -> %>
            <div class="grouped-chart-container" id={"grouped_chart_#{item.id}"} phx-hook="GroupedRatingChart"
                 data-item-id={item.id} data-groups={Jason.encode!(@grouped_stats[item.id])}>
            </div>
            
          <% _ -> %>
            <p>该题型不支持分组图表显示</p>
        <% end %>
      </div>
    <% end %>
  </div>
<% else %>
  <!-- 现有的总体统计内容 -->
<% end %>
```

### 4.3 导出UI扩展

扩展导出功能UI，增加按回答者属性分组导出的选项：

```heex
<div class="export-options">
  <h3>导出选项</h3>
  
  <div class="export-type-selector">
    <label>
      <input type="radio" name="export_type" value="responses" checked={@export_type == "responses"} phx-click="select_export_type" phx-value-type="responses">
      导出原始回答数据
    </label>
    <label>
      <input type="radio" name="export_type" value="statistics" checked={@export_type == "statistics"} phx-click="select_export_type" phx-value-type="statistics">
      导出总体统计数据
    </label>
    <label>
      <input type="radio" name="export_type" value="grouped_statistics" checked={@export_type == "grouped_statistics"} phx-click="select_export_type" phx-value-type="grouped_statistics">
      导出分组统计数据
    </label>
  </div>
  
  <%= if @export_type == "grouped_statistics" do %>
    <div class="grouping-attribute-selector">
      <label for="grouping_attribute">选择分组属性:</label>
      <select id="grouping_attribute" name="attribute_id" phx-change="select_export_attribute">
        <%= for attr <- @form.respondent_attributes do %>
          <option value={attr.id} <%= if @selected_attribute == attr.id, do: "selected" %>>
            <%= attr.label %>
          </option>
        <% end %>
      </select>
    </div>
  <% end %>
  
  <!-- 日期范围筛选 -->
  <div class="date-range-filter">
    <h4>日期筛选</h4>
    <div class="date-inputs">
      <div class="form-group">
        <label for="start_date">开始日期</label>
        <input type="date" id="start_date" name="start_date" value={@start_date} phx-change="update_date_filter">
      </div>
      <div class="form-group">
        <label for="end_date">结束日期</label>
        <input type="date" id="end_date" name="end_date" value={@end_date} phx-change="update_date_filter">
      </div>
    </div>
  </div>
  
  <button class="export-button" phx-click="export_data">
    导出 CSV
  </button>
</div>
```

## 5. 前端交互实现

### 5.1 回答者属性模板JavaScript

提供预定义回答者属性模板的JavaScript实现：

```javascript
// assets/js/form-attribute-templates.js
const attributeTemplates = {
  gender: {
    id: "gender",
    label: "性别",
    type: "select",
    required: false,
    description: "请选择您的性别",
    options: [
      { label: "男", value: "male" },
      { label: "女", value: "female" },
      { label: "其他", value: "other" },
      { label: "不愿透露", value: "prefer_not_to_say" }
    ]
  },
  
  department: {
    id: "department",
    label: "部门",
    type: "select",
    required: false,
    description: "请选择您所在的部门",
    options: [
      { label: "研发", value: "rd" },
      { label: "市场", value: "marketing" },
      { label: "销售", value: "sales" },
      { label: "人力资源", value: "hr" },
      { label: "财务", value: "finance" },
      { label: "行政", value: "admin" },
      { label: "其他", value: "other" }
    ]
  },
  
  age_group: {
    id: "age_group",
    label: "年龄段",
    type: "select",
    required: false,
    description: "请选择您的年龄段",
    options: [
      { label: "18岁以下", value: "under_18" },
      { label: "18-24岁", value: "18-24" },
      { label: "25-34岁", value: "25-34" },
      { label: "35-44岁", value: "35-44" },
      { label: "45-54岁", value: "45-54" },
      { label: "55-64岁", value: "55-64" },
      { label: "65岁以上", value: "65_and_over" }
    ]
  },
  
  education: {
    id: "education_level",
    label: "最高学历",
    type: "select",
    required: false,
    description: "请选择您的最高学历",
    options: [
      { label: "高中/中专及以下", value: "high_school" },
      { label: "大专", value: "junior_college" },
      { label: "本科", value: "bachelor" },
      { label: "硕士", value: "master" },
      { label: "博士及以上", value: "phd" }
    ]
  },
  
  job_type: {
    id: "job_type",
    label: "工作类型",
    type: "select",
    required: false,
    description: "请选择您的工作类型",
    options: [
      { label: "全职", value: "full_time" },
      { label: "兼职", value: "part_time" },
      { label: "合同工", value: "contractor" },
      { label: "实习生", value: "intern" },
      { label: "自由职业", value: "freelancer" }
    ]
  },
  
  management_level: {
    id: "management_level",
    label: "管理级别",
    type: "select",
    required: false,
    description: "请选择您的管理级别",
    options: [
      { label: "普通员工", value: "employee" },
      { label: "团队负责人", value: "team_lead" },
      { label: "部门经理", value: "department_manager" },
      { label: "总监", value: "director" },
      { label: "高管", value: "executive" }
    ]
  },
  
  phone: {
    id: "phone",
    label: "手机号码",
    type: "phone",
    required: false,
    description: "请输入您的手机号码"
  },
  
  hire_date: {
    id: "hire_date",
    label: "入职时间",
    type: "date",
    required: false,
    description: "请选择您的入职日期"
  }
};

export default attributeTemplates;
```

### 5.2 分组图表可视化JavaScript

使用Chart.js实现分组统计图表：

```javascript
// assets/js/grouped-charts.js
import Chart from 'chart.js/auto';

// 初始化分组条形图
const initGroupedBarChart = (element) => {
  const itemId = element.dataset.itemId;
  const groupsData = JSON.parse(element.dataset.groups);
  
  // 提取标签和数据系列
  const labels = Object.keys(groupsData[0].data);
  const datasets = groupsData.map(group => ({
    label: group.name,
    data: Object.values(group.data),
    backgroundColor: getRandomColor()
  }));
  
  // 创建图表
  new Chart(element, {
    type: 'bar',
    data: {
      labels,
      datasets
    },
    options: {
      responsive: true,
      plugins: {
        legend: {
          position: 'top',
        },
        title: {
          display: true,
          text: '按分组的选项分布'
        }
      }
    }
  });
};

// 初始化分组评分图表
const initGroupedRatingChart = (element) => {
  const itemId = element.dataset.itemId;
  const groupsData = JSON.parse(element.dataset.groups);
  
  // 创建数据集
  const datasets = groupsData.map(group => ({
    label: group.name,
    data: [group.avg],
    backgroundColor: getRandomColor()
  }));
  
  // 创建图表
  new Chart(element, {
    type: 'bar',
    data: {
      labels: ['平均分'],
      datasets
    },
    options: {
      responsive: true,
      scales: {
        y: {
          beginAtZero: true,
          max: 5 // 根据评分最大值调整
        }
      },
      plugins: {
        legend: {
          position: 'top',
        },
        title: {
          display: true,
          text: '按分组的平均评分'
        }
      }
    }
  });
};

// 获取随机颜色
const getRandomColor = () => {
  const letters = '0123456789ABCDEF';
  let color = '#';
  for (let i = 0; i < 6; i++) {
    color += letters[Math.floor(Math.random() * 16)];
  }
  return color;
};

// 注册钩子
const GroupedChartsHooks = {
  GroupedBarChart: {
    mounted() {
      initGroupedBarChart(this.el);
    }
  },
  GroupedRatingChart: {
    mounted() {
      initGroupedRatingChart(this.el);
    }
  }
};

export default GroupedChartsHooks;
```

## 6. 实现计划与优先级

实现该功能的建议阶段划分：

### 阶段一：数据结构与后端基础实现
1. 添加Form模型的respondent_attributes字段
2. 创建必要的迁移脚本
3. 扩展Responses模块，添加分组统计功能
4. 更新表单提交页面，支持动态回答者信息收集

### 阶段二：表单编辑器UI扩展
1. 实现回答者属性配置界面
2. 添加常用属性模板功能
3. 集成到表单编辑器

### 阶段三：统计与导出功能
1. 实现按属性分组的统计计算
2. 扩展导出CSV功能，支持分组统计
3. 构建分组统计UI和可视化图表

### 阶段四：优化与完善
1. 性能优化，特别是大数据量分组统计
2. 添加更丰富的可视化图表类型
3. 支持多属性交叉分组分析

## 7. 总结

本设计方案全面涵盖了回答者属性收集和按属性分组统计的功能，支持多种常用回答者属性，并提供了灵活的配置和分析能力。系统通过统一的回答者属性收集组件和扩展的统计功能，可以轻松实现按性别、部门等任意回答者属性的分组统计和分析。

这些功能将显著增强表单系统的数据分析能力，为用户提供更丰富、更有深度的表单数据分析工具，帮助他们更好地理解和利用收集到的数据。

## 8. V2 设计方案：集成工会系统自动关联回答者属性 (规划中)

### 8.1 背景与目标 (V2)

针对内部员工调研场景，并且问卷系统与内部工会系统集成，可以设计一套更优化的回答者属性处理方案 (V2)。该方案旨在：

1.  **简化填表体验**：员工无需手动填写工会系统中已有的个人信息（如部门、性别、职位等）。
2.  **提高数据准确性**：直接从权威数据源（工会系统）获取信息，避免手动输入错误。
3.  **简化表单创建**：表单创建者只需选择需要关联的员工属性，无需设计具体问题。
4.  **保留统计能力**：自动关联的属性可用于后台的回答分组统计。

### 8.2 核心设计思路 (V2)

核心思路是从"用户手动填写属性"转变为"系统自动关联属性"。

1.  **身份识别**：
    *   假设员工通过工会系统访问问卷链接。
    *   工会系统在跳转或加载问卷页面时，通过 Session 或 URL 参数等方式，将当前登录员工的唯一标识符（如 `employee_id`）传递给问卷系统。
2.  **属性获取**：
    *   问卷系统后端接收到 `employee_id`。
    *   在用户提交问卷时（或加载页面时），根据 `employee_id` 调用工会系统的接口 (API) 或直接查询工会系统数据库，获取该员工预定义的一组属性（如姓名、性别、部门、职位、角色等）。
3.  **数据关联与存储**：
    *   获取到的员工属性数据，与该员工提交的问卷回答一起保存。这些属性可以存储在 `Response` 数据表的 `respondent_info` 字段中，或者新增专门字段。
    *   这些自动关联的属性可以选择不在提交页面上对员工可见，以简化界面。但需要考虑隐私告知。
4.  **表单设置简化**：
    *   在表单编辑器中，不再需要手动创建"部门"、"性别"等回答者属性字段。
    *   改为提供一个配置区域，允许表单创建者勾选希望从工会系统自动关联并附加到回答结果中的员工属性字段列表（例如：[x] 部门 [ ] 性别 [x] 职位）。
5.  **统计分析**：
    *   在查看回复和统计分析页面，系统可以读取存储在 `respondent_info` 或专门字段中的自动关联属性，用于分组、筛选和统计，与 V1 手动填写的属性使用方式类似。

### 8.3 实现步骤与计划 (V2)

此 V2 方案目前处于**规划阶段**，尚未开始实施。

1.  **[ ] 定义属性映射与配置 (设计/后端)**
    *   梳理并确定需要从工会系统同步的关键员工属性（如：`工号 employee_id`, `姓名 real_name`, `性别 gender`, `部门 department`, `职位 position`, `角色 role` 等）。
    *   明确这些工会系统字段与问卷系统内部"回答者属性"概念的映射关系。
    *   设计如何在问卷系统的配置中（可能是代码配置或数据库配置）存储这个映射关系，以及定义哪些属性是可供表单创建者选择关联的。
2.  **[ ] API/数据库对接 (后端)**
    *   基于第一步定义的映射，确定需要从工会系统获取的具体字段。
    *   确定工会系统提供这些字段的方式（API 优先，或数据库访问权限）。
    *   实现问卷系统后端服务，根据 `employee_id` 安全、高效地从工会系统获取所需属性。
    *   处理接口异常、数据缺失等情况。
3.  **[ ] 身份传递机制 (前端/后端)**
    *   与工会系统协调，确定传递 `employee_id` 的方式（Session 集成、URL 参数、请求头等）。
    *   问卷系统后端能够正确接收和验证 `employee_id`。
4.  **[ ] 表单编辑器改造 (UI/后端)**
    *   移除或隐藏 V1 的回答者属性手动创建界面（或标记为外部问卷专用）。
    *   新增"关联工会系统属性"的配置界面，动态加载第一步中定义的、可供关联的员工属性供勾选。
    *   保存表单时，存储用户选择需要关联的属性字段列表（例如，更新 `Form` 表的结构或使用现有字段）。
5.  **[ ] 数据关联逻辑 (后端)**
    *   在 `Response` 保存时，根据表单配置中勾选的关联属性，触发属性获取逻辑（调用第2步实现的接口/查询），并将结果存入 `respondent_info` 或新字段。
6.  **[ ] 隐私与告知 (UI/流程)**
    *   设计在问卷提交前（或页面加载时）向员工明确告知哪些已定义的个人信息将被关联，并获得同意（如果法规要求）。
7.  **[ ] 统计功能适配 (后端/UI)**
    *   确保统计分析模块能够识别和使用自动关联的属性进行分组。

### 8.4 V2 设计的优势与挑战

*   **优势**：极大提升内部员工填表效率和数据准确性，简化表单创建。
*   **挑战**：强依赖工会系统的接口或数据访问；必须解决可靠的身份识别问题；需要处理数据隐私告知；只适用于特定内部场景。