// Copyright 2019 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

/*
 * hwpe_ctrl_uloop_tb_wrap.sv
 * Francesco Conti <f.conti@unibo.it>
 *
 * Copyright (C) 2019-2026 ETH Zurich, University of Bologna
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
 * Portless verilator top for the hwpe_ctrl_uloop testbench (see
 * target/sim/verilator/verilator.mk: --top-module hwpe_ctrl_uloop_tb_wrap).
 * Being portless is what makes `verilator --binary --top-module` work
 * directly, mirroring hwpe_ctrl_target_tb_wrap.sv.
 *
 * The clock/reset sequence below reproduces the legacy
 * tb/tb_hwpe_ctrl_uloop.sv clock/reset `initial` (its lines 97-117)
 * verbatim: settle, assert reset, deassert, run 10 cycles, briefly
 * re-assert reset for 10 more cycles, deassert again, then free-run.
 * That file was portless too and generated its own clk_i/rst_ni in the
 * same module as the test; here that responsibility is split out into
 * this dedicated top, with hwpe_ctrl_uloop_tb driven via ports.
 */

timeunit 1ps;
timeprecision 1ps;

module hwpe_ctrl_uloop_tb_wrap;

  // ATI timing parameters.
  localparam time TCP = 1.0ns; // clock period, 1 GHz clock
  localparam time TA  = 0.2ns; // application time
  localparam time TT  = 0.8ns; // test time

  logic clk_i = '0;
  logic rst_ni = '1;

  hwpe_ctrl_uloop_tb #(
    .TCP ( TCP ),
    .TA  ( TA  ),
    .TT  ( TT  )
  ) i_tb (
    .clk_i  ( clk_i  ),
    .rst_ni ( rst_ni )
  );

  // Performs one entire clock cycle.
  task automatic cycle;
    clk_i <= #(TCP/2) 0;
    clk_i <= #TCP 1;
    #TCP;
  endtask

  // clock/reset gen process
  initial begin
    #(20*TCP);

    // Reset phase.
    rst_ni <= #TA 1'b0;
    #(20*TCP);
    rst_ni <= #TA 1'b1;

    for (int i = 0; i < 10; i++)
      cycle();
    rst_ni <= #TA 1'b0;
    for (int i = 0; i < 10; i++)
      cycle();
    rst_ni <= #TA 1'b1;

    while (1) begin
      cycle();
    end
  end

endmodule // hwpe_ctrl_uloop_tb_wrap
