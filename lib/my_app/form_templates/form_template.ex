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
  def render(%__MODULE__{structure: structure}, form_data) when is_map(form_data) do
    # --- 新增：预计算需要编号的字段索引 ---
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
    # --- 结束新增 ---

    # 将结构渲染为HTML
    rendered_elements = structure
      |> Enum.filter(fn element -> should_render_element?(element, form_data) end)
      # |> Enum.map(fn element -> render_element(element, form_data) end)
      |> Enum.map(fn element -> render_element(element, form_data, field_indices) end) # 传递索引 Map
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
  defp render_default_input(type, name, label, value, index) do
    # 假设只有特定类型需要编号，默认渲染器可能不需要显示 index
    # index_span = if index, do: "<span class=\"dynamic-item-number\">#{index}.</span> ", else: ""
    index_span = "" # 或者根据需要决定是否为未知类型添加编号
    """
    <div>
      <label for="#{name}">#{index_span}#{label}</label>
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
