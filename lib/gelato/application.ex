defmodule Gelato.Application do
  @moduledoc false

  use Application

  alias Gelato.Telemetry.Instrumenter

  def start(_type, _args) do
    children = []

    Instrumenter.setup()

    opts = [strategy: :one_for_one, name: Gelato.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
