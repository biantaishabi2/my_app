# 调试图片选择题的保存过程
# 运行方式: mix run debug_image_options.exs

# 测试创建新的图片选择题
IO.puts("====== 创建新的图片选择题进行测试 ======")

# 从表单开始
form_id = "b8fd73c1-c966-43e6-935f-06a893313ebd"
form = MyApp.Forms.get_form(form_id)

IO.puts("获取到表单: #{form.title}")

# 创建一个新的图片选择题
page_id = if form.default_page_id, do: form.default_page_id, else: List.first(form.pages).id

# 1. 创建新的表单项
item_params = %{
  "label" => "测试图片选择题",
  "type" => :image_choice,
  "required" => false,
  "page_id" => page_id,
  "selection_type" => :single,
  "image_caption_position" => :bottom,
  "order" => 999 # 放在最后
}

# 添加表单项
{result, new_item} = MyApp.Forms.add_form_item(form, item_params)
IO.puts("创建表单项结果: #{result}")
IO.puts("新表单项ID: #{new_item.id}")

# 2. 添加选项
option_params1 = %{
  "label" => "测试选项1", 
  "value" => "option_1",
  "order" => 1,
  "form_item_id" => new_item.id
}

option_params2 = %{
  "label" => "测试选项2", 
  "value" => "option_2",
  "order" => 2,
  "form_item_id" => new_item.id,
  # 测试空图片ID
  "image_id" => nil,
  "image_filename" => nil
}

# 添加选项
{result1, option1} = MyApp.Forms.ItemOption.changeset(%MyApp.Forms.ItemOption{}, option_params1) |> MyApp.Repo.insert()
{result2, option2} = MyApp.Forms.ItemOption.changeset(%MyApp.Forms.ItemOption{}, option_params2) |> MyApp.Repo.insert()

IO.puts("添加选项1结果: #{result1}, ID: #{option1.id}")
IO.puts("添加选项2结果: #{result2}, ID: #{option2.id}")

# 3. 验证选项是否添加成功
item_with_options = MyApp.Forms.get_form_item_with_options(new_item.id)
options = item_with_options.options || []

IO.puts("\n表单项选项数量: #{length(options)}")
Enum.each(options, fn option ->
  IO.puts("- 选项ID: #{option.id}, 标签: #{option.label}, 值: #{option.value}")
  IO.puts("  图片ID: #{option.image_id || "无"}, 图片文件名: #{option.image_filename || "无"}")
end)

# 4. 测试保存逻辑
# 将选项2模拟为有图片的选项
mock_option2 = %{option2 | image_id: "fake_image_id", image_filename: "fake_image.jpg"}
updated_options = [option1, mock_option2]

# 使用inspect输出完整选项详情
IO.puts("\n更新前选项详情:")
IO.inspect(updated_options, pretty: true, limit: :infinity)

# 模拟处理选项函数
test_process_options = fn item, options ->
  # 处理表单项选项
  IO.puts("\n==== TEST: 处理表单项选项 ====")
  IO.puts("表单项: #{inspect(item)}")
  IO.puts("传入选项列表: #{inspect(options)}")
  
  # 预处理选项
  options_to_save = options
    |> Enum.map(fn opt ->
        # 提取字段
        %{
          "label" => opt.label || "", 
          "value" => opt.value || "",
          "image_id" => opt.image_id,
          "image_filename" => opt.image_filename
        }
      end)
    |> Enum.filter(fn opt -> 
        # 过滤掉完全空的选项（除非它有关联的图片）
        IO.puts("检查选项: #{inspect(opt)}")
        IO.puts("过滤条件: label=#{opt["label"] != ""}, value=#{opt["value"] != ""}, image_id=#{!is_nil(opt["image_id"])}")
        result = opt["label"] != "" || opt["value"] != "" || !is_nil(opt["image_id"])
        IO.puts("保留选项? #{result}")
        result
      end)

  IO.puts("最终准备保存的选项数量: #{length(options_to_save)}")
  IO.puts("最终选项内容: #{inspect(options_to_save)}")
  
  options_to_save
end

# 测试函数处理
test_process_options.(new_item, updated_options)

# 5. 测试选项过滤
# 我们不直接调用process_options以避免修改数据库,但模拟相同的过滤逻辑
test_options = [
  %{label: "", value: "", image_id: nil, image_filename: nil},  # 应该被过滤掉
  %{label: "有标签", value: "", image_id: nil, image_filename: nil},  # 应该保留
  %{label: "", value: "有值", image_id: nil, image_filename: nil},  # 应该保留
  %{label: "", value: "", image_id: "有图片", image_filename: "test.jpg"}  # 应该保留
]

filtered_options = Enum.filter(test_options, fn opt -> 
    opt.label != "" || opt.value != "" || !is_nil(opt.image_id)
  end)

IO.puts("\n测试选项过滤:")
IO.puts("过滤前: #{length(test_options)} 个选项")
IO.puts("过滤后: #{length(filtered_options)} 个选项")
IO.inspect(filtered_options, pretty: true)

IO.puts("\n====== 测试完成 ======")