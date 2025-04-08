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
  def list_templates(opts \\[]) do
    query = from(t in FormTemplate)
    
    query = if Keyword.get(opts, :active_only, false) do
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
        result = Enum.reduce_while(template.structure, {:ok, form}, fn element, {:ok, form} ->
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
        
      error -> error
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
      _ -> :text_input # 默认类型
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
end