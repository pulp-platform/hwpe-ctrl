/*
 * hwpe_ctrl_interfaces.sv
 * Francesco Conti <f.conti@unibo.it>
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
 */

interface hwpe_ctrl_intf_periph (
  input logic clk
);

  parameter int unsigned ID_WIDTH = -1;

  logic                req;
  logic                gnt;
  logic [31:0]         add;
  logic                wen;
  logic [3:0]          be;
  logic [31:0]         data;
  logic [ID_WIDTH-1:0] id;
  logic [31:0]         r_data;
  logic                r_valid;
  logic [ID_WIDTH-1:0] r_id;

  modport master (
    output req, add, wen, be, data, id,
    input  gnt, r_data, r_valid, r_id
  );
  modport slave (
    input  req, add, wen, be, data, id,
    output gnt, r_data, r_valid, r_id
  );

endinterface // hwpe_ctrl_intf_periph
