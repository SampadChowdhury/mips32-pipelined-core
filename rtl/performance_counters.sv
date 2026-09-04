// Architectural cycle and retirement counters used by the PERFMON instruction.
module performance_counters (
    input  logic        clk,
    input  logic        reset,
    input  logic        retire_valid,
    output logic [31:0] cycle_count,
    output logic [31:0] retired_count
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle_count <= 32'b0;
            retired_count <= 32'b0;
        end else begin
            cycle_count <= cycle_count + 1'b1;
            if (retire_valid)
                retired_count <= retired_count + 1'b1;
        end
    end

endmodule
