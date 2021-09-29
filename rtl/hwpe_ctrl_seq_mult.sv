/* 
 * hwpe_ctrl_seq_mult.sv
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 *
 * Copyright (C) 2014-2018 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * A fully sequential unsigned multiplier. Inputs must
 * be kept stable for AW-1 cycles after the start strobe.
 */


module hwpe_ctrl_seq_mult
  import hwpe_ctrl_package::*;
#(
  parameter int unsigned AW = 8,
  parameter int unsigned BW = 8
)
(
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             clear_i,
  input  logic             start_i,
  input  logic [AW-1:0]    a_i,
  input  logic [BW-1:0]    b_i,
  input  logic             invert_i,
  output logic             valid_o,
  output logic             ready_o,
  output logic [AW+BW-1:0] prod_o
);

  logic [$clog2(AW+1)-1:0] cnt;
  logic [AW+BW-1:0] shifted;
  logic valid_q, ready_q;

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : counter
    if(~rst_ni) begin
      cnt <= '0;
      valid_q <= '0;
      ready_q <= 1'b1;
    end
    else if(clear_i) begin
      cnt <= '0;
      valid_q <= '0;
      ready_q <= 1'b1;
    end
    else if((~invert_i && cnt == AW - 1) || (invert_i && cnt == AW)) begin
      cnt <= 0;
      valid_q <= 1'b1;
      ready_q <= 1'b1;
    end
    else if((start_i==1'b1) || (cnt>0)) begin
      cnt <= cnt + 1;
      valid_q <= 1'b0;
      ready_q <= 1'b0;
    end
  end
  assign valid_o = valid_q;
  assign ready_o = ready_q;

  assign shifted = cnt==AW ? 1 : ({BW{a_i[cnt]}} & b_i) << cnt;

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : product
    if(~rst_ni) begin
      prod_o <= '0;
    end
    else if(clear_i) begin
      prod_o <= '0;
    end
    else if (start_i) begin
      prod_o <= shifted;
    end
    else if(cnt==AW) begin
      prod_o <= ~prod_o + shifted;
    end
    else if(cnt>0) begin
      prod_o <= prod_o + shifted;
    end
  end

endmodule /* hwpe_ctrl_seq_mult */
