defmodule PaperTiger.StandaloneServerTest do
  @moduledoc """
  Covers the HTTP surface that non-Elixir callers depend on when PaperTiger runs
  as a standalone server rather than as an in-process library.

  Not async: the clock is a singleton, so advancing it would race other tests.
  """

  use ExUnit.Case, async: false

  import PaperTiger.Test

  alias PaperTiger.Router

  setup :checkout_paper_tiger

  defp request(method, path, params, headers) do
    method
    |> Plug.Test.conn(path, params)
    |> then(fn conn ->
      Enum.reduce(headers ++ sandbox_headers(), conn, fn {key, value}, acc ->
        Plug.Conn.put_req_header(acc, key, value)
      end)
    end)
    |> Router.call([])
  end

  defp json_response(conn), do: Jason.decode!(conn.resp_body)

  describe "GET /health" do
    test "responds without an Authorization header" do
      conn = request(:get, "/health", nil, [])

      assert conn.status == 200
      assert json_response(conn) == %{"service" => "paper_tiger", "status" => "ok"}
    end

    test "still responds when an Authorization header is present" do
      conn = request(:get, "/health", nil, [{"authorization", "Bearer sk_test_health"}])

      assert conn.status == 200
    end
  end

  describe "API paths remain authenticated" do
    test "a missing Authorization header is rejected" do
      conn = request(:get, "/v1/customers", nil, [])

      assert conn.status == 401
      assert %{"error" => %{"type" => "invalid_request_error"}} = json_response(conn)
    end
  end

  describe "POST /_config/time/advance" do
    setup do
      PaperTiger.Clock.set_mode(:manual)
      PaperTiger.Clock.reset()
      on_exit(fn -> PaperTiger.Clock.set_mode(:real) end)
    end

    @auth [
      {"authorization", "Bearer sk_test_time"},
      {"content-type", "application/x-www-form-urlencoded"}
    ]

    test "accepts form-encoded seconds, as the Stripe SDKs send them" do
      before = PaperTiger.now()
      conn = request(:post, "/_config/time/advance", %{"seconds" => "86400"}, @auth)

      assert conn.status == 200
      assert %{"now" => now, "success" => true} = json_response(conn)
      assert now - before >= 86_400
    end

    test "accepts form-encoded days" do
      before = PaperTiger.now()
      conn = request(:post, "/_config/time/advance", %{"days" => "2"}, @auth)

      assert conn.status == 200
      assert %{"now" => now, "success" => true} = json_response(conn)
      assert now - before >= 2 * 86_400
    end

    test "accepts integer seconds from a JSON body" do
      before = PaperTiger.now()

      conn =
        request(:post, "/_config/time/advance", %{"seconds" => 3600}, [
          {"authorization", "Bearer sk_test_time"},
          {"content-type", "application/json"}
        ])

      assert conn.status == 200
      assert %{"now" => now} = json_response(conn)
      assert now - before >= 3600
    end

    test "rejects a non-numeric value" do
      conn = request(:post, "/_config/time/advance", %{"seconds" => "later"}, @auth)

      assert conn.status == 400

      assert %{"error" => %{"message" => "Missing seconds or days parameter"}} =
               json_response(conn)
    end

    test "rejects a request with neither parameter" do
      conn = request(:post, "/_config/time/advance", %{}, @auth)

      assert conn.status == 400
    end
  end
end
