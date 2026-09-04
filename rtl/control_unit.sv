// Decoder for a compact MIPS32 subset plus MULADD and PERFMON extensions.
module control_unit (
    input  logic [31:0] instruction,
    output logic        valid,
    output logic        use_rs,
    output logic        use_rt,
    output logic        reg_write,
    output logic        mem_write,
    output logic        mem_to_reg,
    output logic        alu_src_imm,
    output logic        branch,
    output logic        jump,
    output logic        muladd,
    output logic        perfmon,
    output logic [2:0]  alu_control
);

    localparam logic [2:0] ALU_AND = 3'b000;
    localparam logic [2:0] ALU_OR  = 3'b001;
    localparam logic [2:0] ALU_ADD = 3'b010;
    localparam logic [2:0] ALU_SUB = 3'b110;
    localparam logic [2:0] ALU_SLT = 3'b111;

    logic [5:0] opcode;
    logic [5:0] funct;

    assign opcode = instruction[31:26];
    assign funct = instruction[5:0];

    always_comb begin
        valid = 1'b0;
        use_rs = 1'b0;
        use_rt = 1'b0;
        reg_write = 1'b0;
        mem_write = 1'b0;
        mem_to_reg = 1'b0;
        alu_src_imm = 1'b0;
        branch = 1'b0;
        jump = 1'b0;
        muladd = 1'b0;
        perfmon = 1'b0;
        alu_control = ALU_ADD;

        case (opcode)
            6'h00: begin
                case (funct)
                    6'h20: begin // ADD
                        valid = 1'b1; use_rs = 1'b1; use_rt = 1'b1;
                        reg_write = 1'b1; alu_control = ALU_ADD;
                    end
                    6'h22: begin // SUB
                        valid = 1'b1; use_rs = 1'b1; use_rt = 1'b1;
                        reg_write = 1'b1; alu_control = ALU_SUB;
                    end
                    6'h24: begin // AND
                        valid = 1'b1; use_rs = 1'b1; use_rt = 1'b1;
                        reg_write = 1'b1; alu_control = ALU_AND;
                    end
                    6'h25: begin // OR
                        valid = 1'b1; use_rs = 1'b1; use_rt = 1'b1;
                        reg_write = 1'b1; alu_control = ALU_OR;
                    end
                    6'h2a: begin // SLT
                        valid = 1'b1; use_rs = 1'b1; use_rt = 1'b1;
                        reg_write = 1'b1; alu_control = ALU_SLT;
                    end
                    6'h08: begin // MULADD rd = (rs * rt) + rt
                        valid = 1'b1; use_rs = 1'b1; use_rt = 1'b1;
                        reg_write = 1'b1; muladd = 1'b1;
                    end
                    6'h0f: begin // PERFMON: shamt[0] selects retired/cycle count
                        valid = 1'b1; reg_write = 1'b1; perfmon = 1'b1;
                    end
                    default: begin end
                endcase
            end
            6'h08: begin // ADDI
                valid = 1'b1; use_rs = 1'b1; reg_write = 1'b1;
                alu_src_imm = 1'b1; alu_control = ALU_ADD;
            end
            6'h23: begin // LW
                valid = 1'b1; use_rs = 1'b1; reg_write = 1'b1;
                mem_to_reg = 1'b1; alu_src_imm = 1'b1; alu_control = ALU_ADD;
            end
            6'h2b: begin // SW
                valid = 1'b1; use_rs = 1'b1; use_rt = 1'b1;
                mem_write = 1'b1; alu_src_imm = 1'b1; alu_control = ALU_ADD;
            end
            6'h04: begin // BEQ
                valid = 1'b1; use_rs = 1'b1; use_rt = 1'b1;
                branch = 1'b1; alu_control = ALU_SUB;
            end
            6'h02: begin // J
                valid = 1'b1; jump = 1'b1;
            end
            default: begin end
        endcase
    end

endmodule
