defmodule NifTest do
  use ExUnit.Case, async: true

  describe "positiv tests" do
    test "request master" do
      assert EthercatEx.Nif.request_master() == :ok
    end
  end

  describe "negative tests" do
    test "first create master when creating new domain" do
      assert EthercatEx.Nif.master_create_domain() == :error
    end
  end
end
