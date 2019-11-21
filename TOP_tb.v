// clk_div_5_5_tb.v
// Testbench

`timescale 1ps/ 1ps
`define JITTER  0               // 希望出现的的jitter百分比+1, 比如希望20%, 这里就给21
`define JITTER_PATTERN    0     // 0: +/    1:+     2:-
//`define CheckByteNum 6000
//`ifndef xx
//`define xx yy // or parameter xx = yy;
//`endif
//`undef XX

module TOP_tb();

reg     RESET_tb;
reg     CLOCK_tb;   // 180MHz sampling clock
reg     UCLOCK_tb;  // 48MHz system clock.
reg     ENABLE_tb;
//reg     RSYNC_tb;
reg     INPUT_tb;
wire    INPUT_N_tb;
//reg     CONFIG_DONE_tb;
wire    CONFIG_DONE_tb;
wire    CONFIG_EN_tb;
wire    SYNC_START_tb;
wire    FRAME_START_tb;
wire    OUTPUT_tb;
wire    OUTPUT_EN_tb;
wire    NANEYE3A_NANEYE2B_N_tb;
wire    ERROR_OUT_tb;
wire    [31:0]  DEBUG_OUT_tb;

wire    RSYNC_tb;

wire    [11:0]  PAR_OUTPUT_tb;
wire    PAR_OUTPUT_EN_tb;
wire    PIXEL_ERROR_tb;
wire    LINE_END_tb;
wire    [15:0]  LINE_PERIOD_tb;
wire    ERROR_OUT2_tb;
wire    [15:0]  DEBUG_OUT2_tb;

wire    [15:0]  LINE_PERIOD2_tb;

//reg     addr_mem[0:80000000];
reg     i;
integer count;
integer fp_r;
//integer     j;
integer     rand;

RX_DECODER
#(
    .G_CLOCK_PERIOD_PS          (2500)      // sample clk 400MHz
)U_RX_DECODER
(
    .RESET                      (RESET_tb),
    .CLOCK                      (CLOCK_tb),
    .ENABLE                     (ENABLE_tb),
    .RSYNC                      (RSYNC_tb),
    .INPUT                      (INPUT_tb),
    //.INPUT                      (INPUT_N_tb),
    .CONFIG_DONE                (CONFIG_DONE_tb),
    .CONFIG_EN                  (CONFIG_EN_tb),
    .SYNC_START                 (SYNC_START_tb),
    .FRAME_START                (FRAME_START_tb),
    .OUTPUT                     (OUTPUT_tb),
    .OUTPUT_EN                  (OUTPUT_EN_tb),
    .NANEYE3A_NANEYE2B_N        (NANEYE3A_NANEYE2B_N_tb),
    .ERROR_OUT                  (ERROR_OUT_tb),
    .DEBUG_OUT                  (DEBUG_OUT_tb)
);


RX_DESERIALIZER
#(
    .C_ROWS                     (320),
    .C_COLUMNS                  (320)
)U_RX_DESERIALIZER
(
    .RESET                      (RESET_tb),
    .CLOCK                      (CLOCK_tb),
    .NANEYE3A_NANEYE2B_N        (NANEYE3A_NANEYE2B_N_tb),
    .FRAME_START                (FRAME_START_tb),
    .SER_INPUT                  (OUTPUT_tb),
    .SER_INPUT_EN               (OUTPUT_EN_tb),
    .DEC_RSYNC                  (RSYNC_tb),
    .PAR_OUTPUT                 (PAR_OUTPUT_tb),
    .PAR_OUTPUT_EN              (PAR_OUTPUT_EN_tb),
    .PIXEL_ERROR                (PIXEL_ERROR_tb),
    .LINE_END                   (LINE_END_tb),
    .LINE_PERIOD                (LINE_PERIOD_tb),
    .ERROR_OUT                  (ERROR_OUT2_tb),
    .DEBUG_OUT                  (DEBUG_OUT2_tb)
);


LINE_PERIOD_CALC
#(
    .G_CLOCK_PERIOD_PS          (20833),            // system clk 48MHz
    .G_LINE_PERIOD_MIN_NS       (30000),            // TPP=95844 328PP=31436
    .G_LINE_PERIOD_MAX_NS       (120000)
)U_LINE_PERIOD_CALC
(
    .RESET                      (RESET_tb),
    .CLOCK                      (UCLOCK_tb),
    .SCLOCK                     (CLOCK_tb),
    .FRAME_START                (FRAME_START_tb),
    .PAR_DATA_EN                (PAR_OUTPUT_EN_tb),
    .PIXEL_ERROR                (PIXEL_ERROR_tb),
    .LINE_END                   (LINE_END_tb),
    .LINE_PERIOD                (LINE_PERIOD2_tb)
);


