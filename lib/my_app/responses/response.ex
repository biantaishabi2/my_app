defmodule MyApp.Responses.Response do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Forms.Form
  alias MyApp.Responses.Answer

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "responses" do
    # Use Ecto.ULID or keep :binary_id depending on preference
    # Precise submission time
    field :submitted_at, :utc_datetime_usec
    # Store user info, etc. as JSONB/Map
    field :respondent_info, :map, default: %{}

    belongs_to :form, Form
    has_many :answers, Answer, on_delete: :delete_all

    # Use timestamps() for automatic management
    timestamps(type: :utc_datetime_usec)
    # field :inserted_at, :utc_datetime_usec, read_after_writes: true # Replaced by timestamps()
    # field :updated_at, :utc_datetime_usec, read_after_writes: true # Replaced by timestamps()
  end

  @doc false
  def changeset(response, attrs) do
    response
    # Remove inserted_at/updated_at from cast if they were there (they weren't in last view)
    |> cast(attrs, [:form_id, :submitted_at, :respondent_info])
    |> validate_required([:form_id, :submitted_at])
    |> foreign_key_constraint(:form_id)
    # Basic handling for nested answers
    |> put_assoc(:answers, attrs[:answers] || [])
  end
end
