# 设置要处理的表单和模板ID
form_id = "b8fd73c1-c966-43e6-935f-06a893313ebd"
template_id = "73c600c3-97ad-4aff-9d07-d8b867fff152"

try do
  # 获取表单及其表单项
  form = MyApp.Forms.get_form_with_full_preload(form_id)

  if is_nil(form) do
    IO.puts("错误: 找不到ID为 #{form_id} 的表单")
    System.halt(1)
  end

  # 获取模板
  template = MyApp.FormTemplates.get_template(template_id)

  if is_nil(template) do
    IO.puts("错误: 找不到ID为 #{template_id} 的模板")
    System.halt(1)
  end

  IO.puts("找到表单: #{form.title}, 有 #{length(form.items)} 个表单项")
  IO.puts("找到模板: #{template.name}")

  # 将表单项转换为模板结构
  structure =
    form.items
    |> Enum.sort_by(& &1.order)
    |> Enum.map(fn item ->
      # 为每个表单项生成模板元素
      %{
        "id" => item.id,
        "type" => Atom.to_string(item.type),
        "label" => item.label,
        "description" => item.description,
        "placeholder" => item.placeholder,
        "required" => item.required,
        "order" => item.order
      }
    end)

  IO.puts("生成了 #{length(structure)} 个模板结构元素")

  # 更新模板结构
  case MyApp.FormTemplates.update_template(template, %{structure: structure}) do
    {:ok, updated_template} ->
      IO.puts("成功更新模板结构")
      IO.puts("模板ID: #{updated_template.id}")
      IO.puts("元素数量: #{length(updated_template.structure)}")

    {:error, changeset} ->
      IO.puts("错误: 更新模板结构失败: #{inspect(changeset.errors)}")
      System.halt(1)
  end
rescue
  e ->
    IO.puts("发生错误: #{inspect(e)}")
    System.halt(1)
end
