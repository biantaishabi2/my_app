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
    form = Repo.get(Form, id)
    if form do
      # 强制加载所有关联的项目和选项，确保测试可以正确访问
      Repo.preload(form, items: {from(i in FormItem, order_by: i.order), [options: from(o in ItemOption, order_by: o.order)]})
    else
      nil
    end
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
    query = from i in FormItem,
            where: i.form_id == ^form.id,
            select: count(i.id)
    new_order = Repo.one(query) + 1

    # 确保attributes全部是字符串键，防止混合键导致错误
    string_attrs = 
      for {key, val} <- item_attrs, into: %{} do
        {to_string(key), val}
      end

    # 构造完整的item属性
    # 确保使用字符串键
    attrs = Map.merge(string_attrs, %{
      "form_id" => form.id,
      "order" => new_order
    })
    
    # 打印构造的属性，用于调试
    IO.puts("准备创建表单项，attrs: #{inspect(attrs)}")
    IO.puts("type值: #{inspect(attrs["type"])}, 类型: #{inspect(typeof(attrs["type"]))}")

    # 创建changeset
    changeset = FormItem.changeset(%FormItem{}, attrs)
    
    # 打印changeset信息
    IO.puts("Changeset验证: #{inspect(changeset.valid?)}")
    IO.puts("Changeset错误: #{inspect(changeset.errors)}")
    
    # 插入数据库
    result = Repo.insert(changeset)
    
    # 打印结果
    case result do
      {:ok, item} -> IO.puts("表单项保存成功: #{inspect(item.id)}")
      {:error, err_changeset} -> IO.puts("表单项保存失败: #{inspect(err_changeset.errors)}")
    end
    
    result
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
  Adds an option to a form item.

  ## Examples

      iex> add_item_option(form_item, %{label: "Yes", value: "yes"})
      {:ok, %ItemOption{}}

      iex> add_item_option(form_item, %{value: "no"})
      {:error, %Ecto.Changeset{}}

  """
  def add_item_option(form_item, option_attrs) do
    # 计算新option的order
    query = from o in ItemOption,
            where: o.form_item_id == ^form_item.id,
            select: count(o.id)
    new_order = Repo.one(query) + 1

    # 确保所有键都是字符串 - 这是防止混合键错误的关键
    string_attrs = 
      for {key, val} <- option_attrs, into: %{} do
        {to_string(key), val}
      end

    # 构造完整的option属性 - 使用字符串键
    attrs = Map.merge(string_attrs, %{
      "form_item_id" => form_item.id,
      "order" => new_order
    })

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
    |> Repo.preload(items: {from(i in FormItem, order_by: i.order), [options: from(o in ItemOption, order_by: o.order)]})
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