defmodule MyApp.FormTemplates.FormTemplate do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "form_templates" do
    field :name, :string
    field :description, :string
    field :structure, :map
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
    |> cast(attrs, [:name, :description, :structure, :is_active, :created_by_id, :updated_by_id])
    |> validate_required([:name, :structure])
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
    has_type = Map.has_key?(element, "type") || Map.has_key?(element, :type)
    has_name = Map.has_key?(element, "name") || Map.has_key?(element, :name)
    has_label = Map.has_key?(element, "label") || Map.has_key?(element, :label)
    
    has_type && has_name && has_label
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
  def render(%__MODULE__{structure: structure}, form_data) when is_map(form_data) do
    # 将结构渲染为HTML
    rendered_elements = structure
      |> Enum.filter(fn element -> should_render_element?(element, form_data) end)
      |> Enum.map(fn element -> render_element(element, form_data) end)
      |> Enum.join("\n")

    "<form>\n#{rendered_elements}\n</form>"
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
  defp render_element(element, form_data) do
    # 提取元素属性
    type = Map.get(element, :type) || Map.get(element, "type")
    name = Map.get(element, :name) || Map.get(element, "name")
    label = Map.get(element, :label) || Map.get(element, "label")
    
    # 获取元素的值（如果在表单数据中存在）
    value = Map.get(form_data, name, "")
    
    # 根据元素类型渲染不同的HTML
    case type do
      "text" -> render_text_input(name, label, value)
      "number" -> render_number_input(name, label, value)
      "select" -> 
        options = Map.get(element, :options) || Map.get(element, "options") || []
        render_select(name, label, value, options)
      _ -> render_default_input(type, name, label, value)
    end
  end

  # 渲染文本输入框
  defp render_text_input(name, label, value) do
    """
    <div>
      <label for="#{name}">#{label}</label>
      <input type="text" id="#{name}" name="#{name}" value="#{value}">
    </div>
    """
  end

  # 渲染数字输入框
  defp render_number_input(name, label, value) do
    """
    <div>
      <label for="#{name}">#{label}</label>
      <input type="number" id="#{name}" name="#{name}" value="#{value}">
    </div>
    """
  end

  # 渲染下拉选择框
  defp render_select(name, label, value, options) do
    options_html = options
      |> Enum.map(fn option ->
        option_value = if is_binary(option), do: option, else: to_string(option)
        selected = if option_value == value, do: " selected", else: ""
        "<option value=\"#{option_value}\"#{selected}>#{option_value}</option>"
      end)
      |> Enum.join("\n")

    """
    <div>
      <label for="#{name}">#{label}</label>
      <select type="select" id="#{name}" name="#{name}">
        #{options_html}
      </select>
    </div>
    """
  end

  # 渲染默认输入框（用于未特别处理的类型）
  defp render_default_input(type, name, label, value) do
    """
    <div>
      <label for="#{name}">#{label}</label>
      <input type="#{type}" id="#{name}" name="#{name}" value="#{value}">
    </div>
    """
  end
  
  # 评估条件是否满足
  defp evaluate_condition(condition, form_data) do
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