/*
 * hwpe_ctrl_target.sv
 * Francesco Conti <f.conti@unibo.it>
 *
 * Copyright (C) 2014-2025 ETH Zurich, University of Bologna
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
  * This module exposes a hwpe_ctrl_intf_periph target (slave) port like the
  * deprecated `hwpe_ctrl_slave`. However, it differs from the previous module
  * in that it exploits SystemRDL to generate a register file interface.
  * This module must be coupled with a register interface generated out of 
  * a SystemRDL description. This repository contains a reference SystemRDL
  * `hwpe_ctrl_regif_example.rdl` and a `rdl.sh` script to generate the register
  * interface with PeakRDL. HWPEs must internalize this and modify the content to
  * align with their required set of job-independent and job-dependent registers,
  * without modifying the mandatory registers.
  * Then, the `hwpe_ctrl_target` can be integrated by 1) overriding the parametric
  * types; 2) plugging the OBI interface signals; 3) plugging `hwif_in` and
  * `hwif_out`.
  */

module hwpe_ctrl_target
  import hwpe_ctrl_package::*;
#(
  parameter int unsigned NB_CONTEXT      = 2,
  parameter int unsigned NB_CLEAR_CYCLES = 3,
  parameter int unsigned ID_WIDTH        = 2,
  parameter int unsigned ADDR_WIDTH      = 16,
  parameter type hwpe_ctrl_regif_in_t  = logic, // must be overridden!
  parameter type hwpe_ctrl_regif_out_t = logic, // must be overridden!
  parameter type hwpe_ctrl_job_indep_t = logic, // must be overridden!
  parameter type hwpe_ctrl_job_dep_t   = logic  // must be overridden!
)
(
  input  logic                 clk_i,
  input  logic                 rst_ni,
  output logic                 clear_o,

  // peripheral interconnect side
  hwpe_ctrl_intf_periph.slave  target,

  // job triggering completion & status
  output logic                 job_trigger_o,
  input  logic                 job_done_i,
  input  logic [31:0]          job_status_i,

  // job-independent registers
  output hwpe_ctrl_job_indep_t job_indep_regs_o,

  // job-dependent registers
  output logic                 job_dep_regs_valid_o,
  output hwpe_ctrl_job_dep_t   job_dep_regs_o,

  // OBI interface to target SystemRDL-generated register interface
  output logic                 target_obi_req_o,
  input  logic                 target_obi_gnt_i,
  output logic [31:0]          target_obi_addr_o,
  output logic                 target_obi_we_o,
  output logic [3:0]           target_obi_be_o,
  output logic [31:0]          target_obi_wdata_o,
  output logic [ID_WIDTH-1:0]  target_obi_aid_o,
  input  logic                 target_obi_rvalid_i,
  output logic                 target_obi_rready_o,
  input  logic [31:0]          target_obi_rdata_i,
  input  logic                 target_obi_err_i,
  input  logic [ID_WIDTH-1:0]  target_obi_rid_i,

  // wrap -> register interface signals
  output hwpe_ctrl_regif_in_t  hwif_in,

  // register interface -> wrap signals
  input  hwpe_ctrl_regif_out_t hwif_out
);

  // unroll periph interconnect signals into OBI
  assign target_obi_req_o    =  target.req;
  assign target.gnt          =  target_obi_gnt_i;
  assign target_obi_addr_o   = {{(32-ADDR_WIDTH){1'b0}} , target.add[ADDR_WIDTH-1:0]};
  assign target_obi_we_o     = ~target.wen;
  assign target_obi_be_o     =  target.be;
  assign target_obi_wdata_o  =  target.data;
  assign target_obi_aid_o    =  target.id;
  assign target.r_data       =  target_obi_rdata_i;
  assign target.r_valid      =  target_obi_rvalid_i;
  assign target.r_id         =  target_obi_rid_i;
  assign target_obi_rready_o =  '1;

  // error codes for job offload
  localparam logic [31:0] HWPE_CTRL_JOB_QUEUE_FULL_ERR_CODE = 32'hffff_ffff;
  localparam logic [31:0] HWPE_CTRL_JOB_ACQUIRED_ERR_CODE   = 32'hffff_fffe;

  // state of job offload procedure
  typedef enum logic { IDLE, ACQUIRE } job_offload_state_t;
  job_offload_state_t job_offload_state_d, job_offload_state_q;

  // current and next job ID
  logic [7:0] job_id_d, job_id_q;

  // job commit signal
  logic job_commit;

  // job queue control signals
  logic job_fifo_full, job_fifo_empty;

  // internal clear signals
  logic                       soft_clear_regfile_d, soft_clear_state_d;
  logic [NB_CLEAR_CYCLES-1:0] soft_clear_regfile_q, soft_clear_state_q;
  logic                       soft_clear_regfile_en, soft_clear_state_en;

  // SOFT_CLEAR register:
  // clear regfile if SOFT_CLEAR[0] is 0, clear state if SOFT_CLEAR[1] is 0
  assign soft_clear_regfile_d = hwif_out.hwpe_ctrl.soft_clear.soft_clear.swacc & ~hwif_out.hwpe_ctrl.soft_clear.soft_clear.value[0];
  assign soft_clear_state_d   = hwif_out.hwpe_ctrl.soft_clear.soft_clear.swacc & ~hwif_out.hwpe_ctrl.soft_clear.soft_clear.value[1];

  // generate clear enables
  assign soft_clear_regfile_en = soft_clear_regfile_d | (|soft_clear_regfile_q);
  assign soft_clear_state_en   = soft_clear_state_d   | (|soft_clear_state_q);

  // activate clear for NB_CLEAR_CYCLES cycles in case of a SOFT_CLEAR write
  always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if(~rst_ni) begin
      soft_clear_regfile_q <= '0;
    end
    else if(soft_clear_regfile_en) begin
      soft_clear_regfile_q[0] <= soft_clear_regfile_d;
      for(int i=1; i<NB_CLEAR_CYCLES; i++) begin
        soft_clear_regfile_q[i] <= soft_clear_regfile_q[i-1];
      end
    end
  end
  always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if(~rst_ni) begin
      soft_clear_state_q <= '0;
    end
    else if(soft_clear_state_en) begin
      soft_clear_state_q[0] <= soft_clear_state_d;
      for(int i=1; i<NB_CLEAR_CYCLES; i++) begin
        soft_clear_state_q[i] <= soft_clear_state_q[i-1];
      end
    end
  end

  // propagate the soft_clear_state everywhere
  assign clear_o = |soft_clear_state_q;

  // COMMIT_TRIGGER register:
  // Commit a job in the job queue if COMMIT_TRIGGER[0] is 1'b0. Trigger the job queue execution if COMMIT_TRIGGER[1] is 1'b0.
  assign job_commit    = hwif_out.hwpe_ctrl.commit_trigger.commit_trigger.swacc & ~hwif_out.hwpe_ctrl.commit_trigger.commit_trigger.value[0];
  assign job_trigger_o = hwif_out.hwpe_ctrl.commit_trigger.commit_trigger.swacc & ~hwif_out.hwpe_ctrl.commit_trigger.commit_trigger.value[1];

  // ACQUIRE register:
  // 1. if in ACQUIRE state, respond to any new reads with error code (-2)
  // 2. if job_fifo_full, respond with error code (-1)
  // 3. else, return the next job ID
  assign hwif_in.hwpe_ctrl.acquire.acquire.next = job_offload_state_q == ACQUIRE ? HWPE_CTRL_JOB_ACQUIRED_ERR_CODE   :
                                                  job_fifo_full                  ? HWPE_CTRL_JOB_QUEUE_FULL_ERR_CODE :
                                                                                   { 24'h0 , job_id_d };
  always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if(~rst_ni) begin
      job_id_q <= '1;
    end
    else if(|soft_clear_regfile_q) begin
      job_id_q <= '1;
    end
    else if(job_done_i) begin
      job_id_q <= job_id_d;
    end
  end
  assign job_id_d = job_id_q + 1;

  // enable state change on ACQUIRE / COMMIT_TRIGGER register access
  logic job_offload_state_en;
  assign job_offload_state_en = hwif_out.hwpe_ctrl.acquire.acquire.swacc | job_commit;
  
  // update state (cleared together with register file)
  assign job_offload_state_d = hwif_out.hwpe_ctrl.acquire.acquire.swacc & ~job_fifo_full ? ACQUIRE :
                               job_commit                                                ? IDLE    :
                                                                                           job_offload_state_q;
  always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if(~rst_ni) begin
      job_offload_state_q <= IDLE;
    end
    else if(|soft_clear_regfile_q) begin
      job_offload_state_q <= IDLE;
    end
    else if(job_offload_state_en) begin
      job_offload_state_q <= job_offload_state_d;
    end
  end

  // STATUS register:
  // propagate status defined externally
  assign hwif_in.hwpe_ctrl.status.status0.next = job_status_i;

  // RUNNING_JOB register:
  // return the current job ID
  assign hwif_in.hwpe_ctrl.running_job.running_job.next = job_id_q;

  // queue for incoming jobs
  fifo_v3 #(
    .FALL_THROUGH ( 0                   ),
    .DEPTH        ( NB_CONTEXT          ),
    .dtype        ( hwpe_ctrl_job_dep_t )
  ) i_job_fifo (
    .clk_i      ( clk_i                 ),
    .rst_ni     ( rst_ni                ),
    .flush_i    ( |soft_clear_regfile_q ),
    .testmode_i ( '0                    ),
    .full_o     ( job_fifo_full         ),
    .empty_o    ( job_fifo_empty        ),
    .usage_o    (                       ),
    .data_i     ( hwif_out.hwpe_job_dep ),
    .push_i     ( job_commit            ),
    .data_o     ( job_dep_regs_o        ),
    .pop_i      ( job_done_i            )
  );
  assign job_dep_regs_valid_o = ~job_fifo_empty;

  // job-independent registers
  assign job_indep_regs_o = hwif_out.hwpe_job_indep;

endmodule // hwpe_ctrl_target
