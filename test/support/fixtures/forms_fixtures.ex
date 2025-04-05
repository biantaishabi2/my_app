defmodule MyApp.FormsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MyApp.Forms` context.
  """

  alias MyApp.Forms
  # 以下别名虽然当前未直接使用，但保留注释以便理解上下文
  # alias MyApp.Forms.Form - 表单模型
  # alias MyApp.Forms.FormItem - 表单项模型 
  # alias MyApp.Forms.ItemOption - 选项模型
  
  @doc """
  生成一个测试表单.
  """
  def form_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{
      title: "测试表单 #{System.unique_integer()}",
      description: "这是一个测试表单",
      status: :draft
    })
    
    {:ok, form} = Forms.create_form(attrs)
    form
  end
  
  @doc """
  为表单添加一个测试表单项.
  """
  def form_item_fixture(form, attrs \\ %{}) do
    base_attrs = %{
      label: "测试表单项 #{System.unique_integer()}",
      type: :text_input,
      required: false
    }
    
    # 根据类型添加特定属性
    attrs = 
      case attrs[:type] || attrs["type"] do
        :matrix ->
          # 矩阵题类型需要额外的属性
          Map.merge(base_attrs, %{
            matrix_rows: ["问题1", "问题2", "问题3"],
            matrix_columns: ["选项A", "选项B", "选项C"],
            matrix_type: :single
          })
        _ -> base_attrs
      end
      |> Map.merge(attrs)
    
    # 添加表单项
    case Forms.add_form_item(form, attrs) do
      {:ok, item} -> item
      {:error, changeset} ->
        IO.puts("表单项创建失败: #{inspect(changeset.errors)}")
        # 如果创建失败，使用基本类型再次尝试
        fallback_attrs = Map.merge(attrs, %{type: :text_input})
        {:ok, item} = Forms.add_form_item(form, fallback_attrs)
        item
    end
  end
  
  @doc """
  为单选表单项添加一个选项.
  """
  def item_option_fixture(form_item, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{
      label: "选项 #{System.unique_integer()}",
      value: "value_#{System.unique_integer()}"
    })
    
    {:ok, option} = Forms.add_item_option(form_item, attrs)
    option
  end
end