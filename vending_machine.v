`timescale 1ns/1ps

module vending_machine(
    input  wire clk,            // 50 MHz system clock
    input  wire resetBtn_n,      // RESET button (active-LOW)
    input  wire nickelBtn_n,     // Nickel button (5¢, active-LOW)
    input  wire dimeBtn_n,       // Dime button (10¢, active-LOW)
    input  wire quarterBtn_n,    // Quarter button (25¢, active-LOW)

    output reg  dispenseLed,     // HIGH when item is dispensed
    output reg  changeLed,       // HIGH when change should be collected

    output reg  [6:0] segOut,    // 7-segment segment lines (a–g)
    output reg  [5:0] digitSel   // Digit select lines (active-LOW)
);

    // Item price in cents
    localparam [6:0] itemPrice = 7'd40;

    // Debounced button outputs
    // Each button provides:
    //  - a single-clock press pulse
    //  - a stable debounced level
    wire resetPulse, resetLevel;
    wire nickelPulse, dimePulse, quarterPulse;
    wire nickelLevel, dimeLevel, quarterLevel;
    // Reset button debounce
    btn_debounce_pulse #(.CLK_HZ(50_000_000), .DEBOUNCE_MS(10)) debounceReset (
        .clk(clk),
        .btn_raw_n(resetBtn_n),
        .press_pulse(resetPulse),
        .btn_stable(resetLevel)
    );

    // Nickel button debounce
    btn_debounce_pulse #(.CLK_HZ(50_000_000), .DEBOUNCE_MS(10)) debounceNickel (
        .clk(clk),
        .btn_raw_n(nickelBtn_n),
        .press_pulse(nickelPulse),
        .btn_stable(nickelLevel)
    );

    // Dime button debounce
    btn_debounce_pulse #(.CLK_HZ(50_000_000), .DEBOUNCE_MS(10)) debounceDime (
        .clk(clk),
        .btn_raw_n(dimeBtn_n),
        .press_pulse(dimePulse),
        .btn_stable(dimeLevel)
    );

    // Quarter button debounce
    btn_debounce_pulse #(.CLK_HZ(50_000_000), .DEBOUNCE_MS(10)) debounceQuarter (
        .clk(clk),
        .btn_raw_n(quarterBtn_n),
        .press_pulse(quarterPulse),
        .btn_stable(quarterLevel)
    );


    // 7-segment decoder
    // Converts decimal digit (0–9) to segment pattern
    // Common-cathode encoding
    function [6:0] sevenSegDecode;
        input [3:0] digitValue;
        begin
            case (digitValue)
                4'd0: sevenSegDecode = 7'b1000000;
                4'd1: sevenSegDecode = 7'b1111001;
                4'd2: sevenSegDecode = 7'b0100100;
                4'd3: sevenSegDecode = 7'b0110000;
                4'd4: sevenSegDecode = 7'b0011001;
                4'd5: sevenSegDecode = 7'b0010010;
                4'd6: sevenSegDecode = 7'b0000010;
                4'd7: sevenSegDecode = 7'b1111000;
                4'd8: sevenSegDecode = 7'b0000000;
                4'd9: sevenSegDecode = 7'b0010000;
                default: sevenSegDecode = 7'b1111111; // blank
            endcase
        end
    endfunction

    // Total inserted money (in cents)
    reg [6:0] totalCents = 0;

    // Always-enabled control (prevents floating enable)
    wire enableLogic = 1'b1;

    // Coin accumulation logic
    // Each debounced pulse adds money once
    // Reset clears total
    always @(posedge clk) begin
        if (resetLevel) begin
            totalCents <= 7'd0;
        end else if (enableLogic) begin
            if      (nickelPulse)  totalCents <= totalCents + 7'd5;
            else if (dimePulse)    totalCents <= totalCents + 7'd10;
            else if (quarterPulse) totalCents <= totalCents + 7'd25;
            else                   totalCents <= totalCents;
        end
    end

    // Display logic
    // Before vend: show inserted money
    // After vend: show remaining change
    wire [6:0] displayValue =
        (totalCents >= itemPrice) ? (totalCents - itemPrice) : totalCents;

    // Extract decimal digits
    wire [3:0] onesDigit = displayValue % 10;
    wire [3:0] tensDigit = displayValue / 10;

    // 2-digit multiplexing control
    // Switches active digit fast enough for persistence of vision
    reg [15:0] muxCounter = 0;
    reg activeDigit = 0;

    always @(posedge clk) begin
        muxCounter <= muxCounter + 1;
        if (muxCounter == 16'd25000) begin
            muxCounter <= 0;
            activeDigit <= ~activeDigit;
        end
    end

    // Output control and 7-segment driving
    always @(*) begin
        // Default LED states
        dispenseLed = 1'b0;
        changeLed   = 1'b0;

        // Vend condition
        if (!resetLevel && totalCents >= itemPrice) begin
            dispenseLed = 1'b1;
            changeLed   = (totalCents > itemPrice);
        end

        // Default display state (all digits off)
        segOut   = 7'b1111111;
        digitSel = 6'b111111;

        if (resetLevel) begin
            // Show "00" during reset
            if (!activeDigit) begin
                digitSel = 6'b011111; // rightmost digit
                segOut   = sevenSegDecode(4'd0);
            end else begin
                digitSel = 6'b101111; // next digit
                segOut   = sevenSegDecode(4'd0);
            end
        end else begin
            // Normal display operation
            if (!activeDigit) begin
                digitSel = 6'b011111; // ones digit
                segOut   = sevenSegDecode(onesDigit);
            end else begin
                digitSel = 6'b101111; // tens digit
                segOut   = sevenSegDecode(tensDigit);
            end
        end
    end

endmodule
