module CONV_REGS 
(      
    CLOCK,                                      // 48MHz system clock
    RESET,                                      // reset active high

    WE_A,                                       //
    ADD_A,                                      // 
    DAT_A,                                      //

    RE_B,
    ADD_B,                                      // 
    DAT_B,                                      //

    MCLK_SPEED,                                 //
    MCLK_MODE,                                  //
    ROWS_DELAY,                                 //
    IDLE_MODE                                   //
    // TODO: add rows_in_reset
);

input                       CLOCK;
input                       RESET;
input                       WE_A;
input   [2:0]               ADD_A;      // 8 addresses
input   [7:0]               DAT_A;      // 1 byte reg
input                       RE_B;
input   [1:0]               ADD_B;      // 4 addresses
output  [15:0]              DAT_B;      // 2 byte reg
output                      MCLK_SPEED;
output                      IDLE_MODE;
output  [1:0]               MCLK_MODE;
output  [4:0]               ROWS_DELAY;


reg     [15:0]              DAT_B;

reg     [15:0]              RAM [0:3];

reg     [7:0]               I_BYTE_H;
//reg     [2:0]               ADD_A_PREV;

//--------------------------------------------------------------------------------
//-- Port A
//--------------------------------------------------------------------------------
always @(posedge CLOCK)
begin
    if (RESET == 1'b1) 
    begin
        //I_BYTE_H <= 8'b0;
        //ADD_A_PREV    <= 3'b000;
        RAM[0]        <= 16'h0000; // 这里是初始值
        RAM[1]        <= 16'h0000; // 这里是初始值
    end
    else
    begin
        if (WE_A == 1'b1)
        begin
            //ADD_A_PREV <= ADD_A;
            //if ((ADD_A % 2) == 0)  // high byte
            //begin
                //I_BYTE_H <= DAT_A;
            //end
            //else    // low byte
            //begin
                //if (ADD_A == (ADD_A_PREV + 1'b1))
                //begin
                    // 写入RAM
                    //RAM[ADD_A_PREV/2] <= {I_BYTE_H,DAT_A};
                //end
            //end
            if (ADD_A%2) // 如果是奇数地址
            begin
                RAM[ADD_A/2] <= {RAM[ADD_A/2][15:8], DAT_A}; // 低字节写入
            end
            else        // 如果是偶数数地址
            begin
                RAM[ADD_A/2] <= {DAT_A, RAM[ADD_A/2][7:0]}; // 高字节写入
            end
        end
    end
end


//--------------------------------------------------------------------------------
//-- Port B
//--------------------------------------------------------------------------------
always @(posedge CLOCK)
begin
    if (RESET == 1'b1) 
    begin
        DAT_B <= 16'h0000;
    end
    else
    begin
        if (RE_B)
        begin
            DAT_B <= RAM[ADD_B];
        end
    end
end

assign MCLK_SPEED = RAM[1][0];
assign IDLE_MODE = RAM[1][1];
assign MCLK_MODE = RAM[1][7:6];
assign ROWS_DELAY = RAM[1][15:11];
endmodule
/*
always @(posedge CLOCK)
begin
    if (RESET == 1'b1) 
    begin
        
    end
    else
    begin
        if ()
        begin
            
        end
        else
        begin
            
        end
    end
end
*/

