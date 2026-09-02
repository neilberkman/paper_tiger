defmodule PaperTiger.Store.Transfers do
  @moduledoc """
  ETS-backed storage for Connect Transfer resources.
  """

  use PaperTiger.Store,
    table: :paper_tiger_transfers,
    resource: "transfer",
    prefix: "tr",
    plural: "transfers"
end
