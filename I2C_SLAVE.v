
module I2C_SLAVE # 
( 
	parameter   I2C_SLAVE_ADDR  = 7'b1010000,   // i2c bus addr
    parameter   DEBOUNCE_LEN    = 10            // 10 ticks = 208nS @ 48MHz
    // TODO: implement sample delay
) 
(      
    CLOCK,                                      // 48MHz system clock
    RESET,                                      // reset active high
	SCL,
	SDA,

    RD_EN,                                      //
    ADD_IN,                                     // 
    DAT_OUT,                                    //

    MCLK_SPEED,                                 //
    MCLK_MODE,                                  //
    ROWS_DELAY,                                 //
    IDLE_MODE                                   //
);

//parameter                   S_IDLE      = 4'd0;
//parameter                   S_START     = 4'd1;
//parameter                   S_INDEX     = 4'd2;
//parameter                   S_READ      = 4'd3;
//parameter                   S_DATE      = 4'd4;
//parameter                   S_STOP      = 4'd5;

input                       CLOCK;
input                       RESET;
input                       SCL;
inout                       SDA;

inout                       RD_EN;
input   [1:0]               ADD_IN;
output  [15:0]              DAT_OUT;
reg     [15:0]              DAT_OUT;

output                      MCLK_SPEED;
output                      IDLE_MODE;
output  [1:0]               MCLK_MODE;
output  [4:0]               ROWS_DELAY;

reg                         I_SDA_ACK_OUT;
wire                        I_SDA_IN;

reg                         I_SDA_DEB;
reg                         I_SCL_DEB;
reg                         I_SDA_DEB_1;
reg                         I_SCL_DEB_1;
reg [DEBOUNCE_LEN-1:0]      I_SDA_PIPE;
reg [DEBOUNCE_LEN-1:0]      I_SCL_PIPE;

reg     [7:0]               I_CTRL_BYTE;
reg     [7:0]               I_REG_ADDR;
reg     [7:0]               I_REG_ADDR_1; // lotch I_REG_ADDR for output until next I_CTRL_BYTE update complete
reg     [7:0]               I_SDA_DATA; // 输入的
reg                         I_SDA_OUT_OE;


wire                        I_SCL_FALL; 
wire                        I_SCL_RISE; 
wire                        I_SCL_HIGH; 
wire                        I_SCL_LOW; 
wire                        I_SDA_FALL;
wire                        I_SDA_RISE;
wire                        I_SDA_HIGH;
wire                        I_SDA_LOW;
//reg     [7:0]               I_SREG_SDA_IN;
reg     [7:0]               I_SREG_SDA_OUT;
//reg     [3:0]               I_BIT_CNT;

reg                         I_WR_OP;
reg                         I_RD_OP;
reg     [7:0]               I_WR_VAL; // for output
reg     [7:0]               I_RD_VAL;

reg                         I_START_FF;
reg                         I_START_FF_1;
wire                        I_START_EDGE;
reg     [1:0]               I_START_EDGE_CNT;
//enum bit {RD_OP,WR_OP}      I_WR_OP;//1bit宽，2值数据类型
parameter HardWriteAddress = I2C_SLAVE_ADDR;
parameter HardReadAddress  = I2C_SLAVE_ADDR | 1'b1;		


parameter    S_IDLE     =3'b000;
parameter    S_READCTRL =3'b001;
parameter    S_READREG  =3'b010;
parameter    S_READ     =3'b011;
parameter    S_WRITE    =3'b100;
parameter    S_STOP     =3'b101;

reg [2:0]   ST_FSM_STATE;

reg [3:0]   sh8out_state;
reg [3:0]   sh8in_state;
reg [1:0]   ackout_state;

//-------------------------并行数据串行状态-----------------------------
// shift8_out从状态机的状态定义
parameter   sh8out_bit7 = 4'b0000;
parameter   sh8out_bit6 = 4'b0001;
parameter   sh8out_bit5 = 4'b0010;
parameter   sh8out_bit4 = 4'b0011;		
parameter   sh8out_bit3 = 4'b0100;
parameter   sh8out_bit2 = 4'b0101;
parameter   sh8out_bit1 = 4'b0110;
parameter   sh8out_bit0 = 4'b0111;
parameter   sh8out_end  = 4'b1000;

