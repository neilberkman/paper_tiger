defmodule PaperTiger.UserAdapters.AutoDiscoverTest do
  use ExUnit.Case, async: true

  alias PaperTiger.UserAdapters.AutoDiscover

  # A repo stub driven by a schema map in the test process:
  #
  #   %{
  #     tables: ["users"],                       # tables that exist
  #     users: %{1 => %{"id" => 1, ...}},        # rows by id, keyed by table
  #     emails: %{10 => "jane@example.com"}      # emails table addresses by id
  #   }
  defmodule FakeRepo do
    def query("SELECT EXISTS" <> _, [table]) do
      {:ok, %{rows: [[table in Map.get(schema(), :tables, [])]]}}
    end

    def query("SELECT address FROM emails WHERE id = $1 LIMIT 1", [email_id]) do
      case get_in(schema(), [:emails, email_id]) do
        nil -> {:ok, %{rows: []}}
        address -> {:ok, %{rows: [[address]]}}
      end
    end

    def query("SELECT * FROM " <> rest, [user_id]) do
      table = rest |> String.split(" ") |> hd()

      case get_in(schema(), [String.to_atom(table), user_id]) do
        nil -> {:ok, %{columns: ["id"], rows: []}}
        row -> {:ok, %{columns: Map.keys(row), rows: [Map.values(row)]}}
      end
    end

    def query(_, _), do: {:ok, %{rows: []}}

    defp schema, do: Process.get(:fake_repo_schema, %{})
  end

  defp with_schema(schema), do: Process.put(:fake_repo_schema, schema)

  defp users_table(row), do: %{tables: ["users"], users: %{1 => Map.put(row, "id", 1)}}

  describe "get_user_info/2 email discovery" do
    test "reads email directly from the users table" do
      with_schema(users_table(%{"email" => "john@example.com", "first_name" => "John", "last_name" => "Doe"}))

      assert {:ok, user_info} = AutoDiscover.get_user_info(FakeRepo, 1)
      assert user_info.email == "john@example.com"
      assert user_info.name == "John Doe"
    end

    test "follows primary_email_id to the emails table" do
      users_table(%{"first_name" => "Jane", "last_name" => "Smith", "primary_email_id" => 10})
      |> Map.put(:emails, %{10 => "jane@example.com"})
      |> with_schema()

      assert {:ok, user_info} = AutoDiscover.get_user_info(FakeRepo, 1)
      assert user_info.email == "jane@example.com"
      assert user_info.name == "Jane Smith"
    end

    test "reads an email_address field" do
      with_schema(
        users_table(%{"email_address" => "charlie@example.com", "first_name" => "Charlie", "last_name" => "Brown"})
      )

      assert {:ok, user_info} = AutoDiscover.get_user_info(FakeRepo, 1)
      assert user_info.email == "charlie@example.com"
      assert user_info.name == "Charlie Brown"
    end
  end

  describe "get_user_info/2 name discovery" do
    test "uses full_name when available" do
      with_schema(users_table(%{"email" => "bob@example.com", "full_name" => "Bob Johnson"}))

      assert {:ok, %{name: "Bob Johnson"}} = AutoDiscover.get_user_info(FakeRepo, 1)
    end

    test "uses name when available" do
      with_schema(users_table(%{"email" => "alice@example.com", "name" => "Alice"}))

      assert {:ok, %{name: "Alice"}} = AutoDiscover.get_user_info(FakeRepo, 1)
    end

    test "returns nil name when only an email exists" do
      with_schema(users_table(%{"email" => "minimal@example.com"}))

      assert {:ok, user_info} = AutoDiscover.get_user_info(FakeRepo, 1)
      assert user_info.email == "minimal@example.com"
      assert user_info.name == nil
    end
  end

  describe "get_user_info/2 table discovery" do
    test "falls back to a singular user table" do
      with_schema(%{
        tables: ["user"],
        user: %{1 => %{"email" => "singular@example.com", "id" => 1, "name" => "Singular User"}}
      })

      assert {:ok, user_info} = AutoDiscover.get_user_info(FakeRepo, 1)
      assert user_info.email == "singular@example.com"
      assert user_info.name == "Singular User"
    end
  end

  describe "get_user_info/2 error cases" do
    test "returns a guidance message when no user table exists" do
      with_schema(%{tables: []})

      assert {:error, error_msg} = AutoDiscover.get_user_info(FakeRepo, 1)
      assert error_msg =~ "could not auto-discover your user table"
      assert error_msg =~ "implement a custom UserAdapter"
    end

    test "returns a guidance message when no email field can be discovered" do
      with_schema(users_table(%{"first_name" => "John", "username" => "johndoe"}))

      assert {:error, error_msg} = AutoDiscover.get_user_info(FakeRepo, 1)
      assert is_binary(error_msg)
      assert error_msg =~ "email field"
      assert error_msg =~ "UserAdapter"
    end

    test "returns :user_not_found for an unknown id" do
      with_schema(users_table(%{"email" => "john@example.com"}))

      assert {:error, :user_not_found} = AutoDiscover.get_user_info(FakeRepo, 999)
    end

    test "treats a dangling primary_email_id as a missing email field" do
      with_schema(users_table(%{"name" => "Test User", "primary_email_id" => 999}))

      assert {:error, error_msg} = AutoDiscover.get_user_info(FakeRepo, 1)
      assert is_binary(error_msg)
    end
  end

  describe "custom user adapter implementation" do
    defmodule CustomUserAdapter do
      @behaviour PaperTiger.UserAdapter

      @impl true
      def get_user_info(_repo, user_id) do
        {:ok, %{email: "custom#{user_id}@example.com", name: "Custom User #{user_id}"}}
      end
    end

    test "custom adapter can be implemented" do
      assert {:ok, user_info} = CustomUserAdapter.get_user_info(nil, 42)
      assert user_info.name == "Custom User 42"
      assert user_info.email == "custom42@example.com"
    end
  end
end
