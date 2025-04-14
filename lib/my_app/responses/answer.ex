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

    # Use timestamps() for automatic management
    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(answer, attrs) do
    answer
    |> cast(attrs, [:value, :response_id, :form_item_id])
    |> validate_required([:value, :form_item_id])
    |> foreign_key_constraint(:response_id)
    |> foreign_key_constraint(:form_item_id)
  end
end
