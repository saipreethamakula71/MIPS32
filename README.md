# MIPS32
##### Things Done So far :
    ALU, Branching, Conditional Branching and Memory Operations 
    Mitigted Control Hazards using Pipeline stalling and Flushing
    Assembler.py to convert custom Assembly code to Binary Inatructions 
    Assembler also keeps in mind Data Hazards and reorders Instructions or inserts NOPs if necessary.

###### Future Updates : 
    Branch Prediction
    Hazard detection unit 
    Forwarding
    Memory Optimisation using Cache 

Implementing a MIPS32 processor in Verilog and testing it using a testbench . What is MIPS32 ? 
MIPS32 is a 32-bit Reduced Instruction Set Computer (RISC) architecture , it is widely used in embedded systems, networking equipment, routers, automotive systems, and microcontrollers.

32 x 4 Byte Register Bank   
max 1023 instructons (32 bit each )   
1023 x 4 Bytes ~ 4KB Memory 

##### Operations 

###### Instruction Layout : 
    [31:30]  type    ALUR=00  ALUI=01  MEM=10  BRANCH=11  
    [29:26]  opcode  (4 bits)  
    [25:21]  rd      destination/branch test register for memory and branch type   
    [20:16]  rt      source B (ALUR)/addr-high (MEM/BRANCH)  
    [15:11]  rs      source A (ALUR/ALUI) / addr-low  (MEM/BRANCH)  
    [15: 0]  imm16   signed immediate — shares [15:11] with rs  
    [20:11]  addr10  memory or branch target address  
    
    For ALUI: set rs=R0 (bits 15:11 = 0) so imm[15:0] is clean  
    For MEM:  rs[15:11] = low 5 bits of address AND source reg  
    Keep rt[20:16]=0 so addr fits within 5 bits (<32).  
    For BRANCH: rd[25:21] = register to test (RTL reads  
    regBank[IR[25:21]] via rdM/rdL for BRANCH type).  
    
##### architecture : 
instruction memory , PC , ALU , Register Bank , memory 
clock : 2 clock cycles 
5 stages : Instruciton Read, Instruction Decode, Execute, Memory, Write Back

##### Instruction Read / Instruction Fetch : 

In instruciton fetch stage we either fetch the next instruction or jumped instruciton or NOP. Normally we fetch next instruciton from instruciton memory , but in case of Jump type instructions we jump to that instruciton, so we fetch the instruction  menitoned (in jump type instruction )  . We fetch NOP when the CPU is HALTED, giving time for the previous instrucitons in the pipeline to finish . This happens in clk 1 . We then store the instruction in a register called IF_ID_IR.

##### Instruction Decode : 

In instrucion decode stage we fetch the regBank for ra and rb , which will be used in EX stage for Arithmetic or Logic operations . Along with this , we fetch immediate ( 16 bit - [15:0] ) and extend MSB by 16 bits (sign extension ) . We then store the Instruction in ID_EX_IR (sometimes we store NOP , we will discuss it later ) . We store regbank[ra],Imm and regbank[rb] in  ID_EX_A, ID_EX_Imm and  ID_EX_B .This happens in clk 2.

##### Execute : 
In this stage we perform ALU operations , check if branch is taken and if program is HALTED. ALU operations are performed based on instruction received (instr[31:30] ) if this is of type ALUR we perform opertion on A and B from regbank , if it is of type ALUI we perform operation on A and Imm obtained from Instruction Decode Stage , we store this output of the operation in EX_MEM_ALUout . Checking if we need to take branch by checking ID_EX_A , if this is equal to zero and Instruciton says branch if it is zero we make TAKEN_BRANCH as 1 , and store the required instruction as NOP for further stages  , if TAKEN_BRANCH is already 1 , we make it zero . 

 Now let us Understand how Jump , TAKEN_BRANCH works : 
 assume instr1 is our jumpif statement 
 initially PC is some j 
 clk 1 happens , nothing is in EX stage and ID stage gets Instr1 from the register 
 |     clk1 |      clk2 |     clk1 |     ckl2 |     clk1 | 
 |----------|-----------|----------|----------|----------|
 |PC=j , TAKEN_BRANCH =0 Instr1 comes and gets stored in IF_ID_IR| | | | |
 
