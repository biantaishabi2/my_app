defmodule MyApp.Responses.Response do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Forms.Form
  alias MyApp.Responses.Answer

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "responses" do
    # Use Ecto.ULID or keep :binary_id depending on preference
    field :submitted_at, :utc_datetime_usec # Precise submission time
    field :respondent_info, :map, default: %{} # Store user info, etc. as JSONB/Map

    belongs_to :form, Form
    has_many :answers, Answer, on_delete: :delete_all

    # No timestamps() here, submitted_at serves that purpose primarily
    # Add inserted_at/updated_at if needed for internal tracking
    field :inserted_at, :utc_datetime, read_after_writes: true
  end

  @doc false
  def changeset(response, attrs) do
    response
    |> cast(attrs, [:form_id, :submitted_at, :respondent_info])
    |> validate_required([:form_id, :submitted_at])
    |> foreign_key_constraint(:form_id)
    |> put_assoc(:answers, attrs[:answers] || []) # Basic handling for nested answers
  end
end 