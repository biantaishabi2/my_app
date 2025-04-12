defmodule MyApp.Upload.UploadedFile do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Forms.Form
  alias MyApp.Forms.FormItem
  alias MyApp.Responses.Response

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "uploaded_files" do
    field :original_filename, :string
    field :filename, :string
    field :path, :string
    field :size, :integer
    field :content_type, :string

    belongs_to :form, Form
    belongs_to :form_item, FormItem
    belongs_to :response, Response

    timestamps()
  end

  @doc false
  def changeset(uploaded_file, attrs) do
    uploaded_file
    |> cast(attrs, [
      :form_id,
      :form_item_id,
      :response_id,
      :original_filename,
      :filename,
      :path,
      :size,
      :content_type
    ])
    |> validate_required([
      :form_id,
      :form_item_id,
      :original_filename,
      :filename,
      :path,
      :size,
      :content_type
    ])
    |> foreign_key_constraint(:form_id)
    |> foreign_key_constraint(:form_item_id)
    |> foreign_key_constraint(:response_id)
  end
end
