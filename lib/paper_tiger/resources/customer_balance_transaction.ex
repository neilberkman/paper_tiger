defmodule PaperTiger.Resources.CustomerBalanceTransaction do
  @moduledoc """
  Handles nested Customer Balance Transaction endpoints.
  """

  import PaperTiger.Resource

  alias PaperTiger.CustomerBalance
  alias PaperTiger.Store.CustomerBalanceTransactions

  @doc """
  Creates a customer balance transaction and mutates the customer's balance.
  """
  @spec create(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def create(conn, customer_id) do
    with {:ok, _params} <- validate_params(conn.params, [:amount, :currency]),
         {:ok, transaction} <- CustomerBalance.create_transaction(customer_id, conn.params) do
      maybe_store_idempotency(conn, transaction)
      json_response(conn, 200, transaction)
    else
      {:error, :invalid_params, field} ->
        missing_param_response(conn, field)

      {:error, :not_found} ->
        error_response(conn, PaperTiger.Error.not_found("customer", customer_id))
    end
  end

  @doc """
  Retrieves a customer balance transaction.
  """
  @spec retrieve(Plug.Conn.t(), String.t(), String.t()) :: Plug.Conn.t()
  def retrieve(conn, customer_id, id) do
    case CustomerBalanceTransactions.get_owned(id, :customer, customer_id) do
      {:ok, transaction} ->
        json_response(conn, 200, transaction)

      {:error, :not_found} ->
        error_response(conn, PaperTiger.Error.not_found("customer_balance_transaction", id))
    end
  end

  @doc """
  Updates customer balance transaction metadata/description.
  """
  @spec update(Plug.Conn.t(), String.t(), String.t()) :: Plug.Conn.t()
  def update(conn, customer_id, id) do
    case CustomerBalanceTransactions.get_owned(id, :customer, customer_id) do
      {:ok, existing} ->
        updated =
          merge_updates(existing, conn.params, [
            :amount,
            :created,
            :credit_note,
            :currency,
            :customer,
            :ending_balance,
            :id,
            :invoice,
            :livemode,
            :object,
            :type
          ])

        case CustomerBalanceTransactions.mutate_owned(:customer, customer_id, [{:update, updated}]) do
          :ok -> json_response(conn, 200, updated)
          {:error, {_reason, _id}} -> not_found(conn, id)
        end

      {:error, :not_found} ->
        not_found(conn, id)
    end
  end

  @doc """
  Lists customer balance transactions.
  """
  @spec list(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def list(conn, customer_id) do
    conn.params
    |> parse_pagination_params()
    |> Map.put(:url, "/v1/customers/#{customer_id}/balance_transactions")
    |> then(fn opts ->
      customer_id
      |> CustomerBalanceTransactions.find_by_customer()
      |> PaperTiger.List.paginate(opts)
    end)
    |> then(&json_response(conn, 200, &1))
  end

  defp not_found(conn, id) do
    error_response(conn, PaperTiger.Error.not_found("customer_balance_transaction", id))
  end
end
