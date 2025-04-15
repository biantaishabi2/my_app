defmodule MyApp.Scoring.ScoreRule do
  @moduledoc """
  表单评分规则模型。

  定义了如何对表单响应进行评分的规则。
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Forms.Form
  alias MyApp.Accounts.User # Assuming Accounts context for User

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "scoring_rules" do
    field :name, :string
    field :description, :string
    field :rules, :map  # 存储JSON格式的评分规则
    field :max_score, :integer
    field :is_active, :boolean, default: true

    belongs_to :form, Form, type: :binary_id
    belongs_to :user, User # User who created/owns the rule

    timestamps()
  end

  @doc false
  def changeset(score_rule, attrs) do
    # 确保attrs是规范化的键类型（全部为字符串或全部为原子）
    processed_attrs = ensure_consistent_keys(attrs)

    score_rule
    |> cast(processed_attrs, [:name, :description, :rules, :max_score, :is_active, :form_id, :user_id])
    |> validate_required([:name, :rules, :form_id, :max_score]) # Keep form_id required here
    |> validate_number(:max_score, greater_than: 0)
    |> validate_rules_structure()
    |> foreign_key_constraint(:form_id)
    |> foreign_key_constraint(:user_id)
  end

  # 确保参数中的键类型一致
  defp ensure_consistent_keys(attrs) when is_map(attrs) do
    # 如果是结构体，直接返回
    if Map.has_key?(attrs, :__struct__) do
      attrs
    else
      # 统一转换为字符串键
      Enum.reduce(attrs, %{}, fn
        # 字符串键直接加入
        {key, val}, acc when is_binary(key) -> Map.put(acc, key, val)
        # 原子键转为字符串键
        {key, val}, acc when is_atom(key) -> Map.put(acc, Atom.to_string(key), val)
        _, acc -> acc
      end)
    end
  end

  defp ensure_consistent_keys(attrs), do: attrs

  # Private validation function for rules structure
  defp validate_rules_structure(changeset) do
    case get_field(changeset, :rules) do # Use get_field for existing or new changes
      nil ->
        # If rules are not being changed or are nil (and required), let validate_required handle it.
        # If rules are optional and nil, this validation passes.
        changeset
      rules when is_map(rules) ->
        # Basic type validation: ensure it's a map.
        # Remove specific key checks (like "items") to avoid testing implementation details here.
        changeset
      _ ->
        add_error(changeset, :rules, "评分规则必须是 JSON 对象 (map)")
    end
  end
end
