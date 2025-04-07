defmodule MyApp.Forms.ItemOption do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Forms.FormItem
  alias MyApp.Upload.UploadedFile

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "item_options" do
    field :label, :string
    field :value, :string # Or consider :text if values can be long
    field :order, :integer
    field :image_filename, :string

    belongs_to :form_item, FormItem
    belongs_to :image, UploadedFile, foreign_key: :image_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(option, attrs) do
    option
    |> cast(attrs, [:label, :value, :order, :form_item_id, :image_id, :image_filename])
    |> validate_required([:label, :value, :order, :form_item_id])
    |> foreign_key_constraint(:form_item_id)
    |> foreign_key_constraint(:image_id)
  end
end 