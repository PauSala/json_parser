defmodule JsonParser.StringParser do
  def string(expected_string, input) when input != "" do
    if String.starts_with?(input, expected_string) do
      remaining_input = String.trim_leading(input, expected_string)
      {:ok, expected_string, remaining_input}
    else
      {:fail, {:expected_string, expected_string, input}, input}
    end
  end

  def string(_expected_string, "") do
    {:fail, :end_of_input, ""}
  end
end
