/*
 * hwpe_ctrl_regfile_parity.sv
 * Maurus Item <itemm@student.ethz.ch>
 *
 * Copyright (C) 2024 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * Module that checks for even parity on a regfile, output delayed to not end up in critcal path.
 */

module hwpe_ctrl_regfile_parity
  import hwpe_ctrl_package::*;
#(
  int unsigned N_IO_REGS,
  int unsigned N_GENERIC_REGS
)(
  input logic                              clk_i,
  input logic                              rst_ni,
  input  hwpe_ctrl_package::ctrl_regfile_t reg_file_i,
  output logic                             fault_detected_o
);

  // Build an even XOR tree per register
  parameter int XOR_INPUTS = N_IO_REGS + N_GENERIC_REGS + 1;
  parameter int XOR_OPS    = XOR_INPUTS - 1; // Always one less than inputs e.g. x + y -> 2 Addends 1 Addition
  parameter int TREE_NODES = XOR_OPS + XOR_INPUTS;

  // Array of addresses for tree adder
  logic [TREE_NODES-1:0][31:0] xor_intermediate;

  // Assign Input Nodes
  for (genvar i = 0; i < N_IO_REGS; i++) begin: gen_hwpe_params_assign
      assign xor_intermediate[XOR_OPS + i] = reg_file_i.hwpe_params[i];
  end

  for (genvar i = 0; i < N_GENERIC_REGS ; i++) begin: gen_generic_params_assign
      assign xor_intermediate[XOR_OPS + N_IO_REGS + i] = reg_file_i.generic_params[i];
  end

  assign xor_intermediate[XOR_OPS + N_IO_REGS + N_GENERIC_REGS] = reg_file_i.ext_data;

  // Calculate XOR in a Tree
  for (genvar i = 0; i < XOR_OPS; i++)
  begin: gen_adder_tree
    assign xor_intermediate[i] = xor_intermediate[i * 2 + 1] ^ xor_intermediate[i * 2 + 2];
  end

  // Take output of tree and OR Bits -> One register should be set in a way so each bit XORs to 0.
  logic fault_detected;
  assign fault_detected = |xor_intermediate[0];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      fault_detected_o <= '0;
    end else begin
      fault_detected_o <= fault_detected;
    end
  end

endmodule: hwpe_ctrl_regfile_parity
