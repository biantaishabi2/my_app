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
    attrs =
      Enum.into(attrs, %{
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

        _ ->
          base_attrs
      end
      |> Map.merge(attrs)

    # 添加表单项
    case Forms.add_form_item(form, attrs) do
      {:ok, item} ->
        item

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
    attrs =
      Enum.into(attrs, %{
        label: "选项 #{System.unique_integer()}",
        value: "value_#{System.unique_integer()}"
      })

    {:ok, option} = Forms.add_item_option(form_item, attrs)
    option
  end

  @doc """
  创建一个带有分页的测试表单.
  """
  def paged_form_fixture(user_id, attrs \\ %{}) do
    # 创建基础表单
    attrs =
      Map.merge(
        %{
          user_id: user_id,
          title: "分页表单测试 #{System.unique_integer()}",
          description: "这是一个分页表单测试",
          status: :draft
        },
        attrs
      )

    form = form_fixture(attrs)

    # 创建默认的三个页面
    {:ok, page1} = Forms.create_form_page(form, %{title: "第一页", description: "基本信息", order: 1})
    {:ok, page2} = Forms.create_form_page(form, %{title: "第二页", description: "联系信息", order: 2})
    {:ok, page3} = Forms.create_form_page(form, %{title: "第三页", description: "其他信息", order: 3})

    # 为每个页面添加表单项
    {:ok, name_item} =
      Forms.add_form_item(form, %{
        label: "姓名",
        type: :text_input,
        required: true,
        page_id: page1.id,
        order: 1
      })

    {:ok, gender_item} =
      Forms.add_form_item(form, %{
        label: "性别",
        type: :radio,
        required: true,
        page_id: page1.id,
        order: 2
      })

    # 添加性别选项
    {:ok, _} = Forms.add_item_option(gender_item, %{label: "男", value: "male"})
    {:ok, _} = Forms.add_item_option(gender_item, %{label: "女", value: "female"})

    # 第二页表单项
    {:ok, email_item} =
      Forms.add_form_item(form, %{
        label: "邮箱",
        type: :email,
        required: true,
        page_id: page2.id,
        order: 1
      })

    {:ok, phone_item} =
      Forms.add_form_item(form, %{
        label: "电话",
        type: :phone,
        required: true,
        page_id: page2.id,
        order: 2
      })

    # 第三页表单项
    {:ok, comment_item} =
      Forms.add_form_item(form, %{
        label: "备注",
        type: :textarea,
        required: false,
        page_id: page3.id,
        order: 1
      })

    # 发布表单
    {:ok, published_form} = Forms.publish_form(form)

    %{
      form: published_form,
      page1: page1,
      page2: page2,
      page3: page3,
      name_item: name_item,
      gender_item: gender_item,
      email_item: email_item,
      phone_item: phone_item,
      comment_item: comment_item
    }
  end
end