parameter C_ADDR_W_tb = 10;

wire    [C_ADDR_W_tb-1:0]       DPRAM_WR_ADDR_tb;
wire    [C_ADDR_W_tb-1:0]       DPRAM_RD_ADDR_tb;
wire                            DPRAM_WE_tb;
wire                            DPRAM_RD_PAGE_tb;
wire                            LINE_FINISHED_tb;

DPRAM_WR_CTRL 
#(
    .C_ADDR_W                   (C_ADDR_W_tb)
)U_DPRAM_WR_CTRL
(
    .RESET                      (RESET_tb),
    .CLOCK                      (CLOCK_tb),
    .PULSE                      (PAR_OUTPUT_EN_tb),
    .PIXEL_ERROR                (PIXEL_ERROR_tb),
    .LINE_SYNC                  (LINE_END_tb),
    .FRAME_SYNC                 (FRAME_START_tb),
    .DPRAM_WR_ADDR              (DPRAM_WR_ADDR_tb),
    .DPRAM_WE                   (DPRAM_WE_tb),
    .DPRAM_RD_PAGE              (DPRAM_RD_PAGE_tb),
    .LINE_FINISHED              (LINE_FINISHED_tb)
);

parameter A_WIDTH_tb = C_ADDR_W_tb;
parameter D_WIDTH_tb = 10;

wire    [D_WIDTH_tb-1:0]        DOA_tb;
wire    [D_WIDTH_tb-1:0]        DOB_tb;

