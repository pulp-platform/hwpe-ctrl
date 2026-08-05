// Copyright 2025-2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

/*
 * hwpe_ctrl_target_wrap.sv
 * Francesco Conti <f.conti@unibo.it>
 *
 * Copyright (C) 2025-2026 ETH Zurich, University of Bologna
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
 * Integration wrapper binding hwpe_ctrl_target to the PeakRDL-generated
 * hwpe_ctrl_regif_example register block (rtl/rdl-example/, produced by
 * `make regif` from rtl/hwpe_ctrl_regif_example.rdl -- see that file for the
 * authoritative register map). This is the same pattern as
 * redmule_target_decoder.sv in the RedMulE repository: 1) plug the
 * SystemRDL-generated types into hwpe_ctrl_target's parametric
 * hwpe_ctrl_regif_*_t / hwpe_ctrl_job_*_t parameters; 2) wire the 11-signal
 * cpuif "passthrough" bundle straight through between hwpe_ctrl_target and
 * the regblock; 3) plug hwif_in/hwif_out through, overriding only the one
 * hwif_in leaf (hw_status) that is driven from outside the generated
 * register file (job_indep_hw_status_i, exercising the hw->sw status path).
 */

module hwpe_ctrl_target_wrap
  import hwpe_ctrl_package::*;
  import hwpe_ctrl_regif_example_pkg::*;
#(
  parameter int unsigned NB_CONTEXT      = 2,
  parameter int unsigned NB_CLEAR_CYCLES = 3
)
(
  input  logic                 clk_i,
  input  logic                 rst_ni,
  output logic                 clear_o,

  // peripheral interconnect side (register-mapped access from the TB)
  hwpe_ctrl_intf_periph.slave  target,

  // job triggering, completion & status
  output logic                 job_trigger_o,
  input  logic                 job_done_i,
  input  logic [31:0]          job_status_i,

  // TB-driven value for the hw_status job-indep leaf (hw=w, sw=r)
  input  logic [31:0]          job_indep_hw_status_i,

  // job-independent registers (config_a, config_b, hw_status)
  output hwpe_ctrl_regif_example__hwpe_ctrl_job_indep__out_t job_indep_regs_o,

  // job-dependent registers (param0, param1, param2)
  output logic                                              job_dep_regs_valid_o,
  output hwpe_ctrl_regif_example__hwpe_ctrl_job_dep__out_t  job_dep_regs_o
);

  // cpuif plug target <-> regif (PeakRDL "passthrough")
  logic        target_cpuif_req;
  logic        target_cpuif_req_is_wr;
  logic [31:0] target_cpuif_addr;
  logic [31:0] target_cpuif_wr_data;
  logic [31:0] target_cpuif_wr_biten;
  logic        target_cpuif_req_stall_wr;
  logic        target_cpuif_req_stall_rd;
  logic        target_cpuif_rd_ack;
  logic        target_cpuif_rd_err;
  logic [31:0] target_cpuif_rd_data;
  logic        target_cpuif_wr_ack;
  logic        target_cpuif_wr_err;

  hwpe_ctrl_regif_example__in_t  hwif_in_target;
  hwpe_ctrl_regif_example__in_t  hwif_in;
  hwpe_ctrl_regif_example__out_t hwif_out;

  hwpe_ctrl_target #(
    .NB_CONTEXT            ( NB_CONTEXT                                          ),
    .NB_CLEAR_CYCLES       ( NB_CLEAR_CYCLES                                     ),
    .ID_WIDTH              ( 2                                                   ),
    .ADDR_WIDTH            ( 8                                                   ),
    .hwpe_ctrl_regif_in_t  ( hwpe_ctrl_regif_example__in_t                       ),
    .hwpe_ctrl_regif_out_t ( hwpe_ctrl_regif_example__out_t                      ),
    .hwpe_ctrl_job_indep_t ( hwpe_ctrl_regif_example__hwpe_ctrl_job_indep__out_t ),
    .hwpe_ctrl_job_dep_t   ( hwpe_ctrl_regif_example__hwpe_ctrl_job_dep__out_t   )
  ) i_target (
    .clk_i                        ( clk_i                     ),
    .rst_ni                       ( rst_ni                    ),
    .clear_o                      ( clear_o                   ),
    .target                       ( target                    ),
    .job_trigger_o                ( job_trigger_o             ),
    .job_done_i                   ( job_done_i                ),
    .job_status_i                 ( job_status_i              ),
    .job_indep_regs_o             ( job_indep_regs_o          ),
    .job_dep_regs_valid_o         ( job_dep_regs_valid_o      ),
    .job_dep_regs_o               ( job_dep_regs_o            ),
    .target_cpuif_req_o           ( target_cpuif_req          ),
    .target_cpuif_req_is_wr_o     ( target_cpuif_req_is_wr    ),
    .target_cpuif_addr_o          ( target_cpuif_addr         ),
    .target_cpuif_wr_data_o       ( target_cpuif_wr_data      ),
    .target_cpuif_wr_biten_o      ( target_cpuif_wr_biten     ),
    .target_cpuif_req_stall_wr_i  ( target_cpuif_req_stall_wr ),
    .target_cpuif_req_stall_rd_i  ( target_cpuif_req_stall_rd ),
    .target_cpuif_rd_ack_i        ( target_cpuif_rd_ack       ),
    .target_cpuif_rd_err_i        ( target_cpuif_rd_err       ),
    .target_cpuif_rd_data_i       ( target_cpuif_rd_data      ),
    .target_cpuif_wr_ack_i        ( target_cpuif_wr_ack       ),
    .target_cpuif_wr_err_i        ( target_cpuif_wr_err       ),
    .hwif_in                      ( hwif_in_target            ),
    .hwif_out                     ( hwif_out                  )
  );

  hwpe_ctrl_regif_example i_regif (
    .clk                  ( clk_i                     ),
    .arst_n               ( rst_ni                    ),
    .s_cpuif_req          ( target_cpuif_req          ),
    .s_cpuif_req_is_wr    ( target_cpuif_req_is_wr    ),
    .s_cpuif_addr         ( target_cpuif_addr         ),
    .s_cpuif_wr_data      ( target_cpuif_wr_data      ),
    .s_cpuif_wr_biten     ( target_cpuif_wr_biten     ),
    .s_cpuif_req_stall_wr ( target_cpuif_req_stall_wr ),
    .s_cpuif_req_stall_rd ( target_cpuif_req_stall_rd ),
    .s_cpuif_rd_ack       ( target_cpuif_rd_ack       ),
    .s_cpuif_rd_err       ( target_cpuif_rd_err       ),
    .s_cpuif_rd_data      ( target_cpuif_rd_data      ),
    .s_cpuif_wr_ack       ( target_cpuif_wr_ack       ),
    .s_cpuif_wr_err       ( target_cpuif_wr_err       ),
    .hwif_in              ( hwif_in                   ),
    .hwif_out             ( hwif_out                  )
  );

  // Copy hwif_in from hwpe_ctrl_target verbatim, overriding only the
  // hw_status leaf (driven from outside the generated register file) --
  // mirrors redmule_target_decoder.sv's hwif_in override for op_id_cnt.
  always_comb begin
    hwif_in = hwif_in_target;
    hwif_in.hwpe_job_indep.hw_status.value.next = job_indep_hw_status_i;
  end

endmodule // hwpe_ctrl_target_wrap
