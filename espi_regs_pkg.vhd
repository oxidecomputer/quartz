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

package espi_regs_pkg is
  -- ------------------------
  -- Addrmap-specific defines
  -- ------------------------
    constant FLAGS_OFFSET : integer := 0;
    constant CONTROL_OFFSET : integer := 4;
    constant STATUS_OFFSET : integer := 8;
    constant FIFO_STATUS_OFFSET : integer := 12;
    constant CMD_FIFO_WDATA_OFFSET : integer := 16;
    constant RESP_FIFO_RDATA_OFFSET : integer := 20;
    constant CMD_SIZE_FIFO_WDATA_OFFSET : integer := 24;

  -- ---------------
  -- Register types
  -- ---------------
  -- ---------------
  -- Register flags definitions
  -- ---------------
  
  type flags_type is record
      alert    : std_logic;
  end record;
  -- register constants
  -- field mask definitions
  constant FLAGS_ALERT_MASK : std_logic_vector(31 downto 0) := 32x"1";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return flags_type;
  function unpack(un : unsigned(31 downto 0)) return flags_type;
  function pack(rec : flags_type) return std_logic_vector;
  function pack(rec : flags_type) return unsigned;
  function compress (rec : flags_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return flags_type;
  function sizeof (rec : flags_type) return integer;
  function rec_reset return flags_type;
  function "or"  (left, right : flags_type) return flags_type;
  function "or"  (left : flags_type; right : std_logic_vector) return flags_type;
  function "or"  (left : flags_type; right : unsigned) return flags_type;
  function "and" (left, right : flags_type) return flags_type;
  function "and" (left : flags_type; right : std_logic_vector) return flags_type;
  function "and" (left : flags_type; right : unsigned) return flags_type;
  function "xor" (left, right : flags_type) return flags_type;
  function "xor" (left : flags_type; right : std_logic_vector) return flags_type;
  function "xor" (left : flags_type; right : unsigned) return flags_type;
  function "not" (right : flags_type) return flags_type;
  -- ---------------
  -- Register control definitions
  -- ---------------
  
  type control_type is record
      cmd_fifo_reset    : std_logic;
      cmd_size_fifo_reset    : std_logic;
      resp_fifo_reset    : std_logic;
      dbg_mode_en    : std_logic;
  end record;
  -- register constants
  -- field mask definitions
  constant CONTROL_CMD_FIFO_RESET_MASK : std_logic_vector(31 downto 0) := 32x"8";
  constant CONTROL_CMD_SIZE_FIFO_RESET_MASK : std_logic_vector(31 downto 0) := 32x"4";
  constant CONTROL_RESP_FIFO_RESET_MASK : std_logic_vector(31 downto 0) := 32x"2";
  constant CONTROL_DBG_MODE_EN_MASK : std_logic_vector(31 downto 0) := 32x"1";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return control_type;
  function unpack(un : unsigned(31 downto 0)) return control_type;
  function pack(rec : control_type) return std_logic_vector;
  function pack(rec : control_type) return unsigned;
  function compress (rec : control_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return control_type;
  function sizeof (rec : control_type) return integer;
  function rec_reset return control_type;
  function "or"  (left, right : control_type) return control_type;
  function "or"  (left : control_type; right : std_logic_vector) return control_type;
  function "or"  (left : control_type; right : unsigned) return control_type;
  function "and" (left, right : control_type) return control_type;
  function "and" (left : control_type; right : std_logic_vector) return control_type;
  function "and" (left : control_type; right : unsigned) return control_type;
  function "xor" (left, right : control_type) return control_type;
  function "xor" (left : control_type; right : std_logic_vector) return control_type;
  function "xor" (left : control_type; right : unsigned) return control_type;
  function "not" (right : control_type) return control_type;
  -- ---------------
  -- Register status definitions
  -- ---------------
  
  type status_type is record
      busy    : std_logic;
  end record;
  -- register constants
  -- field mask definitions
  constant STATUS_BUSY_MASK : std_logic_vector(31 downto 0) := 32x"1";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return status_type;
  function unpack(un : unsigned(31 downto 0)) return status_type;
  function pack(rec : status_type) return std_logic_vector;
  function pack(rec : status_type) return unsigned;
  function compress (rec : status_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return status_type;
  function sizeof (rec : status_type) return integer;
  function rec_reset return status_type;
  function "or"  (left, right : status_type) return status_type;
  function "or"  (left : status_type; right : std_logic_vector) return status_type;
  function "or"  (left : status_type; right : unsigned) return status_type;
  function "and" (left, right : status_type) return status_type;
  function "and" (left : status_type; right : std_logic_vector) return status_type;
  function "and" (left : status_type; right : unsigned) return status_type;
  function "xor" (left, right : status_type) return status_type;
  function "xor" (left : status_type; right : std_logic_vector) return status_type;
  function "xor" (left : status_type; right : unsigned) return status_type;
  function "not" (right : status_type) return status_type;
  -- ---------------
  -- Register fifo_status definitions
  -- ---------------
  
  type fifo_status_type is record
      cmd_used_wds : std_logic_vector(15 downto 0);
      resp_used_wds : std_logic_vector(15 downto 0);
  end record;
  -- register constants
  -- field mask definitions
  constant FIFO_STATUS_CMD_USED_WDS_MASK : std_logic_vector(31 downto 0) := 32x"ffff0000";
  constant FIFO_STATUS_RESP_USED_WDS_MASK : std_logic_vector(31 downto 0) := 32x"ffff";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return fifo_status_type;
  function unpack(un : unsigned(31 downto 0)) return fifo_status_type;
  function pack(rec : fifo_status_type) return std_logic_vector;
  function pack(rec : fifo_status_type) return unsigned;
  function compress (rec : fifo_status_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return fifo_status_type;
  function sizeof (rec : fifo_status_type) return integer;
  function rec_reset return fifo_status_type;
  function "or"  (left, right : fifo_status_type) return fifo_status_type;
  function "or"  (left : fifo_status_type; right : std_logic_vector) return fifo_status_type;
  function "or"  (left : fifo_status_type; right : unsigned) return fifo_status_type;
  function "and" (left, right : fifo_status_type) return fifo_status_type;
  function "and" (left : fifo_status_type; right : std_logic_vector) return fifo_status_type;
  function "and" (left : fifo_status_type; right : unsigned) return fifo_status_type;
  function "xor" (left, right : fifo_status_type) return fifo_status_type;
  function "xor" (left : fifo_status_type; right : std_logic_vector) return fifo_status_type;
  function "xor" (left : fifo_status_type; right : unsigned) return fifo_status_type;
  function "not" (right : fifo_status_type) return fifo_status_type;
  -- ---------------
  -- Register cmd_fifo_wdata definitions
  -- ---------------
  
  type cmd_fifo_wdata_type is record
      fifo_data : std_logic_vector(31 downto 0);
  end record;
  -- register constants
  -- field mask definitions
  constant CMD_FIFO_WDATA_FIFO_DATA_MASK : std_logic_vector(31 downto 0) := 32x"ffffffff";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return cmd_fifo_wdata_type;
  function unpack(un : unsigned(31 downto 0)) return cmd_fifo_wdata_type;
  function pack(rec : cmd_fifo_wdata_type) return std_logic_vector;
  function pack(rec : cmd_fifo_wdata_type) return unsigned;
  function compress (rec : cmd_fifo_wdata_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return cmd_fifo_wdata_type;
  function sizeof (rec : cmd_fifo_wdata_type) return integer;
  function rec_reset return cmd_fifo_wdata_type;
  function "or"  (left, right : cmd_fifo_wdata_type) return cmd_fifo_wdata_type;
  function "or"  (left : cmd_fifo_wdata_type; right : std_logic_vector) return cmd_fifo_wdata_type;
  function "or"  (left : cmd_fifo_wdata_type; right : unsigned) return cmd_fifo_wdata_type;
  function "and" (left, right : cmd_fifo_wdata_type) return cmd_fifo_wdata_type;
  function "and" (left : cmd_fifo_wdata_type; right : std_logic_vector) return cmd_fifo_wdata_type;
  function "and" (left : cmd_fifo_wdata_type; right : unsigned) return cmd_fifo_wdata_type;
  function "xor" (left, right : cmd_fifo_wdata_type) return cmd_fifo_wdata_type;
  function "xor" (left : cmd_fifo_wdata_type; right : std_logic_vector) return cmd_fifo_wdata_type;
  function "xor" (left : cmd_fifo_wdata_type; right : unsigned) return cmd_fifo_wdata_type;
  function "not" (right : cmd_fifo_wdata_type) return cmd_fifo_wdata_type;
  -- ---------------
  -- Register resp_fifo_rdata definitions
  -- ---------------
  
  type resp_fifo_rdata_type is record
      fifo_data : std_logic_vector(31 downto 0);
  end record;
  -- register constants
  -- field mask definitions
  constant RESP_FIFO_RDATA_FIFO_DATA_MASK : std_logic_vector(31 downto 0) := 32x"ffffffff";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return resp_fifo_rdata_type;
  function unpack(un : unsigned(31 downto 0)) return resp_fifo_rdata_type;
  function pack(rec : resp_fifo_rdata_type) return std_logic_vector;
  function pack(rec : resp_fifo_rdata_type) return unsigned;
  function compress (rec : resp_fifo_rdata_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return resp_fifo_rdata_type;
  function sizeof (rec : resp_fifo_rdata_type) return integer;
  function rec_reset return resp_fifo_rdata_type;
  function "or"  (left, right : resp_fifo_rdata_type) return resp_fifo_rdata_type;
  function "or"  (left : resp_fifo_rdata_type; right : std_logic_vector) return resp_fifo_rdata_type;
  function "or"  (left : resp_fifo_rdata_type; right : unsigned) return resp_fifo_rdata_type;
  function "and" (left, right : resp_fifo_rdata_type) return resp_fifo_rdata_type;
  function "and" (left : resp_fifo_rdata_type; right : std_logic_vector) return resp_fifo_rdata_type;
  function "and" (left : resp_fifo_rdata_type; right : unsigned) return resp_fifo_rdata_type;
  function "xor" (left, right : resp_fifo_rdata_type) return resp_fifo_rdata_type;
  function "xor" (left : resp_fifo_rdata_type; right : std_logic_vector) return resp_fifo_rdata_type;
  function "xor" (left : resp_fifo_rdata_type; right : unsigned) return resp_fifo_rdata_type;
  function "not" (right : resp_fifo_rdata_type) return resp_fifo_rdata_type;
  -- ---------------
  -- Register cmd_size_fifo_wdata definitions
  -- ---------------
  
  type cmd_size_fifo_wdata_type is record
      fifo_data : std_logic_vector(7 downto 0);
  end record;
  -- register constants
  -- field mask definitions
  constant CMD_SIZE_FIFO_WDATA_FIFO_DATA_MASK : std_logic_vector(31 downto 0) := 32x"ff";
  -- some useful functions that operate on the <type> record
  function unpack(slv : std_logic_vector(31 downto 0)) return cmd_size_fifo_wdata_type;
  function unpack(un : unsigned(31 downto 0)) return cmd_size_fifo_wdata_type;
  function pack(rec : cmd_size_fifo_wdata_type) return std_logic_vector;
  function pack(rec : cmd_size_fifo_wdata_type) return unsigned;
  function compress (rec : cmd_size_fifo_wdata_type) return std_logic_vector;
  function uncompress (vec : std_logic_vector) return cmd_size_fifo_wdata_type;
  function sizeof (rec : cmd_size_fifo_wdata_type) return integer;
  function rec_reset return cmd_size_fifo_wdata_type;
  function "or"  (left, right : cmd_size_fifo_wdata_type) return cmd_size_fifo_wdata_type;
  function "or"  (left : cmd_size_fifo_wdata_type; right : std_logic_vector) return cmd_size_fifo_wdata_type;
  function "or"  (left : cmd_size_fifo_wdata_type; right : unsigned) return cmd_size_fifo_wdata_type;
  function "and" (left, right : cmd_size_fifo_wdata_type) return cmd_size_fifo_wdata_type;
  function "and" (left : cmd_size_fifo_wdata_type; right : std_logic_vector) return cmd_size_fifo_wdata_type;
  function "and" (left : cmd_size_fifo_wdata_type; right : unsigned) return cmd_size_fifo_wdata_type;
  function "xor" (left, right : cmd_size_fifo_wdata_type) return cmd_size_fifo_wdata_type;
  function "xor" (left : cmd_size_fifo_wdata_type; right : std_logic_vector) return cmd_size_fifo_wdata_type;
  function "xor" (left : cmd_size_fifo_wdata_type; right : unsigned) return cmd_size_fifo_wdata_type;
  function "not" (right : cmd_size_fifo_wdata_type) return cmd_size_fifo_wdata_type;
end espi_regs_pkg;

package body espi_regs_pkg is
  ---------------------------------------
  -- flags_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return flags_type is
      variable ret_rec : flags_type;
    begin
        ret_rec.alert:= slv(0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return flags_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : flags_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(0) := rec.alert;
      return ret_vec;
    end pack;
    function pack (rec : flags_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : flags_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(0 downto 0);
    begin
        ret_vec(0) := rec.alert;
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return flags_type is
        variable ret_rec : flags_type;
    begin
        ret_rec.alert := vec(0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : flags_type) return integer is
    begin
        return 1;
    end sizeof;
    function rec_reset return flags_type is
        variable ret_rec : flags_type;
    begin
        ret_rec.alert := '0';
        return ret_rec;
    end rec_reset;
    function "or" (left, right : flags_type) return flags_type is
      variable ret_rec : flags_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : flags_type; right : std_logic_vector) return flags_type is
      variable ret_rec : flags_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : flags_type; right : unsigned) return flags_type is
      variable ret_rec : flags_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : flags_type) return flags_type is
      variable ret_rec : flags_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : flags_type; right : std_logic_vector) return flags_type is
      variable ret_rec : flags_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : flags_type; right : unsigned) return flags_type is
      variable ret_rec : flags_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : flags_type) return flags_type is
      variable ret_rec : flags_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : flags_type; right : std_logic_vector) return flags_type is
      variable ret_rec : flags_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : flags_type; right : unsigned) return flags_type is
      variable ret_rec : flags_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : flags_type) return flags_type is
      variable ret_rec : flags_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

  ---------------------------------------
  -- control_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return control_type is
      variable ret_rec : control_type;
    begin
        ret_rec.cmd_fifo_reset:= slv(3);
        ret_rec.cmd_size_fifo_reset:= slv(2);
        ret_rec.resp_fifo_reset:= slv(1);
        ret_rec.dbg_mode_en:= slv(0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return control_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : control_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(3) := rec.cmd_fifo_reset;
            ret_vec(2) := rec.cmd_size_fifo_reset;
            ret_vec(1) := rec.resp_fifo_reset;
            ret_vec(0) := rec.dbg_mode_en;
      return ret_vec;
    end pack;
    function pack (rec : control_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : control_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(3 downto 0);
    begin
        ret_vec(3) := rec.cmd_fifo_reset;
        ret_vec(2) := rec.cmd_size_fifo_reset;
        ret_vec(1) := rec.resp_fifo_reset;
        ret_vec(0) := rec.dbg_mode_en;
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return control_type is
        variable ret_rec : control_type;
    begin
        ret_rec.cmd_fifo_reset := vec(3);
        ret_rec.cmd_size_fifo_reset := vec(2);
        ret_rec.resp_fifo_reset := vec(1);
        ret_rec.dbg_mode_en := vec(0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : control_type) return integer is
    begin
        return 4;
    end sizeof;
    function rec_reset return control_type is
        variable ret_rec : control_type;
    begin
        ret_rec.cmd_fifo_reset := '0';
        ret_rec.cmd_size_fifo_reset := '0';
        ret_rec.resp_fifo_reset := '0';
        ret_rec.dbg_mode_en := '0';
        return ret_rec;
    end rec_reset;
    function "or" (left, right : control_type) return control_type is
      variable ret_rec : control_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : control_type; right : std_logic_vector) return control_type is
      variable ret_rec : control_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : control_type; right : unsigned) return control_type is
      variable ret_rec : control_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : control_type) return control_type is
      variable ret_rec : control_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : control_type; right : std_logic_vector) return control_type is
      variable ret_rec : control_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : control_type; right : unsigned) return control_type is
      variable ret_rec : control_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : control_type) return control_type is
      variable ret_rec : control_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : control_type; right : std_logic_vector) return control_type is
      variable ret_rec : control_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : control_type; right : unsigned) return control_type is
      variable ret_rec : control_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : control_type) return control_type is
      variable ret_rec : control_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

  ---------------------------------------
  -- status_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return status_type is
      variable ret_rec : status_type;
    begin
        ret_rec.busy:= slv(0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return status_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : status_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(0) := rec.busy;
      return ret_vec;
    end pack;
    function pack (rec : status_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : status_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(0 downto 0);
    begin
        ret_vec(0) := rec.busy;
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return status_type is
        variable ret_rec : status_type;
    begin
        ret_rec.busy := vec(0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : status_type) return integer is
    begin
        return 1;
    end sizeof;
    function rec_reset return status_type is
        variable ret_rec : status_type;
    begin
        ret_rec.busy := '0';
        return ret_rec;
    end rec_reset;
    function "or" (left, right : status_type) return status_type is
      variable ret_rec : status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : status_type; right : std_logic_vector) return status_type is
      variable ret_rec : status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : status_type; right : unsigned) return status_type is
      variable ret_rec : status_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : status_type) return status_type is
      variable ret_rec : status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : status_type; right : std_logic_vector) return status_type is
      variable ret_rec : status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : status_type; right : unsigned) return status_type is
      variable ret_rec : status_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : status_type) return status_type is
      variable ret_rec : status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : status_type; right : std_logic_vector) return status_type is
      variable ret_rec : status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : status_type; right : unsigned) return status_type is
      variable ret_rec : status_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : status_type) return status_type is
      variable ret_rec : status_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

  ---------------------------------------
  -- fifo_status_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return fifo_status_type is
      variable ret_rec : fifo_status_type;
    begin
        ret_rec.cmd_used_wds:= slv(31 downto 16);
        ret_rec.resp_used_wds:= slv(15 downto 0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return fifo_status_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : fifo_status_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(31 downto 16) := std_logic_vector(rec.cmd_used_wds);
            ret_vec(15 downto 0) := std_logic_vector(rec.resp_used_wds);
      return ret_vec;
    end pack;
    function pack (rec : fifo_status_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : fifo_status_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(31 downto 0);
    begin
        ret_vec(31 downto 16) := std_logic_vector(rec.cmd_used_wds);
        ret_vec(15 downto 0) := std_logic_vector(rec.resp_used_wds);
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return fifo_status_type is
        variable ret_rec : fifo_status_type;
    begin
        ret_rec.cmd_used_wds := vec(31 downto 16);
        ret_rec.resp_used_wds := vec(15 downto 0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : fifo_status_type) return integer is
    begin
        return 32;
    end sizeof;
    function rec_reset return fifo_status_type is
        variable ret_rec : fifo_status_type;
    begin
        ret_rec.cmd_used_wds := 16x"0";
        ret_rec.resp_used_wds := 16x"0";
        return ret_rec;
    end rec_reset;
    function "or" (left, right : fifo_status_type) return fifo_status_type is
      variable ret_rec : fifo_status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : fifo_status_type; right : std_logic_vector) return fifo_status_type is
      variable ret_rec : fifo_status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : fifo_status_type; right : unsigned) return fifo_status_type is
      variable ret_rec : fifo_status_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : fifo_status_type) return fifo_status_type is
      variable ret_rec : fifo_status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : fifo_status_type; right : std_logic_vector) return fifo_status_type is
      variable ret_rec : fifo_status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : fifo_status_type; right : unsigned) return fifo_status_type is
      variable ret_rec : fifo_status_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : fifo_status_type) return fifo_status_type is
      variable ret_rec : fifo_status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : fifo_status_type; right : std_logic_vector) return fifo_status_type is
      variable ret_rec : fifo_status_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : fifo_status_type; right : unsigned) return fifo_status_type is
      variable ret_rec : fifo_status_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : fifo_status_type) return fifo_status_type is
      variable ret_rec : fifo_status_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

  ---------------------------------------
  -- cmd_fifo_wdata_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return cmd_fifo_wdata_type is
      variable ret_rec : cmd_fifo_wdata_type;
    begin
        ret_rec.fifo_data:= slv(31 downto 0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return cmd_fifo_wdata_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : cmd_fifo_wdata_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(31 downto 0) := std_logic_vector(rec.fifo_data);
      return ret_vec;
    end pack;
    function pack (rec : cmd_fifo_wdata_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : cmd_fifo_wdata_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(31 downto 0);
    begin
        ret_vec(31 downto 0) := std_logic_vector(rec.fifo_data);
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return cmd_fifo_wdata_type is
        variable ret_rec : cmd_fifo_wdata_type;
    begin
        ret_rec.fifo_data := vec(31 downto 0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : cmd_fifo_wdata_type) return integer is
    begin
        return 32;
    end sizeof;
    function rec_reset return cmd_fifo_wdata_type is
        variable ret_rec : cmd_fifo_wdata_type;
    begin
        ret_rec.fifo_data := 32x"0";
        return ret_rec;
    end rec_reset;
    function "or" (left, right : cmd_fifo_wdata_type) return cmd_fifo_wdata_type is
      variable ret_rec : cmd_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : cmd_fifo_wdata_type; right : std_logic_vector) return cmd_fifo_wdata_type is
      variable ret_rec : cmd_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : cmd_fifo_wdata_type; right : unsigned) return cmd_fifo_wdata_type is
      variable ret_rec : cmd_fifo_wdata_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : cmd_fifo_wdata_type) return cmd_fifo_wdata_type is
      variable ret_rec : cmd_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : cmd_fifo_wdata_type; right : std_logic_vector) return cmd_fifo_wdata_type is
      variable ret_rec : cmd_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : cmd_fifo_wdata_type; right : unsigned) return cmd_fifo_wdata_type is
      variable ret_rec : cmd_fifo_wdata_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : cmd_fifo_wdata_type) return cmd_fifo_wdata_type is
      variable ret_rec : cmd_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : cmd_fifo_wdata_type; right : std_logic_vector) return cmd_fifo_wdata_type is
      variable ret_rec : cmd_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : cmd_fifo_wdata_type; right : unsigned) return cmd_fifo_wdata_type is
      variable ret_rec : cmd_fifo_wdata_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : cmd_fifo_wdata_type) return cmd_fifo_wdata_type is
      variable ret_rec : cmd_fifo_wdata_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

  ---------------------------------------
  -- resp_fifo_rdata_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return resp_fifo_rdata_type is
      variable ret_rec : resp_fifo_rdata_type;
    begin
        ret_rec.fifo_data:= slv(31 downto 0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return resp_fifo_rdata_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : resp_fifo_rdata_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(31 downto 0) := std_logic_vector(rec.fifo_data);
      return ret_vec;
    end pack;
    function pack (rec : resp_fifo_rdata_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : resp_fifo_rdata_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(31 downto 0);
    begin
        ret_vec(31 downto 0) := std_logic_vector(rec.fifo_data);
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return resp_fifo_rdata_type is
        variable ret_rec : resp_fifo_rdata_type;
    begin
        ret_rec.fifo_data := vec(31 downto 0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : resp_fifo_rdata_type) return integer is
    begin
        return 32;
    end sizeof;
    function rec_reset return resp_fifo_rdata_type is
        variable ret_rec : resp_fifo_rdata_type;
    begin
        ret_rec.fifo_data := 32x"0";
        return ret_rec;
    end rec_reset;
    function "or" (left, right : resp_fifo_rdata_type) return resp_fifo_rdata_type is
      variable ret_rec : resp_fifo_rdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : resp_fifo_rdata_type; right : std_logic_vector) return resp_fifo_rdata_type is
      variable ret_rec : resp_fifo_rdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : resp_fifo_rdata_type; right : unsigned) return resp_fifo_rdata_type is
      variable ret_rec : resp_fifo_rdata_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : resp_fifo_rdata_type) return resp_fifo_rdata_type is
      variable ret_rec : resp_fifo_rdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : resp_fifo_rdata_type; right : std_logic_vector) return resp_fifo_rdata_type is
      variable ret_rec : resp_fifo_rdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : resp_fifo_rdata_type; right : unsigned) return resp_fifo_rdata_type is
      variable ret_rec : resp_fifo_rdata_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : resp_fifo_rdata_type) return resp_fifo_rdata_type is
      variable ret_rec : resp_fifo_rdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : resp_fifo_rdata_type; right : std_logic_vector) return resp_fifo_rdata_type is
      variable ret_rec : resp_fifo_rdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : resp_fifo_rdata_type; right : unsigned) return resp_fifo_rdata_type is
      variable ret_rec : resp_fifo_rdata_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : resp_fifo_rdata_type) return resp_fifo_rdata_type is
      variable ret_rec : resp_fifo_rdata_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

  ---------------------------------------
  -- cmd_size_fifo_wdata_type subprogram bodies
  ---------------------------------------
  function unpack (slv : std_logic_vector(31 downto 0)) return cmd_size_fifo_wdata_type is
      variable ret_rec : cmd_size_fifo_wdata_type;
    begin
        ret_rec.fifo_data:= slv(7 downto 0);
      return ret_rec;
    end unpack;
  function unpack (un : unsigned(31 downto 0)) return cmd_size_fifo_wdata_type is
    begin
      -- convert to std_logic_vector and use the 1st unpack function
      return unpack(std_logic_vector(un));
    end unpack;
  function pack (rec : cmd_size_fifo_wdata_type) return std_logic_vector is
      variable ret_vec : std_logic_vector(31 downto 0) := (others => '0');
    begin
            ret_vec(7 downto 0) := std_logic_vector(rec.fifo_data);
      return ret_vec;
    end pack;
    function pack (rec : cmd_size_fifo_wdata_type) return unsigned is
    begin
      -- convert to std_logic_vector and use the 1st pack function
      return unsigned(std_logic_vector'(pack(rec)));
    end pack;
    function compress (rec : cmd_size_fifo_wdata_type) return std_logic_vector is
        variable ret_vec : std_logic_vector(7 downto 0);
    begin
        ret_vec(7 downto 0) := std_logic_vector(rec.fifo_data);
        return ret_vec;
    end compress;
    function uncompress (vec : std_logic_vector) return cmd_size_fifo_wdata_type is
        variable ret_rec : cmd_size_fifo_wdata_type;
    begin
        ret_rec.fifo_data := vec(7 downto 0);
        return ret_rec;
    end uncompress;
    function sizeof (rec : cmd_size_fifo_wdata_type) return integer is
    begin
        return 8;
    end sizeof;
    function rec_reset return cmd_size_fifo_wdata_type is
        variable ret_rec : cmd_size_fifo_wdata_type;
    begin
        ret_rec.fifo_data := 8x"0";
        return ret_rec;
    end rec_reset;
    function "or" (left, right : cmd_size_fifo_wdata_type) return cmd_size_fifo_wdata_type is
      variable ret_rec : cmd_size_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or std_logic_vector'(pack(right)));
      return ret_rec;
    end "or";
    function "or" (left : cmd_size_fifo_wdata_type; right : std_logic_vector) return cmd_size_fifo_wdata_type is
      variable ret_rec : cmd_size_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "or" (left : cmd_size_fifo_wdata_type; right : unsigned) return cmd_size_fifo_wdata_type is
      variable ret_rec : cmd_size_fifo_wdata_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) or right);
    return ret_rec;
    end "or";
    function "and" (left, right : cmd_size_fifo_wdata_type) return cmd_size_fifo_wdata_type is
      variable ret_rec : cmd_size_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and std_logic_vector'(pack(right)));
    return ret_rec;
    end "and";
    function "and" (left : cmd_size_fifo_wdata_type; right : std_logic_vector) return cmd_size_fifo_wdata_type is
      variable ret_rec : cmd_size_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "and" (left : cmd_size_fifo_wdata_type; right : unsigned) return cmd_size_fifo_wdata_type is
      variable ret_rec : cmd_size_fifo_wdata_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) and right);
    return ret_rec;
    end "and";
    function "xor" (left, right : cmd_size_fifo_wdata_type) return cmd_size_fifo_wdata_type is
      variable ret_rec : cmd_size_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor std_logic_vector'(pack(right)));
    return ret_rec;
    end "xor";
    function "xor" (left : cmd_size_fifo_wdata_type; right : std_logic_vector) return cmd_size_fifo_wdata_type is
      variable ret_rec : cmd_size_fifo_wdata_type;
    begin
      ret_rec := unpack(std_logic_vector'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "xor" (left : cmd_size_fifo_wdata_type; right : unsigned) return cmd_size_fifo_wdata_type is
      variable ret_rec : cmd_size_fifo_wdata_type;
    begin
      ret_rec := unpack(unsigned'(pack(left)) xor right);
    return ret_rec;
    end "xor";
    function "not" (right : cmd_size_fifo_wdata_type) return cmd_size_fifo_wdata_type is
      variable ret_rec : cmd_size_fifo_wdata_type;
    begin
      ret_rec := unpack(not std_logic_vector'(pack(right)));
    return ret_rec;
    end "not";

end espi_regs_pkg;