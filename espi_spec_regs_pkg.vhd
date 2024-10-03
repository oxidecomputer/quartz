-- This is a generated file using the RDL tooling. Do not edit by hand.
--
-------------------------------
-- Register "API" Documentation
-------------------------------
--   Each register is defined as a VHDL record and the following functions
--   are provided for use:
--   unpack() takes a std_logic_vector of the register's width (including 
--     reserved bits in their respective positions) and returns an instance
--     of the register's record type with the appropriate bits set.
--     Overloaded with a version that accepts unsigned vectors.
--   pack() takes an instance of the register's record type and returns a
--     a std_logic_vector of the register's width with the appropriate bits 
--     set, (including reserved bits in their respective positions).
--     Overloaded with an unsigned() version as well
--   compress() takes an instance of the register's record type and returns a
--     a std_logic_vector of the register's width with the appropriate bits 
--     set, skipping any reserved fields.
--   uncompress() is the complement of compress() taking a std_logic_vector 
--     in a register's compressed form putting it back into the record type
--   sizeof() returns an integer of the number of used bits in the register
--   rec_reset abusing overload signatures to return the reset value for the
--     register type as defined in the RDL
--   "or","and", "xor" we provide overloads for logical bitwise functions for 
--     the record type with itself on both sides, it on the left side with an 
--     slv on the right, and it on the left side with an unsigned on the right.
--     Note: In cases where enumerated types are used, these will properly 
--       bitwise operate but doing bitwise operations on enumerated values is
--       likely nonsensical.
--   "not" we provide a convenience overload for doing a bitwise not on the 
--     record itself as a unary operator without forcing the user to convert to
--     bits.
--     Note: In cases where enumerated types are used, this will properly 
--       bitwise operate but doing bitwise operations on enumerated values is
--       likely nonsensical.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package espi_spec_regs_pkg is
  -- ------------------------
  -- Addrmap-specific defines
  -- ------------------------
    constant DEVICE_ID_OFFSET : integer := 4;
    constant GENERAL_CAPABILITIES_OFFSET : integer := 8;
    constant CH0_CAPABILITIES_OFFSET : integer := 16;
    constant CH2_CAPABILITIES_OFFSET : integer := 48;
    constant CH3_CAPABILITIES_OFFSET : integer := 64;
    constant CH3_CAPABILITIES2_OFFSET : integer := 68;

  -- ---------------
  -- Register types
  -- ---------------
  -- ---------------
  -- Register device_id definitions
  -- ---------------
  
  type device_id_type is record
      id : std_logic_vector(7 downto 0);
  end record;
  -- register constants
  -- field mask definitions
  constant DEVICE_ID_ID_MASK : std_logic_vector(31 downto 0) := 32x"ff";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return device_id_type;
  function unpack(un : unsigned(31 downto 0)) return device_id_type;
  function pack(rec : device_id_type) return std_logic_vector;
  function pack(rec : device_id_type) return unsigned;
  function compress (rec : device_id_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return device_id_type;
  function sizeof (rec : device_id_type) return integer;
  function rec_reset return device_id_type;
  function "or"  (left, right : device_id_type) return device_id_type;
  function "or"  (left : device_id_type; right : std_logic_vector) return device_id_type;
  function "or"  (left : device_id_type; right : unsigned) return device_id_type;
  function "and" (left, right : device_id_type) return device_id_type;
  function "and" (left : device_id_type; right : std_logic_vector) return device_id_type;
  function "and" (left : device_id_type; right : unsigned) return device_id_type;
  function "xor" (left, right : device_id_type) return device_id_type;
  function "xor" (left : device_id_type; right : std_logic_vector) return device_id_type;
  function "xor" (left : device_id_type; right : unsigned) return device_id_type;
  function "not" (right : device_id_type) return device_id_type;
  -- ---------------
  -- Register general_capabilities definitions
  -- ---------------
  -- Register-specific Enums
  type general_capabilities_io_mode_sel is (
    SINGLE, -- 0
    DUAL, -- 1
    QUAD, -- 2
    RESERVED); -- 3
  type general_capabilities_io_mode_support is (
    SINGLE, -- 0
    DUAL, -- 1
    QUAD, -- 2
    ANY); -- 3
  type general_capabilities_op_freq_select is (
    TWENTY, -- 0
    TWENTYFIVE, -- 1
    THIRTYTHREE, -- 2
    FIFTY, -- 3
    SIXTYSIX, -- 4
    RSVD0, -- 5
    RSVD1, -- 6
    RSVD2); -- 7
  type general_capabilities_op_freq_support is (
    TWENTY, -- 0
    TWENTYFIVE, -- 1
    THIRTYTHREE, -- 2
    FIFTY, -- 3
    SIXTYSIX, -- 4
    RSVD0, -- 5
    RSVD1, -- 6
    RSVD2); -- 7
  
  type general_capabilities_type is record
      crc_en    : std_logic;
      resp_mod_en    : std_logic;
      alert_mode    : std_logic;
      io_mode_sel  : general_capabilities_io_mode_sel;
      io_mode_support  : general_capabilities_io_mode_support;
      alert_select    : std_logic;
      op_freq_select  : general_capabilities_op_freq_select;
      alert_support    : std_logic;
      op_freq_support  : general_capabilities_op_freq_support;
      max_wait : std_logic_vector(3 downto 0);
      flash_support    : std_logic;
      oob_support    : std_logic;
      virt_wire_support    : std_logic;
      periph_support    : std_logic;
  end record;
  -- register constants
  -- field mask definitions
  constant GENERAL_CAPABILITIES_CRC_EN_MASK : std_logic_vector(31 downto 0) := 32x"80000000";
  constant GENERAL_CAPABILITIES_RESP_MOD_EN_MASK : std_logic_vector(31 downto 0) := 32x"40000000";
  constant GENERAL_CAPABILITIES_ALERT_MODE_MASK : std_logic_vector(31 downto 0) := 32x"10000000";
  constant GENERAL_CAPABILITIES_IO_MODE_SEL_MASK : std_logic_vector(31 downto 0) := 32x"c000000";
  constant GENERAL_CAPABILITIES_IO_MODE_SUPPORT_MASK : std_logic_vector(31 downto 0) := 32x"3000000";
  constant GENERAL_CAPABILITIES_ALERT_SELECT_MASK : std_logic_vector(31 downto 0) := 32x"800000";
  constant GENERAL_CAPABILITIES_OP_FREQ_SELECT_MASK : std_logic_vector(31 downto 0) := 32x"700000";
  constant GENERAL_CAPABILITIES_ALERT_SUPPORT_MASK : std_logic_vector(31 downto 0) := 32x"80000";
  constant GENERAL_CAPABILITIES_OP_FREQ_SUPPORT_MASK : std_logic_vector(31 downto 0) := 32x"70000";
  constant GENERAL_CAPABILITIES_MAX_WAIT_MASK : std_logic_vector(31 downto 0) := 32x"f000";
  constant GENERAL_CAPABILITIES_FLASH_SUPPORT_MASK : std_logic_vector(31 downto 0) := 32x"8";
  constant GENERAL_CAPABILITIES_OOB_SUPPORT_MASK : std_logic_vector(31 downto 0) := 32x"4";
  constant GENERAL_CAPABILITIES_VIRT_WIRE_SUPPORT_MASK : std_logic_vector(31 downto 0) := 32x"2";
  constant GENERAL_CAPABILITIES_PERIPH_SUPPORT_MASK : std_logic_vector(31 downto 0) := 32x"1";
  -- some useful functions that operate on the register-specific enums
  function encode(slv : std_logic_vector(1 downto 0)) return general_capabilities_io_mode_sel;
  function decode(enum: general_capabilities_io_mode_sel) return std_logic_vector;
  function encode(slv : std_logic_vector(1 downto 0)) return general_capabilities_io_mode_support;
  function decode(enum: general_capabilities_io_mode_support) return std_logic_vector;
  function encode(slv : std_logic_vector(2 downto 0)) return general_capabilities_op_freq_select;
  function decode(enum: general_capabilities_op_freq_select) return std_logic_vector;
  function encode(slv : std_logic_vector(2 downto 0)) return general_capabilities_op_freq_support;
  function decode(enum: general_capabilities_op_freq_support) return std_logic_vector;
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return general_capabilities_type;
  function unpack(un : unsigned(31 downto 0)) return general_capabilities_type;
  function pack(rec : general_capabilities_type) return std_logic_vector;
  function pack(rec : general_capabilities_type) return unsigned;
  function compress (rec : general_capabilities_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return general_capabilities_type;
  function sizeof (rec : general_capabilities_type) return integer;
  function rec_reset return general_capabilities_type;
  function "or"  (left, right : general_capabilities_type) return general_capabilities_type;
  function "or"  (left : general_capabilities_type; right : std_logic_vector) return general_capabilities_type;
  function "or"  (left : general_capabilities_type; right : unsigned) return general_capabilities_type;
  function "and" (left, right : general_capabilities_type) return general_capabilities_type;
  function "and" (left : general_capabilities_type; right : std_logic_vector) return general_capabilities_type;
  function "and" (left : general_capabilities_type; right : unsigned) return general_capabilities_type;
  function "xor" (left, right : general_capabilities_type) return general_capabilities_type;
  function "xor" (left : general_capabilities_type; right : std_logic_vector) return general_capabilities_type;
  function "xor" (left : general_capabilities_type; right : unsigned) return general_capabilities_type;
  function "not" (right : general_capabilities_type) return general_capabilities_type;
  -- ---------------
  -- Register ch0_capabilities definitions
  -- ---------------
  
  type ch0_capabilities_type is record
      max_read_request_size : std_logic_vector(2 downto 0);
      max_payload_size : std_logic_vector(2 downto 0);
      max_payload_support : std_logic_vector(2 downto 0);
      bus_master_en    : std_logic;
      chan_rdy    : std_logic;
      chan_en    : std_logic;
  end record;
  -- register constants
  -- field mask definitions
  constant CH0_CAPABILITIES_MAX_READ_REQUEST_SIZE_MASK : std_logic_vector(31 downto 0) := 32x"7000";
  constant CH0_CAPABILITIES_MAX_PAYLOAD_SIZE_MASK : std_logic_vector(31 downto 0) := 32x"700";
  constant CH0_CAPABILITIES_MAX_PAYLOAD_SUPPORT_MASK : std_logic_vector(31 downto 0) := 32x"70";
  constant CH0_CAPABILITIES_BUS_MASTER_EN_MASK : std_logic_vector(31 downto 0) := 32x"4";
  constant CH0_CAPABILITIES_CHAN_RDY_MASK : std_logic_vector(31 downto 0) := 32x"2";
  constant CH0_CAPABILITIES_CHAN_EN_MASK : std_logic_vector(31 downto 0) := 32x"1";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return ch0_capabilities_type;
  function unpack(un : unsigned(31 downto 0)) return ch0_capabilities_type;
  function pack(rec : ch0_capabilities_type) return std_logic_vector;
  function pack(rec : ch0_capabilities_type) return unsigned;
  function compress (rec : ch0_capabilities_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return ch0_capabilities_type;
  function sizeof (rec : ch0_capabilities_type) return integer;
  function rec_reset return ch0_capabilities_type;
  function "or"  (left, right : ch0_capabilities_type) return ch0_capabilities_type;
  function "or"  (left : ch0_capabilities_type; right : std_logic_vector) return ch0_capabilities_type;
  function "or"  (left : ch0_capabilities_type; right : unsigned) return ch0_capabilities_type;
  function "and" (left, right : ch0_capabilities_type) return ch0_capabilities_type;
  function "and" (left : ch0_capabilities_type; right : std_logic_vector) return ch0_capabilities_type;
  function "and" (left : ch0_capabilities_type; right : unsigned) return ch0_capabilities_type;
  function "xor" (left, right : ch0_capabilities_type) return ch0_capabilities_type;
  function "xor" (left : ch0_capabilities_type; right : std_logic_vector) return ch0_capabilities_type;
  function "xor" (left : ch0_capabilities_type; right : unsigned) return ch0_capabilities_type;
  function "not" (right : ch0_capabilities_type) return ch0_capabilities_type;
  -- ---------------
  -- Register ch2_capabilities definitions
  -- ---------------
  
  type ch2_capabilities_type is record
      max_payload_select : std_logic_vector(2 downto 0);
      max_payload_support : std_logic_vector(2 downto 0);
      oob_ready    : std_logic;
      oob_en    : std_logic;
  end record;
  -- register constants
  -- field mask definitions
  constant CH2_CAPABILITIES_MAX_PAYLOAD_SELECT_MASK : std_logic_vector(31 downto 0) := 32x"700";
  constant CH2_CAPABILITIES_MAX_PAYLOAD_SUPPORT_MASK : std_logic_vector(31 downto 0) := 32x"70";
  constant CH2_CAPABILITIES_OOB_READY_MASK : std_logic_vector(31 downto 0) := 32x"2";
  constant CH2_CAPABILITIES_OOB_EN_MASK : std_logic_vector(31 downto 0) := 32x"1";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return ch2_capabilities_type;
  function unpack(un : unsigned(31 downto 0)) return ch2_capabilities_type;
  function pack(rec : ch2_capabilities_type) return std_logic_vector;
  function pack(rec : ch2_capabilities_type) return unsigned;
  function compress (rec : ch2_capabilities_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return ch2_capabilities_type;
  function sizeof (rec : ch2_capabilities_type) return integer;
  function rec_reset return ch2_capabilities_type;
  function "or"  (left, right : ch2_capabilities_type) return ch2_capabilities_type;
  function "or"  (left : ch2_capabilities_type; right : std_logic_vector) return ch2_capabilities_type;
  function "or"  (left : ch2_capabilities_type; right : unsigned) return ch2_capabilities_type;
  function "and" (left, right : ch2_capabilities_type) return ch2_capabilities_type;
  function "and" (left : ch2_capabilities_type; right : std_logic_vector) return ch2_capabilities_type;
  function "and" (left : ch2_capabilities_type; right : unsigned) return ch2_capabilities_type;
  function "xor" (left, right : ch2_capabilities_type) return ch2_capabilities_type;
  function "xor" (left : ch2_capabilities_type; right : std_logic_vector) return ch2_capabilities_type;
  function "xor" (left : ch2_capabilities_type; right : unsigned) return ch2_capabilities_type;
  function "not" (right : ch2_capabilities_type) return ch2_capabilities_type;
  -- ---------------
  -- Register ch3_capabilities definitions
  -- ---------------
  
  type ch3_capabilities_type is record
      flash_cap : std_logic_vector(1 downto 0);
      max_rd_req : std_logic_vector(2 downto 0);
      flash_share_mode    : std_logic;
      flash_max_payload_selected : std_logic_vector(2 downto 0);
      flash_max_payload_supported : std_logic_vector(2 downto 0);
      flash_block_erase_size : std_logic_vector(2 downto 0);
      flash_channel_ready    : std_logic;
      flash_channel_enable    : std_logic;
  end record;
  -- register constants
  -- field mask definitions
  constant CH3_CAPABILITIES_FLASH_CAP_MASK : std_logic_vector(31 downto 0) := 32x"30000";
  constant CH3_CAPABILITIES_MAX_RD_REQ_MASK : std_logic_vector(31 downto 0) := 32x"7000";
  constant CH3_CAPABILITIES_FLASH_SHARE_MODE_MASK : std_logic_vector(31 downto 0) := 32x"800";
  constant CH3_CAPABILITIES_FLASH_MAX_PAYLOAD_SELECTED_MASK : std_logic_vector(31 downto 0) := 32x"700";
  constant CH3_CAPABILITIES_FLASH_MAX_PAYLOAD_SUPPORTED_MASK : std_logic_vector(31 downto 0) := 32x"e0";
  constant CH3_CAPABILITIES_FLASH_BLOCK_ERASE_SIZE_MASK : std_logic_vector(31 downto 0) := 32x"1c";
  constant CH3_CAPABILITIES_FLASH_CHANNEL_READY_MASK : std_logic_vector(31 downto 0) := 32x"2";
  constant CH3_CAPABILITIES_FLASH_CHANNEL_ENABLE_MASK : std_logic_vector(31 downto 0) := 32x"1";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return ch3_capabilities_type;
  function unpack(un : unsigned(31 downto 0)) return ch3_capabilities_type;
  function pack(rec : ch3_capabilities_type) return std_logic_vector;
  function pack(rec : ch3_capabilities_type) return unsigned;
  function compress (rec : ch3_capabilities_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return ch3_capabilities_type;
  function sizeof (rec : ch3_capabilities_type) return integer;
  function rec_reset return ch3_capabilities_type;
  function "or"  (left, right : ch3_capabilities_type) return ch3_capabilities_type;
  function "or"  (left : ch3_capabilities_type; right : std_logic_vector) return ch3_capabilities_type;
  function "or"  (left : ch3_capabilities_type; right : unsigned) return ch3_capabilities_type;
  function "and" (left, right : ch3_capabilities_type) return ch3_capabilities_type;
  function "and" (left : ch3_capabilities_type; right : std_logic_vector) return ch3_capabilities_type;
  function "and" (left : ch3_capabilities_type; right : unsigned) return ch3_capabilities_type;
  function "xor" (left, right : ch3_capabilities_type) return ch3_capabilities_type;
  function "xor" (left : ch3_capabilities_type; right : std_logic_vector) return ch3_capabilities_type;
  function "xor" (left : ch3_capabilities_type; right : unsigned) return ch3_capabilities_type;
  function "not" (right : ch3_capabilities_type) return ch3_capabilities_type;
  -- ---------------
  -- Register ch3_capabilities2 definitions
  -- ---------------
  
  type ch3_capabilities2_type is record
      rpmc_sup : std_logic_vector(5 downto 0);
      ebs_sup : std_logic_vector(7 downto 0);
      tgt_rd_size_support : std_logic_vector(2 downto 0);
  end record;
  -- register constants
  -- field mask definitions
  constant CH3_CAPABILITIES2_RPMC_SUP_MASK : std_logic_vector(31 downto 0) := 32x"3f0000";
  constant CH3_CAPABILITIES2_EBS_SUP_MASK : std_logic_vector(31 downto 0) := 32x"ff00";
  constant CH3_CAPABILITIES2_TGT_RD_SIZE_SUPPORT_MASK : std_logic_vector(31 downto 0) := 32x"7";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return ch3_capabilities2_type;
  function unpack(un : unsigned(31 downto 0)) return ch3_capabilities2_type;
  function pack(rec : ch3_capabilities2_type) return std_logic_vector;
  function pack(rec : ch3_capabilities2_type) return unsigned;
  function compress (rec : ch3_capabilities2_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return ch3_capabilities2_type;
  function sizeof (rec : ch3_capabilities2_type) return integer;
  function rec_reset return ch3_capabilities2_type;
  function "or"  (left, right : ch3_capabilities2_type) return ch3_capabilities2_type;
  function "or"  (left : ch3_capabilities2_type; right : std_logic_vector) return ch3_capabilities2_type;
  function "or"  (left : ch3_capabilities2_type; right : unsigned) return ch3_capabilities2_type;
  function "and" (left, right : ch3_capabilities2_type) return ch3_capabilities2_type;
  function "and" (left : ch3_capabilities2_type; right : std_logic_vector) return ch3_capabilities2_type;
  function "and" (left : ch3_capabilities2_type; right : unsigned) return ch3_capabilities2_type;
  function "xor" (left, right : ch3_capabilities2_type) return ch3_capabilities2_type;
  function "xor" (left : ch3_capabilities2_type; right : std_logic_vector) return ch3_capabilities2_type;
  function "xor" (left : ch3_capabilities2_type; right : unsigned) return ch3_capabilities2_type;
  function "not" (right : ch3_capabilities2_type) return ch3_capabilities2_type;
end espi_spec_regs_pkg;

package body espi_spec_regs_pkg is
  ---------------------------------------
  -- device_id_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return device_id_type is
      variable ret_rec : device_id_type;
    begin
        ret_rec.id:= slv(7 downto 0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return device_id_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : device_id_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(7 downto 0) := std_logic_vector(rec.id);
      return ret_vec;
    end pack;
    function pack (rec : device_id_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : device_id_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(7 downto 0);
    begin
        ret_vec(7 downto 0) := std_logic_vector(rec.id);
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return device_id_type is
        variable ret_rec : device_id_type;
    begin
        ret_rec.id := vec(7 downto 0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : device_id_type) return integer is
    begin
        return 8;
    end sizeof;
    function rec_reset return device_id_type is
        variable ret_rec : device_id_type;
    begin
        ret_rec.id := 8x"1";
        return ret_rec;
    end rec_reset;
    function "or" (left, right : device_id_type) return device_id_type is
      variable ret_rec : device_id_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : device_id_type; right : std_logic_vector) return device_id_type is
      variable ret_rec : device_id_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : device_id_type; right : unsigned) return device_id_type is
      variable ret_rec : device_id_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : device_id_type) return device_id_type is
      variable ret_rec : device_id_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : device_id_type; right : std_logic_vector) return device_id_type is
      variable ret_rec : device_id_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : device_id_type; right : unsigned) return device_id_type is
      variable ret_rec : device_id_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : device_id_type) return device_id_type is
      variable ret_rec : device_id_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : device_id_type; right : std_logic_vector) return device_id_type is
      variable ret_rec : device_id_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : device_id_type; right : unsigned) return device_id_type is
      variable ret_rec : device_id_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : device_id_type) return device_id_type is
      variable ret_rec : device_id_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

  ---------------------------------------
  -- general_capabilities_type subprogram bodies
  ---------------------------------------
  -- enum general_capabilities_io_mode_sel encode from bits
  function encode(slv : std_logic_vector(1 downto 0)) return general_capabilities_io_mode_sel is
      variable ret_enum : general_capabilities_io_mode_sel;
    begin
      case slv is
        when 2x"0" => ret_enum := Single;
        when 2x"1" => ret_enum := Dual;
        when 2x"2" => ret_enum := Quad;
        when 2x"3" => ret_enum := Reserved;
        when others => null;
      end case;
      return ret_enum;
  end encode;
  -- enum general_capabilities_io_mode_sel decode to bits
  function decode(enum: general_capabilities_io_mode_sel) return std_logic_vector is
      variable ret_vec: std_logic_vector(1 downto 0) := (others => '0');
    begin
      case enum is
        when Single => ret_vec := 2x"0";
        when Dual => ret_vec := 2x"1";
        when Quad => ret_vec := 2x"2";
        when Reserved => ret_vec := 2x"3";
      end case;
      return ret_vec;
  end decode;
  function encode(slv : std_logic_vector(1 downto 0)) return general_capabilities_io_mode_support is
      variable ret_enum : general_capabilities_io_mode_support;
    begin
      case slv is
        when 2x"0" => ret_enum := Single;
        when 2x"1" => ret_enum := Dual;
        when 2x"2" => ret_enum := Quad;
        when 2x"3" => ret_enum := Any;
        when others => null;
      end case;
      return ret_enum;
  end encode;
  -- enum general_capabilities_io_mode_support decode to bits
  function decode(enum: general_capabilities_io_mode_support) return std_logic_vector is
      variable ret_vec: std_logic_vector(1 downto 0) := (others => '0');
    begin
      case enum is
        when Single => ret_vec := 2x"0";
        when Dual => ret_vec := 2x"1";
        when Quad => ret_vec := 2x"2";
        when Any => ret_vec := 2x"3";
      end case;
      return ret_vec;
  end decode;
  function encode(slv : std_logic_vector(2 downto 0)) return general_capabilities_op_freq_select is
      variable ret_enum : general_capabilities_op_freq_select;
    begin
      case slv is
        when 3x"0" => ret_enum := Twenty;
        when 3x"1" => ret_enum := TwentyFive;
        when 3x"2" => ret_enum := ThirtyThree;
        when 3x"3" => ret_enum := Fifty;
        when 3x"4" => ret_enum := SixtySix;
        when 3x"5" => ret_enum := RSVD0;
        when 3x"6" => ret_enum := RSVD1;
        when 3x"7" => ret_enum := RSVD2;
        when others => null;
      end case;
      return ret_enum;
  end encode;
  -- enum general_capabilities_op_freq_select decode to bits
  function decode(enum: general_capabilities_op_freq_select) return std_logic_vector is
      variable ret_vec: std_logic_vector(2 downto 0) := (others => '0');
    begin
      case enum is
        when Twenty => ret_vec := 3x"0";
        when TwentyFive => ret_vec := 3x"1";
        when ThirtyThree => ret_vec := 3x"2";
        when Fifty => ret_vec := 3x"3";
        when SixtySix => ret_vec := 3x"4";
        when RSVD0 => ret_vec := 3x"5";
        when RSVD1 => ret_vec := 3x"6";
        when RSVD2 => ret_vec := 3x"7";
      end case;
      return ret_vec;
  end decode;
  function encode(slv : std_logic_vector(2 downto 0)) return general_capabilities_op_freq_support is
      variable ret_enum : general_capabilities_op_freq_support;
    begin
      case slv is
        when 3x"0" => ret_enum := Twenty;
        when 3x"1" => ret_enum := TwentyFive;
        when 3x"2" => ret_enum := ThirtyThree;
        when 3x"3" => ret_enum := Fifty;
        when 3x"4" => ret_enum := SixtySix;
        when 3x"5" => ret_enum := RSVD0;
        when 3x"6" => ret_enum := RSVD1;
        when 3x"7" => ret_enum := RSVD2;
        when others => null;
      end case;
      return ret_enum;
  end encode;
  -- enum general_capabilities_op_freq_support decode to bits
  function decode(enum: general_capabilities_op_freq_support) return std_logic_vector is
      variable ret_vec: std_logic_vector(2 downto 0) := (others => '0');
    begin
      case enum is
        when Twenty => ret_vec := 3x"0";
        when TwentyFive => ret_vec := 3x"1";
        when ThirtyThree => ret_vec := 3x"2";
        when Fifty => ret_vec := 3x"3";
        when SixtySix => ret_vec := 3x"4";
        when RSVD0 => ret_vec := 3x"5";
        when RSVD1 => ret_vec := 3x"6";
        when RSVD2 => ret_vec := 3x"7";
      end case;
      return ret_vec;
  end decode;
  function unpack (slv : std_logic_vector(31 downto 0)) return general_capabilities_type is
      variable ret_rec : general_capabilities_type;
    begin
        ret_rec.crc_en:= slv(31);
        ret_rec.resp_mod_en:= slv(30);
        ret_rec.alert_mode:= slv(28);
        ret_rec.io_mode_sel:= encode(slv(27 downto 26));
        ret_rec.io_mode_support:= encode(slv(25 downto 24));
        ret_rec.alert_select:= slv(23);
        ret_rec.op_freq_select:= encode(slv(22 downto 20));
        ret_rec.alert_support:= slv(19);
        ret_rec.op_freq_support:= encode(slv(18 downto 16));
        ret_rec.max_wait:= slv(15 downto 12);
        ret_rec.flash_support:= slv(3);
        ret_rec.oob_support:= slv(2);
        ret_rec.virt_wire_support:= slv(1);
        ret_rec.periph_support:= slv(0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return general_capabilities_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : general_capabilities_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(31) := rec.crc_en;
            ret_vec(30) := rec.resp_mod_en;
            ret_vec(28) := rec.alert_mode;
          ret_vec(27 downto 26) := decode(rec.io_mode_sel);
          ret_vec(25 downto 24) := decode(rec.io_mode_support);
            ret_vec(23) := rec.alert_select;
          ret_vec(22 downto 20) := decode(rec.op_freq_select);
            ret_vec(19) := rec.alert_support;
          ret_vec(18 downto 16) := decode(rec.op_freq_support);
            ret_vec(15 downto 12) := std_logic_vector(rec.max_wait);
            ret_vec(3) := rec.flash_support;
            ret_vec(2) := rec.oob_support;
            ret_vec(1) := rec.virt_wire_support;
            ret_vec(0) := rec.periph_support;
      return ret_vec;
    end pack;
    function pack (rec : general_capabilities_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : general_capabilities_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(22 downto 0);
    begin
        ret_vec(22) := rec.crc_en;
        ret_vec(21) := rec.resp_mod_en;
        ret_vec(20) := rec.alert_mode;
        ret_vec(19 downto 18) := decode(rec.io_mode_sel);
        ret_vec(17 downto 16) := decode(rec.io_mode_support);
        ret_vec(15) := rec.alert_select;
        ret_vec(14 downto 12) := decode(rec.op_freq_select);
        ret_vec(11) := rec.alert_support;
        ret_vec(10 downto 8) := decode(rec.op_freq_support);
        ret_vec(7 downto 4) := std_logic_vector(rec.max_wait);
        ret_vec(3) := rec.flash_support;
        ret_vec(2) := rec.oob_support;
        ret_vec(1) := rec.virt_wire_support;
        ret_vec(0) := rec.periph_support;
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return general_capabilities_type is
        variable ret_rec : general_capabilities_type;
    begin
        ret_rec.crc_en := vec(22);
        ret_rec.resp_mod_en := vec(21);
        ret_rec.alert_mode := vec(20);
        ret_rec.io_mode_sel := encode(vec(19 downto 18));
        ret_rec.io_mode_support := encode(vec(17 downto 16));
        ret_rec.alert_select := vec(15);
        ret_rec.op_freq_select := encode(vec(14 downto 12));
        ret_rec.alert_support := vec(11);
        ret_rec.op_freq_support := encode(vec(10 downto 8));
        ret_rec.max_wait := vec(7 downto 4);
        ret_rec.flash_support := vec(3);
        ret_rec.oob_support := vec(2);
        ret_rec.virt_wire_support := vec(1);
        ret_rec.periph_support := vec(0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : general_capabilities_type) return integer is
    begin
        return 23;
    end sizeof;
    function rec_reset return general_capabilities_type is
        variable ret_rec : general_capabilities_type;
    begin
        ret_rec.crc_en := '0';
        ret_rec.resp_mod_en := '0';
        ret_rec.alert_mode := '0';
        ret_rec.io_mode_sel := encode(2x"0");
        ret_rec.io_mode_support := encode(2x"3");
        ret_rec.alert_select := '0';
        ret_rec.op_freq_select := encode(3x"0");
        ret_rec.alert_support := '0';
        ret_rec.op_freq_support := encode(3x"4");
        ret_rec.max_wait := 4x"0";
        ret_rec.flash_support := '0';
        ret_rec.oob_support := '1';
        ret_rec.virt_wire_support := '0';
        ret_rec.periph_support := '0';
        return ret_rec;
    end rec_reset;
    function "or" (left, right : general_capabilities_type) return general_capabilities_type is
      variable ret_rec : general_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : general_capabilities_type; right : std_logic_vector) return general_capabilities_type is
      variable ret_rec : general_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : general_capabilities_type; right : unsigned) return general_capabilities_type is
      variable ret_rec : general_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : general_capabilities_type) return general_capabilities_type is
      variable ret_rec : general_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : general_capabilities_type; right : std_logic_vector) return general_capabilities_type is
      variable ret_rec : general_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : general_capabilities_type; right : unsigned) return general_capabilities_type is
      variable ret_rec : general_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : general_capabilities_type) return general_capabilities_type is
      variable ret_rec : general_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : general_capabilities_type; right : std_logic_vector) return general_capabilities_type is
      variable ret_rec : general_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : general_capabilities_type; right : unsigned) return general_capabilities_type is
      variable ret_rec : general_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : general_capabilities_type) return general_capabilities_type is
      variable ret_rec : general_capabilities_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

  ---------------------------------------
  -- ch0_capabilities_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return ch0_capabilities_type is
      variable ret_rec : ch0_capabilities_type;
    begin
        ret_rec.max_read_request_size:= slv(14 downto 12);
        ret_rec.max_payload_size:= slv(10 downto 8);
        ret_rec.max_payload_support:= slv(6 downto 4);
        ret_rec.bus_master_en:= slv(2);
        ret_rec.chan_rdy:= slv(1);
        ret_rec.chan_en:= slv(0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return ch0_capabilities_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : ch0_capabilities_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(14 downto 12) := std_logic_vector(rec.max_read_request_size);
            ret_vec(10 downto 8) := std_logic_vector(rec.max_payload_size);
            ret_vec(6 downto 4) := std_logic_vector(rec.max_payload_support);
            ret_vec(2) := rec.bus_master_en;
            ret_vec(1) := rec.chan_rdy;
            ret_vec(0) := rec.chan_en;
      return ret_vec;
    end pack;
    function pack (rec : ch0_capabilities_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : ch0_capabilities_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(11 downto 0);
    begin
        ret_vec(11 downto 9) := std_logic_vector(rec.max_read_request_size);
        ret_vec(8 downto 6) := std_logic_vector(rec.max_payload_size);
        ret_vec(5 downto 3) := std_logic_vector(rec.max_payload_support);
        ret_vec(2) := rec.bus_master_en;
        ret_vec(1) := rec.chan_rdy;
        ret_vec(0) := rec.chan_en;
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return ch0_capabilities_type is
        variable ret_rec : ch0_capabilities_type;
    begin
        ret_rec.max_read_request_size := vec(11 downto 9);
        ret_rec.max_payload_size := vec(8 downto 6);
        ret_rec.max_payload_support := vec(5 downto 3);
        ret_rec.bus_master_en := vec(2);
        ret_rec.chan_rdy := vec(1);
        ret_rec.chan_en := vec(0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : ch0_capabilities_type) return integer is
    begin
        return 12;
    end sizeof;
    function rec_reset return ch0_capabilities_type is
        variable ret_rec : ch0_capabilities_type;
    begin
        ret_rec.max_read_request_size := 3x"1";
        ret_rec.max_payload_size := 3x"1";
        ret_rec.max_payload_support := 3x"3";
        ret_rec.bus_master_en := '0';
        ret_rec.chan_rdy := '0';
        ret_rec.chan_en := '1';
        return ret_rec;
    end rec_reset;
    function "or" (left, right : ch0_capabilities_type) return ch0_capabilities_type is
      variable ret_rec : ch0_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : ch0_capabilities_type; right : std_logic_vector) return ch0_capabilities_type is
      variable ret_rec : ch0_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : ch0_capabilities_type; right : unsigned) return ch0_capabilities_type is
      variable ret_rec : ch0_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : ch0_capabilities_type) return ch0_capabilities_type is
      variable ret_rec : ch0_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : ch0_capabilities_type; right : std_logic_vector) return ch0_capabilities_type is
      variable ret_rec : ch0_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : ch0_capabilities_type; right : unsigned) return ch0_capabilities_type is
      variable ret_rec : ch0_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : ch0_capabilities_type) return ch0_capabilities_type is
      variable ret_rec : ch0_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : ch0_capabilities_type; right : std_logic_vector) return ch0_capabilities_type is
      variable ret_rec : ch0_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : ch0_capabilities_type; right : unsigned) return ch0_capabilities_type is
      variable ret_rec : ch0_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : ch0_capabilities_type) return ch0_capabilities_type is
      variable ret_rec : ch0_capabilities_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

  ---------------------------------------
  -- ch2_capabilities_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return ch2_capabilities_type is
      variable ret_rec : ch2_capabilities_type;
    begin
        ret_rec.max_payload_select:= slv(10 downto 8);
        ret_rec.max_payload_support:= slv(6 downto 4);
        ret_rec.oob_ready:= slv(1);
        ret_rec.oob_en:= slv(0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return ch2_capabilities_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : ch2_capabilities_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(10 downto 8) := std_logic_vector(rec.max_payload_select);
            ret_vec(6 downto 4) := std_logic_vector(rec.max_payload_support);
            ret_vec(1) := rec.oob_ready;
            ret_vec(0) := rec.oob_en;
      return ret_vec;
    end pack;
    function pack (rec : ch2_capabilities_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : ch2_capabilities_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(7 downto 0);
    begin
        ret_vec(7 downto 5) := std_logic_vector(rec.max_payload_select);
        ret_vec(4 downto 2) := std_logic_vector(rec.max_payload_support);
        ret_vec(1) := rec.oob_ready;
        ret_vec(0) := rec.oob_en;
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return ch2_capabilities_type is
        variable ret_rec : ch2_capabilities_type;
    begin
        ret_rec.max_payload_select := vec(7 downto 5);
        ret_rec.max_payload_support := vec(4 downto 2);
        ret_rec.oob_ready := vec(1);
        ret_rec.oob_en := vec(0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : ch2_capabilities_type) return integer is
    begin
        return 8;
    end sizeof;
    function rec_reset return ch2_capabilities_type is
        variable ret_rec : ch2_capabilities_type;
    begin
        ret_rec.max_payload_select := 3x"1";
        ret_rec.max_payload_support := 3x"3";
        ret_rec.oob_ready := '0';
        ret_rec.oob_en := '0';
        return ret_rec;
    end rec_reset;
    function "or" (left, right : ch2_capabilities_type) return ch2_capabilities_type is
      variable ret_rec : ch2_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : ch2_capabilities_type; right : std_logic_vector) return ch2_capabilities_type is
      variable ret_rec : ch2_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : ch2_capabilities_type; right : unsigned) return ch2_capabilities_type is
      variable ret_rec : ch2_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : ch2_capabilities_type) return ch2_capabilities_type is
      variable ret_rec : ch2_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : ch2_capabilities_type; right : std_logic_vector) return ch2_capabilities_type is
      variable ret_rec : ch2_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : ch2_capabilities_type; right : unsigned) return ch2_capabilities_type is
      variable ret_rec : ch2_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : ch2_capabilities_type) return ch2_capabilities_type is
      variable ret_rec : ch2_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : ch2_capabilities_type; right : std_logic_vector) return ch2_capabilities_type is
      variable ret_rec : ch2_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : ch2_capabilities_type; right : unsigned) return ch2_capabilities_type is
      variable ret_rec : ch2_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : ch2_capabilities_type) return ch2_capabilities_type is
      variable ret_rec : ch2_capabilities_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

  ---------------------------------------
  -- ch3_capabilities_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return ch3_capabilities_type is
      variable ret_rec : ch3_capabilities_type;
    begin
        ret_rec.flash_cap:= slv(17 downto 16);
        ret_rec.max_rd_req:= slv(14 downto 12);
        ret_rec.flash_share_mode:= slv(11);
        ret_rec.flash_max_payload_selected:= slv(10 downto 8);
        ret_rec.flash_max_payload_supported:= slv(7 downto 5);
        ret_rec.flash_block_erase_size:= slv(4 downto 2);
        ret_rec.flash_channel_ready:= slv(1);
        ret_rec.flash_channel_enable:= slv(0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return ch3_capabilities_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : ch3_capabilities_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(17 downto 16) := std_logic_vector(rec.flash_cap);
            ret_vec(14 downto 12) := std_logic_vector(rec.max_rd_req);
            ret_vec(11) := rec.flash_share_mode;
            ret_vec(10 downto 8) := std_logic_vector(rec.flash_max_payload_selected);
            ret_vec(7 downto 5) := std_logic_vector(rec.flash_max_payload_supported);
            ret_vec(4 downto 2) := std_logic_vector(rec.flash_block_erase_size);
            ret_vec(1) := rec.flash_channel_ready;
            ret_vec(0) := rec.flash_channel_enable;
      return ret_vec;
    end pack;
    function pack (rec : ch3_capabilities_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : ch3_capabilities_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(16 downto 0);
    begin
        ret_vec(16 downto 15) := std_logic_vector(rec.flash_cap);
        ret_vec(14 downto 12) := std_logic_vector(rec.max_rd_req);
        ret_vec(11) := rec.flash_share_mode;
        ret_vec(10 downto 8) := std_logic_vector(rec.flash_max_payload_selected);
        ret_vec(7 downto 5) := std_logic_vector(rec.flash_max_payload_supported);
        ret_vec(4 downto 2) := std_logic_vector(rec.flash_block_erase_size);
        ret_vec(1) := rec.flash_channel_ready;
        ret_vec(0) := rec.flash_channel_enable;
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return ch3_capabilities_type is
        variable ret_rec : ch3_capabilities_type;
    begin
        ret_rec.flash_cap := vec(16 downto 15);
        ret_rec.max_rd_req := vec(14 downto 12);
        ret_rec.flash_share_mode := vec(11);
        ret_rec.flash_max_payload_selected := vec(10 downto 8);
        ret_rec.flash_max_payload_supported := vec(7 downto 5);
        ret_rec.flash_block_erase_size := vec(4 downto 2);
        ret_rec.flash_channel_ready := vec(1);
        ret_rec.flash_channel_enable := vec(0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : ch3_capabilities_type) return integer is
    begin
        return 17;
    end sizeof;
    function rec_reset return ch3_capabilities_type is
        variable ret_rec : ch3_capabilities_type;
    begin
        ret_rec.flash_cap := 2x"2";
        ret_rec.max_rd_req := 3x"1";
        ret_rec.flash_share_mode := '1';
        ret_rec.flash_max_payload_selected := 3x"1";
        ret_rec.flash_max_payload_supported := 3x"3";
        ret_rec.flash_block_erase_size := 3x"1";
        ret_rec.flash_channel_ready := '0';
        ret_rec.flash_channel_enable := '0';
        return ret_rec;
    end rec_reset;
    function "or" (left, right : ch3_capabilities_type) return ch3_capabilities_type is
      variable ret_rec : ch3_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : ch3_capabilities_type; right : std_logic_vector) return ch3_capabilities_type is
      variable ret_rec : ch3_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : ch3_capabilities_type; right : unsigned) return ch3_capabilities_type is
      variable ret_rec : ch3_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : ch3_capabilities_type) return ch3_capabilities_type is
      variable ret_rec : ch3_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : ch3_capabilities_type; right : std_logic_vector) return ch3_capabilities_type is
      variable ret_rec : ch3_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : ch3_capabilities_type; right : unsigned) return ch3_capabilities_type is
      variable ret_rec : ch3_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : ch3_capabilities_type) return ch3_capabilities_type is
      variable ret_rec : ch3_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : ch3_capabilities_type; right : std_logic_vector) return ch3_capabilities_type is
      variable ret_rec : ch3_capabilities_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : ch3_capabilities_type; right : unsigned) return ch3_capabilities_type is
      variable ret_rec : ch3_capabilities_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : ch3_capabilities_type) return ch3_capabilities_type is
      variable ret_rec : ch3_capabilities_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

  ---------------------------------------
  -- ch3_capabilities2_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return ch3_capabilities2_type is
      variable ret_rec : ch3_capabilities2_type;
    begin
        ret_rec.rpmc_sup:= slv(21 downto 16);
        ret_rec.ebs_sup:= slv(15 downto 8);
        ret_rec.tgt_rd_size_support:= slv(2 downto 0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return ch3_capabilities2_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : ch3_capabilities2_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(21 downto 16) := std_logic_vector(rec.rpmc_sup);
            ret_vec(15 downto 8) := std_logic_vector(rec.ebs_sup);
            ret_vec(2 downto 0) := std_logic_vector(rec.tgt_rd_size_support);
      return ret_vec;
    end pack;
    function pack (rec : ch3_capabilities2_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : ch3_capabilities2_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(16 downto 0);
    begin
        ret_vec(16 downto 11) := std_logic_vector(rec.rpmc_sup);
        ret_vec(10 downto 3) := std_logic_vector(rec.ebs_sup);
        ret_vec(2 downto 0) := std_logic_vector(rec.tgt_rd_size_support);
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return ch3_capabilities2_type is
        variable ret_rec : ch3_capabilities2_type;
    begin
        ret_rec.rpmc_sup := vec(16 downto 11);
        ret_rec.ebs_sup := vec(10 downto 3);
        ret_rec.tgt_rd_size_support := vec(2 downto 0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : ch3_capabilities2_type) return integer is
    begin
        return 17;
    end sizeof;
    function rec_reset return ch3_capabilities2_type is
        variable ret_rec : ch3_capabilities2_type;
    begin
        ret_rec.rpmc_sup := 6x"0";
        ret_rec.ebs_sup := 8x"0";
        ret_rec.tgt_rd_size_support := 3x"3";
        return ret_rec;
    end rec_reset;
    function "or" (left, right : ch3_capabilities2_type) return ch3_capabilities2_type is
      variable ret_rec : ch3_capabilities2_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : ch3_capabilities2_type; right : std_logic_vector) return ch3_capabilities2_type is
      variable ret_rec : ch3_capabilities2_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : ch3_capabilities2_type; right : unsigned) return ch3_capabilities2_type is
      variable ret_rec : ch3_capabilities2_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : ch3_capabilities2_type) return ch3_capabilities2_type is
      variable ret_rec : ch3_capabilities2_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : ch3_capabilities2_type; right : std_logic_vector) return ch3_capabilities2_type is
      variable ret_rec : ch3_capabilities2_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : ch3_capabilities2_type; right : unsigned) return ch3_capabilities2_type is
      variable ret_rec : ch3_capabilities2_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : ch3_capabilities2_type) return ch3_capabilities2_type is
      variable ret_rec : ch3_capabilities2_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : ch3_capabilities2_type; right : std_logic_vector) return ch3_capabilities2_type is
      variable ret_rec : ch3_capabilities2_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : ch3_capabilities2_type; right : unsigned) return ch3_capabilities2_type is
      variable ret_rec : ch3_capabilities2_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : ch3_capabilities2_type) return ch3_capabilities2_type is
      variable ret_rec : ch3_capabilities2_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

end espi_spec_regs_pkg;