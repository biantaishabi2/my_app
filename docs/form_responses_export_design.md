# 表单回答导出与统计功能设计

## 1. 功能概述

为表单回答(Response)系统添加数据导出和基础统计功能，使管理员能够：
- 以CSV/Excel格式导出表单回答数据
- 按时间范围筛选导出数据
- 查看选择题和评分题的基础统计分析
- 按回答者属性(性别、部门等)进行分组统计分析
- 下载统计报表

## 2. 实现计划

### 2.1 后端API实现

- [x] 设计文档
- [x] 定义导出数据的格式结构
- [x] 实现数据统计处理功能
- [x] 实现数据导出为CSV格式功能
- [x] 添加时间筛选参数
- [x] 编写单元测试
- [x] 实现回答者属性分组统计模块
- [ ] 实现导出控制器或Live View处理函数

### 2.2 前端实现

- [ ] 在回答列表页添加导出按钮
- [ ] 添加导出选项(所有数据/统计摘要)
- [ ] 实现日期筛选组件
- [ ] 添加导出格式选择(CSV/Excel)
- [ ] 实现回答者属性设置界面
- [ ] 创建按回答者属性分组统计页面
- [ ] 优化下载用户体验(进度提示等)

## 3. 数据结构设计

### 3.1 导出数据格式

标准CSV格式，包含以下列：
- 回答ID
- 提交时间
- 回答者信息 (可选字段，如姓名、邮箱等)
- 每个表单项的问题和回答(动态列，根据表单结构生成)

### 3.2 统计数据格式

对于选择题和评分题，生成以下统计信息：
- 选择题：每个选项的选择计数和百分比
- 评分题：平均分、最高分、最低分
- 文本题：回答数量统计(不含具体内容)

### 3.3 按回答者属性分组统计数据格式

```elixir
[
  %{
    attribute_value: "男",
    count: 25,
    item_statistics: %{
      "item_id_1" => %{
        type: :radio,
        item_label: "问题1",
        options: [
          %{option_id: "opt1", option_label: "选项A", count: 15, percentage: 60},
          %{option_id: "opt2", option_label: "选项B", count: 10, percentage: 40}
        ]
      },
      "item_id_2" => %{
        type: :rating,
        item_label: "问题2",
        stats: %{count: 25, avg: 4.2, min: 2, max: 5, distribution: [...]}
      }
    }
  },
  %{
    attribute_value: "女",
    count: 30,
    item_statistics: {
      # 类似结构...
    }
  }
]
```

## 4. API设计

### 4.1 导出原始数据API

```elixir
# 在Responses模块中添加
def export_responses(form_id, options \\ %{}) do
  # 获取表单及其项目
  # 获取筛选后的回答数据
  # 转换为CSV格式
  # 返回二进制数据
end
```

选项参数包括：
- `format`: "csv" 或 "excel"
- `start_date`: 开始日期(可选)
- `end_date`: 结束日期(可选)
- `include_respondent_info`: 是否包含回答者信息

### 4.2 导出统计数据API

```elixir
# 在Responses模块中添加
def export_statistics(form_id, options \\ %{}) do
  # 获取表单结构
  # 统计选择题和评分题数据
  # 转换为CSV格式
  # 返回二进制数据
end
```

### 4.3 按回答者属性分组导出统计数据API

```elixir
# 在Responses.GroupedStatistics模块中添加
def export_statistics_by_attribute(form_id, attribute_id, options \\ %{}) do
  # 验证属性ID
  # 获取表单和回答
  # 按属性对回答进行分组
  # 生成每个分组的统计数据
  # 转换为CSV格式
  # 返回二进制数据
end

# 获取按属性分组的统计数据
def get_grouped_statistics(form_id, attribute_id, options \\ %{}) do
  # 验证属性ID
  # 获取表单和回答
  # 按属性对回答进行分组
  # 计算每个分组的统计数据
  # 返回分组统计数据
end
```

## 5. 控制器/Live组件设计

### 5.1 基础导出功能

为FormLive.Responses模块添加导出功能：

