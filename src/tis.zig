//! TPM Interface Specification (TIS)

const tpm = @import("main.zig");

const MAX_FRAME_SIZE = 64;

pub const TISError = error{
    DeviceNotPresent,
    NoAcknowledge,
    Unexpected,
};

pub const registers = struct {
    /// For system software, the TPM has a 64 bit address 0x0000_0000_FED4_xxxx.
    /// On LPC, the chipset passes the least significant 16 bits to the TPM. On
    /// SPI, the chipset passes the least significant 24 bit so the TPM. On I2C
    /// the chipset passes the least significant 8 bits to the TPM.
    pub const BASE: u24 = 0xD40000;

    pub inline fn register(addr: u16, locality: u8) u24 {
        return (BASE | (@as(u24, @intCast(locality)) << 12) | @as(u24, @intCast(addr)));
    }

    // I2C
    pub const ACCESS_I2C: u16 = 0x04;
    pub const INTF_CAPS_I2C: u16 = 0x30;
    pub const DID_VID_I2C: u16 = 0x48;
    pub const RID_I2C: u16 = 0x4c;
    pub const INT_CAPS: u16 = 0x14;
    pub const I2C_DEVICE_ADDR: u16 = 0x38;
    pub const DATA_CSUM_ENABLE: u16 = 0x40;
    pub const DATA_CSUM: u16 = 0x44;

    // Other
    pub const ACCESS: u16 = 0x00;
    pub const INTF_CAPS: u16 = 0x14;
    pub const DID_VID: u16 = 0x0f00;
    pub const RID: u16 = 0x0f04;

    // Shared
    pub const INT_ENABLE: u16 = 0x08;
    pub const INT_VECTOR: u16 = 0x0c;
    pub const INT_STATUS: u16 = 0x10;
    pub const STS: u16 = 0x18;
    pub const BURST_COUNT: u16 = 0x19;
    pub const DATA_FIFO: u16 = 0x24;
    pub const XDATA_FIFO: u16 = 0x83;
};

pub const InterruptCapability = packed struct {
    /// __MANDATORY__: Corresponds to TPM_INT_ENABLE.dataAvailIntEnable.
    ///
    /// * `1 = supported`
    /// * `0 = not allowed`
    dataAvailIntSupport: u1,
    /// __OPTIONAL__: Corresponds to TPM_INT_ENABLE.stsValidIntEnable
    ///
    /// * `1 = supported`
    /// * `0 = not allowed`
    stsValidIntSupport: u1,
    /// __OPTIONAL__: Corresponds to TPM_INT_ENABLE.localityChangeIntEnable.
    ///
    /// * `1 = supported`
    /// * `0 = not allowed`
    localityChangeIntSupport: u1,
    /// Reserved: Always 0 on read
    reserved1: u4,
    /// __OPTIONAL__: Corresponds to TPM_INT_ENABLE.commandReadyEnable.
    ///
    /// * `1 = supported`
    /// * `0 = not allowed`
    commandReadyIntSupport: u1,
    /// Reserved: Always 0 on read
    reserved2: u24,
};

pub const StatusRegister = packed struct {
    reserved1: u1,
    /// Software writes a 1 to this field to force the TPM to re-send the response.
    /// Reads always return 0.
    responseRetry: u1,
    /// This field indicates that the TPM has completed all self-test actions
    /// following a TPM2_SelfTest command. Read of 0 indicates self-test
    /// is not complete. Read of 1 indicates self-test is complete.
    selfTestDone: u1,
    /// The TPM sets this field to a value of 1 when it expects another byte
    /// of data for a command. It clears this field to a value of 0 when it has
    /// received all the data it expects for that command, based on the TPM
    /// size field within the packet.
    /// Valid indicator: TPM_STS.stsValid = 1
    expect: u1,
    dataAvail: u1,
    tpmGo: u1,
    commandReady: u1,
    stsValid: u1,
    burstCount: u16,
    commandCancel: u1,
    resetEstablishmentBit: u1,
    reserved2: u6,
};

pub const TPMFamily = enum(u2) {
    TPM_1_2 = 0,
    TPM_2_0 = 1,
};

pub const CapLocality = enum(u2) {
    /// This I2C TPM supports Locality 0 only.
    One = 0,
    /// This I2C TPM supports 5 localities (0 – 4).
    Five = 1,
    /// This I2C TPM supports all localities (0 – 255).
    All = 2,
};

pub const I2CInterfaceType = enum(u4) {
    FIFO_I2C = 2,
};

pub const I2CInterfaceVersion = enum(u3) {
    ///  TCG I2C interface 1.0
    TCG_I2C_Interface_1_0 = 0,
};

pub const I2CDevAddrChange = enum(u2) {
    /// Changing the I2C Device Address is not supported
    NotSupported = 0,
    /// Changing the I2C Device Address is supported using a vendor defined mechanism
    Vendor = 1,
    /// Reserved (not allowed)
    Reserved1 = 2,
    /// Changing the I2C Device Address is supported using the TCG defined mechanism (see 6.5.15)
    TCG = 3,
};

pub const I2CBurstCount = enum(u1) {
    Dynamic = 0,
    Static = 1,
};

pub const I2CInterfaceCapabilityRegister = packed struct {
    interfaceType: I2CInterfaceType,
    /// 000: TCG I2C interface 1.0 as defined in this specification
    /// 001 – 111: Reserved
    interfaceVersion: I2CInterfaceVersion,
    /// TPM Family Identifier
    /// 00: TPM 1.2 Family
    /// 01: TPM 2.0 Family
    /// 10 – 11: Reserved
    tpmFamily: TPMFamily,
    /// Guard time in us
    guard_time: u8,
    write_write: u1,
    write_read: u1,
    read_write: u1,
    read_read: u1,
    smSupport: u1,
    fmSupport: u1,
    fmPlusSupport: u1,
    hsModeSupport: u1,
    capLocality: CapLocality,
    devAdrChange: I2CDevAddrChange,
    burstCountStatic: I2CBurstCount,
    guard_time_sr: u1,
    reserved1: u1,
};
