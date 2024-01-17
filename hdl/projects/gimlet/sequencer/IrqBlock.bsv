package IrqBlock;
// Bring in enable vector
// Bring is cause_raw vector
// Bring in debug vector
// Bring in clear vector
// Out cause_sticky
// Out irq bit.
// Functionality:
// Cause_raw monitored for rising edges.
// Cause_raw_redges bitwise or'd with debug strobe is stored in cause_sticky
// cause clear clears bits, but if a rising edge is happening the same cycle we let it through so interrupts aren't missed.
// cause_sticky bitwise and with enable and or-reduced to become irq out (registered)

interface IRQBlock#(type irq_type);
    (* always_enabled *)
    method Action enables(irq_type value);
    (* always_enabled *)
    method Action cause_raw(irq_type value);
    (* always_enabled *)
    method Action clear(irq_type value);
    (* always_enabled *)
    method Action debug(irq_type value);
    method irq_type cause_reg;
    method Bit#(1) irq_pin;
endinterface

module mkIRQBlock (IRQBlock#(type_t))
    provisos(
        Bits#(type_t, s), 
        Bitwise#(type_t)
    );
    Reg#(type_t) cause_pins_last <- mkReg(unpack(0));
    Reg#(type_t) cause <- mkReg(unpack(0));
    Reg#(Bit#(1))irq <- mkReg(0);
    // Combo stuff
    Wire#(type_t) cur_cause_raw <- mkDWire(unpack(0));
    Wire#(type_t) cur_enables <- mkDWire(unpack(0));
    Wire#(type_t) cur_dbg <- mkDWire(unpack(0));
    Wire#(type_t) cur_clear <- mkDWire(unpack(0));

    rule do_irq_management;
        // Sample the inputs for next cycle
        cause_pins_last <= cur_cause_raw;
        // If cur_dbg or new inputs are rising wrt last inputs we have rising edges
        let rising_raw_causes = cur_cause_raw & (~cause_pins_last);  // Get rising edges on causes
        let final_rising = rising_raw_causes | cur_dbg;  // Allow software to cause a rising edge regardless of input pin state
        // rising edges get stored as the cause register
        
        // Don't allow a clear this cycle to clear any interrupts that would be triggered
        // this cycle (so we don't accidentally drop an interrupt) by masking off any bits that will be triggered
        // this cycle from the clear mask
        let clear_mask = cur_clear & (~final_rising);    
        
        // keep any sticky bits, set any new bis and clear any cleared bits.
        let new_cause =  (cause | final_rising) & (~clear_mask);
        cause <= new_cause;
        irq <= reduceOr(pack(new_cause & cur_enables));
    endrule
    
    method enables = cur_enables._write;
    method cause_raw = cur_cause_raw._write;
    method clear = cur_clear._write;
    method debug = cur_dbg._write;
    method irq_pin = irq._read;
    method cause_reg = cause._read;


endmodule
endpackage
