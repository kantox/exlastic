defmodule Gelato.Test.DDL.Helper do
  @moduledoc false
  def yo(arg), do: {:ok, arg}
end

defmodule Gelato.Test.DDL.Test do
  @moduledoc false
  use Gelato

  defdelegatelog(yo_test(arg),
    to: Gelato.Test.DDL.Helper,
    as: :yo,
    level: :warn,
    tag: "app",
    entity: :ddl
  )
end
