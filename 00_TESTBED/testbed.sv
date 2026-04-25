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
//   File Name   : testbed.sv
//   Module Name : testbed
//   Release version : v1.0
//
//   Description : Top-level simulation testbench.
//                 Instantiates: PATTERN, pokemon (DUT), bridge, pseudo_DRAM,
//                 and Checker, wired through the INF interface.
//
//   IMPORTANT: Do NOT `include any .sv files here.
//              All files are compiled once via filelist.f / run_sim.sh.
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`timescale 1ns/100ps

module testbed;

// ============================================================
//  Clock generation  (10ns period → 100MHz)
// ============================================================
parameter CYCLE = 10.0;

logic clk;
initial clk = 0;
always #(CYCLE/2.0) clk = ~clk;

logic [15:0] debug_D;
assign debug_D = inf.D;
logic [63:0] debug_out_info;
assign debug_out_info = inf.out_info;

initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, testbed);   // 0 = 全層遞迴 dump
    $fsdbDumpSVA(0, testbed);    // dump assertion pass/fail（可選）
end

// ============================================================
//  Interface
// ============================================================
INF inf(.clk(clk));

// ============================================================
//  DUT : pokemon
// ============================================================
pokemon u_pokemon(
    .clk(clk),
    .inf(inf.pokemon_inf)
);

// ============================================================
//  Bridge
// ============================================================
bridge u_bridge(
    .clk(clk),
    .inf(inf.bridge_inf)
);

// ============================================================
//  Pseudo DRAM
// ============================================================
pseudo_DRAM u_DRAM(
    .clk(clk),
    .inf(inf.DRAM_inf)
);

// ============================================================
//  Pattern (stimulus)
// ============================================================
PATTERN u_PATTERN(
    .clk(clk),
    .inf(inf.PATTERN)
);

// ============================================================
//  Checker (assertions & coverage)
// ============================================================
Checker u_CHECKER(
    .clk(clk),
    .inf(inf.CHECKER)
);

endmodule
