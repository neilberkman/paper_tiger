defmodule PaperTiger.RouterCase do
  @moduledoc """
  Test harness for driving `PaperTiger.Router` in-process.

  Provides `request/4`, `request_no_auth/3`, and `json_response/1` to the
  using module, with content-type, bearer auth, and sandbox headers applied to
  every request. Remaining options go to `ExUnit.Case`.

  ## Options

  - `:api_key` - bearer token sent with authenticated requests
    (default `"sk_test_key"`)
  - `:encoding` - `:json` sends params as a JSON body through `Plug.Parsers`;
    `:form` sends them form-encoded, in the query string for GET and DELETE
    and in the body otherwise. Both keep GET and DELETE params out of the body
    (default `:json`)

  ## Example

      use PaperTiger.RouterCase, async: true, api_key: "sk_test_customer_key"

      setup :checkout_paper_tiger

      test "creates a customer" do
        conn = request(:post, "/v1/customers", %{email: "a@b.c"})
        assert conn.status == 200
        assert json_response(conn)["email"] == "a@b.c"
      end
  """

  defmacro __using__(opts) do
    {api_key, opts} = Keyword.pop(opts, :api_key, "sk_test_key")
    {encoding, opts} = Keyword.pop(opts, :encoding, :json)

    quote do
      use ExUnit.Case, unquote(opts)

      import PaperTiger.Test

      alias PaperTiger.Router

      def request(method, path, params \\ nil, headers \\ []) do
        PaperTiger.RouterCase.request(method, path, params, headers, unquote(api_key), unquote(encoding))
      end

      def request_no_auth(method, path, params \\ nil) do
        PaperTiger.RouterCase.request_no_auth(method, path, params, unquote(encoding))
      end

      def json_response(conn), do: PaperTiger.RouterCase.json_response(conn)
    end
  end

  @doc """
  Sends an authenticated request through the router.
  """
  @spec request(atom(), String.t(), map() | nil, [{String.t(), String.t()}], String.t(), :json | :form) ::
          Plug.Conn.t()
  def request(method, path, params, headers, api_key, encoding) do
    method
    |> build_conn(path, params, [{"authorization", "Bearer #{api_key}"} | headers], encoding)
    |> PaperTiger.Router.call([])
  end

  @doc """
  Sends a request through the router with no authorization header.
  """
  @spec request_no_auth(atom(), String.t(), map() | nil, :json | :form) :: Plug.Conn.t()
  def request_no_auth(method, path, params, encoding) do
    method
    |> build_conn(path, params, [], encoding)
    |> PaperTiger.Router.call([])
  end

  @doc """
  Decodes the JSON body of a router response.
  """
  @spec json_response(Plug.Conn.t()) :: term()
  def json_response(conn), do: Jason.decode!(conn.resp_body)

  defp build_conn(method, path, params, headers, :json) when method in [:get, :delete] do
    put_headers(Plug.Test.conn(method, path, params), headers)
  end

  defp build_conn(method, path, params, headers, :json) do
    body = if is_map(params), do: Jason.encode!(params), else: ""
    conn = Plug.Test.conn(method, path, body)
    put_headers(conn, [{"content-type", "application/json"} | headers])
  end

  defp build_conn(method, path, params, headers, :form) do
    encoded = if is_map(params), do: params_to_form_data(params), else: ""

    {path, body} =
      cond do
        method in [:get, :delete] and encoded != "" -> {"#{path}?#{encoded}", ""}
        method in [:get, :delete] -> {path, ""}
        true -> {path, encoded}
      end

    conn = Plug.Test.conn(method, path, body)
    put_headers(conn, [{"content-type", "application/x-www-form-urlencoded"} | headers])
  end

  defp put_headers(conn, headers) do
    Enum.reduce(headers ++ PaperTiger.Test.sandbox_headers(), conn, fn {key, value}, acc ->
      Plug.Conn.put_req_header(acc, key, value)
    end)
  end

  defp params_to_form_data(params) do
    params
    |> flatten_params()
    |> Enum.map_join("&", fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
  end

  defp flatten_params(params, parent_key \\ "") do
    Enum.flat_map(params, fn
      {key, value} when is_map(value) ->
        flatten_params(value, nested_key(parent_key, key))

      {key, value} when is_list(value) ->
        new_key = nested_key(parent_key, key)

        value
        |> Enum.with_index(fn item, idx -> flatten_list_item(item, new_key, idx) end)
        |> List.flatten()

      {key, value} ->
        [{nested_key(parent_key, key), value}]
    end)
  end

  defp nested_key("", key), do: key
  defp nested_key(parent_key, key), do: "#{parent_key}[#{key}]"

  defp flatten_list_item(item, new_key, idx) when is_map(item), do: flatten_params(item, "#{new_key}[#{idx}]")
  defp flatten_list_item(item, new_key, _idx), do: {"#{new_key}[]", item}
end
