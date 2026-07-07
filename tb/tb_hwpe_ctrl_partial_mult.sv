/* 
 * tb_hwpe_ctrl_partial_mult.sv
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

timeunit 1ns;
timeprecision 1ps;

module tb_hwpe_ctrl_partial_mult;

  localparam VERBOSE = 1;
  localparam AW = 32;
  localparam BW = 32;
  localparam MULT_BITS = 4;
  localparam NUM_TRANSACTIONS = 10000;

  logic clk_i = '0;
  logic rst_ni = '1;

  logic [AW-1:0] a;
  logic [BW-1:0] b;
  logic [AW+BW-1:0] prod;
  logic valid;
  logic ready;
  logic start;
  logic invert;

  // ATI timing parameters.
  localparam TCP = 1.0ns; // clock period, 1GHz clock
  localparam TA  = 0.2ns; // application time
  localparam TT  = 0.8ns; // test time

  // Performs one entire clock cycle.
  task cycle;
    clk_i <= #(TCP/2) 1'b0;
    clk_i <= #TCP 1'b1;
    #TCP;
  endtask

  initial begin
    #(20*TCP);
    // Reset phase.
    for (int i = 0; i < 10; i++)
      cycle();
    rst_ni <= #TA 1'b0;
    for (int i = 0; i < 10; i++)
      cycle();
    rst_ni <= #TA 1'b1;
    for (int t = 0; t < NUM_TRANSACTIONS; t++) begin
      a <= #TA $random();
      b <= #TA $random();
      invert <= #TA $urandom_range(0,1);
      start <= #TA 1'b1;
      cycle();
      start <= #TA 1'b0;
      for(int i=0; i<(AW/MULT_BITS + (AW % MULT_BITS ? 1 : 0)); i++)
        cycle();
    end
    $finish;
  end

  hwpe_ctrl_partial_mult #(
    .AW        ( AW        ),
    .BW        ( BW        ),
    .MULT_BITS ( MULT_BITS )
  ) ctrl_seq_mult_i (
    .clk_i   ( clk_i  ),
    .rst_ni  ( rst_ni ),
    .clear_i ( 1'b0   ),
    .start_i ( start  ),
    .a_i     ( a      ),
    .b_i     ( b      ),
    .invert_i ( invert ),
    .valid_o ( valid  ),
    .ready_o ( ready  ),
    .prod_o  ( prod   )
  );

  always_ff @(posedge clk_i) begin
    if(valid & ~start & rst_ni & VERBOSE)
      $display("prod %016x = %08x * %08x\n", prod, a, b);
  end

  assert property (@(posedge clk_i) (valid & ~start & rst_ni) |->
    (prod == (invert ? -((AW+BW)'(a) * b) : (AW+BW)'(a) * b)))
    else $fatal("Wrong multiplication data produced!!!");

endmodule // tb_hwpe_ctrl_seq_mult
