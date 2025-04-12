defmodule MyAppWeb.Helpers do
  @doc """
  格式化文件大小，将字节数转换为人类可读的格式。
  """
  def format_file_size(size_bytes) when is_integer(size_bytes) do
    cond do
      size_bytes < 1024 -> "#{size_bytes} B"
      size_bytes < 1024 * 1024 -> "#{Float.round(size_bytes / 1024, 1)} KB"
      size_bytes < 1024 * 1024 * 1024 -> "#{Float.round(size_bytes / 1024 / 1024, 1)} MB"
      true -> "#{Float.round(size_bytes / 1024 / 1024 / 1024, 1)} GB"
    end
  end

  def format_file_size(_), do: "未知大小"
end
