# MIPS32
Implementing a MIPS32 processor in Verilog and testing it using a testbench . What is MIPS32 ? 
MIPS32 is a 32-bit Reduced Instruction Set Computer (RISC) architecture , it is widely used in embedded systems, networking equipment, routers, automotive systems, and microcontrollers.

32 x 4 Byte Register Bank 
max 1023 instructons (32 bit each ) 
1023 x 4 Bytes ~ 4KB Memory 
Operations 


Instruction Layout : 
    [31:30]  type    ALUR=00  ALUI=01  MEM=10  BRANCH=11
    [29:26]  opcode  (4 bits)
    [25:21]  rd      destination / branch test register for memory and branch type 
    [20:16]  rt      source B (ALUR) / addr-high (MEM/BRANCH)
    [15:11]  rs      source A (ALUR/ALUI) / addr-low  (MEM/BRANCH)
    [15: 0]  imm16   signed immediate — shares [15:11] with rs
    [20:11]  addr10  memory or branch target address
    For ALUI: set rs=R0 (bits 15:11 = 0) so imm[15:0] is clean
    For MEM:  rs[15:11] = low 5 bits of address AND source reg
    Keep rt[20:16]=0 so addr fits within 5 bits (<32).
    For BRANCH: rd[25:21] = register to test (RTL reads
    regBank[IR[25:21]] via rdM/rdL for BRANCH type).
    
