defmodule Exlastic.Telemetry.Instrumenter do
  require Logger
  @levels ~w|debug info warn error|a

  def setup do
    otp_app = Application.get_env(:exlastic, :otp_app, :exlastic)

    custom_events =
      :exlastic
      |> Application.get_env(:events, [])
      |> Enum.map(&Enum.map(@levels, fn lvl -> [:exlastic, &1, lvl] end))

    events = Enum.map(@levels, &[:exlastic, &1]) ++ custom_events

    :telemetry.attach_many("#{otp_app}-instrumenter", events, &handle_event/4, nil)
  end

  def handle_event(event, measurements, metadata, config) do
    IO.inspect({event, measurements, metadata, config})
    # Timber.add_context(measurements: measurements, event: Enum.join(event, "."))

    {title, metadata} = Map.pop(metadata, :title, :data)
    {text, metadata} = Map.pop(metadata, :text, "Telemetry Event")

    content =
      Jason.encode_to_iodata!(%{
        measurements: measurements,
        context: metadata,
        title: title,
        text: text
      })

    case event do
      [:exlastic, level] when level in @levels ->
        Logger.log(level, fn -> content end)

      [:exlastic, type, level] when level in @levels ->
        Logger.log(level, fn -> Map.put(content, :type, type) end)
    end
  end
end
