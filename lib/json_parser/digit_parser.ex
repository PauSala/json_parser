# Option 2: Compare the integer code point directly (Recommended for single-char checks)
defmodule JsonParser.DigitParser do
  def digit(input) do
    case input do
      <<head_char_code_point::utf8, rest::binary>> ->
        if head_char_code_point >= ?0 and head_char_code_point <= ?9 do
          {:ok, <<head_char_code_point::utf8>>, rest}
        else
          {:fail, {:expected_digit, <<head_char_code_point::utf8>>}, input}
        end

      "" ->
        {:fail, :end_of_input, input}
    end
  end
end
