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

`ifndef SYNTHESIS
timeunit 1ps;
timeprecision 1ps;
`endif

interface hwpe_ctrl_intf_periph (
  input logic clk
);

  parameter  int unsigned AddrWidth = -1;
  parameter  int unsigned DataWidth = -1;
  parameter  int unsigned ID_WIDTH  = -1;
  localparam int unsigned BeWidth   = DataWidth/8;

  logic                 req;
  logic                 gnt;
  logic [AddrWidth-1:0] add;
  logic                 wen;
  logic [BeWidth-1:0]   be;
  logic [DataWidth-1:0] data;
  logic [ID_WIDTH-1:0]  id;
  logic [DataWidth-1:0] r_data;
  logic                 r_valid;
  logic [ID_WIDTH-1:0]  r_id;

  modport master (
    output req,
    output add,
    output wen,
    output be,
    output data,
    output id,
    input  gnt,
    input  r_data,
    input  r_valid,
    input  r_id
  );
  modport slave (
    input  req,
    input  add,
    input  wen,
    input  be,
    input  data,
    input  id,
    output gnt,
    output r_data,
    output r_valid,
    output r_id
  );

endinterface // hwpe_ctrl_intf_periph

interface hwpe_ctrl_intf_reqrsp (
  input logic clk
);

  parameter int unsigned AW = -1;
  parameter int unsigned DW = -1;

  // Q (request) channel
  logic [AW-1:0]   q_addr;
  logic            q_write;
  logic [DW/8-1:0] q_strb;
  logic [DW-1:0]   q_data;
  // Q (request) handshake
  logic            q_valid;
  logic            q_ready;

  // P (response) channel
  logic [DW-1:0]   p_data;
  // P (response) handshake
  logic            p_valid;
  logic            p_ready;

  modport initiator (
    output q_addr, q_write, q_strb, q_data, q_valid, p_ready,
    input  p_data, p_valid, q_ready
  );
  modport target (
    input  q_addr, q_write, q_strb, q_data, q_valid, p_ready,
    output p_data, p_valid, q_ready
  );

endinterface // hwpe_ctrl_intf_reqrsp
