# 表单模板逻辑结构分析

## 表单模板数据结构

经过查询，表单模板的主要字段如下：

```elixir
[:id, :name, :description, :structure, :decoration, :version, :is_active,
 :created_by_id, :updated_by_id, :inserted_at, :updated_at]
```

其中，最重要的两个字段是：
- `structure`: 存储表单结构和逻辑规则
- `decoration`: 存储装饰元素

## 逻辑规则存储方式

通过查询数据库中的表单模板，我们发现逻辑规则是直接存储在每个表单项的属性中，而不是作为单独的集合。

示例模板结构：

```elixir
[
  %{
    "description" => nil,
    "id" => "fe01d45d-fb33-4a47-b19c-fdd53b35d93e",
    "label" => "修改后的文本问题",
    "logic" => %{
      "condition" => %{"operator" => "equals", "value" => "我是🐷"},
      "target_id" => "f029db4f-e30d-4799-be1f-f330b1a6b9fe",
      "type" => "jump"
    },
    "order" => 2,
    "placeholder" => nil,
    "required" => false,
    "type" => "radio"
  },
  %{
    "id" => "f029db4f-e30d-4799-be1f-f330b1a6b9fe",
    "label" => "测试图片选择题",
    "order" => 17,
    "placeholder" => nil,
    "required" => false,
    "type" => "image_choice"
  },
  // 其他表单项...
]
```

## 逻辑规则结构

逻辑规则的结构如下：

```elixir
"logic" => %{
  "condition" => %{"operator" => "equals", "value" => "我是🐷"},
  "target_id" => "f029db4f-e30d-4799-be1f-f330b1a6b9fe",
  "type" => "jump"
}
```

逻辑规则的关键组成部分：

1. **逻辑类型**: `"type" => "jump"` - 表示这是一个跳转逻辑
2. **条件**: `"condition" => %{"operator" => "equals", "value" => "我是🐷"}` - 条件包含操作符和值
3. **目标ID**: `"target_id" => "f029db4f-e30d-4799-be1f-f330b1a6b9fe"` - 满足条件后跳转到的目标表单项ID

## 重要发现

1. **逻辑规则位置**：逻辑规则直接附加在源表单项上，而不是作为单独的集合存储
2. **源表单项ID**：源表单项的ID是隐含的（即包含逻辑规则的表单项），不需要在逻辑规则中显式指定 `source_id`
3. **目标表单项ID**：目标表单项的ID是明确指定的 (`target_id`)

## 应用逻辑的正确方法

基于这一发现，正确的逻辑处理应该是：

1. 从表单模板的 `structure` 中加载所有表单项
2. 对于每个表单项，检查它是否包含 `logic` 属性
3. 如果包含，则需要评估该逻辑条件
4. 对于"jump"类型的逻辑，**如果条件满足（例如，用户选择了 "我是🐷"），则应该执行跳转，只显示源项和目标项，隐藏中间项**。如果条件不满足，则正常显示所有项。

当前的实现问题在于，我们尝试为每个表单项查找适用的逻辑规则，但实际上应该从表单模板的 `structure` 中加载逻辑规则，然后应用到整个表单。

## 具体实现步骤

### 1. 逻辑加载时机 - ✅ 已完成

表单模板结构在 `FormTemplateRenderer.render_template_with_decorations` 函数中加载。现在已经修改为：

```elixir
# 从模板结构中加载逻辑规则
template_structure = template.structure || []

# 为表单项添加模板逻辑
form_items_with_logic = Enum.map(form_items, fn item ->
  # 从模板结构中找到对应的项
  template_item = Enum.find(template_structure, fn struct_item -> 
    struct_item["id"] == item.id
  end)
  
  # 如果在模板结构中找到了对应项，并且它有逻辑规则
  item_with_logic = if template_item && Map.has_key?(template_item, "logic") do
    # 将模板中的逻辑规则添加到表单项
    Map.put(item, :logic, template_item["logic"])
  else
    item
  end
  
  item_with_logic
end)
```

### 2. 逻辑评估时机 - ✅ 已完成

当表单字段值改变时，会触发 `submit.ex` 中的 `handle_event("validate", ...)` 函数。现在已经修改为：

