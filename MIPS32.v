/*
BASIC MISPS32 pipelined  cpu 
with custom instructions 
*/
module CPU( 
    input clk1,
    input clk2,
    input reset
);
    reg [31:0] Instr_M [0:1023];
    reg [31:0] regBank [0:31];
    reg [31:0] RAM [0:1023];
    reg [9:0] PC;
    integer i;

    parameter 
    rdM=25,rdL=21,rtM=20,rtL=16,rsM=15,rsL=11,opM=29,opL=26,memM=20,memL=11,immM=15,immL=0;

   

    parameter typeM=31,typeL=30;

    parameter BRANCH_TYPE = 2'b11, ALUI_TYPE=2'b01,ALUR_TYPE=2'b00,MEM_TYPE=2'b10;

    parameter NOP =32'b0;

    parameter EQUAL =1'b1,NOT_EQUAL=1'b0; 

    parameter
    ADD=4'b0000,
    SUB=4'b0001,
    MUL=4'b0010,
    AND=4'b0011,
    OR=4'b0100,
    XOR=4'b0110,
    XNOR=4'b0101,
    BEQZ=4'b1010,
    BNEQZ=4'b1011,
    LOAD=4'b1100,
    STORE=4'b1101,
    MAX=4'b1110,
    MIN=4'b1111;

    

    // IF stage registers / latches 

    reg [31:0] IF_ID_IR  ;
    // ID stage registers / latches
    reg [31:0] ID_EX_A,ID_EX_B,ID_EX_Imm,ID_EX_IR;


    // EX stage registers/latches
    reg TAKEN_BRANCH,HALTED,EX_MEM_COND;
    reg [31:0] EX_MEM_ALUOut,EX_MEM_IR;

    // MEM stage registers 
    reg [31:0] MEM_WB_IR,MEM_WB_LMD,MEM_WB_ALUOut;
 

// ------   IF ,     EX ,     WB    -----

    always @ (posedge clk1)


        begin
// if reset 
            if ( reset)
                begin   
                    for ( i=0;i<1024;i=i+1)
                        begin
                            Instr_M[i]<=32'b0;
                            RAM[i]<=32'b0;

                        end 
                    PC<=10'b0;
                    for ( i=0;i<32;i=i+1)
                        begin
                            regBank[i]<=32'b0;
                        
                        end 
                    HALTED<=0;
                    TAKEN_BRANCH<=0;
                    ID_EX_A<=32'b0;
                    ID_EX_B<=32'b0;
                    ID_EX_Imm<=32'b0;
                    ID_EX_IR<=32'b0;
                    EX_MEM_ALUOut<=32'b0;
                    EX_MEM_COND<=1'b0;
                    EX_MEM_IR<=32'b0;
                    IF_ID_IR <= 32'b0;
                    MEM_WB_IR <= 32'b0;
                    MEM_WB_LMD <= 32'b0;
                    MEM_WB_ALUOut <= 32'b0;
                    

                end 
// if not reset 
            else 
                begin
                    
// IF stage
                

                
                    PC<=TAKEN_BRANCH?EX_MEM_IR[memM:memL]:PC+1;
                    
                    if (HALTED) IF_ID_IR<= 32'b0 ;
                    else IF_ID_IR<= TAKEN_BRANCH?Instr_M[EX_MEM_IR[memM:memL]] : Instr_M[PC];

                
