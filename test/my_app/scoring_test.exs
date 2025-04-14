defmodule MyApp.ScoringTest do
  use MyApp.DataCase, async: true

  alias MyApp.Repo
  alias MyApp.Scoring
  alias MyApp.Scoring.ScoreRule
  alias MyApp.Scoring.FormScore
  alias MyApp.Scoring.ResponseScore
  # Assuming schemas exist for these
  alias MyApp.Accounts.User
  alias MyApp.Forms.Form
  alias MyApp.Forms.FormItem
  alias MyApp.Responses.Response
  # alias MyApp.Factory # REMOVED

  @moduletag :scoring_context

  # Helper function to insert a default user
  defp insert_user(attrs \\ %{}) do
    default_attrs = %{
      email: "user#{System.unique_integer()}@example.com",
      name: "Test User",
      # Add a default password for registration changeset
      password: "Password123!"
    }
    user_attrs = Map.merge(default_attrs, attrs)

    # Use registration_changeset to handle password hashing
    %User{}
    |> User.registration_changeset(user_attrs)
    |> Repo.insert!()
  end

  # Helper function to insert a default form for a user
  defp insert_form(user, attrs \\ %{}) do
    default_attrs = %{title: "Test Form", description: "A test form"}
     %Form{}
     |> Form.changeset(Map.merge(default_attrs, Map.put(attrs, :user_id, user.id)))
     |> Repo.insert!()
  end

  # Helper function to insert a default score rule
  # Use Keyword.merge to handle keyword list attrs correctly
  defp insert_score_rule(form, user, attrs \\ []) do
    default_attrs = %{
      name: "Default Test Rule",
      rules: %{"version" => 1, "type" => "automatic", "items" => []},
      max_score: 100,
      form_id: form.id,
      user_id: user.id
    }
    # Use Keyword.merge for default_attrs (map) and attrs (keyword list)
    # Convert the result back to a map for the changeset
    final_attrs = Keyword.merge(Map.to_list(default_attrs), attrs) |> Map.new()

    %ScoreRule{}
    |> ScoreRule.changeset(final_attrs)
    |> Repo.insert!()
  end

  # Helper function to insert a form item
  defp insert_form_item(form, attrs) do
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

  # Helper function to insert a response
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

  # Helper function to insert a form score config
  defp insert_form_score(form, attrs) do
    default_attrs = %{
      total_score: 100,
      passing_score: 60,
      score_visibility: :private,
      auto_score: true,
      form_id: form.id
    }
    config_attrs = Map.merge(default_attrs, attrs)
    %FormScore{}
    |> FormScore.changeset(config_attrs)
    |> Repo.insert!()
  end

  # Helper function to insert a response score
  defp insert_response_score(response, score_rule, attrs) do
    default_attrs = %{
      response_id: response.id,
      score_rule_id: score_rule.id,
      score: 80, # Example score
      max_score: 100, # Example max_score
      scored_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
    score_attrs = Map.merge(default_attrs, attrs)
    %ResponseScore{}
    |> ResponseScore.changeset(score_attrs)
    |> Repo.insert!()
  end

  describe "Score Rule Management within Scoring Context" do
    @valid_rule_attrs %{
      name: "测试规则",
      description: "用于测试的规则",
      rules: %{
        "version" => 1,
        "type" => "automatic",
        "items" => []
      },
      max_score: 100
    }

    test "Scoring.create_score_rule/1 creates a score rule" do
      user = insert_user()
      form = insert_form(user)
      attrs = Map.put(@valid_rule_attrs, :form_id, form.id)

      assert {:ok, %ScoreRule{} = rule} = Scoring.create_score_rule(attrs, user)
      assert rule.name == "测试规则"
      assert rule.form_id == form.id
      assert rule.user_id == user.id
      assert not is_nil(rule.id)

      assert %ScoreRule{} = Repo.get(ScoreRule, rule.id)
    end

    test "Scoring.create_score_rule/1 fails with invalid data" do
      user = insert_user()
      # Missing form_id in @valid_rule_attrs
      assert {:error, %Ecto.Changeset{} = changeset} = Scoring.create_score_rule(@valid_rule_attrs, user)
      # Use Map.has_key? as errors_on returns a map
      assert errors_on(changeset) |> Map.has_key?(:form_id)
    end

    test "Scoring.get_score_rules_for_form/1 returns rules for a specific form" do
      user1 = insert_user()
      user2 = insert_user()
      form1 = insert_form(user1)
      form2 = insert_form(user2)

      _rule1 = insert_score_rule(form1, user1, name: "规则1")
      _rule2 = insert_score_rule(form2, user2, name: "规则2") # Belongs to other form
      _rule3 = insert_score_rule(form1, user1, name: "规则3")

      rules_for_form1 = Scoring.get_score_rules_for_form(form1.id)

      assert length(rules_for_form1) == 2
      assert Enum.all?(rules_for_form1, fn r -> r.form_id == form1.id end)
      rule_names = Enum.map(rules_for_form1, & &1.name) |> Enum.sort()
      assert rule_names == ["规则1", "规则3"]
    end

    test "Scoring.get_score_rules_for_form/1 returns empty list for form with no rules" do
      user = insert_user()
      form = insert_form(user)
      assert Scoring.get_score_rules_for_form(form.id) == []
    end

    test "Scoring.get_score_rule/1 returns the rule when it exists" do
      user = insert_user()
      form = insert_form(user)
      rule = insert_score_rule(form, user)

      assert {:ok, fetched_rule} = Scoring.get_score_rule(rule.id)
      assert fetched_rule.id == rule.id
      assert fetched_rule.name == rule.name
    end

    test "Scoring.get_score_rule/1 returns error when rule does not exist" do
      non_existent_id = Ecto.UUID.generate()
      assert {:error, :not_found} = Scoring.get_score_rule(non_existent_id)
    end

    test "Scoring.update_score_rule/2 updates an existing rule" do
      user = insert_user()
      form = insert_form(user)
      rule = insert_score_rule(form, user, name: "旧名称", is_active: true)
      update_attrs = %{name: "新名称", is_active: false}

      assert {:ok, updated_rule} = Scoring.update_score_rule(rule, update_attrs, user)
      assert updated_rule.id == rule.id
      assert updated_rule.name == "新名称"
      assert updated_rule.is_active == false

      db_rule = Repo.get!(ScoreRule, rule.id)
      assert db_rule.name == "新名称"
      assert db_rule.is_active == false
    end

    test "Scoring.update_score_rule/2 fails with invalid data" do
      user = insert_user()
      form = insert_form(user)
      rule = insert_score_rule(form, user)
      invalid_attrs = %{name: nil}

      assert {:error, %Ecto.Changeset{} = changeset} = Scoring.update_score_rule(rule, invalid_attrs, user)
      assert errors_on(changeset) |> Map.has_key?(:name)

      db_rule = Repo.get!(ScoreRule, rule.id)
      assert db_rule.name == rule.name # Should remain unchanged
    end

    test "Scoring.delete_score_rule/1 deletes an existing rule" do
      user = insert_user()
      form = insert_form(user)
      rule = insert_score_rule(form, user)

      assert {:ok, %ScoreRule{} = deleted_rule} = Scoring.delete_score_rule(rule, user)
      assert deleted_rule.id == rule.id

      assert Repo.get(ScoreRule, rule.id) == nil
      assert Scoring.get_score_rule(rule.id) == {:error, :not_found}
    end

    test "Scoring.delete_score_rule/1 returns the rule even if already deleted (idempotent)" do
      user = insert_user()
      form = insert_form(user)
      rule = insert_score_rule(form, user)
      {:ok, _} = Scoring.delete_score_rule(rule, user)

      assert {:ok, %ScoreRule{} = deleted_again} = Scoring.delete_score_rule(rule, user)
      assert deleted_again.id == rule.id
      assert Repo.get(ScoreRule, rule.id) == nil
    end
  end

  describe "Score Rule permissions" do
    # Define valid attrs accessible here
    @valid_rule_attrs %{
      name: "测试规则", description: "用于测试的规则",
      rules: %{"version" => 1, "type" => "automatic", "items" => []}, max_score: 100
    }

    setup do
      owner = insert_user()
      non_owner = insert_user()
      form = insert_form(owner)
      rule = insert_score_rule(form, owner)
      %{owner: owner, non_owner: non_owner, form: form, rule: rule, valid_rule_attrs: @valid_rule_attrs}
    end

    test "non-owner cannot create score rule for a form", %{non_owner: non_owner, form: form, valid_rule_attrs: attrs} do
      attrs_with_form = Map.put(attrs, :form_id, form.id)
      assert {:error, :unauthorized} = Scoring.create_score_rule(attrs_with_form, non_owner)
    end

    test "owner can create score rule for their form", %{owner: owner, form: form, valid_rule_attrs: attrs} do
      attrs_with_form = Map.put(attrs, :form_id, form.id)
      assert {:ok, _rule} = Scoring.create_score_rule(attrs_with_form, owner)
    end

    test "non-owner cannot update a score rule", %{non_owner: non_owner, rule: rule} do
      update_attrs = %{name: "Attempted Update"}
      assert {:error, :unauthorized} = Scoring.update_score_rule(rule, update_attrs, non_owner)
    end

    test "owner can update their score rule", %{owner: owner, rule: rule} do
      update_attrs = %{name: "Successful Update"}
      assert {:ok, updated_rule} = Scoring.update_score_rule(rule, update_attrs, owner)
      assert updated_rule.name == "Successful Update"
    end

    test "non-owner cannot delete a score rule", %{non_owner: non_owner, rule: rule} do
      assert {:error, :unauthorized} = Scoring.delete_score_rule(rule, non_owner)
      assert Repo.get(ScoreRule, rule.id) != nil
    end

    test "owner can delete their score rule", %{owner: owner, rule: rule} do
      assert {:ok, _deleted_rule} = Scoring.delete_score_rule(rule, owner)
      assert Repo.get(ScoreRule, rule.id) == nil
    end
  end

  describe "Form Score Configuration within Scoring Context" do
    @valid_config_attrs %{
      total_score: 100,
      passing_score: 60,
      score_visibility: :private,
      auto_score: true
    }

    test "Scoring.setup_form_scoring/2 creates config for a form for the first time" do
      user = insert_user()
      form = insert_form(user)
      attrs = @valid_config_attrs

      assert {:ok, %FormScore{} = config} = Scoring.setup_form_scoring(form.id, attrs, user)
      assert config.form_id == form.id
      assert config.total_score == 100
      assert config.passing_score == 60

      assert %FormScore{} = Repo.get_by(FormScore, form_id: form.id)
    end

    test "Scoring.setup_form_scoring/2 updates config if it already exists" do
      user = insert_user()
      form = insert_form(user)
      {:ok, initial_config} = Scoring.setup_form_scoring(form.id, @valid_config_attrs, user)

      update_attrs = %{total_score: 150, passing_score: 90, score_visibility: :public}
      assert {:ok, %FormScore{} = updated_config} = Scoring.setup_form_scoring(form.id, update_attrs, user)

      assert updated_config.id == initial_config.id
      assert updated_config.total_score == 150
      assert updated_config.passing_score == 90
      assert updated_config.score_visibility == :public

      db_config = Repo.get_by!(FormScore, form_id: form.id)
      assert db_config.total_score == 150
    end

    test "Scoring.setup_form_scoring/2 fails with invalid data" do
      user = insert_user()
      form = insert_form(user)
      invalid_attrs = %{total_score: 100, passing_score: 120}

      assert {:error, %Ecto.Changeset{} = changeset} = Scoring.setup_form_scoring(form.id, invalid_attrs, user)
      assert errors_on(changeset) |> Map.has_key?(:passing_score)

      assert Repo.get_by(FormScore, form_id: form.id) == nil
    end

    test "Scoring.get_form_score_config/1 returns the config when it exists" do
      user = insert_user()
      form = insert_form(user)
      {:ok, config} = Scoring.setup_form_scoring(form.id, @valid_config_attrs, user)

      assert %FormScore{} = fetched_config = Scoring.get_form_score_config(form.id)
      assert fetched_config.id == config.id
      assert fetched_config.total_score == config.total_score
    end

    test "Scoring.get_form_score_config/1 returns nil when config does not exist" do
      user = insert_user()
      form = insert_form(user)
      assert Scoring.get_form_score_config(form.id) == nil
    end
  end

  describe "Form Score permissions" do
    @valid_config_attrs %{
      total_score: 100, passing_score: 60, score_visibility: :private, auto_score: true
    }

    setup do
      owner = insert_user()
      non_owner = insert_user()
      form = insert_form(owner)
      %{owner: owner, non_owner: non_owner, form: form, valid_config_attrs: @valid_config_attrs}
    end

    test "non-owner cannot setup form score config", %{non_owner: non_owner, form: form, valid_config_attrs: attrs} do
      assert {:error, :unauthorized} = Scoring.setup_form_scoring(form.id, attrs, non_owner)
    end

    test "owner can setup form score config", %{owner: owner, form: form, valid_config_attrs: attrs} do
      assert {:ok, _config} = Scoring.setup_form_scoring(form.id, attrs, owner)
    end
  end

  # === Response Scoring (Calculation) Tests ===
  describe "Response Scoring (Calculation)" do
    setup do
      # Common setup for scoring tests
      user = insert_user()
      form = insert_form(user)
      # Use map for attributes
      form_item1 = insert_form_item(form, %{label: "Q1"})
      form_item2 = insert_form_item(form, %{label: "Q2"})
      %{user: user, form: form, form_item1: form_item1, form_item2: form_item2}
    end

    # --- Success Cases (3.1) ---
    test "成功计算并保存简单规则的得分", %{user: user, form: form, form_item1: item1} do
      # Use map for attributes in insert_score_rule if needed (assuming it accepts Keyword list)
      # Keyword list is fine for insert_score_rule based on its definition
      score_rule = insert_score_rule(form, user, name: "SimpleRule", max_score: 10, rules: %{
        "version" => 1, "type" => "automatic", "items" => [
          %{"item_id" => item1.id, "scoring_method" => "exact_match", "correct_answer" => %{text: "A"}, "score" => 10}
        ]
      })
      # Use map for attributes in insert_form_score
      insert_form_score(form, %{auto_score: true})
      # Use map for attributes in insert_response
      response = insert_response(user, form, item1, %{answers: [%{form_item_id: item1.id, value: %{text: "A"}}]})

      # Perform the scoring and assert results
      assert {:ok, %ResponseScore{} = response_score} = Scoring.score_response(response.id)
      assert response_score.score == 10
      assert response_score.max_score == 10
      assert response_score.response_id == response.id
      assert response_score.score_rule_id == score_rule.id
      assert not is_nil(response_score.scored_at)

      # Verify persistence
      assert %ResponseScore{} = db_score = Repo.get_by!(ResponseScore, response_id: response.id)
      assert db_score.score == 10
    end

    test "成功计算并保存涉及多个评分项的得分", %{user: user, form: form, form_item1: item1, form_item2: item2} do
      # Rule with two items, total max_score = 15
      score_rule = insert_score_rule(form, user, name: "MultiItemRule", max_score: 15, rules: %{
        "version" => 1, "type" => "automatic", "items" => [
          # Item 1: Correct answer 'A', score 10
          %{"item_id" => item1.id, "scoring_method" => "exact_match", "correct_answer" => %{text: "A"}, "score" => 10},
          # Item 2: Correct answer 'B', score 5
          %{"item_id" => item2.id, "scoring_method" => "exact_match", "correct_answer" => %{text: "B"}, "score" => 5}
        ]
      })
      insert_form_score(form, %{auto_score: true})
      # Response: Answers 'A' for item1 (correct), 'C' for item2 (incorrect)
      response = insert_response(user, form, item1, %{
        answers: [
          %{form_item_id: item1.id, value: %{text: "A"}},
          %{form_item_id: item2.id, value: %{text: "C"}}
        ]
      })

      # Perform the scoring and assert results
      assert {:ok, %ResponseScore{} = response_score} = Scoring.score_response(response.id)
      # Only item1 should score points
      assert response_score.score == 10
      assert response_score.max_score == 15 # Max score from the rule
      assert response_score.response_id == response.id
      assert response_score.score_rule_id == score_rule.id

      # Verify persistence
      assert %ResponseScore{} = db_score = Repo.get_by!(ResponseScore, response_id: response.id)
      assert db_score.score == 10
      assert db_score.max_score == 15
    end

    test "包含未在规则中定义的答案项 (应忽略)", %{user: user, form: form, form_item1: item1, form_item2: item2} do
      # Rule only defines scoring for item1, max_score = 10
      score_rule = insert_score_rule(form, user, name: "IgnoreExtraAnswersRule", max_score: 10, rules: %{
        "version" => 1, "type" => "automatic", "items" => [
          # Item 1: Correct answer 'A', score 10
          %{"item_id" => item1.id, "scoring_method" => "exact_match", "correct_answer" => %{text: "A"}, "score" => 10}
          # No rule for item2
        ]
      })
      insert_form_score(form, %{auto_score: true})
      # Response: Answers 'A' for item1 (correct), and 'X' for item2 (should be ignored)
      response = insert_response(user, form, item1, %{
        answers: [
          %{form_item_id: item1.id, value: %{text: "A"}},
          %{form_item_id: item2.id, value: %{text: "X"}} # Answer for item not in rule
        ]
      })

      # Perform the scoring and assert results
      assert {:ok, %ResponseScore{} = response_score} = Scoring.score_response(response.id)
      # Only item1 should score points, item2's answer is ignored
      assert response_score.score == 10
      assert response_score.max_score == 10 # Max score from the rule
      assert response_score.response_id == response.id
      assert response_score.score_rule_id == score_rule.id

      # Verify persistence
      assert %ResponseScore{} = db_score = Repo.get_by!(ResponseScore, response_id: response.id)
      assert db_score.score == 10
      assert db_score.max_score == 10
    end

    test "规则中包含未被回答的评分项 (得分按 0 计算)", %{user: user, form: form, form_item1: item1, form_item2: item2} do
      # Rule with two items, total max_score = 15
      score_rule = insert_score_rule(form, user, name: "MissingAnswerRule", max_score: 15, rules: %{
        "version" => 1, "type" => "automatic", "items" => [
          # Item 1: Correct answer 'A', score 10
          %{"item_id" => item1.id, "scoring_method" => "exact_match", "correct_answer" => %{text: "A"}, "score" => 10},
          # Item 2: Correct answer 'B', score 5 (This item won't be answered)
          %{"item_id" => item2.id, "scoring_method" => "exact_match", "correct_answer" => %{text: "B"}, "score" => 5}
        ]
      })
      insert_form_score(form, %{auto_score: true})
      # Response: Only answers 'A' for item1 (correct). No answer for item2.
      # Note: insert_response currently requires at least one answer via form_item arg.
      # We need to adjust insert_response or how we create the response data here.
      # Let's create the response manually for this case.
      response_attrs = %{
        form_id: form.id,
        answers: [%{form_item_id: item1.id, value: %{text: "A"}}],
        submitted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        respondent_info: %{user_id: user.id, email: user.email}
      }
      {:ok, response} = %Response{}
                       |> Ecto.Changeset.cast(response_attrs, [:form_id, :submitted_at, :respondent_info])
                       |> Ecto.Changeset.cast_assoc(:answers)
                       |> Repo.insert()

      # Perform the scoring and assert results
      assert {:ok, %ResponseScore{} = response_score} = Scoring.score_response(response.id)
      # Only item1 should score points, item2 gets 0 as it wasn't answered
      assert response_score.score == 10
      assert response_score.max_score == 15 # Max score from the rule
      assert response_score.response_id == response.id
      assert response_score.score_rule_id == score_rule.id

      # Verify persistence
      assert %ResponseScore{} = db_score = Repo.get_by!(ResponseScore, response_id: response.id)
      assert db_score.score == 10
      assert db_score.max_score == 15
    end

    # --- Error Handling & Edge Cases (3.2) ---
    test "响应已被评分", %{user: user, form: form, form_item1: item1} do
      score_rule = insert_score_rule(form, user)
      insert_form_score(form, %{auto_score: true}) # Use map
      response = insert_response(user, form, item1) # Uses default map
      # Pre-insert a score
      initial_score = insert_response_score(response, score_rule, %{score: 55})
      initial_score_count = Repo.all(ResponseScore) |> length()

      # Attempt to score again
      assert {:error, :already_scored} = Scoring.score_response(response.id)

      # Verify no new score was created and the old one is unchanged
      assert Repo.all(ResponseScore) |> length() == initial_score_count
      db_score = Repo.get!(ResponseScore, initial_score.id)
      assert db_score.score == 55 # Check score didn't change
    end

    test "响应不存在", %{user: _user, form: _form, form_item1: _item1} do
      non_existent_id = Ecto.UUID.generate()
      assert {:error, :response_not_found} = Scoring.score_response(non_existent_id)
    end

    test "表单未配置评分规则", %{user: user, form: form, form_item1: item1} do
      # 创建表单评分配置，但不创建评分规则
      insert_form_score(form, %{auto_score: true})
      response = insert_response(user, form, item1)
      # 期望返回评分规则未找到错误
      assert {:error, :score_rule_not_found} = Scoring.score_response(response.id)
    end

    test "表单未配置评分设置 (FormScore)", %{user: user, form: form, form_item1: item1} do
      insert_score_rule(form, user)
      response = insert_response(user, form, item1) # Uses default map
      # No FormScore inserted
      assert {:error, :form_score_config_not_found} = Scoring.score_response(response.id)
    end

    test "表单评分设置中禁用了自动评分", %{user: user, form: form, form_item1: item1} do
      insert_score_rule(form, user)
      insert_form_score(form, %{auto_score: false}) # Use map, auto score disabled
      response = insert_response(user, form, item1) # Uses default map
      assert {:error, :auto_score_disabled} = Scoring.score_response(response.id)
    end

    test "评分规则格式无效或无法解析", %{user: user, form: form, form_item1: item1} do
      # insert_score_rule takes keyword list, so this is fine
      # Insert a rule with invalid format in 'rules' (items is not a list)
      insert_score_rule(form, user, rules: %{"version" => 1, "items" => "not_a_list"})
      insert_form_score(form, %{auto_score: true}) # Use map
      response = insert_response(user, form, item1) # Uses default map
      # Assuming the calculation logic will detect this and return a specific error
      # The exact error might depend on implementation, :invalid_rule_format is a placeholder
      assert {:error, _reason} = Scoring.score_response(response.id)
      # TODO: Assert specific error like :invalid_rule_format once calculation is more robust
    end
  end

end
