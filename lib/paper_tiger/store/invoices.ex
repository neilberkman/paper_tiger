defmodule PaperTiger.Store.Invoices do
  @moduledoc """
  ETS-backed storage for Invoice resources.

  Uses the shared store pattern via `use PaperTiger.Store` which provides:
  - GenServer wraps ETS table
  - Reads go directly to ETS (concurrent, fast)
  - Writes go through GenServer (serialized, safe)

  ## Architecture

  - **ETS Table**: `:paper_tiger_invoices` (public, read_concurrency: true)
  - **GenServer**: Serializes writes, handles initialization
  - **Shared Implementation**: All CRUD operations via PaperTiger.Store

  ## Examples

      # Direct read (no GenServer bottleneck)
      {:ok, invoice} = PaperTiger.Store.Invoices.get("in_123")

      # Serialized write
      invoice = %{id: "in_123", customer: "cus_123", status: "paid", ...}
      {:ok, invoice} = PaperTiger.Store.Invoices.insert(invoice)

      # Query helpers (direct ETS access)
      invoices = PaperTiger.Store.Invoices.find_by(:customer, "cus_123")
      invoices = PaperTiger.Store.Invoices.find_by(:status, "paid")
  """

  use PaperTiger.Store,
    table: :paper_tiger_invoices,
    resource: "invoice",
    prefix: "in"

  @doc """
  Returns all invoices without pagination.

  **Direct ETS access** - does not go through GenServer.
  """
  @spec all() :: [map()]
  def all do
    namespace = PaperTiger.Connect.storage_namespace()

    :ets.match_object(@table, {{namespace, :_}, :_})
    |> Enum.map(fn {_key, invoice} -> invoice end)
  end

  @deprecated "Use find_by/2"
  def find_by_customer(value), do: find_by(:customer, value)

  @deprecated "Use find_by/2"
  def find_by_subscription(value), do: find_by(:subscription, value)

  @deprecated "Use find_by/2"
  def find_by_status(value), do: find_by(:status, value)
end
