defmodule Gelato.Telemetry.Instrumenter do
  @moduledoc false

  require Logger
  alias Gelato.Logger.Formatter

  @levels ~w|debug info warn error|a
  @uri Application.get_env(:gelato, :uri, "http://127.0.0.1:9200")

  def setup do
    otp_app = Application.get_env(:gelato, :otp_app, :gelato)

    custom_events =
      :gelato
      |> Application.get_env(:events, [])
      |> Kernel.++([:default])
      |> Enum.flat_map(&Enum.map(@levels, fn lvl -> [:gelato, &1, lvl] end))

    events = Enum.map(@levels, &[:gelato, &1]) ++ custom_events

    :telemetry.attach_many("#{otp_app}-instrumenter", events, &handle_event/4, nil)
  end

  def handle_event(event, measurements, context, _config) do
    {entity, measurements} = Map.pop(measurements, :entity, "default")
    {metadata, measurements} = Map.pop(measurements, :metadata, %{})
    {handler, measurements} = Map.pop(measurements, :handler, :elastic)

    {timestamp, measurements} =
      Map.pop(measurements, :timestamp, DateTime.to_iso8601(DateTime.utc_now()) <> "Z")

    uuid = Gelato.UUID.generate()

    {type, level} =
      case event do
        [:gelato] -> {:default, :info}
        [:gelato, level] when level in @levels -> {:default, level}
        [:gelato, type, level] when level in @levels -> {type, level}
      end

    content = %{
      uuid: uuid,
      level: level,
      entity: entity,
      timestamp: timestamp,
      context: context,
      telemetry: measurements,
      metadata: Map.new(metadata)
    }

    json = Jason.encode!(content)

    case handler do
      :elastic ->
        Task.start(fn ->
          result =
            case :httpc.request(
                   :post,
                   {to_charlist(@uri <> "/#{type}/_create/#{uuid}"), [], 'application/json',
                    :erlang.binary_to_list(json)},
                   [],
                   []
                 ) do
              {:ok, {{'HTTP/1.1', 201, 'Created'}, resp, _}} ->
                case for {'location', id} <- resp, do: id do
                  [id] -> {:ok, id}
                  error -> {:error, error}
                end

              error ->
                {:error, error}
            end

          if Mix.env() == :dev, do: IO.inspect(result)
        end)

      :stdout ->
        level
        |> Formatter.format(content, timestamp, metadata)
        |> IO.puts()
    end
  end
end
