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

  @tag :ek1100
  describe "EK1100 example" do
    test "configure" do
      :ok = EthercatEx.Nif.request_master()
      :ok = EthercatEx.Nif.master_create_domain()
      :ok = EthercatEx.Nif.master_slave_config(0, 0, 0x00000002, 0x044c2c52)
      :ok = EthercatEx.Nif.slave_config_pdos(nil) # TODO pass configuration through
      :ok = EthercatEx.Nif.master_activate()
    end
  end
end
