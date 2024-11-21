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

  describe "EK1100 example" do
    @tag :ek1100
    test "configure" do
      :ok = EthercatEx.Nif.request_master()
      :ok = EthercatEx.Nif.master_create_domain()
      :ok = EthercatEx.Nif.master_slave_config(0, 0, 0x00000002, 0x044C2C52)
      # TODO pass configuration through
      :ok = EthercatEx.Nif.slave_config_pdos(nil)
      :ok = EthercatEx.Nif.master_activate()
    end
  end

  describe "Scan network" do
    @tag :scan
    test "yo" do
      :ok = EthercatEx.Nif.request_master()
      :ok = EthercatEx.Nif.master_activate()
      :ok = EthercatEx.Nif.master_state()
    end
  end
end
