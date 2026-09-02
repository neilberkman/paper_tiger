defmodule PaperTiger.Store.Transfers do
  @moduledoc """
  ETS-backed storage for Connect Transfer resources.
  """

  use PaperTiger.Store,
    table: :paper_tiger_transfers,
    resource: "transfer",
    prefix: "tr",
    plural: "transfers"

  @deprecated "Use find_by/2"
  def find_by_destination(value), do: find_by(:destination, value)
end
