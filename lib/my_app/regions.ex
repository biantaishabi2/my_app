defmodule MyApp.Regions do
  @moduledoc """
  处理省市区三级地区数据
  数据来源: https://github.com/modood/Administrative-divisions-of-China
  """
  
  @regions_file "priv/static/data/pca-code.json"
  
  @doc """
  获取所有省份列表
  """
  def get_provinces do
    load_regions()
    |> Enum.map(fn province -> %{code: province["code"], name: province["name"]} end)
  end
  
  @doc """
  获取指定省份的所有城市
  """
  def get_cities(province_name) do
    load_regions()
    |> Enum.find(fn p -> p["name"] == province_name end)
    |> case do
      nil -> []
      province -> 
        province["children"]
        |> Enum.map(fn city -> %{code: city["code"], name: city["name"]} end)
    end
  end
  
  @doc """
  获取指定省份和城市的所有区县
  """
  def get_districts(province_name, city_name) do
    load_regions()
    |> Enum.find(fn p -> p["name"] == province_name end)
    |> case do
      nil -> []
      province -> 
        province["children"]
        |> Enum.find(fn c -> c["name"] == city_name end)
        |> case do
          nil -> []
          city -> 
            city["children"]
            |> Enum.map(fn district -> %{code: district["code"], name: district["name"]} end)
        end
    end
  end
  
  @doc """
  加载地区数据
  """
  def load_regions do
    Application.app_dir(:my_app, @regions_file)
    |> File.read!()
    |> Jason.decode!()
  end
end