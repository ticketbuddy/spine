defmodule Spine.WishTest do
  use ExUnit.Case
  alias Spine.Wish

  defmodule Shop do
    import Spine.Wish, only: [defwish: 3]

    defwish(CreateOrder, [:order_id, :title], to: Shop.Order)
    defwish(CreateProduct, [product_id: "abc", title: "T-Shirt"], to: Shop.Order)
  end

  test "can initiate a struct" do
    assert %Shop.CreateOrder{} == %Shop.CreateOrder{}
  end

  test "can initiate a struct with defaults" do
    assert %Shop.CreateProduct{} == %Shop.CreateProduct{product_id: "abc", title: "T-Shirt"}
  end

  test "can obtain the aggregate id using first provided attribute" do
    wish = %Shop.CreateOrder{order_id: "abcd"}
    assert "abcd" == Wish.aggregate_id(wish)
  end

  test "can obtain the aggregate handler" do
    wish = %Shop.CreateOrder{order_id: "abcd"}
    assert Shop.Order == Wish.aggregate_handler(wish)
  end

  test "can get aggregate id when a default is given for the key" do
    assert "abc" == Wish.aggregate_id(%Shop.CreateProduct{})
    assert "def" == Wish.aggregate_id(%Shop.CreateProduct{product_id: "def"})
  end
end
