defmodule Exlastic do
  @moduledoc """
  Documentation for Exlastic.
  """

  require Logger

  @type entity :: binary() | atom()

  @doc """
  Geberic log function.

  ## Examples

      iex> Exlastic.hello()
      :world

  """

  @spec log(level :: Logger.level(), tag :: atom(), entity :: entity(), payload :: keyword()) ::
          :ok
  defmacro log(level, tag \\ nil, entity, payload) do
    %{module: module, function: fun, file: file, line: line, context: context, vars: vars} =
      _metadata = __CALLER__

    quote do
      # Logger.metadata(request_id: "ABCDEF")
      event =
        if is_nil(unquote(tag)),
          do: [:exlastic, unquote(level)],
          else: [:exlastic, unquote(tag), unquote(level)]

      :telemetry.execute(
        event,
        %{
          now: :erlang.monotonic_time(),
          entity: unquote(entity),
          metadata: %{
            vars: Map.new(unquote(vars)),
            context: unquote(context),
            module: unquote(module),
            function: unquote(fun),
            file: unquote(file),
            line: unquote(line)
          }
        },
        Map.new(unquote(payload))
      )
    end
  end

  @spec bench(
          level :: Logger.level(),
          tag :: atom(),
          entity :: entity(),
          payload_and_do_block :: keyword()
        ) :: any()
  defmacro bench(level, tag \\ nil, entity, payload_and_do_block) do
    {block, payload} = Keyword.pop(payload_and_do_block, :do, :ok) |> IO.inspect(label: "TM")

    quote do
      reference = inspect(make_ref())

      payload =
        unquote(payload)
        |> Keyword.put(:reference, reference)
        |> Keyword.put(:tag, :in)

      :ok = Exlastic.log(unquote(level), unquote(tag), unquote(entity), payload)

      result = unquote(block)

      payload = Keyword.put(payload, :tag, :out)

      :ok = Exlastic.log(unquote(level), unquote(tag), unquote(entity), payload)

      result
    end
  end
end
