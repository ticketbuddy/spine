defmodule Test.Support.Mox do
  defmacro __using__(_opts) do
    quote do
      import Mox
      setup :set_mox_from_context
      setup :verify_on_exit!
    end
  end
end
