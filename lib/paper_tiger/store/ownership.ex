defmodule PaperTiger.Store.Ownership do
  @moduledoc false

  @type operation :: {:insert | :update, map()} | {:delete, String.t()}
  @type mutation_error ::
          {:already_exists | :duplicate_operation | :not_found | :not_owned, String.t()}

  @spec mutate(atom(), term(), atom(), term(), [operation()]) ::
          :ok | {:error, mutation_error()}
  def mutate(table, namespace, owner_field, owner_id, operations) do
    with :ok <- validate_unique_operation_ids(operations),
         :ok <- validate_owned_operations(table, operations, namespace, owner_field, owner_id) do
      apply_operations(table, operations, namespace)
    end
  end

  defp validate_unique_operation_ids(operations) do
    operations
    |> Enum.reduce_while(MapSet.new(), fn operation, seen_ids ->
      id = operation_id(operation)

      if MapSet.member?(seen_ids, id) do
        {:halt, {:error, {:duplicate_operation, id}}}
      else
        {:cont, MapSet.put(seen_ids, id)}
      end
    end)
    |> case do
      %MapSet{} -> :ok
      error -> error
    end
  end

  defp validate_owned_operations(table, operations, namespace, owner_field, owner_id) do
    Enum.reduce_while(operations, :ok, fn operation, :ok ->
      case validate_owned_operation(table, operation, namespace, owner_field, owner_id) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_owned_operation(table, {:insert, item}, namespace, owner_field, owner_id) do
    id = item.id

    cond do
      Map.get(item, owner_field) != owner_id ->
        {:error, {:not_owned, id}}

      :ets.member(table, {namespace, id}) ->
        {:error, {:already_exists, id}}

      true ->
        :ok
    end
  end

  defp validate_owned_operation(table, {:update, item}, namespace, owner_field, owner_id) do
    validate_existing_owner(table, namespace, item.id, owner_field, owner_id, item)
  end

  defp validate_owned_operation(table, {:delete, id}, namespace, owner_field, owner_id) do
    validate_existing_owner(table, namespace, id, owner_field, owner_id, nil)
  end

  defp validate_existing_owner(table, namespace, id, owner_field, owner_id, replacement) do
    case :ets.lookup(table, {namespace, id}) do
      [] ->
        {:error, {:not_found, id}}

      [{_key, existing}] ->
        if Map.get(existing, owner_field) == owner_id and
             (is_nil(replacement) or Map.get(replacement, owner_field) == owner_id) do
          :ok
        else
          {:error, {:not_owned, id}}
        end
    end
  end

  defp apply_operations(table, operations, namespace) do
    Enum.each(operations, fn
      {:insert, item} -> :ets.insert(table, {{namespace, item.id}, item})
      {:update, item} -> :ets.insert(table, {{namespace, item.id}, item})
      {:delete, id} -> :ets.delete(table, {namespace, id})
    end)

    :ok
  end

  defp operation_id({_operation, item}) when is_map(item), do: item.id
  defp operation_id({:delete, id}), do: id
end
