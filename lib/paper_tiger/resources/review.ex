defmodule PaperTiger.Resources.Review do
  @moduledoc """
  Handles Review resource endpoints.

  ## Endpoints

  - GET    /v1/reviews/:id  - Retrieve review
  - POST   /v1/reviews/:id  - Update review
  - GET    /v1/reviews      - List reviews

  Note: Reviews cannot be created or deleted (created by Stripe Radar, immutable).

  ## Review Object

      %{
        id: "prv_...",
        object: "review",
        created: 1234567890,
        charge: "ch_...",
        payment_intent: "pi_...",
        reason: "rule" | "manual" | "approved" | "refunded",
        open: true,
        closed_reason: "approved" | "refunded" | "refunded_as_fraud" | "disputed",
        metadata: %{},
        # ... other fields
      }
  """

  import PaperTiger.Resource

  alias PaperTiger.Store.Reviews

  @doc """
  Retrieves a review by ID.
  """
  @spec retrieve(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def retrieve(conn, id), do: retrieve_response(conn, Reviews, "review", id)

  @doc """
  Updates a review.

  Note: Reviews can only have limited fields updated.

  ## Updatable Fields

  - closed_reason (only when closing a review)
  - metadata
  """
  @spec update(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def update(conn, id),
    do: update_response(conn, Reviews, "review", id, [:id, :object, :created, :charge, :payment_intent, :reason, :open])

  @doc """
  Lists all reviews with pagination.

  ## Parameters

  - limit - Number of items (default: 10, max: 100)
  - starting_after - Cursor for pagination
  - ending_before - Reverse cursor
  - charge - Filter by charge ID
  - payment_intent - Filter by payment intent ID
  """
  @spec list(Plug.Conn.t()) :: Plug.Conn.t()
  def list(conn), do: list_response(conn, Reviews)

  ## Private Functions
end
