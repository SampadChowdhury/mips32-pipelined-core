// Five-stage MIPS32-subset pipeline with forwarding, interlocks, branch/jump
// flushing, a two-cycle MULADD extension, and readable performance counters.
module mips32_pipeline_core (
    input  logic        clk,
    input  logic        reset,

    output logic [31:0] imem_addr,
    input  logic [31:0] imem_read_data,

    output logic        dmem_write_enable,
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_write_data,
    input  logic [31:0] dmem_read_data,

    output logic [31:0] cycle_count,
    output logic [31:0] retired_count,
    output logic        pipeline_stall
);

    typedef struct packed {
        logic        valid;
        logic [31:0] pc_plus4;
        logic [31:0] instruction;
    } if_id_reg_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] pc_plus4;
        logic [31:0] rs_value;
        logic [31:0] rt_value;
        logic [31:0] immediate;
        logic [4:0]  rs;
        logic [4:0]  rt;
        logic [4:0]  destination;
        logic        perf_select;
        logic [2:0]  alu_control;
        logic        reg_write;
        logic        mem_write;
        logic        mem_to_reg;
        logic        alu_src_imm;
        logic        branch;
        logic        muladd;
        logic        perfmon;
    } id_ex_reg_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] alu_result;
        logic [31:0] store_data;
        logic [4:0]  destination;
        logic        perf_select;
        logic        reg_write;
        logic        mem_write;
        logic        mem_to_reg;
        logic        perfmon;
    } ex_mem_reg_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] alu_result;
        logic [31:0] memory_data;
        logic [4:0]  destination;
        logic        perf_select;
        logic        reg_write;
        logic        mem_to_reg;
        logic        perfmon;
    } mem_wb_reg_t;

    logic [31:0] pc_f;
    if_id_reg_t if_id;
    id_ex_reg_t id_ex;
    ex_mem_reg_t ex_mem;
    mem_wb_reg_t mem_wb;

    // Decode-stage fields and controls.
    logic [4:0] rs_d;
    logic [4:0] rt_d;
    logic [4:0] rd_d;
    logic [4:0] destination_d;
    logic [31:0] immediate_d;
    logic [31:0] reg_data_a_d;
    logic [31:0] reg_data_b_d;
    logic valid_d;
    logic use_rs_d;
    logic use_rt_d;
    logic reg_write_d;
    logic mem_write_d;
    logic mem_to_reg_d;
    logic alu_src_imm_d;
    logic branch_d;
    logic jump_control_d;
    logic muladd_d;
    logic perfmon_d;
    logic [2:0] alu_control_d;
    logic jump_d;
    logic [31:0] jump_target_d;

    // Hazard and forwarding controls.
    logic stall_d;
    logic [1:0] forward_a_e;
    logic [1:0] forward_b_e;
    logic late_result_e;
    logic late_result_m;

    // Execute-stage datapath.
    logic [31:0] forwarded_a_e;
    logic [31:0] forwarded_b_e;
    logic [31:0] alu_operand_b_e;
    logic [31:0] normal_alu_result_e;
    logic [31:0] execute_result_e;
    logic [31:0] branch_target_e;
    logic branch_taken_e;

    // MULADD executes multiplication in its first EX cycle and addition in its
    // second. The front of the pipeline is held for exactly the first cycle.
    logic muladd_busy;
    logic muladd_start;
    logic [31:0] muladd_product;
    logic [31:0] muladd_addend;
    logic stall_front;

    // Writeback signals.
    logic [31:0] writeback_result;
    logic writeback_enable;

    assign imem_addr = pc_f;
    assign rs_d = if_id.instruction[25:21];
    assign rt_d = if_id.instruction[20:16];
    assign rd_d = if_id.instruction[15:11];
    assign destination_d = (if_id.instruction[31:26] == 6'h00) ? rd_d : rt_d;
    assign immediate_d = {{16{if_id.instruction[15]}}, if_id.instruction[15:0]};

    control_unit decoder (
        .instruction(if_id.instruction),
        .valid(valid_d),
        .use_rs(use_rs_d),
        .use_rt(use_rt_d),
        .reg_write(reg_write_d),
        .mem_write(mem_write_d),
        .mem_to_reg(mem_to_reg_d),
        .alu_src_imm(alu_src_imm_d),
        .branch(branch_d),
        .jump(jump_control_d),
        .muladd(muladd_d),
        .perfmon(perfmon_d),
        .alu_control(alu_control_d)
    );

    assign jump_d = if_id.valid && valid_d && jump_control_d;
    assign jump_target_d = {if_id.pc_plus4[31:28], if_id.instruction[25:0], 2'b00};

    assign writeback_result = mem_wb.perfmon
        ? (mem_wb.perf_select ? retired_count : cycle_count)
        : (mem_wb.mem_to_reg ? mem_wb.memory_data : mem_wb.alu_result);
    assign writeback_enable = mem_wb.valid && mem_wb.reg_write;

    register_file registers (
        .clk(clk),
        .reset(reset),
        .write_enable(writeback_enable),
        .read_addr_a(rs_d),
        .read_addr_b(rt_d),
        .write_addr(mem_wb.destination),
        .write_data(writeback_result),
        .read_data_a(reg_data_a_d),
        .read_data_b(reg_data_b_d)
    );

    assign late_result_e = id_ex.mem_to_reg || id_ex.perfmon;
    assign late_result_m = ex_mem.mem_to_reg || ex_mem.perfmon;

    hazard_forward_unit hazards (
        .valid_d(if_id.valid && valid_d),
        .use_rs_d(use_rs_d),
        .use_rt_d(use_rt_d),
        .rs_d(rs_d),
        .rt_d(rt_d),
        .valid_e(id_ex.valid),
        .late_result_e(late_result_e),
        .reg_write_e(id_ex.reg_write),
        .write_reg_e(id_ex.destination),
        .rs_e(id_ex.rs),
        .rt_e(id_ex.rt),
        .valid_m(ex_mem.valid),
        .late_result_m(late_result_m),
        .reg_write_m(ex_mem.reg_write),
        .write_reg_m(ex_mem.destination),
        .valid_w(mem_wb.valid),
        .reg_write_w(mem_wb.reg_write),
        .write_reg_w(mem_wb.destination),
        .stall_d(stall_d),
        .forward_a_e(forward_a_e),
        .forward_b_e(forward_b_e)
    );

    // Plain combinational block keeps compatibility with Icarus releases that
    // conservatively warn about packed-struct member selects in always_comb.
    always @* begin
        case (forward_a_e)
            2'b10: forwarded_a_e = ex_mem.alu_result;
            2'b01: forwarded_a_e = writeback_result;
            default: forwarded_a_e = id_ex.rs_value;
        endcase

        case (forward_b_e)
            2'b10: forwarded_b_e = ex_mem.alu_result;
            2'b01: forwarded_b_e = writeback_result;
            default: forwarded_b_e = id_ex.rt_value;
        endcase
    end

    assign alu_operand_b_e = id_ex.alu_src_imm ? id_ex.immediate : forwarded_b_e;

    alu execute_alu (
        .operand_a(forwarded_a_e),
        .operand_b(alu_operand_b_e),
        .operation(id_ex.alu_control),
        .result(normal_alu_result_e)
    );

    assign muladd_start = id_ex.valid && id_ex.muladd && !muladd_busy;
    assign execute_result_e = muladd_busy
        ? (muladd_product + muladd_addend)
        : normal_alu_result_e;
    assign branch_target_e = id_ex.pc_plus4 + (id_ex.immediate << 2);
    assign branch_taken_e = id_ex.valid && id_ex.branch &&
                            (forwarded_a_e == forwarded_b_e);
    assign stall_front = stall_d || muladd_start;
    assign pipeline_stall = stall_front;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            muladd_busy <= 1'b0;
            muladd_product <= 32'b0;
            muladd_addend <= 32'b0;
        end else if (muladd_start) begin
            muladd_busy <= 1'b1;
            muladd_product <= forwarded_a_e * forwarded_b_e;
            muladd_addend <= forwarded_b_e;
        end else if (muladd_busy) begin
            muladd_busy <= 1'b0;
        end
    end

    // IF stage program counter. An older taken branch has priority over stalls
    // and decode-stage jumps.
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            pc_f <= 32'b0;
        else if (branch_taken_e)
            pc_f <= branch_target_e;
        else if (!stall_front)
            pc_f <= jump_d ? jump_target_d : (pc_f + 32'd4);
    end

    // IF/ID register: hold on an interlock and flush wrong-path instructions.
    always_ff @(posedge clk or posedge reset) begin
        if (reset || branch_taken_e || (jump_d && !stall_front)) begin
            if_id <= '0;
        end else if (!stall_front) begin
            if_id.valid <= 1'b1;
            if_id.pc_plus4 <= pc_f + 32'd4;
            if_id.instruction <= imem_read_data;
        end
    end

    // ID/EX register: late-result hazards inject a bubble; the first MULADD
    // cycle holds its instruction so the second cycle retains its metadata.
    always_ff @(posedge clk or posedge reset) begin
        if (reset || branch_taken_e || stall_d) begin
            id_ex <= '0;
        end else if (!muladd_start) begin
            id_ex.valid <= if_id.valid && valid_d;
            id_ex.pc_plus4 <= if_id.pc_plus4;
            id_ex.rs_value <= reg_data_a_d;
            id_ex.rt_value <= reg_data_b_d;
            id_ex.immediate <= immediate_d;
            id_ex.rs <= rs_d;
            id_ex.rt <= rt_d;
            id_ex.destination <= destination_d;
            id_ex.perf_select <= if_id.instruction[6];
            id_ex.alu_control <= alu_control_d;
            id_ex.reg_write <= reg_write_d;
            id_ex.mem_write <= mem_write_d;
            id_ex.mem_to_reg <= mem_to_reg_d;
            id_ex.alu_src_imm <= alu_src_imm_d;
            id_ex.branch <= branch_d;
            id_ex.muladd <= muladd_d;
            id_ex.perfmon <= perfmon_d;
        end
    end

    // EX/MEM register. The multiplication cycle inserts a bubble; the second
    // MULADD cycle emits the completed result like a normal ALU operation.
    always_ff @(posedge clk or posedge reset) begin
        if (reset || muladd_start) begin
            ex_mem <= '0;
        end else begin
            ex_mem.valid <= id_ex.valid;
            ex_mem.alu_result <= execute_result_e;
            ex_mem.store_data <= forwarded_b_e;
            ex_mem.destination <= id_ex.destination;
            ex_mem.perf_select <= id_ex.perf_select;
            ex_mem.reg_write <= id_ex.reg_write;
            ex_mem.mem_write <= id_ex.mem_write;
            ex_mem.mem_to_reg <= id_ex.mem_to_reg;
            ex_mem.perfmon <= id_ex.perfmon;
        end
    end

    assign dmem_write_enable = ex_mem.valid && ex_mem.mem_write;
    assign dmem_addr = ex_mem.alu_result;
    assign dmem_write_data = ex_mem.store_data;

    // MEM/WB register captures asynchronous memory read data for writeback.
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_wb <= '0;
        end else begin
            mem_wb.valid <= ex_mem.valid;
            mem_wb.alu_result <= ex_mem.alu_result;
            mem_wb.memory_data <= dmem_read_data;
            mem_wb.destination <= ex_mem.destination;
            mem_wb.perf_select <= ex_mem.perf_select;
            mem_wb.reg_write <= ex_mem.reg_write;
            mem_wb.mem_to_reg <= ex_mem.mem_to_reg;
            mem_wb.perfmon <= ex_mem.perfmon;
        end
    end

    performance_counters counters (
        .clk(clk),
        .reset(reset),
        .retire_valid(mem_wb.valid),
        .cycle_count(cycle_count),
        .retired_count(retired_count)
    );

endmodule
