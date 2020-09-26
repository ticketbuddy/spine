defmodule Spine.Event do
  def encorced_keys(attributes) do
    Enum.reduce(attributes, [], fn
      {_k, _v}, acc -> acc
      attr, acc -> [attr | acc]
    end)
  end

  defmacro defevent(name, attributes) do
    quote do
      defmodule unquote(name) do
        use Spine.Event, attributes: unquote(attributes)
      end
    end
  end

  defmacro __using__(attributes: attributes) do
    quote do
      @enforce_keys Spine.Event.encorced_keys(unquote(attributes))
      defstruct unquote(attributes)
      @attributes unquote(attributes)
    end
  end
end
