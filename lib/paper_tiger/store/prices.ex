defmodule PaperTiger.Store.Prices do
  @moduledoc """
  ETS-backed storage for Price resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_prices` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, price} = PaperTiger.Store.Prices.get("price_123")

      # Serialized write
      price = %{id: "price_123", product: "prod_123", active: true, ...}
      {:ok, price} = PaperTiger.Store.Prices.insert(price)

      # Query helpers (direct ETS access)
      prices = PaperTiger.Store.Prices.find_by(:product, "prod_123")
      active_prices = PaperTiger.Store.Prices.find_by(:active, true)
  """

  use PaperTiger.Store,
    table: :paper_tiger_prices,
    resource: "price",
    prefix: "price"

  alias PaperTiger.Store.Plans

  @doc """
  Fetches a price by ID, accepting a legacy plan ID in its place.

  Stripe accepts plan IDs wherever a price ID is expected. A plan comes back
  converted to price shape, with its amount as `unit_amount` and its interval
  under `recurring`.

  **Direct ETS access** - does not go through GenServer.
  """
  @spec get_or_plan(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_or_plan(id) when is_binary(id) do
    with {:error, :not_found} <- get(id),
         {:ok, plan} <- Plans.get(id) do
      {:ok, price_from_plan(plan)}
    end
  end

  defp price_from_plan(plan) do
    %{
      active: plan.active,
      created: plan.created,
      currency: plan.currency,
      id: plan.id,
      livemode: plan.livemode,
      metadata: plan.metadata || %{},
      nickname: plan.nickname,
      object: "price",
      product: plan.product,
      recurring: %{interval: plan.interval, interval_count: plan[:interval_count] || 1},
      type: "recurring",
      unit_amount: plan.amount
    }
  end

  @doc """
  Fetches a price by ID, or builds a minimal placeholder when the ID is unknown.

  Callers that embed a price inside another resource (subscription items,
  checkout line items) commonly receive ad-hoc price IDs that were never
  created. They get a well-formed price object either way. A price map passes
  through unchanged; anything else returns `nil`.

  **Direct ETS access** - does not go through GenServer.
  """
  @spec get_or_placeholder(String.t() | map() | nil) :: map() | nil
  def get_or_placeholder(price_id) when is_binary(price_id) do
    case get_or_plan(price_id) do
      {:ok, price} -> price
      {:error, :not_found} -> placeholder(price_id)
    end
  end

  def get_or_placeholder(%{} = price), do: price
  def get_or_placeholder(_other), do: nil

  defp placeholder(price_id) do
    %{
      active: true,
      currency: "usd",
      id: price_id,
      livemode: false,
      object: "price",
      type: "recurring"
    }
  end

  @deprecated "Use find_by/2"
  def find_by_product(value), do: find_by(:product, value)

  @deprecated "Use find_by/2"
  def find_active, do: find_by(:active, true)
end
