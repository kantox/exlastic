defmodule Exlastic.Logger.Item do
  @moduledoc false

  defstruct [:timestamp, :level, :message, :type, metadata: [], context: %{}]

  @type t :: %__MODULE__{
          timestamp: DateTime.t(),
          level: Logger.level(),
          message: Logger.message(),
          type: atom(),
          metadata: Logger.metadata(),
          context: map()
        }

  @doc """
  Creates a new `Item` struct
  """
  @spec create(
          timestamp :: DateTime.t(),
          level :: Logger.level(),
          message :: Logger.message(),
          metadata :: keyword()
        ) :: t()
  def create(timestamp \\ nil, level, message, metadata \\ []) do
    message = Jason.decode!(message, keys: :atoms)
    {context, message} = Map.pop(message, :context)
    {explicit_metadata, message} = Map.pop(message, :metadata)
    {type, message} = Map.pop(message, :type, :default)

    metadata = Keyword.merge(metadata, Map.to_list(explicit_metadata))

    %__MODULE__{
      timestamp: fix_timestamp(timestamp),
      level: level,
      type: type,
      message: message,
      metadata: Keyword.update(metadata, :pid, inspect(self()), &inspect/1),
      context: context
    }
  end

  @spec fix_timestamp(timestamp :: nil | :calendar.datetime()) :: binary()
  @doc false
  defp fix_timestamp(nil),
    do: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  defp fix_timestamp({{_, _, _} = d, {h, m, s, _ms}}), do: fix_timestamp({d, {h, m, s}})

  defp fix_timestamp({{_, _, _}, {_, _, _}} = timestamp) do
    with {:ok, timestamp} <- NaiveDateTime.from_erl(timestamp),
         result <- NaiveDateTime.to_iso8601(timestamp) do
      "#{result}Z"
    end
  end
end
