package CounterRAM;

import BRAMCore::*;
import ClientServer::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Probe::*;

import DReg::*;


typedef UInt#(counter_sz) Value#(type counter_sz);
typedef UInt#(amount_sz) Amount#(type amount_sz);

typedef struct {
    Bool clear;
    counter_id id;
} CounterReadRequest#(type counter_id) deriving (Bits, FShow);

typedef enum {
    Set,
    Add,
    Subtract
} ProducerOp deriving (Bits, Eq, FShow);

typedef struct {
    ProducerOp op;
    Amount#(amount_sz) amount;
    counter_id id;
} CounterWriteRequest#(type counter_id, numeric type amount_sz)
    deriving (Bits, FShow);

typedef struct {
    Value#(counter_sz) value;
    counter_id id;
} CounterWrite#(type counter_id, numeric type counter_sz)
    deriving (Bits, FShow);

interface Producer #(type counter_id, numeric type amount_sz);
    interface Put#(CounterWriteRequest#(counter_id, amount_sz)) request;
    method Bool idle();
endinterface

typedef Server#(CounterReadRequest#(counter_id), Value#(counter_sz))
    Consumer#(type counter_id, numeric type counter_sz);

interface CounterRAM #(
            type counter_id,
            numeric type counter_sz,
            numeric type amount_sz);
    interface Producer#(counter_id, amount_sz) producer;
    interface Consumer#(counter_id, counter_sz) consumer;
endinterface

