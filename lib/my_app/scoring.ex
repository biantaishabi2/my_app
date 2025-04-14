defmodule MyApp.Scoring do
  @moduledoc """
  评分系统上下文模块。

  提供对表单响应进行评分的功能，包括评分规则设置、批量评分和评分统计等。
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias MyApp.Repo

  alias MyApp.Scoring.ScoreRule
  alias MyApp.Scoring.FormScore # Use the alias now
  # alias MyApp.Scoring.ResponseScore # Will use later

  alias MyApp.Forms # Assuming Forms context exists
  # alias MyApp.Accounts # Assuming Accounts context exists

  # === Score Rule Management ===

  @doc """
  创建评分规则。
  需要检查调用用户是否有权限对该表单创建规则。
  """
  def create_score_rule(attrs, user) do
    # First, try to build the changeset and assign the user
    changeset =
      %ScoreRule{}
      |> ScoreRule.changeset(Map.put(attrs, :user_id, user.id))

    # Check if changeset is valid *before* checking permissions,
    # but extract form_id first for the check.
    form_id = get_field(changeset, :form_id) # Use get_field to handle potential nil

    # Decide the next step based on form_id presence and changeset validity
    case {form_id, changeset.valid?} do
      {nil, _} ->
        # If form_id is missing (and required), changeset is invalid. Return it.
        {:error, changeset}

      {form_id_present, true} ->
        # If form_id is present and changeset is initially valid, check permissions
        case user_can_modify_form?(form_id_present, user) do
          true -> Repo.insert(changeset) # Permissions pass, insert
          false -> {:error, :unauthorized} # Permissions fail
          {:error, reason} -> {:error, reason} # Other error from permission check
        end

      {_, false} ->
        # If form_id was present but changeset became invalid for other reasons
        {:error, changeset}
    end
  end

  @doc """
  获取表单的所有评分规则。
  """
  def get_score_rules_for_form(form_id) do
    ScoreRule
    |> where([r], r.form_id == ^form_id)
    |> Repo.all()
  end

  @doc """
  获取评分规则详情。
  """
  def get_score_rule(id) do
    case Repo.get(ScoreRule, id) do
      nil -> {:error, :not_found}
      rule -> {:ok, rule}
    end
  end

  @doc """
  更新评分规则。
  需要检查用户是否有权限修改此规则 (通常基于表单所有权)。
  """
  def update_score_rule(%ScoreRule{} = score_rule, attrs, user) do
     with true <- user_can_modify_form?(score_rule.form_id, user) do
        score_rule
        |> ScoreRule.changeset(attrs)
        |> Repo.update()
     else
        false -> {:error, :unauthorized}
        _ -> {:error, :form_not_found}
     end
  end

  @doc """
  删除评分规则。
  需要检查用户是否有权限删除此规则 (通常基于表单所有权)。
  """
  def delete_score_rule(%ScoreRule{} = score_rule, user) do
    with true <- user_can_modify_form?(score_rule.form_id, user) do
      Repo.delete(score_rule, [allow_stale: true])
    else
       false -> {:error, :unauthorized}
       _ -> {:error, :form_not_found}
    end
  end

  # === Form Score Configuration ===

  @doc """
  Sets up or updates the scoring configuration for a form.

  Requires the user to own the form.
  Performs an upsert operation.
  """
  def setup_form_scoring(form_id, attrs, user) do
    with true <- user_can_modify_form?(form_id, user) do
      # Prepare attributes, ensuring form_id is set
      prepared_attrs = Map.put(attrs, :form_id, form_id)

      # Try to get existing config or build a new one
      case Repo.get_by(FormScore, form_id: form_id) do
        nil ->
          # Create new config
          %FormScore{}
          |> FormScore.changeset(prepared_attrs)
          |> Repo.insert()
        existing_config ->
          # Update existing config
          existing_config
          |> FormScore.changeset(prepared_attrs)
          |> Repo.update()
      end
    else
      false -> {:error, :unauthorized}
      # Handle potential {:error, reason} from user_can_modify_form?
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets the scoring configuration for a form.
  Returns the FormScore struct or nil if not found.
  """
  def get_form_score_config(form_id) do
    Repo.get_by(FormScore, form_id: form_id)
  end

  # === Response Scoring ===
  # (To be implemented later)

  # === Statistics ===
  # (To be implemented later)

  # --- Helper Functions ---

  # Checks if a user can modify a given form (owns it)
  defp user_can_modify_form?(nil, _user), do: false # Handle nil form_id directly
  defp user_can_modify_form?(form_id, user) do
    case Forms.get_form(form_id) do # Assuming Forms context has get_form/1
      nil -> false # Form not found
      form -> form.user_id == user.id
    end
  end

end
