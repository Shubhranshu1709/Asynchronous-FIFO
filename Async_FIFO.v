module async_fifo1
#(
  parameter DSIZE = 8,
  parameter ASIZE = 4
 )
(
  input   winc, wclk, wrst_n, // winc write enable signal
  input   rinc, rclk, rrst_n, // rinc read enable signal
  input   [DSIZE-1:0] wdata,

  output  [DSIZE-1:0] rdata,
  output  wfull,
  output  rempty
);

  wire [ASIZE-1:0] waddr, raddr;
  wire [ASIZE:0] wptr, rptr, wq2_rptr, rq2_wptr;

  sync_r2w #(ASIZE) sync_r2w (
    .wclk(wclk),
    .wrst_n(wrst_n),
    .rptr(rptr),
    .wq2_rptr(wq2_rptr)
  );
  
  sync_w2r #(ASIZE) sync_w2r (
    .rclk(rclk),
    .rrst_n(rrst_n),
    .wptr(wptr),
    .rq2_wptr(rq2_wptr)
  );
  
  fifomem #(DSIZE, ASIZE) fifomem (
    .winc(winc),
    .wfull(wfull),
    .wclk(wclk),
    .waddr(waddr),
    .raddr(raddr),
    .wdata(wdata),
    .rdata(rdata)
  );
  
  rptr_empty #(ASIZE) rptr_empty (
    .rinc(rinc),
    .rclk(rclk),
    .rrst_n(rrst_n),
    .rq2_wptr(rq2_wptr),
    .rempty(rempty),
    .raddr(raddr),
    .rptr(rptr)
  );
  
  wptr_full #(ASIZE) wptr_full (
    .winc(winc),
    .wclk(wclk),
    .wrst_n(wrst_n),
    .wq2_rptr(wq2_rptr),
    .wfull(wfull),
    .waddr(waddr),
    .wptr(wptr)
  );

endmodule

module fifomem
#(
  parameter DATASIZE = 8, // Memory data word width
  parameter ADDRSIZE = 4  // Number of mem address bits
)
(
  input   winc, wfull, wclk,
  input   [ADDRSIZE-1:0] waddr, raddr,
  input   [DATASIZE-1:0] wdata,
  output  [DATASIZE-1:0] rdata
);

  // RTL Verilog memory model
  localparam DEPTH = 1 << ADDRSIZE;

  reg [DATASIZE-1:0] mem [0:DEPTH-1];

  assign rdata = mem[raddr];

  always @(posedge wclk)
    if (winc && !wfull)
      mem[waddr] <= wdata;

endmodule

module rptr_empty
#(
  parameter ADDRSIZE = 4
)
(
  input   rinc, rclk, rrst_n,
  input   [ADDRSIZE:0] rq2_wptr,
  output reg  rempty,
  output  [ADDRSIZE-1:0] raddr,
  output reg [ADDRSIZE:0] rptr
);

  reg [ADDRSIZE:0] rbin;
  wire [ADDRSIZE:0] rgraynext, rbinnext;

  //-------------------
  // GRAYSTYLE2 pointer
  //-------------------
  always @(posedge rclk or negedge rrst_n)
    if (!rrst_n)
      {rbin, rptr} <=0;
    else
      {rbin, rptr} <= {rbinnext, rgraynext};

  // Memory read-address pointer (okay to use binary to address memory)
  assign raddr = rbin[ADDRSIZE-1:0];
  assign rbinnext = rbin + (rinc & ~rempty);
  assign rgraynext = (rbinnext >> 1) ^ rbinnext;

  //---------------------------------------------------------------
  // FIFO empty when the next rptr == synchronized wptr or on reset
  //---------------------------------------------------------------
  assign rempty_val = (rgraynext == rq2_wptr);

  always @(posedge rclk or negedge rrst_n)
    if (!rrst_n)
      rempty <= 1'b1;
    else
      rempty <= rempty_val;

endmodule

module sync_r2w
#(
  parameter ADDRSIZE = 4
)
(
  input   wclk, wrst_n,
  input   [ADDRSIZE:0] rptr,
  output reg  [ADDRSIZE:0] wq2_rptr
);

  reg [ADDRSIZE:0] wq1_rptr;

  always @(posedge wclk or negedge wrst_n)
    if (!wrst_n) 
      {wq2_rptr, wq1_rptr} <= 0;
    else 
      {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr};

endmodule

module sync_w2r
#(
  parameter ADDRSIZE = 4
)
(
  input   rclk, rrst_n,
  input   [ADDRSIZE:0] wptr,
  output reg [ADDRSIZE:0] rq2_wptr
);

  reg [ADDRSIZE:0] rq1_wptr;

  always @(posedge rclk or negedge rrst_n)
    if (!rrst_n)
      {rq2_wptr, rq1_wptr} <=0;
    else
      {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr};

endmodule

module wptr_full
#(
  parameter ADDRSIZE = 4
)
(
  input   winc, wclk, wrst_n,
  input   [ADDRSIZE:0] wq2_rptr,
  output reg  wfull,
  output  [ADDRSIZE-1:0] waddr,
  output reg [ADDRSIZE:0] wptr
);

  reg [ADDRSIZE:0] wbin;
  wire [ADDRSIZE:0] wgraynext, wbinnext;

  // GRAYSTYLE2 pointer
  always @(posedge wclk or negedge wrst_n)
    if (!wrst_n)
      {wbin, wptr} <= 0;
    else
      {wbin, wptr} <= {wbinnext, wgraynext};

  // Memory write-address pointer (okay to use binary to address memory)
  assign waddr = wbin[ADDRSIZE-1:0];
  assign wbinnext = wbin + (winc & ~wfull);
  assign wgraynext = (wbinnext >> 1) ^ wbinnext;

  //------------------------------------------------------------------
  // Simplified version of the three necessary full-tests:
  // assign wfull_val=((wgnext[ADDRSIZE] !=wq2_rptr[ADDRSIZE] ) &&
  // (wgnext[ADDRSIZE-1] !=wq2_rptr[ADDRSIZE-1]) &&
  // (wgnext[ADDRSIZE-2:0]==wq2_rptr[ADDRSIZE-2:0]));
  //------------------------------------------------------------------
  assign wfull_val = (wgraynext == {~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});

  always @(posedge wclk or negedge wrst_n)
    if (!wrst_n)
      wfull <= 1'b0;
    else
      wfull <= wfull_val;

endmodule