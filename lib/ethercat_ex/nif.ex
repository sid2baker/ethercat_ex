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
      master_activate: [],
      master_receive: [],
      master_send: [],
      master_state: [],
      master_create_domain: [],
      master_slave_config: [],
      master_reset: [],
      release_master: [],
      master_get_slave: [],
      domain_process: [],
      domain_queue: [],
      domain_data: [],
      domain_state: [],
      slave_config_sync_manager: [],
      slave_config_pdo_assign_add: [],
      slave_config_pdo_assign_clear: [],
      slave_config_pdo_mapping_add: [],
      slave_config_pdo_mapping_clear: [],
      slave_config_reg_pdo_entry: [],
      master_get_pdo: []
    ],
    resources: [
      :MasterResource,
      :DomainResource,
      :SlaveConfigResource
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
      ActivateError,
      PdoRegError,
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

  pub fn master_activate(master: MasterResource) !void {
      const result = ecrt.ecrt_master_activate(master.unpack());
      if (result != 0) return MasterError.ActivateError;
  }

  pub fn master_receive(master: MasterResource) !void {
      _ = ecrt.ecrt_master_receive(master.unpack());
  }

  pub fn master_send(master: MasterResource) !void {
      _ = ecrt.ecrt_master_send(master.unpack());
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

  pub fn domain_process(domain: DomainResource) !void {
      _ = ecrt.ecrt_domain_process(domain.unpack());
  }

  pub fn domain_queue(domain: DomainResource) !void {
      _ = ecrt.ecrt_domain_queue(domain.unpack());
  }

  // since ecrt_domain_data just returns domain->process_data
  // this should be managed inside zig.
  // So there should be these functions
  // get_domain_value(domain, offset, bit_position?)
  // which returns the current value
  // set_domain_value(domain, offset, bit_position?, value)
  // which sets the value
  // and subscribe_domain_value(domain, offset, bit_position?)
  // which subscribes to changes of the value
  pub fn domain_data(domain: DomainResource) ![*c]u8 {
      const result = ecrt.ecrt_domain_data(domain.unpack());
      return result;
  }

  pub fn domain_state(domain: DomainResource) !beam.term {
      var state: ecrt.ec_domain_state_t = undefined;
      _ = ecrt.ecrt_domain_state(domain.unpack(), &state);
      return beam.make(state, .{});
  }

  pub fn slave_config_sync_manager(slave_config: SlaveConfigResource, sync_index: u8, direction: ecrt.ec_direction_t, watchdog_mode: ecrt.ec_watchdog_mode_t) !void {
      _ = ecrt.ecrt_slave_config_sync_manager(slave_config.unpack(), sync_index, direction, watchdog_mode);
  }

  pub fn slave_config_pdo_assign_add(slave_config: SlaveConfigResource, sync_index: u8, index: u16) !void {
    _ = ecrt.ecrt_slave_config_pdo_assign_add(slave_config.unpack(), sync_index, index);
  }

  pub fn slave_config_pdo_assign_clear(slave_config: SlaveConfigResource, sync_index: u8) !void {
      _ = ecrt.ecrt_slave_config_pdo_assign_clear(slave_config.unpack(), sync_index);
  }

  pub fn slave_config_pdo_mapping_add(slave_config: SlaveConfigResource, pdo_index: u16, entry_index: u16, entry_subindex: u8, entry_bit_length: u8) !void {
      _ = ecrt.ecrt_slave_config_pdo_mapping_add(slave_config.unpack(), pdo_index, entry_index, entry_subindex, entry_bit_length);
  }

  pub fn slave_config_pdo_mapping_clear(slave_config: SlaveConfigResource, pdo_index: u16) !void {
      _ = ecrt.ecrt_slave_config_pdo_mapping_clear(slave_config.unpack(), pdo_index);
  }

  pub fn slave_config_reg_pdo_entry(slave_config: SlaveConfigResource, entry_index: u16, entry_subindex: u8, domain: DomainResource) !u32 {
      var bit_position: c_uint = 0;
      const result: c_int = ecrt.ecrt_slave_config_reg_pdo_entry(slave_config.unpack(), entry_index, entry_subindex, domain.unpack(), &bit_position);
      if (result >= 0) {
        return @as(u32, @intCast(result));
      } else {
        return MasterError.PdoRegError;
      }
  }

  // TODO: look for further functions to implement which aren't listed in ecrt.h (https://gitlab.com/etherlab.org/ethercat/-/blob/stable-1.6/lib/master.c)
  pub fn master_get_pdo(master: MasterResource, slave_position: u16, sync_index: u8, pos: u16) !void {
      var pdo: ecrt.ec_pdo_info_t = undefined;
      _ = ecrt.ecrt_master_get_pdo(master.unpack(), slave_position, sync_index, pos, &pdo);
      //return beam.make(pdo, .{});
  }
  """
end
