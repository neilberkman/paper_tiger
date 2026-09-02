defmodule PaperTiger.Store.BankAccounts do
  @moduledoc """
  ETS-backed storage for BankAccount resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_bank_accounts` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, bank_account} = PaperTiger.Store.BankAccounts.get("ba_123")

      # Serialized write
      bank_account = %{id: "ba_123", customer: "cus_123", ...}
      {:ok, bank_account} = PaperTiger.Store.BankAccounts.insert(bank_account)

      # Query helpers (direct ETS access)
      bank_accounts = PaperTiger.Store.BankAccounts.find_by(:customer, "cus_123")
  """

  use PaperTiger.Store,
    table: :paper_tiger_bank_accounts,
    resource: "bank_account",
    prefix: "ba"
end
