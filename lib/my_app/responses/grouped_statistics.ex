defmodule MyApp.Responses.GroupedStatistics do
  @moduledoc """
  处理表单回答的分组统计功能。
  提供按回答者属性(如性别、部门等)对回答进行分组统计分析的功能。
  """

  import Ecto.Query, warn: false
  alias MyApp.Repo
  alias MyApp.Responses.Response
  alias MyApp.Responses.Answer
  alias MyApp.Forms
  alias NimbleCSV.RFC4180, as: CSV
  
  @doc """
  按回答者属性导出分组统计数据。

  ## 参数
    * `form_id` - 表单ID
    * `attribute_id` - 回答者属性ID (例如 "gender", "department")
    * `options` - 可选参数
      * `:format` - 导出格式，默认为"csv"
      * `:start_date` - 开始日期过滤
      * `:end_date` - 结束日期过滤

  ## 返回值
    * `{:ok, binary_data}` - 成功导出的CSV数据
    * `{:error, reason}` - 导出失败的原因
  """
  def export_statistics_by_attribute(form_id, attribute_id, options \\ %{}) do
    # 验证参数
    with :ok <- validate_attribute_id(attribute_id),
         {:ok, form} <- get_form(form_id),
         {:ok, responses} <- get_filtered_responses(form_id, options) do
      
      # 按指定属性分组响应
      grouped_responses = group_responses_by_attribute(responses, attribute_id)
      
      # 生成分组统计数据
      generate_grouped_statistics_csv(form, grouped_responses, attribute_id)
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  获取按回答者属性分组的统计数据，用于在UI中显示。

  ## 参数
    * `form_id` - 表单ID
    * `attribute_id` - 回答者属性ID
    * `options` - 可选参数 (如日期筛选)

  ## 返回值
    * `{:ok, grouped_stats}` - 分组统计数据
    * `{:error, reason}` - 错误原因
  """
  def get_grouped_statistics(form_id, attribute_id, options \\ %{}) do
    with :ok <- validate_attribute_id(attribute_id),
         {:ok, form} <- get_form(form_id),
         {:ok, responses} <- get_filtered_responses(form_id, options) do
      
      # 按属性分组响应
      grouped_responses = group_responses_by_attribute(responses, attribute_id)
      
      # 处理分组数据
      results = 
        Enum.map(grouped_responses, fn {attribute_value, group_responses} ->
          # 获取每个表单项的统计数据
          item_stats = calculate_item_statistics(form, group_responses)
          
          %{
            attribute_value: attribute_value,
            count: length(group_responses),
            item_statistics: item_stats
          }
        end)
      
      {:ok, results}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  # 验证属性ID是否有效
  defp validate_attribute_id(attribute_id) when is_binary(attribute_id), do: :ok
  defp validate_attribute_id(_), do: {:error, :invalid_attribute_id}
  
  # 获取表单与其表单项
  defp get_form(form_id) do
    case Forms.get_form_with_items(form_id) do
      nil -> {:error, :form_not_found}
      form -> {:ok, form}
    end
  end
  
  # 获取按日期筛选的响应
  defp get_filtered_responses(form_id, options) do
    # 构建查询
    query = from(r in Response, where: r.form_id == ^form_id)
    
    # 添加日期筛选
    query = apply_date_filters(query, options)
    
    # 执行查询与预加载
    responses = Repo.all(query)
                |> Repo.preload(answers: from(a in Answer, order_by: a.id), 
                               form: [pages: [items: :options], items: :options])
    
    {:ok, responses}
  end
  
  # 应用日期筛选
  defp apply_date_filters(query, options) do
    query
    |> maybe_filter_by_start_date(options[:start_date])
    |> maybe_filter_by_end_date(options[:end_date])
    |> order_by([r], desc: r.submitted_at)
  end
  
  # 如果提供了开始日期，添加过滤条件
  defp maybe_filter_by_start_date(query, nil), do: query
  defp maybe_filter_by_start_date(query, start_date) do
    start_datetime = date_to_datetime(start_date, :start_of_day)
    from(r in query, where: r.submitted_at >= ^start_datetime)
  end
  
  # 如果提供了结束日期，添加过滤条件
  defp maybe_filter_by_end_date(query, nil), do: query
  defp maybe_filter_by_end_date(query, end_date) do
    end_datetime = date_to_datetime(end_date, :end_of_day)
    from(r in query, where: r.submitted_at <= ^end_datetime)
  end
  
  # 将日期转换为日期时间
  defp date_to_datetime(date, time_option \\ :start_of_day) do
    time = 
      case time_option do
        :start_of_day -> ~T[00:00:00]
        :end_of_day -> ~T[23:59:59]
      end
    
    case date do
      %Date{} -> 
        DateTime.new!(date, time, "Etc/UTC")
      date_string when is_binary(date_string) ->
        {:ok, date} = Date.from_iso8601(date_string)
        DateTime.new!(date, time, "Etc/UTC")
    end
  end
  
  # 按属性对响应进行分组
  defp group_responses_by_attribute(responses, attribute_id) do
    responses
    |> Enum.group_by(fn response ->
      # 从respondent_info中获取指定属性值
      get_attribute_value(response.respondent_info, attribute_id)
    end)
  end
  
  # 从respondent_info中获取属性值，处理各种边缘情况
  defp get_attribute_value(nil, _), do: "未指定"
  defp get_attribute_value(respondent_info, attribute_id) do
    case Map.get(respondent_info, attribute_id) do
      nil -> "未指定"
      "" -> "未指定"
      value -> value
    end
  end
  
  # 计算每个表单项的统计数据
  defp calculate_item_statistics(form, group_responses) do
    # 获取表单项
    form_items = 
      form.pages
      |> Enum.flat_map(& &1.items)
      |> Enum.sort_by(& &1.order)
    
    # 为每个表单项计算统计数据
    Enum.map(form_items, fn item ->
      case item.type do
        :radio -> 
          {item.id, calculate_choice_statistics(item, group_responses, :single)}
        :checkbox -> 
          {item.id, calculate_choice_statistics(item, group_responses, :multiple)}
        :rating -> 
          {item.id, calculate_rating_statistics(item, group_responses)}
        :text_input -> 
          {item.id, calculate_text_statistics(item, group_responses)}
        _ -> 
          {item.id, %{type: item.type, stats: nil}}
      end
    end)
    |> Enum.into(%{})
  end
  
  # 计算选择题统计数据 (单选或多选)
  defp calculate_choice_statistics(item, responses, selection_type) do
    # 获取所有选项
    options = Enum.sort_by(item.options, & &1.order)
    
    # 初始化每个选项的计数
    initial_counts = Enum.reduce(options, %{}, fn opt, acc -> 
      Map.put(acc, opt.id, 0) 
    end)
    
    # 统计各选项的选择次数
    counts = 
      responses
      |> Enum.reduce(initial_counts, fn response, acc ->
        # 找到相关答案
        answer = Enum.find(response.answers, fn a -> a.form_item_id == item.id end)
        
        if answer do
          value = answer.value["value"]
          
          case selection_type do
            :single ->
              # 单选题 - 增加选中选项的计数
              if value && Map.has_key?(acc, value) do
                Map.update!(acc, value, &(&1 + 1))
              else
                acc
              end
            
            :multiple ->
              # 多选题 - 增加所有选中选项的计数
              if is_list(value) do
                Enum.reduce(value, acc, fn opt_id, inner_acc ->
                  if Map.has_key?(inner_acc, opt_id) do
                    Map.update!(inner_acc, opt_id, &(&1 + 1))
                  else
                    inner_acc
                  end
                end)
              else
                acc
              end
          end
        else
          acc
        end
      end)
    
    # 计算总选择次数与百分比
    total_count = Enum.sum(Map.values(counts))
    
    # 生成选项统计数据
    options_stats = 
      options
      |> Enum.map(fn opt ->
        count = Map.get(counts, opt.id, 0)
        percentage = if total_count > 0, do: count / total_count * 100, else: 0
        
        %{
          option_id: opt.id,
          option_label: opt.label,
          count: count,
          percentage: Float.round(percentage, 1)
        }
      end)
    
    # 返回统计结果
    %{
      type: if(selection_type == :single, do: :radio, else: :checkbox),
      item_label: item.label,
      total_count: total_count,
      options: options_stats
    }
  end
  
  # 计算评分题统计数据
  defp calculate_rating_statistics(item, responses) do
    # 提取评分值
    ratings = 
      responses
      |> Enum.map(fn response ->
        answer = Enum.find(response.answers, fn a -> a.form_item_id == item.id end)
        if answer, do: parse_rating_value(answer.value["value"]), else: nil
      end)
      |> Enum.reject(&is_nil/1)
    
    # 计算基础统计量
    count = length(ratings)
    
    stats = 
      if count > 0 do
        sum = Enum.sum(ratings)
        avg = sum / count
        min = Enum.min(ratings, fn -> 0 end)
        max = Enum.max(ratings, fn -> 0 end)
        
        # 计算评分分布
        max_rating = item.max_rating || 5
        distribution = 
          Enum.reduce(1..max_rating, %{}, fn i, acc -> 
            Map.put(acc, i, 0) 
          end)
        
        distribution = 
          Enum.reduce(ratings, distribution, fn rating, acc ->
            Map.update!(acc, rating, &(&1 + 1))
          end)
        
        # 计算每个评分的百分比
        distribution_with_percentage = 
          Enum.map(1..max_rating, fn rating ->
            rating_count = Map.get(distribution, rating, 0)
            percentage = if count > 0, do: rating_count / count * 100, else: 0
            
            %{
              rating: rating,
              count: rating_count,
              percentage: Float.round(percentage, 1)
            }
          end)
        
        %{
          count: count,
          avg: Float.round(avg, 1),
          min: min,
          max: max,
          distribution: distribution_with_percentage
        }
      else
        %{
          count: 0,
          avg: 0,
          min: 0,
          max: 0,
          distribution: []
        }
      end
    
    # 返回统计结果
    %{
      type: :rating,
      item_label: item.label,
      stats: stats
    }
  end
  
  # 解析评分值
  defp parse_rating_value(value) when is_integer(value), do: value
  defp parse_rating_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, _} -> int_value
      :error -> nil
    end
  end
  defp parse_rating_value(_), do: nil
  
  # 计算文本题统计数据
  defp calculate_text_statistics(item, responses) do
    # 统计非空回答
    text_answers = 
      responses
      |> Enum.map(fn response ->
        answer = Enum.find(response.answers, fn a -> a.form_item_id == item.id end)
        if answer, do: answer.value["value"], else: nil
      end)
      |> Enum.reject(&is_text_empty?/1)
    
    # 计算统计量
    answered_count = length(text_answers)
    total_count = length(responses)
    response_rate = if total_count > 0, do: answered_count / total_count * 100, else: 0
    
    # 返回统计结果
    %{
      type: :text_input,
      item_label: item.label,
      stats: %{
        answered_count: answered_count,
        total_count: total_count,
        response_rate: Float.round(response_rate, 1)
      }
    }
  end
  
  # 检查文本是否为空
  defp is_text_empty?(nil), do: true
  defp is_text_empty?(""), do: true
  defp is_text_empty?(text) when is_binary(text), do: String.trim(text) == ""
  defp is_text_empty?(_), do: false
  
  # 生成分组统计CSV
  defp generate_grouped_statistics_csv(form, grouped_responses, attribute_id) do
    # 获取表单项
    form_items = 
      form.pages
      |> Enum.flat_map(& &1.items)
      |> Enum.sort_by(& &1.order)
    
    # 创建CSV头
    csv_data = [
      ["表单标题:", form.title],
      ["分组属性:", attribute_id],
      []
    ]
    
    # 为每个分组生成统计数据
    csv_data = 
      Enum.reduce(grouped_responses, csv_data, fn {group_value, group_responses}, acc ->
        # 添加分组标题
        group_header = [
          [],
          ["#{attribute_id}:", "#{group_value}"],
          ["回答数量:", "#{length(group_responses)}"],
          []
        ]
        
        # 为该分组内的每个表单项生成统计
        group_stats = 
          Enum.reduce(form_items, [], fn item, item_acc ->
            case item.type do
              :radio -> 
                item_acc ++ generate_choice_statistics_for_group(item, group_responses, "单选题")
              :checkbox -> 
                item_acc ++ generate_choice_statistics_for_group(item, group_responses, "多选题")
              :rating -> 
                item_acc ++ generate_rating_statistics_for_group(item, group_responses)
              :text_input -> 
                item_acc ++ generate_text_statistics_for_group(item, group_responses)
              _ -> 
                item_acc
            end
          end)
        
        # 合并该分组的所有统计数据
        acc ++ group_header ++ group_stats
      end)
    
    # 转换为CSV字符串
    csv_string = CSV.dump_to_iodata(csv_data) |> IO.iodata_to_binary()
    {:ok, csv_string}
  end
  
  # 为分组生成选择题统计
  defp generate_choice_statistics_for_group(item, group_responses, item_type) do
    # 获取选项
    options = Enum.sort_by(item.options, & &1.order)
    
    # 统计选项分布
    option_counts = count_option_selections(item, group_responses, options)
    
    # 计算总回答数和百分比
    total_responses = Enum.sum(Map.values(option_counts))
    
    if total_responses > 0 do
      # 生成CSV行
      [
        [""],
        ["#{item_type}:", item.label],
        ["选项", "回答数量", "百分比"]
      ] ++
      Enum.map(options, fn option ->
        count = Map.get(option_counts, option.id, 0)
        percentage = if total_responses > 0, do: count / total_responses * 100, else: 0
        [option.label, "#{count}", "#{Float.round(percentage, 1)}%"]
      end) ++
      [["总计", "#{total_responses}", "100%"]]
    else
      [
        [""],
        ["#{item_type}:", item.label],
        ["无回答数据"]
      ]
    end
  end
  
  # 统计选项选择
  defp count_option_selections(item, responses, options) do
    # 初始化选项计数
    initial_counts = Enum.reduce(options, %{}, fn opt, acc -> 
      Map.put(acc, opt.id, 0) 
    end)
    
    # 计算每个选项的选择次数
    Enum.reduce(responses, initial_counts, fn response, acc ->
      # 找到回答
      answer = Enum.find(response.answers, fn a -> a.form_item_id == item.id end)
      
      if answer do
        value = answer.value["value"]
        
        case item.type do
          :radio ->
            # 单选题 - 增加选中选项的计数
            if value && Map.has_key?(acc, value) do
              Map.update!(acc, value, &(&1 + 1))
            else
              acc
            end
          
          :checkbox ->
            # 多选题 - 增加所有选中选项的计数
            if is_list(value) do
              Enum.reduce(value, acc, fn opt_id, inner_acc ->
                if Map.has_key?(inner_acc, opt_id) do
                  Map.update!(inner_acc, opt_id, &(&1 + 1))
                else
                  inner_acc
                end
              end)
            else
              acc
            end
            
          _ -> acc
        end
      else
        acc
      end
    end)
  end
  
  # 为分组生成评分题统计
  defp generate_rating_statistics_for_group(item, group_responses) do
    # 获取所有评分值
    ratings = 
      group_responses
      |> Enum.map(fn response ->
        answer = Enum.find(response.answers, fn a -> a.form_item_id == item.id end)
        if answer, do: parse_rating_value(answer.value["value"]), else: nil
      end)
      |> Enum.reject(&is_nil/1)
    
    # 计算统计量
    count = length(ratings)
    
    if count > 0 do
      sum = Enum.sum(ratings)
      avg = sum / count
      min = Enum.min(ratings, fn -> 0 end)
      max = Enum.max(ratings, fn -> 0 end)
      
      # 计算评分分布
      max_rating = item.max_rating || 5
      distribution = 
        Enum.reduce(1..max_rating, %{}, fn i, acc -> 
          Map.put(acc, i, 0) 
        end)
      
      distribution = 
        Enum.reduce(ratings, distribution, fn rating, acc ->
          Map.update!(acc, rating, &(&1 + 1))
        end)
      
      # 生成CSV行
      [
        [""],
        ["评分题:", item.label],
        ["统计指标", "值"],
        ["回答数量", "#{count}"],
        ["平均分", "#{Float.round(avg, 1)}"],
        ["最低分", "#{min}"],
        ["最高分", "#{max}"],
        [""],
        ["评分", "回答数量", "百分比"]
      ] ++
      Enum.map(1..max_rating, fn rating ->
        rating_count = Map.get(distribution, rating, 0)
        percentage = if count > 0, do: rating_count / count * 100, else: 0
        ["#{rating}", "#{rating_count}", "#{Float.round(percentage, 1)}%"]
      end)
    else
      [
        [""],
        ["评分题:", item.label],
        ["无回答数据"]
      ]
    end
  end
  
  # 为分组生成文本题统计
  defp generate_text_statistics_for_group(item, group_responses) do
    # 统计非空回答
    text_answers = 
      group_responses
      |> Enum.map(fn response ->
        answer = Enum.find(response.answers, fn a -> a.form_item_id == item.id end)
        if answer, do: answer.value["value"], else: nil
      end)
      |> Enum.reject(&is_text_empty?/1)
    
    # 计算统计量
    answered_count = length(text_answers)
    total_count = length(group_responses)
    response_rate = if total_count > 0, do: answered_count / total_count * 100, else: 0
    
    # 生成CSV行
    [
      [""],
      ["文本题:", item.label],
      ["回答数量", "#{answered_count}"],
      ["总回答数", "#{total_count}"],
      ["回答率", "#{Float.round(response_rate, 1)}%"]
    ]
  end
end