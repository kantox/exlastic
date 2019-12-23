defmodule Exlastic.Logger.Backend do
  @moduledoc """
  Logger backend to send logs to `ElasticSearch` engine with a telemetry attached.

  Log events are coming in the following format:

  ```
  { log_level, group_leader, {Logger, message, timestamp, metadata} }
  ```
  """

  @behaviour :gen_event

  defmacrop macro_log(do: block), do: quote(do: unquote(block))

  defp maybe_log(min_level, level, do: block) do
    min_level = Application.get_env(:logger, :compile_time_purge_level, min_level)

    if Logger.Config.compare_levels(level, min_level) != :lt,
      do: macro_log(do: block)
  end

  @type state :: %{
          :name => atom(),
          :base_level => Logger.level()
        }

  @impl :gen_event
  def init(__MODULE__), do: {:ok, configure(__MODULE__)}

  @impl :gen_event
  def handle_event(:flush, state), do: {:ok, state}

  @impl :gen_event
  def handle_event(
        {level, _group_leader, {Logger, message, timestamp, metadata}},
        %{level: min_level} = state
      ) do
    maybe_log min_level, level do
      item =
        Exlastic.Logger.Item.create(timestamp, level, message, metadata)
        |> IO.inspect(label: "ITEM")

      Logger.metadata(item.metadata)

      Exlastic.Logger.Formatter.format(item.level, item.message, item.timestamp, item.metadata)
      |> IO.inspect()
    end

    {:ok, state}
  end

  @impl :gen_event
  def handle_call({:configure, opts}, %{name: name} = state),
    do: {:ok, :ok, configure(name, opts, state)}

  ##############################################################################

  @spec configure(name :: atom(), opts :: keyword(), state :: state()) :: state()
  defp configure(name, opts \\ [], state \\ %{}) when is_map(state) do
    base_level = Application.get_env(:logger, :level, :debug)

    opts =
      :logger
      |> Application.get_env(name, opts)
      |> Map.new()

    state
    |> Map.merge(opts)
    |> Map.put_new(:name, name)
    |> Map.put_new(:level, base_level)
  end
end
