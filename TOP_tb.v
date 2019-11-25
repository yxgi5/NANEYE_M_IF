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
wire    CONFIG_DONE_tb;

wire    [1:0]               BREAK_N_tb;
wire                        TX_OE_N_tb;
wire                        TX_DAT_tb;
wire                        TX_CLK_tb;


parameter   D_WIDTH = 10;

wire  [D_WIDTH-1:0]       PAR_RAW_tb;
wire                      PCLK_tb;
wire                      V_SYNC_tb;
wire                      H_SYNC_tb;

//wire                      I2C_SDA_tb;
//wire                      I2C_SCL_tb;  


wire                      MCLK_SPEED_tb;
wire                      IDLE_MODE_tb;
wire  [1:0]               MCLK_MODE_tb;
wire  [4:0]               ROWS_DELAY_tb;

//reg     addr_mem[0:80000000];
reg     i;
integer count;
integer fp_r;
integer     j;
integer     rand;


TOP U_TOP
(
    .RESET                      (RESET_tb),
    .SCLOCK                     (CLOCK_tb),
    .SYS_CLOCK                  (UCLOCK_tb),
    .RX_DATA                    (INPUT_tb),
    .CONFIG_DONE_O              (CONFIG_DONE_tb),
    .ERROR_OUT                  (),
    .ERROR_OUT2                 (),
    //.DEBUG_OUT                 (),
    .BREAK_N                    (BREAK_N_tb),
    .TX_OE_N                    (TX_OE_N_tb),
    .TX_DAT                     (TX_DAT_tb),
    .TX_CLK                     (TX_CLK_tb),
    .PAR_RAW                    (PAR_RAW_tb),
    .PCLK                       (PCLK_tb),
    .H_SYNC                     (H_SYNC_tb),
    .V_SYNC                     (V_SYNC_tb),

    .I2C_SDA                    (I2C_SDA_tb),
    .I2C_SCL                    (I2C_SCL_tb),

    .MCLK_SPEED                 (MCLK_SPEED_tb),
    .IDLE_MODE                  (IDLE_MODE_tb),
    .MCLK_MODE                  (MCLK_MODE_tb),
    .ROWS_DELAY                 (ROWS_DELAY_tb)
);



initial
begin
    j=0;
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

always @ (posedge CLOCK_tb)
begin
    if (CONFIG_DONE_tb)
    begin
        j = 1;
    end
end

initial
begin
    while(j==0)
    begin
        # 1;
    end

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


