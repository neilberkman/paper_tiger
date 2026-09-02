defmodule PaperTiger.Store.Cards do
  @moduledoc """
  ETS-backed storage for Card resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_cards` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, card} = PaperTiger.Store.Cards.get("card_123")

      # Serialized write
      card = %{id: "card_123", customer: "cus_123", ...}
      {:ok, card} = PaperTiger.Store.Cards.insert(card)

      # Query helpers (direct ETS access)
      cards = PaperTiger.Store.Cards.find_by(:customer, "cus_123")
  """

  use PaperTiger.Store,
    table: :paper_tiger_cards,
    resource: "card",
    prefix: "card"
end
