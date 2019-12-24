defmodule Exlastic.Logger.Formatter do
  @protected %{
    request_id: "[********]"
  }

  def format(level, message, timestamp, metadata) do
    "##### #{timestamp!(timestamp)} #{metadata!(metadata)} [#{level}] #{metadata!(message)}\n"
  rescue
    # {:debug, "Starting Application...",
    #  {{2019, 12, 23}, {13, 30, 15, 464}},
    #  [pid: #PID<0.202.0>, line: 19, function: "log/0", module: Exlastic, file: "lib/exlastic.ex", application: :exlastic, request_id: "ABCDEF"]}
    err ->
      "could not format message: #{inspect({level, message, timestamp, metadata})}\n#{
        inspect(err)
      }"
  end

  defp metadata!(%{} = md), do: metadata!(Map.to_list(md))

  defp metadata!(md) when is_list(md) do
    md
    |> Keyword.keys()
    |> Enum.map(&do_metadata(md, &1))
    |> Enum.join(" ")
  end

  defp do_metadata(metadata, key) do
    value = if is_nil(metadata[key]), do: "nil", else: metadata[key]

    value =
      Map.get(
        @protected,
        key,
        if(String.Chars.impl_for(value), do: to_string(value), else: inspect(value))
      )

    "#{key}=#{value}"
  end

  defp timestamp!({date, {hh, mm, ss, ms}}) do
    with {:ok, timestamp} <- NaiveDateTime.from_erl({date, {hh, mm, ss}}, {ms * 1000, 3}),
         result <- NaiveDateTime.to_iso8601(timestamp) do
      "#{result}Z"
    end
  end
end
