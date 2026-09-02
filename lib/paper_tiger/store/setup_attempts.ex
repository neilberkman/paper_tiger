defmodule PaperTiger.Store.SetupAttempts do
  @moduledoc """
  ETS-backed storage for SetupAttempt resources.

  SetupAttempts record each SetupIntent confirmation attempt and are scoped by
  the same PaperTiger test namespace as the SetupIntent they belong to.
  """

  use PaperTiger.Store,
    table: :paper_tiger_setup_attempts,
    resource: "setup_attempt",
    plural: "setup_attempts",
    prefix: "setatt"
end
