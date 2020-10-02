defmodule Test.Support.Mox do
  defmacro __using__(_opts) do
    quote do
      import Mox
      setup :set_mox_global
      setup :verify_on_exit!
    end
  end
end
