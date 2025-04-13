# 这个脚本模拟应用中加载和处理表单模板的过程，以便排查问题

# 目标表单项和跳转目标ID
target_item_id = "fe01d45d-fb33-4a47-b19c-fdd53b35d93e" # "我是🐷"项目ID
target_jump_id = "f029db4f-e30d-4799-be1f-f330b1a6b9fe" # 跳转目标ID

# 1. 模拟实际应用中的加载过程
form_id = "b8fd73c1-c966-43e6-935f-06a893313ebd" # 使用实际表单ID
form = MyApp.Repo.get(MyApp.Forms.Form, form_id)

IO.puts("\n========== 表单信息 ==========")
IO.puts("表单ID: #{form.id}")
IO.puts("表单标题: #{form.title}")
IO.puts("表单模板ID: #{form.form_template_id || "未设置"}")

# 2. 加载表单表项
form_items = MyApp.Forms.list_form_items_by_form_id(form_id)
IO.puts("\n发现 #{length(form_items)} 个表单项")

# 3. 加载模板 - 使用实际应用中的方法
template = if form.form_template_id do
  template = MyApp.FormTemplates.get_template(form.form_template_id)
  IO.puts("\n========== 模板信息 ==========")
  IO.puts("模板ID: #{template.id}")
  IO.puts("模板名称: #{template.name || "未命名"}")
  IO.puts("模板结构: #{if is_list(template.structure), do: "列表，长度: #{length(template.structure)}", else: "非列表类型"}")
  template
else
  IO.puts("\n未找到关联的模板")
  nil
end

# 4. 提取并输出模板结构中的逻辑规则
if template && is_list(template.structure) do
  IO.puts("\n========== 模板结构中的逻辑规则 ==========")
  
  # 统计有逻辑规则的项目
  logic_items = Enum.filter(template.structure, fn item ->
    Map.has_key?(item, "logic") || Map.has_key?(item, :logic)
  end)
  
  IO.puts("发现 #{length(logic_items)} 个带有逻辑规则的项目")
  
  # 显示详细信息
  Enum.each(logic_items, fn item ->
    item_id = item["id"] || item[:id]
    item_label = item["label"] || item[:label]
    logic = item["logic"] || item[:logic]
    
    IO.puts("\n项目: ID=#{item_id}, 标签=#{item_label}")
    IO.puts("逻辑规则: #{inspect(logic)}")
  end)
  
  # 特别检查我们感兴趣的项目
  target_logic_item = Enum.find(template.structure, fn item ->
    item_id = item["id"] || item[:id]
    item_id == target_item_id
  end)
  
  if target_logic_item do
    IO.puts("\n========== 目标表单项逻辑 ==========")
    IO.puts("ID: #{target_item_id}")
    IO.puts("标签: #{target_logic_item["label"] || target_logic_item[:label]}")
    
    if Map.has_key?(target_logic_item, "logic") || Map.has_key?(target_logic_item, :logic) do
      logic = target_logic_item["logic"] || target_logic_item[:logic]
      IO.puts("发现逻辑规则: #{inspect(logic)}")
    else
      IO.puts("未找到逻辑规则")
    end
  else
    IO.puts("\n未在模板结构中找到目标表单项: #{target_item_id}")
  end
end

# 5. 模拟将逻辑规则应用到表单项的过程
IO.puts("\n========== 模拟表单项与模板逻辑匹配 ==========")

form_items_with_logic = if template && is_list(template.structure) do
  template_structure = template.structure
  
  # 使用和实际代码相似的方法 
  Enum.map(form_items, fn item ->
    IO.puts("\n处理表单项: #{item.id} (#{item.label || "无标签"})")
    
    # 用不同的方法尝试匹配表单项和模板项
    
    # 方法1: 直接比较，可能不匹配
    method1_item = Enum.find(template_structure, fn struct_item -> 
      struct_item_id = struct_item["id"] || struct_item[:id]
      struct_item_id == item.id
    end)
    
    # 方法2: 字符串比较，应该匹配
    method2_item = Enum.find(template_structure, fn struct_item -> 
      struct_item_id = struct_item["id"] || struct_item[:id]
      to_string(struct_item_id) == to_string(item.id)
    end)
    
    # 方法3: 尝试转换所有可能的格式
    method3_item = Enum.find(template_structure, fn struct_item -> 
      struct_item_id = struct_item["id"] || struct_item[:id]
      String.downcase(to_string(struct_item_id)) == String.downcase(to_string(item.id))
    end)
    
    # 输出比较结果
    IO.puts("方法1 (直接比较): #{if method1_item, do: "找到", else: "未找到"}")
    IO.puts("方法2 (字符串比较): #{if method2_item, do: "找到", else: "未找到"}")
    IO.puts("方法3 (忽略大小写): #{if method3_item, do: "找到", else: "未找到"}")
    
    # 检查逻辑规则
    if method2_item do
      if Map.has_key?(method2_item, "logic") || Map.has_key?(method2_item, :logic) do
        logic = method2_item["logic"] || method2_item[:logic]
        IO.puts("找到逻辑规则: #{inspect(logic)}")
        
        # 将逻辑规则复制到表单项
        Map.put(item, :logic, logic)
      else
        IO.puts("模板中未找到逻辑规则")
        item
      end
    else
      IO.puts("在模板结构中未找到匹配项")
      item
    end
  end)
else
  IO.puts("无法处理表单项，因为模板不可用或结构格式错误")
  form_items
end

# 6. 检查最终处理后的结果
IO.puts("\n========== 检查目标表单项的最终处理结果 ==========")

target_item_with_logic = Enum.find(form_items_with_logic, fn item -> item.id == target_item_id end)

if target_item_with_logic do
  IO.puts("ID: #{target_item_with_logic.id}")
  IO.puts("标签: #{target_item_with_logic.label || "无标签"}")
  
  if Map.has_key?(target_item_with_logic, :logic) do
    IO.puts("成功应用逻辑规则: #{inspect(target_item_with_logic.logic)}")
  else
    IO.puts("未成功应用逻辑规则")
  end
else
  IO.puts("未找到目标表单项")
end

# 7. 辅助模拟处理表单数据的函数，用于验证跳转逻辑
IO.puts("\n========== 模拟处理表单数据 ==========")

simulate_process_form_data = fn form_data, items_with_logic ->
  # 查找包含逻辑的表单项
  items_with_jump_logic = Enum.filter(items_with_logic, fn item ->
    logic = Map.get(item, :logic)
    logic && (logic["type"] == "jump" || logic[:type] == "jump")
  end)
  
  IO.puts("发现 #{length(items_with_jump_logic)} 个带有跳转逻辑的表单项")
  
  # 对每个有跳转逻辑的项进行处理
  Enum.each(items_with_jump_logic, fn item ->
    logic = Map.get(item, :logic)
    condition = logic["condition"] || logic[:condition]
    target_id = logic["target_id"] || logic[:target_id]
    
    # 获取条件相关信息
    operator = condition["operator"] || condition[:operator]
    value = condition["value"] || condition[:value]
    
    # 获取表单数据中的值
    form_value = Map.get(form_data, item.id)
    
    IO.puts("\n处理表单项: #{item.id} (#{item.label || "无标签"})")
    IO.puts("条件: 如果值#{operator} #{inspect(value)}, 跳转到 #{target_id}")
    IO.puts("当前值: #{inspect(form_value)}")
    
    # 评估条件
    condition_result = case operator do
      "equals" -> "#{form_value}" == "#{value}"
      "not_equals" -> "#{form_value}" != "#{value}"
      _ -> false
    end
    
    IO.puts("条件评估结果: #{condition_result}")
    
    # 模拟跳转逻辑处理
    if condition_result do
      IO.puts("条件满足 - 不执行跳转，所有项目正常显示")
    else
      IO.puts("条件不满足 - 执行跳转到目标项 #{target_id}")
    end
  end)
end

# 8. 测试不同的表单数据场景
IO.puts("\n========== 测试场景1: 选择 '我是🐷' ==========")
simulate_process_form_data.(%{target_item_id => "我是🐷"}, form_items_with_logic)

IO.puts("\n========== 测试场景2: 选择 'a' ==========")
simulate_process_form_data.(%{target_item_id => "a"}, form_items_with_logic)