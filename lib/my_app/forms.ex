defmodule MyApp.Forms do
  @moduledoc """
  The Forms context.
  """

  import Ecto.Query, warn: false
  alias MyApp.Repo

  alias MyApp.Forms.Form
  # alias MyApp.Forms.FormItem
  # alias MyApp.Forms.ItemOption

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

  # Other function implementations will go here
end 