```elixir
# 在FormLive.Responses模块中添加
def handle_event("export_data", %{"format" => format, "type" => type} = params, socket) do
  form_id = socket.assigns.form.id
  options = %{
    format: format,
    start_date: params["start_date"],
    end_date: params["end_date"],
    include_respondent_info: params["include_respondent_info"] == "true"
  }
  
  {filename, binary_data} = 
    case type do
      "raw" -> 
        {"responses_#{form_id}.#{format}", Responses.export_responses(form_id, options)}
      "statistics" -> 
        {"statistics_#{form_id}.#{format}", Responses.export_statistics(form_id, options)}
    end
    
  {:noreply,
   socket
   |> put_flash(:info, "导出成功")
   |> push_event("download", %{filename: filename, content: binary_data})}
end
```

### 5.2 分组统计页面设计

创建新的FormLive.Statistics Live View组件：

```elixir
# 新建FormLive.Statistics模块
defmodule MyAppWeb.FormLive.Statistics do
  use MyAppWeb, :live_view
  
  alias MyApp.Forms
  alias MyApp.Responses
  
  @impl true
  def mount(%{"id" => form_id}, _session, socket) do
    # 获取表单和属性列表
    case Forms.get_form(form_id) do
      nil -> 
        {:ok, socket |> put_flash(:error, "表单不存在") |> redirect(to: ~p"/forms")}
      form ->
        # 获取表单的回答者属性设置
        respondent_attributes = form.respondent_attributes || []
        
        {:ok, 
         socket
         |> assign(:form, form)
         |> assign(:respondent_attributes, respondent_attributes)
         |> assign(:selected_attribute_id, nil)
         |> assign(:grouped_statistics, nil)}
    end
  end
  
  @impl true
  def handle_event("select_attribute", %{"attribute_id" => attribute_id}, socket) do
    form_id = socket.assigns.form.id
    
    # 获取分组统计数据
    case Responses.get_grouped_statistics(form_id, attribute_id) do
      {:ok, stats} ->
        {:noreply, 
         socket
         |> assign(:selected_attribute_id, attribute_id)
         |> assign(:grouped_statistics, stats)}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "获取统计数据失败: #{reason}")}
    end
  end
  
  @impl true
  def handle_event("export_grouped_statistics", %{"attribute_id" => attribute_id}, socket) do
    form_id = socket.assigns.form.id
    
    # 导出分组统计数据
    case Responses.export_statistics_by_attribute(form_id, attribute_id) do
      {:ok, csv_data} ->
        {:noreply,
         socket
         |> put_flash(:info, "导出成功")
         |> push_event("download", %{
              filename: "grouped_statistics_#{form_id}_by_#{attribute_id}.csv", 
              content: csv_data
            })}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "导出失败: #{reason}")}
    end
  end
end
```

## 6. 实现注意事项

### 6.1 性能考虑

- 对于大量回答数据，使用流处理(Stream)减少内存占用
- 考虑使用后台任务处理导出，避免长时间阻塞请求
- 对于大型表单，可能需要分页导出或限制日期范围

### 6.2 安全考虑

- 验证用户对表单数据的访问权限
- 敏感信息导出时考虑使用加密CSV或受密码保护的Excel
- 添加导出操作的日志记录

### 6.3 用户体验

- 大型导出操作时显示进度提示
- 导出完成后提供通知
- 简洁清晰的导出选项界面

## 7. 技术依赖

- CSV生成：使用`NimbleCSV`库 (已实现)
- 时间处理：使用Elixir内置DateTime (已实现)
- Excel生成：考虑使用`Elixlsx`库 (未来扩展)

## 8. 实现总结

已完成的功能：
- 表单回答原始数据导出为CSV格式
- 基于表单回答的统计数据生成和导出
- 按日期范围筛选回答数据
- 错误处理（无效表单ID、无效日期、无效格式选项）
- 完整的单元测试覆盖

## 9. 后续优化方向

- 实现前端交互界面
- 添加Excel格式导出支持
- 添加更复杂的数据分析功能
- 添加可视化图表导出
- 支持自定义导出字段选择
- 添加定期自动导出和邮件发送功能
- 实现分组间数据比较功能
- 开发统计数据可视化图表组件
- 支持多属性交叉分析(如同时按性别和部门分组)

## 10. 回答者属性设置与分组统计流程

### 10.1 回答者属性设置流程

1. 在表单编辑页面，点击"回答者属性设置"按钮
2. 打开回答者属性设置界面，可以添加/编辑属性设置：
   - 添加常用属性(如性别、部门等)
   - 自定义新属性
   - 设置属性是否必填
