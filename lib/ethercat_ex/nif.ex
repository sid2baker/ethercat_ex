defmodule EthercatEx.Nif do
  @moduledoc false
  use Zig,
    otp_app: :zigler,
    c: [
      include_dirs: "/usr/include/",
      link_lib: [{:system, "fakeethercat"}, {:system, "ethercat"}]
    ],
    nifs: [
      version_magic: [],
      request_master: [],
      master_create_domain: [],
      master_reset: [],
      release_master: [],
      master_get_slave: []
    ],
    resources: [
      :MasterResource,
      :DomainResource
    ]

  ~Z"""
  const beam = @import("beam");
  const root = @import("root");
  const ecrt = @cImport(@cInclude("ecrt.h"));

  pub const MasterResource = beam.Resource(*ecrt.ec_master_t, root, .{ .Callbacks = MasterResourceCallbacks });
  pub const DomainResource = beam.Resource(*ecrt.ec_domain_t, root, .{});

  pub const MasterResourceCallbacks = struct {
      pub fn dtor(s: **ecrt.ec_master_t) void {
          ecrt.ecrt_release_master(s.*);
      }
  };

  const MasterError = error{
      MasterNotFound,
      ResetError,
      GetSlaveError,
  };

  pub fn version_magic() !u32 {
      return ecrt.ecrt_version_magic();
  }

  pub fn request_master() !MasterResource {
      const master = ecrt.ecrt_request_master(0) orelse return MasterError.MasterNotFound;
      return MasterResource.create(master, .{});
  }

  pub fn master_create_domain(master: beam.term) !DomainResource {
      const m = try beam.get(MasterResource, master, .{});
      const domain = ecrt.ecrt_master_create_domain(m.unpack()) orelse return MasterError.MasterNotFound;
      return DomainResource.create(domain, .{});
  }

  pub fn master_get_slave(master: beam.term, slave_position: u16) !beam.term {
      const m = try beam.get(MasterResource, master, .{});
      var slave_info: ecrt.ec_slave_info_t = undefined;
      const result = ecrt.ecrt_master_get_slave(m.unpack(), slave_position, &slave_info);
      if (result != 0) {
          return MasterError.GetSlaveError;
      }
      return beam.make(slave_info, .{});
  }

  pub fn master_reset(master: beam.term) !void {
      const m = try beam.get(MasterResource, master, .{});
      const result = ecrt.ecrt_master_reset(m.unpack());
      if (result != 0) {
          return MasterError.ResetError;
      }
  }

  pub fn release_master(master: beam.term) !void {
      const m = try beam.get(MasterResource, master, .{});
      ecrt.ecrt_release_master(m.unpack());
  }
  """

  # def request_master(), do: :erlang.nif_error(:nif_not_loaded)
  # def master_create_domain(_name), do: :erlang.nif_error(:nif_not_loaded)
  # def master_remove_domain(_name), do: :erlang.nif_error(:nif_not_loaded)

  # def master_get_slave(_index), do: :erlang.nif_error(:nif_not_loaded)

  # def master_slave_config(_alias, _position, _vendor_id, _product_code),
  #   do: :erlang.nif_error(:nif_not_loaded)

  # def slave_config_pdos(_config), do: :erlang.nif_error(:nif_not_loaded)
  # def master_activate, do: :erlang.nif_error(:nif_not_loaded)
  # def master_queue_all_domains, do: :erlang.nif_error(:nif_not_laded)

  # def master_send, do: :erlang.nif_error(:nif_not_loaded)
  # def run, do: :erlang.nif_error(:nif_not_loaded)

  # Add additional Elixir wrappers for NIF functions
end
