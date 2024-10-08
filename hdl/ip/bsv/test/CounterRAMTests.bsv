package CounterRAMTests;

import ClientServer::*;
import GetPut::*;
import StmtFSM::*;

import CounterRAM::*;
import TestUtils::*;


typedef Bit#(4) Id;
typedef CounterReadRequest#(Id) Read;
typedef CounterWriteRequest#(Id, 8) Write;
typedef CounterRAM#(Id, 8, 8) Counters;

module mkSetAndReadTest (Empty);
    Counters counters <- mkCounterRAM(15);

    mkAutoFSM(seq
        counters.producer.request.put(Write {id: 0, op: Set, amount: 1});
        assert_false(counters.producer.idle, "expected producer not idle");
        await(counters.producer.idle);

        // Reading the counter without clearing it should yield the same value.
        repeat(3) seq
            counters.consumer.request.put(Read {id: 0, clear: False});
            assert_get_eq(
                counters.consumer.response, 1,
                "expected a count of 1");
        endseq
    endseq);

    mkTestWatchdog(100);
endmodule

module mkSetAndReadClearTest (Empty);
    Counters counters <- mkCounterRAM(15);

    mkAutoFSM(seq
        counters.producer.request.put(Write {id: 0, op: Set, amount: 1});
        await(counters.producer.idle);

        counters.consumer.request.put(Read {id: 0, clear: True});
        assert_get_eq(counters.consumer.response, 1, "expected a count of 1");

        // Reading the counter again should yield 0.
        counters.consumer.request.put(Read {id: 0, clear: False});
        assert_get_eq(counters.consumer.response, 0, "expected a count of 0");
    endseq);

    mkTestWatchdog(100);
endmodule

module mkAddSaturateTest (Empty);
    Counters counters <- mkCounterRAM(15);

    mkAutoFSM(seq
        counters.producer.request.put(Write {id: 0, op: Set, amount: 1});
        counters.producer.request.put(Write {id: 0, op: Add, amount: 255});
        await(counters.producer.idle);

        counters.consumer.request.put(Read {id: 0, clear: False});
        assert_get_eq(
            counters.consumer.response, 255,
            "expected a count of 255");
    endseq);

    mkTestWatchdog(100);
endmodule

module mkSubtractSaturateTest (Empty);
    Counters counters <- mkCounterRAM(15);

    mkAutoFSM(seq
        counters.producer.request.put(Write {id: 0, op: Set, amount: 1});
        counters.producer.request.put(Write {id: 0, op: Subtract, amount: 2});
        await(counters.producer.idle);

        counters.consumer.request.put(Read {id: 0, clear: False});
        assert_get_eq(counters.consumer.response, 0, "expected a count of 0");
    endseq);

    mkTestWatchdog(100);
endmodule

module mkConcurrentReadClearAndUpdateScenario1Test (Empty);
    Counters counters <- mkCounterRAM(15);

    mkAutoFSM(seq
        counters.producer.request.put(Write {id: 0, op: Set, amount: 1});
        await(counters.producer.idle);

        action
            counters.producer.request.put(Write {id: 0, op: Add, amount: 1});
            counters.consumer.request.put(Read {id: 0, clear: True});
        endaction
        assert_get_eq(counters.consumer.response, 1, "expected a count of 1");

        counters.consumer.request.put(Read {id: 0, clear: False});
        assert_get_eq(counters.consumer.response, 1, "expected a count of 1");
    endseq);
endmodule

module mkConcurrentReadClearAndUpdateScenario2Test (Empty);
    Counters counters <- mkCounterRAM(15);

    mkAutoFSM(seq
        counters.producer.request.put(Write {id: 0, op: Set, amount: 1});
        await(counters.producer.idle);

        counters.producer.request.put(Write {id: 0, op: Add, amount: 1});
        counters.consumer.request.put(Read {id: 0, clear: True});
        assert_get_eq(counters.consumer.response, 1, "expected a count of 1");

        counters.consumer.request.put(Read {id: 0, clear: False});
        assert_get_eq(counters.consumer.response, 1, "expected a count of 1");
    endseq);
endmodule

module mkConcurrentReadClearAndUpdateScenario3Test (Empty);
    Counters counters <- mkCounterRAM(15);

    mkAutoFSM(seq
        counters.producer.request.put(Write {id: 0, op: Set, amount: 1});
        await(counters.producer.idle);

        counters.producer.request.put(Write {id: 0, op: Add, amount: 1});
        noAction;
        counters.consumer.request.put(Read {id: 0, clear: True});
        assert_get_eq(counters.consumer.response, 2, "expected a count of 2");

        counters.consumer.request.put(Read {id: 0, clear: False});
        assert_get_eq(counters.consumer.response, 0, "expected a count of 0");
    endseq);
endmodule

module mkConcurrentReadClearAndUpdateScenario4Test (Empty);
    Counters counters <- mkCounterRAM(15);

    mkAutoFSM(seq
        counters.producer.request.put(Write {id: 0, op: Set, amount: 1});
        await(counters.producer.idle);

        counters.consumer.request.put(Read {id: 0, clear: True});
        counters.producer.request.put(Write {id: 0, op: Add, amount: 1});
        assert_get_eq(counters.consumer.response, 1, "expected a count of 1");

        counters.consumer.request.put(Read {id: 0, clear: False});
        assert_get_eq(counters.consumer.response, 1, "expected a count of 1");
    endseq);
endmodule

module mkMultipleAddSingleCounterTest (Empty);
    Counters counters <- mkCounterRAM(15);

    mkAutoFSM(seq
        counters.producer.request.put(Write {id: 0, op: Set, amount: 0});
        repeat(4) counters.producer.request.put(
                    Write {id: 0, op: Add, amount: 1});

        await(counters.producer.idle);
        counters.consumer.request.put(Read {id: 0, clear: False});
        assert_get_eq(counters.consumer.response, 3, "expected a count of 3");
    endseq);
endmodule

module mkMultipleAddMultipleCountersTest (Empty);
    Counters counters <- mkCounterRAM(15);

    mkAutoFSM(seq
        counters.producer.request.put(Write {id: 0, op: Set, amount: 0});
        counters.producer.request.put(Write {id: 1, op: Set, amount: 10});

        repeat(4) seq
            counters.producer.request.put(Write {id: 0, op: Add, amount: 1});
            counters.producer.request.put(Write {id: 1, op: Add, amount: 1});
        endseq

        counters.consumer.request.put(Read {id: 0, clear: False});
        assert_get_eq(counters.consumer.response, 3, "expected a count of 3");

        counters.consumer.request.put(Read {id: 1, clear: False});
        assert_get_eq(counters.consumer.response, 13, "expected a count of 13");
    endseq);
endmodule

endpackage
