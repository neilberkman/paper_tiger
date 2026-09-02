defmodule PaperTiger.Resources.IntentRedirectReturnUrlTest do
  @moduledoc """
  Confirming an intent whose `automatic_payment_methods` allows redirects
  requires a `return_url`, as real Stripe does.

  Stripe rejects the confirmation outright when redirect-based methods (boleto,
  iDEAL, ...) are in play and the caller supplied nowhere to send the customer
  back to. Accepting it here lets an integration ship a confirm call that cannot
  succeed against the real API — the mock and the bug agree, and the suite stays
  green.

  Only the case that is decidable from the request is covered:
  `automatic_payment_methods[enabled]=true` with `allow_redirects` not set to
  `never`. When the parameter is omitted entirely, real Stripe falls back to the
  payment methods enabled in the account's dashboard, which PaperTiger does not
  model.
  """

  use PaperTiger.RouterCase, async: true, api_key: "sk_test_return_url_key"

  setup :checkout_paper_tiger

  defp create_payment_intent(automatic_payment_methods) do
    params =
      %{"amount" => 1000, "currency" => "usd"}
      |> put_apm(automatic_payment_methods)

    :post
    |> request("/v1/payment_intents", params)
    |> json_response()
    |> Map.fetch!("id")
  end

  # A SetupIntent needs a payment method before it is confirmable at all —
  # without one, confirm fails on that instead, which would make these tests red
  # for the wrong reason.
  defp create_setup_intent(automatic_payment_methods) do
    :post
    |> request(
      "/v1/setup_intents",
      put_apm(%{"payment_method" => "pm_card_visa"}, automatic_payment_methods)
    )
    |> json_response()
    |> Map.fetch!("id")
  end

  defp put_apm(params, nil), do: params
  defp put_apm(params, apm), do: Map.put(params, "automatic_payment_methods", apm)

  describe "POST /v1/payment_intents/:id/confirm" do
    test "rejects confirmation when redirects are allowed and no return_url is given" do
      id = create_payment_intent(%{"enabled" => "true"})

      conn = request(:post, "/v1/payment_intents/#{id}/confirm")

      assert conn.status == 400
      error = json_response(conn)
      assert error["error"]["type"] == "invalid_request_error"
      assert error["error"]["message"] =~ "This PaymentIntent"
      assert error["error"]["message"] =~ "return_url"
      assert error["error"]["param"] == "return_url"
    end

    test "accepts confirmation when the return_url is supplied at confirm time" do
      id = create_payment_intent(%{"enabled" => "true"})

      conn =
        request(:post, "/v1/payment_intents/#{id}/confirm", %{
          "return_url" => "https://example.test/return"
        })

      assert conn.status == 200
    end

    test "accepts confirmation when the return_url was supplied at create time" do
      params = %{
        "amount" => 1000,
        "automatic_payment_methods" => %{"enabled" => "true"},
        "currency" => "usd",
        "return_url" => "https://example.test/return"
      }

      id = request(:post, "/v1/payment_intents", params) |> json_response() |> Map.fetch!("id")

      assert request(:post, "/v1/payment_intents/#{id}/confirm").status == 200
    end

    test "accepts confirmation when redirects are disallowed" do
      id = create_payment_intent(%{"allow_redirects" => "never", "enabled" => "true"})

      assert request(:post, "/v1/payment_intents/#{id}/confirm").status == 200
    end

    # The omitted case depends on account-level configuration PaperTiger does not
    # model, so it must keep working rather than guess a rejection.
    test "accepts confirmation when automatic_payment_methods is absent" do
      id = create_payment_intent(nil)

      assert request(:post, "/v1/payment_intents/#{id}/confirm").status == 200
    end
  end

  describe "POST /v1/setup_intents/:id/confirm" do
    test "rejects confirmation when redirects are allowed and no return_url is given" do
      id = create_setup_intent(%{"enabled" => "true"})

      conn = request(:post, "/v1/setup_intents/#{id}/confirm")

      assert conn.status == 400
      error = json_response(conn)
      assert error["error"]["type"] == "invalid_request_error"
      assert error["error"]["message"] =~ "This SetupIntent"
      assert error["error"]["message"] =~ "return_url"
      assert error["error"]["param"] == "return_url"
    end

    test "accepts confirmation when the return_url is supplied at confirm time" do
      id = create_setup_intent(%{"enabled" => "true"})

      conn =
        request(:post, "/v1/setup_intents/#{id}/confirm", %{
          "return_url" => "https://example.test/return"
        })

      assert conn.status == 200
    end

    test "accepts confirmation when the return_url was supplied at create time" do
      params = %{
        "automatic_payment_methods" => %{"enabled" => "true"},
        "payment_method" => "pm_card_visa",
        "return_url" => "https://example.test/return"
      }

      id = request(:post, "/v1/setup_intents", params) |> json_response() |> Map.fetch!("id")

      assert request(:post, "/v1/setup_intents/#{id}/confirm").status == 200
    end

    test "accepts confirmation when redirects are disallowed" do
      id = create_setup_intent(%{"allow_redirects" => "never", "enabled" => "true"})

      assert request(:post, "/v1/setup_intents/#{id}/confirm").status == 200
    end

    test "accepts confirmation when automatic_payment_methods is absent" do
      id = create_setup_intent(nil)

      assert request(:post, "/v1/setup_intents/#{id}/confirm").status == 200
    end
  end
end
