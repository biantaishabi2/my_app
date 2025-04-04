defmodule MyApp.FormsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MyApp.Forms` context.
  """

  alias MyApp.Forms
  alias MyApp.Forms.Form
  alias MyApp.Forms.FormItem
  alias MyApp.Forms.ItemOption
  
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
    attrs = Enum.into(attrs, %{
      label: "测试表单项 #{System.unique_integer()}",
      type: :text_input,
      required: false
    })
    
    {:ok, item} = Forms.add_form_item(form, attrs)
    item
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