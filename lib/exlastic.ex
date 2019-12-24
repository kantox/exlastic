defmodule Exlastic do
  @moduledoc """
  Documentation for Exlastic.
  """

  require Logger

  @doc """
  Geberic log function.

  ## Examples

      iex> Exlastic.hello()
      :world

  """
  defmacro log(level, tag \\ nil, {entity, payload}) do
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
        unquote(payload)
      )
    end
  end
end
