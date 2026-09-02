defmodule PaperTiger.Store.Refunds do
  @moduledoc """
  ETS-backed storage for Refund resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_refunds` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, refund} = PaperTiger.Store.Refunds.get("re_123")

      # Serialized write
      refund = %{id: "re_123", charge: "ch_123", ...}
      {:ok, refund} = PaperTiger.Store.Refunds.insert(refund)

      # Query helpers (direct ETS access)
      refunds = PaperTiger.Store.Refunds.find_by(:charge, "ch_123")
  """

  use PaperTiger.Store,
    table: :paper_tiger_refunds,
    resource: "refund",
    prefix: "re"
end
