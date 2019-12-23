defmodule Exlastic.Logger.Item do
  @moduledoc false

  defstruct [:timestamp, :level, :message, :event, metadata: [], context: %{}]

  @type t :: %__MODULE__{
          timestamp: DateTime.t(),
          level: Logger.level(),
          message: Logger.message(),
          event: nil | Event.t(),
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
          metadata :: keyword(),
          context: map()
        ) :: t()
  def create(timestamp \\ nil, level, message, metadata \\ [], context \\ %{}) do
    message = Jason.decode!(message) |> IO.inspect(label: "HERE")
    {explicit_metadata, message} = pop_in(message, ["measurements", "metadata"])

    metadata =
      Keyword.merge(
        metadata,
        for({k, v} <- explicit_metadata || %{}, do: {String.to_atom(k), v})
      )

    %__MODULE__{
      timestamp: timestamp || DateTime.utc_now(),
      level: level,
      message: message,
      metadata: metadata,
      context: context
    }
  end
end
