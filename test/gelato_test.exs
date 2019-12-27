defmodule Gelato.Test do
  use ExUnit.Case
  import ExUnit.CaptureIO
  require Gelato

  doctest Gelato

  test "accepts :app as an index" do
    assert {:ok, _} = Gelato.info(:app, "measures", foo: 42)
  end

  test "#bench/4 executes a block" do
    assert capture_io(fn ->
             Gelato.bench(:info, "measures", foo: 42, do: IO.puts("block executed"))
           end) =~ "block executed"
  end

  test "#log/4 allows to discard process info" do
    assert capture_io(fn ->
             Gelato.log(:info, "measures", foo: 42, process_info: true)
           end) =~ ~r/%{\s*garbage_collection:/

    refute capture_io(fn ->
             Gelato.log(:info, "measures", foo: 42, process_info: "N/A")
           end) =~ ~r/%{\s*garbage_collection:/
  end
end
