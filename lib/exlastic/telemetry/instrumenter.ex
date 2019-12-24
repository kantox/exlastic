defmodule Exlastic.Telemetry.Instrumenter do
  @moduledoc false

  require Logger
  @levels ~w|debug info warn error|a

  def setup do
    otp_app = Application.get_env(:exlastic, :otp_app, :exlastic)

    custom_events =
      :exlastic
      |> Application.get_env(:events, [])
      |> Enum.flat_map(&Enum.map(@levels, fn lvl -> [:exlastic, &1, lvl] end))

    events = Enum.map(@levels, &[:exlastic, &1]) ++ custom_events

    :telemetry.attach_many("#{otp_app}-instrumenter", events, &handle_event/4, nil)
  end

  def handle_event(event, measurements, context, _config) do
    {entity, measurements} = Map.pop(measurements, :entity, "default")
    {metadata, measurements} = Map.pop(measurements, :metadata)

    content = %{
      context: context,
      measurements: measurements,
      metadata: metadata,
      entity: entity
    }

    {type, level} =
      case event do
        [:exlastic, level] when level in @levels -> {:default, level}
        [:exlastic, type, level] when level in @levels -> {type, level}
      end

    Logger.log(level, fn ->
      content
      |> Map.put(:type, type)
      |> Jason.encode_to_iodata!()
    end)
  end
end
