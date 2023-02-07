/*
 * hwpe_ctrl_reqrsp_interface.sv
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
 *
 * This is a very minimal interface thought for Snitch-based systems:
 *  - reqrsp interface
 *  - single context & single coupled core
 *  - push/pull programming
 */

module hwpe_ctrl_reqrsp_interface
  import hwpe_ctrl_package::*;
#(
  parameter int unsigned NB_CTRL_REGISTER = 6,
  parameter int unsigned NB_REGISTER      = 16,
  parameter int unsigned N_IO_REGS        = 2, // compatibility
  parameter int unsigned N_GENERIC_REGS   = 0, // compatibility
  parameter int unsigned REGISTER_WIDTH   = 64,
  parameter int unsigned N_EVT            = REGFILE_N_EVT,
  parameter int unsigned N_SW_EVT         = 8,
  parameter type reqrsp_req_t = logic,
  parameter type reqrsp_rsp_t = logic
)
(
  input  logic          clk_i,
  input  logic          rst_ni,
  output logic          clear_o,

  // req-rsp controller
  input  reqrsp_req_t   cfg_req_i,
  output reqrsp_rsp_t   cfg_rsp_o,

  input  ctrl_slave_t   ctrl_i,
  output flags_slave_t  flags_o,
  output ctrl_regfile_t reg_file
);

  parameter int unsigned HWPE_CTRL_REQRSP_TRIGGER = 0;
  parameter int unsigned HWPE_CTRL_REQRSP_STATUS  = 1;
  parameter int unsigned HWPE_CTRL_REQRSP_JOBID   = 2;
  parameter int unsigned HWPE_CTRL_REQRSP_SOFTCLR = 3;
  parameter int unsigned HWPE_CTRL_REQRSP_PUSH    = 4;
  parameter int unsigned HWPE_CTRL_REQRSP_PULL    = 5;

  typedef enum { IDLE, RUN } reqrsp_interface_state_t;
  reqrsp_interface_state_t state_d, state_q;

  reqrsp_rsp_t cfg_rsp_d, cfg_rsp_q;

  logic job_id_update_d, job_id_update_q;
  logic [15:0] job_id_d, job_id_q;

  logic [NB_REGISTER-1:0][REGISTER_WIDTH-1:0] register_file;
  logic [2:0] ctrl_reg_d;
  logic [$clog2(NB_REGISTER)-1:0] pull_cnt_d, pull_cnt_q;
  logic [$clog2(NB_REGISTER)-1:0] push_cnt_d, push_cnt_q;

  logic [1:0] soft_clear_cnt_d, soft_clear_cnt_q;
  logic [1:0] soft_clear_reg_cnt_d, soft_clear_reg_cnt_q;
  logic soft_clear_s;
  logic soft_clear_reg_s;
  
  logic done_q;

  // selected control register is given by addr bits [4:2] (masked with valid)
  assign ctrl_reg_d = cfg_req_i.q_valid ? cfg_req_i.q_addr[4:2] : '0;

  // FSM
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : state_seq_p
    if(~rst_ni) begin
      state_q <= IDLE;
    end
    else if(soft_clear_s) begin
      state_q <= IDLE;
    end
    else begin
      state_q <= state_d;
    end
  end  
  always_comb
  begin : state_comb_p
    state_d = state_q;
    job_id_update_d = '0;
    case(state_q)
      IDLE: begin
        if ((cfg_req_i.q_valid & cfg_req_i.q_write) && ctrl_reg_d == HWPE_CTRL_REQRSP_TRIGGER) begin
          state_d = RUN;
          job_id_update_d = 1'b1;
        end
      end
      RUN: begin
        if (ctrl_i.done) begin
          state_d = IDLE;
        end
      end
    endcase
  end

  // register file itself
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : register_file_p
    if(~rst_ni) begin
      register_file <= '0;
    end
    else if(soft_clear_reg_s) begin
      register_file <= '0;
    end
    else if(cfg_req_i.q_valid & cfg_req_i.q_write & cfg_rsp_o.q_ready) begin
      register_file[push_cnt_q] <= cfg_req_i.q_data;
    end
  end

  // response interface
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : reqrsp_response_p
    if(~rst_ni) begin
      cfg_rsp_q <= '0;
    end
    else if(soft_clear_s) begin
      cfg_rsp_q <= '0;
    end
    else if(cfg_req_i.q_valid | cfg_req_i.p_ready) begin
      cfg_rsp_q <= cfg_rsp_d;
    end
  end
  assign cfg_rsp_d.q_ready = '1;
  // respond with data to STATUS, JOBID, PULL requests, else with '0 (but keeping the valid bit)
  assign cfg_rsp_d.p_data = (cfg_req_i.q_valid & ~cfg_req_i.q_write) ? (
    ctrl_reg_d == HWPE_CTRL_REQRSP_STATUS ? (state_q == RUN ? 1 : 0) :
    ctrl_reg_d == HWPE_CTRL_REQRSP_JOBID  ? job_id_q :
    ctrl_reg_d == HWPE_CTRL_REQRSP_PULL   ? register_file[pull_cnt_q] : '0
  ) : '0;
  assign cfg_rsp_d.p_valid = (cfg_req_i.q_valid & ~cfg_req_i.q_write) ? 1'b1 : '0;

  // interface is always ready, response comes from reqrsp_response_p
  assign cfg_rsp_o = cfg_rsp_q;

  // push counter
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : push_cnt_p
    if(~rst_ni) begin
      push_cnt_q <= '0;
    end
    else if(soft_clear_s) begin
      push_cnt_q <= '0;
    end
    else begin
      push_cnt_q <= push_cnt_d;
    end
  end
  assign push_cnt_d = (cfg_req_i.q_valid & cfg_req_i.q_write) && ctrl_reg_d == HWPE_CTRL_REQRSP_PUSH ? (push_cnt_q == NB_REGISTER-1 ? '0 : push_cnt_q + 1) : push_cnt_q;

  // pull counter
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : pull_cnt_p
    if(~rst_ni) begin
      pull_cnt_q <= '0;
    end
    else if(soft_clear_s) begin
      pull_cnt_q <= '0;
    end
    else begin
      pull_cnt_q <= pull_cnt_d;
    end
  end
  assign pull_cnt_d = (cfg_req_i.q_valid & ~cfg_req_i.q_write) && ctrl_reg_d == HWPE_CTRL_REQRSP_PULL ? (pull_cnt_q == NB_REGISTER-1 ? '0 : pull_cnt_q + 1) : pull_cnt_q;

  // job id counter
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : job_id_p
    if(~rst_ni) begin
      job_id_q <= '0;
    end
    else if(soft_clear_s) begin
      job_id_q <= '0;
    end
    else if(job_id_update_d) begin
      job_id_q <= job_id_d;
    end
  end
  assign job_id_d = job_id_q + 1;
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : job_id_update_p
    if(~rst_ni) begin
      job_id_update_q <= '0;
    end
    else if(soft_clear_s) begin
      job_id_update_q <= '0;
    end
    else begin
      job_id_update_q <= job_id_update_d;
    end
  end

  // clear generation (full clear)
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : soft_clear_p
    if(~rst_ni) begin
      soft_clear_cnt_q <= '0;
    end
    else if(soft_clear_cnt_q != '0 || ((cfg_req_i.q_valid & cfg_req_i.q_write) && ctrl_reg_d == HWPE_CTRL_REQRSP_SOFTCLR && cfg_req_i.q_data == '0)) begin
      soft_clear_cnt_q <= soft_clear_cnt_d;
    end
  end
  assign soft_clear_cnt_d = soft_clear_cnt_q + 1;
  assign soft_clear_s = |(soft_clear_cnt_q);
  assign clear_o = soft_clear_s;

  // clear generation (regfile clear - when data is 0)
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : soft_clear_reg_p
    if(~rst_ni) begin
      soft_clear_reg_cnt_q <= '0;
    end
    else if(soft_clear_reg_cnt_q != '0 || ((cfg_req_i.q_valid & cfg_req_i.q_write) && ctrl_reg_d == HWPE_CTRL_REQRSP_SOFTCLR && cfg_req_i.q_data != '0)) begin
      soft_clear_reg_cnt_q <= soft_clear_reg_cnt_d;
    end
  end
  assign soft_clear_reg_cnt_d = soft_clear_reg_cnt_q + 1;
  assign soft_clear_reg_s = |(soft_clear_reg_cnt_q) | soft_clear_s;

  // flags generation
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : done_p
    if(~rst_ni) begin
      done_q <= '0;
    end
    else if(soft_clear_s) begin
      done_q <= '0;
    end
    else begin
      done_q <= ctrl_i.done;
    end
  end
  assign flags_o.start      = job_id_update_q;
  assign flags_o.evt        = '0; // unused in Snitch systems
  assign flags_o.done       = done_q;
  assign flags_o.is_working = state_q == RUN ? 1'b1 : 1'b0;
  assign flags_o.enable     = state_q == RUN ? 1'b1 : 1'b0;
  assign flags_o.sw_evt     = '0; // unused in Snitch systems
  assign flags_o.ext_id     = '0; // unused in Snitch systems
  assign flags_o.ext_we     = '0; // unused in Snitch systems
  assign flags_o.ext_re     = '0; // unused in Snitch systems

  // regfile export
  localparam N_GENERIC_REGS_EVEN = N_GENERIC_REGS % 2 != 0 ? N_GENERIC_REGS+1 : N_GENERIC_REGS;
  localparam N_IO_REGS_EVEN      = N_IO_REGS % 2 != 0      ? N_IO_REGS+1      : N_IO_REGS;
  for(genvar ii=0; ii<N_GENERIC_REGS_EVEN; ii+=1) begin
    assign reg_file.generic_params[ii] = register_file[ii/2][(ii%2)*32+31:(ii%2)*32];
  end
  for(genvar ii=N_GENERIC_REGS_EVEN; ii<N_GENERIC_REGS_EVEN+N_IO_REGS_EVEN; ii+=1) begin
    assign reg_file.hwpe_params[ii-N_GENERIC_REGS_EVEN] = register_file[ii/2][(ii%2)*32+31:(ii%2)*32];
  end

endmodule
