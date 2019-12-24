defmodule Exlastic do
  @moduledoc """
  Documentation for Exlastic.
  """

  require Logger

  @type entity :: binary() | atom()

  @doc """
  Geberic log function.

  ## Examples


  """

  # @spec log(level :: Logger.level(), tag :: atom(), entity :: entity(), payload :: keyword()) ::
  #         {:ok, integer()}
  defmacro log(level, tag \\ nil, entity, payload) do
    %{module: module, function: fun, file: file, line: line, context: context} = __CALLER__

    quote do
      event =
        if is_nil(unquote(tag)),
          do: [:exlastic, unquote(level)],
          else: [:exlastic, unquote(tag), unquote(level)]

      now = System.monotonic_time(:microsecond)
      {benchmark, payload} = Keyword.pop(unquote(payload), :benchmark, "N/A")

      :ok =
        :telemetry.execute(
          event,
          %{
            now: now,
            benchmark: benchmark,
            entity: unquote(entity),
            metadata: %{
              context: unquote(context),
              module: unquote(module),
              function: unquote(fun),
              file: unquote(file),
              line: unquote(line)
            }
          },
          Map.new(payload)
        )

      {:ok, now}
    end
  end

  @spec bench(
          level :: Logger.level(),
          tag :: atom(),
          entity :: entity(),
          payload_and_do_block :: keyword()
        ) :: any()
  defmacro bench(level, tag \\ nil, entity, payload_and_do_block) do
    {block, payload} = Keyword.pop(payload_and_do_block, :do, :ok)

    quote do
      reference = inspect(make_ref())

      payload =
        unquote(payload)
        |> Keyword.put(:reference, reference)
        |> Keyword.put(:tag, :in)

      {:ok, now} = Exlastic.log(unquote(level), unquote(tag), unquote(entity), payload)

      result = unquote(block)

      payload =
        payload
        |> Keyword.put(:tag, :out)
        |> Keyword.put(:benchmark, System.monotonic_time(:microsecond) - now)

      {:ok, _} = Exlastic.log(unquote(level), unquote(tag), unquote(entity), payload)

      result
    end
  end
end
