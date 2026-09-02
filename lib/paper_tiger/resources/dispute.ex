defmodule PaperTiger.Resources.Dispute do
  @moduledoc """
  Handles Dispute resource endpoints.

  ## Endpoints

  - GET    /v1/disputes/:id  - Retrieve dispute
  - POST   /v1/disputes/:id  - Update dispute
  - GET    /v1/disputes      - List disputes

  Note: Disputes cannot be created or deleted (created by card networks, immutable).

  ## Dispute Object

      %{
        id: "dp_...",
        object: "dispute",
        created: 1234567890,
        amount: 2000,  # $20.00 in cents
        charge: "ch_...",
        currency: "usd",
        status: "warning_needs_response" | "warning_under_review" | "warning_closed" |
                "needs_response" | "under_review" | "charge_refunded" | "won" | "lost",
        reason: "duplicate" | "fraudulent" | "subscription_canceled" |
                "product_unacceptable" | "product_not_received" | "unrecognized" |
                "credit_not_processed" | "general",
        evidence: %{},
        metadata: %{},
        # ... other fields
      }
  """

  import PaperTiger.Resource

  alias PaperTiger.Store.Disputes

  @doc """
  Retrieves a dispute by ID.
  """
  @spec retrieve(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def retrieve(conn, id), do: retrieve_response(conn, Disputes, "dispute", id)

  @doc """
  Updates a dispute.

  Note: Disputes can only have limited fields updated.

  ## Updatable Fields

  - evidence
  - metadata
  """
  @spec update(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def update(conn, id) do
    update_response(conn, Disputes, "dispute", id, [
      :id,
      :object,
      :created,
      :amount,
      :charge,
      :currency,
      :status,
      :reason
    ])
  end

  @doc """
  Lists all disputes with pagination.

  ## Parameters

  - limit - Number of items (default: 10, max: 100)
  - starting_after - Cursor for pagination
  - ending_before - Reverse cursor
  - charge - Filter by charge ID
  - status - Filter by dispute status
  """
  @spec list(Plug.Conn.t()) :: Plug.Conn.t()
  def list(conn), do: list_response(conn, Disputes)

  ## Private Functions
end
