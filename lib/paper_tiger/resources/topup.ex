defmodule PaperTiger.Resources.Topup do
  @moduledoc """
  Handles Topup resource endpoints.

  ## Endpoints

  - POST   /v1/topups      - Create topup
  - GET    /v1/topups/:id  - Retrieve topup
  - POST   /v1/topups/:id  - Update topup
  - GET    /v1/topups      - List topups

  Note: Topups cannot be deleted (only canceled).

  ## Topup Object

      %{
        id: "tu_...",
        object: "topup",
        created: 1234567890,
        amount: 2000,
        currency: "usd",
        status: "pending" | "succeeded" | "failed" | "canceled" | "reversed",
        description: "Account top-up",
        metadata: %{},
        # ... other fields
      }
  """

  import PaperTiger.Resource

  alias PaperTiger.Store.Topups

  @doc """
  Creates a new topup.

  ## Required Parameters

  - amount - Amount in cents (e.g., 2000 for $20.00)
  - currency - Three-letter ISO currency code (e.g., "usd")
  - description - Topup description

  ## Optional Parameters

  - metadata - Key-value metadata
  """
  @spec create(Plug.Conn.t()) :: Plug.Conn.t()
  def create(conn) do
    with {:ok, _params} <- validate_params(conn.params, [:amount, :currency, :description]),
         topup = build_topup(conn.params),
         {:ok, topup} <- Topups.insert(topup) do
      maybe_store_idempotency(conn, topup)

      topup
      |> maybe_expand(conn.params)
      |> then(&json_response(conn, 200, &1))
    else
      {:error, :invalid_params, field} ->
        missing_param_response(conn, field)
    end
  end

  @doc """
  Retrieves a topup by ID.
  """
  @spec retrieve(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def retrieve(conn, id), do: retrieve_response(conn, Topups, "topup", id)

  @doc """
  Updates a topup.

  Note: Topups can only have limited fields updated.

  ## Updatable Fields

  - description
  - metadata
  """
  @spec update(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def update(conn, id),
    do: update_response(conn, Topups, "topup", id, [:id, :object, :created, :amount, :currency, :status])

  @doc """
  Lists all topups with pagination.

  ## Parameters

  - limit - Number of items (default: 10, max: 100)
  - starting_after - Cursor for pagination
  - ending_before - Reverse cursor
  - status - Filter by status
  """
  @spec list(Plug.Conn.t()) :: Plug.Conn.t()
  def list(conn), do: list_response(conn, Topups)

  ## Private Functions

  # Additional fields
  defp build_topup(params) do
    %{
      amount: get_integer(params, :amount),
      created: PaperTiger.now(),
      currency: Map.get(params, :currency),
      description: Map.get(params, :description),
      expected_arrival_date: Map.get(params, :expected_arrival_date),
      failure_code: Map.get(params, :failure_code),
      failure_message: Map.get(params, :failure_message),
      id: generate_id("tu"),
      livemode: false,
      metadata: Map.get(params, :metadata, %{}),
      object: "topup",
      source: Map.get(params, :source),
      statement_descriptor: Map.get(params, :statement_descriptor),
      status: Map.get(params, :status, "pending"),
      transfer_group: Map.get(params, :transfer_group)
    }
  end
end
