defmodule MyApp.Responses.Answer do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Responses.Response
  alias MyApp.Forms.FormItem

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "answers" do
    # Use JSONB/Map to store various answer types (string, list, etc.)
    field :value, :map

    belongs_to :response, Response
    belongs_to :form_item, FormItem

    # No timestamps needed usually
    field :inserted_at, :utc_datetime, read_after_writes: true
    field :updated_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(answer, attrs) do
    answer
    |> cast(attrs, [:value, :response_id, :form_item_id, :inserted_at, :updated_at])
    |> validate_required([:value, :response_id, :form_item_id])
    |> foreign_key_constraint(:response_id)
    |> foreign_key_constraint(:form_item_id)
  end
end
