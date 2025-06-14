defmodule GrammarTests do
  alias JsonParser.Grammar

  use ExUnit.Case
  doctest JsonParser.Grammar

  test "number_parser" do
    assert Grammar.number_parser().("123, 123") == {:ok, 123, ", 123"}
    assert Grammar.number_parser().("1.23") == {:ok, 1.23, ""}
    assert Grammar.number_parser().("-4.56") == {:ok, -4.56, ""}
    assert Grammar.number_parser().("-12.3e+4") == {:ok, -123_000.0, ""}
    assert Grammar.number_parser().("1e10") == {:ok, 10_000_000_000.0, ""}
    assert Grammar.number_parser().("0.0") == {:ok, 0.0, ""}
  end

  test "unicode_escape_parser" do
    assert Grammar.unicode_escape_parser().("\\u0041rest") == {:ok, "A", "rest"}
    assert {:fail, _, _} = Grammar.unicode_escape_parser().("\\uFFFZ abcd")
    assert {:fail, _, _} = Grammar.unicode_escape_parser().("\\u004")
  end

  test "simple_escape_parser: parses backslash double quote" do
    assert Grammar.simple_escape_parser().("\\\"rest") == {:ok, "\"", "rest"}
    assert Grammar.simple_escape_parser().("\\\\rest") == {:ok, "\\", "rest"}
    assert Grammar.simple_escape_parser().("\\/rest") == {:ok, "/", "rest"}
    assert Grammar.simple_escape_parser().("\\brest") == {:ok, "\b", "rest"}
    assert Grammar.simple_escape_parser().("\\frest") == {:ok, "\f", "rest"}
    assert {:fail, _, _} = Grammar.simple_escape_parser().("\\arest")
    assert {:fail, _, _} = Grammar.simple_escape_parser().("not_an_escape")
    assert {:fail, _, _} = Grammar.simple_escape_parser().("\\")
  end

  test "normal_string_char_parser: fails on control character (e.g., null byte)" do
    assert Grammar.string_char_parser().("Arest") == {:ok, "A", "rest"}
    assert Grammar.string_char_parser().("€rest") == {:ok, "€", "rest"}
    assert {:fail, _, _} = Grammar.string_char_parser().("\u0000rest")
  end

  test "json_string_parser: parses an empty string" do
    assert Grammar.json_string_parser().("\"\"") == {:ok, "", ""}
    assert Grammar.json_string_parser().("\"hello world!\"") == {:ok, "hello world!", ""}

    assert Grammar.json_string_parser().("\"line1\\nline2\\tline3\"") ==
             {:ok, "line1\nline2\tline3", ""}

    assert Grammar.json_string_parser().("\"quotes\\\"and\\\\slashes\\/\"") ==
             {:ok, "quotes\"and\\slashes/", ""}

    assert Grammar.json_string_parser().("\"backspace\\bformfeed\\f\"") ==
             {:ok, "backspace\bformfeed\f", ""}

    assert Grammar.json_string_parser().("\"Unicode A: \\u0041 Euro: \\u20AC Digit: \\u0030\"") ==
             {:ok, "Unicode A: A Euro: € Digit: 0", ""}
  end

  test "array_parser" do
    assert Grammar.array_parser().("[]") == {:ok, [], ""}
    assert Grammar.array_parser().("[   ]") == {:ok, [], ""}
    assert Grammar.array_parser().("[123]") == {:ok, [123], ""}
    assert Grammar.array_parser().("[\"hello\"]") == {:ok, ["hello"], ""}

    input = ~s"[1, \"two\", true, null, 5]"
    assert Grammar.array_parser().(input) == {:ok, [1, "two", true, nil, 5.0], ""}

    assert Grammar.array_parser().(~S"[1, [2, 3], 4]") == {:ok, [1, [2, 3], 4], ""}

    assert {:fail, _, _} = Grammar.array_parser().("[1, 2")
  end

  defp fixture_path(filename) do
    Path.join([File.cwd!(), "test", "fixtures", filename])
  end

  test "object_parser" do
    f = fixture_path("test_case.json")
    {:ok, content} = File.read(f)
    IO.inspect(Grammar.object_parser().(content))
  end
end
