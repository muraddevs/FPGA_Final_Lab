`timescale 1ns/1ps

module tb_vending_machine;

  reg clk;
  reg resetBtn_n;
  reg nickelBtn_n;
  reg dimeBtn_n;
  reg quarterBtn_n;

  wire dispenseLed;
  wire changeLed;
  wire [6:0] segOut;
  wire [5:0] digitSel;

  vending_machine dut (
    .clk(clk),
    .resetBtn_n(resetBtn_n),
    .nickelBtn_n(nickelBtn_n),
    .dimeBtn_n(dimeBtn_n),
    .quarterBtn_n(quarterBtn_n),
    .dispenseLed(dispenseLed),
    .changeLed(changeLed),
    .segOut(segOut),
    .digitSel(digitSel)
  );

  // 50 MHz clock
  initial clk = 0;
  always #10 clk = ~clk;

  initial begin
    // idle
    resetBtn_n   = 1;
    nickelBtn_n  = 1;
    dimeBtn_n    = 1;
    quarterBtn_n = 1;

    // wait 1 ms
    #1_000_000;

    // RESET (hold 12 ms)
    resetBtn_n = 0;
    #12_000_000;
    resetBtn_n = 1;

    // wait
    #2_000_000;

    // QUARTER
    quarterBtn_n = 0;
    #12_000_000;
    quarterBtn_n = 1;

    #2_000_000;

    // DIME
    dimeBtn_n = 0;
    #12_000_000;
    dimeBtn_n = 1;

    #2_000_000;

    // NICKEL (total = 40)
    nickelBtn_n = 0;
    #12_000_000;
    nickelBtn_n = 1;

    #20_000_000;
    $stop;
  end

endmodule
