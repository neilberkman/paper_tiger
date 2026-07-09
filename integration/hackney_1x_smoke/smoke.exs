# End-to-end check of the hackney 1.x branch of paper_tiger's constraint:
# resolves hackney 1.x, drives PaperTiger.StripityStripeHackney against a
# running PaperTiger server, and proves the namespace header is injected.
#
# Run with: PAPER_TIGER_START=true mix run smoke.exs

defmodule Smoke do
  def assert!(true, _label), do: :ok
  def assert!(other, label), do: raise("smoke failure: #{label} (got: #{inspect(other)})")

  def request!(method, url, headers, body \\ "") do
    {:ok, status, _headers, ref} =
      PaperTiger.StripityStripeHackney.request(method, url, headers, body, [])

    {:ok, response_body} = :hackney.body(ref)
    {status, response_body}
  end
end

hackney_vsn = :hackney |> Application.spec(:vsn) |> to_string()
Smoke.assert!(String.starts_with?(hackney_vsn, "1."), "resolved hackney 1.x, not #{hackney_vsn}")

base = "http://localhost:#{PaperTiger.get_port()}"

headers = [
  {"authorization", "Bearer sk_test_smoke"},
  {"content-type", "application/x-www-form-urlencoded"}
]

# Create a customer inside a namespace; the adapter must inject the header.
Process.put(:paper_tiger_namespace, self())

{status, body} =
  Smoke.request!(:post, base <> "/v1/customers", headers, "email=smoke%40example.com")

Smoke.assert!(status == 200, "namespaced customer create returns 200")
customer = Jason.decode!(body)
Smoke.assert!(customer["object"] == "customer", "create returns a customer object")
Smoke.assert!(customer["email"] == "smoke@example.com", "email round-trips")

# Same namespace can read it back.
{status, _body} = Smoke.request!(:get, base <> "/v1/customers/#{customer["id"]}", headers)
Smoke.assert!(status == 200, "namespaced customer readable in the same namespace")

# Without the namespace the customer must be invisible (global scope) —
# this fails if the adapter silently stopped injecting the header on hackney 1.x.
Process.delete(:paper_tiger_namespace)
{status, _body} = Smoke.request!(:get, base <> "/v1/customers/#{customer["id"]}", headers)
Smoke.assert!(status == 404, "namespaced customer invisible without the header")

IO.puts("hackney #{hackney_vsn} smoke: OK")
