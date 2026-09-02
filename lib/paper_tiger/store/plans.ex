defmodule PaperTiger.Store.Plans do
  @moduledoc """
  ETS-backed storage for Plan resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_plans` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, plan} = PaperTiger.Store.Plans.get("plan_123")

      # Serialized write
      plan = %{id: "plan_123", product: "prod_123", ...}
      {:ok, plan} = PaperTiger.Store.Plans.insert(plan)

      # Query helpers (direct ETS access)
      plans = PaperTiger.Store.Plans.find_by(:product, "prod_123")
      active_plans = PaperTiger.Store.Plans.find_by(:active, true)
  """

  use PaperTiger.Store,
    table: :paper_tiger_plans,
    resource: "plan",
    prefix: "plan"

  @deprecated "Use find_by/2"
  def find_by_product(value), do: find_by(:product, value)

  @deprecated "Use find_by/2"
  def find_active, do: find_by(:active, true)
end
