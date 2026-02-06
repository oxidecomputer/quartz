// Integration test: Helper functions for counter module
package CounterHelpers;

// Helper function to check if a value is within range
function Bool inRange(Bit#(16) value, Bit#(16) min, Bit#(16) max);
    return (value >= min) && (value <= max);
endfunction

// Helper function to saturate a value
function Bit#(16) saturate(Bit#(16) value, Bit#(16) max);
    return (value > max) ? max : value;
endfunction

// Helper function to wrap a value
function Bit#(16) wrapValue(Bit#(16) value, Bit#(16) max);
    return (value > max) ? (value - max - 1) : value;
endfunction

endpackage: CounterHelpers
