// Detects late-result hazards in decode and selects EX-stage forwarding paths.
module hazard_forward_unit (
    input  logic       valid_d,
    input  logic       use_rs_d,
    input  logic       use_rt_d,
    input  logic [4:0] rs_d,
    input  logic [4:0] rt_d,
    input  logic       valid_e,
    input  logic       late_result_e,
    input  logic       reg_write_e,
    input  logic [4:0] write_reg_e,
    input  logic [4:0] rs_e,
    input  logic [4:0] rt_e,
    input  logic       valid_m,
    input  logic       late_result_m,
    input  logic       reg_write_m,
    input  logic [4:0] write_reg_m,
    input  logic       valid_w,
    input  logic       reg_write_w,
    input  logic [4:0] write_reg_w,
    output logic       stall_d,
    output logic [1:0] forward_a_e,
    output logic [1:0] forward_b_e
);

    always_comb begin
        stall_d = valid_d && valid_e && late_result_e && reg_write_e &&
                  (write_reg_e != 5'b0) &&
                  ((use_rs_d && (rs_d == write_reg_e)) ||
                   (use_rt_d && (rt_d == write_reg_e)));

        forward_a_e = 2'b00;
        if (valid_m && reg_write_m && !late_result_m &&
            (write_reg_m != 5'b0) && (write_reg_m == rs_e))
            forward_a_e = 2'b10;
        else if (valid_w && reg_write_w &&
                 (write_reg_w != 5'b0) && (write_reg_w == rs_e))
            forward_a_e = 2'b01;

        forward_b_e = 2'b00;
        if (valid_m && reg_write_m && !late_result_m &&
            (write_reg_m != 5'b0) && (write_reg_m == rt_e))
            forward_b_e = 2'b10;
        else if (valid_w && reg_write_w &&
                 (write_reg_w != 5'b0) && (write_reg_w == rt_e))
            forward_b_e = 2'b01;
    end

endmodule
