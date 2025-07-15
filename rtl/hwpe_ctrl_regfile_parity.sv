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
 * Module that checks for bitwise even parity on a regfile for all dwords.
 * Output delayed to not end up in critcal path.
 *
 * You should have one dedicated "parity register", to use this module where
 * you place a XOR Signature dword (16 bits) to achieve parity. Where in the 
 * register file this is is up to your implementation. You can use the other 
 * half for something else, sensible would be additional parity information.
 *
 * |=======================================================================|
 * || # reg |  offset  |  bits   |   bitmask    ||  content               ||
 * ||-------+----------+---------+--------------++------------------------||
 * ||-------+----------+---------+--------------++------------------------||
 * ||  ANY  |    ANY   |         |              ||  PARITY_REGISTER:      ||
 * ||       |          |  31:16  |  0xFFFF0000  ||  PARITY_INFORMATION    ||
 * ||       |          |  15: 0  |  0x0000FFFF  ||  XOR_SIGNATURE         ||
 * |=======================================================================|
 * 
 * The signature should be the XOR of all dwords in the regfile e.g.:
 * XOR_SIGNATURE = PARITY_INFORMATION ^ REGISTER_1[15:0] ^ REGISTER_1[31:16] ^ REGISTER_2[15:0] ^ REGISTER_2[31:16] ... 
 * 
 * You can use the following c-code to calculate it:
 * 
 * uint_32t parity_register; // Final value in register
 * uint_16t parity_info;     // Your additional info in here
 * 
 * // Collect all other registers
 * uint_32t xor_signature = 0; // Temp variable to collect all parity info
 * xor_signature ^= register_1;
 * xor_signature ^= register_2;
 *  .... 
 * 
 * parity_register = (xor_signature ^ ((xor_signature ^ parity_info) << 16)) & 0xFFFF0000 | parity_info & 0x0000FFFF
 * 
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
  assign fault_detected = |(xor_intermediate[0][31:16] ^ xor_intermediate[0][15:0]);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      fault_detected_o <= '0;
    end else begin
      fault_detected_o <= fault_detected;
    end
  end

endmodule: hwpe_ctrl_regfile_parity