DPRAM
#(
    .A_WIDTH                    (A_WIDTH_tb),
    .D_WIDTH                    (D_WIDTH_tb)
)U_DPRAM
(
    .CLKA                       (UCLOCK_tb),
    .CLKB                       (CLOCK_tb),
    .ENA                        (1'b1),
    .ENB                        (1'b1),
    .WEA                        (1'b0),
    .WEB                        (DPRAM_WE_tb),
    .ADDRA                      (DPRAM_RD_ADDR_tb),
    .ADDRB                      (DPRAM_WR_ADDR_tb),
    .DIA                        ({(D_WIDTH_tb){1'bx}}),
    .DIB                        (PAR_OUTPUT_tb[10:1]),
    .DOA                        (DOA_tb),
    .DOB                        (DOB_tb)
);

wire                            DPRAM_RDAT_VALID_tb;
wire                            H_SYNC_tb;
wire                            V_SYNC_tb;

DPRAM_RD_CTRL
#(
    .C_ROWS                     (320),
    .C_COLUMNS                  (320),
    .C_ADDR_W                   (C_ADDR_W_tb)
)U_DPRAM_RD_CTRL
(
    .RESET                      (RESET_tb),
    .SCLOCK                     (CLOCK_tb),
    .CLOCK                      (UCLOCK_tb),
    .NANEYE3A_NANEYE2B_N        (NANEYE3A_NANEYE2B_N_tb),
    .FRAMING_ERROR              (1'b0),
    .FRAME_START                (FRAME_START_tb),
    .LINE_FINISHED              (LINE_END_tb),
    .DPRAM_RD_PAGE              (DPRAM_RD_PAGE_tb),
    .DPRAM_RD_ADDR              (DPRAM_RD_ADDR_tb),
    .DPRAM_RDAT_VALID           (DPRAM_RDAT_VALID_tb),
    .H_SYNC                     (H_SYNC_tb),
    .V_SYNC                     (V_SYNC_tb)
);

wire    [D_WIDTH_tb-1:0]        PAR_RAW_OUT_tb;

OUT_REG
#(
    .D_WIDTH                    (D_WIDTH_tb)
)U_OUT_REG
(
    .RESET                      (RESET_tb),
    .CLOCK                      (UCLOCK_tb),
    .RDAT_VALID                 (DPRAM_RDAT_VALID_tb),
    .PAR_INPUT                  (DOA_tb),
    .PAR_OUTPUT                 (PAR_RAW_OUT_tb)
);

wire    [1:0]                   BREAK_N_OUTPUT_tb;

BREAK_LOGIC U_BREAK_LOGIC
(
    .RESET                      (RESET_tb),
    .CLOCK                      (CLOCK_tb),
    .CONFIG_EN                  (CONFIG_EN_tb),
    .SYNC_START                 (SYNC_START_tb),
    .DEC_OUT_EN                 (OUTPUT_EN_tb),
    .BREAK_N_OUTPUT             (BREAK_N_OUTPUT_tb)
);

//wire                            TX_END_tb;
wire                            TX_DAT_tb;
wire                            TX_CLK_tb;
wire                            TX_OE_N_tb;
wire                            TX_OE_tb;
wire    [15:0]                  pdata;
wire    [2:0]                   paddr;
wire                            rd_en;

CONFIG_TX
#(
    .CLOCK_PERIOD_PS            (20833),    // 48MHz
    .BIT_PERIOD_NS              (400),      // 2.5MHz
    .C_NO_CFG_BITS              (24)
)U_CONFIG_TX
(
    .RESET                      (RESET_tb),
    .CLOCK                      (UCLOCK_tb),
    .START                      (CONFIG_EN_tb),
    .LINE_PERIOD                (LINE_PERIOD2_tb),
    .INPUT                      (pdata),
    .RD_ADDR                    (paddr),
    .RD_EN                      (rd_en),
    //.TX_END                     (TX_END_tb),
    .TX_END                     (CONFIG_DONE_tb),
    .TX_DAT                     (TX_DAT_tb),
    .TX_CLK                     (TX_CLK_tb),
    .TX_OE                      (TX_OE_tb)
);

CONV_REGS U_CONV_REGS
(
    .CLOCK                      (UCLOCK_tb),                                      // 48MHz system clock
    .RESET                      (RESET_tb),                                      // reset active high

    .WE_A                       (1'b0),                                        //
    .ADD_A                      (3'b000),                                      // 
    .DAT_A                      (8'h00),                                      //

    .RE_B                       (rd_en),
    .ADD_B                      (paddr[1:0]),                                      // 
    .DAT_B                      (pdata)                                       //
);


assign      TX_OE_N_tb  =       ~TX_OE_tb;

initial
begin
//    j=0;
    CLOCK_tb = 1;
    UCLOCK_tb = 1;
    RESET_tb = 1;

//   #40 reset = 0;
//   #100 $finish;
    ENABLE_tb = 1;
    //RSYNC_tb = 1;
    //INPUT_tb = 0;
    //CONFIG_DONE_tb = 0;

    //#500
    //INPUT_tb = 1;
    //#700
    //INPUT_tb = 0;

    #40000 
    RESET_tb = 0;
    //#2500000
    //CONFIG_DONE_tb = 1;
    //RSYNC_tb = 0;
    //#(10+2778*2)
    //CONFIG_DONE_tb = 0;
end

initial
begin
   //$readmemh("./data.dat",addr_mem);
    fp_r=$fopen("./data.dat","r");//以读的方式打开文件
end

initial
begin
    //INPUT_tb = addr_mem[0];
    $display("Begin READING-----READING-----READING-----READING");
    while(! $feof(fp_r))
    begin
        count=$fscanf(fp_r,"%b" ,i) ;//每次读一行
        INPUT_tb = i;
        if(`JITTER != 0)
        begin
            case (`JITTER_PATTERN)
            0: rand = $random % `JITTER;
            1: rand = $urandom % `JITTER;
            2: rand = -1*($urandom % `JITTER);
            endcase
        end
        else
        begin
            rand = 0;
        end
        //$display("random jitter %0d%%",rand);
        //# (13889 + rand*13889/100);  // 36MHz data_in
        # 7987;                        // 62.6MHz data_in
    end
    $fclose(fp_r);

    // //for(j = 0; j <=`CheckByteNum; j = j+1)
    //for (;;)
    // begin
    //    INPUT_tb = addr_mem[j]; 
    //    j=j+1;
    //    //$display("DATA %0h ---READ RIGHT",INPUT_tb);
    //    //@(posedge SCLOCK or negedge SCLOCK );

    //    # (13889);  // 36MHz data_in

    //    //rand = ($random % 20);    +/-20% jitter
    //    //rand = ($urandom % 20); // +20% jitter
    //    //rand = -1*($urandom % 20); // -20% jitter
    //    //$display("random jitter %0d%%",rand);
    //    //# (13889 + rand*13889/100);  // 36MHz data_in data rate with jitter
    // end
end  

always
begin
    #1250 CLOCK_tb = ~CLOCK_tb; // 400MHz sample clock
end

always
begin
    #10416 UCLOCK_tb = ~UCLOCK_tb; // 48MHz system clock
end

/*
always@(posedge CLOCK_tb or RESET_tb)		
begin
  if (RESET_tb == 1'b1)
  begin
	CONFIG_DONE_tb <= 0;
  end
  else
  begin
    if(CONFIG_EN_tb == 1'b1)
    begin
        CONFIG_DONE_tb <= 1;
    end
    else
    begin
        CONFIG_DONE_tb <= 0;
    end
  end
end
*/

assign INPUT_N_tb = ~INPUT_tb;

endmodule


