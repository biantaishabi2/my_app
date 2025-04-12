defmodule MyAppWeb.Components.RegionSelect do
  use Phoenix.Component

  def region_select(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)
    assigns = assign_new(assigns, :region_level, fn -> 3 end)
    assigns = assign_new(assigns, :form_state, fn -> %{} end)
    assigns = assign_new(assigns, :errors, fn -> %{} end)

    # 获取已选值
    province = Map.get(assigns.form_state || %{}, "#{assigns.field_id}_province")
    city = Map.get(assigns.form_state || %{}, "#{assigns.field_id}_city")
    district = Map.get(assigns.form_state || %{}, "#{assigns.field_id}_district")

    assigns = assign(assigns, :province, province)
    assigns = assign(assigns, :city, city)
    assigns = assign(assigns, :district, district)

    ~H"""
    <div class="space-y-2">
      <div class="text-sm text-gray-600 mb-2">
        请选择您所在的地区
      </div>

      <div class={"grid grid-cols-#{@region_level} gap-2"}>
        <!-- 省份选择 -->
        <div class="relative region-select-container" id={"region-province-container-#{@field_id}"}>
          <select
            id={"#{@field_id}_province"}
            name={"form[#{@field_id}_province]"}
            phx-change="handle_province_change"
            data-field-id={@field_id}
            class="region-select w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 border-gray-300"
            {if @disabled, do: [disabled: true], else: []}
          >
            <option value="" disabled selected={!@province}>省/直辖市</option>

            <%= for p <- MyApp.Regions.get_provinces() do %>
              <option value={p.name} selected={@province == p.name}>
                {p.name}
              </option>
            <% end %>
          </select>
          <div
            class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-500"
            style="height: 40px;"
          >
            <svg
              class="h-4 w-4"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
        </div>
        
    <!-- 城市选择 -->
        <%= if @region_level >= 2 do %>
          <div class="relative region-select-container" id={"region-city-container-#{@field_id}"}>
            <select
              id={"#{@field_id}_city"}
              name={"form[#{@field_id}_city]"}
              phx-change="handle_city_change"
              data-field-id={@field_id}
              data-province={@province}
              class="region-select w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 border-gray-300"
              disabled={!@province}
            >
              <option value="" disabled selected={!@city}>市</option>

              <%= if @province do %>
                <%= for c <- MyApp.Regions.get_cities(@province) do %>
                  <option value={c.name} selected={@city == c.name}>
                    {c.name}
                  </option>
                <% end %>
              <% end %>
            </select>
            <div
              class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-500"
              style="height: 40px;"
            >
              <svg
                class="h-4 w-4"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
          </div>
        <% end %>
        
    <!-- 区县选择 -->
        <%= if @region_level >= 3 do %>
          <div class="relative region-select-container" id={"region-district-container-#{@field_id}"}>
            <select
              id={"#{@field_id}_district"}
              name={"form[#{@field_id}_district]"}
              phx-change="handle_district_change"
              data-field-id={@field_id}
              class="region-select w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 border-gray-300"
              disabled={!@city}
            >
              <option value="" disabled selected={!@district}>区/县</option>

              <%= if @province && @city do %>
                <%= for d <- MyApp.Regions.get_districts(@province, @city) do %>
                  <option value={d.name} selected={@district == d.name}>
                    {d.name}
                  </option>
                <% end %>
              <% end %>
            </select>
            <div
              class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-500"
              style="height: 40px;"
            >
              <svg
                class="h-4 w-4"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
          </div>
        <% end %>
      </div>
      
    <!-- 隐藏的输入字段，用于提交完整的地区值 -->
      <input
        type="hidden"
        id={@field_id}
        name={"form[#{@field_id}]"}
        value={combine_region_value(@province, @city, @district)}
      />

      <%= if Map.get(@errors, @field_id) do %>
        <div id={"error_#{@field_id}"} class="text-red-500 text-sm mt-1 error-message" role="alert">
          {@errors[@field_id]}
        </div>
      <% end %>
    </div>
    """
  end

  # 用于将地区选择的三个字段组合成一个值
  defp combine_region_value(province, city, district) do
    case {province, city, district} do
      {nil, _, _} ->
        ""

      {_, nil, _} when not is_nil(province) ->
        province

      {_, _, nil} when not is_nil(province) and not is_nil(city) ->
        "#{province}-#{city}"

      {_, _, _} when not is_nil(province) and not is_nil(city) and not is_nil(district) ->
        "#{province}-#{city}-#{district}"

      _ ->
        ""
    end
  end
end
