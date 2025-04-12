defmodule MyApp.FormTemplates do
  @moduledoc """
  表单模板上下文模块。

  提供表单模板的创建、查询、编辑、删除等操作，以及表单模板渲染等功能。
  """

  import Ecto.Query, warn: false
  alias MyApp.Repo
  alias MyApp.FormTemplates.FormTemplate

  @doc """
  返回所有表单模板的列表。

  ## 参数
    - opts: 可选的查询选项
      - :active_only - 当为true时，只返回活跃的模板

  ## 示例

      iex> list_templates()
      [%FormTemplate{}, ...]

      iex> list_templates(active_only: true)
      [%FormTemplate{is_active: true}, ...]
  """
  def list_templates(opts \\ []) do
    query = from(t in FormTemplate)

    query =
      if Keyword.get(opts, :active_only, false) do
        from t in query, where: t.is_active == true
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  获取单个表单模板。

  如果模板不存在，返回nil。

  ## 示例

      iex> get_template(123)
      %FormTemplate{}

      iex> get_template(456)
      nil
  """
  def get_template(id) do
    Repo.get(FormTemplate, id)
  end

  @doc """
  获取单个表单模板。如果不存在则抛出错误。

  ## 示例

      iex> get_template!(123)
      %FormTemplate{}

      iex> get_template!(456)
      ** (Ecto.NoResultsError)
  """
  def get_template!(id) do
    Repo.get!(FormTemplate, id)
  end

  @doc """
  根据名称获取表单模板。

  ## 示例

      iex> get_template_by_name("问卷调查")
      %FormTemplate{}

      iex> get_template_by_name("不存在的模板")
      nil
  """
  def get_template_by_name(name) do
    Repo.get_by(FormTemplate, name: name)
  end

  @doc """
  创建表单模板。

  ## 示例

      iex> create_template(%{name: "问卷调查", structure: [...]})
      {:ok, %FormTemplate{}}

      iex> create_template(%{invalid: :data})
      {:error, %Ecto.Changeset{}}
  """
  def create_template(attrs) do
    %FormTemplate{}
    |> FormTemplate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  创建默认的空白表单模板。
  用于在创建新表单时自动关联一个默认模板。

  ## 示例

      iex> create_default_template(%{user_id: user_id})
      {:ok, %FormTemplate{}}
  """
  def create_default_template(attrs) do
    default_attrs = %{
      name: "默认表单模板 #{DateTime.utc_now() |> Calendar.strftime("%Y%m%d%H%M%S")}",
      description: "自动创建的默认表单模板",
      structure: [],
      version: 1
    }

    # 合并用户ID和其他可能的属性
    attrs = Map.merge(default_attrs, attrs)

    # 确保有created_by_id
    attrs =
      if Map.has_key?(attrs, :created_by_id) || Map.has_key?(attrs, "created_by_id") do
        attrs
      else
        Map.put(attrs, :created_by_id, Map.get(attrs, :user_id) || Map.get(attrs, "user_id"))
      end

    create_template(attrs)
  end

  @doc """
  更新表单模板。

  ## 示例

      iex> update_template(template, %{name: "新名称"})
      {:ok, %FormTemplate{}}

      iex> update_template(template, %{invalid: :data})
      {:error, %Ecto.Changeset{}}
  """
  def update_template(%FormTemplate{} = template, attrs) do
    template
    |> FormTemplate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  删除表单模板。

  ## 示例

      iex> delete_template(template)
      {:ok, %FormTemplate{}}

      iex> delete_template(template)
      {:error, %Ecto.Changeset{}}
  """
  def delete_template(%FormTemplate{} = template) do
    Repo.delete(template)
  end

  @doc """
  标记模板为活跃或非活跃。

  ## 示例

      iex> activate_template(template, true)
      {:ok, %FormTemplate{is_active: true}}

      iex> activate_template(template, false)
      {:ok, %FormTemplate{is_active: false}}
  """
  def activate_template(%FormTemplate{} = template, is_active) when is_boolean(is_active) do
    update_template(template, %{is_active: is_active})
  end

  @doc """
  返回可用于表单的模板变更集。

  ## 示例

      iex> change_template(template)
      %Ecto.Changeset{data: %FormTemplate{}}
  """
  def change_template(%FormTemplate{} = template, attrs \\ %{}) do
    FormTemplate.changeset(template, attrs)
  end

  @doc """
  根据表单模板创建新表单。

  ## 参数
    - template: 表单模板结构体
    - attrs: 表单属性，至少应包含user_id

  ## 示例

      iex> create_form_from_template(template, %{user_id: user_id})
      {:ok, %MyApp.Forms.Form{}}
  """
  def create_form_from_template(%FormTemplate{} = template, attrs) do
    # 基础表单属性
    form_attrs = %{
      title: "#{template.name} - #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d")}",
      description: template.description,
      status: :draft,
      user_id: Map.get(attrs, :user_id) || Map.get(attrs, "user_id")
    }

    # 合并额外属性
    form_attrs = Map.merge(form_attrs, attrs)

    # 创建表单
    case MyApp.Forms.create_form(form_attrs) do
      {:ok, form} ->
        # 转换模板结构为表单项
        # 注意：这里需要处理更复杂的逻辑，将模板结构转换为实际的表单项
        # 这里只是简化的示例
        result =
          Enum.reduce_while(template.structure, {:ok, form}, fn element, {:ok, form} ->
            # 转换模板元素为表单项属性
            item_attrs = %{
              type: get_element_type(element),
              label: get_element_label(element),
              placeholder: get_element_placeholder(element),
              required: get_element_required(element)
            }

            # 添加表单项
            case MyApp.Forms.add_form_item(form, item_attrs) do
              {:ok, _} -> {:cont, {:ok, form}}
              {:error, changeset} -> {:halt, {:error, changeset}}
            end
          end)

        case result do
          {:ok, form} -> {:ok, MyApp.Forms.get_form_with_full_preload(form.id)}
          error -> error
        end

      error ->
        error
    end
  end

  # 从模板元素中提取字段
  defp get_element_type(element) do
    type = Map.get(element, :type) || Map.get(element, "type")

    try do
      case type do
        "text" -> :text_input
        "number" -> :number
        "select" -> :dropdown
        _ when is_binary(type) -> String.to_existing_atom(type)
        _ when is_atom(type) -> type
        _ -> :text_input
      end
    rescue
      # 默认类型
      _ -> :text_input
    end
  end

  defp get_element_label(element) do
    Map.get(element, :label) || Map.get(element, "label") || "未命名字段"
  end

  defp get_element_placeholder(element) do
    Map.get(element, :placeholder) || Map.get(element, "placeholder") || ""
  end

  defp get_element_required(element) do
    Map.get(element, :required) || Map.get(element, "required") || false
  end

  @doc """
  渲染表单模板为HTML。

  ## 参数
    - template: 表单模板结构体
    - form_data: 表单数据，格式为 %{"field_name" => "value"}

  ## 返回值
    渲染后的HTML字符串

  ## 示例

      iex> render_template(template, %{"name" => "John"})
      "<form>...rendered HTML...</form>"
  """
  def render_template(%FormTemplate{} = template, form_data) when is_map(form_data) do
    FormTemplate.render(template, form_data)
  end

  @doc """
  根据表单模板和表单数据筛选要显示的表单项。

  ## 参数
    - items: 表单项列表，通常是 form.items
    - template_structure: 表单模板结构，通常是 template.structure
    - form_data: 表单数据，格式为 %{"field_id" => "value"}

  ## 返回值
    满足条件显示规则的表单项列表

  ## 示例

      iex> filter_items_by_template(form.items, template.structure, %{"name" => "John"})
      [%FormItem{}, %FormItem{}, ...]
  """
  def filter_items_by_template(items, form_data, template_structure)
      when is_list(items) and is_map(form_data) do
    # Extract first and second field IDs from the template structure
    %{"elements" => elements} = template_structure

    %{"config" => %{"first_field_id" => first_field_id, "second_field_id" => second_field_id}} =
      Enum.find(elements, &(&1["type"] == "demo_logic"))

    _first_field_value = Map.get(form_data, first_field_id, "") || ""
    _second_field_value = Map.get(form_data, second_field_id, "") || ""

    # For now, return all items regardless of the filter values
    # Replace with actual filtering logic based on _first_field_value and _second_field_value
    items
  end

  @doc """
  根据特定的筛选规则过滤表单项。

  这是用于表单模板演示页面的特殊版本，支持基于位置索引的过滤规则。

  ## 参数
    - items: 表单项列表，通常是 form.items
    - form_data: 表单数据
    - template_structure: 模板结构

  ## 返回值
    满足特定筛选规则的表单项列表
  """
  def filter_items_by_demo_rules(items, form_data, _template_structure)
      when is_list(items) and is_map(form_data) do
    # IO.inspect(form_data, label: "Form Data for Demo Filtering")
    # IO.inspect(items, label: "Items for Demo Filtering")
    # 示例逻辑：如果表单数据中 "field_abc" 的值是 "show_special"
    # 则只显示类型为 "special_type" 的项目
    # ... existing code ...
  end
end