//--------------------------串行数据并行状态----------------------------
// shift8in从状态机的状态定义
parameter   sh8in_begin    = 4'b0000;
parameter   sh8in_bit7     = 4'b0001;
parameter   sh8in_bit6     = 4'b0010;
parameter   sh8in_bit5     = 4'b0011;		
parameter   sh8in_bit4     = 4'b0100;
parameter   sh8in_bit3     = 4'b0101;
parameter   sh8in_bit2     = 4'b0110;
parameter   sh8in_bit1     = 4'b0111;
parameter   sh8in_bit0     = 4'b1000;
parameter   sh8in_ack      = 4'b1001;
parameter   sh8in_end      = 4'b1010;

//--------------------------ACK输出状态----------------------------
parameter   ack_begin  = 2'b00;
parameter   ack_bit    = 2'b01;
parameter   ack_end    = 2'b10;


reg     I_ACK_OE;
reg     I_RD_OE;
wire    I_SDA_SOURCE_1;
wire    I_SDA_SOURCE_2;
assign  I_SDA_SOURCE_1      = (I_ACK_OE)     ? I_SDA_ACK_OUT : 1'b0; // 考虑直接I_SDA_ACK_OUT 换成0
assign  I_SDA_SOURCE_2      = (I_RD_OE)      ? I_SREG_SDA_OUT[7] : 1'b0;
assign  I_SDA_OUT           = (I_SDA_SOURCE_1 | I_SDA_SOURCE_2);
assign  SDA                 = (I_SDA_OUT_OE) ? I_SDA_OUT : 1'bz;
assign  I_SDA_IN            = SDA;

assign  I_SCL_FALL          =   ~I_SCL_DEB & I_SCL_DEB_1; 
assign  I_SCL_RISE          =   I_SCL_DEB & ~I_SCL_DEB_1; 
assign  I_SCL_HIGH          =   I_SCL_DEB & I_SCL_DEB_1; 
assign  I_SCL_LOW           =   ~I_SCL_DEB & ~I_SCL_DEB_1; 
assign  I_SDA_FALL          =   ~I_SDA_DEB & I_SDA_DEB_1; 
assign  I_SDA_RISE          =   I_SDA_DEB & ~I_SDA_DEB_1; 
assign  I_SDA_HIGH          =   I_SDA_DEB & I_SDA_DEB_1; 
assign  I_SDA_LOW           =   ~I_SDA_DEB & ~I_SDA_DEB_1; 

