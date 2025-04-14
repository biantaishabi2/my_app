defmodule MyApp.Repo.Migrations.CreateScoringSystemTables do
  use Ecto.Migration

  def change do
    # 创建评分规则表
    create table(:scoring_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :rules, :map, null: false
      add :max_score, :integer, null: false
      add :is_active, :boolean, default: true, null: false

      add :form_id, references(:forms, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :bigint)

      timestamps()
    end

    create index(:scoring_rules, [:form_id])
    create index(:scoring_rules, [:user_id])

    # 创建表单评分配置表
    create table(:form_scores, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :total_score, :integer, null: false
      add :passing_score, :integer
      add :score_visibility, :string # Consider using :enum type if your DB supports it
      add :auto_score, :boolean, default: true, null: false

      add :form_id, references(:forms, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:form_scores, [:form_id])

    # 创建响应评分表
    create table(:response_scores, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :total_score, :integer, null: false
      add :passed, :boolean
      add :score_breakdown, :map
      add :feedback, :text

      add :response_id, references(:responses, type: :binary_id, on_delete: :delete_all), null: false
      add :score_rule_id, references(:scoring_rules, type: :binary_id, on_delete: :nothing)
      add :grader_id, references(:users, type: :bigint, on_delete: :nothing)

      timestamps()
    end

    create index(:response_scores, [:response_id])
    create index(:response_scores, [:score_rule_id])
    create index(:response_scores, [:grader_id])

    # It might be beneficial to add an index to query scores by form quickly via responses
    # create index(:response_scores, [:response_id, :form_id]) # Needs modification if form_id isn't directly on responses

  end
end
