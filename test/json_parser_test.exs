defmodule JsonParserTest do
  alias JsonParser.CharParser
  alias JsonParser.DigitParser
  alias JsonParser.StringParser
  alias JsonParser.AnyCharParser
  alias JsonParser.Combinators
  alias JsonParser.Grammar

  use ExUnit.Case
  doctest JsonParser

  test "char_parser" do
    assert CharParser.char(?a, "abc") == {:ok, "a", "bc"}
  end

  test "digit_parser" do
    assert DigitParser.digit("123") == {:ok, "1", "23"}
  end

  test "string_parser" do
    assert StringParser.string("abc", "abc def") == {:ok, "abc", " def"}
  end

  test "any_char_parser" do
    assert AnyCharParser.anychar("____") == {:ok, "_", "___"}
  end

  test "separated_by" do
    assert Combinators.separated_by(Combinators.any_char(), Combinators.char(?,)).("1,,,,,") ==
             {:ok, ["1", ",", ","], ","}
  end
end
