# Portable Design Compiler setup for the processor core only.
# Set PDK_DIR to the directory containing gscl45nm.db before running dc_shell.

set rtl_files [list \
    ../rtl/alu.sv \
    ../rtl/control_unit.sv \
    ../rtl/hazard_forward_unit.sv \
    ../rtl/performance_counters.sv \
    ../rtl/register_file.sv \
    ../rtl/mips32_pipeline_core.sv]

set top_module mips32_pipeline_core
set clock_period_ns 2.0
set io_delay_ns 0.1

set pdk_dir [getenv PDK_DIR]
if {$pdk_dir eq ""} {
    error "PDK_DIR must point to the directory containing gscl45nm.db"
}

set search_path [concat $search_path [list $pdk_dir]]
set target_library [list gscl45nm.db]
set link_library [concat "*" $target_library [list dw_foundation.sldb]]

define_design_lib WORK -path ./WORK
analyze -format sverilog $rtl_files
elaborate $top_module
current_design $top_module
link
uniquify

create_clock -name clk -period $clock_period_ns [get_ports clk]
set_input_delay $io_delay_ns -clock clk \
    [remove_from_collection [all_inputs] [get_ports {clk reset}]]
set_output_delay $io_delay_ns -clock clk [all_outputs]
set_false_path -from [get_ports reset]

compile_ultra
check_design
report_constraint -all_violators

file mkdir reports
redirect reports/timing.rpt {report_timing -max_paths 10}
redirect reports/area.rpt {report_area -hierarchy}
redirect reports/power.rpt {report_power}

write -format ddc -hierarchy -output reports/mips32_pipeline_core.ddc
write_sdc reports/mips32_pipeline_core.sdc
quit
