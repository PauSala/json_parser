defmodule JsonParser.AnyCharParser do
  def anychar(input) do
    case input do
      <<head_char_code_point::utf8, rest::binary>> ->
        {:ok, <<head_char_code_point::utf8>>, rest}

      "" ->
        {:fail, :end_of_input, input}
    end
  end
end
