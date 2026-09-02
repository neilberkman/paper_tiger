defmodule PaperTiger.RequestLogTest do
  @moduledoc """
  Tests for inbound request capture helpers.
  """

  use PaperTiger.RouterCase, async: true, api_key: "sk_test_request_log"

  alias PaperTiger.Store.Requests

  describe "request spy" do
    setup :checkout_paper_tiger

    setup do
      clear_requests()
      :ok
    end

    test "captures method, path, params, and idempotency key" do
      idempotency_key = "request-log-key-#{:rand.uniform(1_000_000)}"

      conn =
        request(:post, "/v1/customers", %{"email" => "trace@example.com"}, [
          {"idempotency-key", idempotency_key}
        ])

      assert conn.status == 200
      _response = json_response(conn)

      matches = assert_request(:post, "/v1/customers", %{email: "trace@example.com"})

      assert length(matches) == 1
      [captured] = matches
      assert captured.method == "POST"
      assert captured.path == "/v1/customers"
      assert captured.params["email"] == "trace@example.com"
      assert captured.idempotency_key == idempotency_key
    end

    test "supports method and path filtering" do
      request(:post, "/v1/customers", %{"email" => "create@example.com"})
      request(:get, "/v1/customers", %{})

      assert length(requests(method: :post, path: "/v1/customers")) == 1
      assert length(requests(method: :get, path: "/v1/customers")) == 1
      assert length(requests(path: "/v1/customers")) == 2
    end

    test "supports refute_request and clear_requests" do
      request(:post, "/v1/customers", %{"email" => "delete@example.com"})

      assert length(requests()) == 1
      assert refute_request(:get, "/v1/customers") == :ok

      clear_requests()
      assert requests() == []
    end
  end

  describe "global-mode logging" do
    setup do
      previous_namespace = Process.get(:paper_tiger_namespace)
      previous_shared_namespace = Application.get_env(:paper_tiger, :paper_tiger_shared_namespace)

      Process.delete(:paper_tiger_namespace)
      Application.delete_env(:paper_tiger, :paper_tiger_shared_namespace)

      on_exit(fn ->
        if is_nil(previous_namespace) do
          Process.delete(:paper_tiger_namespace)
        else
          Process.put(:paper_tiger_namespace, previous_namespace)
        end

        if is_nil(previous_shared_namespace) do
          Application.delete_env(:paper_tiger, :paper_tiger_shared_namespace)
        else
          Application.put_env(:paper_tiger, :paper_tiger_shared_namespace, previous_shared_namespace)
        end
      end)

      :ok
    end

    test "does not capture requests when no sandbox namespace is set" do
      before_requests = Requests.list_namespace(:global)

      conn = Plug.Test.conn(:post, "/v1/customers", %{"email" => "global@example.com"})

      conn =
        Enum.reduce(
          [{"content-type", "application/json"}, {"authorization", "Bearer sk_test_request_log"}],
          conn,
          fn {key, value}, acc -> Plug.Conn.put_req_header(acc, key, value) end
        )
        |> Router.call([])

      assert conn.status == 200
      after_requests = Requests.list_namespace(:global)

      assert length(after_requests) == length(before_requests)
    end
  end

  describe "request log retention" do
    setup :checkout_paper_tiger

    setup do
      clear_requests()
      previous_limit = Application.get_env(:paper_tiger, :request_log_max_entries)
      Application.put_env(:paper_tiger, :request_log_max_entries, 2)

      on_exit(fn ->
        if is_nil(previous_limit) do
          Application.delete_env(:paper_tiger, :request_log_max_entries)
        else
          Application.put_env(:paper_tiger, :request_log_max_entries, previous_limit)
        end
      end)

      :ok
    end

    test "enforces a max request history size" do
      request(:post, "/v1/customers", %{"email" => "ring-1@example.com"})
      request(:post, "/v1/customers", %{"email" => "ring-2@example.com"})
      request(:post, "/v1/customers", %{"email" => "ring-3@example.com"})

      assert length(requests()) == 2
      assert Enum.map(requests(), & &1.params["email"]) == ["ring-3@example.com", "ring-2@example.com"]
    end
  end
end
