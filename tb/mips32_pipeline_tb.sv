`timescale 1ns/1ps

// End-to-end architectural test for forwarding, a load-use stall, taken-branch
// flushing, two-cycle MULADD, PERFMON reads, stores, and jump control.
module mips32_pipeline_tb;

    logic clk;
    logic reset;
    logic [31:0] imem_addr;
    logic [31:0] imem_read_data;
    logic dmem_write_enable;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_write_data;
    logic [31:0] dmem_read_data;
    logic [31:0] cycle_count;
    logic [31:0] retired_count;
    logic pipeline_stall;

    logic [31:0] instruction_memory [0:63];
    logic [31:0] data_memory [0:63];
    integer imem_index;
    integer dmem_index;
    integer store_count;
    integer stall_count;

    mips32_pipeline_core dut (.*);

    assign imem_read_data = instruction_memory[imem_addr[7:2]];
    assign dmem_read_data = data_memory[dmem_addr[7:2]];

    initial begin
        for (imem_index = 0; imem_index < 64; imem_index = imem_index + 1)
            instruction_memory[imem_index] = 32'b0;
        $readmemh("programs/demo.hex", instruction_memory);
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            for (dmem_index = 0; dmem_index < 64; dmem_index = dmem_index + 1)
                data_memory[dmem_index] <= 32'b0;
            store_count <= 0;
            stall_count <= 0;
        end else begin
            if (pipeline_stall)
                stall_count <= stall_count + 1;

            if (dmem_write_enable) begin
                data_memory[dmem_addr[7:2]] <= dmem_write_data;
                store_count <= store_count + 1;

                case (dmem_addr)
                    32'd0:  if (dmem_write_data !== 32'd30)
                        $fatal(1, "Forwarded ADD result incorrect: %0d", dmem_write_data);
                    32'd4:  if (dmem_write_data !== 32'd220)
                        $fatal(1, "MULADD result incorrect: %0d", dmem_write_data);
                    32'd8:  if (dmem_write_data !== 32'd230)
                        $fatal(1, "Post-MULADD forwarding incorrect: %0d", dmem_write_data);
                    32'd12: if (dmem_write_data !== 32'd40)
                        $fatal(1, "Load-use result incorrect: %0d", dmem_write_data);
                    32'd16: if (dmem_write_data !== 32'd0)
                        $fatal(1, "Taken-branch instructions were not flushed: %0d", dmem_write_data);
                    32'd20: if (dmem_write_data == 32'd0)
                        $fatal(1, "Cycle counter snapshot must be nonzero");
                    32'd24: if (dmem_write_data == 32'd0)
                        $fatal(1, "Retired counter snapshot must be nonzero");
                    default: $fatal(1, "Unexpected store address %0d", dmem_addr);
                endcase
            end
        end
    end

    initial begin
        reset = 1'b1;
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        wait (store_count == 7);
        @(negedge clk);

        if (data_memory[5] <= data_memory[6])
            $fatal(1, "Expected cycle snapshot (%0d) > retired snapshot (%0d)",
                   data_memory[5], data_memory[6]);
        if (stall_count < 2)
            $fatal(1, "Expected load-use and MULADD stalls, observed %0d", stall_count);

        $display("PASS: pipeline, hazards, MULADD, PERFMON, branch, and jump behavior verified");
        $display("      cycle snapshot=%0d retired snapshot=%0d stalls=%0d",
                 data_memory[5], data_memory[6], stall_count);
        $finish;
    end

    initial begin
        $dumpfile("mips32_pipeline.vcd");
        $dumpvars(0, mips32_pipeline_tb);
        #5000 $fatal(1, "Simulation timeout");
    end

endmodule
