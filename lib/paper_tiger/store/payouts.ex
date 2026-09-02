defmodule PaperTiger.Store.Payouts do
  @moduledoc """
  ETS-backed storage for Payout resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_payouts` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, payout} = PaperTiger.Store.Payouts.get("po_123")

      # Serialized write
      payout = %{id: "po_123", status: "pending", ...}
      {:ok, payout} = PaperTiger.Store.Payouts.insert(payout)

      # Query helpers (direct ETS access)
      payouts = PaperTiger.Store.Payouts.find_by(:status, "paid")
  """

  use PaperTiger.Store,
    table: :paper_tiger_payouts,
    resource: "payout",
    prefix: "po"

  @deprecated "Use find_by/2"
  def find_by_status(value), do: find_by(:status, value)
end
