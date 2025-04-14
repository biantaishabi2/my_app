defmodule MyApp.ResponsesExportTest do
  use MyApp.DataCase
  alias MyApp.Responses
  alias MyApp.Forms
  alias MyApp.Accounts

  # 测试辅助函数
  setup do
    # 创建用户
    {:ok, user} =
      Accounts.register_user(%{
        email: "test_#{System.unique_integer()}@example.com",
        password: "TestPassword123!"
      })

    # 创建含有不同类型表单项的表单
    form = setup_form_with_items(user.id)

    # 创建多个回答记录（不同时间、不同答案）
    response1 = create_test_response(form, ~U[2022-01-01 10:00:00.000000Z])
    response2 = create_test_response(form, ~U[2022-02-01 10:00:00.000000Z])
    response3 = create_test_response(form, ~U[2022-03-01 10:00:00.000000Z])

    %{form: form, responses: [response1, response2, response3], user: user}
  end

  # 创建包含多种题型的表单
  defp setup_form_with_items(user_id) do
    {:ok, form} =
      Forms.create_form(%{
        title: "测试导出表单",
        description: "用于测试导出功能的表单",
        published: true,
        user_id: user_id
      })

    # 添加单选题
    {:ok, radio_item} =
      Forms.add_form_item(form, %{
        label: "单选题",
        type: :radio,
        required: true,
        order: 1
      })

    # 添加单选题选项
    for {label, value, order} <- [{"选项A", "A", 1}, {"选项B", "B", 2}, {"选项C", "C", 3}] do
      Forms.add_item_option(radio_item, %{
        label: label,
        value: value,
        order: order
      })
    end

    # 添加多选题
    {:ok, checkbox_item} =
      Forms.add_form_item(form, %{
        label: "多选题",
        type: :checkbox,
        required: false,
        order: 2
      })

    # 添加多选题选项
    for {label, value, order} <- [{"选项X", "X", 1}, {"选项Y", "Y", 2}, {"选项Z", "Z", 3}] do
      Forms.add_item_option(checkbox_item, %{
        label: label,
        value: value,
        order: order
      })
    end

    # 添加评分题
    {:ok, _rating_item} =
      Forms.add_form_item(form, %{
        label: "评分题",
        type: :rating,
        required: true,
        order: 3,
        max_rating: 5
      })

    # 添加文本题
    {:ok, _text_item} =
      Forms.add_form_item(form, %{
        label: "文本题",
        type: :text_input,
        required: false,
        order: 4
      })

    # 重新加载表单及其关联项
    Forms.get_form_with_items(form.id)
  end

  # 创建测试回答
  defp create_test_response(form, submitted_at) do
    # 构建回答数据
    # Get form items from pages to ensure we have access to them
    form_items = form.pages |> Enum.flat_map(& &1.items) |> Enum.sort_by(& &1.order)

    answers =
      Enum.map(form_items, fn item ->
        case item.type do
          :radio ->
            options = Enum.sort_by(item.options, & &1.order)
            # 随机选择一个选项
            selected_option = Enum.random(options)
            {item.id, %{"value" => selected_option.id}}

          :checkbox ->
            options = Enum.sort_by(item.options, & &1.order)
            # 随机选择0-3个选项
            selected_options = Enum.take_random(options, :rand.uniform(4) - 1)
            {item.id, %{"value" => Enum.map(selected_options, & &1.id)}}

          :rating ->
            # 随机评分1-5
            {item.id, %{"value" => :rand.uniform(5)}}

          :text_input ->
            # 随机文本
            {item.id, %{"value" => "测试回答 #{:rand.uniform(100)}"}}

          _ ->
            {item.id, %{"value" => nil}}
        end
      end)

    # 转换为map
    answers_map = Map.new(answers)

    # 创建回答
    {:ok, response} = Responses.create_response(form.id, answers_map)

    # 更新提交时间，确保所有时间字段都有值
    # 确保时间字段类型匹配
    {:ok, updated_response} =
      Repo.update(
        Ecto.Changeset.change(response,
          submitted_at: submitted_at,
          inserted_at: DateTime.truncate(submitted_at, :microsecond),
          updated_at: DateTime.truncate(submitted_at, :microsecond)
        )
      )

    # 重新加载response及其answers
    Responses.get_response!(updated_response.id)
  end

  # 创建包含已知值的回答
  defp create_response_with_known_values(form) do
    # 获取表单项
    # Get form items from pages to ensure we have access to them
    form_items = form.pages |> Enum.flat_map(& &1.items) |> Enum.sort_by(& &1.order)
    radio_item = Enum.find(form_items, &(&1.type == :radio))
    checkbox_item = Enum.find(form_items, &(&1.type == :checkbox))
    rating_item = Enum.find(form_items, &(&1.type == :rating))
    text_item = Enum.find(form_items, &(&1.type == :text_input))

    # 获取第一个单选项选项
    radio_option = Enum.sort_by(radio_item.options, & &1.order) |> List.first()

    # 获取多选项的前两个选项
    checkbox_options = Enum.sort_by(checkbox_item.options, & &1.order) |> Enum.take(2)

    # 构建已知值的回答
    answers_map = %{
      radio_item.id => %{"value" => radio_option.id},
      checkbox_item.id => %{"value" => Enum.map(checkbox_options, & &1.id)},
      rating_item.id => %{"value" => 4},
      text_item.id => %{"value" => "这是一个已知值的测试回答"}
    }

    # 创建回答
    {:ok, response} = Responses.create_response(form.id, answers_map)

    # 重新加载response及其answers
    Responses.get_response!(response.id)
  end

  # 创建控制好的选择题回答分布
  defp create_controlled_choice_responses(form) do
    # 获取单选题
    # Get form items from pages to ensure we have access to them
    form_items = form.pages |> Enum.flat_map(& &1.items) |> Enum.sort_by(& &1.order)
    radio_item = Enum.find(form_items, &(&1.type == :radio))

    # 获取选项
    options = Enum.sort_by(radio_item.options, & &1.order)
    [option_a, option_b, option_c] = options

    # 创建10个回答，分布为5:3:2
    create_responses_with_choice(form, radio_item.id, option_a.id, 5)
    create_responses_with_choice(form, radio_item.id, option_b.id, 3)
    create_responses_with_choice(form, radio_item.id, option_c.id, 2)
  end

  # 创建指定数量的相同选择的回答
  defp create_responses_with_choice(form, item_id, option_id, count) do
    Enum.each(1..count, fn _ ->
      # 构建基本回答数据
      # Get form items from pages to ensure we have access to them
      form_items = form.pages |> Enum.flat_map(& &1.items) |> Enum.sort_by(& &1.order)

      base_answers =
        Enum.map(form_items, fn item ->
          if item.id == item_id do
            {item.id, %{"value" => option_id}}
          else
            case item.type do
              :checkbox -> {item.id, %{"value" => []}}
              :rating -> {item.id, %{"value" => 3}}
              :text_input -> {item.id, %{"value" => "测试文本"}}
              _ -> {item.id, %{"value" => nil}}
            end
          end
        end)

      # 创建回答
      Responses.create_response(form.id, Map.new(base_answers))
    end)
  end

  # 创建控制好的评分回答分布
  defp create_controlled_rating_responses(form) do
    # 获取评分题
    # Get form items from pages to ensure we have access to them
    form_items = form.pages |> Enum.flat_map(& &1.items) |> Enum.sort_by(& &1.order)
    rating_item = Enum.find(form_items, &(&1.type == :rating))

    # 创建回答，分布使得平均分为3.5
    # 例如: 2个1分, 3个2分, 5个3分, 5个4分, 5个5分 -> 平均=(2*1+3*2+5*3+5*4+5*5)/20=3.5
    create_responses_with_rating(form, rating_item.id, 1, 2)
    create_responses_with_rating(form, rating_item.id, 2, 3)
    create_responses_with_rating(form, rating_item.id, 3, 5)
    create_responses_with_rating(form, rating_item.id, 4, 5)
    create_responses_with_rating(form, rating_item.id, 5, 5)
  end

  # 创建指定数量的相同评分的回答
  defp create_responses_with_rating(form, item_id, rating, count) do
    Enum.each(1..count, fn _ ->
      # 构建基本回答数据
      # Get form items from pages to ensure we have access to them
      form_items = form.pages |> Enum.flat_map(& &1.items) |> Enum.sort_by(& &1.order)

      base_answers =
        Enum.map(form_items, fn item ->
          if item.id == item_id do
            {item.id, %{"value" => rating}}
          else
            case item.type do
              :radio ->
                option = List.first(item.options)
                {item.id, %{"value" => option.id}}

              :checkbox ->
                {item.id, %{"value" => []}}

              :text_input ->
                {item.id, %{"value" => "测试文本"}}

              _ ->
                {item.id, %{"value" => nil}}
            end
          end
        end)

      # 创建回答
      Responses.create_response(form.id, Map.new(base_answers))
    end)
  end

  # 原始数据导出测试
  describe "export_responses/2" do
    test "successfully exports all responses for a form as CSV", %{
      form: form,
      responses: responses
    } do
      result = Responses.export_responses(form.id, %{format: "csv"})

      # 验证返回二进制数据
      assert {:ok, data} = result
      assert is_binary(data)
      # 验证包含CSV头部
      assert String.contains?(data, "提交时间")
      assert String.contains?(data, "回答ID")
      # 验证所有回答都包含在导出数据中
      Enum.each(responses, fn response ->
        assert String.contains?(data, DateTime.to_string(response.submitted_at))
      end)
    end

    test "exports responses with correct answer values", %{form: form} do
      # 创建包含特定值的回答
      response = create_response_with_known_values(form)

      result = Responses.export_responses(form.id, %{format: "csv"})

      # 验证导出数据包含正确的答案值
      text_answer =
        Enum.find(response.answers, fn a ->
          # Get form items from pages to ensure we have access to them
          form_items = form.pages |> Enum.flat_map(& &1.items)
          form_item = Enum.find(form_items, &(&1.id == a.form_item_id))
          form_item.type == :text_input
        end)

      # 验证文本答案被正确导出
      assert {:ok, data} = result
      assert String.contains?(data, text_answer.value["value"])
    end

    test "handles empty response set", %{user: user} do
      # 确保没有回答数据
      {:ok, form_copy} =
        Forms.create_form(%{
          title: "无回答表单",
          description: "测试无回答数据导出",
          published: true,
          user_id: user.id
        })

      # Reload the form with all pages and items
      form_copy = Forms.get_form_with_full_preload(form_copy.id)

      result = Responses.export_responses(form_copy.id, %{format: "csv"})

      # 验证仍返回有效CSV（仅包含头部）
      assert {:ok, data} = result
      assert is_binary(data)
      assert String.contains?(data, "提交时间")
      # 验证没有回答数据行
      # 头部+空行
      assert String.split(data, "\n") |> length() <= 2
    end
  end

  # 统计数据导出测试
  describe "export_statistics/2" do
    test "successfully generates statistics for a form", %{form: form} do
      # 创建多个包含不同答案的回答
      Enum.each(1..5, fn _ -> create_test_response(form, DateTime.utc_now()) end)

      result = Responses.export_statistics(form.id, %{format: "csv"})

      # 验证返回二进制数据
      assert {:ok, data} = result
      assert is_binary(data)
      # 验证包含统计标题
      assert String.contains?(data, "回答数量")
    end

    test "correctly calculates percentages for choice questions", %{form: form} do
      # 创建已知分布的选择题回答
      create_controlled_choice_responses(form)

      result = Responses.export_statistics(form.id, %{format: "csv"})

      # 验证百分比计算正确
      assert {:ok, data} = result

      # 检查数据中是否包含单选题选项的分布
      # 打印CSV数据以便调试
      IO.puts("导出的CSV数据: #{inspect(data)}")

      # 提取各选项的数据和百分比
      option_a_match = Regex.run(~r/选项A,(\d+),(\d+\.?\d*)%/, data)
      option_b_match = Regex.run(~r/选项B,(\d+),(\d+\.?\d*)%/, data)
      option_c_match = Regex.run(~r/选项C,(\d+),(\d+\.?\d*)%/, data)

      assert option_a_match != nil
      assert option_b_match != nil
      assert option_c_match != nil

      # 转换为数字并验证比例正确 - 使用第2个捕获组（百分比）
      option_a_percent = String.to_float(Enum.at(option_a_match, 2))
      option_b_percent = String.to_float(Enum.at(option_b_match, 2))
      option_c_percent = String.to_float(Enum.at(option_c_match, 2))

      # 获取计数 - 使用第1个捕获组（回答数量）
      option_a_count = String.to_integer(Enum.at(option_a_match, 1))
      option_b_count = String.to_integer(Enum.at(option_b_match, 1))
      option_c_count = String.to_integer(Enum.at(option_c_match, 1))

      # 验证总和接近100%
      total_percent = option_a_percent + option_b_percent + option_c_percent
      assert_in_delta total_percent, 100.0, 1.0

      # 验证每个选项至少有一些回答
      assert option_a_count > 0
      assert option_b_count > 0
      assert option_c_count > 0

      # 验证总计数
      total_count = option_a_count + option_b_count + option_c_count
      assert total_count >= 10
    end

    test "correctly calculates average for rating questions", %{form: form} do
      # 创建已知评分的回答
      create_controlled_rating_responses(form)

      result = Responses.export_statistics(form.id, %{format: "csv"})

      # 验证平均分计算正确
      assert {:ok, data} = result

      # 提取平均分
      avg_match = Regex.run(~r/平均分,(\d+\.\d+)/, data)
      assert avg_match != nil
      [_, avg_str] = avg_match
      avg = String.to_float(avg_str)

      # 验证平均分在合理范围内（应该在3-4之间，基于我们的测试数据）
      assert avg >= 3.0 && avg <= 4.0
    end
  end

  # 筛选功能测试
  describe "export with filtering" do
    test "filters responses by date range", %{form: form, responses: responses} do
      # 设置过滤日期
      options = %{
        format: "csv",
        start_date: ~D[2022-01-15],
        end_date: ~D[2022-02-15]
      }

      result = Responses.export_responses(form.id, options)

      # 验证只包含日期范围内的回答
      assert {:ok, data} = result
      assert String.contains?(data, DateTime.to_string(Enum.at(responses, 1).submitted_at))
      refute String.contains?(data, DateTime.to_string(Enum.at(responses, 0).submitted_at))
      refute String.contains?(data, DateTime.to_string(Enum.at(responses, 2).submitted_at))
    end

    test "applies only start_date filter when only start_date is provided", %{
      form: form,
      responses: responses
    } do
      options = %{
        format: "csv",
        start_date: ~D[2022-02-15]
      }

      result = Responses.export_responses(form.id, options)

      # 验证只包含日期之后的回答
      assert {:ok, data} = result
      refute String.contains?(data, DateTime.to_string(Enum.at(responses, 0).submitted_at))
      refute String.contains?(data, DateTime.to_string(Enum.at(responses, 1).submitted_at))
      assert String.contains?(data, DateTime.to_string(Enum.at(responses, 2).submitted_at))
    end

    test "applies only end_date filter when only end_date is provided", %{
      form: form,
      responses: responses
    } do
      options = %{
        format: "csv",
        end_date: ~D[2022-01-15]
      }

      result = Responses.export_responses(form.id, options)

      # 验证只包含日期之前的回答
      assert {:ok, data} = result
      assert String.contains?(data, DateTime.to_string(Enum.at(responses, 0).submitted_at))
      refute String.contains?(data, DateTime.to_string(Enum.at(responses, 1).submitted_at))
      refute String.contains?(data, DateTime.to_string(Enum.at(responses, 2).submitted_at))
    end
  end

  # 错误处理测试
  describe "error handling" do
    test "returns error when form does not exist" do
      result =
        Responses.export_responses("00000000-0000-0000-0000-000000000999", %{format: "csv"})

      assert {:error, :not_found} = result
    end

    test "returns error with invalid date format" do
      # 确保先创建有效的表单
      {:ok, user} =
        Accounts.register_user(%{
          email: "test_date_#{System.unique_integer()}@example.com",
          password: "TestPassword123!"
        })

      {:ok, test_form} =
        Forms.create_form(%{
          title: "测试日期表单",
          description: "用于测试日期错误",
          published: true,
          user_id: user.id
        })

      # 确保表单正确预加载（创建至少一个页面和一个表单项）
      {:ok, _page} =
        Forms.create_form_page(test_form, %{
          title: "第一页",
          description: "测试页面",
          order: 1
        })

      # 重新获取表单确保页面已加载
      test_form = Forms.get_form_with_full_preload(test_form.id)

      # 使用有效的表单ID但无效的日期格式
      result =
        Responses.export_responses(test_form.id, %{format: "csv", start_date: "invalid-date"})

      assert {:error, :invalid_date_format} = result
    end

    test "returns error with invalid format option" do
      # 确保先创建有效的表单
      {:ok, user} =
        Accounts.register_user(%{
          email: "test_format_#{System.unique_integer()}@example.com",
          password: "TestPassword123!"
        })

      {:ok, test_form} =
        Forms.create_form(%{
          title: "测试格式表单",
          description: "用于测试导出格式错误",
          published: true,
          user_id: user.id
        })

      # 确保表单正确预加载（创建至少一个页面和一个表单项）
      {:ok, _page} =
        Forms.create_form_page(test_form, %{
          title: "第一页",
          description: "测试页面",
          order: 1
        })

      # 重新获取表单确保页面已加载
      test_form = Forms.get_form_with_full_preload(test_form.id)

      # 使用有效的表单ID但无效的格式
      result = Responses.export_responses(test_form.id, %{format: "invalid"})
      assert {:error, :invalid_format} = result
    end
  end
end
