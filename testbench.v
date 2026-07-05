`timescale 1ns/1ps


//  Simple testbench for MISPS32 pipelined CPU
//  Tests: 1x ALU-R, 1x ALU-I, 1x LOAD, 1x STORE, 1x JUMPIF
//  Data hazards are IGNORED (NOPs inserted manually).
//  JUMPIF uses BEQZ R0 (R0=0 always) so branch is always
//  taken, confirming the flush path is exercised.


module cpu_tb;

    reg clk1, clk2, reset;
    initial clk1 = 0;  always #5 clk1 = ~clk1;
    initial clk2 = 0;  always #5 clk2 = ~clk2;

    CPU dut (.clk1(clk1), .clk2(clk2), .reset(reset));

    `define NOP 32'b0

    task load_program;
        integer k;
    begin
        for (k = 0; k < 1024; k = k + 1)
            dut.Instr_M[k] = `NOP;

        // Register / RAM pre-loads
        dut.regBank[2] = 32'd7;          // R2 = 7
        dut.regBank[3] = 32'd3;          // R3 = 3
        dut.RAM[5]     = 32'hDEAD_BEEF; // LOAD source




        dut.Instr_M[ 0] = `NOP;
        dut.Instr_M[ 1] = `NOP;
        dut.Instr_M[ 2] = `NOP;

        // ---- ALU-R: ADD R1, R2, R3 → R1 = 10 -----------------------
        // type=00 op=ADD(0000) rd=R1[25:21] rt=R2[20:16] rs=R3[15:11]
        // Encoding: 0x00221800
        dut.Instr_M[ 3] = {2'b00, 4'b0000,   // ALUR, ADD
                            5'd1,             // rd = R1   [25:21]
                            5'd2,             // rt = R2   [20:16]
                            5'd3,             // rs = R3   [15:11]
                            11'b0};

        dut.Instr_M[ 4] = `NOP;
        dut.Instr_M[ 5] = `NOP;
        dut.Instr_M[ 6] = `NOP;

        // ---- ALU-I: ADDI R4, R0, #20 → R4 = 20 ---------------------
        // Source A = regBank[rs] where rs=[15:11]. Set rs=R0=0 so imm
        // field [15:0] is uncontaminated. Result = 0 + 20 = 20.
        // Encoding: 0x40800014
        dut.Instr_M[ 7] = {2'b01, 4'b0000,   // ALUI, ADD
                            5'd4,             // rd  = R4   [25:21]
                            5'd0,             // rt  = R0   [20:16] (unused)
                            16'd20};          // imm = 20   [15:0]  (rs=0 implicit)

        dut.Instr_M[ 8] = `NOP;
        dut.Instr_M[ 9] = `NOP;
        dut.Instr_M[10] = `NOP;

        // ---- LOAD: R5 = RAM[5] → R5 = 0xDEADBEEF -------------------

        // addr[20:11] = {rt[20:16]=0, rs[15:11]=5} = 5
        // Encoding: 0xB0A02800

        dut.Instr_M[11] = {2'b10, 4'b1100,   // MEM, LOAD
                            5'd5,             // rd  = R5   [25:21]
                            5'd0,             // rt  = 0    [20:16] (addr high = 0)
                            5'd5,             // rs  = 5    [15:11] (addr low  = 5)
                            11'b0};

        dut.Instr_M[12] = `NOP;
        dut.Instr_M[13] = `NOP;
        dut.Instr_M[14] = `NOP;

        // ---- STORE: RAM[4] = R4 = 20 --------------------------------
        // EX default (MEM type): EX_MEM_ALUOut = ID_EX_A = regBank[rs]
        // rs[15:11] = R4 = 4 → value = R4 = 20
        // addr[20:11] = {rt=0, rs=4} = 4 → writes to RAM[4]
        // Encoding: 0xB4802000

        dut.Instr_M[15] = {2'b10, 4'b1101,   // MEM, STORE
                            5'd4,             // rd  = R4   [25:21] (unused)
                            5'd0,             // rt  = 0    [20:16] (addr high = 0)
                            5'd4,             // rs  = R4   [15:11] (source + addr low = 4)
                            11'b0};

        dut.Instr_M[16] = `NOP;
        dut.Instr_M[17] = `NOP;
        dut.Instr_M[18] = `NOP;

        // ---- BEQZ R0, #22 → always taken, tests flush ---------------
        // R0 = 0 always → EX_MEM_COND=1=EQUAL → BEQZ fires every time.
        // Pipeline flushes addr 20 & 21 (canary SUBs) → R5 preserved.
        // rd[25:21] = R0 = 0 → RTL reads regBank[0] = 0 ✓
        // addr[20:11] = 22: {rt[20:16]=0, rs[15:11]=22} → 22 ✓
        // Encoding: 0xE800B000

        dut.Instr_M[19] = {2'b11, 4'b1010,   // BRANCH, BEQZ
                            5'd0,             // rd  = R0   [25:21] (always 0)
                            5'd0,             // rt  = 0    [20:16] (target high = 0)
                            5'd22,            // rs  = 22   [15:11] (target low  = 22)
                            11'b0};

        // Canary: SUB R5,R5,R5 — zeros R5 if not flushed
        dut.Instr_M[20] = {2'b00, 4'b0001, 5'd5, 5'd5, 5'd5, 11'b0};
        dut.Instr_M[21] = {2'b00, 4'b0001, 5'd5, 5'd5, 5'd5, 11'b0};

        dut.Instr_M[22] = `NOP;              // branch-target landing pad

        // HALT: ALUI type with lower 30 bits = 0
        dut.Instr_M[23] = {2'b01, 30'b0};

    end
    endtask

    // ---- stimulus -----------------------------------------------
    
    integer cycle;

    initial begin
        reset = 1; #20; reset = 0;
        load_program;

        $display("\n=== MISPS32 Simple Testbench ===\n");
        $display("%-6s %-12s %-12s %-12s %-10s",
                 "Cycle","PC","IF_ID_IR","EX_MEM_IR","TAKEN_BR");

        for (cycle = 0; cycle < 40; cycle = cycle + 1) begin
            @(posedge clk1); #1;
            $display("%-6d 0x%-10h 0x%-10h 0x%-10h %-10b",
                     cycle, dut.PC, dut.IF_ID_IR,
                     dut.EX_MEM_IR, dut.TAKEN_BRANCH);
        end

        // ---- assertions -----------------------------------------
        $display("\n=== Final State Checks ===\n");

        // ALU-R: R1 = R2 + R3 = 7 + 3 = 10
        if (dut.regBank[1] === 32'd10)
            $display("PASS  ALU-R  : R1 = %0d  (expected 10)", dut.regBank[1]);
        else
            $display("FAIL  ALU-R  : R1 = %0d  (expected 10)", dut.regBank[1]);

        // ALU-I: R4 = R0 + 20 = 20
        if (dut.regBank[4] === 32'd20)
            $display("PASS  ALU-I  : R4 = %0d  (expected 20)", dut.regBank[4]);
        else
            $display("FAIL  ALU-I  : R4 = %0d  (expected 20)", dut.regBank[4]);

        // LOAD: R5 = RAM[5] = 0xDEADBEEF
        if (dut.regBank[5] === 32'hDEAD_BEEF)
            $display("PASS  LOAD   : R5 = 0x%h  (expected 0xDEADBEEF)", dut.regBank[5]);
        else
            $display("FAIL  LOAD   : R5 = 0x%h  (expected 0xDEADBEEF)", dut.regBank[5]);

        // STORE: RAM[4] = R4 = 20
        if (dut.RAM[4] === 32'd20)
            $display("PASS  STORE  : RAM[4] = %0d  (expected 20)", dut.RAM[4]);
        else
            $display("FAIL  STORE  : RAM[4] = %0d  (expected 20)", dut.RAM[4]);

        // JUMPIF: BEQZ R0 always taken → flush canaries → R5 intact
        if (dut.regBank[5] === 32'hDEAD_BEEF)
            $display("PASS  JUMPIF : R5=0x%h — canary intact, flush confirmed",
                     dut.regBank[5]);
        else
            $display("FAIL  JUMPIF : R5=0x%h — canary corrupted, flush FAILED",
                     dut.regBank[5]);

        $display("\n=== Testbench Done ===\n");
        $finish;
    end

    initial begin
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);
    end

endmodule