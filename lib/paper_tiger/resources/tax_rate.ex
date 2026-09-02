defmodule PaperTiger.Resources.TaxRate do
  @moduledoc """
  Handles TaxRate resource endpoints.

  ## Endpoints

  - POST   /v1/tax_rates      - Create tax rate
  - GET    /v1/tax_rates/:id  - Retrieve tax rate
  - POST   /v1/tax_rates/:id  - Update tax rate
  - GET    /v1/tax_rates      - List tax rates

  Note: Tax rates cannot be deleted (audit purposes).

  ## TaxRate Object

      %{
        id: "txr_...",
        object: "tax_rate",
        created: 1234567890,
        active: true,
        display_name: "VAT",
        inclusive: false,
        jurisdiction: "EU",
        percentage: 20.0,
        metadata: %{},
        # ... other fields
      }
  """

  import PaperTiger.Resource

  alias PaperTiger.Store.TaxRates

  @doc """
  Creates a new tax rate.

  ## Required Parameters

  - display_name - Tax rate display name (e.g., "VAT")
  - percentage - Tax percentage as decimal (e.g., 20.0 for 20%)
  - inclusive - Whether tax is included in price (boolean)

  ## Optional Parameters

  - active - Whether tax rate is active (default: true)
  - jurisdiction - Geographic jurisdiction (e.g., "EU", "US-CA")
  - metadata - Key-value metadata
  """
  @spec create(Plug.Conn.t()) :: Plug.Conn.t()
  def create(conn) do
    with {:ok, _params} <- validate_params(conn.params, [:display_name, :percentage, :inclusive]),
         tax_rate = build_tax_rate(conn.params),
         {:ok, tax_rate} <- TaxRates.insert(tax_rate) do
      maybe_store_idempotency(conn, tax_rate)

      tax_rate
      |> maybe_expand(conn.params)
      |> then(&json_response(conn, 200, &1))
    else
      {:error, :invalid_params, field} ->
        missing_param_response(conn, field)
    end
  end

  @doc """
  Retrieves a tax rate by ID.
  """
  @spec retrieve(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def retrieve(conn, id), do: retrieve_response(conn, TaxRates, "tax_rate", id)

  @doc """
  Updates a tax rate.

  Note: Tax rates can only have limited fields updated.

  ## Updatable Fields

  - active
  - metadata
  """
  @spec update(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def update(conn, id) do
    update_response(conn, TaxRates, "tax_rate", id, [
      :id,
      :object,
      :created,
      :display_name,
      :percentage,
      :inclusive,
      :jurisdiction
    ])
  end

  @doc """
  Lists all tax rates with pagination.

  ## Parameters

  - limit - Number of items (default: 10, max: 100)
  - starting_after - Cursor for pagination
  - ending_before - Reverse cursor
  - active - Filter by active status
  """
  @spec list(Plug.Conn.t()) :: Plug.Conn.t()
  def list(conn), do: list_response(conn, TaxRates)

  ## Private Functions

  defp build_tax_rate(params) do
    %{
      # Additional fields
      active: Map.get(params, :active, true),
      country: Map.get(params, :country),
      created: PaperTiger.now(),
      description: Map.get(params, :description),
      display_name: Map.get(params, :display_name),
      id: generate_id("txr"),
      inclusive: Map.get(params, :inclusive),
      jurisdiction: Map.get(params, :jurisdiction),
      livemode: false,
      metadata: Map.get(params, :metadata, %{}),
      object: "tax_rate",
      percentage: Map.get(params, :percentage),
      state: Map.get(params, :state),
      tax_type: Map.get(params, :tax_type)
    }
  end
end
