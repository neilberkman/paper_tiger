defmodule PaperTiger.Store.SetupIntents do
  @moduledoc """
  ETS-backed storage for SetupIntent resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_setup_intents` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, setup_intent} = PaperTiger.Store.SetupIntents.get("seti_123")

      # Serialized write
      setup_intent = %{id: "seti_123", customer: "cus_123", ...}
      {:ok, setup_intent} = PaperTiger.Store.SetupIntents.insert(setup_intent)

      # Query helpers (direct ETS access)
      setup_intents = PaperTiger.Store.SetupIntents.find_by(:customer, "cus_123")
  """

  use PaperTiger.Store,
    table: :paper_tiger_setup_intents,
    resource: "setup_intent",
    prefix: "seti"
end
