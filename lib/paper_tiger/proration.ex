defmodule PaperTiger.Proration do
  @moduledoc """
  Proration math shared by the immediate proration invoice (subscription
  updates) and the proration lines in its preview
  (`POST /v1/invoices/create_preview`).

  One module on purpose: the previewed proration lines quote the immediate
  adjustment, so both paths must use the same remaining-period ratio, item
  diff, and currency.

  Amounts follow Stripe's model: credit the unused remainder of what was
  removed, charge the remainder of what was added, both scaled by how much of
  the current billing period is left.
  """

  import PaperTiger.Resource, only: [generate_id: 1]

  alias PaperTiger.Store.Prices

  @doc """
  The share of the current billing period still ahead at `now`, clamped to
  0..1. A subscription without a sane period (missing fields, zero-length
  period) prorates at 1.0 — full charge, full credit — which is at least
  predictable where the period math would be garbage.
  """
  @spec remaining_ratio(map(), integer()) :: float()
  def remaining_ratio(subscription, now) do
    period_start = subscription[:current_period_start]
    period_end = subscription[:current_period_end]

    if is_integer(period_start) and is_integer(period_end) and period_end > period_start do
      ((period_end - now) / (period_end - period_start)) |> max(0.0) |> min(1.0)
    else
      1.0
    end
  end

  @doc """
  Proration line items for a change from `old_items` to `new_items`, scaled
  by `ratio`. Items are `%{price_id, product, quantity, unit_amount}` maps;
  quantities are aggregated per price, and a price whose total amount did not
  change produces no lines. Line currency comes from the price in the store,
  falling back to "usd" for a price it does not hold.
  """
  @spec lines([map()], [map()], float(), integer()) :: [map()]
  def lines(old_items, new_items, ratio, now) do
    old_by_price = aggregate_by_price(old_items)
    new_by_price = aggregate_by_price(new_items)

    MapSet.union(MapSet.new(Map.keys(old_by_price)), MapSet.new(Map.keys(new_by_price)))
    |> Enum.sort()
    |> Enum.flat_map(&lines_for_price(&1, old_by_price, new_by_price, ratio, now))
  end

  defp aggregate_by_price(items) do
    Enum.reduce(items, %{}, fn item, acc ->
      quantity = item.quantity || 1
      amount = (item.unit_amount || 0) * quantity

      Map.update(
        acc,
        item.price_id,
        %{amount: amount, product: item.product, quantity: quantity, unit_amount: item.unit_amount},
        fn agg -> %{agg | amount: agg.amount + amount, quantity: agg.quantity + quantity} end
      )
    end)
  end

  defp lines_for_price(price_id, old_by_price, new_by_price, ratio, now) do
    old = Map.get(old_by_price, price_id)
    new = Map.get(new_by_price, price_id)

    if (old && old.amount) == (new && new.amount) do
      []
    else
      [
        credit_line(price_id, old, ratio, now),
        charge_line(price_id, new, ratio, now)
      ]
      |> Enum.reject(&is_nil/1)
    end
  end

  defp credit_line(_price_id, nil, _ratio, _now), do: nil

  defp credit_line(price_id, old, ratio, now) do
    build_line(price_id, old, -round(old.amount * ratio), "Unused time on", now)
  end

  defp charge_line(_price_id, nil, _ratio, _now), do: nil

  defp charge_line(price_id, new, ratio, now) do
    build_line(price_id, new, round(new.amount * ratio), "Remaining time on", now)
  end

  defp build_line(_price_id, _agg, 0, _prefix, _now), do: nil

  defp build_line(price_id, agg, amount, prefix, now) do
    %{
      amount: amount,
      currency: price_currency(price_id),
      description: "#{prefix} #{agg.quantity} x (#{price_id})",
      id: generate_id("il"),
      object: "line_item",
      period: %{end: now, start: now},
      price: %{id: price_id, product: agg.product, unit_amount: agg.unit_amount},
      proration: true,
      quantity: agg.quantity,
      type: "subscription"
    }
  end

  @doc """
  The currency of a price in the store, falling back to "usd" for one it
  does not hold. Also the invoice-level currency for a set of lines: the
  first line's currency, on the Stripe invariant that one invoice carries
  one currency.
  """
  @spec price_currency(String.t() | nil) :: String.t()
  def price_currency(price_id) do
    case price_id && Prices.get(to_string(price_id)) do
      {:ok, price} -> price.currency || "usd"
      _ -> "usd"
    end
  end

  @doc "Invoice-level currency for a list of built lines."
  @spec invoice_currency([map()]) :: String.t()
  def invoice_currency([%{currency: currency} | _]) when is_binary(currency), do: currency
  def invoice_currency(_), do: "usd"
end
