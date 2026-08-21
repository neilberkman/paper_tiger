defmodule PaperTiger.StoreOwnershipTest do
  use ExUnit.Case, async: true

  import PaperTiger.Test

  alias PaperTiger.Store.SubscriptionItems

  setup :checkout_paper_tiger

  setup do
    owned = subscription_item("si_owned", "sub_target", 1)
    foreign = subscription_item("si_foreign", "sub_other", 1)
    {:ok, _owned} = SubscriptionItems.insert(owned)
    {:ok, _foreign} = SubscriptionItems.insert(foreign)
    %{foreign: foreign, owned: owned}
  end

  test "owned lookup does not disclose a foreign child", %{owned: owned} do
    assert {:ok, ^owned} = SubscriptionItems.get_owned(owned.id, :subscription, "sub_target")
    assert {:error, :not_found} = SubscriptionItems.get_owned(owned.id, :subscription, "sub_other")
    assert {:error, :not_found} = SubscriptionItems.get_owned("si_missing", :subscription, "sub_target")
  end

  test "rejects a foreign update", %{foreign: foreign} do
    update = %{foreign | quantity: 9}

    assert {:error, {:not_owned, "si_foreign"}} =
             SubscriptionItems.mutate_owned(:subscription, "sub_target", [{:update, update}])

    assert {:ok, %{quantity: 1, subscription: "sub_other"}} = SubscriptionItems.get(foreign.id)
  end

  test "rejects deletion of a foreign child", %{foreign: foreign} do
    assert {:error, {:not_owned, "si_foreign"}} =
             SubscriptionItems.mutate_owned(:subscription, "sub_target", [{:delete, foreign.id}])

    assert {:ok, ^foreign} = SubscriptionItems.get(foreign.id)
  end

  test "rejects an unknown child ID", %{owned: owned} do
    assert {:error, {:not_found, "si_missing"}} =
             SubscriptionItems.mutate_owned(:subscription, "sub_target", [{:delete, "si_missing"}])

    assert {:ok, ^owned} = SubscriptionItems.get(owned.id)
  end

  test "rejects an insert whose ID already exists without overwriting it", %{owned: owned} do
    replacement = %{owned | quantity: 7}

    assert {:error, {:already_exists, "si_owned"}} =
             SubscriptionItems.mutate_owned(:subscription, "sub_target", [{:insert, replacement}])

    assert {:ok, ^owned} = SubscriptionItems.get(owned.id)
  end

  test "rejects an insert that would overwrite and reparent a foreign child", %{foreign: foreign} do
    replacement = %{foreign | quantity: 7, subscription: "sub_target"}

    assert {:error, {:already_exists, "si_foreign"}} =
             SubscriptionItems.mutate_owned(:subscription, "sub_target", [{:insert, replacement}])

    assert {:ok, ^foreign} = SubscriptionItems.get(foreign.id)
  end

  test "rejects duplicate operation IDs before writing", %{owned: owned} do
    operations = [{:update, %{owned | quantity: 2}}, {:delete, owned.id}]

    assert {:error, {:duplicate_operation, "si_owned"}} =
             SubscriptionItems.mutate_owned(:subscription, "sub_target", operations)

    assert {:ok, ^owned} = SubscriptionItems.get(owned.id)
  end

  test "a mixed valid and invalid batch performs no writes", %{foreign: foreign, owned: owned} do
    operations = [
      {:update, %{owned | quantity: 2}},
      {:update, %{foreign | quantity: 9}},
      {:insert, subscription_item("si_new", "sub_target", 1)}
    ]

    assert {:error, {:not_owned, "si_foreign"}} =
             SubscriptionItems.mutate_owned(:subscription, "sub_target", operations)

    assert {:ok, ^owned} = SubscriptionItems.get(owned.id)
    assert {:ok, ^foreign} = SubscriptionItems.get(foreign.id)
    assert {:error, :not_found} = SubscriptionItems.get("si_new")
  end

  test "rejects reparenting through update", %{owned: owned} do
    reparented = %{owned | subscription: "sub_other"}

    assert {:error, {:not_owned, "si_owned"}} =
             SubscriptionItems.mutate_owned(:subscription, "sub_target", [{:update, reparented}])

    assert {:ok, ^owned} = SubscriptionItems.get(owned.id)
  end

  test "applies a fully valid batch", %{owned: owned} do
    inserted = subscription_item("si_new", "sub_target", 3)

    assert :ok =
             SubscriptionItems.mutate_owned(:subscription, "sub_target", [
               {:update, %{owned | quantity: 2}},
               {:insert, inserted}
             ])

    assert {:ok, %{quantity: 2}} = SubscriptionItems.get(owned.id)
    assert {:ok, ^inserted} = SubscriptionItems.get(inserted.id)
  end

  defp subscription_item(id, subscription, quantity) do
    %{
      created: PaperTiger.now(),
      id: id,
      object: "subscription_item",
      quantity: quantity,
      subscription: subscription
    }
  end
end
