defmodule MyApp.Scoring.ScoreRuleTest do
  use MyApp.DataCase, async: true

  alias MyApp.Scoring.ScoreRule
  alias MyApp.Factory # Assuming ExMachina factory module

  describe "changeset/2" do
    test "valid changeset for creating a score rule" do
      form = Factory.insert(:form)
      user = Factory.insert(:user)

      valid_attrs = %{
        name: "测试规则",
        description: "一个有效的测试规则",
        rules: %{
          "version" => 1,
          "type" => "automatic",
          "items" => [%{"item_id" => "item-uuid-1", "max_score" => 10}]
        },
        max_score: 100,
        is_active: true,
        form_id: form.id,
        user_id: user.id
      }

      changeset = ScoreRule.changeset(%ScoreRule{}, valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset when missing required fields" do
      # Missing name, rules, form_id
      invalid_attrs = %{
        description: "无效规则",
        max_score: 50
      }

      changeset = ScoreRule.changeset(%ScoreRule{}, invalid_attrs)
      refute changeset.valid?
      assert errors_on(changeset) |> Keyword.has_key?(:name)
      assert errors_on(changeset) |> Keyword.has_key?(:rules)
      assert errors_on(changeset) |> Keyword.has_key?(:form_id)
    end

    test "invalid changeset with non-positive max_score" do
      form = Factory.insert(:form)
      invalid_attrs = %{
        name: "无效规则",
        rules: %{"version" => 1, "items" => []},
        form_id: form.id,
        max_score: 0
      }

      changeset = ScoreRule.changeset(%ScoreRule{}, invalid_attrs)
      refute changeset.valid?
      assert errors_on(changeset) |> Keyword.get(:max_score) == ["must be greater than 0"]
    end

    test "invalid changeset with invalid rules format (not a map)" do
      form = Factory.insert(:form)
       invalid_attrs = %{
        name: "无效规则",
        rules: "not a map",
        max_score: 100,
        form_id: form.id
      }

      changeset = ScoreRule.changeset(%ScoreRule{}, invalid_attrs)
      refute changeset.valid?
      assert errors_on(changeset) |> Keyword.get(:rules) == ["评分规则必须是JSON对象"]
    end

     test "invalid changeset with invalid rules structure (missing 'items')" do
      form = Factory.insert(:form)
      invalid_attrs = %{
        name: "无效规则",
        rules: %{"version" => 1}, # Missing "items" key
        max_score: 100,
        form_id: form.id
      }
      changeset = ScoreRule.changeset(%ScoreRule{}, invalid_attrs)
      refute changeset.valid?
      # Note: The exact error message depends on the implementation of validate_rules_format/1
      assert errors_on(changeset) |> Keyword.get(:rules) == ["评分规则格式无效"]
    end

    test "invalid changeset with non-existent form_id" do
       non_existent_form_id = Ecto.UUID.generate()
       attrs = %{
        name: "测试规则",
        rules: %{"version" => 1, "items" => []},
        max_score: 100,
        form_id: non_existent_form_id
      }
      changeset = ScoreRule.changeset(%ScoreRule{}, attrs)
      # Foreign key constraints are usually checked at the Repo level,
      # but the changeset marks it for checking.
      assert errors_on(changeset) |> Keyword.has_key?(:form_id)
    end

    test "invalid changeset with non-existent user_id" do
      form = Factory.insert(:form)
      non_existent_user_id = Ecto.UUID.generate()
      attrs = %{
        name: "测试规则",
        rules: %{"version" => 1, "items" => []},
        max_score: 100,
        form_id: form.id,
        user_id: non_existent_user_id
      }
      changeset = ScoreRule.changeset(%ScoreRule{}, attrs)
      # Foreign key constraints are usually checked at the Repo level,
      # but the changeset marks it for checking.
      assert errors_on(changeset) |> Keyword.has_key?(:user_id)
    end
  end
end
