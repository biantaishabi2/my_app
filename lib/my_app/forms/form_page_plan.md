# 表单分页功能实施计划

## 一、需求概述

实现多页表单功能，允许用户将表单拆分为多个页面，改善长表单的填写体验和组织结构。

### 核心功能需求

1. **页面管理**
   * 创建、编辑和删除表单页面
   * 调整页面顺序
   * 为页面添加标题和描述

2. **页面内容组织**
   * 将表单项分配到特定页面
   * 在页面间移动表单项
   * 支持页面内表单项排序

3. **页面导航**
   * 提供页面间导航控件（上一页/下一页按钮）
   * 显示页面进度指示器
   * 支持快速跳转到特定页面

4. **数据管理**
   * 跨页面数据保持（部分提交时保存已填写数据）
   * 跨页面数据验证
   * 分页预览功能

5. **扩展功能**
   * 支持基于条件的页面跳转
   * 支持页面完成度指示
   * 支持不同页面使用不同主题和布局

## 二、数据模型设计

### 新增模型：`FormPage`

```elixir
defmodule MyApp.Forms.FormPage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "form_pages" do
    field :title, :string
    field :description, :string
    field :order, :integer
    
    # 关联到表单
    belongs_to :form, MyApp.Forms.Form
    
    # 反向关联到表单项
    has_many :items, MyApp.Forms.FormItem
    
    timestamps(type: :utc_datetime)
  end
  
  @doc false
  def changeset(page, attrs) do
    page
    |> cast(attrs, [:title, :description, :order, :form_id])
    |> validate_required([:title, :order, :form_id])
    |> foreign_key_constraint(:form_id)
  end
end
```

### 修改现有模型：`FormItem`

```elixir
# 在FormItem模型中添加page_id字段
field :page_id, :binary_id
belongs_to :page, MyApp.Forms.FormPage
```

### 数据库迁移

1. 创建表单页面表
```sql
CREATE TABLE form_pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  order INTEGER NOT NULL,
  form_id UUID NOT NULL REFERENCES forms(id) ON DELETE CASCADE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX form_pages_form_id_idx ON form_pages(form_id);
```

2. 修改表单项表，添加页面关联
```sql
ALTER TABLE form_items ADD COLUMN page_id UUID REFERENCES form_pages(id) ON DELETE SET NULL;
CREATE INDEX form_items_page_id_idx ON form_items(page_id);
```

## 三、API设计

### 页面管理API

1. **创建页面**
```elixir
def create_form_page(form, attrs \\ %{})
```

2. **获取页面**
```elixir
def get_form_page(id)
def get_form_page!(id)
```

3. **更新页面**
```elixir
def update_form_page(page, attrs)
```

4. **删除页面**
```elixir
def delete_form_page(page)
```

5. **列出表单的所有页面**
```elixir
def list_form_pages(form_id)
```

6. **重新排序页面**
```elixir
def reorder_form_pages(form_id, page_ids)
```

### 表单项管理API扩展

1. **将表单项分配到页面**
```elixir
def assign_item_to_page(item, page)
```

2. **在页面间移动表单项**
```elixir
def move_item_to_page(item_id, page_id)
```

3. **获取页面中的所有表单项**
```elixir
def list_page_items(page_id)
```

## 四、前端实现

### 编辑界面

1. **页面管理面板**
   * 页面列表显示（带标题和描述）
   * 添加/编辑/删除页面按钮
   * 页面拖拽排序功能

2. **表单项页面分配**
   * 在表单项编辑界面添加页面选择器
   * 提供拖拽方式在页面间移动表单项

3. **页面内容预览**
   * 按页面分组显示表单项
   * 提供页面切换功能

### 提交界面

1. **分页导航**
   * 上一页/下一页按钮
   * 页面导航菜单（带完成状态指示）
   * 进度条指示当前完成度

2. **分页表单验证**
   * 页面内表单项验证
   * 提交前全表单验证

3. **分页数据保存**
   * 页面切换时自动保存数据
   * 实现会话数据临时存储

## 五、实施步骤

### 第一阶段：数据模型实现 (预计2天)

1. 创建FormPage模型和迁移文件
2. 修改FormItem模型，添加page_id字段
3. 修改Forms上下文，添加页面管理功能
4. 编写模型测试

### 第二阶段：后端API实现 (预计3天)

1. 实现页面管理API
2. 实现表单项页面分配API
3. 更新表单获取API以支持页面结构
4. 编写API测试

### 第三阶段：编辑界面实现 (预计3天)

1. 创建页面管理组件
2. 修改表单编辑界面以支持页面
3. 添加页面间表单项移动功能
4. 实现页面预览功能

### 第四阶段：提交界面实现 (预计3天)

1. 实现分页导航组件
2. 添加页面间数据保存逻辑
3. 实现分页表单验证
4. 添加进度指示功能

### 第五阶段：测试与优化 (预计2天)

1. 编写集成测试
2. 添加错误处理和边界情况处理
3. 性能优化
4. UI/UX改进

## 六、注意事项与风险点

1. **数据完整性**
   - 页面删除后表单项处理策略（移至默认页面或设为null）
   - 确保表单数据结构变更不影响已有响应数据

2. **性能考量**
   - 大型表单的页面切换性能
   - 同时加载所有页面vs按需加载

3. **用户体验**
   - 确保导航直观易用
   - 处理页面间数据依赖关系
   - 提供清晰的错误提示和引导

4. **向后兼容性**
   - 保持API兼容性，支持无页面表单
   - 现有表单迁移策略（自动创建默认页面）

## 七、评估指标

1. **功能完整性**
   - 所有计划功能成功实现
   - 测试覆盖率达到90%以上

2. **性能指标**
   - 页面切换时间<300ms
   - 表单加载时间<1s（包含10个页面）

3. **用户体验**
   - 导航流程清晰直观
   - 错误提示及时准确
   - 数据保存可靠无丢失