module async_fifo1_tb;

  parameter DSIZE = 8;
  parameter ASIZE = 4;

  wire [DSIZE-1:0] rdata;
  wire wfull;
  wire rempty;
  reg [DSIZE-1:0] wdata;
  reg winc, wclk, wrst_n;
  reg rinc, rclk, rrst_n;

  // Verification queue
  reg [DSIZE-1:0] verif_data_q[0:31];
  integer q_front = 0;
  integer q_back = 0;
  reg [DSIZE-1:0] verif_wdata;

  // Instantiate the FIFO
  async_fifo1 #(DSIZE, ASIZE) dut (
    .winc(winc),
    .wclk(wclk),
    .wrst_n(wrst_n),
    .rinc(rinc),
    .rclk(rclk),
    .rrst_n(rrst_n),
    .wdata(wdata),
    .rdata(rdata),
    .wfull(wfull),
    .rempty(rempty)
  );

  integer i, iter;

  // **Fixing Clock Generation**
  initial begin
    wclk = 0;
    rclk = 0;
    forever begin
      #10 wclk = ~wclk;
    end
  end

  initial begin
    forever begin
      #35 rclk = ~rclk;
    end
  end

  // **Fixing Reset Behavior**
  initial begin
    wrst_n = 0;
    rrst_n = 0;
    #100;
    wrst_n = 1;
    rrst_n = 1;
    $display("Reset deasserted at time %t", $time);
  end

  // **Write Process**
  initial begin
    winc = 0;
    wdata = 0;
    repeat(5) @(posedge wclk);
    $display("Starting writes at time %t", $time);

    for (iter = 0; iter < 2; iter = iter + 1) begin
      for (i = 0; i < 16; i = i + 1) begin  // Reduce writes to avoid overflow
        @(posedge wclk);
        if (!wfull) begin
          winc = 1;
          wdata = $urandom % (1 << DSIZE);
          verif_data_q[q_front] = wdata;
          q_front = (q_front + 1) % 32;
          $display("[WRITE] Time: %t | Data: %h | wfull: %b", $time, wdata, wfull);
        end else begin
          winc = 0;
        end
      end
      #500;
    end
  end

  // **Read Process**
  initial begin
    rinc = 0;
    repeat(8) @(posedge rclk);
    $display("Starting reads at time %t", $time);

    for (iter = 0; iter < 2; iter = iter + 1) begin
      for (i = 0; i < 16; i = i + 1) begin  // Reduce reads to avoid underflow
        @(posedge rclk);
        if (!rempty) begin
          rinc = 1;
          verif_wdata = verif_data_q[q_back];
          q_back = (q_back + 1) % 32;
          $display("[READ] Time: %t | Expected: %h | Actual: %h | rempty: %b", 
                   $time, verif_wdata, rdata, rempty);
          if (rdata !== verif_wdata) begin
            $error("[MISMATCH] Expected: %h | Actual: %h at time %t", verif_wdata, rdata, $time);
          end
        end else begin
          rinc = 0;
        end
      end
      #500;
    end
    $finish;
  end

endmodule