```elixir
def handle_event("validate", %{"form_data" => form_data} = params, socket) do
  # 更新表单状态
  updated_form_state = 
    socket.assigns.form_state
    |> Map.merge(form_data)
  
  # 当用户与表单交互时，检查是否有特殊逻辑
  changed_field_id = case params["_target"] do
    ["form_data", field_id] -> field_id
    _ -> nil
  end
  
  if changed_field_id do
    field_value = Map.get(form_data, changed_field_id)
    Logger.info("字段变更: #{changed_field_id}, 值: #{inspect(field_value)}")
    
    # 记录特殊值情况
    if "#{field_value}" == "我是🐷" do
      Logger.info("🚨 检测到特殊值 '我是🐷'，这可能会触发跳转逻辑")
    end
    
    # 识别表单项是否有逻辑规则
    item = Map.get(socket.assigns.items_map || %{}, changed_field_id)
    if item && (Map.get(item, :logic) || Map.get(item, "logic")) do
      logic = Map.get(item, :logic) || Map.get(item, "logic")
      Logger.info("字段 #{changed_field_id} 有逻辑规则: #{inspect(logic)}")
    end
  end
  
  # 重要：更新form_data，这是模板逻辑渲染评估所需的
  updated_socket = socket
                  |> assign(:form_state, updated_form_state)
                  |> maybe_validate_form(form_data)
  
  {:noreply, updated_socket}
end
```

同时，更新了`maybe_validate_form`函数以正确处理表单数据并更新视图：

```elixir
defp maybe_validate_form(socket, form_data) do
  # 执行基本验证
  errors = validate_form_data(form_data, socket.assigns.items_map)
  
  # 记录表单数据更新
  Logger.info("表单数据更新: #{inspect(form_data)}")
  
  # 记录可能触发的跳转逻辑
  form_items = socket.assigns.form_items || []
  Enum.each(form_data, fn {field_id, value} ->
    # 查找是否有包含跳转逻辑的表单项
    item_with_logic = Enum.find(form_items, fn item -> 
      item.id == field_id && 
      (Map.get(item, :logic) || Map.get(item, "logic"))
    end)
    
    if item_with_logic do
      logic = Map.get(item_with_logic, :logic) || Map.get(item_with_logic, "logic")
      logic_type = Map.get(logic, "type") || Map.get(logic, :type)
      
      # 检查是否有"我是🐷"条件
      condition = Map.get(logic, "condition") || Map.get(logic, :condition) || %{}
      condition_value = Map.get(condition, "value") || Map.get(condition, :value)
      
      if logic_type == "jump" && "#{condition_value}" == "我是🐷" do
        Logger.info("🚨 检测到关键跳转逻辑字段 #{field_id} 更新为 #{inspect(value)}")
        Logger.info("🚨 目标字段ID: #{Map.get(logic, "target_id") || Map.get(logic, :target_id)}")
      end
    end
  end)
  
  # 更新视图状态
  socket
    |> assign(:form_data, form_data)
    |> assign(:errors, errors)
    |> assign(:form_updated_at, System.system_time(:millisecond))
end
```

### 3. 渲染时的可见性控制 - ⏳ 待确认/修改

渲染器 (例如 `FormTemplateRenderer`) 负责根据 `maybe_validate_form` 计算出的 `@jump_state` 来控制表单项的可见性。

*   **如果 `@jump_state.active` 为 `true`**: 渲染器应该只渲染 `@jump_state.source_id` 和 `@jump_state.target_id` 对应的表单项。
*   **如果 `@jump_state.active` 为 `false`**: 渲染器应该正常渲染所有表单项（或根据其他显示/隐藏逻辑判断）。

**之前的 `evaluate_jump_logic` 函数实现（如下所示）是不正确的，因为它包含了反向逻辑。正确的实现应该在 `maybe_validate_form` 中完成状态计算，并在渲染器中直接使用该状态。**

```elixir
# (移除或标记为过时的 evaluate_jump_logic 代码示例)
# 旧的、包含反向逻辑的 evaluate_jump_logic 实现已不再适用。
# 正确的跳转判断发生在 maybe_validate_form 中，
# 渲染器直接使用计算出的 jump_state。
```

### 4. 实际应用案例 - 修正

在当前实现中（假设代码已修正为标准逻辑）：

1. 当用户在ID为 `fe01d45d-fb33-4a47-b19c-fdd53b35d93e` 的表单项选择了 **"我是🐷"** 时：
    * `handle_event("validate", ...)` 函数检测到变化。
    * `maybe_validate_form` 评估条件 `"我是🐷" == "我是🐷"`，结果为 `true`。
    * `maybe_validate_form` 计算出 `jump_state` 为 `{active: true, source_id: "fe01d...", target_id: "f029..."}`。
    * 渲染器接收到激活的 `jump_state`，执行跳转，**只显示源项 ("fe01d...") 和目标项 ("f029...")**，隐藏中间项。

2. 当用户选择了 **其他选项 (例如 "我是🐂")** 时：
    * `handle_event("validate", ...)` 函数检测到变化。
    * `maybe_validate_form` 评估条件 `"我是🐂" == "我是🐷"`，结果为 `false`。
    * `maybe_validate_form` 计算出 `jump_state` 为 `{active: false}`。
    * 渲染器接收到未激活的 `jump_state`，**不执行跳转，正常显示所有项目**。

通过这些修改，文档现在应该与模板定义的原始逻辑（等于 "我是🐷" 时跳转）保持一致。