package LevelTrans;







interface LevelTransIF;
    method Action a_in();
    method Bit#(1) a_out();
    method Action b_in();
    method Bit#(1) b_out();
endinterface


module mkLevelTrans(LevelTransIF);
    Reg#(Bit#(1)) a_int_reg <- mkReg(1);
    Reg#(Bit#(1)) b_int_reg <- mkReg(1);


    // Driving or releasing A means B is the bus master now
    // Drive A when we're not driving A, A in = 1, B_in = 0, and we're not driving B
    rule do_drive_a (a_int_reg == 1 && a_in == 1 && b_in == 0 && b_int_reg = 1);
    a_int_reg <= 0;
    endrule
    // Release A when we're driving A + B_in = 1 and we're not driving B
    rule do_release_a(a_int_reg == 0 && a_in == 0 && b_in == 1  && b_int_reg = 1);
    a_int_reg <= 1;
    endrule

    // Driving or releasing B means A is the bus master now
    rule do_drive_b (b_int_reg == 1 && b_in == 1 && a_in == 0 &&  a_int_reg = 1);
    b_int_reg <= 0;
    endrule

    rule do_release_b (b_int_reg == 0 && b_in == 1 && a_in == 1 && a_int_reg = 1);
    b_int_reg <= 1;
    endrule

endmodule