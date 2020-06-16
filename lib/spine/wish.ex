defmodule Spine.Wish do
  defmacro defwish(name, attributes, to: aggregate_handler) do
    quote do
      defmodule unquote(name) do
        defstruct unquote(attributes)
        @attributes unquote(attributes)
        @aggregate_handler unquote(aggregate_handler)

        def aggregate_id(wish = %unquote(name){}) do
          Map.get(wish, wish_primary_key())
        end

        def aggregate_handler, do: @aggregate_handler

        def wish_primary_key do
          case List.first(@attributes) do
            {key, _value} -> key
            key -> key
          end
        end
      end
    end
  end

  def aggregate_id(wish) do
    module = wish.__struct__
    module.aggregate_id(wish)
  end

  def aggregate_handler(wish) do
    module = wish.__struct__
    module.aggregate_handler()
  end

  def id_with_prefix(wish) do
    module = wish.__struct__
    prefix = module.aggregate_handler().id_prefix()
    current_id = aggregate_id(wish)

    case Headwater.Aggregate.Id.prefix_id(prefix, current_id) do
      {:ok, prefixed_id} -> {:ok, Map.put(wish, module.wish_primary_key(), prefixed_id)}
      {:warn, :invalid_id} -> {:warn, :invalid_id}
    end
  end
end
