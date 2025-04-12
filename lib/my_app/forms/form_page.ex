defmodule MyApp.Forms.FormPage do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Forms.Form
  alias MyApp.Forms.FormItem

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "form_pages" do
    field :title, :string
    field :description, :string
    field :order, :integer

    belongs_to :form, Form
    has_many :items, FormItem, foreign_key: :page_id

    timestamps()
  end

  @doc false
  def changeset(page, attrs) do
    page
    |> cast(attrs, [:title, :description, :order, :form_id])
    |> validate_required([:title, :form_id])
    |> foreign_key_constraint(:form_id)
  end
end
