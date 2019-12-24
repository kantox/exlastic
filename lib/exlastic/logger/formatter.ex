defmodule Exlastic.Logger.Formatter do
  @moduledoc false

  @protected %{
    password: "[********]"
  }

  @spec format(
          level :: Logger.level(),
          message :: Logger.message(),
          timestamp :: binary(),
          metadata :: Logger.metadata()
        ) :: binary()
  def format(level, message, timestamp, metadata) do
    "[🎬] #{timestamp} #{binary!(metadata)} [#{level}] #{binary!(message)}\n"
  rescue
    err ->
      inputs = inspect({level, message, timestamp, metadata})
      "[🎬] could not format message: #{inputs}\n#{inspect(err)}"
  end

  @spec binary!(term :: map() | keyword()) :: binary()
  defp binary!(%{} = term), do: binary!(Map.to_list(term))

  defp binary!(term) when is_list(term) do
    term
    |> Keyword.keys()
    |> Enum.map(&do_binary(term, &1))
    |> Enum.join(" ")
  end

  @spec do_binary(term :: keyword(), key :: atom()) :: binary()
  defp do_binary(term, key) do
    value = if is_nil(term[key]), do: "nil", else: term[key]

    value =
      Map.get(
        @protected,
        key,
        if(String.Chars.impl_for(value), do: to_string(value), else: inspect(value))
      )

    "#{key}=#{value}"
  end
end
