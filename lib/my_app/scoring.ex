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
  alias MyApp.Scoring.ResponseScore # Added alias

  alias MyApp.Forms # Assuming Forms context exists
  alias MyApp.Forms.Form # Added alias
  # alias MyApp.Forms.FormItem # Added alias - REMOVE
  alias MyApp.Responses.Response # Added alias
  # alias MyApp.Responses.Answer # Added alias - REMOVE
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
  返回一个用于创建或修改评分规则的 changeset。
  """
  def change_score_rule(%ScoreRule{} = score_rule, attrs \\ %{}) do
    ScoreRule.changeset(score_rule, attrs)
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

  @doc """
  Calculates the score for a given response based on the form's scoring rule
  and saves the result as a ResponseScore record.

  Returns `{:ok, response_score}` on success,
  or `{:error, reason}` if scoring cannot be performed.
  Reasons include: :response_not_found, :already_scored, :score_rule_not_found,
  :form_score_config_not_found, :auto_score_disabled, :calculation_error, etc.
  """
  def score_response(response_id) do
    # Preload data needed for calculation and validation, but not the non-existent response_scores assoc
    preload_query = from r in Response, where: r.id == ^response_id
    response = Repo.get(preload_query, response_id)
               |> Repo.preload([:form, answers: :form_item]) # Removed response_scores preload

    # Pass response_id to handle_already_scored
    with {:ok, response} <- handle_response_found(response),
         :ok <- handle_already_scored(response.id),
         {:ok, form} <- handle_form_association(response),
         {:ok, score_rule} <- find_score_rule(form.id),
         {:ok, form_config} <- find_form_score_config(form.id),
         :ok <- check_auto_score_enabled(form_config) do

      # --- Actual calculation logic --- START ---
      # Validate rule format before proceeding
      with {:ok, rule_items} <- validate_rule_items_format(score_rule.rules) do
        answers_map = Map.new(response.answers, fn answer -> {answer.form_item_id, answer} end)

        calculated_score = Enum.reduce(rule_items, 0, fn item, acc ->
          item_id = item["item_id"]
          scoring_method = item["scoring_method"]
          correct_answer = item["correct_answer"]
          score_value = item["score"] || 0 # Default to 0 if score is missing

          case {Map.get(answers_map, item_id), scoring_method} do
            # Found answer and method is exact_match
            {%{value: user_answer_value}, "exact_match"} ->
              if user_answer_value == correct_answer do
                acc + score_value
              else
                acc # No points if answer doesn't match
              end
            # TODO: Handle other scoring methods
            # Answer not found for this item_id, or unknown scoring method
            _ ->
              acc # No points for this item
          end
        end)

        # Use the rule's max_score as defined in the rule itself
        calculated_max_score = score_rule.max_score
        scored_at_time = DateTime.utc_now() |> DateTime.truncate(:second)
        score_details_map = %{} # TODO: Populate score details later
        # --- Actual calculation logic --- END ---

        # Prepare attributes for ResponseScore
        response_score_attrs = %{
          response_id: response.id,
          score_rule_id: score_rule.id,
          score: calculated_score,
          max_score: calculated_max_score,
          scored_at: scored_at_time,
          score_details: score_details_map
        }

        # Create and insert the ResponseScore
        %ResponseScore{}
        |> ResponseScore.changeset(response_score_attrs)
        |> Repo.insert()
      else
         # Error from validate_rule_items_format
         {:error, reason} -> {:error, reason}
      end
    else
      # If any check in the outer `with` block fails, return the error
      {:error, reason} -> {:error, reason}
    end
  end

  # --- score_response Helper Functions --- START ---
  defp handle_response_found(nil), do: {:error, :response_not_found}
  defp handle_response_found(response), do: {:ok, response}

  # Check if ResponseScore already exists by querying directly
  defp handle_already_scored(response_id) do
    case Repo.get_by(ResponseScore, response_id: response_id) do
      nil -> :ok # Not scored yet
      _ -> {:error, :already_scored}
    end
  end

  # Check if form association is loaded (should be if response exists)
  defp handle_form_association(%Response{form: %Form{}} = response), do: {:ok, response.form}
  defp handle_form_association(_response), do: {:error, :form_not_found} # Or internal error

  # Find the active scoring rule for the form (assuming only one for now)
  # TODO: Add logic if multiple rules are possible
  defp find_score_rule(form_id) do
    case Repo.get_by(ScoreRule, form_id: form_id, is_active: true) do
      nil -> {:error, :score_rule_not_found}
      rule -> {:ok, rule}
    end
  end

  # Find the form score configuration
  defp find_form_score_config(form_id) do
    case get_form_score_config(form_id) do # Reuse existing function
      nil -> {:error, :form_score_config_not_found}
      config -> {:ok, config}
    end
  end

  # Check if auto scoring is enabled
  defp check_auto_score_enabled(%FormScore{auto_score: true}), do: :ok
  defp check_auto_score_enabled(_form_config), do: {:error, :auto_score_disabled}

  # Validate that the 'items' key in rules exists and is a list
  defp validate_rule_items_format(%{"items" => items}) when is_list(items), do: {:ok, items}
  defp validate_rule_items_format(_rules), do: {:error, :invalid_rule_format}
  # --- score_response Helper Functions --- END ---

  # === Response Score Queries ===
  
  @doc """
  获取指定表单下所有响应的评分结果列表。
  
  返回包含响应信息和评分信息的列表。
  """
  def get_response_scores_for_form(form_id) do
    query = from rs in ResponseScore,
            join: r in Response, on: rs.response_id == r.id,
            where: r.form_id == ^form_id,
            preload: [response: r]
            
    Repo.all(query)
  end
  
  @doc """
  获取单个响应的评分结果。
  
  返回 `{:ok, response_score}` 或 `{:error, :not_found}`。
  """
  def get_response_score_for_response(response_id) do
    case Repo.get_by(ResponseScore, response_id: response_id) do
      nil -> {:error, :not_found}
      response_score -> 
        response_score = response_score |> Repo.preload(:response)
        {:ok, response_score}
    end
  end
  
  @doc """
  获取表单信息，主要用于检查权限和显示表单标题等信息。
  """
  def get_form(form_id) do
    Forms.get_form(form_id)
  end
  
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
