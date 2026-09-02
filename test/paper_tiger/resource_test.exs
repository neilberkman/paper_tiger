defmodule PaperTiger.ResourceTest do
  use ExUnit.Case, async: true

  import PaperTiger.Resource

  describe "param/3" do
    test "reads atom and string keys" do
      assert param(%{code: "A"}, :code) == "A"
      assert param(%{"code" => "B"}, :code) == "B"
      assert param(%{"code" => "B", code: "A"}, :code) == "A"
    end

    test "falls back to the default for a missing key or nil value" do
      assert param(%{}, :code) == nil
      assert param(%{}, :code, "x") == "x"
      assert param(%{code: nil}, :code, "x") == "x"
      assert param(nil, :code, "x") == "x"
    end

    test "keeps false as a real value" do
      assert param(%{trial: false}, :trial, true) == false
      assert param(%{"trial" => false}, :trial, true) == false
    end
  end

  describe "to_integer/2" do
    test "parses integers and strings" do
      assert to_integer(5) == 5
      assert to_integer("5") == 5
    end

    test "uses the default when the value cannot be parsed" do
      assert to_integer("abc") == 0
      assert to_integer("abc", 1) == 1
      assert to_integer(nil, 7) == 7
    end
  end
end
