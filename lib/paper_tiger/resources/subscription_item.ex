defmodule PaperTiger.Resources.SubscriptionItem do
  @moduledoc """
  Handles Subscription Item resource endpoints.

  ## Endpoints

  - POST   /v1/subscription_items              - Create subscription item
  - GET    /v1/subscription_items/:id          - Retrieve subscription item
  - POST   /v1/subscription_items/:id          - Update subscription item
  - DELETE /v1/subscription_items/:id          - Delete subscription item
  - GET    /v1/subscription_items              - List subscription items

  ## Subscription Item Object

      %{
        id: "si_...",
        object: "subscription_item",
        created: 1234567890,
        subscription: "sub_...",
        price: %{id: "price_...", object: "price", ...},
        quantity: 1,
        metadata: %{},
        # ... other fields
      }
  """

  import PaperTiger.Resource

  alias PaperTiger.Store.Prices
  alias PaperTiger.Store.SubscriptionItems

  @doc """
  Creates a new subscription item.

  ## Required Parameters

  - subscription - Subscription ID
  - price - Price ID

  ## Optional Parameters

  - quantity - Item quantity (default: 1)
  - metadata - Key-value metadata
  """
  @spec create(Plug.Conn.t()) :: Plug.Conn.t()
  def create(conn) do
    with {:ok, _params} <- validate_params(conn.params, [:subscription, :price]),
         item = build_subscription_item(conn.params),
         {:ok, item} <- SubscriptionItems.insert(item) do
      maybe_store_idempotency(conn, item)

      item
      |> maybe_expand(conn.params)
      |> then(&json_response(conn, 200, &1))
    else
      {:error, :invalid_params, field} ->
        missing_param_response(conn, field)
    end
  end

  @doc """
  Retrieves a subscription item by ID.
  """
  @spec retrieve(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def retrieve(conn, id), do: retrieve_response(conn, SubscriptionItems, "subscription_item", id)

  @doc """
  Updates a subscription item.

  ## Updatable Fields

  - price
  - quantity
  - metadata
  """
  @spec update(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def update(conn, id),
    do: update_response(conn, SubscriptionItems, "subscription_item", id, [:id, :object, :created, :subscription])

  @doc """
  Deletes a subscription item.

  Removes the item from the subscription.

  Returns a deletion confirmation object.
  """
  @spec delete(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def delete(conn, id), do: delete_response(conn, SubscriptionItems, "subscription_item", id)

  @doc """
  Lists all subscription items with pagination.

  ## Parameters

  - subscription - Filter by subscription (required)
  - limit - Number of items (default: 10, max: 100)
  - starting_after - Cursor for pagination
  - ending_before - Reverse cursor
  """
  @spec list(Plug.Conn.t()) :: Plug.Conn.t()
  def list(conn) do
    case Map.get(conn.params, :subscription) do
      nil ->
        error_response(
          conn,
          PaperTiger.Error.invalid_request("Missing required parameter", "subscription")
        )

      _subscription ->
        pagination_opts = parse_pagination_params(conn.params)

        result = SubscriptionItems.list(pagination_opts)

        json_response(conn, 200, result)
    end
  end

  ## Private Functions

  # Additional fields
  defp build_subscription_item(params) do
    price_id = Map.get(params, :price)
    price_object = Prices.get_or_placeholder(price_id)

    %{
      billing_thresholds: Map.get(params, :billing_thresholds),
      created: PaperTiger.now(),
      id: generate_id("si"),
      livemode: false,
      metadata: Map.get(params, :metadata, %{}),
      object: "subscription_item",
      price: price_object,
      quantity: get_integer(params, :quantity, 1),
      subscription: Map.get(params, :subscription),
      tax_rates: Map.get(params, :tax_rates, [])
    }
  end
end
