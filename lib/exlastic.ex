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
  defmacro log(level, payload) do
    %{module: module, function: fun, file: file, line: line} = _metadata = __CALLER__

    quote do
      # Logger.metadata(request_id: "ABCDEF")
      :telemetry.execute(
        [:exlastic, unquote(level)],
        %{
          now: :erlang.monotonic_time(),
          metadata: %{
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
