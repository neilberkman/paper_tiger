defmodule PaperTiger.UserAdapters.AutoDiscoverTest do
  use ExUnit.Case, async: true

  alias PaperTiger.UserAdapters.AutoDiscover

  describe "get_user_info/2 with simple schema (email in users table)" do
    defmodule SimpleRepo do
      def query("SELECT EXISTS" <> _, ["users"]), do: {:ok, %{rows: [[true]]}}
      def query("SELECT EXISTS" <> _, _), do: {:ok, %{rows: [[false]]}}

      def query("SELECT * FROM users WHERE id = $1 LIMIT 1", [1]) do
        {:ok,
         %{
           columns: ["id", "email", "first_name", "last_name"],
           rows: [[1, "john@example.com", "John", "Doe"]]
         }}
      end

      def query(_, _), do: {:ok, %{rows: []}}
    end

    test "discovers user with email directly in users table" do
      assert {:ok, user_info} = AutoDiscover.get_user_info(SimpleRepo, 1)
      assert user_info.email == "john@example.com"
      assert user_info.name == "John Doe"
    end
  end

  describe "get_user_info/2 with separate emails table" do
    defmodule EmailsTableRepo do
      def query("SELECT EXISTS" <> _, ["users"]), do: {:ok, %{rows: [[true]]}}
      def query("SELECT EXISTS" <> _, _), do: {:ok, %{rows: [[false]]}}

      def query("SELECT * FROM users WHERE id = $1 LIMIT 1", [1]) do
        {:ok,
         %{
           columns: ["id", "primary_email_id", "first_name", "last_name"],
           rows: [[1, 10, "Jane", "Smith"]]
         }}
      end

      def query("SELECT address FROM emails WHERE id = $1 LIMIT 1", [10]) do
        {:ok, %{rows: [["jane@example.com"]]}}
      end

      def query(_, _), do: {:ok, %{rows: []}}
    end

    test "follows foreign key to emails table" do
      assert {:ok, user_info} = AutoDiscover.get_user_info(EmailsTableRepo, 1)
      assert user_info.email == "jane@example.com"
      assert user_info.name == "Jane Smith"
    end
  end

  describe "get_user_info/2 with full_name field" do
    defmodule FullNameRepo do
      def query("SELECT EXISTS" <> _, ["users"]), do: {:ok, %{rows: [[true]]}}
      def query("SELECT EXISTS" <> _, _), do: {:ok, %{rows: [[false]]}}

      def query("SELECT * FROM users WHERE id = $1 LIMIT 1", [1]) do
        {:ok,
         %{
           columns: ["id", "email", "full_name"],
           rows: [[1, "bob@example.com", "Bob Johnson"]]
         }}
      end

      def query(_, _), do: {:ok, %{rows: []}}
    end

    test "uses full_name when available" do
      assert {:ok, user_info} = AutoDiscover.get_user_info(FullNameRepo, 1)
      assert user_info.email == "bob@example.com"
      assert user_info.name == "Bob Johnson"
    end
  end

  describe "get_user_info/2 with single name field" do
    defmodule SingleNameRepo do
      def query("SELECT EXISTS" <> _, ["users"]), do: {:ok, %{rows: [[true]]}}
      def query("SELECT EXISTS" <> _, _), do: {:ok, %{rows: [[false]]}}

      def query("SELECT * FROM users WHERE id = $1 LIMIT 1", [1]) do
        {:ok,
         %{
           columns: ["id", "email", "name"],
           rows: [[1, "alice@example.com", "Alice"]]
         }}
      end

      def query(_, _), do: {:ok, %{rows: []}}
    end

    test "uses name field when available" do
      assert {:ok, user_info} = AutoDiscover.get_user_info(SingleNameRepo, 1)
      assert user_info.email == "alice@example.com"
      assert user_info.name == "Alice"
    end
  end

  describe "get_user_info/2 with email_address field" do
    defmodule EmailAddressRepo do
      def query("SELECT EXISTS" <> _, ["users"]), do: {:ok, %{rows: [[true]]}}
      def query("SELECT EXISTS" <> _, _), do: {:ok, %{rows: [[false]]}}

      def query("SELECT * FROM users WHERE id = $1 LIMIT 1", [1]) do
        {:ok,
         %{
           columns: ["id", "email_address", "first_name", "last_name"],
           rows: [[1, "charlie@example.com", "Charlie", "Brown"]]
         }}
      end

      def query(_, _), do: {:ok, %{rows: []}}
    end

    test "discovers email_address field" do
      assert {:ok, user_info} = AutoDiscover.get_user_info(EmailAddressRepo, 1)
      assert user_info.email == "charlie@example.com"
      assert user_info.name == "Charlie Brown"
    end
  end

  describe "get_user_info/2 with only email (no name)" do
    defmodule EmailOnlyRepo do
      def query("SELECT EXISTS" <> _, ["users"]), do: {:ok, %{rows: [[true]]}}
      def query("SELECT EXISTS" <> _, _), do: {:ok, %{rows: [[false]]}}

      def query("SELECT * FROM users WHERE id = $1 LIMIT 1", [1]) do
        {:ok,
         %{
           columns: ["id", "email"],
           rows: [[1, "minimal@example.com"]]
         }}
      end

      def query(_, _), do: {:ok, %{rows: []}}
    end

    test "handles users with only email field" do
      assert {:ok, user_info} = AutoDiscover.get_user_info(EmailOnlyRepo, 1)
      assert user_info.email == "minimal@example.com"
      assert user_info.name == nil
    end
  end

  describe "get_user_info/2 with user table (singular)" do
    defmodule SingularUserRepo do
      def query("SELECT EXISTS" <> _, ["users"]), do: {:ok, %{rows: [[false]]}}
      def query("SELECT EXISTS" <> _, ["user"]), do: {:ok, %{rows: [[true]]}}
      def query("SELECT EXISTS" <> _, _), do: {:ok, %{rows: [[false]]}}

      def query("SELECT * FROM user WHERE id = $1 LIMIT 1", [1]) do
        {:ok,
         %{
           columns: ["id", "email", "name"],
           rows: [[1, "singular@example.com", "Singular User"]]
         }}
      end

      def query(_, _), do: {:ok, %{rows: []}}
    end

    test "discovers 'user' table (singular)" do
      assert {:ok, user_info} = AutoDiscover.get_user_info(SingularUserRepo, 1)
      assert user_info.email == "singular@example.com"
      assert user_info.name == "Singular User"
    end
  end

  describe "get_user_info/2 error cases" do
    defmodule NoUserTableRepo do
      def query("SELECT EXISTS" <> _, _), do: {:ok, %{rows: [[false]]}}
      def query(_, _), do: {:ok, %{rows: []}}
    end

    test "returns error when no user table exists" do
      assert {:error, error_msg} = AutoDiscover.get_user_info(NoUserTableRepo, 1)
      assert error_msg =~ "could not auto-discover your user table"
      assert error_msg =~ "implement a custom UserAdapter"
    end

    defmodule NoEmailFieldRepo do
      def query("SELECT EXISTS" <> _, ["users"]), do: {:ok, %{rows: [[true]]}}
      def query("SELECT EXISTS" <> _, _), do: {:ok, %{rows: [[false]]}}

      def query("SELECT * FROM users WHERE id = $1 LIMIT 1", [1]) do
        {:ok,
         %{
           columns: ["id", "username", "first_name"],
           rows: [[1, "johndoe", "John"]]
         }}
      end

      def query(_, _), do: {:ok, %{rows: []}}
    end

    test "returns error when email field cannot be discovered" do
      assert {:error, error_msg} = AutoDiscover.get_user_info(NoEmailFieldRepo, 1)
      assert is_binary(error_msg)
      assert error_msg =~ "email field"
      assert error_msg =~ "UserAdapter"
    end

    defmodule UserNotFoundRepo do
      def query("SELECT EXISTS" <> _, ["users"]), do: {:ok, %{rows: [[true]]}}
      def query("SELECT EXISTS" <> _, _), do: {:ok, %{rows: [[false]]}}

      def query("SELECT * FROM users WHERE id = $1 LIMIT 1", [999]) do
        {:ok, %{columns: ["id", "email"], rows: []}}
      end

      def query(_, _), do: {:ok, %{rows: []}}
    end

    test "returns error when user not found" do
      assert {:error, :user_not_found} = AutoDiscover.get_user_info(UserNotFoundRepo, 999)
    end

    defmodule MissingEmailRecordRepo do
      def query("SELECT EXISTS" <> _, ["users"]), do: {:ok, %{rows: [[true]]}}
      def query("SELECT EXISTS" <> _, _), do: {:ok, %{rows: [[false]]}}

      def query("SELECT * FROM users WHERE id = $1 LIMIT 1", [1]) do
        {:ok,
         %{
           columns: ["id", "primary_email_id", "name"],
           rows: [[1, 999, "Test User"]]
         }}
      end

      def query("SELECT address FROM emails WHERE id = $1 LIMIT 1", [999]) do
        {:ok, %{rows: []}}
      end

      def query(_, _), do: {:ok, %{rows: []}}
    end

    test "returns error when email record not found in separate table" do
      # When email record is not found, it falls back to :no_email_field error
      assert {:error, error_msg} = AutoDiscover.get_user_info(MissingEmailRecordRepo, 1)
      assert is_binary(error_msg)
    end
  end

  describe "custom user adapter implementation" do
    defmodule CustomUserAdapter do
      @behaviour PaperTiger.UserAdapter

      @impl true
      def get_user_info(_repo, user_id) do
        # Custom logic for a specific schema
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
