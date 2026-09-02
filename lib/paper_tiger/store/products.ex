defmodule PaperTiger.Store.Products do
  @moduledoc """
  ETS-backed storage for Product resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_products` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, product} = PaperTiger.Store.Products.get("prod_123")

      # Serialized write
      product = %{id: "prod_123", name: "Premium Plan", ...}
      {:ok, product} = PaperTiger.Store.Products.insert(product)

      # Query helpers (direct ETS access)
      products = PaperTiger.Store.Products.find_by(:active, true)
  """

  use PaperTiger.Store,
    table: :paper_tiger_products,
    resource: "product",
    prefix: "prod"

  @deprecated "Use find_by/2"
  def find_active, do: find_by(:active, true)
end
