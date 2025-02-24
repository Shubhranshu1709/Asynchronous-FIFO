# Asynchronous-FIFO
A FIFO (First-In, First-Out) is a queue-based memory buffer used to store and transfer data between different parts of a system. It ensures that the data is read in the same order it was written.

Key Features of FIFO:
Sequential Access: The first data written is the first to be read.
Buffering: Used to handle temporary storage in data flow.
Clock Domain Dependency: Can be synchronous or asynchronous.

Asynchronous FIFO
An asynchronous FIFO is a FIFO buffer where the write and read operations occur in different clock domains (i.e., it operates between two different clock frequencies).

Key Features of Asynchronous FIFO:
Different Clocks: Write and read clocks are independent.
Synchronization Mechanism: Uses Gray code pointers or dual flip-flop synchronization to avoid metastability.
Useful in Clock Domain Crossing (CDC): Allows safe data transfer between different clock domains.

Applications of Asynchronous FIFO:
Data transfer between different clock domains in FPGA/ASIC designs.
Communication interfaces like UART.
