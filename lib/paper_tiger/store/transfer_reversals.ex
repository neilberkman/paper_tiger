defmodule PaperTiger.Store.TransferReversals do
  @moduledoc """
  ETS-backed storage for Connect Transfer Reversal resources.
  """

  use PaperTiger.Store,
    table: :paper_tiger_transfer_reversals,
    resource: "transfer_reversal",
    prefix: "trr",
    plural: "transfer_reversals",
    url_path: "/v1/transfers"

  @deprecated "Use find_by/2"
  def find_by_transfer(value), do: find_by(:transfer, value)
end
