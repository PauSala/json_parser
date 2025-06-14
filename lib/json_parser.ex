defmodule JsonParser do
  alias JsonParser.Grammar

  def parse(input) do
    Grammar.object_parser().(input)
  end
end
