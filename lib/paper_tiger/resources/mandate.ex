defmodule PaperTiger.Resources.Mandate do
  @moduledoc """
  Handles Mandate resource endpoints.
  """

  import PaperTiger.Resource

  alias PaperTiger.Store.Mandates

  @doc """
  Retrieves a mandate by ID.
  """
  @spec retrieve(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def retrieve(conn, id), do: retrieve_response(conn, Mandates, "mandate", id)
end
