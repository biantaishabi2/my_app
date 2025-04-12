defmodule MyApp.Repo.Migrations.AddImageChoiceAndFileUploadFieldsToFormItems do
  use Ecto.Migration

  def change do
    alter table(:form_items) do
      # 图片选择控件字段
      add :selection_type, :string, default: "single"
      add :image_caption_position, :string, default: "bottom"

      # 文件上传控件字段
      add :allowed_extensions, {:array, :string}, default: []
      add :max_file_size, :integer, default: 5
      add :multiple_files, :boolean, default: false
      add :max_files, :integer, default: 1
    end

    # 更新类型枚举，添加图片选择和文件上传类型
    execute(
      "ALTER TABLE form_items DROP CONSTRAINT IF EXISTS form_items_type_check",
      ""
    )

    execute(
      "ALTER TABLE form_items ADD CONSTRAINT form_items_type_check CHECK (type::text = ANY (ARRAY['text_input'::character varying, 'textarea'::character varying, 'radio'::character varying, 'checkbox'::character varying, 'dropdown'::character varying, 'rating'::character varying, 'number'::character varying, 'email'::character varying, 'phone'::character varying, 'date'::character varying, 'time'::character varying, 'region'::character varying, 'matrix'::character varying, 'image_choice'::character varying, 'file_upload'::character varying]::text[]))",
      "ALTER TABLE form_items ADD CONSTRAINT form_items_type_check CHECK (type::text = ANY (ARRAY['text_input'::character varying, 'textarea'::character varying, 'radio'::character varying, 'checkbox'::character varying, 'dropdown'::character varying, 'rating'::character varying, 'number'::character varying, 'email'::character varying, 'phone'::character varying, 'date'::character varying, 'time'::character varying, 'region'::character varying, 'matrix'::character varying]::text[]))"
    )
  end
end
