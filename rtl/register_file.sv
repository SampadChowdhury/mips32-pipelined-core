// Two-read, one-write register file. Register zero is hardwired to zero.
module register_file (
    input  logic        clk,
    input  logic        reset,
    input  logic        write_enable,
    input  logic [4:0]  read_addr_a,
    input  logic [4:0]  read_addr_b,
    input  logic [4:0]  write_addr,
    input  logic [31:0] write_data,
    output logic [31:0] read_data_a,
    output logic [31:0] read_data_b
);

    logic [31:0] registers [0:31];
    integer index;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (index = 1; index < 32; index = index + 1)
                registers[index] <= 32'b0;
        end else if (write_enable && (write_addr != 5'b0)) begin
            registers[write_addr] <= write_data;
        end
    end

    assign read_data_a = (read_addr_a == 5'b0) ? 32'b0 : registers[read_addr_a];
    assign read_data_b = (read_addr_b == 5'b0) ? 32'b0 : registers[read_addr_b];

endmodule
