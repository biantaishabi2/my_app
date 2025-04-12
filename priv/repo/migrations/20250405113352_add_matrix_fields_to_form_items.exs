defmodule MyApp.Repo.Migrations.AddMatrixFieldsToFormItems do
  use Ecto.Migration

  def change do
    alter table(:form_items) do
      # 添加矩阵控件字段
      add :matrix_rows, {:array, :string}, default: []
      add :matrix_columns, {:array, :string}, default: []
      add :matrix_type, :string, default: "single"
    end

    # 更新类型枚举，添加矩阵选择类型
    execute(
      "ALTER TABLE form_items DROP CONSTRAINT IF EXISTS form_items_type_check",
      ""
    )

    execute(
      "ALTER TABLE form_items ADD CONSTRAINT form_items_type_check CHECK (type::text = ANY (ARRAY['text_input'::character varying, 'textarea'::character varying, 'radio'::character varying, 'checkbox'::character varying, 'dropdown'::character varying, 'rating'::character varying, 'number'::character varying, 'email'::character varying, 'phone'::character varying, 'date'::character varying, 'time'::character varying, 'region'::character varying, 'matrix'::character varying]::text[]))",
      "ALTER TABLE form_items ADD CONSTRAINT form_items_type_check CHECK (type::text = ANY (ARRAY['text_input'::character varying, 'textarea'::character varying, 'radio'::character varying, 'checkbox'::character varying, 'dropdown'::character varying, 'rating'::character varying, 'number'::character varying, 'email'::character varying, 'phone'::character varying, 'date'::character varying, 'time'::character varying, 'region'::character varying]::text[]))"
    )
  end
end
