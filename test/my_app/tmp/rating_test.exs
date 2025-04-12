defmodule MyApp.RatingTest do
  use MyApp.DataCase
  import MyApp.AccountsFixtures

  alias MyApp.Forms

  describe "rating component" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "create a form with rating component", %{user: user} do
      # 创建一个基本表单
      {:ok, form} =
        Forms.create_form(%{
          title: "测试评分表单",
          description: "用于测试评分组件",
          status: :draft,
          user_id: user.id
        })

      # 添加一个评分组件到表单
      {:ok, rating_item} =
        Forms.add_form_item(form, %{
          "label" => "请为服务评分",
          "type" => "rating",
          "required" => true,
          "order" => 1,
          # 设置最大评分为10，模拟表单提交字符串值
          "max_rating" => "10"
        })

      # 打印评分组件的所有字段用于调试
      IO.inspect(rating_item, label: "创建的评分组件")

      # 验证评分组件被正确创建
      assert rating_item.type == :rating
      assert rating_item.label == "请为服务评分"
      # 现在应该能正确保存max_rating值了
      assert rating_item.max_rating == 10
      assert rating_item.required == true

      # 通过ID获取评分组件并验证
      retrieved_item = Forms.get_form_item(rating_item.id)
      IO.inspect(retrieved_item, label: "获取的评分组件")
      # 验证max_rating正确保存到了数据库
      assert retrieved_item.max_rating == 10
      assert retrieved_item.type == :rating

      # 更新评分组件
      {:ok, updated_item} =
        Forms.update_form_item(rating_item, %{
          "max_rating" => "5",
          "label" => "更新后的评分标签"
        })

      IO.inspect(updated_item, label: "更新后的评分组件")
      # 现在应该正确更新为5
      assert updated_item.max_rating == 5
      assert updated_item.label == "更新后的评分标签"
    end

    test "create form with default max_rating", %{user: user} do
      # 创建一个基本表单
      {:ok, form} =
        Forms.create_form(%{
          title: "默认评分表单",
          description: "测试默认评分值",
          status: :draft,
          user_id: user.id
        })

      # 添加一个评分组件，不指定max_rating
      {:ok, rating_item} =
        Forms.add_form_item(form, %{
          "label" => "默认评分项",
          "type" => "rating",
          "required" => false,
          "order" => 1
        })

      # 验证默认值是5
      assert rating_item.max_rating == 5
    end
  end
end
