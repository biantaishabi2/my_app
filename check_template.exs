# 直接使用我们关注的表单项ID，通过直接查看特定表单
target_item_id = "fe01d45d-fb33-4a47-b19c-fdd53b35d93e" # "我是🐷"项目ID
target_jump_id = "f029db4f-e30d-4799-be1f-f330b1a6b9fe" # 跳转目标ID

# 查找所有表单模板
templates = MyApp.FormTemplates.list_templates()
IO.puts("找到 #{length(templates)} 个表单模板")

Enum.each(templates, fn template ->
  IO.puts("\n===================== 模板信息 =====================")
  IO.puts("模板ID: #{template.id}")
  IO.puts("模板名称: #{template.name || "未命名"}")
  
  # 检查模板结构
  IO.puts("\n===================== 模板结构 =====================")
  if is_list(template.structure) do
    IO.puts("模板结构类型: 列表, 长度: #{length(template.structure)}")
    
    # 输出结构中的所有项目
    Enum.each(template.structure, fn item ->
      item_id = item["id"] || Map.get(item, :id)
      item_type = item["type"] || Map.get(item, :type)
      item_label = item["label"] || Map.get(item, :label)
      
      # 检查是否有逻辑规则
      has_logic = Map.has_key?(item, "logic") || Map.has_key?(item, :logic)
      
      if has_logic do
        logic = item["logic"] || Map.get(item, :logic)
        logic_type = (logic["type"] || Map.get(logic, :type)) || "未知"
        target_id = (logic["target_id"] || Map.get(logic, :target_id)) || "未知"
        condition = logic["condition"] || Map.get(logic, :condition)
        
        IO.puts("\n项目: ID=#{item_id}, 类型=#{item_type}, 标签=#{item_label}")
        IO.puts("  逻辑类型: #{logic_type}")
        IO.puts("  目标ID: #{target_id}")
        IO.puts("  条件: #{inspect(condition)}")
        
        # 检查特定ID
        if item_id == target_item_id do
          IO.puts("\n!!! 找到特定项目: 源跳转项 !!!")
          IO.inspect(item, label: "源项详情", pretty: true)
        end
        
        if target_id == target_jump_id do
          IO.puts("\n!!! 找到特定目标: 跳转目标项 !!!")
        end
      end
    end)
  else
    IO.puts("模板结构不是列表类型: #{inspect(template.structure)}")
  end
end)