package IgnitionControllerShared;

typedef UInt#(TLog#(n)) ControllerId#(numeric type n);

// Given a bit_vector_t with zero or more bits indicating requests and a
// bit_vector_t with exactly one bit set indicating the preferred (next) request
// to select, round-robin select the next request.
function bit_vector_t round_robin_select(
        bit_vector_t pending,
        bit_vector_t base)
            provisos (Bits#(bit_vector_t, sz));
    let _base = extend(pack(base));
    let _pending = {pack(pending), pack(pending)};

    match {.left, .right} = split(_pending & ~(_pending - _base));
    return unpack(left | right);
endfunction

endpackage
