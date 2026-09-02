defmodule PaperTiger.Store.Sources do
  @moduledoc """
  ETS-backed storage for Source resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_sources` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, source} = PaperTiger.Store.Sources.get("src_123")

      # Serialized write
      source = %{id: "src_123", customer: "cus_123", ...}
      {:ok, source} = PaperTiger.Store.Sources.insert(source)

      # Query helpers (direct ETS access)
      sources = PaperTiger.Store.Sources.find_by(:customer, "cus_123")
  """

  use PaperTiger.Store,
    table: :paper_tiger_sources,
    resource: "source",
    prefix: "src"

  @deprecated "Use find_by/2"
  def find_by_customer(value), do: find_by(:customer, value)
end
