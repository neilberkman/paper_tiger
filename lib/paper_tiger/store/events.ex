defmodule PaperTiger.Store.Events do
  @moduledoc """
  ETS-backed storage for Event resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_events` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, event} = PaperTiger.Store.Events.get("evt_123")

      # Serialized write
      event = %{id: "evt_123", type: "payment_intent.succeeded", ...}
      {:ok, event} = PaperTiger.Store.Events.insert(event)

      # Query helpers (direct ETS access)
      events = PaperTiger.Store.Events.find_by(:type, "payment_intent.succeeded")
  """

  use PaperTiger.Store,
    table: :paper_tiger_events,
    resource: "event",
    prefix: "evt"

  @deprecated "Use find_by/2"
  def find_by_type(value), do: find_by(:type, value)
end
