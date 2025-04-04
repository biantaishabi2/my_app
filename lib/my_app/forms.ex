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

    # 构造完整的item属性
    attrs = Map.merge(item_attrs, %{
      form_id: form.id,
      order: new_order
    })

    %FormItem{}
    |> FormItem.changeset(attrs)
    |> Repo.insert()
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

    # 构造完整的option属性
    attrs = Map.merge(option_attrs, %{
      form_item_id: form_item.id,
      order: new_order
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
end