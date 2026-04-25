`ifndef PSEUDO_DRAM_SV
`define PSEUDO_DRAM_SV
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
//   File Name   : pseudo_DRAM.sv
//   Module Name : pseudo_DRAM
//   Release version : v1.0
//
//   Description :
//     Simulates an AXI4-Lite-like external DRAM for the bridge module.
//     Address map: base = 17'h10000 (65536), each player entry = 8 bytes.
//     256 entries => occupies 65536 ~ 65536+2047.
//     Supports random read/write latency to stress-test the bridge.
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module pseudo_DRAM(input clk, INF.DRAM_inf inf);

// ============================================================
//  Parameters
// ============================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";

// DRAM address range: 0x10000 ~ 0x107FF  (256 players × 8 bytes)
parameter DRAM_BASE  = 17'h10000;
parameter DRAM_WORDS = 256;        // number of 8-byte words

// ============================================================
//  Internal memory
// ============================================================
reg [7:0] mem [((DRAM_BASE + DRAM_WORDS*8) - 1) : DRAM_BASE];

initial begin
    $readmemh(DRAM_p_r, mem, 65536, 67583);
    $display("psuedo DRAM loaded!!!");
end

// ============================================================
//  FSM
// ============================================================
typedef enum logic [2:0] {
    IDLE        = 3'd0,
    AR_WAIT     = 3'd1,   // waiting for AR_VALID
    R_DELAY     = 3'd2,   // random read latency
    R_OUT       = 3'd3,   // output read data
    AW_WAIT     = 3'd4,   // waiting for AW_VALID
    W_WAIT      = 3'd5,   // waiting for W_VALID
    W_DELAY     = 3'd6,   // random write latency / response
    B_OUT       = 3'd7
} dram_state_t;

dram_state_t state, next_state;

// ============================================================
//  Latency counter  (1~3 cycles random)
// ============================================================
logic [1:0] lat_cnt;
logic [1:0] lat_target;

// simple LFSR for "random" latency
logic [3:0] lfsr;
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) lfsr <= 4'hA;
    else            lfsr <= {lfsr[2:0], lfsr[3] ^ lfsr[2]};
end
// latency 1~3
assign lat_target = (lfsr[1:0] == 2'b00) ? 2'd1 :
                    (lfsr[1:0] == 2'b01) ? 2'd1 :
                    (lfsr[1:0] == 2'b10) ? 2'd2 : 2'd3;

// ============================================================
//  Address / data registers
// ============================================================
logic [16:0] addr_r;
logic [63:0] wdata_r;
logic [63:0] rdata_r;

// ============================================================
//  State machine
// ============================================================
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) state <= IDLE;
    else            state <= next_state;
end

always_comb begin
    next_state = state;
    case (state)
        IDLE: begin
            if      (inf.AR_VALID) next_state = AR_WAIT;
            else if (inf.AW_VALID) next_state = AW_WAIT;
        end
        AR_WAIT: begin
            // AR_READY will be asserted combinatorially; go to delay
            next_state = R_DELAY;
        end
        R_DELAY: begin
            if (lat_cnt == lat_target) next_state = R_OUT;
        end
        R_OUT: begin
            if (inf.R_READY) next_state = IDLE;
        end
        AW_WAIT: begin
            next_state = W_WAIT;
        end
        W_WAIT: begin
            if (inf.W_VALID) next_state = W_DELAY;
        end
        W_DELAY: begin
            if (lat_cnt == lat_target) next_state = B_OUT;
        end
        B_OUT: begin
            if (inf.B_READY) next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// ============================================================
//  Latency counter
// ============================================================
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)
        lat_cnt <= 0;
    else if (state == AR_WAIT || state == AW_WAIT || state == W_WAIT)
        lat_cnt <= 0;
    else if (state == R_DELAY || state == W_DELAY)
        lat_cnt <= lat_cnt + 1;
end

// ============================================================
//  Capture address and write data
// ============================================================
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        addr_r  <= 0;
        wdata_r <= 0;
    end else begin
        if (inf.AR_VALID && state == IDLE) addr_r <= inf.AR_ADDR;
        if (inf.AW_VALID && state == IDLE) addr_r <= inf.AW_ADDR;
        if (inf.W_VALID  && state == W_WAIT) wdata_r <= inf.W_DATA;
    end
end

// ============================================================
//  Read data assembly from byte memory (little-endian in mem,
//  bridge writes {addr+7..addr+0} as bytes [63:56]..[7:0])
// ============================================================
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        rdata_r <= 0;
    end else if (state == AR_WAIT) begin
        rdata_r <= { mem[addr_r+0], mem[addr_r+1], mem[addr_r+2], mem[addr_r+3],
                     mem[addr_r+4], mem[addr_r+5], mem[addr_r+6], mem[addr_r+7] };
    end
end

// ============================================================
//  Write to memory
// ============================================================
always @(posedge clk) begin
    if (state == W_DELAY && lat_cnt == lat_target) begin
        mem[addr_r+0] <= wdata_r[63:56];
        mem[addr_r+1] <= wdata_r[55:48];
        mem[addr_r+2] <= wdata_r[47:40];
        mem[addr_r+3] <= wdata_r[39:32];
        mem[addr_r+4] <= wdata_r[31:24];
        mem[addr_r+5] <= wdata_r[23:16];
        mem[addr_r+6] <= wdata_r[15: 8];
        mem[addr_r+7] <= wdata_r[ 7: 0];
    end
end

// ============================================================
//  Output assignments
// ============================================================

// AR channel handshake
assign inf.AR_READY = (state == AR_WAIT);

// R channel
assign inf.R_VALID  = (state == R_OUT);
assign inf.R_DATA   = (state == R_OUT) ? rdata_r : 64'd0;
assign inf.R_RESP   = 2'b00;

// AW channel handshake
assign inf.AW_READY = (state == AW_WAIT);

// W channel handshake
assign inf.W_READY  = (state == W_WAIT);

// B channel
assign inf.B_VALID  = (state == B_OUT);
assign inf.B_RESP   = 2'b00;

endmodule

`endif // PSEUDO_DRAM_SV
