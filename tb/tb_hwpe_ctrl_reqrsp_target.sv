/* 
 * tb_hwpe_ctrl_seq_mult.sv
 * Francesco Conti <f.conti@unibo.it>
 *
 * Copyright (C) 2023 ETH Zurich, University of Bologna
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

module tb_hwpe_ctrl_reqrsp_target
  import hwpe_ctrl_package::*;;

  // ATI timing parameters.
  localparam TCP = 1.0ns; // clock period, 1GHz clock
  localparam TA  = 0.2ns; // application time
  localparam TT  = 0.8ns; // test time

  logic clk_i = '0;
  logic rst_ni = '1;
  logic clear_o;
    
  // typedef struct packed {
  //   logic [31:0] q_addr;
  //   logic        q_write;
  //   logic [63:0] q_data;
  //   logic        q_valid;
  //   logic        p_ready;
  // } reqrsp_req_t;
  // typedef struct packed {
  //   logic [63:0] p_data;
  //   logic        p_valid;
  //   logic        q_ready;
  // } reqrsp_rsp_t;

  parameter int unsigned HWPE_CTRL_REQRSP_TRIGGER = 0;
  parameter int unsigned HWPE_CTRL_REQRSP_STATUS  = 1;
  parameter int unsigned HWPE_CTRL_REQRSP_JOBID   = 2;
  parameter int unsigned HWPE_CTRL_REQRSP_SOFTCLR = 3;
  parameter int unsigned HWPE_CTRL_REQRSP_PUSH    = 4;
  parameter int unsigned HWPE_CTRL_REQRSP_PULL    = 5;

  hwpe_ctrl_intf_reqrsp #(
    .AW (32),
    .DW (64)
  ) cfg (
    .clk ( clk_i )
  );
  // reqrsp_req_t cfg_req_i;
  // reqrsp_rsp_t cfg_rsp_o;
  ctrl_slave_t   ctrl_i;
  flags_slave_t  flags_o;
  ctrl_regfile_t reg_file;

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
    while(1) begin
      cycle();
    end
  end

  task reqrsp_reset();
    #(TA);
    cfg.q_addr = '0;
    cfg.q_data = '0;
    cfg.q_write = '0;
    cfg.q_valid = '0;
    cfg.p_ready = '0;
    cfg.q_strb = '0;
    #(TCP-TA);
  endtask

  task reqrsp_write(
    input logic [31:0] w_add,
    input logic [63:0] w_data
  );
    #(TA);
    cfg.q_addr = w_add;
    cfg.q_data = w_data;
    cfg.q_write = 1'b1;
    cfg.q_valid = 1'b1;
    cfg.q_strb = '1;
    while (cfg.q_ready != 1'b1)
      #(TCP);
    #(TCP);
    cfg.q_valid = 1'b0;
    cfg.q_strb = '0;
    #(TCP-TA);
  endtask

  task reqrsp_read(
    input  logic [31:0] r_add,
    output logic [63:0] rdata,
    input  int          ready_delay
  );
    #(TA);
    cfg.q_addr = r_add;
    cfg.q_write = 1'b0;
    cfg.q_valid = 1'b1;
    while (cfg.q_ready != 1'b1)
      #(TCP);
    #(TCP);
    cfg.q_valid = 1'b0;
    for(int i=0; i<ready_delay; i+=1)
      #(TCP);
    cfg.p_ready = 1'b1;
    while (cfg.p_valid != 1'b1)
      #(TCP);
    #(TCP-TA);
    rdata = cfg.p_data;
    #(TA);
    cfg.p_ready = 1'b0;
    #(TCP-TA);
  endtask


  logic [63:0] rdata;
  initial begin
    reqrsp_reset();
    ctrl_i = '0;
    #(50*TCP);
    // SOFT CLEAR (all but regfile)
    reqrsp_write({HWPE_CTRL_REQRSP_SOFTCLR, 2'b0}, 1);
    #(5*TCP);
    // SOFT CLEAR (all)
    reqrsp_write({HWPE_CTRL_REQRSP_SOFTCLR, 2'b0}, 0);
    #(5*TCP);
    // STATUS (must be 0)
    reqrsp_read({HWPE_CTRL_REQRSP_STATUS, 2'b0}, rdata, 0);
    #(5*TCP);
    // JOBID (must be 0)
    reqrsp_read({HWPE_CTRL_REQRSP_JOBID, 2'b0}, rdata, 0);
    #(5*TCP);
    // PUSH x 3
    reqrsp_write({HWPE_CTRL_REQRSP_PUSH, 2'b0}, 64'h12345678_9ABCDEF0);
    #(TCP);
    reqrsp_write({HWPE_CTRL_REQRSP_PUSH, 2'b0}, 64'hDEADBEEF_0BADF00D);
    #(TCP);
    reqrsp_write({HWPE_CTRL_REQRSP_PUSH, 2'b0}, 64'h01234567_FEDCBA98);
    #(5*TCP);
    // PULL x 3
    reqrsp_read({HWPE_CTRL_REQRSP_PULL, 2'b0}, rdata, 2);
    #(TCP);
    reqrsp_read({HWPE_CTRL_REQRSP_PULL, 2'b0}, rdata, 2);
    #(TCP);
    reqrsp_read({HWPE_CTRL_REQRSP_PULL, 2'b0}, rdata, 2);
    #(5*TCP);
    // TRIGGER
    reqrsp_write({HWPE_CTRL_REQRSP_TRIGGER, 2'b0}, 0);
    #(5*TCP);
    // STATUS (must be 1)
    reqrsp_read({HWPE_CTRL_REQRSP_STATUS, 2'b0}, rdata, 4);
    #(5*TCP);
    // JOBID (must be 1)
    reqrsp_read({HWPE_CTRL_REQRSP_JOBID, 2'b0}, rdata, 10);
    #(5*TCP);
    ctrl_i.done = 1'b1;
    #(TCP);
    ctrl_i.done = 1'b0;
    #(TCP);
    // STATUS (must be 0)
    reqrsp_read({HWPE_CTRL_REQRSP_STATUS, 2'b0}, rdata, 0);
    // SOFT CLEAR (all)
    reqrsp_write({HWPE_CTRL_REQRSP_SOFTCLR, 2'b0}, 0);
  end

  hwpe_ctrl_reqrsp_target #(
    .NB_CTRL_REGISTER ( 6            ),
    .NB_REGISTER      ( 4            ),
    .N_IO_REGS        ( 8            )
  ) i_target (
    .clk_i         ( clk_i   ),
    .rst_ni        ( rst_ni  ),
    .clear_o       ( clear_o ),
    .cfg           ( cfg     ),
    .ctrl_i        (ctrl_i   ),
    .flags_o       (flags_o  ),
    .reg_file      (reg_file )
  );

endmodule // tb_hwpe_ctrl_seq_mult
