defmodule MyApp.FormCategoryTest do
  use MyApp.DataCase, async: false

  alias MyApp.Forms
  alias MyApp.Forms.FormItem
  import MyApp.AccountsFixtures
  import MyApp.FormsFixtures

  describe "form_item_category" do
    setup do
      user = user_fixture()
      form = form_fixture(%{user_id: user.id})
      %{user: user, form: form}
    end

    test "add_form_item/2 assigns default category to basic form items", %{form: form} do
      basic_item_types = [:text_input, :textarea, :radio, :checkbox, :dropdown, :number]

      for type <- basic_item_types do
        item_attrs = %{
          label: "Test #{type} item",
          type: type,
          required: true
        }

        {:ok, item} = Forms.add_form_item(form, item_attrs)
        assert item.category == :basic, "Expected #{type} to have :basic category"
      end
    end

    test "add_form_item/2 assigns default category to personal info form items", %{form: form} do
      personal_item_types = [:email, :phone, :date, :time, :region]

      for type <- personal_item_types do
        item_attrs = %{
          label: "Test #{type} item",
          type: type,
          required: true
        }

        {:ok, item} = Forms.add_form_item(form, item_attrs)
        assert item.category == :personal, "Expected #{type} to have :personal category"
      end
    end

    test "add_form_item/2 assigns default category to advanced form items", %{form: form} do
      # 为矩阵类型准备特殊属性
      attrs_for_matrix = %{
        label: "Test matrix item",
        type: :matrix,
        required: true,
        matrix_rows: ["行1", "行2"],
        matrix_columns: ["列1", "列2"]
      }

      # 先测试矩阵类型
      {:ok, matrix_item} = Forms.add_form_item(form, attrs_for_matrix)
      assert matrix_item.category == :advanced, "Expected matrix to have :advanced category"

      # 测试其他高级类型
      other_advanced_types = [:rating, :image_choice, :file_upload]

      for type <- other_advanced_types do
        item_attrs = %{
          label: "Test #{type} item",
          type: type,
          required: true
        }

        {:ok, item} = Forms.add_form_item(form, item_attrs)
        assert item.category == :advanced, "Expected #{type} to have :advanced category"
      end
    end

    test "add_form_item/2 with custom category overrides default", %{form: form} do
      item_attrs = %{
        label: "Custom category item",
        type: :text_input,
        required: true,
        # Override default :basic category
        category: :advanced
      }

      {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.category == :advanced
    end

    test "update_form_item/2 can change category", %{form: form} do
      # First create an item
      {:ok, item} =
        Forms.add_form_item(form, %{
          label: "Test item",
          type: :text_input,
          required: true
        })

      # Verify default category is assigned
      assert item.category == :basic

      # Update the category
      {:ok, updated_item} = Forms.update_form_item(item, %{category: :personal})
      assert updated_item.category == :personal
    end

    test "list_available_form_item_types/0 returns types grouped by category" do
      result = Forms.list_available_form_item_types()

      # Check that result is a map with the expected keys
      assert is_map(result)
      assert Map.has_key?(result, :basic)
      assert Map.has_key?(result, :personal)
      assert Map.has_key?(result, :advanced)

      # Verify some types are in the correct categories
      assert :text_input in result.basic
      assert :email in result.personal
      assert :matrix in result.advanced
    end

    test "list_available_form_item_types/1 with :flat option returns flat list" do
      result = Forms.list_available_form_item_types(:flat)

      # Check that result is a list containing all form item types
      assert is_list(result)
      assert :text_input in result
      assert :email in result
      assert :matrix in result
    end

    test "search_form_item_types/1 filters types by search term" do
      # Search for types containing "text"
      result = Forms.search_form_item_types("text")
      assert :text_input in result
      assert :textarea in result
      refute :radio in result

      # Search should be case insensitive
      result = Forms.search_form_item_types("TEXT")
      assert :text_input in result

      # Search should return empty list for non-matching terms
      result = Forms.search_form_item_types("nonexistent")
      assert result == []
    end
  end
end
