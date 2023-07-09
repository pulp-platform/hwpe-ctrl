// Copyright (c) 2020 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`define HWPE_CTRL_ASSIGN_TO_INTF(intf, reqst, rspns)\
  assign intf.req    = reqst.req;                   \
  assign intf.add    = reqst.add;                   \
  assign intf.wen    = reqst.wen;                   \
  assign intf.data   = reqst.data;                  \
  assign intf.be     = reqst.be;                    \
  assign intf.id     = reqst.id;                    \
  assign rspns.gnt     = intf.gnt;                  \
  assign rspns.r_data  = intf.r_data;               \
  assign rspns.r_valid = intf.r_valid;              \
  assign rspns.r_id    = intf.r_id;

`define HWPE_CTRL_ASSIGN_FROM_INTF(intf, reqst, rspns)\
  assign reqst.req      = intf.req;                   \
  assign reqst.add      = intf.add;                   \
  assign reqst.wen      = intf.wen;                   \
  assign reqst.data     = intf.data;                  \
  assign reqst.be       = intf.be;                    \
  assign reqst.id       = intf.id;                    \
  assign intf.gnt     = rspns.gnt;                    \
  assign intf.r_data  = rspns.r_data;                 \
  assign intf.r_valid = rspns.r_valid;                \
  assign intf.r_id    = rspns.r_id;
