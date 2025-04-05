defmodule MyApp.Forms do
  @moduledoc """
  The Forms context.
  """

  import Ecto.Query, warn: false
  alias MyApp.Repo

  alias MyApp.Forms.Form
  alias MyApp.Forms.FormItem
  alias MyApp.Forms.ItemOption

  @doc """
  Creates a form.

  ## Examples

      iex> create_form(%{field: value})
      {:ok, %Form{}} # Changed Form to MyApp.Forms.Form

      iex> create_form(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_form(attrs \\ %{}) do
    %Form{}
    |> Form.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single form by ID.

  Returns nil if the form does not exist.

  ## Examples

      iex> get_form(123)
      %Form{}

      iex> get_form(456)
      nil

  """
  def get_form(id) do
    Repo.get(Form, id)
    |> preload_form_items_and_options()
  end

  @doc """
  Adds a form item to the given form.

  ## Examples

      iex> add_form_item(form, %{label: "Name", type: :text_input})
      {:ok, %FormItem{}}

      iex> add_form_item(form, %{type: :text_input})
      {:error, %Ecto.Changeset{}}

  """
  def add_form_item(form, item_attrs) do
    # 计算新item的order
    new_order = get_next_item_order(form.id)

    # 规范化属性确保都是字符串键
    normalized_attrs = normalize_attrs(item_attrs)

    # 构造完整的item属性
    attrs = Map.merge(normalized_attrs, %{
      "form_id" => form.id,
      "order" => new_order
    })
    
    # 打印构造的属性，用于调试
    IO.puts("准备创建表单项，attrs: #{inspect(attrs)}")
    IO.puts("type值: #{inspect(attrs["type"])}, 类型: #{inspect(typeof(attrs["type"]))}")

    # 创建changeset和插入
    result = create_form_item(attrs)
    
    # 打印结果
    case result do
      {:ok, item} -> IO.puts("表单项保存成功: #{inspect(item.id)}")
      {:error, err_changeset} -> IO.puts("表单项保存失败: #{inspect(err_changeset.errors)}")
    end
    
    result
  end
  
  @doc """
  Gets the next order value for a new form item.
  """
  def get_next_item_order(form_id) do
    query = from i in FormItem,
            where: i.form_id == ^form_id,
            select: count(i.id)
    Repo.one(query) + 1
  end
  
  @doc """
  Creates a form item with the given attributes.
  """
  def create_form_item(attrs) do
    # 处理特殊属性
    attrs = prepare_special_attributes(attrs)
    
    # 创建changeset
    changeset = FormItem.changeset(%FormItem{}, attrs)
    
    # 打印changeset信息
    IO.puts("Changeset验证: #{inspect(changeset.valid?)}")
    IO.puts("Changeset错误: #{inspect(changeset.errors)}")
    
    # 插入数据库
    Repo.insert(changeset)
  end
  
  # 处理特殊表单项属性
  defp prepare_special_attributes(attrs) do
    case get_in(attrs, ["type"]) || get_in(attrs, [:type]) do
      "rating" ->
        # 处理评分控件的属性，将max_rating转换为整数
        max_rating = attrs["max_rating"] || attrs[:max_rating] || "5"
        max_rating = 
          case max_rating do
            max when is_binary(max) -> String.to_integer(max)
            max when is_integer(max) -> max
            _ -> 5
          end
        Map.put(attrs, "max_rating", max_rating)
      
      _ ->
        attrs
    end
  end
  
  # 辅助函数，用于打印变量类型
  defp typeof(x) do
    cond do
      is_binary(x) -> "字符串"
      is_boolean(x) -> "布尔值"
      is_atom(x) -> "原子"
      is_integer(x) -> "整数"
      is_float(x) -> "浮点数"
      is_map(x) -> "映射"
      is_list(x) -> "列表"
      is_tuple(x) -> "元组"
      true -> "未知类型"
    end
  end
  
  @doc """
  Normalizes attributes to ensure all keys are strings.
  Useful to prevent mixing atom and string keys in maps passed to changesets.
  
  ## Examples
  
      iex> normalize_attrs(%{label: "Text", type: :text_input})
      %{"label" => "Text", "type" => :text_input}
  """
  def normalize_attrs(attrs) do
    for {key, val} <- attrs, into: %{} do
      {to_string(key), val}
    end
  end

  @doc """
  Adds an option to a form item.

  ## Examples

      iex> add_item_option(form_item, %{label: "Yes", value: "yes"})
      {:ok, %ItemOption{}}

      iex> add_item_option(form_item, %{value: "no"})
      {:error, %Ecto.Changeset{}}

  """
  def add_item_option(form_item, option_attrs) do
    # 计算新option的order
    new_order = get_next_option_order(form_item.id)

    # 规范化属性确保都是字符串键
    normalized_attrs = normalize_attrs(option_attrs)

    # 构造完整的option属性
    attrs = Map.merge(normalized_attrs, %{
      "form_item_id" => form_item.id,
      "order" => new_order
    })

    # 创建并插入选项
    create_item_option(attrs)
  end
  
  @doc """
  Gets the next order value for a new item option.
  """
  def get_next_option_order(form_item_id) do
    query = from o in ItemOption,
            where: o.form_item_id == ^form_item_id,
            select: count(o.id)
    Repo.one(query) + 1
  end
  
  @doc """
  Creates an item option with the given attributes.
  """
  def create_item_option(attrs) do
    %ItemOption{}
    |> ItemOption.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Publishes a form by changing its status from :draft to :published.
  Returns error if the form is already published.

  ## Examples

      iex> publish_form(form)
      {:ok, %Form{}}

      iex> publish_form(published_form)
      {:error, :already_published}

  """
  def publish_form(%Form{status: :published}), do: {:error, :already_published}
  def publish_form(%Form{} = form) do
    form
    |> Form.changeset(%{status: :published})
    |> Repo.update()
  end

  @doc """
  Returns a form changeset for the given form and attributes.

  ## Examples

      iex> change_form(form)
      %Ecto.Changeset{data: %Form{}}

  """
  def change_form(%Form{} = form, attrs \\ %{}) do
    Form.changeset(form, attrs)
  end

  @doc """
  Lists all forms for a specific user.

  ## Examples

      iex> list_forms(user_id)
      [%Form{}, ...]

  """
  def list_forms(user_id) do
    Form
    |> where([f], f.user_id == ^user_id)
    |> order_by([f], desc: f.updated_at)
    |> Repo.all()
  end

  @doc """
  Updates a form.

  ## Examples

      iex> update_form(form, %{field: new_value})
      {:ok, %Form{}}

      iex> update_form(form, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_form(%Form{} = form, attrs) do
    form
    |> Form.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a form.

  ## Examples

      iex> delete_form(form)
      {:ok, %Form{}}

      iex> delete_form(form)
      {:error, %Ecto.Changeset{}}

  """
  def delete_form(%Form{} = form) do
    Repo.delete(form)
  end

  @doc """
  Gets a form with all its items and their options.

  ## Examples

      iex> get_form_with_items(123)
      %Form{items: [%FormItem{options: [%ItemOption{}, ...]}, ...]}

      iex> get_form_with_items(456)
      nil

  """
  def get_form_with_items(id) do
    Form
    |> Repo.get(id)
    |> preload_form_items_and_options()
  end
  
  @doc """
  Preloads form items and their options for a form.
  This is a utility function to standardize preloading across different functions.
  
  ## Examples
  
      iex> preload_form_items_and_options(form)
      %Form{items: [%FormItem{options: [%ItemOption{}, ...]}, ...]}
      
  """
  def preload_form_items_and_options(nil), do: nil
  def preload_form_items_and_options(form) do
    Repo.preload(form, items: {from(i in FormItem, order_by: i.order), [options: from(o in ItemOption, order_by: o.order)]})
  end

  @doc """
  Gets a single form item by ID.

  Returns nil if the form item does not exist.

  ## Examples

      iex> get_form_item(123)
      %FormItem{}

      iex> get_form_item(456)
      nil

  """
  def get_form_item(id) do
    Repo.get(FormItem, id)
  end
  
  @doc """
  Gets a single form item by ID and preloads its options.

  Returns nil if the form item does not exist.

  ## Examples

      iex> get_form_item_with_options(123)
      %FormItem{options: [%ItemOption{}, ...]}

      iex> get_form_item_with_options(456)
      nil

  """
  def get_form_item_with_options(id) do
    FormItem
    |> Repo.get(id)
    |> Repo.preload(options: from(o in ItemOption, order_by: o.order))
  end
  
  @doc """
  Updates a form item.

  ## Examples

      iex> update_form_item(item, %{field: new_value})
      {:ok, %FormItem{}}

      iex> update_form_item(item, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_form_item(%FormItem{} = item, attrs) do
    # 处理特殊属性
    attrs = prepare_special_attributes(attrs)
    
    item
    |> FormItem.changeset(attrs)
    |> Repo.update()
  end
  
  @doc """
  Deletes a form item and its associated options.

  ## Examples

      iex> delete_form_item(item)
      {:ok, %FormItem{}}

      iex> delete_form_item(item)
      {:error, %Ecto.Changeset{}}

  """
  def delete_form_item(%FormItem{} = item) do
    Repo.delete(item)
  end
  
  @doc """
  Deletes an item option.

  ## Examples

      iex> delete_item_option(option)
      {:ok, %ItemOption{}}

      iex> delete_item_option(option)
      {:error, %Ecto.Changeset{}}

  """
  def delete_item_option(%ItemOption{} = option) do
    Repo.delete(option)
  end

  @doc """
  Reorders form items for a specific form.
  
  Takes a form_id and a list of item_ids in the desired order.
  Updates the order of each item accordingly.
  
  ## Examples
  
      iex> reorder_form_items(form_id, [item3_id, item1_id, item2_id])
      {:ok, [%FormItem{order: 1}, %FormItem{order: 2}, %FormItem{order: 3}]}
      
      iex> reorder_form_items(form_id, [invalid_id, ...])
      {:error, :invalid_item_ids}
      
  """
  def reorder_form_items(form_id, item_ids) do
    # 1. Get all items for this form
    query = from i in FormItem, where: i.form_id == ^form_id
    form_items = Repo.all(query)
    form_item_ids = Enum.map(form_items, & &1.id)
    
    # 2. Validate all item_ids are from this form
    if Enum.sort(form_item_ids) != Enum.sort(item_ids) do
      if Enum.all?(item_ids, &(&1 in form_item_ids)) do
        {:error, :missing_items}
      else
        {:error, :invalid_item_ids}
      end
    else
      # 3. Update the order of each item
      Repo.transaction(fn ->
        results = Enum.with_index(item_ids, 1) |> Enum.map(fn {item_id, new_order} ->
          item = Enum.find(form_items, &(&1.id == item_id))
          
          # Only update if the order has changed
          if item.order != new_order do
            {:ok, updated_item} = update_form_item(item, %{order: new_order})
            updated_item
          else
            item
          end
        end)
        
        # Sort results by new order
        Enum.sort_by(results, & &1.order)
      end)
    end
  end
end