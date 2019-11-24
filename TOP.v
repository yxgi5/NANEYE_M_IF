module TOP # 
( 
	parameter   SAMPLE_CLOCK_PERIOD_PS = 2500,      // sample clk 400MHz
    parameter   TRANS_CLOCK_PERIOD_MIN_PS = 7987,   // max data clk 62.6MHz
    parameter   SYSTEM_CLOCK_PERIOD_PS = 20833,     // system clk 48MHz
    parameter   CONFIG_BIT_PERIOD_NS = 400,         // 2.5MHz
    parameter   A_WIDTH = 10,
    parameter   D_WIDTH = 10
) 
(
    RESET,
    SCLOCK,
    SYS_CLOCK,
    RX_DATA,
    ERROR_OUT,
    ERROR_OUT2,
    //DEBUG_OUT,
    BREAK_N,
    TX_OE_N,
    TX_DAT,
    TX_CLK,
    PAR_RAW,
    PCLK,
    H_SYNC,
    V_SYNC,
    I2C_SDA,
    I2C_SCL,

    MCLK_SPEED,
    IDLE_MODE,
    MCLK_MODE,
    ROWS_DELAY
);

input                       RESET;
input                       SCLOCK;         // 400MHz sampling clock
input                       SYS_CLOCK;      // 48MHz system clock.
input                       RX_DATA;

output                      ERROR_OUT;
output                      ERROR_OUT2;
//output  [31:0]              DEBUG_OUT;

output  [1:0]               BREAK_N;
output                      TX_OE_N;
output                      TX_DAT;
output                      TX_CLK;

output  [D_WIDTH-1:0]       PAR_RAW;
output                      PCLK;
output                      V_SYNC;
output                      H_SYNC;
inout                       I2C_SDA;
output                      I2C_SCL;    

output                      MCLK_SPEED;
output                      IDLE_MODE;
output  [1:0]               MCLK_MODE;
output  [4:0]               ROWS_DELAY;       


wire                        CONFIG_DONE;
wire                        CONFIG_EN;
wire                        SYNC_START;
wire                        FRAME_START;
wire                        DEC_OUTPUT;
wire                        DEC_OUTPUT_EN;
wire                        RSYNC;
wire    [D_WIDTH+1:0]       PAR_OUTPUT;
wire                        PAR_OUTPUT_EN;
wire                        PIXEL_ERROR;
wire                        LINE_END;
wire    [15:0]              LINE_PERIOD;
wire    [31:0]              DEBUG_OUT;
wire    [15:0]              DEBUG_OUT2;
wire    [15:0]              LINE_PERIOD2;

//wire                        MCLK_SPEED;
//wire                        IDLE_MODE;
//wire  [1:0]                 MCLK_MODE;
//wire  [4:0]                 ROWS_DELAY;


RX_DECODER
#(
    .G_CLOCK_PERIOD_PS          (SAMPLE_CLOCK_PERIOD_PS)      // sample clk 400MHz
)U_RX_DECODER
(
    .RESET                      (RESET),
    .CLOCK                      (SCLOCK),
    .ENABLE                     (1'b1),     // alway enable
    .RSYNC                      (RSYNC),
    .INPUT                      (RX_DATA),
    .CONFIG_DONE                (CONFIG_DONE),
    .CONFIG_EN                  (CONFIG_EN),
    .SYNC_START                 (SYNC_START),
    .FRAME_START                (FRAME_START),
    .V_SYNC                     (V_SYNC),
    .H_SYNC                     (H_SYNC),
    .OUTPUT                     (DEC_OUTPUT),
    .OUTPUT_EN                  (DEC_OUTPUT_EN),
    .ERROR_OUT                  (ERROR_OUT),
    .DEBUG_OUT                  (DEBUG_OUT)
);

RX_DESERIALIZER
#(
    .C_ROWS                     (320),
    .C_COLUMNS                  (320)
)U_RX_DESERIALIZER
(
    .RESET                      (RESET),
    .CLOCK                      (SCLOCK),
    .FRAME_START                (FRAME_START),
    .SER_INPUT                  (DEC_OUTPUT),
    .SER_INPUT_EN               (DEC_OUTPUT_EN),
    .DEC_RSYNC                  (RSYNC),
    .PAR_OUTPUT                 (PAR_RAW),
    .PAR_OUTPUT_EN              (PAR_OUTPUT_EN),
    .PCLK                       (PCLK),
    .PIXEL_ERROR                (PIXEL_ERROR),
    .LINE_END                   (LINE_END),
    //.LINE_PERIOD                (LINE_PERIOD),
    .ERROR_OUT                  (ERROR_OUT2),
    .DEBUG_OUT                  (DEBUG_OUT2)
);

