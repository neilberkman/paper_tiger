defmodule PaperTiger.Resources.PlanIdCompatTest do
  # Stripe accepts legacy plan IDs anywhere a price ID is expected.
  use PaperTiger.RouterCase, async: true, api_key: "sk_test_plan_compat_key"

  setup :checkout_paper_tiger

  setup do
    product = create("/v1/products", %{"name" => "Gold"})

    price =
      create("/v1/prices", %{
        "currency" => "usd",
        "product" => product["id"],
        "recurring" => %{"interval" => "month"},
        "unit_amount" => 1000
      })

    plan =
      create("/v1/plans", %{
        "amount" => 2500,
        "currency" => "eur",
        "interval" => "month",
        "product" => product["id"]
      })

    customer = create("/v1/customers", %{"email" => "plan@example.com"})
    %{customer: customer, plan: plan, price: price}
  end

  test "subscription item update resolves a plan ID to a price object", %{customer: customer, plan: plan, price: price} do
    subscription =
      create("/v1/subscriptions", %{
        "customer" => customer["id"],
        "items" => [%{"price" => price["id"], "quantity" => 1}]
      })

    [item] = subscription["items"]["data"]

    updated = create("/v1/subscription_items/#{item["id"]}", %{"price" => plan["id"]})

    assert updated["price"]["id"] == plan["id"]
    assert updated["price"]["object"] == "price"
    assert updated["price"]["unit_amount"] == 2500
    assert updated["price"]["currency"] == "eur"
    assert updated["price"]["recurring"]["interval_count"] == 1
  end

  test "payment link line items resolve a plan ID", %{plan: plan} do
    link =
      create("/v1/payment_links", %{
        "expand" => ["line_items"],
        "line_items" => [%{"price" => plan["id"], "quantity" => 2}]
      })

    [line] = link["line_items"]["data"]
    assert line["price"]["id"] == plan["id"]
    assert line["price"]["unit_amount"] == 2500
    assert line["amount_total"] == 5000
  end

  test "a subscription created from a plan invoices the plan amount", %{customer: customer, plan: plan} do
    subscription =
      create("/v1/subscriptions", %{
        "customer" => customer["id"],
        "items" => [%{"price" => plan["id"], "quantity" => 2}],
        "payment_behavior" => "default_incomplete"
      })

    [item] = subscription["items"]["data"]
    assert item["price"]["id"] == plan["id"]

    conn = request(:get, "/v1/invoices/#{subscription["latest_invoice"]}")
    assert conn.status == 200
    # The initial invoice's currency is hardcoded to usd today, independent of plan IDs
    assert json_response(conn)["amount_due"] == 5000

    preview =
      request(:get, "/v1/invoices/upcoming", %{"customer" => customer["id"], "subscription" => subscription["id"]})

    assert preview.status == 200
    # Preview currency is hardcoded to usd on this path today, independent of plan IDs
    [line] = json_response(preview)["lines"]["data"]
    assert line["price"]["id"] == plan["id"]
    assert line["amount"] == 5000
  end

  test "subscription schedule phases keep trial: false", %{customer: customer, price: price} do
    schedule =
      create("/v1/subscription_schedules", %{
        "customer" => customer["id"],
        "phases" => [%{"items" => [%{"price" => price["id"], "quantity" => 1}], "iterations" => 1, "trial" => false}],
        "start_date" => "now"
      })

    [phase] = schedule["phases"]
    assert phase["trial"] == false
  end

  defp create(path, params) do
    conn = request(:post, path, params)
    assert conn.status == 200, "POST #{path} failed: #{conn.resp_body}"
    json_response(conn)
  end
end
