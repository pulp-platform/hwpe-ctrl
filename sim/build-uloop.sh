#!/bin/bash
vlib hwpe_ctrl_lib
vmap hwpe_ctrl_lib hwpe_ctrl_lib
vlog -work hwpe_ctrl_lib +nowarnSVCHK -suppress 2275 -suppress 2583 -suppress 13314 ../rtl/hwpe_ctrl_package.sv ../rtl/hwpe_ctrl_uloop.sv ../tb/tb_hwpe_ctrl_uloop.sv
vopt +acc=mnpr -o vopt_tb_hwpe_ctrl_uloop tb_hwpe_ctrl_uloop -work hwpe_ctrl_lib

