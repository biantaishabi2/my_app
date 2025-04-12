# 表单回答导出与统计功能设计

## 1. 功能概述

为表单回答(Response)系统添加数据导出和基础统计功能，使管理员能够：
- 以CSV/Excel格式导出表单回答数据
- 按时间范围筛选导出数据
- 查看选择题和评分题的基础统计分析
- 下载统计报表

## 2. 实现计划

### 2.1 后端API实现

- [x] 设计文档
- [x] 定义导出数据的格式结构
- [x] 实现数据统计处理功能
- [x] 实现数据导出为CSV格式功能
- [x] 添加时间筛选参数
- [x] 编写单元测试
- [ ] 实现导出控制器或Live View处理函数

### 2.2 前端实现

- [ ] 在回答列表页添加导出按钮
- [ ] 添加导出选项(所有数据/统计摘要)
- [ ] 实现日期筛选组件
- [ ] 添加导出格式选择(CSV/Excel)
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

## 5. 控制器/Live组件设计

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