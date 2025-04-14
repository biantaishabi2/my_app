defmodule MyApp.Scoring.FormScore do
  @moduledoc """
  表单评分配置模型。

  存储表单整体的评分设置，如总分、评分模式等。
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Forms.Form

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "form_scores" do
    field :total_score, :integer, default: 100
    field :passing_score, :integer
    field :score_visibility, Ecto.Enum, values: [:private, :public], default: :private
    field :auto_score, :boolean, default: true

    belongs_to :form, Form

    timestamps()
  end

  @doc false
  def changeset(form_score, attrs) do
    form_score
    |> cast(attrs, [:total_score, :passing_score, :score_visibility, :auto_score, :form_id])
    |> validate_required([:total_score, :form_id])
    |> validate_number(:total_score, greater_than: 0)
    |> validate_number(:passing_score, greater_than: 0)
    |> validate_passing_score()
    |> foreign_key_constraint(:form_id)
  end

  # Custom validator to check passing_score against total_score
  defp validate_passing_score(changeset) do
    passing_score = get_field(changeset, :passing_score)
    total_score = get_field(changeset, :total_score)

    # Only validate if both scores are present and valid numbers so far
    if is_integer(passing_score) and is_integer(total_score) and passing_score > 0 do
      if passing_score > total_score do
        add_error(changeset, :passing_score, "must be less than or equal to total score")
      else
        changeset
      end
    else
      # If passing_score is nil or not a valid number yet, skip this validation
      # Other validators (validate_required, validate_number) will handle those cases
      changeset
    end
  end
end
