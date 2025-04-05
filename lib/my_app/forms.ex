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
  Alias for get_form that ensures backward compatibility.
  Gets a single form with preloaded items.
  
  ## Examples
  
      iex> get_form_with_items(123)
      %Form{items: [%FormItem{}, ...]}
  """
  def get_form_with_items(id), do: get_form(id)
  
  @doc """
  Returns a changeset for a form.
  
  ## Examples
      
      iex> change_form(form)
      %Ecto.Changeset{}
  """
  def change_form(form, attrs \\ %{}) do
    Form.changeset(form, attrs)
  end

  @doc """
  Returns a list of all form item types supported by the system.
  
  ## Options
  
  * `:flat` - 返回扁平列表，不按类别分组
  
  ## Examples
  
      iex> list_available_form_item_types()
      %{
        basic: [:text_input, :textarea, :radio, :checkbox, :dropdown, :number],
        personal: [:email, :phone, :date, :time, :region],
        advanced: [:rating, :matrix, :image_choice, :file_upload]
      }
      
      iex> list_available_form_item_types(:flat)
      [:text_input, :textarea, :radio, :checkbox, ...]
  """
  def list_available_form_item_types(option \\ nil)
  
  def list_available_form_item_types(:flat) do
    # 直接返回所有支持的控件类型列表
    [
      :text_input, :textarea, :radio, :checkbox, :dropdown, :number,
      :email, :phone, :date, :time, :region,
      :rating, :matrix, :image_choice, :file_upload
    ]
  end
  
  def list_available_form_item_types(_) do
    # 按类别分组的控件类型
    %{
      basic: [:text_input, :textarea, :radio, :checkbox, :dropdown, :number],
      personal: [:email, :phone, :date, :time, :region],
      advanced: [:rating, :matrix, :image_choice, :file_upload]
    }
  end
  
  @doc """
  搜索控件类型，返回名称中包含搜索词的控件类型列表
  """
  def search_form_item_types(search_term) when is_binary(search_term) do
    search_term = String.downcase(search_term)
    
    # 获取所有控件类型
    all_types = list_available_form_item_types(:flat)
    
    # 过滤匹配搜索词的类型
    Enum.filter(all_types, fn type ->
      type
      |> Atom.to_string()
      |> String.downcase()
      |> String.contains?(search_term)
    end)
  end

  @doc """
  Gets a single form with preloaded items.

  Raises `Ecto.NoResultsError` if the Form does not exist.

  ## Examples

      iex> get_form!(123)
      %Form{}

      iex> get_form!(456)
      ** (Ecto.NoResultsError)

  """
  def get_form!(id) do
    Repo.get!(Form, id)
    |> preload_form_items_and_options()
  end

  @doc """
  Gets a form by ID with preloaded items and options, filtered by user_id authorization.
  
  ## Examples
  
      iex> get_authorized_form(form_id, user_id, :any)
      {:ok, %Form{}}
      
      iex> get_authorized_form(form_id, user_id, :owner)
      {:error, :unauthorized}
  
  """
  def get_authorized_form(form_id, user_id, authorization_level \\ :any) do
    case get_form(form_id) do
      nil -> 
        {:error, :not_found}
      form ->
        case authorization_level do
          :any -> 
            # For any level, user can access published forms and their own forms
            if form.status == :published or form.user_id == user_id do
              {:ok, form}
            else
              {:error, :unauthorized}
            end
          :owner ->
            # For owner level, user can only access their own forms
            if form.user_id == user_id do
              {:ok, form}
            else
              {:error, :unauthorized}
            end
        end
    end
  end
  
  @doc """
  Returns the list of forms for a given user.

  ## Examples

      iex> list_forms_for_user(user_id)
      [%Form{}, ...]

  """
  def list_forms_for_user(user_id) do
    # 转换整数ID为字符串，确保兼容性
    user_id = cond do
      is_integer(user_id) -> to_string(user_id)
      is_binary(user_id) -> user_id
      true -> raise ArgumentError, "user_id must be a string or integer"
    end
    
    Form
    |> where([f], f.user_id == ^user_id)
    |> order_by([f], [desc: f.inserted_at])
    |> Repo.all()
  end
  
  @doc """
  Alias for list_forms_for_user for backwards compatibility.
  """
  def list_forms(user_id), do: list_forms_for_user(user_id)
  
  @doc """
  Returns the list of all published forms.

  ## Examples

      iex> list_published_forms()
      [%Form{}, ...]

  """
  def list_published_forms do
    Form
    |> where([f], f.status == :published)
    |> order_by([f], [desc: f.inserted_at])
    |> Repo.all()
  end

  @doc """
  Creates or updates a form.

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
  Publishes a form.

  ## Examples

      iex> publish_form(form)
      {:ok, %Form{}}

      iex> publish_form(form) # when already published
      {:error, :already_published}

  """
  def publish_form(%Form{status: :draft} = form) do
    update_form(form, %{status: :published})
  end
  
  def publish_form(%Form{status: :published}) do
    {:error, :already_published}
  end
  
  def publish_form(%Form{}) do
    {:error, :invalid_status}
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
  Preloads items and options for a form.
  """
  def preload_form_items_and_options(nil), do: nil
  def preload_form_items_and_options(form) do
    form = Repo.preload(form, items: from(i in FormItem, order_by: i.order))
    %{form | items: preload_items_with_options(form.items)}
  end
  
  defp preload_items_with_options(items) do
    Enum.map(items, fn item ->
      Repo.preload(item, options: from(o in ItemOption, order_by: o.order))
    end)
  end

  @doc """
  Adds a form item to a form.

  ## Examples

      iex> add_form_item(form, %{type: :text_input, label: "Question", ...})
      {:ok, %FormItem{}}

      iex> add_form_item(form, %{bad: :data})
      {:error, %Ecto.Changeset{}}

  """
  def add_form_item(%Form{id: form_id}, attrs) do
    # Get the current highest order value for this form
    order_query = from i in FormItem,
                  where: i.form_id == ^form_id,
                  select: max(i.order)
    current_max_order = Repo.one(order_query) || 0
    
    # Normalize attributes to ensure type is correctly set
    attrs = normalize_attrs(attrs)
    
    # Prepare final attrs with the form_id and new order
    attrs = attrs
      |> Map.put(:form_id, form_id)
      |> Map.put(:order, current_max_order + 1)
    
    # Debug output for attributes
    IO.puts("准备创建表单项，attrs: #{inspect(attrs)}")
    
    # Debug type
    type = Map.get(attrs, :type) || Map.get(attrs, "type")
    type_str = if is_atom(type), do: "原子", else: "字符串"
    IO.puts("type值: #{inspect(type)}, 类型: \"#{type_str}\"")
    
    # Create the form item
    changeset = FormItem.changeset(%FormItem{}, attrs)
    
    # Debug changeset validation
    IO.puts("Changeset验证: #{changeset.valid?}")
    IO.puts("Changeset错误: #{inspect(changeset.errors)}")
    
    # Insert the form item
    case Repo.insert(changeset) do
      {:ok, item} -> 
        IO.puts("表单项保存成功: \"#{item.id}\"")
        {:ok, item}
      {:error, changeset} ->
        IO.puts("表单项保存失败: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end
  
  # Normalizes attributes, converting string keys to atoms and handling type conversion
  defp normalize_attrs(attrs) when is_map(attrs) do
    normalize_params(attrs)
    |> convert_type_to_atom()
    |> normalize_required_field()
    |> convert_category_to_atom()
  end
  
  # Handle category string to atom conversion
  defp convert_category_to_atom(%{category: category_str} = attrs) when is_binary(category_str) do
    %{attrs | category: String.to_existing_atom(category_str)}
  rescue
    # 如果转换失败，使用默认分类
    _ -> Map.delete(attrs, :category)
  end
  
  defp convert_category_to_atom(attrs), do: attrs
  
  # Convert string params to atom keys recursively
  defp normalize_params(params) when is_map(params) do
    Enum.reduce(params, %{}, fn
      {key, value}, acc when is_binary(key) ->
        Map.put(acc, String.to_atom(key), normalize_params(value))
      {key, value}, acc ->
        Map.put(acc, key, normalize_params(value))
    end)
  end
  
  defp normalize_params(params) when is_list(params) do
    Enum.map(params, &normalize_params/1)
  end
  
  defp normalize_params(other), do: other
  
  # Handle special case for :type conversion from string to atom
  defp convert_type_to_atom(%{type: type_str} = attrs) when is_binary(type_str) do
    %{attrs | type: String.to_existing_atom(type_str)}
  end
  
  defp convert_type_to_atom(attrs), do: attrs
  
  # Handle conversion of "required" field to boolean
  defp normalize_required_field(%{required: required} = attrs) when is_binary(required) do
    %{attrs | required: required == "true"}
  end
  
  defp normalize_required_field(attrs), do: attrs

  @doc """
  Gets a form item.
  
  ## Examples
  
      iex> get_form_item(id)
      %FormItem{}
      
      iex> get_form_item(invalid_id)
      nil
  """
  def get_form_item(id) do
    Repo.get(FormItem, id)
  end
  
  @doc """
  Gets a form item with preloaded options.
  
  ## Examples
  
      iex> get_form_item_with_options(id)
      %FormItem{options: [...]}
      
      iex> get_form_item_with_options(invalid_id)
      nil
  """
  def get_form_item_with_options(id) do
    FormItem
    |> Repo.get(id)
    |> Repo.preload(options: from(o in ItemOption, order_by: o.order))
  end

  @doc """
  Adds an option to a form item.

  ## Examples

      iex> add_item_option(form_item, %{label: "Option 1", value: "1"})
      {:ok, %ItemOption{}}

      iex> add_item_option(form_item, %{bad: :data})
      {:error, %Ecto.Changeset{}}

  """
  def add_item_option(%FormItem{id: item_id, type: type}, attrs) when type in [:radio, :checkbox, :dropdown] do
    # Get the current highest order value for this item
    order_query = from o in ItemOption,
                  where: o.form_item_id == ^item_id,
                  select: max(o.order)
    current_max_order = Repo.one(order_query) || 0
    
    # Create the final attrs map with computed values
    attrs = normalize_params(attrs)
    |> Map.put(:form_item_id, item_id)
    |> Map.put(:order, current_max_order + 1)
    
    # Create and insert the option
    %ItemOption{}
    |> ItemOption.changeset(attrs)
    |> Repo.insert()
  end
  
  def add_item_option(%FormItem{type: other_type}, _attrs) do
    {:error, "Item type #{other_type} does not support options"}
  end
  
  @doc """
  Reorders item options for a specific form item.
  
  Takes a form_item_id and a list of option_ids in the desired order.
  Updates the order of each option accordingly.
  
  ## Examples
  
      iex> reorder_item_options(item_id, [option3_id, option1_id, option2_id])
      {:ok, [%ItemOption{order: 1}, %ItemOption{order: 2}, %ItemOption{order: 3}]}
      
      iex> reorder_item_options(item_id, [invalid_id, ...])
      {:error, :invalid_option_ids}
      
  """
  def reorder_item_options(item_id, option_ids) do
    # 1. Get all options for this item
    query = from o in ItemOption, where: o.form_item_id == ^item_id
    item_options = Repo.all(query)
    option_item_ids = Enum.map(item_options, & &1.id)
    
    # 2. Validate all option_ids are from this item
    if Enum.sort(option_item_ids) != Enum.sort(option_ids) do
      if Enum.all?(option_ids, &(&1 in option_item_ids)) do
        {:error, :missing_options}
      else
        {:error, :invalid_option_ids}
      end
    else
      # 3. Update the order of each option
      Repo.transaction(fn ->
        results = Enum.with_index(option_ids, 1) |> Enum.map(fn {option_id, new_order} ->
          option = Enum.find(item_options, &(&1.id == option_id))
          
          # Only update if the order has changed
          if option.order != new_order do
            {:ok, updated_option} = update_item_option(option, %{order: new_order})
            updated_option
          else
            option
          end
        end)
        
        # Sort results by new order
        Enum.sort_by(results, & &1.order)
      end)
    end
  end
  
  @doc """
  Updates a form item.

  ## Examples

      iex> update_form_item(item, %{label: "New Label"})
      {:ok, %FormItem{}}

      iex> update_form_item(item, %{some: :invalid})
      {:error, %Ecto.Changeset{}}

  """
  def update_form_item(%FormItem{} = item, attrs) do
    attrs = normalize_attrs(attrs)
    
    item
    |> FormItem.changeset(attrs)
    |> Repo.update()
  end
  
  @doc """
  Updates an item option.

  ## Examples

      iex> update_item_option(option, %{label: "New Label"})
      {:ok, %ItemOption{}}

      iex> update_item_option(option, %{some: :invalid})
      {:error, %Ecto.Changeset{}}

  """
  def update_item_option(%ItemOption{} = option, attrs) do
    attrs = normalize_params(attrs)
    
    option
    |> ItemOption.changeset(attrs)
    |> Repo.update()
  end
  
  @doc """
  Deletes a form item.

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