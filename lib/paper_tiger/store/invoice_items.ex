defmodule PaperTiger.Store.InvoiceItems do
  @moduledoc """
  ETS-backed storage for InvoiceItem resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_invoice_items` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, invoice_item} = PaperTiger.Store.InvoiceItems.get("ii_123")

      # Serialized write
      invoice_item = %{id: "ii_123", invoice: "in_123", customer: "cus_123", ...}
      {:ok, invoice_item} = PaperTiger.Store.InvoiceItems.insert(invoice_item)

      # Query helpers (direct ETS access)
      invoice_items = PaperTiger.Store.InvoiceItems.find_by(:invoice, "in_123")
  """

  use PaperTiger.Store,
    table: :paper_tiger_invoice_items,
    resource: "invoice_item",
    prefix: "ii"
end
