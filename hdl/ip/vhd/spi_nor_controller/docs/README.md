This controller aims to provide an interface from software and the espi blocks

From the software side, we support read and writes.

The sw interface is intended to be rather simple:
There are registers for a 256byte tx/rx fifo, and various fifo flags in the status register.
There are fifo reset signals in the control register.

The software interface to issue commands is as follows:
If doing a data write:
- (Optional: clean out any data in FIFOs using control register to reset them)
- Write up to 256 data bytes into TX FIFO, each write is 4 bytes due to 32bit access.
- Set data size register to the number of data bytes to send. This does not have to be 4 byte multiple
- Write number of dummy *clocks* into the dummy register as required for the instruction according to flash datasheeet
- Write instruction into the instruction register. Write-side effect will begin the transaction.
- Wait until status shows not busy

If doing a data read
- (Optional: clean out any data in FIFOs using control register to reset them)
- Set data size register to the number of data bytes to send. This does not have to be 4 byte multiple
- Write number of dummy *clocks* into the dummy register as required for the instruction according to flash datasheeet
- Write instruction into the instruction register. Write-side effect will begin the transaction.
- You can either wait until status shows not busy, or poll on the rx fifo used wds and start consuming data
-   as it becomes available
- Wait until status shows not busy