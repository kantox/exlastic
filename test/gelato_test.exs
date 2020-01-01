defmodule Gelato.Test do
  use ExUnit.Case
  import ExUnit.CaptureIO
  alias Gelato.Test.DDL.Test

  require Logger
  require Gelato

  doctest Gelato

  test "accepts :app as an index" do
    assert :ok = Logger.info("app", entity: "measures", foo: 42)
  end

  test "#bench/4 executes a block" do
    assert capture_io(fn ->
             Gelato.bench(:info, "app", foo: 42, do: IO.puts("block executed"))
           end) =~ "block executed"
  end

  test "#log/4 allows to discard process info" do
    Logger.log(:info, "default", entity: "measures", foo: 42, process_info: true)
    Logger.log(:info, "default", entity: "measures", foo: 42, process_info: "N/A")
  end

  test "#defdelegatelog/2 accepts arguments and works" do
    assert {:ok, [foo: 42]} = Test.yo_test(foo: 42)
  end
end