// EX stage 
                // logic for TAKEN_BRANCH
                EX_MEM_IR<=TAKEN_BRANCH? 32'b0 : ID_EX_IR;

                if (TAKEN_BRANCH) 
                    TAKEN_BRANCH <= 0;
                else if (((ID_EX_A == 32'b0) & (ID_EX_IR[opM:opL] == BEQZ)) | 
                        ((ID_EX_A != 32'b0) & (ID_EX_IR[opM:opL] == BNEQZ))) 
                    TAKEN_BRANCH <= 1;

                
                EX_MEM_COND<=(ID_EX_A==32'b0);
                if ((ID_EX_IR[31:30]==ALUI_TYPE)&(ID_EX_IR[29:0]==30'b0)) HALTED<=1;
                


                case (ID_EX_IR[typeM:typeL])

                ALUR_TYPE :
                begin 
                    case (ID_EX_IR[opM:opL])
                    
                    ADD: EX_MEM_ALUOut<=ID_EX_A+ID_EX_B;
                    SUB: EX_MEM_ALUOut<=ID_EX_A-ID_EX_B;
                    MUL:EX_MEM_ALUOut<=ID_EX_A * ID_EX_B;
                    AND : EX_MEM_ALUOut<=ID_EX_A & ID_EX_B;
                    OR : EX_MEM_ALUOut<=ID_EX_A | ID_EX_B;
                    XOR : EX_MEM_ALUOut<=ID_EX_A ^ ID_EX_B;
                    MAX:EX_MEM_ALUOut<=(ID_EX_A>ID_EX_B) ? ID_EX_A :  ID_EX_B;
                    MIN: EX_MEM_ALUOut<=(ID_EX_A<ID_EX_B) ? ID_EX_A :  ID_EX_B;

                    default : EX_MEM_ALUOut<=ID_EX_A;
                    endcase

                   
                end 

                ALUI_TYPE:
                begin
                    
                    case (ID_EX_IR[opM:opL] )
                    ADD: EX_MEM_ALUOut<=ID_EX_A + ID_EX_Imm;
                    SUB: EX_MEM_ALUOut<=ID_EX_A - ID_EX_Imm;
                    MUL: EX_MEM_ALUOut<=ID_EX_A *  ID_EX_Imm;
                    MAX: EX_MEM_ALUOut<=(ID_EX_A>ID_EX_Imm) ? ID_EX_A :  ID_EX_Imm;
                    MIN: EX_MEM_ALUOut<=(ID_EX_A<ID_EX_Imm) ? ID_EX_A :  ID_EX_Imm;

                    default : EX_MEM_ALUOut<=ID_EX_A;
                    endcase
                end 
                
                default :
                begin
                EX_MEM_ALUOut<=ID_EX_A;
                end 
                endcase

// WB stage
                if ((MEM_WB_IR[typeM:typeL]==ALUI_TYPE)|(MEM_WB_IR[typeM:typeL]==ALUR_TYPE))
                    begin  
                        regBank[MEM_WB_IR[rdM:rdL]]<=MEM_WB_ALUOut;
                    end 
                else if (MEM_WB_IR[opM:opL]==LOAD) 
                    begin
                        regBank[MEM_WB_IR[rdM:rdL]]<=MEM_WB_LMD;
                    end 
                        
//else if ended 
                end                
                

// clk1 ended
        end 
    
// ID , MEM


    always @ (posedge  clk2)
        begin                
// ID stage 

                // if jump type 
                

                if ( (IF_ID_IR[typeM:typeL]==2'b11) & (IF_ID_IR[rdM:rdL]==4'b0000) ) ID_EX_A<=32'b0 ;
                else if (IF_ID_IR[typeM:typeL]==2'b11)  ID_EX_A<=regBank[IF_ID_IR[rdM:rdL]];
                

                else if (IF_ID_IR[rsM:rsL]==4'b0000 ) ID_EX_A<=32'b0 ;
                else ID_EX_A<=regBank[IF_ID_IR[rsM:rsL]];

                ID_EX_IR<=TAKEN_BRANCH ? NOP : IF_ID_IR;
                // signed immediate
                ID_EX_Imm<={{16{IF_ID_IR[immM]}},IF_ID_IR[immM:immL]}; 
                
                if (IF_ID_IR[rtM:rtL]==4'b0000 ) ID_EX_B<=32'b0;
                else ID_EX_B<=regBank[IF_ID_IR[rtM:rtL]];

// MEM Stage     
            if (EX_MEM_IR[typeM:typeL]==MEM_TYPE)
                begin
                    if (EX_MEM_IR[opM:opL]==LOAD) MEM_WB_LMD<=RAM[EX_MEM_IR[rtM:rsL]];
                    else if (EX_MEM_IR[opM:opL]==STORE) RAM[EX_MEM_IR[rtM:rsL]]<=EX_MEM_ALUOut;
                end 
            MEM_WB_ALUOut<=EX_MEM_ALUOut;
            MEM_WB_IR<=EX_MEM_IR;

        end 

    
endmodule 
