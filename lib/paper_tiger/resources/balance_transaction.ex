defmodule PaperTiger.Resources.BalanceTransaction do
  @moduledoc """
  Handles BalanceTransaction resource endpoints.

  ## Endpoints

  - GET    /v1/balance_transactions/:id  - Retrieve balance transaction
  - GET    /v1/balance_transactions      - List balance transactions

  Note: Balance transactions are auto-generated and immutable for audit trail integrity.

  ## Balance Transaction Object

      %{
        id: "txn_...",
        object: "balance_transaction",
        created: 1234567890,
        amount: 1000,
        currency: "usd",
        net: 980,
        fee: 20,
        type: "charge",
        status: "available",
        source: "ch_...",
        description: "Transaction description"
      }
  """

  import PaperTiger.Resource

  alias PaperTiger.Store.BalanceTransactions

  @doc """
  Retrieves a balance transaction by ID.
  """
  @spec retrieve(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def retrieve(conn, id), do: retrieve_response(conn, BalanceTransactions, "balance_transaction", id)

  @doc """
  Lists all balance transactions with pagination.

  ## Parameters

  - limit - Number of items (default: 10, max: 100)
  - starting_after - Cursor for pagination
  - ending_before - Reverse cursor
  - type - Filter by transaction type (charge, refund, payout, payment, etc.)
  - source - Filter by source ID
  """
  @spec list(Plug.Conn.t()) :: Plug.Conn.t()
  def list(conn), do: list_response(conn, BalanceTransactions)

  ## Private Functions
end
