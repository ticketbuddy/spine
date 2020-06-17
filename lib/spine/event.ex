defmodule Spine.Event do
  defmacro defevent(name, attributes) do
    quote do
      defmodule unquote(name) do
        defstruct unquote(attributes)
        @attributes unquote(attributes)
      end
    end
  end
end
