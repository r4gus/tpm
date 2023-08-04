const std = @import("std");

pub const tis = @import("tis.zig");
pub const io = @import("io.zig");

pub const Interface = enum(u8) {
    I2C,
    SPI,
    LPC,
};

pub const Context = extern struct {
    interface: extern struct {
        type: Interface,
        device: *anyopaque,
        read: *const fn (dev: *anyopaque, addr: u24, out: []u8) tis.TISError!usize,
        write: *const fn (dev: *anyopaque, addr: u24, in: []const u8) tis.TISError!usize,
    },
    tis: extern struct {
        locality: u8 = 0,
        caps: u32 = 0,
        did_vid: u32 = 0,
    } = .{},

    pub fn read(self: @This(), register: u24, in: []u8) !usize {
        if (self.interface.type == .I2C) {
            // Specify the register to access (first byte of the payload)
            var out: [1]u8 = .{@intCast(register & 0xff)};
            std.log.info("[I2C]: reading register with address 0x{s}", .{std.fmt.fmtSliceHexUpper(&out)});
            _ = self.interface.write(self.interface.device, TPM_I2C_DEFAULT_ADDRESS, &out) catch |err| {
                std.log.err("[I2C]: unable to set register address ({any})", .{err});
                return err;
            };

            // Read from register previously specified
            return self.interface.read(self.interface.device, TPM_I2C_DEFAULT_ADDRESS, in) catch |err| {
                std.log.err("[I2C]: unable to read from register ({any})", .{err});
                return err;
            };
        } else {
            return error.UnsupportedInterface;
        }
    }

    pub fn int_caps(self: *@This(), locality: u8) !u24 {
        return if (self.interface.type == .I2C) blk: {
            break :blk tis.registers.register(tis.registers.INT_CAPS, locality);
        } else blk: {
            break :blk error.UnsupportedRegister;
        };
    }

    pub fn STS(self: *@This(), locality: u8) u24 {
        _ = self;
        return tis.registers.register(tis.registers.STS, locality);
    }

    pub fn INTF_CAPS(self: *@This(), locality: u8) u24 {
        return if (self.interface.type == .I2C) blk: {
            break :blk tis.registers.register(tis.registers.INTF_CAPS_I2C, locality);
        } else blk: {
            break :blk tis.registers.register(tis.registers.INTF_CAPS, locality);
        };
    }
};

// I2C

const TPM_I2C_DEFAULT_ADDRESS = 0x2E;

// TODO: I2C repeated start condition (Sr) if not yet implemented
// TODO: I2C clock stretching if not yet implemented

pub const StatusRegister = packed struct {
    reserved1: u1,
    responseEntry: u1,
    selfTestDone: u1,
    expect: u1,
    dataAvail: u1,
    tpmGo: u1,
    commandReady: u1,
    stsValid: u1,
    burstCount: u16,
    commandCancel: u1,
    resetEstablishmentBit: u1,
    reserved: u6,
};

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Types
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

/// Interface type used for command tags
pub const TPMI_ST_COMMAND_TAG = enum(u16) {
    /// Indicates that the command has no attached sessions and
    /// no authorizationSize/parameterSize value is present.
    TPM_ST_NO_SESSIONS = 0x8001,
    /// Indicates that the command has one or more attached
    /// sessions and the authorizationSize/parameterSize field
    /// is present.
    TPM_ST_SESSIONS = 0x8002,
};

/// Command Codes
pub const TPM_CC = enum(u32) {
    TPM_CC_Startup = 0x00000144,
};

/// Startup Type
pub const TPM_SU = enum(u16) {
    /// * On TPM2_Shutdown(): Tells TPM to prepare for loss of power and save state
    /// * On TPM2_Startup(): TPM should perform TPM Reset or TPM Restart
    TPM_SU_CLEAR = 0x0000,
    /// * On TPM2_Shutdown(): Tells TPM to prepare for loss of power and save state
    /// * On TPM2_Startup(): TPM should restore the state saved by TPM2_Shutdown(TPM_SU_STATE)
    TPM_SU_STATE = 0x0001,
};

/// TPM Startup command
pub const CTPM2_Startup = extern struct {
    tag: TPMI_ST_COMMAND_TAG,
    commandSize: u32 = 12,
    commandCode: TPM_CC,
    // --- Arguments
    startupType: TPM_SU,
};
