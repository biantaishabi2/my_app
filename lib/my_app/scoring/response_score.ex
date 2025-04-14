defmodule MyApp.Scoring.ResponseScore do
  @moduledoc """
  Stores the scoring result for a single form response.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Responses.Response
  alias MyApp.Scoring.ScoreRule # Link to the rule used for scoring

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id # Matches Response and ScoreRule PKs

  schema "response_scores" do
    field :score, :integer           # Actual calculated score
    field :max_score, :integer        # Maximum possible score based on the rule/form
    field :score_details, :map, default: %{} # Optional: Store details like %{item_id => item_score}
    field :scored_at, :utc_datetime_usec # Timestamp when scoring was completed

    belongs_to :response, Response    # The response that was scored
    belongs_to :score_rule, ScoreRule # The rule used for scoring

    timestamps() # Adds inserted_at and updated_at
  end

  @doc false
  def changeset(response_score \\ %__MODULE__{}, attrs) do
    response_score
    |> cast(attrs, [:response_id, :score_rule_id, :score, :max_score, :scored_at, :score_details])
    |> validate_required([:response_id, :score_rule_id, :score, :max_score, :scored_at])
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> validate_number(:max_score, greater_than: 0)
    |> validate_score_vs_max_score()
    |> foreign_key_constraint(:response_id)
    |> foreign_key_constraint(:score_rule_id)
    # Ensures score_details is always a map, even if nil is passed
    |> maybe_cast_score_details()
  end

  defp validate_score_vs_max_score(changeset) do
    score = get_field(changeset, :score)
    max_score = get_field(changeset, :max_score)

    if is_integer(score) and is_integer(max_score) do
      if score > max_score do
        add_error(changeset, :score, "cannot be greater than max score")
      else
        changeset
      end
    else
      changeset # Don't add error if types are wrong, other validations handle that
    end
  end

  # Cast score_details safely, ensuring it's a map or becomes an empty map.
  defp maybe_cast_score_details(changeset) do
    case get_field(changeset, :score_details) do
      nil ->
        # If score_details is not provided or nil, put an empty map
        put_change(changeset, :score_details, %{})
      details when is_map(details) ->
        # If it's already a map, keep it
        changeset
      _ ->
        # If it's something else (e.g., string, integer), add an error
        add_error(changeset, :score_details, "must be a map")
    end
  end
end
