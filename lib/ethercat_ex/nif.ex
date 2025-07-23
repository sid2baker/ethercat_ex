defmodule EthercatEx.Nif do
  @moduledoc false
  use Zig,
    otp_app: :zigler,
    c: [
      include_dirs: "/usr/include/",
      link_lib:
        if Mix.env() == :test do
          [{:system, "fakeethercat"}, {:system, "ethercat"}]
        else
          {:system, "ethercat"}
        end
    ],
    nifs: [
      version_magic: [],
      request_master: [],
      master_state: [],
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
  const std = @import("std");
  const beam = @import("beam");
  const root = @import("root");
  const ecrt = @cImport(@cInclude("ecrt.h"));

  pub const MasterResource = beam.Resource(*ecrt.ec_master_t, root, .{ .Callbacks = MasterResourceCallbacks });
  pub const DomainResource = beam.Resource(*ecrt.ec_domain_t, root, .{});
  pub const SlaveConfigResource = beam.Resource(*ecrt.ec_slave_config_t, root, .{});

  pub const MasterResourceCallbacks = struct {
      pub fn dtor(s: **ecrt.ec_master_t) void {
          std.debug.print("dtor called: {}\n", .{s.*});
          ecrt.ecrt_release_master(s.*);
      }
  };

  const MasterError = error{
      MasterNotFound,
      ResetError,
      GetSlaveError,
      SlaveConfigError,
  };

  // this is needed since zig doesn't support bitfields. See https://github.com/ziglang/zig/issues/1499
  const ec_master_state_t = packed struct {
    slaves_responding: u32, // 32 bits
    al_states: u4,         // 4 bits
    link_up: u1,           // 1 bit
    padding: u27,          // 27 bits to align to 64 bits (8 bytes)
  };

  pub fn version_magic() !u32 {
      return ecrt.ecrt_version_magic();
  }

  pub fn request_master() !MasterResource {
      const master = ecrt.ecrt_request_master(0) orelse return MasterError.MasterNotFound;
      return MasterResource.create(master, .{.released = false});
  }

  pub fn master_state(master: MasterResource) !beam.term {
    var state: ec_master_state_t = undefined;
    const result = ecrt.ecrt_master_state(master.unpack(), @ptrCast(&state));
    if (result != 0) {
      return MasterError.MasterNotFound;
    }
    return beam.make(state, .{.as = .map});
  }

  pub fn master_create_domain(master: MasterResource) !DomainResource {
      const domain = ecrt.ecrt_master_create_domain(master.unpack()) orelse return MasterError.MasterNotFound;
      return DomainResource.create(domain, .{});
  }

  pub fn master_slave_config(master: MasterResource, alias: u16, position: u16, vendor_id: u32, product_code: u32) !SlaveConfigResource {
      const slave_config = ecrt.ecrt_master_slave_config(master.unpack(), alias, position, vendor_id, product_code) orelse return MasterError.SlaveConfigError;
      return SlaveConfigResource.create(slave_config, .{});
  }

  pub fn master_get_slave(master: MasterResource, slave_position: u16) !beam.term {
      var slave_info: ecrt.ec_slave_info_t = undefined;
      const result = ecrt.ecrt_master_get_slave(master.unpack(), slave_position, &slave_info);
      if (result != 0) {
          return MasterError.GetSlaveError;
      }
      return beam.make(slave_info, .{});
  }

  pub fn master_reset(master: MasterResource) !void {
      const result = ecrt.ecrt_master_reset(master.unpack());
      if (result != 0) {
          return MasterError.ResetError;
      }
  }

  pub fn release_master(master: MasterResource) !void {
      // TODO check if master.release needs to be called
      ecrt.ecrt_release_master(master.unpack());
      master.release();
      std.debug.print("Master released: {}\n", .{master.unpack()});
  }
  """
end
