defmodule PaperTiger.Store.CheckoutSessions do
  @moduledoc """
  ETS-backed storage for Checkout Session resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_checkout_sessions` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, session} = PaperTiger.Store.CheckoutSessions.get("cs_123")

      # Serialized write
      session = %{id: "cs_123", customer: "cus_123", ...}
      {:ok, session} = PaperTiger.Store.CheckoutSessions.insert(session)

      # Query helpers (direct ETS access)
      sessions = PaperTiger.Store.CheckoutSessions.find_by(:customer, "cus_123")
  """

  use PaperTiger.Store,
    table: :paper_tiger_checkout_sessions,
    resource: "checkout_session",
    prefix: "cs"

  @deprecated "Use find_by/2"
  def find_by_customer(value), do: find_by(:customer, value)
end
