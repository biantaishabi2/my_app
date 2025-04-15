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
    # 确保attrs中的键类型一致（统一使用字符串键）
    prepared_attrs =
      case attrs do
        %{__struct__: _} -> attrs  # 如果是结构体，直接使用
        _ ->
          # 规范化键类型，将所有键转换为字符串
          attrs
          |> Map.put("user_id", user.id)
          |> Map.delete(:user_id)  # 删除可能存在的原子键user_id
      end

    # First, try to build the changeset and assign the user
    changeset =
      %ScoreRule{}
      |> ScoreRule.changeset(prepared_attrs)

    # 使用get_change更安全地获取form_id
    form_id = get_field(changeset, :form_id)

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
     # 确保键类型一致（这里复用前面的逻辑）
     prepared_attrs =
       case attrs do
         %{__struct__: _} -> attrs  # 如果是结构体，直接使用
         _ ->
           # 规范化键类型，统一使用字符串键
           attrs
           |> Map.delete(:user_id)  # 删除可能存在的原子键user_id（我们不允许更新用户ID）
       end

     with true <- user_can_modify_form?(score_rule.form_id, user) do
        score_rule
        |> ScoreRule.changeset(prepared_attrs)
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
  设置表单的评分配置。创建或更新 FormScore 记录。
  该函数支持创建新的评分设置或更新现有设置。

  ## 参数
  - form_id: 需要设置评分的表单 ID
  - attrs: 包含评分配置属性的映射
  - user: 执行操作的用户，用于权限检查

  ## 返回值
  - {:ok, %FormScore{}} - 设置成功
  - {:error, changeset} - 验证错误
  - {:error, :unauthorized} - 用户无权操作
  """
  def setup_form_scoring(form_id, attrs, user) do
    require Logger
    Logger.debug("setup_form_scoring called with form_id: #{form_id}, attrs: #{inspect(attrs)}")

    with true <- user_can_modify_form?(form_id, user) do
      # 确保所有键都是字符串类型
      prepared_attrs =
        attrs
        |> Map.put("form_id", form_id)
        # 如果attrs中有:form_id，则删除它以避免混合键
        |> Map.delete(:form_id)

      Logger.debug("Prepared attrs: #{inspect(prepared_attrs)}")

      # Try to get existing config or build a new one
      case Repo.get_by(FormScore, form_id: form_id) do
        nil ->
          Logger.debug("Creating new form score config")
          # Create new config
          %FormScore{}
          |> FormScore.changeset(prepared_attrs)
          |> Repo.insert()

        existing_config ->
          Logger.debug("Updating existing form score config: #{inspect(existing_config)}")

          # 检查现有配置和新属性是否有变化
          changeset = FormScore.changeset(existing_config, prepared_attrs)

          if changeset.changes == %{} do
            # 如果没有变化，仍然返回成功但不执行数据库更新
            Logger.debug("No changes detected, returning existing config without update")
            {:ok, existing_config}
          else
            # 有变化，执行更新
            Logger.debug("Changes detected, updating config")
            changeset |> Repo.update()
          end
      end
    else
      false ->
        Logger.debug("Unauthorized access to setup_form_scoring")
        {:error, :unauthorized}
      # Handle potential {:error, reason} from user_can_modify_form?
      {:error, reason} ->
        Logger.debug("Error in user_can_modify_form?: #{inspect(reason)}")
        {:error, reason}
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
  :form_score_config_not_found, :calculation_error, etc.

  注意：自动评分无需检查auto_score_enabled，因为该检查已在调用处完成。
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
         {:ok, _form_config} <- find_form_score_config(form.id) do

      # --- Actual calculation logic --- START ---
      # Validate rule format before proceeding
      with {:ok, rule_items} <- validate_rule_items_format(score_rule.rules) do
        answers_map = Map.new(response.answers, fn answer -> {answer.form_item_id, answer} end)

        calculated_score = Enum.reduce(rule_items, 0, fn item, acc ->
          item_id = item["item_id"]
          scoring_method = item["scoring_method"]
          correct_answer = item["correct_answer"]
          score_value = String.to_integer(item["score"] || "0") # 确保是整数

          user_answer_struct = Map.get(answers_map, item_id)

          if user_answer_struct && is_map(user_answer_struct.value) do
            user_answer_value = Map.get(user_answer_struct.value, "value")
            
            # 找到对应的form_item以获取类型信息
            form_item = Enum.find(response.form.items || [], fn fi -> fi.id == item_id end)
            item_type = form_item && form_item.type
            
            points = case {item_type, scoring_method} do
              # 单选题和下拉菜单
              {type, "exact_match"} when type in [:radio, :dropdown] ->
                if to_string(user_answer_value) == to_string(correct_answer), do: score_value, else: 0
                
              # 多选题
              {:checkbox, "exact_match"} ->
                # 解析正确答案和用户答案
                correct_values = parse_checkbox_values(correct_answer)
                user_values = 
                  if is_list(user_answer_value), 
                    do: user_answer_value, 
                    else: [user_answer_value]
                    
                # 转换为字符串进行比较
                correct_set = MapSet.new(correct_values, &to_string/1)
                user_set = MapSet.new(user_values, &to_string/1)
                
                # 完全匹配才得分
                if MapSet.equal?(correct_set, user_set), do: score_value, else: 0
                
              # 填空题
              {:fill_in_blank, "exact_match"} ->
                # 解析正确答案
                correct_values = 
                  case Jason.decode(correct_answer) do
                    {:ok, values} when is_list(values) -> values
                    _ -> [correct_answer]
                  end
                  
                # 解析用户答案
                user_values = 
                  case Jason.decode(user_answer_value) do
                    {:ok, values} when is_list(values) -> values
                    _ -> [user_answer_value]
                  end
                  
                # 检查是否有单独的空位分值
                individual_scores = 
                  case item["blank_scores"] do
                    nil -> nil # 没有单独分值设置
                    scores when is_binary(scores) ->
                      case Jason.decode(scores) do
                        {:ok, values} when is_list(values) -> values
                        _ -> nil
                      end
                    _ -> nil
                  end
                
                # 根据空位单独分值或总分计算
                if is_list(individual_scores) && length(individual_scores) > 0 do
                  # 使用单独分值
                  Enum.zip([correct_values, user_values, individual_scores])
                  |> Enum.reduce(0, fn
                    {correct, user, blank_score}, acc when is_number(blank_score) ->
                      if to_string(correct) == to_string(user), do: acc + blank_score, else: acc
                    _, acc -> acc
                  end)
                else
                  # 按比例计算得分
                  correct_count = 
                    Enum.zip(correct_values, user_values)
                    |> Enum.count(fn {correct, user} -> 
                         to_string(correct) == to_string(user) 
                       end)
                       
                  total_blanks = max(length(correct_values), 1)
                  round(score_value * correct_count / total_blanks)
                end
                
              # 默认情况 - 简单文本匹配
              {_, "exact_match"} ->
                if to_string(user_answer_value) == to_string(correct_answer), do: score_value, else: 0
                
              # 其他评分方法（尚未实现）
              _ -> 0
            end
            
            acc + points
          else
            # 用户未回答此题目
            acc
          end
        end)

        # Use the rule's max_score as defined in the rule itself
        calculated_max_score = score_rule.max_score
        scored_at_time = DateTime.utc_now() |> DateTime.truncate(:second)
        
        # 构建每道题的得分详情
        score_details_map = Enum.reduce(rule_items, %{}, fn item, details_acc ->
          item_id = item["item_id"]
          scoring_method = item["scoring_method"]
          correct_answer = item["correct_answer"]
          score_value = String.to_integer(item["score"] || "0") # 确保是整数
          
          user_answer_struct = Map.get(answers_map, item_id)
          
          if user_answer_struct && is_map(user_answer_struct.value) do
            user_answer_value = Map.get(user_answer_struct.value, "value")
            
            # 找到对应的form_item以获取类型信息
            form_item = Enum.find(response.form.items || [], fn fi -> fi.id == item_id end)
            item_type = form_item && form_item.type
            
            points = case {item_type, scoring_method} do
              # 单选题和下拉菜单
              {type, "exact_match"} when type in [:radio, :dropdown] ->
                if to_string(user_answer_value) == to_string(correct_answer), do: score_value, else: 0
                
              # 多选题
              {:checkbox, "exact_match"} ->
                # 解析正确答案和用户答案
                correct_values = parse_checkbox_values(correct_answer)
                user_values = 
                  if is_list(user_answer_value), 
                    do: user_answer_value, 
                    else: [user_answer_value]
                    
                # 转换为字符串进行比较
                correct_set = MapSet.new(correct_values, &to_string/1)
                user_set = MapSet.new(user_values, &to_string/1)
                
                # 完全匹配才得分
                if MapSet.equal?(correct_set, user_set), do: score_value, else: 0
                
              # 填空题
              {:fill_in_blank, "exact_match"} ->
                # 解析正确答案
                correct_values = 
                  case Jason.decode(correct_answer) do
                    {:ok, values} when is_list(values) -> values
                    _ -> [correct_answer]
                  end
                  
                # 解析用户答案
                user_values = 
                  case Jason.decode(user_answer_value) do
                    {:ok, values} when is_list(values) -> values
                    _ -> [user_answer_value]
                  end
                  
                # 检查是否有单独的空位分值
                individual_scores = 
                  case item["blank_scores"] do
                    nil -> nil # 没有单独分值设置
                    scores when is_binary(scores) ->
                      case Jason.decode(scores) do
                        {:ok, values} when is_list(values) -> values
                        _ -> nil
                      end
                    _ -> nil
                  end
                
                # 根据空位单独分值或总分计算
                if is_list(individual_scores) && length(individual_scores) > 0 do
                  # 使用单独分值
                  Enum.zip([correct_values, user_values, individual_scores])
                  |> Enum.reduce(0, fn
                    {correct, user, blank_score}, acc when is_number(blank_score) ->
                      if to_string(correct) == to_string(user), do: acc + blank_score, else: acc
                    _, acc -> acc
                  end)
                else
                  # 按比例计算得分
                  correct_count = 
                    Enum.zip(correct_values, user_values)
                    |> Enum.count(fn {correct, user} -> 
                         to_string(correct) == to_string(user) 
                       end)
                       
                  total_blanks = max(length(correct_values), 1)
                  round(score_value * correct_count / total_blanks)
                end
                
              # 默认情况 - 简单文本匹配
              {_, "exact_match"} ->
                if to_string(user_answer_value) == to_string(correct_answer), do: score_value, else: 0
                
              # 其他评分方法（尚未实现）
              _ -> 0
            end
            
            # 将此题目的得分添加到详情map中
            Map.put(details_acc, to_string(item_id), %{
              "score" => points,
              "max_score" => score_value,
              "correct" => points > 0
            })
          else
            # 用户未回答此题目，记录为零分
            Map.put(details_acc, to_string(item_id), %{
              "score" => score_value,
              "max_score" => score_value,
              "correct" => false
            })
          end
        end)
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

  # Check if auto scoring is enabled - 保留但不在score_response主流程中使用
  # 此函数由UI界面调用时使用，自动评分流程会在调用前检查此设置
  # 使用@doc false标记以避免编译警告
  @doc false
  def check_auto_score_enabled(%FormScore{auto_score: true}), do: :ok
  @doc false
  def check_auto_score_enabled(_form_config), do: {:error, :auto_score_disabled}

  # Validate that the 'items' key in rules exists and is a list
  defp validate_rule_items_format(%{"items" => items}) when is_list(items), do: {:ok, items}
  defp validate_rule_items_format(_rules), do: {:error, :invalid_rule_format}
  
  # 解析多选题答案格式
  defp parse_checkbox_values(value) do
    cond do
      # JSON数组
      is_binary(value) && String.starts_with?(value, "[") ->
        case Jason.decode(value) do
          {:ok, values} when is_list(values) -> values
          _ -> []
        end
        
      # 逗号分隔的字符串
      is_binary(value) && String.contains?(value, ",") ->
        String.split(value, ",") |> Enum.map(&String.trim/1)
        
      # 单个值
      is_binary(value) && value != "" -> [value]
      
      # 默认情况
      true -> []
    end
  end
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
