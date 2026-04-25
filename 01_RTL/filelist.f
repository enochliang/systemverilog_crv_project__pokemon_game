// ============================================================
//  filelist.f  — compile order for PSG Lab09
//  Usage:
//    vcs  -full64 -sverilog -timescale=1ns/100ps -f filelist.f -o simv
//    vsim (questa): vlog -sv -f filelist.f
// ============================================================

// 1. Type package (must be first)
../00_TESTBED/Usertype_PKG.sv

// 2. Interface (depends on package)
../00_TESTBED/INF.sv

// 3. RTL
./bridge.sv
./pokemon.sv

// 4. Testbench components
../00_TESTBED/pseudo_DRAM.sv
../00_TESTBED/PATTERN.sv
../00_TESTBED/CHECKER.sv

// 5. Top-level testbed
../00_TESTBED/testbed.sv
