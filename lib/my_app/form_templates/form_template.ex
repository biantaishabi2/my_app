defmodule MyApp.FormTemplates.FormTemplate do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "form_templates" do
    field :name, :string
    field :description, :string
    field :structure, {:array, :map}, default: []
    field :decoration, {:array, :map}, default: []
    field :version, :integer
    field :is_active, :boolean, default: true

    belongs_to :created_by, MyApp.Accounts.User
    belongs_to :updated_by, MyApp.Accounts.User

    timestamps()
  end

  @doc """
  创建表单模板的changeset。

  ## 参数
    - form_template: 表单模板结构体
    - attrs: 属性映射
  """
  def changeset(form_template, attrs) do
    form_template
    |> cast(attrs, [:name, :description, :structure, :decoration, :version, :is_active, :created_by_id, :updated_by_id])
    |> validate_required([:name, :structure, :version])
    |> unique_constraint(:name)
    |> validate_structure()
  end

  # 验证表单模板结构的有效性
  defp validate_structure(changeset) do
    case get_change(changeset, :structure) do
      nil -> changeset
      structure ->
        if is_valid_structure?(structure) do
          changeset
        else
          add_error(changeset, :structure, "结构格式无效")
        end
    end
  end

  # 检查结构是否为有效的表单模板结构
  defp is_valid_structure?(structure) when is_list(structure) do
    Enum.all?(structure, &is_valid_element?/1)
  end
  defp is_valid_structure?(_), do: false

  # 检查单个元素是否为有效的表单元素定义
  defp is_valid_element?(element) when is_map(element) do
    # 检查必要的字段
    # has_type = Map.has_key?(element, "type") || Map.has_key?(element, :type)
    # has_name = Map.has_key?(element, "name") || Map.has_key?(element, :name)
    # has_label = Map.has_key?(element, "label") || Map.has_key?(element, :label)

    # has_type && has_name && has_label

    # 根据新设计，检查 id 和 type
    has_id = Map.has_key?(element, "id") || Map.has_key?(element, :id)
    has_type = Map.has_key?(element, "type") || Map.has_key?(element, :type)

    # 还可以添加对 id 格式的检查 (例如是否为 UUID 字符串)，如果需要更严格的验证
    # is_valid_id_format = case Map.get(element, "id") || Map.get(element, :id) do
    #   id when is_binary(id) -> Ecto.UUID.cast(id) != :error # 简易检查
    #   _ -> false
    # end

    has_id && has_type # && is_valid_id_format (如果添加了格式检查)
  end
  defp is_valid_element?(_), do: false

  @doc """
  根据模板结构和表单数据渲染表单。

  ## 参数
    - template: 表单模板结构体
    - form_data: 表单数据，格式为 %{"field_name" => "value"}

  ## 返回值
    渲染后的HTML字符串
  """
  def render(%__MODULE__{structure: structure, decoration: decoration}, form_data) when is_map(form_data) do
    # --- 预计算需要编号的字段索引 ---
    # 识别需要编号的类型 (与渲染测试保持一致)
    field_types_to_number = ["text", "number", "select"]

    # 过滤可见且需要编号的元素，并生成 ID -> 序号 的 Map
    field_indices =
      structure
      |> Enum.filter(&should_render_element?(&1, form_data))
      |> Enum.filter(fn element ->
        elem_type = Map.get(element, "type") || Map.get(element, :type)
        elem_type in field_types_to_number
      end)
      |> Enum.with_index(1) # 从 1 开始编号
      |> Enum.into(%{}, fn {element, index} ->
        # 使用 id 作为 key
        elem_id = Map.get(element, "id") || Map.get(element, :id)
        {elem_id, index}
      end)
    
    # 过滤可见的表单元素
    filtered_structure = structure
      |> Enum.filter(fn element -> should_render_element?(element, form_data) end)
    
    # 渲染装饰元素
    decoration_elements = if is_list(decoration) do
      decoration
    else
      [] # 如果decoration不是列表，则使用空列表
    end

    # 合并并渲染所有元素
    rendered_html = render_combined_elements(filtered_structure, decoration_elements, form_data, field_indices)

    "<form>\n#{rendered_html}\n</form>"
  end
  
  # 处理并渲染组合的表单结构和装饰元素
  defp render_combined_elements(structure, decoration, form_data, field_indices) do
    # 1. 为表单元素和装饰元素添加通用标识
    form_elements = Enum.map(structure, fn element -> 
      element_id = Map.get(element, "id") || Map.get(element, :id)
      element
      |> Map.put("element_type", "form_item")
      |> Map.put("element_id", element_id)
    end)
    
    decoration_elements = Enum.map(decoration, fn element -> 
      element_id = Map.get(element, "id") || Map.get(element, :id)
      element
      |> Map.put("element_type", "decoration")
      |> Map.put("element_id", element_id)
    end)
    
    # 2. 创建ID到元素的映射，用于快速查找
    element_map = (form_elements ++ decoration_elements)
                  |> Enum.into(%{}, fn element -> 
                    {Map.get(element, "element_id"), element} 
                  end)
    
    # 3. 收集所有应该在开头显示的装饰元素
    start_elements = decoration_elements
                     |> Enum.filter(fn element ->
                       position = Map.get(element, "position")
                       position != nil && position["type"] == "start"
                     end)
                     
    # 4. 收集所有应该在末尾显示的装饰元素
    end_elements = decoration_elements
                   |> Enum.filter(fn element ->
                     position = Map.get(element, "position")
                     position != nil && position["type"] == "end"
                   end)
    
    # 5. 根据位置属性将装饰元素插入到正确的位置
    positioned_elements = %{}
    
    # 收集所有带"before"和"after"位置的装饰元素
    positioned_elements = decoration_elements
                          |> Enum.reduce(positioned_elements, fn element, acc ->
                            position = Map.get(element, "position")
                            if position != nil && position["type"] in ["before", "after"] && position["target_id"] != nil do
                              target_id = position["target_id"]
                              pos_type = position["type"]
                              
                              # 根据位置类型更新收集器
                              case pos_type do
                                "before" ->
                                  before_list = Map.get(acc, {:before, target_id}, [])
                                  Map.put(acc, {:before, target_id}, before_list ++ [element])
                                "after" ->
                                  after_list = Map.get(acc, {:after, target_id}, [])
                                  Map.put(acc, {:after, target_id}, after_list ++ [element])
                              end
                            else
                              acc
                            end
                          end)
    
    # 6. 获取没有特殊位置的装饰元素（既不是start/end/before/after）
    neutral_decorations = decoration_elements
                         |> Enum.filter(fn element ->
                           position = Map.get(element, "position")
                           is_nil(position) || 
                           (position["type"] != "start" && 
                            position["type"] != "end" && 
                            position["type"] != "before" && 
                            position["type"] != "after")
                         end)
    
    # 7. 构建最终的元素列表，首先添加开头元素
    final_elements = start_elements
    
    # 8. 按照原始顺序添加表单控件和中间装饰元素，并把before/after元素插入到对应位置
    main_elements = form_elements ++ neutral_decorations
                    |> Enum.filter(fn element ->
                      # 过滤掉已经在start或end列表中的元素，避免重复
                      element_id = Map.get(element, "element_id")
                      !(Enum.any?(start_elements ++ end_elements, fn e -> 
                        Map.get(e, "element_id") == element_id
                      end))
                    end)
    
    # 9. 添加主要元素和它们对应的before/after装饰元素
    final_elements = Enum.reduce(main_elements, final_elements, fn element, acc ->
      element_id = Map.get(element, "element_id")
      
      # 获取应放在此元素前面的装饰元素
      before_list = Map.get(positioned_elements, {:before, element_id}, [])
      
      # 获取应放在此元素后面的装饰元素
      after_list = Map.get(positioned_elements, {:after, element_id}, [])
      
      # 按顺序添加：before元素 + 当前元素 + after元素
      acc ++ before_list ++ [element] ++ after_list
    end)
    
    # 10. 最后添加结尾元素
    final_elements = final_elements ++ end_elements
    
    # 11. 渲染最终的元素列表
    final_elements
    |> Enum.map(fn element -> 
      element_type = Map.get(element, "element_type")
      case element_type do
        "form_item" -> render_element(element, form_data, field_indices) 
        "decoration" -> render_decoration_element(element)
        _ -> "" # 处理未知元素类型
      end
    end)
    |> Enum.join("\n")
  end
  
  
  # 渲染装饰元素
  defp render_decoration_element(element) do
    # 提取元素属性
    elem_id = Map.get(element, "id") || Map.get(element, :id)
    type = Map.get(element, "type") || Map.get(element, :type)
    
    case type do
      "title" -> 
        title = Map.get(element, "title") || Map.get(element, :title) || "未命名标题"
        level = Map.get(element, "level") || Map.get(element, :level) || 2
        align = Map.get(element, "align") || Map.get(element, :align) || "left"
        
        title_tag = case level do
          1 -> "h1"
          2 -> "h2"
          3 -> "h3"
          _ -> "h4"
        end
        
        """
        <div class="decoration-title" id="#{elem_id}">
          <#{title_tag} style="text-align: #{align};" class="decoration-title-text">#{title}</#{title_tag}>
        </div>
        """
        
      "paragraph" ->
        content = Map.get(element, "content") || Map.get(element, :content) || ""
        
        """
        <div class="decoration-paragraph" id="#{elem_id}">
          <p>#{content}</p>
        </div>
        """
        
      "section" ->
        title = Map.get(element, "title") || Map.get(element, :title)
        divider_style = Map.get(element, "divider_style") || Map.get(element, :divider_style) || "solid"
        
        title_html = if title do
          "<h3 class=\"section-title\">#{title}</h3>"
        else
          ""
        end
        
        """
        <div class="decoration-section" id="#{elem_id}">
          <hr class="divider-#{divider_style}">
          #{title_html}
        </div>
        """
        
      "explanation" ->
        content = Map.get(element, "content") || Map.get(element, :content) || ""
        note_type = Map.get(element, "note_type") || Map.get(element, :note_type) || "info"
        
        """
        <div class="decoration-explanation explanation-#{note_type}" id="#{elem_id}">
          <div class="explanation-content">#{content}</div>
        </div>
        """
        
      "header_image" ->
        image_url = Map.get(element, "image_url") || Map.get(element, :image_url) || ""
        height = Map.get(element, "height") || Map.get(element, :height) || "300px"
        alt = Map.get(element, "alt") || Map.get(element, :alt) || ""
        
        """
        <div class="decoration-header-image" id="#{elem_id}">
          <img src="#{image_url}" alt="#{alt}" style="height: #{height}; width: 100%; object-fit: cover;">
        </div>
        """
        
      "inline_image" ->
        image_url = Map.get(element, "image_url") || Map.get(element, :image_url) || ""
        caption = Map.get(element, "caption") || Map.get(element, :caption)
        width = Map.get(element, "width") || Map.get(element, :width) || "100%"
        align = Map.get(element, "align") || Map.get(element, :align) || "center"
        
        caption_html = if caption do
          "<div class=\"image-caption\">#{caption}</div>"
        else
          ""
        end
        
        """
        <div class="decoration-inline-image" id="#{elem_id}" style="text-align: #{align};">
          <img src="#{image_url}" alt="#{caption || ""}" style="width: #{width}; max-width: 100%;">
          #{caption_html}
        </div>
        """
        
      "spacer" ->
        height = Map.get(element, "height") || Map.get(element, :height) || "20px"
        
        """
        <div class="decoration-spacer" id="#{elem_id}" style="height: #{height};"></div>
        """
        
      _ -> 
        # 默认情况，未知装饰元素类型
        """
        <div class="decoration-unknown" id="#{elem_id}">
          <p>未知装饰元素类型: #{type}</p>
        </div>
        """
    end
  end

  # 判断是否应该渲染指定的表单元素
  defp should_render_element?(element, form_data) do
    condition = Map.get(element, :condition) || Map.get(element, "condition")

    if is_nil(condition) do
      # 没有条件，总是渲染
      true
    else
      # 评估条件
      evaluate_condition(condition, form_data)
    end
  end

  # 渲染单个表单元素
  defp render_element(element, form_data, field_indices) do # 接收索引 Map
    # 提取元素属性
    elem_id = Map.get(element, "id") || Map.get(element, :id)
    type = Map.get(element, :type) || Map.get(element, "type")
    name = Map.get(element, :name) || Map.get(element, "name")
    label = Map.get(element, :label) || Map.get(element, "label")

    # 获取元素的值（如果在表单数据中存在）
    value = Map.get(form_data, name, "")

    # --- 新增：获取当前元素的序号 ---
    current_index = Map.get(field_indices, elem_id) # 如果是需要编号的字段，会得到序号，否则为 nil
    # --- 结束新增 ---

    # 根据元素类型渲染不同的HTML
    case type do
      "text" -> render_text_input(name, label, value, current_index)
      "number" -> render_number_input(name, label, value, current_index)
      "select" ->
        options = Map.get(element, :options) || Map.get(element, "options") || []
        render_select(name, label, value, options, current_index)
      _ -> render_default_input(type, name, label, value, current_index) # 也传递给默认渲染器
    end
  end

  # 渲染文本输入框
  defp render_text_input(name, label, value, index) do
    index_span = if index, do: "<span class=\"dynamic-item-number\">#{index}.</span> ", else: ""
    """
    <div>
      <label for="#{name}">#{index_span}#{label}</label>
      <input type="text" id="#{name}" name="#{name}" value="#{value}">
    </div>
    """
  end

  # 渲染数字输入框
  defp render_number_input(name, label, value, index) do
    index_span = if index, do: "<span class=\"dynamic-item-number\">#{index}.</span> ", else: ""
    """
    <div>
      <label for="#{name}">#{index_span}#{label}</label>
      <input type="number" id="#{name}" name="#{name}" value="#{value}">
    </div>
    """
  end

  # 渲染下拉选择框
  defp render_select(name, label, value, options, index) do
    index_span = if index, do: "<span class=\"dynamic-item-number\">#{index}.</span> ", else: ""
    options_html = options
      |> Enum.map(fn option ->
        option_value = if is_binary(option), do: option, else: to_string(option)
        selected = if option_value == value, do: " selected", else: ""
        "<option value=\"#{option_value}\"#{selected}>#{option_value}</option>"
      end)
      |> Enum.join("\n")

    """
    <div>
      <label for="#{name}">#{index_span}#{label}</label>
      <select type="select" id="#{name}" name="#{name}">
        #{options_html}
      </select>
    </div>
    """
  end

  # 渲染默认输入框（用于未特别处理的类型）
  defp render_default_input(type, name, label, value, _index) do
    # 默认渲染器不显示编号
    """
    <div>
      <label for="#{name}">#{label}</label>
      <input type="#{type}" id="#{name}" name="#{name}" value="#{value}">
    </div>
    """
  end

  @doc """
  评估条件是否满足。

  ## 参数
    - condition: 条件定义，格式为 %{operator: op, left: left, right: right} 或复合条件
    - form_data: 表单数据，格式为 %{"field_name" => "value"}

  ## 返回值
    条件评估结果，true 表示满足条件，false 表示不满足
  """
  def evaluate_condition(condition, form_data) do
    cond do
      # 简单条件（如：字段 == 值）
      is_map_key(condition, :operator) && is_map_key(condition, :left) && is_map_key(condition, :right) ->
        evaluate_simple_condition(condition, form_data)

      # 字符串键的简单条件
      is_map_key(condition, "operator") && is_map_key(condition, "left") && is_map_key(condition, "right") ->
        condition = %{
          operator: condition["operator"],
          left: condition["left"],
          right: condition["right"]
        }
        evaluate_simple_condition(condition, form_data)

      # 复合条件 AND/OR（带原子键）
      is_map_key(condition, :operator) && is_map_key(condition, :conditions) ->
        evaluate_compound_condition(condition.operator, condition.conditions, form_data)

      # 复合条件 AND/OR（带字符串键）
      is_map_key(condition, "operator") && is_map_key(condition, "conditions") ->
        evaluate_compound_condition(condition["operator"], condition["conditions"], form_data)

      # 未知条件格式
      true ->
        false
    end
  end

  # 评估简单条件
  defp evaluate_simple_condition(%{operator: operator, left: left, right: right}, form_data) do
    # 获取左侧操作数的值
    left_value = case left do
      %{type: "field", name: field_name} ->
        Map.get(form_data, field_name, "")
      %{type: "value", value: value} ->
        value
      %{"type" => "field", "name" => field_name} ->
        Map.get(form_data, field_name, "")
      %{"type" => "value", "value" => value} ->
        value
      _ -> ""
    end

    # 获取右侧操作数的值
    right_value = case right do
      %{type: "field", name: field_name} ->
        Map.get(form_data, field_name, "")
      %{type: "value", value: value} ->
        value
      %{"type" => "field", "name" => field_name} ->
        Map.get(form_data, field_name, "")
      %{"type" => "value", "value" => value} ->
        value
      _ -> ""
    end

    # 确保left_value和right_value不是nil
    left_value = left_value || ""
    right_value = right_value || ""

    # 根据操作符比较值
    case operator do
      "==" -> left_value == right_value
      "!=" -> left_value != right_value
      ">" ->
        try do
          {left_num, _} = if is_binary(left_value), do: Integer.parse(left_value), else: {left_value, nil}
          {right_num, _} = if is_binary(right_value), do: Integer.parse(right_value), else: {right_value, nil}
          left_num > right_num
        rescue
          _ -> false
        end
      ">=" ->
        try do
          {left_num, _} = if is_binary(left_value), do: Integer.parse(left_value), else: {left_value, nil}
          {right_num, _} = if is_binary(right_value), do: Integer.parse(right_value), else: {right_value, nil}
          left_num >= right_num
        rescue
          _ -> false
        end
      "<" ->
        try do
          {left_num, _} = if is_binary(left_value), do: Integer.parse(left_value), else: {left_value, nil}
          {right_num, _} = if is_binary(right_value), do: Integer.parse(right_value), else: {right_value, nil}
          left_num < right_num
        rescue
          _ -> false
        end
      "<=" ->
        try do
          {left_num, _} = if is_binary(left_value), do: Integer.parse(left_value), else: {left_value, nil}
          {right_num, _} = if is_binary(right_value), do: Integer.parse(right_value), else: {right_value, nil}
          left_num <= right_num
        rescue
          _ -> false
        end
      "contains" ->
        if is_binary(left_value) and is_binary(right_value) do
          String.contains?(left_value, right_value)
        else
          false
        end
      _ -> false
    end
  end

  # 评估复合条件
  defp evaluate_compound_condition(operator, conditions, form_data) do
    # 确保条件是个列表
    conditions = if is_list(conditions), do: conditions, else: []

    # 评估每个子条件
    results = Enum.map(conditions, fn condition -> evaluate_condition(condition, form_data) end)

    # 根据操作符组合结果
    case operator do
      "and" -> Enum.all?(results, & &1)
      "or" -> Enum.any?(results, & &1)
      _ -> false
    end
  end
end
