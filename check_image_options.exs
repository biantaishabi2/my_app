# 检查图片选择题的选项和关联图片
# 运行方式: mix run check_image_options.exs

# 要检查的表单项ID
form_id = "b8fd73c1-c966-43e6-935f-06a893313ebd"
image_item_id = "ea81ee99-c3ff-47ca-9966-7935d597070a"

# 直接连接数据库会话
IO.puts("====== 开始检查图片选择题 ======")
IO.puts("表单ID: #{form_id}")
IO.puts("图片选择题ID: #{image_item_id}")

# 获取表单项
form_item = MyApp.Forms.get_form_item(image_item_id)
IO.puts("\n表单项信息:")
IO.puts("标题: #{form_item.label}")
IO.puts("类型: #{form_item.type}")

# 检查该表单项是否有选项
IO.puts("\n检查选项:")
form_item_with_options = MyApp.Forms.get_form_item_with_options(image_item_id)
options = form_item_with_options.options || []

if Enum.empty?(options) do
  IO.puts("该表单项没有选项数据!")
else
  IO.puts("该表单项有 #{length(options)} 个选项:")
  
  Enum.each(options, fn option ->
    IO.puts("\n选项ID: #{option.id}")
    IO.puts("选项标签: #{option.label}")
    IO.puts("选项值: #{option.value}")
    IO.puts("图片ID: #{option.image_id || "无"}")
    IO.puts("图片文件名: #{option.image_filename || "无"}")
    
    # 检查是否有关联图片
    if option.image_id do
      image = MyApp.Upload.get_file(option.image_id)
      if image do
        IO.puts("关联图片信息:")
        IO.puts("  - 路径: #{image.path}")
        IO.puts("  - 原文件名: #{image.original_filename}")
        IO.puts("  - 文件大小: #{image.size} 字节")
      else
        IO.puts("图片ID存在但找不到图片记录!")
      end
    end
  end)
end

# 检查 item_options 表查询
IO.puts("\n检查数据库查询:")
item_options_query = "SELECT * FROM item_options WHERE form_item_id = '#{image_item_id}'"
result = Ecto.Adapters.SQL.query!(MyApp.Repo, item_options_query, [])

if result.num_rows == 0 do
  IO.puts("数据库中没有该表单项的选项记录!")
else
  IO.puts("数据库中有 #{result.num_rows} 条选项记录")
  
  # 获取列名
  columns = Enum.map(result.columns, &String.to_atom/1)
  
  # 打印每一行记录
  Enum.each(result.rows, fn row ->
    # 将行数据与列名结合
    row_data = Enum.zip(columns, row) |> Enum.into(%{})
    
    IO.puts("\n数据库记录:")
    IO.puts("  ID: #{row_data.id}")
    IO.puts("  标签: #{row_data.label}")
    IO.puts("  值: #{row_data.value}")
    IO.puts("  图片ID: #{row_data.image_id || "nil"}")
    IO.puts("  图片文件名: #{row_data.image_filename || "nil"}")
  end)
end

IO.puts("\n====== 检查完成 ======")