LINE_PERIOD_CALC
#(
    .G_CLOCK_PERIOD_PS          (20833),            // system clk 48MHz
    .G_LINE_PERIOD_MIN_NS       (30000),            // TPP=95844 328PP=31436
    .G_LINE_PERIOD_MAX_NS       (120000)
)U_LINE_PERIOD_CALC
(
    .RESET                      (RESET),
    .CLOCK                      (SYS_CLOCK),
    .SCLOCK                     (SCLOCK),
    .FRAME_START                (FRAME_START),
    .PAR_DATA_EN                (PAR_OUTPUT_EN),
    .PIXEL_ERROR                (PIXEL_ERROR),
    .LINE_END                   (LINE_END),
    .LINE_PERIOD                (LINE_PERIOD2)
);

BREAK_LOGIC U_BREAK_LOGIC
(
    .RESET                      (RESET),
    .CLOCK                      (SCLOCK),
    .CONFIG_EN                  (CONFIG_EN),
    .SYNC_START                 (SYNC_START),
    .DEC_OUT_EN                 (DEC_OUTPUT_EN),
    .BREAK_N_OUTPUT             (BREAK_N)
);

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
    .RESET                      (RESET),
    .CLOCK                      (SYS_CLOCK),
    .START                      (CONFIG_EN),
    .LINE_PERIOD                (LINE_PERIOD2),
    .INPUT                      (pdata),
    .RD_ADDR                    (paddr),
    .RD_EN                      (rd_en),
    .TX_END                     (CONFIG_DONE),
    .TX_DAT                     (TX_DAT),
    .TX_CLK                     (TX_CLK),
    .TX_OE                      (TX_OE_N)
);

wire                            wr_en;
wire    [7:0]                   pdata1;
wire    [7:0]                   paddr1;

CONV_REGS U_CONV_REGS
(
    .CLOCK                      (SYS_CLOCK),                                     // 48MHz system clock
    .RESET                      (RESET),                                         // reset active high

    .WE_A                       (wr_en),                                         // 和i2c_slave模块连接
    .ADD_A                      (paddr1[2:0]),                                   // 和i2c_slave模块连接
    .DAT_A                      (pdata1),                                        // 和i2c_slave模块连接

    .RE_B                       (rd_en),
    .ADD_B                      (paddr[1:0]),                                    // 和config_tx2模块连接
    .DAT_B                      (pdata),                                         // 和config_tx2模块连接
    
    .MCLK_SPEED                 (MCLK_SPEED),                                    // 和rx_decoder模块等连接
    .MCLK_MODE                  (MCLK_MODE),                                     // 和rx_decoder模块等连接
    .ROWS_DELAY                 (ROWS_DELAY),                                    // 和rx_decoder模块等连接
    .IDLE_MODE                  (IDLE_MODE)                                      // 和rx_decoder模块等连接
);

I2C_SLAVE U_I2C_SLAVE
(      
    .CLOCK                      (SYS_CLOCK),
    .RESET                      (RESET),
	.SCL                        (I2C_SCL),      // 100kHz for i2c
	.SDA                        (I2C_SDA),
    .WR_EN                      (wr_en),
    .ADD_OUT                    (paddr1[2:0]), 
    .DAT_OUT                    (pdata1)
);


endmodule


