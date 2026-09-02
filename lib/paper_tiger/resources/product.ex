defmodule PaperTiger.Resources.Product do
  @moduledoc """
  Handles Product resource endpoints.

  ## Endpoints

  - POST   /v1/products      - Create product
  - GET    /v1/products/:id  - Retrieve product
  - POST   /v1/products/:id  - Update product
  - DELETE /v1/products/:id  - Delete product
  - GET    /v1/products      - List products

  ## Product Object

      %{
        id: "prod_...",
        object: "product",
        created: 1234567890,
        active: true,
        name: "Premium Plan",
        description: "A premium subscription plan",
        metadata: %{},
        # ... other fields
      }
  """

  import PaperTiger.Resource

  alias PaperTiger.ListFilters
  alias PaperTiger.Store.Products

  @doc """
  Creates a new product.

  ## Required Parameters

  - name - Product name

  ## Optional Parameters

  - id - Custom ID (must start with "prod_"). Useful for seeding deterministic data.
  - active - Whether product is active (default: true)
  - description - Product description
  - metadata - Key-value metadata
  - images - Product images URLs
  - statement_descriptor - Descriptor for bank statements
  """
  @spec create(Plug.Conn.t()) :: Plug.Conn.t()
  def create(conn) do
    with {:ok, _params} <- validate_params(conn.params, [:name]),
         product = build_product(conn.params),
         {:ok, product} <- Products.insert(product) do
      maybe_store_idempotency(conn, product)

      :telemetry.execute([:paper_tiger, :product, :created], %{}, %{object: product})

      product
      |> maybe_expand(conn.params)
      |> then(&json_response(conn, 200, &1))
    else
      {:error, :invalid_params, field} ->
        missing_param_response(conn, field)
    end
  end

  @doc """
  Retrieves a product by ID.
  """
  @spec retrieve(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def retrieve(conn, id), do: retrieve_response(conn, Products, "product", id)

  @doc """
  Updates a product.

  ## Updatable Fields

  - active
  - name
  - description
  - metadata
  - images
  - statement_descriptor
  """
  @spec update(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def update(conn, id), do: update_response(conn, Products, "product", id)

  @doc """
  Deletes a product.

  Returns a deletion confirmation object.
  """
  @spec delete(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def delete(conn, id), do: delete_response(conn, Products, "product", id)

  @doc """
  Lists all products with pagination.

  ## Parameters

  - limit - Number of items (default: 10, max: 100)
  - starting_after - Cursor for pagination
  - ending_before - Reverse cursor
  - active - Filter by active status
  """
  @spec list(Plug.Conn.t()) :: Plug.Conn.t()
  def list(conn) do
    pagination_opts = parse_pagination_params(conn.params)

    with :ok <- ListFilters.reject_combination(conn.params, :ids, [:starting_after, :ending_before]),
         {:ok, products} <-
           Products.list_namespace(PaperTiger.Connect.storage_namespace())
           |> ListFilters.apply(conn.params, [
             {:boolean, :active},
             {:created, :created},
             {:string_in, :ids, :id, []},
             {:boolean, :shippable},
             {:string, :url}
           ]) do
      result =
        products
        |> PaperTiger.List.paginate(Map.put(pagination_opts, :url, "/v1/products"))
        |> ListFilters.expand_page(conn.params)

      json_response(conn, 200, result)
    else
      {:error, error} ->
        error_response(conn, error)
    end
  end

  ## Private Functions

  defp build_product(params) do
    # Additional fields
    %{
      active: to_boolean(Map.get(params, :active, true)),
      attributes: Map.get(params, :attributes, []),
      caption: Map.get(params, :caption),
      created: PaperTiger.now(),
      default_price: Map.get(params, :default_price),
      description: Map.get(params, :description),
      id: generate_id("prod", Map.get(params, :id)),
      images: Map.get(params, :images, []),
      livemode: false,
      marketing_features: Map.get(params, :marketing_features, []),
      metadata: Map.get(params, :metadata, %{}),
      name: Map.get(params, :name),
      object: "product",
      package_dimensions: Map.get(params, :package_dimensions),
      shippable: maybe_boolean(Map.get(params, :shippable)),
      statement_descriptor: Map.get(params, :statement_descriptor),
      tax_code: Map.get(params, :tax_code),
      type: "service",
      unit_label: Map.get(params, :unit_label),
      updated: PaperTiger.now(),
      url: Map.get(params, :url)
    }
  end

  defp maybe_boolean(nil), do: nil
  defp maybe_boolean(value), do: to_boolean(value)
end
