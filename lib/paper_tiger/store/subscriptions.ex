defmodule PaperTiger.Store.Subscriptions do
  @moduledoc """
  ETS-backed storage for Subscription resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_subscriptions` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, subscription} = PaperTiger.Store.Subscriptions.get("sub_123")

      # Serialized write
      subscription = %{id: "sub_123", customer: "cus_123", status: "active", ...}
      {:ok, subscription} = PaperTiger.Store.Subscriptions.insert(subscription)

      # Query helpers (direct ETS access)
      subscriptions = PaperTiger.Store.Subscriptions.find_by(:customer, "cus_123")
      active_subscriptions = PaperTiger.Store.Subscriptions.find_by(:status, "active")
  """

  use PaperTiger.Store,
    table: :paper_tiger_subscriptions,
    resource: "subscription",
    prefix: "sub"

  @deprecated "Use find_by/2"
  def find_by_customer(value), do: find_by(:customer, value)

  @deprecated "Use find_by/2"
  def find_active, do: find_by(:status, "active")
end
