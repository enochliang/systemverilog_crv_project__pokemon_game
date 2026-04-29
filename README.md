# CRV Lab — PSG (Pokemon Strategy Game)

> **NYCU ICLAB 2021 Fall — Lab09, Lab10**
> An RTL design of a Pokemon Strategy Game implemented in SystemVerilog, with Functional Coverage Verification and Assertion-Based Verification (ABV).

---

## Table of Contents

- [Project Overview](#project-overview)
- [Project Structure](#project-structure)
- [System Architecture & Module Descriptions](#system-architecture--module-descriptions)
- [Interface Signal Descriptions](#interface-signal-descriptions)
- [Data Type Definitions](#data-type-definitions)
- [Supported Actions](#supported-actions)
- [Error Messages](#error-messages)
- [Environment Requirements](#environment-requirements)
- [How to Use](#how-to-use)
  - [Compilation & Simulation](#compilation--simulation)
  - [Waveform Viewing](#waveform-viewing)
  - [Cleaning Generated Files](#cleaning-generated-files)
- [Coverage Specification](#coverage-specification)
- [Notes](#notes)

---

## Project Overview

This project implements an RTL circuit for a "Pokemon Strategy Game (PSG)". Core features include:

- **Player Data Management**: Each player has a Bag and Pokemon information stored in an external pseudo-DRAM.
- **Transaction System**: Supports Buy, Sell, and Deposit operations.
- **Item System**: Use Berry, Medicine, Candy, and Bracer items to affect Pokemon status.
- **Battle System**: Two players' Pokemon attack each other; damage and experience points are calculated accordingly.
- **Bridge Module**: The `bridge` module accesses the external pseudo-DRAM via an AXI4-Lite-like protocol, enabling the `pokemon` main module to read and write player data.

The verification environment uses CRV (Constraint Random Verification) to generate 6,000 random test cases, and employs Cover Groups and SVA Assertions to confirm design correctness.

---

## Project Structure

```
project/
├── 00_TESTBED/
│   ├── Usertype_PKG.sv    # Data type definitions (enum, struct, union)
│   ├── INF.sv             # System interface definitions (Interface)
│   ├── PATTERN.sv         # Random stimulus generator (CRV)
│   ├── CHECKER.sv         # Coverage groups & SVA assertions
│   ├── pseudo_DRAM.sv     # Simulated external DRAM (AXI4-Lite slave)
│   ├── testbed.sv         # Top-level simulation platform (Testbench)
│   └── DRAM/
│       └── dram.dat       # DRAM initial data (256 player records)
└── 01_RTL/
    ├── pokemon.sv         # Main design module (DUT)
    ├── bridge.sv          # AXI4-Lite bridge module
    ├── filelist.f         # Compilation order list
    └── Makefile           # Simulation shortcut commands
```

---

## System Architecture & Module Descriptions

![system architecture](99_IMAGES/module_hier-(light).drawio.png#gh-light-mode-only)
![system architecture](99_IMAGES/module_hier-(dark).drawio.png#gh-dark-mode-only)

| Module | Description |
|--------|-------------|
| `pokemon` | Main design module (DUT). Receives inputs from PATTERN, executes action logic, and communicates with `bridge` via an internal channel. |
| `bridge` | AXI4-Lite bridge module. Translates read/write requests from `pokemon` into the DRAM protocol. |
| `pseudo_DRAM` | Simulated external DRAM acting as an AXI4-Lite Slave, providing player data read/write. |
| `PATTERN` | CRV random stimulus generator. Produces 6,000 valid/invalid operations and compares DUT output against the Golden Model. |
| `CHECKER` | Functional coverage groups (Spec1–Spec5) and SVA assertions. |
| `INF` | System interface (SystemVerilog Interface) connecting all modules. |

---

## Interface Signal Descriptions

### PATTERN → pokemon (Inputs)

| Signal | Width | Description |
|--------|-------|-------------|
| `rst_n` | 1 | Asynchronous active-low reset |
| `id_valid` | 1 | Player ID valid strobe |
| `act_valid` | 1 | Action valid strobe |
| `item_valid` | 1 | Item valid strobe |
| `type_valid` | 1 | Pokemon type valid strobe |
| `amnt_valid` | 1 | Amount valid strobe |
| `D` | 16 | Data bus (union, contains money / id / act / item / type) |

### pokemon → PATTERN (Outputs)

| Signal | Width | Description |
|--------|-------|-------------|
| `out_valid` | 1 | Output valid strobe |
| `complete` | 1 | Operation succeeded (1) or failed (0) |
| `err_msg` | 4 | Error code (`Error_Msg` enum) |
| `out_info` | 64 | Player state after operation (`Player_Info` struct) |

### pokemon ↔ bridge (Internal Channel)

| Signal | Direction | Description |
|--------|-----------|-------------|
| `C_in_valid` | pokemon → bridge | Request valid |
| `C_r_wb` | pokemon → bridge | 1 = Read, 0 = Write |
| `C_addr` | pokemon → bridge | Player ID (8-bit address) |
| `C_data_w` | pokemon → bridge | Write data (64-bit) |
| `C_out_valid` | bridge → pokemon | Response valid |
| `C_data_r` | bridge → pokemon | Read data (64-bit) |

---

## Data Type Definitions

### Player_Info (64-bit packed struct)

```
[63:48]  Bag_Info.money        (16-bit)
[47:44]  Bag_Info.bracer_num   (4-bit)
[43:40]  Bag_Info.candy_num    (4-bit)
[39:36]  Bag_Info.medicine_num (4-bit)
[35:32]  Bag_Info.berry_num    (4-bit)
[31:28]  PKM_Info.stage        (4-bit)
[27:24]  PKM_Info.pkm_type     (4-bit)
[23:16]  PKM_Info.hp           (8-bit)
[15:8]   PKM_Info.atk          (8-bit)
[7:0]    PKM_Info.exp          (8-bit)
```

### Pokemon Base Attack Power (ATK) Reference Table

| Stage \ Type | Grass | Fire | Water | Electric |
|:---:|:---:|:---:|:---:|:---:|
| Lowest  | 63 | 64 | 60 | 65 |
| Middle  | 94 | 96 | 89 | 97 |
| Highest | 123 | 127 | 113 | 124 |

---

## Supported Actions

| Action | Code | Input Sequence | Description |
|--------|------|----------------|-------------|
| `Buy` | 4'd1 | id → act → (item \| type) | Purchase an item or Pokemon |
| `Sell` | 4'd2 | id → act | Sell a Pokemon |
| `Deposit` | 4'd4 | id → act → amnt | Deposit money |
| `Use_item` | 4'd6 | id → act → item | Use an item |
| `Check` | 4'd8 | id → act | Check player status |
| `Attack` | 4'd10 | id → act → id (opponent) | Initiate an attack |

---

## Error Messages

| Code | Name | Trigger Condition |
|------|------|-------------------|
| 4'd0 | `No_Err` | Operation succeeded |
| 4'd1 | `Already_Have_PKM` | Attempted to buy a Pokemon but already owns one |
| 4'd2 | `Out_of_money` | Insufficient funds |
| 4'd4 | `Bag_is_full` | Bag items have reached the maximum limit |
| 4'd6 | `Not_Having_PKM` | Operation requires a Pokemon but the player has none |
| 4'd8 | `Has_Not_Grown` | Pokemon has not yet met the evolution condition |
| 4'd10 | `Not_Having_Item` | The specified item is not in the bag |
| 4'd13 | `HP_is_Zero` | Pokemon HP is zero; cannot attack |

---

## Environment Requirements

| Tool | Version Requirement | Purpose |
|------|---------------------|---------|
| **VCS** (Synopsys) | Any version supporting `-full64 -sverilog` | Compilation & simulation |
| **Verdi / nWave** | Requires `$VERDI_HOME` environment variable | Waveform viewing (FSDB) |
| SystemVerilog | IEEE 1800-2012 or later | Language standard |

> If using Questa (ModelSim), refer to the comments in `filelist.f` for the compilation command:
> ```
> vlog -sv -f filelist.f
> ```

---

## How to Use

### Compilation & Simulation

Navigate to the RTL directory and run `make`:

```bash
cd project/01_RTL
make sim
```

This command is equivalent to:

```bash
vcs -full64 -sverilog \
    -timescale=1ns/100ps \
    -f filelist.f \
    -P ${VERDI_HOME}/share/PLI/VCS/LINUX64/novas.tab \
       ${VERDI_HOME}/share/PLI/VCS/LINUX64/pli.a \
    -o simv \
    -l compile.log
./simv
```

**After successful compilation**, the simulator automatically runs `./simv`. PATTERN will sequentially send **6,000** random test cases and compare the DUT output against the Golden Model for each one.

The following files are generated after simulation:

| File | Description |
|------|-------------|
| `simv` | Compiled simulation executable |
| `compile.log` | Compilation warnings and error log |
| `dump.fsdb` | Verdi waveform file (full hierarchical dump) |

### Waveform Viewing

After simulation, open the waveform with Verdi:

```bash
verdi -ssf dump.fsdb &
```

Or use nWave:

```bash
nWave dump.fsdb &
```

The waveform includes all signals across the full testbench hierarchy (set by `$fsdbDumpvars(0, testbed)`) as well as SVA assertion Pass/Fail events.

### Cleaning Generated Files

```bash
cd project/01_RTL
make clean
```

This command removes: `simv*`, `*.fsdb`, `*.log`, `novas*`, `nWaveLog`, `csrc`, `ucli.key`

---

## Coverage Specification

`CHECKER.sv` defines the following five coverage groups:

| Group | Sampling Event | Coverage Goal |
|-------|----------------|---------------|
| **Spec1** | `negedge clk && out_valid` | Output Pokemon Stage (4 types) and Type (5 types), each at least 20 times |
| **Spec2** | `posedge clk && id_valid` | All 256 player IDs appear at least once each |
| **Spec3** | `posedge clk && act_valid` | All transitions between actions (Buy/Sell/Deposit/Use_item/Check/Attack), each at least 5 times |
| **Spec4** | `negedge clk && out_valid` | `complete = 1` (success) and `complete = 0` (failure), each at least 200 times |
| **Spec5** | `negedge clk && out_valid` | All 7 `Error_Msg` types appear at least 20 times each |

---

## Notes

1. **DRAM Data Format**: `dram.dat` stores 256 player records, each occupying 8 bytes (64-bit). Addresses start at `65536` (`0x10000`); player ID N maps to address `0x10000 + N * 8`.

2. **The compilation order in `filelist.f` must not be changed**: `Usertype_PKG.sv` must be compiled first (Package definition), followed by `INF.sv` (Interface requires Package), then the RTL modules.

3. **Parts of the RTL modules that must not be modified**: Sections in `Usertype_PKG.sv` marked `Don't revise` are TA-provided specifications. Students may only add custom types in the designated areas.

4. **Clock Settings**: The system clock is **100 MHz** (period of 10 ns, timescale `1ns/100ps`).

5. **Reset Behavior**: `rst_n` is an **asynchronous active-low reset**. Both `bridge` and `pokemon` reset their state machines to IDLE on the `negedge rst_n`.
