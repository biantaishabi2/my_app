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

  # Other function implementations will go here
end 