// debounce sda and scl
// 去抖窗口 10 ticks
// 跳变之后稳定10个连续的电平才认为跳变完毕
always @(posedge CLOCK)
begin
    if (RESET == 1'b1) 
    begin
        I_SDA_PIPE <= {DEBOUNCE_LEN{1'b1}};
        I_SDA_DEB <= 1'b1;
        I_SDA_DEB_1 <= 1'b1;
        I_SCL_PIPE <= {DEBOUNCE_LEN{1'b1}};
        I_SCL_DEB <= 1'b1;
        I_SCL_DEB_1 <= 1'b1;
        I_SREG_SDA_OUT <= 8'b0;
    end
    else
    begin
        I_SDA_PIPE <= {I_SDA_PIPE[DEBOUNCE_LEN-2:0], I_SDA_IN}; // bit shift
        I_SCL_PIPE <= {I_SCL_PIPE[DEBOUNCE_LEN-2:0], SCL};      // bit shift
        if (&I_SCL_PIPE[DEBOUNCE_LEN-1:1] == 1'b1)
        begin
            I_SCL_DEB <= 1'b1;
            I_SCL_DEB_1 <= I_SCL_DEB;
        end
        else if (|I_SCL_PIPE[DEBOUNCE_LEN-1:1] == 1'b0)
        begin
            I_SCL_DEB <= 1'b0;
            I_SCL_DEB_1 <= I_SCL_DEB;
        end
        if (&I_SDA_PIPE[DEBOUNCE_LEN-1:1] == 1'b1)
        begin
            I_SDA_DEB <= 1'b1;
            I_SDA_DEB_1 <= I_SDA_DEB;
        end
        else if (|I_SDA_PIPE[DEBOUNCE_LEN-1:1] == 1'b0)
        begin
            I_SDA_DEB <= 1'b0;
            I_SDA_DEB_1 <= I_SDA_DEB;
        end
    end
end

//-----------------------------检测start/stop----------------------------------
always @ (posedge CLOCK)
begin
    if(RESET == 1'b1)
        begin     
        I_START_FF      <= 1'b0;
        I_START_FF_1    <= 1'b0;
        I_START_EDGE_CNT <= 2'b0;
    end
    else
    begin
        if (I_SCL_HIGH & I_SDA_FALL)
        begin
            I_START_FF  <= 1'b1;
            I_START_FF_1  <= I_START_FF;
            if(I_START_EDGE_CNT<2)
            begin
                I_START_EDGE_CNT <= I_START_EDGE_CNT+1'b1;
            end
        end
        else if (I_SCL_HIGH & I_SDA_RISE )
        begin
            I_START_FF      <= 1'b0;
            I_START_FF_1    <= 1'b0;
            I_START_EDGE_CNT <= 2'b0;
        end
    end
end
assign I_START_EDGE = I_START_FF & ~I_START_FF_1;




reg         FF;         //标志寄存器
reg         RFF;         //标志寄存器
//-----------------------------主状态机程序----------------------------------
always @ (posedge CLOCK)
begin
    if(RESET == 1'b1)
    begin
        I_WR_VAL        <= 8'h00;
        I_RD_VAL        <= 8'h00;
        I_REG_ADDR      <= 8'h00;
        I_REG_ADDR_1    <= 8'h00;
        I_CTRL_BYTE     <= 8'h00;
        I_SDA_DATA      <= 8'h00;
        I_SDA_OUT_OE    <= 1'b0;
        I_ACK_OE        <= 0;
        I_RD_OE         <= 0;
        I_SDA_ACK_OUT   <= 1'b0;
        ST_FSM_STATE    <= S_IDLE;
        FF              <= 0;
        RFF             <= 1;
        sh8out_state    <= sh8out_bit7;
        sh8in_state     <= sh8in_begin;
        ackout_state    <= ack_begin;
        I_WR_OP         <= 0;
        I_RD_OP         <= 0;
    end
    else
    casex(ST_FSM_STATE)
    S_IDLE:
    begin
        if(I_START_EDGE)
        begin
            ST_FSM_STATE    <= S_READCTRL;
            sh8in_state     <= sh8in_begin;
            FF              <= 0;
        end
        else
        begin
            ST_FSM_STATE    <= S_IDLE;
        end
    end
    S_READCTRL:
    begin
        if(FF == 0) 
        begin
            shift8in(I_CTRL_BYTE);
        end
        else if(I_CTRL_BYTE==HardWriteAddress)
        begin
            if(I_START_EDGE_CNT==0)
            begin
                ST_FSM_STATE    <= S_IDLE;
            end
            else
            begin
                ST_FSM_STATE    <= S_READREG;
                sh8in_state     <= sh8in_begin;
                FF              <= 0;
            end
        end
        else if(I_CTRL_BYTE==HardReadAddress)
        begin
            if(I_START_EDGE_CNT==0)
            begin
                ST_FSM_STATE    <= S_IDLE;
            end
            else
            begin
                I_RD_VAL        <= 8'b0;
                I_WR_OP         <= 0;
                I_RD_OP         <= 1;
                if(I_RD_OP)
                begin
                    I_RD_OP         <= 0;
                    RFF             <= 0;
                    ST_FSM_STATE    <= S_READ;
                    sh8in_state     <= sh8in_begin;
                    FF              <= 0;
                end
            end
        end
        else
        begin
            ST_FSM_STATE    <= S_IDLE;
        end
    end

    S_READREG:
    begin
        if(FF == 0) 
        begin
            shift8in(I_REG_ADDR);
        end
        else
        begin
            // TODO: 限制范围
            ST_FSM_STATE    <= S_WRITE;
            sh8in_state     <= sh8in_begin;
            FF              <= 0;
            I_REG_ADDR_1    <= I_REG_ADDR;   // for output
        end
    end

    S_WRITE:
    begin
        if(FF == 0) 
        begin
            if(I_START_EDGE_CNT==2)
            begin
                ST_FSM_STATE    <= S_READCTRL;
                sh8in_state     <= sh8in_begin;
            end
            else
            begin
                shift8in(I_SDA_DATA);
            end
        end
        else
        begin
            I_WR_OP         <= 1;
            I_RD_OP         <= 0;
            I_WR_VAL        <= I_SDA_DATA;
            
            if(I_WR_OP)
            begin
                ST_FSM_STATE    <= S_STOP;
                I_WR_OP         <= 0;
                FF              <= 0;
            end
        end
    end

    S_READ:
    begin
        if(FF == 0) 
        begin
            if(RFF == 0)
            begin
                I_SREG_SDA_OUT  <= I_RD_VAL;
                RFF <= 1;
            end
            else
            begin           
                shift8_out;
            end
        end
        else
        begin      
            ST_FSM_STATE    <= S_STOP;
            FF              <= 0;
        end
    end

    S_STOP:
    begin
        if(I_START_EDGE_CNT==0)
        begin
            ST_FSM_STATE    <= S_IDLE;
        end
        else
        begin
            ST_FSM_STATE    <= S_STOP;
        end
    end

    default:
    begin
        ST_FSM_STATE    <= S_IDLE;
    end

    endcase
end

//------------------------串行数据转换为并行数据任务----------------------------------
task shift8in; 
output [7:0] shift;
begin 
    casex(sh8in_state)
    
    sh8in_begin:
    begin
	   	sh8in_state <= sh8in_bit7;
    end
    
    sh8in_bit7:
    begin
        if(I_SCL_RISE)   
        begin 
            shift[7] <= I_SDA_DEB;	
            sh8in_state     <= sh8in_bit6;
        end
        else
        begin
            sh8in_state <= sh8in_bit7;
        end
    end
    
    sh8in_bit6:
    begin
        if(I_SCL_RISE) 
        begin
            shift[6] <= I_SDA_DEB;
            sh8in_state     <= sh8in_bit5;
        end
        else
        begin
            sh8in_state <= sh8in_bit6;
        end
    end

    sh8in_bit5:
    begin
        if(I_SCL_RISE) 
        begin	
            shift[5] <= I_SDA_DEB;
            sh8in_state     <= sh8in_bit4;
        end
        else
        begin
            sh8in_state <= sh8in_bit5;
        end
    end
                 
    sh8in_bit4:
    begin
        if(I_SCL_RISE) 
        begin	
            shift[4] <= I_SDA_DEB;
            sh8in_state     <= sh8in_bit3;
        end
        else
        begin
            sh8in_state <= sh8in_bit4;
        end
    end
            
    sh8in_bit3:
    begin
        if(I_SCL_RISE) 
        begin 
            shift[3] <= I_SDA_DEB;
            sh8in_state     <= sh8in_bit2;
        end
        else
        begin 		
            sh8in_state <= sh8in_bit3; 
        end    
    end

    sh8in_bit2:
    begin
        if(I_SCL_RISE) 
        begin 
            shift[2] <= I_SDA_DEB;
            sh8in_state     <= sh8in_bit1;
        end
        else
        begin 		
            sh8in_state <= sh8in_bit2;  
        end
    end

    sh8in_bit1:
    begin
        if(I_SCL_RISE) 
        begin 
            shift[1] <= I_SDA_DEB;
            sh8in_state     <= sh8in_bit0;
        end
        else
        begin 		
            sh8in_state <= sh8in_bit1;  
        end
    end
  
    sh8in_bit0:
    begin
        if(I_SCL_RISE) 
        begin	
            shift[0] <= I_SDA_DEB;
            sh8in_state     <= sh8in_ack;
            ackout_state   <= ack_begin;
        end
        else
        begin		
            sh8in_state <= sh8in_bit0;
        end
    end

    sh8in_ack:
    begin
        ack_out;
        if(ackout_state == ack_end)
        begin
            sh8in_state <= sh8in_end;
            ackout_state <= ack_begin;
        end
    end

    sh8in_end:
    begin
        //if(I_SCL_RISE)
        begin 
            //link_read   <= YES;
            FF          <=  1;                    
            sh8in_state <= sh8in_bit7; 
        end 
        //else
        //begin 		
            //sh8in_state  <= sh8in_end;
        //end
    end

    default:
    begin
		  //link_read    <= NO;
		  //sh8in_state  <= sh8in_bit7;
        sh8in_state  <= sh8in_begin;
	end
    
    endcase  
end  
endtask
//------------------------------ ack任务 ---------------------------
task ack_out;
begin
    casex(ackout_state)
    ack_begin:
    begin
        if (I_SCL_FALL)
        begin
            I_SDA_ACK_OUT<=1'b0;
            I_ACK_OE<=1'b1;
            I_SDA_OUT_OE<=1'b1;
            ackout_state <= ack_bit;
        end
    end
    ack_bit:
    begin
        if (I_SCL_FALL)
        begin
            ackout_state <= ack_end;
        end
        else
        begin
            ackout_state <= ack_bit;
        end
    end
    ack_end:
    begin
        I_SDA_ACK_OUT<=1'b0;
        I_ACK_OE<=1'b0; 
        I_SDA_OUT_OE<=1'b0;
    end
    default:
    begin
        ackout_state    <= ack_begin;
    end

    endcase
end
endtask
//------------------------------ 并行数据转换为串行数据任务 ---------------------------
task shift8_out;
begin
    casex(sh8out_state)
    
    sh8out_bit7:
    begin
        I_RD_OE         <= 1'b1;
        I_SDA_OUT_OE    <= 1'b1;
        //if(I_SCL_FALL)
        //begin	
            sh8out_state    <= sh8out_bit6;
        //end   
        //else
        //begin  	
            //sh8out_state <= sh8out_bit7;            
        //end
    end

    sh8out_bit6:
    begin
        if(I_SCL_FALL) 
        begin 
            sh8out_state  <= sh8out_bit5; 
            I_SREG_SDA_OUT    <= I_SREG_SDA_OUT<<1;
        end		 
        else
        begin
            sh8out_state <= sh8out_bit6;
        end
    end
                    
    sh8out_bit5: 
    begin
        if(I_SCL_FALL) 
        begin 
            sh8out_state <= sh8out_bit4; 
            I_SREG_SDA_OUT   <= I_SREG_SDA_OUT<<1;
        end   
        else
        begin		
            sh8out_state <= sh8out_bit5;
        end
    end
    
    sh8out_bit4: 
    begin
        if(I_SCL_FALL) 
        begin 
            sh8out_state <= sh8out_bit3;
            I_SREG_SDA_OUT   <= I_SREG_SDA_OUT<<1;
        end    
        else
        begin		
            sh8out_state <= sh8out_bit4;
        end
    end
 
    sh8out_bit3:
    begin    
        if(I_SCL_FALL) 
        begin 
            sh8out_state <= sh8out_bit2; 
            I_SREG_SDA_OUT   <= I_SREG_SDA_OUT<<1; 
        end    
        else
        begin		
            sh8out_state <= sh8out_bit3;
        end
    end

    sh8out_bit2:
    begin
        if(I_SCL_FALL) 
        begin 
            sh8out_state <= sh8out_bit1; 
            I_SREG_SDA_OUT   <= I_SREG_SDA_OUT<<1;


        end    
        else
        begin		
            sh8out_state <= sh8out_bit2;
        end
    end

    sh8out_bit1: 
    begin
        if(I_SCL_FALL)	
        begin 
            sh8out_state <= sh8out_bit0; 
            I_SREG_SDA_OUT   <= I_SREG_SDA_OUT<<1; 
        end    
        else 		
        begin
            sh8out_state <= sh8out_bit1;
        end
    end

    sh8out_bit0: 
    begin
        if(I_SCL_FALL)	
        begin 
            sh8out_state <= sh8out_end; 
            I_SREG_SDA_OUT   <= I_SREG_SDA_OUT<<1; 
        end    
        else
        begin 	
            sh8out_state <= sh8out_bit0;
        end
    end

    sh8out_end: 
    begin
        if(I_SCL_FALL) 
        begin	
            I_RD_OE         <= 1'b0;
            I_SDA_OUT_OE    <= 1'b0;
            FF              <= 1;
        end    
        else     
        begin
            sh8out_state <= sh8out_end;
        end
    end

    default:
    begin
        sh8out_state <= sh8out_bit7;
    end

    endcase     
end 
endtask

reg     [7:0]   ROReg0;   
reg     [7:0]   ROReg1;  
reg     [7:0]   ROReg2;  
reg     [7:0]   ROReg3;  
reg     [15:0]  RAM [0:3];

always @(posedge CLOCK)
begin
    if (RESET == 1'b1) 
    begin
        RAM[0]      <= 16'h8095; // 这里是初始值
        RAM[1]      <= 16'h031d; // 这里是初始值
        RAM[2]      <= 16'h0000; // 这里是初始值
        RAM[3]      <= 16'h0000; // 这里是初始值
        ROReg0      <=   8'h10; // RO, default 0x10
        ROReg1      <=   8'h20; // RO, default 0x20
        ROReg2      <=   8'h30; // RO, default 0x30
        ROReg3      <=   8'h40; // RO, default 0x40
    end
    else
    begin
        if (I_RD_OP == 1'b1) // --- I2C Read
        begin
            case (I_REG_ADDR)
            8'h00: I_RD_VAL <= RAM[0][15:8];  
            8'h01: I_RD_VAL <= RAM[0][7:0];  
            8'h02: I_RD_VAL <= RAM[1][15:8];  
            8'h03: I_RD_VAL <= RAM[1][7:0];  
            8'h04: I_RD_VAL <= RAM[2][15:8];  
            8'h05: I_RD_VAL <= RAM[2][7:0];  
            8'h06: I_RD_VAL <= RAM[3][15:8]; 
            8'h07: I_RD_VAL <= RAM[3][7:0];  
            8'h08: I_RD_VAL <= ROReg0;  
            8'h09: I_RD_VAL <= ROReg1;  
            8'h0a: I_RD_VAL <= ROReg2;  
            8'h0b: I_RD_VAL <= ROReg3; 
            default: I_RD_VAL <= 8'hFF; // i2c读非法内部地址, 返回0xff
            endcase
        end
        else if (I_WR_OP == 1'b1) // --- I2C Write
        begin
            case (I_REG_ADDR)
            8'h00: RAM[0][15:8] <= I_SDA_DATA;  //  high byte
            8'h01: RAM[0][7:0] <= I_SDA_DATA;   //  low byte
            8'h02: RAM[1][15:8] <= I_SDA_DATA;
            8'h03: RAM[1][7:0] <= I_SDA_DATA;
            8'h04: RAM[2][15:8] <= I_SDA_DATA;
            8'h05: RAM[2][7:0] <= I_SDA_DATA;
            8'h06: RAM[3][15:8] <= I_SDA_DATA;
            8'h07: RAM[3][7:0] <= I_SDA_DATA;
            /*
            if (I_REG_ADDR%2) // 如果是奇数地址
            begin
                RAM[I_REG_ADDR/2] <= {RAM[I_REG_ADDR/2][15:8], I_SDA_DATA}; // 低字节写入
            end
            else        // 如果是偶数数地址
            begin
                RAM[I_REG_ADDR/2] <= {I_SDA_DATA, RAM[I_REG_ADDR/2][7:0]}; // 高字节写入
            end
            */
            endcase
        end
    end
end

always @(posedge CLOCK)
begin
    if (RESET == 1'b1) 
    begin
        DAT_OUT <= 16'h0000;
    end
    else
    begin
        if (RD_EN)
        begin
            DAT_OUT <= RAM[ADD_IN];
        end
    end
end

assign MCLK_SPEED = RAM[1][0];
assign IDLE_MODE = RAM[1][1];
assign MCLK_MODE = RAM[1][7:6];
assign ROWS_DELAY = RAM[1][15:11];


/*
// delay I_WR_OP for 1 tick
reg                 I_WR_OP_1;
always @(posedge CLOCK)
begin
    if (RESET == 1'b1) 
    begin
        I_WR_OP_1   <= 1'b0;
    end
    else
    begin
        I_WR_OP_1 <= I_WR_OP; 
    end
end
*/
//assign WR_EN        = I_WR_OP_1;
//assign ADD_OUT      = I_REG_ADDR_1;
//assign DAT_OUT      = I_WR_VAL;

endmodule
/*
always @(posedge CLOCK)
begin
    if (RESET == 1'b1) 
    begin
    end
    else
    begin
    end
end
*/



