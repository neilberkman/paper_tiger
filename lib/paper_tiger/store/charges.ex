defmodule PaperTiger.Store.Charges do
  @moduledoc """
  ETS-backed storage for Charge resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_charges` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, charge} = PaperTiger.Store.Charges.get("ch_123")

      # Serialized write
      charge = %{id: "ch_123", customer: "cus_123", ...}
      {:ok, charge} = PaperTiger.Store.Charges.insert(charge)

      # Query helpers (direct ETS access)
      charges = PaperTiger.Store.Charges.find_by(:customer, "cus_123")
  """

  use PaperTiger.Store,
    table: :paper_tiger_charges,
    resource: "charge",
    prefix: "ch"

  @deprecated "Use find_by/2"
  def find_by_customer(value), do: find_by(:customer, value)

  @deprecated "Use find_by/2"
  def find_by_payment_intent(value), do: find_by(:payment_intent, value)
end
