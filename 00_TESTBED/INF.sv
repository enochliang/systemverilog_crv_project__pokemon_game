`ifndef INF_SV
`define INF_SV
//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2021 ICLAB Fall Course
//   Lab09      : PSG (Pokemon Strategy Game)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : INF.sv
//   Release version : v1.0
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//`include "Usertype_PKG.sv"

interface INF(input logic clk);
import usertype::*;

// ============================================================
//  Pattern  →  DUT  (input signals driven by PATTERN)
// ============================================================

// Reset
logic       rst_n;

// Valid strobes (one-hot each cycle)
logic       id_valid;
logic       act_valid;
logic       item_valid;
logic       type_valid;
logic       amnt_valid;

// Data bus (union)
DATA        D;

// ============================================================
//  DUT  →  Pattern / Checker  (output signals from pokemon)
// ============================================================

logic       out_valid;
logic       complete;
Error_Msg   err_msg;
Player_Info out_info;

// ============================================================
//  pokemon  ↔  bridge  (internal channel)
// ============================================================

// pokemon → bridge
logic        C_in_valid;
logic        C_r_wb;       // 1 = read, 0 = write
logic [7:0]  C_addr;
logic [63:0] C_data_w;

// bridge → pokemon
logic        C_out_valid;
logic [63:0] C_data_r;

// ============================================================
//  bridge  ↔  pseudo_DRAM  (AXI4-Lite-like)
// ============================================================

// --- Read address channel ---
logic        AR_VALID;
logic        AR_READY;
logic [16:0] AR_ADDR;

// --- Read data channel ---
logic        R_VALID;
logic        R_READY;
logic [63:0] R_DATA;
logic [1:0]  R_RESP;

// --- Write address channel ---
logic        AW_VALID;
logic        AW_READY;
logic [16:0] AW_ADDR;

// --- Write data channel ---
logic        W_VALID;
logic        W_READY;
logic [63:0] W_DATA;

// --- Write response channel ---
logic        B_VALID;
logic        B_READY;
logic [1:0]  B_RESP;

// ============================================================
//  Modports
// ============================================================

modport PATTERN (
    input  clk,
    output rst_n,
    output id_valid,
    output act_valid,
    output item_valid,
    output type_valid,
    output amnt_valid,
    output D,
    input  out_valid,
    input  complete,
    input  err_msg,
    input  out_info
);

modport pokemon_inf (
    input  clk,
    input  rst_n,
    input  id_valid,
    input  act_valid,
    input  item_valid,
    input  type_valid,
    input  amnt_valid,
    input  D,
    output out_valid,
    output complete,
    output err_msg,
    output out_info,
    // bridge channel
    output C_in_valid,
    output C_r_wb,
    output C_addr,
    output C_data_w,
    input  C_out_valid,
    input  C_data_r
);

modport bridge_inf (
    input  clk,
    input  rst_n,
    // pokemon channel
    input  C_in_valid,
    input  C_r_wb,
    input  C_addr,
    input  C_data_w,
    output C_out_valid,
    output C_data_r,
    // DRAM AXI channel
    output AR_VALID,
    input  AR_READY,
    output AR_ADDR,
    input  R_VALID,
    output R_READY,
    input  R_DATA,
    input  R_RESP,
    output AW_VALID,
    input  AW_READY,
    output AW_ADDR,
    output W_VALID,
    input  W_READY,
    output W_DATA,
    input  B_VALID,
    output B_READY,
    input  B_RESP
);

modport CHECKER (
    input  clk,
    input  rst_n,
    input  id_valid,
    input  act_valid,
    input  item_valid,
    input  type_valid,
    input  amnt_valid,
    input  D,
    input  out_valid,
    input  complete,
    input  err_msg,
    input  out_info
);

modport DRAM_inf (
    input  clk,
    input  rst_n,
    // Read address channel
    input  AR_VALID,
    output AR_READY,
    input  AR_ADDR,
    // Read data channel
    output R_VALID,
    input  R_READY,
    output R_DATA,
    output R_RESP,
    // Write address channel
    input  AW_VALID,
    output AW_READY,
    input  AW_ADDR,
    // Write data channel
    input  W_VALID,
    output W_READY,
    input  W_DATA,
    // Write response channel
    output B_VALID,
    input  B_READY,
    output B_RESP
);

endinterface

`endif // INF_SV
