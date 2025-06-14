defmodule JsonParser.CharParser do
  def char(expected_char_code_point, <<head_char_code_point::utf8, rest::binary>>) do
    if head_char_code_point == expected_char_code_point do
      {:ok, <<head_char_code_point::utf8>>, rest}
    else
      {:fail,
       {:expected_char, <<expected_char_code_point::utf8>>, <<head_char_code_point::utf8>>},
       <<head_char_code_point::utf8, rest::binary>>}
    end
  end

  def char(_expected_char_code_point, "") do
    {:fail, :end_of_input, ""}
  end
end
