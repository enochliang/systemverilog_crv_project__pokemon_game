# CRV Lab — PSG (Pokemon Strategy Game)

> **NYCU ICLAB 2021 Fall — Lab09, Lab10**
> 以 SystemVerilog 實作的寶可夢策略遊戲 RTL 設計，並搭配功能覆蓋率驗證（Functional Coverage）與斷言驗證（Assertion-Based Verification）。

---

## 目錄

- [專案簡介](#專案簡介)
- [專案架構](#專案架構)
- [系統架構與模組說明](#系統架構與模組說明)
- [介面訊號說明](#介面訊號說明)
- [資料型別定義](#資料型別定義)
- [支援的動作（Action）](#支援的動作action)
- [錯誤訊息（Error\_Msg）](#錯誤訊息error_msg)
- [環境需求](#環境需求)
- [如何使用](#如何使用)
  - [編譯與模擬](#編譯與模擬)
  - [波形觀察](#波形觀察)
  - [清除產生檔案](#清除產生檔案)
- [覆蓋率規格（Coverage Spec）](#覆蓋率規格coverage-spec)
- [注意事項](#注意事項)

---

## 專案簡介

本專案實作一個「寶可夢策略遊戲（Pokemon Strategy Game，PSG）」的 RTL 電路，核心功能包含：

- **玩家資料管理**：每位玩家擁有背包（Bag）與寶可夢（Pokemon）資訊，儲存於外部偽 DRAM 中。
- **交易系統**：支援購買（Buy）、販賣（Sell）、存款（Deposit）等操作。
- **道具系統**：使用 Berry、Medicine、Candy、Bracer 等道具影響寶可夢狀態。
- **戰鬥系統**：兩位玩家的寶可夢相互攻擊，計算傷害與經驗值。
- **橋接模組**：`bridge` 模組透過 AXI4-Lite-like 協定存取外部偽 DRAM，供 `pokemon` 主模組讀寫玩家資料。

驗證環境使用 CRV（Constraint Random Verification）產生 6000 筆隨機測試，並以覆蓋群組（Cover Group）與 SVA 斷言（Assertion）確認設計正確性。

---

## 專案架構

```
project/
├── 00_TESTBED/
│   ├── Usertype_PKG.sv    # 資料型別定義（enum、struct、union）
│   ├── INF.sv             # 系統介面定義（Interface）
│   ├── PATTERN.sv         # 隨機測試激勵產生器（CRV）
│   ├── CHECKER.sv         # 覆蓋率群組 & SVA 斷言
│   ├── pseudo_DRAM.sv     # 模擬外部 DRAM（AXI4-Lite slave）
│   ├── testbed.sv         # 頂層模擬平台（Top-level Testbench）
│   └── DRAM/
│       └── dram.dat       # DRAM 初始資料（256 筆玩家資料）
└── 01_RTL/
    ├── pokemon.sv         # 主設計模組（DUT）
    ├── bridge.sv          # AXI4-Lite 橋接模組
    ├── filelist.f         # 編譯順序清單
    └── Makefile           # 模擬快速指令
```

---

## 系統架構與模組說明

```
┌──────────────┐       Custom Channel         	┌──────────────┐     AXI4-Lite     	┌───────────────┐
│   PATTERN    │ ──── (id/act/item valid) ──▶	│   pokemon    │ ◀──────────────▶ 	│    bridge     │ ◀──▶ pseudo_DRAM
│  (Stimulus)  │ ◀─── (out_valid / info) ─── 	│    (DUT)     │  	C_in_valid      │               │
└──────────────┘                              	└──────────────┘  	C_r_wb          └───────────────┘
                                                     │           		C_addr
                                                     ▼            	C_data_w/r
                                              ┌──────────────┐
                                              │   CHECKER    │
                                              │(Coverage/SVA)│
                                              └──────────────┘
```

| 模組 | 說明 |
|------|------|
| `pokemon` | 主設計模組（DUT），接收 PATTERN 輸入，執行動作邏輯，透過內部通道與 `bridge` 溝通 |
| `bridge` | AXI4-Lite 橋接模組，負責將 `pokemon` 的讀寫請求轉換為 DRAM 協定 |
| `pseudo_DRAM` | 模擬外部 DRAM，扮演 AXI4-Lite Slave，提供玩家資料讀寫 |
| `PATTERN` | CRV 隨機激勵產生器，產生 6000 筆合法/非法操作並比對輸出 |
| `CHECKER` | 功能覆蓋率群組（Spec1~Spec5）與 SVA 斷言 |
| `INF` | 連接所有模組的系統介面（SystemVerilog Interface） |

---

## 介面訊號說明

### PATTERN → pokemon（輸入）

| 訊號 | 寬度 | 說明 |
|------|------|------|
| `rst_n` | 1 | 非同步低電位重置 |
| `id_valid` | 1 | 玩家 ID 有效 Strobe |
| `act_valid` | 1 | 動作有效 Strobe |
| `item_valid` | 1 | 道具有效 Strobe |
| `type_valid` | 1 | 寶可夢類型有效 Strobe |
| `amnt_valid` | 1 | 金額有效 Strobe |
| `D` | 16 | 資料匯流排（union，含 money / id / act / item / type） |

### pokemon → PATTERN（輸出）

| 訊號 | 寬度 | 說明 |
|------|------|------|
| `out_valid` | 1 | 輸出有效 Strobe |
| `complete` | 1 | 操作成功（1）或失敗（0） |
| `err_msg` | 4 | 錯誤代碼（`Error_Msg` enum） |
| `out_info` | 64 | 操作後的玩家狀態（`Player_Info` struct） |

### pokemon ↔ bridge（內部通道）

| 訊號 | 方向 | 說明 |
|------|------|------|
| `C_in_valid` | pokemon → bridge | 請求有效 |
| `C_r_wb` | pokemon → bridge | 1 = 讀取，0 = 寫入 |
| `C_addr` | pokemon → bridge | 玩家 ID（8-bit 位址） |
| `C_data_w` | pokemon → bridge | 寫入資料（64-bit） |
| `C_out_valid` | bridge → pokemon | 回應有效 |
| `C_data_r` | bridge → pokemon | 讀取資料（64-bit） |

---

## 資料型別定義

### Player_Info（64-bit packed struct）

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

### 寶可夢基礎攻擊力（ATK）對照表

| Stage \ Type | Grass | Fire | Water | Electric |
|:---:|:---:|:---:|:---:|:---:|
| Lowest  | 63 | 64 | 60 | 65 |
| Middle  | 94 | 96 | 89 | 97 |
| Highest | 123 | 127 | 113 | 124 |

---

## 支援的動作（Action）

| 動作 | 代碼 | 輸入序列 | 說明 |
|------|------|----------|------|
| `Buy` | 4'd1 | id → act → (item \| type) | 購買道具或寶可夢 |
| `Sell` | 4'd2 | id → act | 販賣寶可夢 |
| `Deposit` | 4'd4 | id → act → amnt | 存入金錢 |
| `Use_item` | 4'd6 | id → act → item | 使用道具 |
| `Check` | 4'd8 | id → act | 查詢玩家狀態 |
| `Attack` | 4'd10 | id → act → id（對手）| 發動攻擊 |

---

## 錯誤訊息（Error_Msg）

| 代碼 | 名稱 | 觸發條件 |
|------|------|----------|
| 4'd0 | `No_Err` | 操作成功 |
| 4'd1 | `Already_Have_PKM` | 嘗試購買寶可夢但已有寶可夢 |
| 4'd2 | `Out_of_money` | 金錢不足 |
| 4'd4 | `Bag_is_full` | 背包道具已達上限 |
| 4'd6 | `Not_Having_PKM` | 操作需要寶可夢但玩家沒有 |
| 4'd8 | `Has_Not_Grown` | 寶可夢尚未達到進化條件 |
| 4'd10 | `Not_Having_Item` | 背包中沒有指定道具 |
| 4'd13 | `HP_is_Zero` | 寶可夢 HP 為零，無法攻擊 |

---

## 環境需求

| 工具 | 版本需求 | 用途 |
|------|----------|------|
| **VCS** (Synopsys) | 任意支援 `-full64 -sverilog` 版本 | 編譯與模擬 |
| **Verdi / nWave** | 需設定 `$VERDI_HOME` 環境變數 | 波形觀察（FSDB） |
| SystemVerilog | IEEE 1800-2012 以上 | 語言標準 |

> 若使用 Questa（ModelSim），編譯指令請參考 `filelist.f` 內的註解：
> ```
> vlog -sv -f filelist.f
> ```

---

## 如何使用

### 編譯與模擬

進入 RTL 目錄後執行 `make`：

```bash
cd project/01_RTL
make sim
```

此指令等同於執行：

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

**編譯成功後**，模擬器會自動執行 `./simv`，PATTERN 將依序送出 **6000 筆**隨機測試，並在每筆比對 DUT 輸出與 Golden Model。

模擬完成後會產生以下檔案：

| 檔案 | 說明 |
|------|------|
| `simv` | 編譯後的模擬執行檔 |
| `compile.log` | 編譯警告與錯誤紀錄 |
| `dump.fsdb` | Verdi 波形檔（全層遞迴 dump） |

### 波形觀察

模擬完成後，使用 Verdi 開啟波形：

```bash
verdi -ssf dump.fsdb &
```

或使用 nWave：

```bash
nWave dump.fsdb &
```

波形包含 testbed 全層信號（由 `$fsdbDumpvars(0, testbed)` 設定）以及 SVA 斷言的 Pass/Fail 事件。

### 清除產生檔案

```bash
cd project/01_RTL
make clean
```

此指令會移除：`simv*`、`*.fsdb`、`*.log`、`novas*`、`nWaveLog`、`csrc`、`ucli.key`

---

## 覆蓋率規格（Coverage Spec）

`CHECKER.sv` 中定義了以下五個覆蓋群組：

| 群組 | 取樣事件 | 覆蓋目標 |
|------|----------|----------|
| **Spec1** | `negedge clk && out_valid` | 輸出的寶可夢 Stage（4 種）與 Type（5 種），每種至少 20 次 |
| **Spec2** | `posedge clk && id_valid` | 所有 256 個玩家 ID 至少各出現 1 次 |
| **Spec3** | `posedge clk && act_valid` | 所有動作（Buy/Sell/Deposit/Use_item/Check/Attack）之間的轉換，各至少 5 次 |
| **Spec4** | `negedge clk && out_valid` | `complete = 1`（成功）與 `complete = 0`（失敗）各至少 200 次 |
| **Spec5** | `negedge clk && out_valid` | 7 種 Error_Msg 各至少出現 20 次 |

---

## 注意事項

1. **DRAM 資料格式**：`dram.dat` 儲存 256 筆玩家資料，每筆佔 8 Bytes（64-bit），位址從 `65536`（`0x10000`）起始，玩家 ID N 對應位址 `0x10000 + N * 8`。

2. **filelist.f 編譯順序不可更改**：`Usertype_PKG.sv` 必須最先編譯（Package 定義），其次是 `INF.sv`（Interface 需要 Package），RTL 模組再其後。

3. **RTL 模組禁止修改的部分**：`Usertype_PKG.sv` 中有標示 `Don't revise` 的區段為 TA 提供的規格，學生只能在指定區域加入自訂型別。

4. **時脈設定**：系統時脈為 **100 MHz**（週期 10ns，timescale `1ns/100ps`）。

5. **重置行為**：`rst_n` 為**非同步低電位重置**，`bridge` 與 `pokemon` 皆在 `negedge rst_n` 時重置狀態機至 IDLE。
