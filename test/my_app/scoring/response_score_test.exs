defmodule MyApp.Scoring.ResponseScoreTest do
  use MyApp.DataCase, async: true

  alias MyApp.Repo
  alias MyApp.Scoring.ResponseScore
  alias MyApp.Scoring.ScoreRule
  alias MyApp.Accounts.User
  alias MyApp.Forms.Form
  alias MyApp.Responses.Response
  alias MyApp.Forms.FormItem

  # TODO: Add necessary aliases (e.g., for Response, User, Form)
  # TODO: Add helper functions if needed (e.g., insert_response)

  # --- Helper functions (copied/adapted) ---
  defp insert_user(attrs \\ %{}) do
    default_attrs = %{
      email: "user#{System.unique_integer()}@example.com",
      name: "Test User",
      password: "Password123!"
    }
    user_attrs = Map.merge(default_attrs, attrs)
    %User{}
    |> User.registration_changeset(user_attrs)
    |> Repo.insert!()
  end

  defp insert_form(user, attrs \\ %{}) do
    default_attrs = %{title: "Test Form", description: "A test form"}
    %Form{}
    |> Form.changeset(Map.merge(default_attrs, Map.put(attrs, :user_id, user.id)))
    |> Repo.insert!()
  end

  # Helper function to insert a form item
  defp insert_form_item(form, attrs \\ %{}) do
    default_attrs = %{
      label: "Test Item",
      type: "text_input",
      settings: %{},
      position: 0,
      order: 0,
      form_id: form.id
    }
    item_attrs = Map.merge(default_attrs, attrs)
    %FormItem{}
    |> FormItem.changeset(item_attrs)
    |> Repo.insert!()
  end

  # Helper function to insert a score rule (copied from ScoringTest)
  defp insert_score_rule(form, user, attrs \\ []) do
    default_attrs = %{
      name: "Default Test Rule",
      rules: %{"version" => 1, "type" => "automatic", "items" => []},
      max_score: 100,
      form_id: form.id,
      user_id: user.id # Assuming ScoreRule still uses user_id directly
    }
    final_attrs = Keyword.merge(Map.to_list(default_attrs), attrs) |> Map.new()

    %ScoreRule{}
    |> ScoreRule.changeset(final_attrs)
    |> Repo.insert!()
  end

  # Basic helper to insert a response - Now requires form_item
  defp insert_response(user, form, form_item, attrs \\ %{}) do
    default_attrs = %{
      form_id: form.id,
      answers: [%{form_item_id: form_item.id, value: %{text: "default"}}],
      submitted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      respondent_info: %{user_id: user.id, email: user.email}
    }
    response_attrs = Map.merge(default_attrs, attrs)
    %Response{}
    |> Ecto.Changeset.cast(response_attrs, [:form_id, :submitted_at, :respondent_info])
    |> Ecto.Changeset.cast_assoc(:answers)
    |> Repo.insert!()
  end
  # --- End Helper functions ---

  @valid_attrs %{
    score: 85,
    max_score: 100,
    scored_at: DateTime.utc_now() |> DateTime.truncate(:second)
    # response_id will be added in tests
    # score_details is optional
  }

  describe "changeset/2" do
    # Tests will be added here based on TDD doc

    test "valid changeset with valid attributes" do
      user = insert_user()
      form = insert_form(user)
      form_item = insert_form_item(form)
      response = insert_response(user, form, form_item)
      score_rule = insert_score_rule(form, user)

      attrs = @valid_attrs
              |> Map.put(:response_id, response.id)
              |> Map.put(:score_rule_id, score_rule.id)

      changeset = ResponseScore.changeset(%ResponseScore{}, attrs)
      assert changeset.valid?
    end

    # Add other test cases from TDD doc 3.1
    test "invalid changeset when missing required fields" do
      # Test with an empty map
      attrs = %{}
      changeset = ResponseScore.changeset(%ResponseScore{}, attrs)
      refute changeset.valid?
      # Check for presence of error keys
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :response_id)
      assert Map.has_key?(errors, :score_rule_id)
      assert Map.has_key?(errors, :score)
      assert Map.has_key?(errors, :max_score)
      assert Map.has_key?(errors, :scored_at)
    end

    test "invalid changeset with invalid score or max_score (non-numeric, negative)" do
      # Need response and score_rule for other required fields
      user = insert_user()
      form = insert_form(user)
      form_item = insert_form_item(form)
      response = insert_response(user, form, form_item)
      score_rule = insert_score_rule(form, user)

      base_attrs = %{
        response_id: response.id,
        score_rule_id: score_rule.id,
        scored_at: DateTime.utc_now()
      }

      # Test non-numeric score
      attrs_invalid_score = Map.merge(base_attrs, %{score: "abc", max_score: 100})
      changeset_score_type = ResponseScore.changeset(%ResponseScore{}, attrs_invalid_score)
      refute changeset_score_type.valid?
      assert errors_on(changeset_score_type) |> Map.has_key?(:score)

      # Test negative score
      attrs_negative_score = Map.merge(base_attrs, %{score: -10, max_score: 100})
      changeset_score_neg = ResponseScore.changeset(%ResponseScore{}, attrs_negative_score)
      refute changeset_score_neg.valid?
      assert errors_on(changeset_score_neg) |> Map.has_key?(:score)

      # Test non-numeric max_score
      attrs_invalid_max = Map.merge(base_attrs, %{score: 50, max_score: "xyz"})
      changeset_max_type = ResponseScore.changeset(%ResponseScore{}, attrs_invalid_max)
      refute changeset_max_type.valid?
      assert errors_on(changeset_max_type) |> Map.has_key?(:max_score)

      # Test zero max_score (should be > 0)
      attrs_zero_max = Map.merge(base_attrs, %{score: 0, max_score: 0})
      changeset_max_zero = ResponseScore.changeset(%ResponseScore{}, attrs_zero_max)
      refute changeset_max_zero.valid?
      assert errors_on(changeset_max_zero) |> Map.has_key?(:max_score)

      # Test negative max_score
      attrs_negative_max = Map.merge(base_attrs, %{score: 0, max_score: -10})
      changeset_max_neg = ResponseScore.changeset(%ResponseScore{}, attrs_negative_max)
      refute changeset_max_neg.valid?
      assert errors_on(changeset_max_neg) |> Map.has_key?(:max_score)
    end

    test "invalid changeset with score greater than max_score" do
      # Need response and score_rule for other required fields
      user = insert_user()
      form = insert_form(user)
      form_item = insert_form_item(form)
      response = insert_response(user, form, form_item)
      score_rule = insert_score_rule(form, user)

      attrs = %{
        response_id: response.id,
        score_rule_id: score_rule.id,
        score: 110, # Score > max_score
        max_score: 100,
        scored_at: DateTime.utc_now()
      }

      changeset = ResponseScore.changeset(%ResponseScore{}, attrs)
      refute changeset.valid?
      # The custom validator adds error to :score key
      assert errors_on(changeset) |> Map.has_key?(:score)
      assert errors_on(changeset).score == ["cannot be greater than max score"]
    end

    test "invalid changeset with non-existent response_id" do
      # Need a valid score_rule for other required fields
      user = insert_user()
      form = insert_form(user)
      score_rule = insert_score_rule(form, user)

      non_existent_response_id = Ecto.UUID.generate() # Generate a random UUID

      attrs = %{
        response_id: non_existent_response_id,
        score_rule_id: score_rule.id,
        score: 50,
        max_score: 100,
        scored_at: DateTime.utc_now()
      }

      changeset = ResponseScore.changeset(%ResponseScore{}, attrs)
      # Changeset should be VALID at this stage, FK check happens at DB level.
      # The foreign_key_constraint only adds metadata for the DB check.
      assert changeset.valid?
      # Optionally, test the Repo operation:
      # assert {:error, fk_changeset} = Repo.insert(changeset)
      # assert fk_changeset.errors[:response_id] == {"does not exist", [constraint: :foreign]}
    end

  end
end
