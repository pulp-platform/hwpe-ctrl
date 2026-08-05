// Copyright 2025-2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

/*
 * hwpe_ctrl_seq_mult_tb_wrap.sv
 * Francesco Conti <f.conti@unibo.it>
 *
 * Copyright (C) 2014-2026 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */

/*
 * Portless verilator top for the hwpe_ctrl_seq_mult testbench (see
 * target/sim/verilator/verilator.mk: --top-module hwpe_ctrl_seq_mult_tb_wrap).
 * Being portless is what makes `verilator --binary --top-module` work
 * directly, mirroring hwpe_ctrl_target_tb_wrap.sv and
 * hwpe_ctrl_partial_mult_tb_wrap.sv.
 */

timeunit 1ps;
timeprecision 1ps;

module hwpe_ctrl_seq_mult_tb_wrap
#(
  parameter int unsigned AW = 8,
  parameter int unsigned BW = 8
);

  // ATI timing parameters.
  localparam time TCP = 1.0ns; // clock period, 1 GHz clock
  localparam time TA  = 0.2ns; // application time
  localparam time TT  = 0.8ns; // test time

  logic clk_i;
  logic rst_ni;

  hwpe_ctrl_seq_mult_tb #(
    .TCP ( TCP ),
    .TA  ( TA  ),
    .TT  ( TT  ),
    .AW  ( AW  ),
    .BW  ( BW  )
  ) i_tb (
    .clk_i  ( clk_i  ),
    .rst_ni ( rst_ni )
  );

  // Performs one entire clock cycle.
  task automatic cycle;
    clk_i <= #(TCP/2) 1'b0;
    clk_i <= #TCP 1'b1;
    #TCP;
  endtask

  // Free-running clock/reset generation process. hwpe_ctrl_seq_mult_tb (and
  // the driver tasks within it) synchronize to clk_i/rst_ni via
  // @(posedge clk_i); the actual test scenario runs there and calls
  // $finish itself once done -- this process just keeps the clock alive
  // for as long as the simulation runs.
  initial begin
    clk_i  <= 1'b0;
    rst_ni <= 1'b0;

    for (int i = 0; i < 20; i++) cycle();

    rst_ni <= #TA 1'b1;

    while (1) cycle();
  end

endmodule // hwpe_ctrl_seq_mult_tb_wrap
