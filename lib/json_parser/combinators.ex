defmodule JsonParser.Combinators do
  def char(expected_char_code_point) do
    fn input -> JsonParser.CharParser.char(expected_char_code_point, input) end
  end

  def string(expected_string) do
    fn input -> JsonParser.StringParser.string(expected_string, input) end
  end

  def digit() do
    &JsonParser.DigitParser.digit/1
  end

  def any_char() do
    &JsonParser.AnyCharParser.anychar/1
  end

  def map(parser_func, transform_func) do
    fn input ->
      case parser_func.(input) do
        {:ok, result, remaining} ->
          transformed_result = transform_func.(result)
          {:ok, transformed_result, remaining}

        error_tuple ->
          error_tuple
      end
    end
  end

  @doc """
  Applies a list of parsers in sequence.
  If all parsers succeed, returns {:ok, [results], remaining_input}.
  If any parser fails, immediately propagates the failure.
  """
  def sequence(parsers) when is_list(parsers) do
    fn initial_input ->
      reduction_result =
        Enum.reduce_while(parsers, {:ok, [], initial_input}, fn parser, acc ->
          case acc do
            {:ok, current_results_list, current_input} ->
              case parser.(current_input) do
                {:ok, new_result, new_remaining} ->
                  {:cont, {:ok, [new_result | current_results_list], new_remaining}}

                error_tuple ->
                  {:halt, error_tuple}
              end

            error_tuple ->
              {:halt, error_tuple}
          end
        end)

      case reduction_result do
        {:ok, collected_results, final_remaining} ->
          {:ok, Enum.reverse(collected_results), final_remaining}

        error_tuple ->
          error_tuple
      end
    end
  end

  def sequence(parser1, parser2) do
    sequence([parser1, parser2])
  end

  @doc """
  Applies a list of parsers in order.
  Returns the result of the first parser that succeeds.
  If all parsers fail, returns the failure of the last parser attempted.
  """
  def choice(parsers) when is_list(parsers) do
    fn initial_input ->
      reduction_result =
        Enum.reduce_while(parsers, {:fail, :no_choices_attempted, initial_input}, fn parser,
                                                                                     _last_error_acc ->
          case parser.(initial_input) do
            {:ok, result, remaining} ->
              {:halt, {:ok, result, remaining}}

            error_tuple ->
              {:cont, error_tuple}
          end
        end)

      case reduction_result do
        {:halt, {:ok, result, remaining}} ->
          {:ok, result, remaining}

        error_tuple ->
          error_tuple
      end
    end
  end

  def choice(parser1, parser2) do
    choice([parser1, parser2])
  end

  def many(parser_func) do
    fn input ->
      do_many = fn do_many, current_input, acc_results ->
        case parser_func.(current_input) do
          {:ok, result, remaining} ->
            new_acc_results = [result | acc_results]
            do_many.(do_many, remaining, new_acc_results)

          _ ->
            {:ok, Enum.reverse(acc_results), current_input}
        end
      end

      do_many.(do_many, input, [])
    end
  end

  def some(parser_func) do
    fn input ->
      case parser_func.(input) do
        {:ok, result1, remaining} ->
          {:ok, result2, remaining} = many(parser_func).(remaining)
          {:ok, [result1 | result2], remaining}

        e ->
          e
      end
    end
  end

  def optional(parser_func) do
    fn input ->
      case parser_func.(input) do
        {:ok, result1, remaining} ->
          {:ok, result1, remaining}

        _ ->
          {:ok, nil, input}
      end
    end
  end

  def separated_by(element_parser, separator_parser) do
    separator_then_element_parser =
      sequence(separator_parser, element_parser)
      |> map(fn [_separator_result, element_result] -> element_result end)

    fn input ->
      case element_parser.(input) do
        {:ok, first_element, remaining_after_first_element} ->
          case many(separator_then_element_parser).(remaining_after_first_element) do
            {:ok, rest_of_elements, final_remaining_input} ->
              {:ok, [first_element | rest_of_elements], final_remaining_input}

            error_tuple ->
              error_tuple
          end

        error_tuple ->
          error_tuple
      end
    end
  end

  def separated_by_zero_or_more(element_parser, separator_parser) do
    fn input ->
      case separated_by(element_parser, separator_parser).(input) do
        {:ok, result, remaining} -> {:ok, result, remaining}
        _ -> {:ok, [], input}
      end
    end
  end

  def ignore(parser) do
    fn input ->
      case parser.(input) do
        {:ok, _, remaining} -> {:ok, nil, remaining}
        e -> e
      end
    end
  end

  def one_in(expected_code_points) when is_list(expected_code_points) do
    if Enum.empty?(expected_code_points) do
      raise ArgumentError, "Combinators.one_in/1 expects a non-empty list of code points"
    end

    initial_parser = char(hd(expected_code_points))

    Enum.drop(expected_code_points, 1)
    |> Enum.reduce(initial_parser, fn char_code_point, acc_parser ->
      choice(acc_parser, char(char_code_point))
    end)
  end

  def satisfy(parser_func, predicate_func) do
    fn input ->
      case parser_func.(input) do
        {:ok, result, remaining} ->
          if predicate_func.(result) do
            {:ok, result, remaining}
          else
            {:fail, {:predicate_failed, result}, input}
          end

        error_tuple ->
          error_tuple
      end
    end
  end

  @doc """
  Creates a parser that lazily evaluates another parser.
  This is used to resolve circular dependencies in grammar definitions (e.g., value -> array -> value).
  `parser_thunk_fun` must be a 0-arity function (a thunk) that returns the actual parser function.
  """
  def lazy(parser_thunk_fun) when is_function(parser_thunk_fun, 0) do
    fn input ->
      actual_parser = parser_thunk_fun.()
      actual_parser.(input)
    end
  end
end
