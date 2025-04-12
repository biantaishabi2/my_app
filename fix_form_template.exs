# 要修复的表单ID
form_id = "b8fd73c1-c966-43e6-935f-06a893313ebd"

try do
  # 获取表单
  form = MyApp.Forms.get_form(form_id)

  if is_nil(form) do
    IO.puts("错误: 找不到ID为 #{form_id} 的表单")
    System.halt(1)
  end

  IO.puts("找到表单: #{form.title}")

  # 检查表单是否已有模板
  if form.form_template_id do
    IO.puts("表单 #{form_id} 已经关联了模板ID: #{form.form_template_id}")
    System.halt(0)
  end

  # 创建默认模板属性 - 不尝试设置created_by_id
  template_attrs = %{
    name: "默认表单模板 #{DateTime.utc_now() |> Calendar.strftime("%Y%m%d%H%M%S")}",
    description: "自动创建的默认表单模板",
    structure: [],
    version: 1,
    is_active: true
  }

  # 打印调试信息
  IO.puts("正在尝试创建模板: #{inspect(template_attrs)}")

  # 创建默认表单模板
  case MyApp.FormTemplates.create_template(template_attrs) do
    {:ok, template} ->
      IO.puts("成功创建默认模板，ID: #{template.id}")

      # 更新表单关联模板
      case MyApp.Forms.update_form(form, %{form_template_id: template.id}) do
        {:ok, updated_form} ->
          IO.puts("成功将模板 #{template.id} 关联到表单 #{form_id}")
          IO.puts("操作成功完成\!")

        {:error, changeset} ->
          IO.puts("错误: 无法更新表单: #{inspect(changeset.errors)}")
          System.halt(1)
      end

    {:error, changeset} ->
      IO.puts("错误: 无法创建默认模板: #{inspect(changeset)}")
      System.halt(1)
  end
rescue
  e ->
    IO.puts("发生错误: #{inspect(e)}")
    System.halt(1)
end
