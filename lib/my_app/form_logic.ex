defmodule MyApp.FormLogic do
  @moduledoc """
  处理表单条件逻辑的模块。

  提供了创建、评估表单条件的功能，用于实现表单项的条件显示、条件验证等功能。

  条件逻辑支持简单条件（如：性别=男，年龄>=18）和复合条件（如：AND、OR组合）。
  同时支持条件嵌套，可以构建复杂的条件判断树。
  """

  # 实际代码中没有使用以下别名，但为了可能的未来扩展保留注释
  # alias MyApp.Forms
  # alias MyApp.Forms.FormItem

  @doc """
  创建一个简单条件。

  ## 参数
    - source_item_id: 条件源表单项ID，即条件判断依据的表单项
    - operator: 条件操作符，如 "equals", "not_equals", "greater_than" 等
    - value: 用于比较的目标值
    
  ## 返回值
    包含条件信息的结构体
  """
  def build_condition(source_item_id, operator, value) do
    %{
      type: :simple,
      source_item_id: source_item_id,
      operator: operator,
      value: value
    }
  end

  @doc """
  创建一个复合条件。

  ## 参数
    - operator: 复合条件操作符，如 "and", "or"
    - conditions: 子条件列表，可以是简单条件或其他复合条件
    
  ## 返回值
    包含复合条件信息的结构体
  """
  def build_compound_condition(operator, conditions) do
    %{
      type: :compound,
      operator: operator,
      conditions: conditions
    }
  end

  @doc """
  评估条件是否满足。

  ## 参数
    - condition: 条件结构体，可以是简单条件或复合条件
    - form_data: 表单数据，格式为 %{"form_item_id" => "value"}
    
  ## 返回值
    布尔值，表示条件是否满足
  """
  def evaluate_condition(condition, form_data) do
    case condition do
      %{type: :simple} = simple_condition ->
        evaluate_simple_condition(simple_condition, form_data)

      %{type: :compound, operator: operator, conditions: conditions} ->
        evaluate_compound_condition(operator, conditions, form_data)

      # 处理字符串键的条件（从JSON解码后）
      %{"type" => "simple"} = simple_condition ->
        simple_condition = atomize_keys(simple_condition)
        evaluate_simple_condition(simple_condition, form_data)

      %{"type" => "compound", "operator" => operator, "conditions" => conditions} ->
        atomized_conditions = Enum.map(conditions, &atomize_keys/1)
        evaluate_compound_condition(operator, atomized_conditions, form_data)
    end
  end

  @doc """
  判断表单项是否应该显示，基于其可见性条件。

  ## 参数
    - form_item: 表单项结构体
    - form_data: 表单数据，格式为 %{"form_item_id" => "value"}
    
  ## 返回值
    布尔值，表示表单项是否应该显示
  """
  def should_show_item?(form_item, form_data) do
    cond do
      # 没有可见性条件，默认显示
      is_nil(form_item.visibility_condition) ->
        true

      # 有可见性条件，评估条件是否满足
      true ->
        condition = Jason.decode!(form_item.visibility_condition)
        evaluate_condition(condition, form_data)
    end
  end

  @doc """
  判断表单项是否是必填的，基于其必填条件。

  ## 参数
    - form_item: 表单项结构体
    - form_data: 表单数据，格式为 %{"form_item_id" => "value"}
    
  ## 返回值
    布尔值，表示表单项是否是必填的
  """
  def is_item_required?(form_item, form_data) do
    cond do
      # 原本就是必填的，并且没有条件必填规则
      form_item.required && is_nil(form_item.required_condition) ->
        true

      # 有条件必填规则，评估条件是否满足
      not is_nil(form_item.required_condition) ->
        condition = Jason.decode!(form_item.required_condition)
        evaluate_condition(condition, form_data)

      # 默认不是必填的
      true ->
        false
    end
  end

  # 私有函数：评估简单条件
  defp evaluate_simple_condition(
         %{source_item_id: source_item_id, operator: operator, value: target_value},
         form_data
       ) do
    # 获取表单数据中的值
    actual_value = Map.get(form_data, "#{source_item_id}")

    # 如果值不存在，则条件不满足
    if is_nil(actual_value) do
      false
    else
      # 根据操作符评估条件
      case operator do
        "equals" ->
          actual_value == to_string(target_value)

        "not_equals" ->
          actual_value != to_string(target_value)

        "greater_than" ->
          # 尝试转换为数字进行比较
          with {actual_num, _} <- Integer.parse(actual_value),
               target_num when is_number(target_num) <- target_value do
            actual_num > target_num
          else
            _ -> false
          end

        "greater_than_or_equal" ->
          # 尝试转换为数字进行比较
          with {actual_num, _} <- Integer.parse(actual_value),
               target_num when is_number(target_num) <- target_value do
            actual_num >= target_num
          else
            _ -> false
          end

        "less_than" ->
          # 尝试转换为数字进行比较
          with {actual_num, _} <- Integer.parse(actual_value),
               target_num when is_number(target_num) <- target_value do
            actual_num < target_num
          else
            _ -> false
          end

        "less_than_or_equal" ->
          # 尝试转换为数字进行比较
          with {actual_num, _} <- Integer.parse(actual_value),
               target_num when is_number(target_num) <- target_value do
            actual_num <= target_num
          else
            _ -> false
          end

        "contains" ->
          String.contains?(actual_value, to_string(target_value))

        _ ->
          # 未知操作符，默认返回false
          false
      end
    end
  end

  # 私有函数：评估复合条件
  defp evaluate_compound_condition(operator, conditions, form_data) do
    # 对每个子条件进行评估
    results = Enum.map(conditions, &evaluate_condition(&1, form_data))

    # 根据操作符组合结果
    case operator do
      "and" ->
        # 所有子条件都必须满足
        Enum.all?(results, &(&1 == true))

      "or" ->
        # 至少有一个子条件满足
        Enum.any?(results, &(&1 == true))

      _ ->
        # 未知操作符，默认返回false
        false
    end
  end

  # 将字符串键的Map转换为原子键的Map（仅转换type, operator, conditions, source_item_id, value这几个键）
  defp atomize_keys(map) when is_map(map) do
    map
    |> Map.new(fn {k, v} ->
      key =
        case k do
          "type" -> :type
          "operator" -> :operator
          "conditions" -> :conditions
          "source_item_id" -> :source_item_id
          "value" -> :value
          _ -> k
        end

      value =
        case v do
          v when is_map(v) -> atomize_keys(v)
          v when is_list(v) -> Enum.map(v, &atomize_keys/1)
          _ -> v
        end

      {key, value}
    end)
  end

  defp atomize_keys(value), do: value
end
