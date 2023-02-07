#!/bin/bash
vlib hwpe_ctrl_lib
vmap hwpe_ctrl_lib hwpe_ctrl_lib
vlog -work hwpe_ctrl_lib +nowarnSVCHK -suppress 2275 -suppress 2583 -suppress 13314 ../rtl/hwpe_ctrl_package.sv ../rtl/hwpe_ctrl_interfaces.sv ../rtl/hwpe_ctrl_reqrsp_target.sv ../tb/tb_hwpe_ctrl_reqrsp_target.sv
vopt +acc=npr -o vopt_tb_hwpe_ctrl_reqrsp_target tb_hwpe_ctrl_reqrsp_target -work hwpe_ctrl_lib


