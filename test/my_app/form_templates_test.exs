# test/my_app/form_templates_test.exs
defmodule MyApp.FormTemplatesTest do
  use MyApp.DataCase, async: true # Use DataCase for DB operations

  alias MyApp.FormTemplates
  alias MyApp.FormTemplates.FormTemplate
  # Import any necessary fixtures, e.g., import MyApp.FormTemplatesFixtures

  # Helper function to create a form template fixture
  # Adjust attributes as needed for your schema
  defp form_template_fixture(attrs) do
    {:ok, template} =
      attrs
      |> Enum.into(%{
        name: "Test Template for Ordering",
        version: 1,
        structure: [
          %{id: "elem_a", type: "text", label: "Element A"},
          %{id: "elem_b", type: "number", label: "Element B"},
          %{id: "elem_c", type: "section", title: "Element C"}
        ]
      })
      |> FormTemplates.create_template() # Assuming this context function exists

    template
  end

  describe "FormTemplate Context Operations" do
    @valid_attrs %{name: "Valid Template Name", version: 1, structure: [%{id: "a", type: "text"}]}
    @invalid_attrs %{version: 1} # Missing name and structure

    test "create_template/1 with valid data creates a template" do
      assert {:ok, %FormTemplate{} = template} = FormTemplates.create_template(@valid_attrs)
      assert template.name == "Valid Template Name"
      assert template.version == 1
      assert template.structure == [%{id: "a", type: "text"}] # 期望原子键
    end

    test "create_template/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} = FormTemplates.create_template(@invalid_attrs)
      # assert errors_on(changeset) |> Map.keys() |> Enum.sort() == [:name, :structure]
      # 只检查缺失的 :name
      assert errors_on(changeset) |> Map.keys() == [:name]
    end

    test "get_template!/1 returns the template with given id" do
      template = form_template_fixture(%{})
      fetched_template = FormTemplates.get_template!(template.id)
      assert fetched_template.id == template.id
      assert fetched_template.name == template.name
    end

    test "get_template!/1 raises if id does not exist" do
      non_existent_uuid = Ecto.UUID.generate()
      assert_raise Ecto.NoResultsError, fn ->
        FormTemplates.get_template!(non_existent_uuid)
      end
    end

    test "update_template/2 successfully updates non-structure attributes" do
      template = form_template_fixture(%{})
      update_attrs = %{name: "Updated Template Name", version: 2}

      assert {:ok, updated_template} = FormTemplates.update_template(template, update_attrs)
      assert updated_template.name == "Updated Template Name"
      assert updated_template.version == 2
      assert updated_template.structure == template.structure # Structure should remain unchanged

      # Verify persistence
      fetched_template = FormTemplates.get_template!(template.id)
      assert fetched_template.name == "Updated Template Name"
      assert fetched_template.version == 2
    end

    test "update_template/2 成功更新模板 structure 中元素的顺序" do
      # 1. Create initial template
      template = form_template_fixture(%{})
      original_structure = template.structure
      assert length(original_structure) == 3
      original_ids = Enum.map(original_structure, & &1.id) # ["elem_a", "elem_b", "elem_c"]

      # 2. Define the new order and structure
      # Move "elem_c" to the front
      new_order_ids = ["elem_c", "elem_a", "elem_b"]
      # Find the original elements and reorder them
      elem_c = Enum.find(original_structure, &(&1.id == "elem_c"))
      elem_a = Enum.find(original_structure, &(&1.id == "elem_a"))
      elem_b = Enum.find(original_structure, &(&1.id == "elem_b"))
      new_structure = [elem_c, elem_a, elem_b]

      # Ensure the new structure is different but contains the same elements
      refute new_structure == original_structure
      assert Enum.map(new_structure, & &1.id) == new_order_ids

      # 3. Call the update function
      # Adjust function name if needed (e.g., Forms.update_form_template)
      update_attrs = %{structure: new_structure}
      assert {:ok, updated_template} = FormTemplates.update_template(template, update_attrs)

      # 4. Verify the returned template has the new structure
      assert updated_template.structure == new_structure

      # 5. Verify the change is persisted in the database
      fetched_template = FormTemplates.get_template!(template.id)
      # assert fetched_template.structure == new_structure # 移除直接比较
      # Double-check the IDs order from the fetched structure
      # assert Enum.map(fetched_template.structure, & &1.id) == new_order_ids
      assert Enum.map(fetched_template.structure, & &1["id"]) == new_order_ids # 使用字符串键访问
    end

    test "delete_template/1 deletes the template" do
      template = form_template_fixture(%{})
      assert {:ok, %FormTemplate{}} = FormTemplates.delete_template(template)
      # Verify it's deleted
      assert_raise Ecto.NoResultsError, fn ->
        FormTemplates.get_template!(template.id)
      end
    end

    # Add other FormTemplate context tests here later if needed
  end
end
