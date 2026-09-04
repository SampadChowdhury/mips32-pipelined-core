// Combinational 32-bit ALU for the supported MIPS instruction subset.
module alu (
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic [2:0]  operation,
    output logic [31:0] result
);

    localparam logic [2:0] ALU_AND = 3'b000;
    localparam logic [2:0] ALU_OR  = 3'b001;
    localparam logic [2:0] ALU_ADD = 3'b010;
    localparam logic [2:0] ALU_SUB = 3'b110;
    localparam logic [2:0] ALU_SLT = 3'b111;

    always_comb begin
        case (operation)
            ALU_AND: result = operand_a & operand_b;
            ALU_OR:  result = operand_a | operand_b;
            ALU_ADD: result = operand_a + operand_b;
            ALU_SUB: result = operand_a - operand_b;
            ALU_SLT: result = {31'b0, $signed(operand_a) < $signed(operand_b)};
            default: result = 32'b0;
        endcase
    end

endmodule
