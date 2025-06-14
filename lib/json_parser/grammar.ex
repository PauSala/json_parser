defmodule JsonParser.Grammar do
  alias JsonParser.Combinators

  def number_parser() do
    minus_sign_parser = Combinators.optional(Combinators.char(?\-))
    zero_digit_parser = Combinators.char(?0)

    non_zero_digit_parser =
      Combinators.satisfy(Combinators.digit(), fn d_char -> d_char != "0" end)

    remaining_digits_parser = Combinators.many(Combinators.digit())

    integer_digits_sequence_parser =
      Combinators.choice(
        zero_digit_parser
        |> Combinators.map(fn char_string -> [char_string] end),
        Combinators.sequence(non_zero_digit_parser, remaining_digits_parser)
        |> Combinators.map(fn [first_digit, rest_digits] -> [first_digit | rest_digits] end)
      )

    integer_part_string_parser =
      Combinators.sequence(minus_sign_parser, integer_digits_sequence_parser)
      |> Combinators.map(fn [minus_char, digits_chars] ->
        signed_str = if minus_char, do: "-", else: ""
        signed_str <> List.to_string(digits_chars)
      end)

    fraction_part_parser =
      Combinators.sequence(
        Combinators.char(?.),
        Combinators.some(Combinators.digit())
      )
      |> Combinators.map(fn [_dot_char, digits_chars] ->
        "." <> List.to_string(digits_chars)
      end)
      |> Combinators.optional()

    exponent_char_parser = Combinators.one_in([?e, ?E])
    exponent_sign_parser = Combinators.optional(Combinators.one_in([?+, ?\-]))
    exponent_digits_parser = Combinators.some(Combinators.digit())

    exponent_part_parser =
      Combinators.sequence([exponent_char_parser, exponent_sign_parser, exponent_digits_parser])
      |> Combinators.map(fn [e_char, sign_char, digits_chars] ->
        e_str = List.to_string([e_char])
        sign_str = if sign_char, do: List.to_string([sign_char]), else: ""
        digits_str = List.to_string(digits_chars)
        e_str <> sign_str <> digits_str
      end)
      |> Combinators.optional()

    full_number_string_parser =
      Combinators.sequence([
        integer_part_string_parser,
        fraction_part_parser,
        exponent_part_parser
      ])
      |> Combinators.map(fn [int_str, fraction_str, exponent_str] ->
        int_str <> (fraction_str || "") <> (exponent_str || "")
      end)

    Combinators.sequence(full_number_string_parser, whitespace_parser())
    |> Combinators.map(fn [num_str, _ws] ->
      if String.contains?(num_str, ".") or String.contains?(num_str, ["e", "E"]) do
        case Float.parse(num_str) do
          {float_val, <<>>} -> float_val
          _ -> {:error, "Failed to parse float: #{inspect(num_str)}"}
        end
      else
        case Integer.parse(num_str) do
          {int_val, <<>>} -> int_val
          _ -> {:error, "Failed to parse integer: #{inspect(num_str)}"}
        end
      end
    end)
  end

  defp space_code(), do: Combinators.char(?\s)
  defp tab_code(), do: Combinators.char(?\t)
  defp newline_code(), do: Combinators.char(?\n)
  defp cr_code(), do: Combinators.char(?\r)

  defp one_whitespace_char_parser() do
    Combinators.choice(
      space_code(),
      Combinators.choice(
        tab_code(),
        Combinators.choice(newline_code(), cr_code())
      )
    )
  end

  defp whitespace_parser() do
    Combinators.ignore(Combinators.many(one_whitespace_char_parser()))
  end

  defp hex_digit_parser() do
    digit_codes = Enum.to_list(?0..?9)
    lower_hex_codes = Enum.to_list(?a..?f)
    upper_hex_codes = Enum.to_list(?A..?F)

    all_hex_codes = digit_codes ++ lower_hex_codes ++ upper_hex_codes

    Combinators.one_in(all_hex_codes)
  end

  def unicode_escape_parser() do
    four_hex_digits_parser =
      Combinators.sequence([
        hex_digit_parser(),
        hex_digit_parser(),
        hex_digit_parser(),
        hex_digit_parser()
      ])

    Combinators.map(
      Combinators.sequence([
        Combinators.char(?\\),
        Combinators.char(?u),
        four_hex_digits_parser
      ]),
      fn
        [_, _, nested_hex_digits_list] ->
          code_point = String.to_integer(Enum.join(List.flatten(nested_hex_digits_list)), 16)

          <<code_point::utf8>>

        s ->
          raise "Unexpected result structure in unicode_escape_parser map transformation: #{inspect(s)}"
      end
    )
  end

  def simple_escape_parser() do
    allowed_escape_codes = [
      ?\",
      ?\\,
      ?/,
      ?b,
      ?f,
      ?n,
      ?r,
      ?t
    ]

    Combinators.map(
      Combinators.sequence(
        Combinators.char(?\\),
        Combinators.one_in(allowed_escape_codes)
      ),
      fn [_backslash_result, escape_char_string] ->
        case escape_char_string do
          "\"" -> "\""
          "\\" -> "\\"
          "/" -> "/"
          "b" -> "\b"
          "f" -> "\f"
          "n" -> "\n"
          "r" -> "\r"
          "t" -> "\t"
          _ -> raise "Unexpected simple escape character: #{inspect(escape_char_string)}"
        end
      end
    )
  end

  def string_char_parser() do
    Combinators.satisfy(
      Combinators.any_char(),
      fn char_string ->
        code_point = hd(String.to_charlist(char_string))

        cond do
          code_point in [?", ?\\] -> false
          code_point <= 0x1F -> false
          true -> true
        end
      end
    )
  end

  def any_string_content_char_parser() do
    Combinators.choice([simple_escape_parser(), unicode_escape_parser(), string_char_parser()])
  end

  def json_string_parser() do
    full_quoted_string_sequence =
      Combinators.sequence([
        Combinators.char(?\"),
        Combinators.many(any_string_content_char_parser()),
        Combinators.char(?\")
      ])

    string_value_parser =
      Combinators.map(
        full_quoted_string_sequence,
        fn [_opening_quote, content_chars_list, _closing_quote] ->
          Enum.join(content_chars_list)
        end
      )

    Combinators.sequence(string_value_parser, whitespace_parser())
    |> Combinators.map(fn [str_val, _ws] -> str_val end)
  end

  def boolean_parser() do
    boolean_value_parser =
      Combinators.map(
        Combinators.choice(Combinators.string("true"), Combinators.string("false")),
        fn string_value ->
          case string_value do
            "true" ->
              true

            "false" ->
              false

            _ ->
              raise "Internal error: boolean parser matched unexpected string: #{inspect(string_value)}"
          end
        end
      )

    Combinators.sequence(boolean_value_parser, whitespace_parser())
    |> Combinators.map(fn [bool_val, _ws] -> bool_val end)
  end

  def null_parser() do
    p =
      Combinators.map(
        Combinators.string("null"),
        fn string_value ->
          case string_value do
            "null" ->
              nil

            _ ->
              raise "Internal error: null parser matched unexpected string: #{inspect(string_value)}"
          end
        end
      )

    Combinators.sequence(p, whitespace_parser())
    |> Combinators.map(fn [nil_value, _ws] -> nil_value end)
  end

  def value_parser() do
    Combinators.choice([
      json_string_parser(),
      number_parser(),
      boolean_parser(),
      null_parser(),
      Combinators.lazy(fn -> array_parser() end),
      Combinators.lazy(fn -> object_parser() end)
    ])
  end

  def comma_separator_parser() do
    raw_comma_parser = Combinators.char(?,)

    Combinators.sequence([whitespace_parser(), raw_comma_parser, whitespace_parser()])
    |> Combinators.map(fn [_ws1, _comma, _ws2] -> nil end)
  end

  def array_parser() do
    list_of_values_content_parser =
      Combinators.separated_by_zero_or_more(value_parser(), comma_separator_parser())

    lbracket_parser = Combinators.char(?[)
    rbracket_parser = Combinators.char(?])

    raw_array_sequence_parser =
      Combinators.sequence([
        lbracket_parser,
        whitespace_parser(),
        list_of_values_content_parser,
        whitespace_parser(),
        rbracket_parser
      ])

    array_value_parser =
      Combinators.map(
        raw_array_sequence_parser,
        fn [_lbracket, _ws_after_lbracket, values_list, _ws_before_rbracket, _rbracket] ->
          values_list
        end
      )

    Combinators.sequence(array_value_parser, whitespace_parser())
    |> Combinators.map(fn [array, _ws] -> array end)
  end

  defp colon_separator_parser() do
    Combinators.sequence([whitespace_parser(), Combinators.char(?:), whitespace_parser()])
    |> Combinators.map(fn [_ws1, _colon, _ws2] -> nil end)
  end

  defp key_value_pair_parser() do
    raw_key_value_pair =
      Combinators.sequence([json_string_parser(), colon_separator_parser(), value_parser()])

    Combinators.map(
      raw_key_value_pair,
      fn [key_string, _colon_sep, value_data] ->
        {key_string, value_data}
      end
    )
  end

  def object_parser() do
    lcurly_parser = Combinators.char(?{)
    rcurly_parser = Combinators.char(?})

    list_of_key_value_pairs_content_parser =
      Combinators.separated_by_zero_or_more(
        key_value_pair_parser(),
        comma_separator_parser()
      )

    raw_object_sequence_parser =
      Combinators.sequence([
        lcurly_parser,
        whitespace_parser(),
        list_of_key_value_pairs_content_parser,
        whitespace_parser(),
        rcurly_parser
      ])

    object_value_parser =
      Combinators.map(
        raw_object_sequence_parser,
        fn [_lcurly, _ws_after_lcurly, key_value_pairs_list, _ws_before_rcurly, _rcurly] ->
          Map.new(key_value_pairs_list)
        end
      )

    Combinators.sequence(object_value_parser, whitespace_parser())
    |> Combinators.map(fn [object_map, _ws] -> object_map end)
  end
end
