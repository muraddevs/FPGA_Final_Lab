`timescale 1ns/1ps
module btn_debounce_pulse #(
    // Input clock frequency in Hz
    parameter integer CLK_HZ = 50_000_000,
    // Desired debounce time in milliseconds
    parameter integer DEBOUNCE_MS = 10
)(
    input  wire clk,           // System clock
    input  wire btn_raw_n,      // Raw button input (active-low)
    output wire press_pulse,    // 1-clock pulse on button press
    output wire btn_stable      // Debounced button level
);

    // Convert active-low button to active-high (1 = pressed)
    wire btn_raw = ~btn_raw_n;

    // 2-flip-flop synchronizer
    // Prevents metastability by syncing the asynchronous button signal
    // into the clock domain
    reg sync_ff1 = 0, sync_ff2 = 0;
    always @(posedge clk) begin
        sync_ff1 <= btn_raw;
        sync_ff2 <= sync_ff1;
    end

    // Debounce counter
    // Counts how long the synchronized signal remains stable
    localparam integer DEBOUNCE_CNT_MAX =
        (CLK_HZ / 1000) * DEBOUNCE_MS;

    // Counter width is automatically sized using clog2
    reg [$clog2(DEBOUNCE_CNT_MAX+1)-1:0] debounce_cnt = 0;

    reg btn_filtered = 0;   // Debounced (stable) button state
    reg sync_prev   = 0;   // Previous synchronized button state

    always @(posedge clk) begin
        // If the synchronized button value changes,
        // reset the debounce counter
        if (sync_ff2 != sync_prev) begin
            sync_prev   <= sync_ff2;
            debounce_cnt <= 0;
        end else begin
            // If input remains stable, increment counter
            if (debounce_cnt < DEBOUNCE_CNT_MAX)
                debounce_cnt <= debounce_cnt + 1;
            else
                // Once stable long enough, accept new value
                btn_filtered <= sync_prev;
        end
    end

    // Output the debounced button level
    assign btn_stable = btn_filtered;

    
    // Press pulse generation
    // Creates a single-clock pulse on rising edge of debounced signal
    reg btn_filtered_d = 0;
    always @(posedge clk)
        btn_filtered_d <= btn_filtered;

    // Pulse is high for 1 clock when button transitions 0 → 1
    assign press_pulse = btn_filtered & ~btn_filtered_d;

endmodule
