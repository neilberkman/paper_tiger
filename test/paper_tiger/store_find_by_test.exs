defmodule PaperTiger.StoreFindByTest do
  use ExUnit.Case, async: true

  import PaperTiger.Test

  alias PaperTiger.Store.Customers

  setup :checkout_paper_tiger

  setup do
    {:ok, pro} = Customers.insert(%{id: "cus_pro", metadata: %{seats: 3, tier: "pro"}, object: "customer"})
    {:ok, free} = Customers.insert(%{id: "cus_free", metadata: %{}, object: "customer"})
    {:ok, _} = Customers.insert(%{id: "cus_none", object: "customer"})
    %{free: free, pro: pro}
  end

  test "matches a scalar field" do
    assert [%{id: "cus_pro"}] = Customers.find_by(:id, "cus_pro")
  end

  test "compares map values with strict equality rather than a partial match", %{free: free} do
    assert Customers.find_by(:metadata, %{}) == [free]
    assert Customers.find_by(:metadata, %{tier: "pro"}) == []
    assert [%{id: "cus_pro"}] = Customers.find_by(:metadata, %{seats: 3, tier: "pro"})
  end

  test "does not treat match-pattern atoms as wildcards" do
    assert Customers.find_by(:metadata, :_) == []
    assert Customers.find_by(:id, :"$1") == []
  end

  test "returns nothing for nil" do
    assert Customers.find_by(:metadata, nil) == []
  end

  test "stays inside the current namespace" do
    PaperTiger.Connect.put_account("acct_other")
    assert Customers.find_by(:id, "cus_pro") == []

    {:ok, _} = Customers.insert(%{id: "cus_pro", metadata: %{}, object: "customer"})
    assert [%{metadata: %{}}] = Customers.find_by(:id, "cus_pro")

    PaperTiger.Connect.clear_account()
    assert [%{metadata: %{tier: "pro"}}] = Customers.find_by(:id, "cus_pro")
  end
end