module mkCounterRAM #(Integer n)
        (CounterRAM#(counter_id, counter_sz, amount_sz))
            provisos (
                Bits#(counter_id, counter_id_sz),
                Eq#(counter_id),
                FShow#(counter_id),
                // Make sure Amount fits in Value.
                Add#(amount_sz, _, counter_sz));
    BRAM_DUAL_PORT#(counter_id, Value#(counter_sz))
            ram <- mkBRAMCore2(n, False);

    let producer_port = ram.a;
    let consumer_port = ram.b;

    Reg#(ProducerState#(counter_id, counter_sz, amount_sz))
            producer_state <- mkReg(tagged AwaitingRequest);
    RWire#(CounterWriteRequest#(counter_id, amount_sz))
            producer_request_next <- mkRWire();

    Reg#(ConsumerState#(counter_id))
            consumer_state <- mkReg(tagged AwaitingRequest);
    RWire#(CounterReadRequest#(counter_id)) consumer_request_next <- mkRWire();

    // Use a FIFO with unguarded enq, allowing it to be used without blocking
    // unrelated parts of the `do_handle_requests` rule. The rule explicitly
    // checks `notFull` to avoid overwriting responses.
    FIFOF#(Value#(counter_sz)) consumer_response <- mkGLFIFOF(True, False);

    let producer_idle =
            case (producer_state) matches
                tagged AwaitingRequest: True;
                tagged AwaitingWriteCommit .*: True;
                default: False;
            endcase;

    let consumer_idle =
            case (consumer_state) matches
                tagged RequestPending .*: False;
                tagged ReadingValue .request: !request.clear;
                default: True;
            endcase;

    //
    // Counter producer and consumer requests can be issued concurrently but
    // because a read from and a write to the same RAM address may result in an
    // undefined value being read there needs to be some collision detection
    // logic in place to handle these cases. This logic depends on data from
    // both requests and implementing all of it in a single rule is most
    // straightforward.
    //
    // Both counter producer and consumer requests follow a similar sequence.
    // Upon accepting a request the current value of the counter is read from
    // RAM. A consumer request may then clear the counter value by writing a 0
    // to RAM while a counter write request will update the counter value and
    // write it back to RAM.
    //
    (* fire_when_enabled *)
    rule do_handle_requests;
        let producer_performs_clear =
                case (tuple2(producer_state, consumer_state)) matches
                    {tagged ReadingValue .write,
                        tagged RequestPending .read}:
                            (write.id == read.id && read.clear);
                    {tagged ReadingValue .write,
                        tagged ReadingValue .read}:
                            (write.id == read.id && read.clear);
                    {tagged ReadingValue .write,
                        tagged AwaitingWriteCommit .clear_id}:
                            (write.id == clear_id);
                    {tagged WritePending .write,
                        tagged ReadingValue .read}:
                            (write.id == read.id && read.clear);
                    default: False;
                endcase;

        if (consumer_state matches tagged AwaitingWriteCommit .*)
            if (consumer_request_next.wget matches tagged Valid .next_request)
                consumer_state <= tagged RequestPending next_request;
            else
                consumer_state <= tagged AwaitingRequest;

        // Select the counter value returned to the consumer, reading from the
        // producer or the consumer port depending on whether or not there is a
        // update/clear conflict.
        else if (consumer_state matches
                    tagged ReadingValue .request) begin
            let counter_value =
                    case (producer_state) matches
                        // If the producer is updating the same counter, use the
                        // value of that write request.
                        tagged WritePending .write_request &&&
                                (request.id == write_request.id):
                                    write_request.value;
                        tagged AwaitingWriteCommit .write_request &&&
                                (request.id == write_request.id):
                                    write_request.value;

                        // In all other cases read the counter value from the
                        // consumer port.
                        default: consumer_port.read;
                    endcase;

            consumer_response.enq(counter_value);

            if (request.clear && !producer_performs_clear) begin
                consumer_port.put(True, request.id, 0);
                consumer_state <= tagged AwaitingWriteCommit request.id;
            end
            else if (consumer_request_next.wget matches
                        tagged Valid .next_request)
                consumer_state <= tagged RequestPending next_request;
            else
                consumer_state <= tagged AwaitingRequest;
        end
        // Start the pending consumer request if the response can be enqueued.
        else if (consumer_state matches tagged RequestPending .read &&&
                consumer_response.notFull) begin
            consumer_port.put(False, read.id, ?);
            consumer_state <= tagged ReadingValue read;
        end
        // Accept the next consumer request.
        else if (consumer_state matches tagged AwaitingRequest &&&
                consumer_request_next.wget matches tagged Valid .request)
            consumer_state <= tagged RequestPending request;

        if (producer_state matches tagged AwaitingWriteCommit .*) begin
            if (producer_request_next.wget matches tagged Valid .request)
                producer_state <= tagged RequestPending request;
            else
                producer_state <= tagged AwaitingRequest;
        end

        else if (producer_state matches tagged WritePending .write) begin
            producer_port.put(True, write.id, write.value);
            producer_state <= tagged AwaitingWriteCommit write;
        end

        else if (producer_state matches tagged ReadingValue .request) begin
            let value = producer_performs_clear ? 0 : producer_port.read;
            let amount = extend(request.amount);
            let write =
                    CounterWrite {
                        id: request.id,
                        value:
                            case (request.op)
                                Set: amount;
                                Add: boundedPlus(value, amount);
                                Subtract: boundedMinus(value, amount);
                            endcase};

            producer_state <= tagged WritePending write;
        end

        else if (producer_state matches tagged RequestPending .request) begin
            producer_port.put(False, request.id, ?);
            producer_state <= tagged ReadingValue request;
        end

        else if (producer_state matches tagged AwaitingRequest &&&
                producer_request_next.wget matches tagged Valid .request)
            producer_state <= tagged RequestPending request;

        // $display(
        //     fshow(producer_state),
        //     " ",
        //     fshow(consumer_state),
        //     " ",
        //     fshow(producer_performs_clear));
    endrule

    interface Producer producer;
        interface Put request;
            method put if (producer_idle) =
                    producer_request_next.wset;
        endinterface

        method idle = producer_idle;
    endinterface

    interface Server consumer;
        interface Put request;
            method put if (consumer_idle) =
                    consumer_request_next.wset;
        endinterface

        interface Get response = toGet(fifofToFifo(consumer_response));
    endinterface
endmodule

typedef union tagged {
    void AwaitingRequest;
    CounterWriteRequest#(counter_id, amount_sz) RequestPending;
    CounterWriteRequest#(counter_id, amount_sz) ReadingValue;
    CounterWrite#(counter_id, counter_sz) WritePending;
    CounterWrite#(counter_id, counter_sz) AwaitingWriteCommit;
} ProducerState#(
        type counter_id,
        numeric type counter_sz,
        numeric type amount_sz)
            deriving (Bits, FShow);

typedef union tagged {
    void AwaitingRequest;
    CounterReadRequest#(counter_id) RequestPending;
    CounterReadRequest#(counter_id) ReadingValue;
    counter_id AwaitingWriteCommit;
} ConsumerState#(type counter_id) deriving (Bits, FShow);

endpackage