3. 属性设置保存后，将在表单提交页面添加相应输入字段
4. 提交表单时，这些属性值会保存在响应的respondent_info字段中

### 10.2 回答者属性数据收集

当前的实现存在一个问题：表单提交页面只显示了固定的姓名和邮箱字段，没有动态显示表单中配置的自定义回答者属性。需要进行以下改进：

1. 修改表单提交页面，动态渲染所有自定义回答者属性：
   ```heex
   <!-- 回答者信息 -->
   <div class="respondent-info mb-8">
     <h3 class="text-lg font-medium mb-4">您的联系信息</h3>
     <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
       <%= for attr <- @form.respondent_attributes do %>
         <div class="form-group">
           <label for={"respondent_#{attr.id}"} class="block text-sm font-medium mb-1">
             <%= attr.label %>
             <%= if attr.required do %><span class="text-red-500">*</span><% end %>
           </label>
           
           <!-- 根据属性类型渲染不同的输入控件 -->
           <%= case attr.type do %>
             <% "select" -> %>
               <select id={"respondent_#{attr.id}"} name={"respondent_info[#{attr.id}]"} 
                      class="form-control w-full p-2 border rounded">
                 <option value="">-- 请选择 --</option>
                 <%= for opt <- attr.options || [] do %>
                   <option value={opt.value}><%= opt.label %></option>
                 <% end %>
               </select>
             <% _ -> %>
               <input type={attr.type} id={"respondent_#{attr.id}"} name={"respondent_info[#{attr.id}]"}
                     class="form-control w-full p-2 border rounded" />
           <% end %>
         </div>
       <% end %>
     </div>
   </div>
   ```

2. 这样用户填写的自定义属性值会保存到respondent_info字段中，便于后续分组统计分析。

### 10.3 分组统计访问流程

1. 在表单响应列表页面，点击"按属性分组统计"按钮
2. 系统通过patch跳转到统计分析页面
3. 在统计分析页面中：
   - 显示表单中已配置的所有回答者属性列表
   - 用户选择一个属性进行分组分析(如"性别")
   - 系统从所有响应中提取该属性的实际值(如"男"、"女")，而不是使用硬编码的预定义值
   - 系统按这些值对表单回答进行分组统计
   - 显示每个分组的统计数据和可视化图表
   - 可以导出分组统计结果为CSV文件

### 10.4 改进后的统计页面设计

统计分析页面需要进行以下改进：

1. **动态属性值**：从实际回答中提取属性值，而不是使用硬编码的预定义值：
   ```elixir
   # 构建每个属性的可用值列表
   attribute_values = 
     responses
     |> Enum.reduce(%{}, fn response, acc ->
       Enum.reduce(respondent_attributes, acc, fn attr, inner_acc ->
         attr_id = Map.get(attr, :id) || Map.get(attr, "id")
         attr_value = get_in(response.respondent_info, [attr_id])
         
         if attr_value do
           values = Map.get(inner_acc, attr_id, [])
           Map.put(inner_acc, attr_id, [attr_value | values] |> Enum.uniq())
         else
           inner_acc
         end
       end)
     end)
   ```

2. **增强图表效果**：为不同类型的问题提供更丰富的图表类型：
   - 单选题：饼图和柱状图
   - 多选题：堆叠柱状图
   - 评分题：箱线图或线图
   - 文本题：回答率统计

3. **交互式比较**：允许用户同时查看不同分组的数据进行对比分析

4. **多种导出格式**：提供CSV、Excel和PDF格式的导出选项

### 10.5 页面交互设计

改进后的分组统计页面主要由以下部分组成：
- 左侧：回答者属性选择面板，显示表单中配置的所有属性
- 顶部：选定属性的分组概览(数据卡片)，显示各个属性值的回答数量和占比
- 中部：分组详细统计图表区域，对每个问题按分组显示统计图表
- 底部：导出和分享选项

页面采用响应式设计，在不同设备上均能良好展示。图表使用交互式JavaScript库(如Chart.js或ECharts)实现，支持悬停查看详情、缩放和保存图表图像等功能。

使用LiveView的patch导航确保用户可以方便地在响应列表和统计分析之间切换，无需刷新页面，提供流畅的用户体验。