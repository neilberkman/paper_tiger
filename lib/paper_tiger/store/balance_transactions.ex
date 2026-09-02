defmodule PaperTiger.Store.BalanceTransactions do
  @moduledoc """
  ETS-backed storage for BalanceTransaction resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_balance_transactions` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, txn} = PaperTiger.Store.BalanceTransactions.get("txn_123")

      # Serialized write
      txn = %{id: "txn_123", source: "ch_123", ...}
      {:ok, txn} = PaperTiger.Store.BalanceTransactions.insert(txn)

      # Query helpers (direct ETS access)
      txns = PaperTiger.Store.BalanceTransactions.find_by(:source, "ch_123")
  """

  use PaperTiger.Store,
    table: :paper_tiger_balance_transactions,
    resource: "balance_transaction",
    prefix: "txn"

  @deprecated "Use find_by/2"
  def find_by_source(value), do: find_by(:source, value)
end
