defmodule MyApp.Repo.Migrations.UpdateFormItemsTypeCheckForFillInBlank do
  use Ecto.Migration

  def change do
    # 更新类型枚举，添加填空题类型
    execute(
      "ALTER TABLE form_items DROP CONSTRAINT IF EXISTS form_items_type_check",
      ""
    )

    execute(
      "ALTER TABLE form_items ADD CONSTRAINT form_items_type_check CHECK (type::text = ANY (ARRAY['text_input'::character varying, 'textarea'::character varying, 'radio'::character varying, 'checkbox'::character varying, 'dropdown'::character varying, 'rating'::character varying, 'number'::character varying, 'email'::character varying, 'phone'::character varying, 'date'::character varying, 'time'::character varying, 'region'::character varying, 'matrix'::character varying, 'image_choice'::character varying, 'file_upload'::character varying, 'fill_in_blank'::character varying]::text[]))",
      "ALTER TABLE form_items ADD CONSTRAINT form_items_type_check CHECK (type::text = ANY (ARRAY['text_input'::character varying, 'textarea'::character varying, 'radio'::character varying, 'checkbox'::character varying, 'dropdown'::character varying, 'rating'::character varying, 'number'::character varying, 'email'::character varying, 'phone'::character varying, 'date'::character varying, 'time'::character varying, 'region'::character varying, 'matrix'::character varying, 'image_choice'::character varying, 'file_upload'::character varying]::text[]))"
    )
  end
end
