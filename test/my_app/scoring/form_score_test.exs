defmodule MyApp.Scoring.FormScoreTest do
  use MyApp.DataCase, async: true

  alias MyApp.Scoring.FormScore
  alias MyApp.Factory # Assuming ExMachina factory module

  describe "changeset/2" do
    test "valid changeset for creating a form score config" do
      form = Factory.insert(:form)
      valid_attrs = %{
        total_score: 100,
        passing_score: 60,
        score_visibility: :public,
        auto_score: true,
        form_id: form.id
      }

      changeset = FormScore.changeset(%FormScore{}, valid_attrs)
      assert changeset.valid?
    end

    test "valid changeset with minimal attributes (uses defaults)" do
      form = Factory.insert(:form)
      valid_attrs = %{
        total_score: 50, # Required
        form_id: form.id # Required
      }

      changeset = FormScore.changeset(%FormScore{}, valid_attrs)
      assert changeset.valid?
      # Check defaults are applied if needed by get_field/get_change later
    end

    test "invalid changeset when missing required fields" do
      # Missing total_score, form_id
      invalid_attrs = %{
        passing_score: 60
      }

      changeset = FormScore.changeset(%FormScore{}, invalid_attrs)
      refute changeset.valid?
      assert errors_on(changeset) |> Keyword.has_key?(:total_score)
      assert errors_on(changeset) |> Keyword.has_key?(:form_id)
    end

    test "invalid changeset with non-positive total_score" do
      form = Factory.insert(:form)
      invalid_attrs = %{
        total_score: 0,
        form_id: form.id
      }

      changeset = FormScore.changeset(%FormScore{}, invalid_attrs)
      refute changeset.valid?
      assert errors_on(changeset) |> Keyword.get(:total_score) == ["must be greater than 0"]
    end

    test "invalid changeset with non-positive passing_score" do
      form = Factory.insert(:form)
      invalid_attrs = %{
        total_score: 100,
        passing_score: 0,
        form_id: form.id
      }

      changeset = FormScore.changeset(%FormScore{}, invalid_attrs)
      refute changeset.valid?
      assert errors_on(changeset) |> Keyword.get(:passing_score) == ["must be greater than 0"]
    end

    test "invalid changeset with passing_score greater than total_score" do
      form = Factory.insert(:form)
      invalid_attrs = %{
        total_score: 100,
        passing_score: 101,
        form_id: form.id
      }

      changeset = FormScore.changeset(%FormScore{}, invalid_attrs)
      refute changeset.valid?
      # The error message depends on how validate_number is implemented with less_than_or_equal_to
      assert errors_on(changeset) |> Keyword.has_key?(:passing_score)
    end

     test "valid changeset with passing_score equal to total_score" do
      form = Factory.insert(:form)
      valid_attrs = %{
        total_score: 100,
        passing_score: 100,
        form_id: form.id
      }

      changeset = FormScore.changeset(%FormScore{}, valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with invalid score_visibility enum value" do
      form = Factory.insert(:form)
      invalid_attrs = %{
        total_score: 100,
        score_visibility: :invalid_value,
        form_id: form.id
      }

      changeset = FormScore.changeset(%FormScore{}, invalid_attrs)
      refute changeset.valid?
      assert errors_on(changeset) |> Keyword.has_key?(:score_visibility)
    end

    test "invalid changeset with non-existent form_id" do
       non_existent_form_id = Ecto.UUID.generate()
       attrs = %{
        total_score: 100,
        form_id: non_existent_form_id
      }
      changeset = FormScore.changeset(%FormScore{}, attrs)
      assert errors_on(changeset) |> Keyword.has_key?(:form_id)
    end

  end
end
