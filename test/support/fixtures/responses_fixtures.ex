defmodule MyApp.ResponsesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MyApp.Responses` context.
  """

  alias MyApp.Responses
  alias MyApp.Responses.Response
  alias MyApp.Responses.Answer

  @doc """
  生成一个测试响应.
  """
  def response_fixture(form_id, answers_map \\ %{}) do
    # 如果没有提供答案，使用一个默认答案
    answers_map = if map_size(answers_map) == 0 do
      # 假设有一个默认的表单项
      %{"default_item_id" => "默认回答"}
    else
      answers_map
    end
    
    # 创建响应
    {:ok, response} = Responses.create_response(form_id, answers_map)
    
    # 预加载 answers
    response = MyApp.Repo.preload(response, :answers)
    response
  end
end