then clk2 happns and in ID stage regA and regB are taken out 

 |     clk1 |      clk2 |     clk1 |     ckl2 |     clk1 | 
 |----------|-----------|----------|----------|----------|
 |PC=j , TAKEN_BRANCH =0 Instr1 comes and gets stored in IF_ID_IR -> PC=j+1| | | | |
 | | regA and reg B are fetched from regBank  -> ID_EX_MEM=Instr1 | | | | 

 then clk1 happens and in IF stage instr2 (PC=j+1 ) comes , in EX stage instr1 gets executed. Since it is a branching condition we make TAKEN_BRANCH as 1 . 
 
 ###### Everything after -> are scheduled at the end of clk 
 
 |     clk1 |      clk2 |     clk1 |     ckl2 |     clk1 | 
 |----------|-----------|----------|----------|----------|
 |PC=j , TAKEN_BRANCH =0 Instr1 comes and gets stored in IF_ID_IR| | | | |
 | | regA and reg B are fetched from regBank  -> ID_EX_MEM=Instr1 | | | | 
 | | | Instr2 comes , Instr1 executes -> PC=j+2 , IF_ID_IR=Instr2 , EX_MEM_IR=Instr1  , TAKEN_BRANCH=1 |||

again clk2 happens, Instr 2 decodes A, B and Imm are accessed from regBank . Actually speaking this should not happen , why ? because the next instruction after branching should be something else and not Instr2 (j+1) , so we fill the ID_EX_IR with NOP instead of Instr 2 . Nothing happens in Memory stage because Instr 1 is in Memory stage and it is not memory type . 
 
 |     clk1 |      clk2 |     clk1 |     ckl2 |     clk1 | 
 |----------|-----------|----------|----------|----------|
 |PC=j , TAKEN_BRANCH =0 Instr1 comes and gets stored in IF_ID_IR| | | | |
 | | regA and reg B are fetched from regBank  -> ID_EX_MEM=Instr1 | | | | 
 | | | Instr2 comes , Instr1 executes -> PC=j+2 , IF_ID_IR=Instr2 , EX_MEM_IR=Instr1  , TAKEN_BRANCH=1 |||
| | | | Instr 2 decodes , EX_MEM_IR is still Instr 1, IF_ID_IR is still Instr2 ->  MEM_WB_IR = Instr1 , ID_EX_IR=NOP | | 

 Again comes clk1 , this time in IF stage we EX_MEM_IR's jump location ie Instr1's jump location . In EX stage we have NOP and since TAKEN_BRANCH is HIGH we make it LOW . In WB stage we have Instr1 , nothing happens because Instr1 is jump type and not ALU type or Memory type . 

 
 |     clk1 |      clk2 |     clk1 |     ckl2 |     clk1 | 
 |----------|-----------|----------|----------|----------|
 |PC=j , TAKEN_BRANCH =0 Instr1 comes and gets stored in IF_ID_IR| | | | |
 | | regA and reg B are fetched from regBank  -> ID_EX_MEM=Instr1 | | | | 
 | | | Instr2 comes , Instr1 executes -> PC=j+2 , IF_ID_IR=Instr2 , EX_MEM_IR=Instr1  , TAKEN_BRANCH=1 |||
| | | | Instr 2 decodes , EX_MEM_IR is still Instr 1, IF_ID_IR is still Instr2 ->  MEM_WB_IR = Instr1 , ID_EX_IR=NOP | | 
| | | | | Jumped instruction is fetched in IF stage,-> IF_ID_IR= jumped Instr , ID_EX_IR= NOP , EX_MEM_IR=NOP , MEM_WB_IR=Instr1|

there is no Instr 2 anywhere , we basically flushed out wrong instructions .

###### Memory Stage : 

In this stage we either store values in or from memory ( 4K Byte ) 

###### Write Back Stage : 
In this stage we write back into registers and Memory. 



    
    
    


 
 
 

 





