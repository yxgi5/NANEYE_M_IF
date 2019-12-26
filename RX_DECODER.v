module RX_DECODER # 
( 
	parameter   G_CLOCK_PERIOD_PS = 5555,      // CLOCK period in ps (eg. 180MHz T=5555ns)
    parameter   IDLE_PERIOD_MAX_NS = 25000000   // wait if no input, then send gain
) 
(
    reset,    // reset module, active high
    sclock,   // sample clock, eg. 400MHz
    rx_data,
    rsync_dec,    // resynchronize decoder
    config_done,    // end of config phase (async)
    line_des_end,    // 
    tx_oe_n,
    config_en,
    frame_start,
    v_sync,
    h_sync,
    decoded_data,
    decoded_en,
    dec_err,
    debug
)/* synthesis syn_preserve=1 */;
input   reset;
input   sclock;
input   rx_data;
input   rsync_dec;
input   config_done;
input   line_des_end;
input   tx_oe_n;
output  config_en;
output  frame_start;
output  v_sync;
output  h_sync;
output  decoded_data;
output  decoded_en;
output  dec_err;
output  [15:0]  debug;



parameter   C_BIT_LEN_W = 5;
parameter   C_HISTOGRAM_ENTRIES = 2**C_BIT_LEN_W;
parameter   C_HISTOGRAM_ENTRY_W = 12;
parameter   C_CAL_CNT_W = 14;
parameter   C_HB_PERIOD_CNT_W = 14;

parameter   C_CAL_CNT_FR_END = 850000/G_CLOCK_PERIOD_PS;
parameter   C_CAL_CNT_SYNC = 32;
parameter   C_RSYNC_PER_CNT_END = 14'b11_1111_1111_1111;
parameter   C_RSYNC_PP_THR = 2*350*12;

parameter   C_WAIT_PERIOD_MAX = (IDLE_PERIOD_MAX_NS/G_CLOCK_PERIOD_PS)*1000;

parameter   S_IDLE     =3'b000;

parameter   CAL_IDLE            = 4'b0000;
parameter   CAL_FIND_FS         = 4'b0001;
parameter   CAL_FIND_SYNC       = 4'b0010;
parameter   WAIT_FOR_SENSOR_CFG = 4'b0011;
parameter   CAL_SYNC_FOUND      = 4'b0100;
parameter   CAL_MEASURE         = 4'b0101;
parameter   CAL_SEARCH_MIN      = 4'b0110;
parameter   CAL_FOUND_MIN       = 4'b0111;
parameter   CAL_SEARCH_MAX      = 4'b1000;
parameter   CAL_FOUND_MAX       = 4'b1001;
parameter   CAL_DONE            = 4'b1010;

parameter   DEC_IDLE            = 3'b000;
parameter   DEC_START           = 3'b001;
parameter   DEC_SYNC            = 3'b010;
parameter   DEC_HALF_BIT        = 3'b011;
parameter   DEC_ERROR           = 3'b100;

wire    reset;
wire    sclock;
wire    rx_data;
wire    rsync_dec;
wire    config_done;
wire    line_des_end;
wire    tx_oe_n;

wire    [15:0]  debug /* synthesis syn_keep = 1 */;
wire    dec_err  /* synthesis syn_keep = 1 */;
wire    frame_start  /* synthesis syn_keep = 1 */;
wire    I_CONFIG_EN  /* synthesis syn_keep = 1 */;
wire    config_en  /* synthesis syn_keep = 1 */;
wire    I_H_SYNC_START_P /* synthesis syn_keep = 1 */;
wire    I_DEC_START_END_P /* synthesis syn_keep = 1 */;

wire    I_IDDR_Q0 /* synthesis syn_keep = 1 */; // rising edge sample value
wire    I_IDDR_Q1 /* synthesis syn_keep = 1 */; // falling edge sample value

wire    I_IDLE_WATI_TIMEOUT_P /* synthesis syn_keep = 1 */;
//reg     I_IDLE_WATI_TIMEOUT_P /* synthesis syn_keep = 1 */;

reg     [3:0]   I_CAL_PS /* synthesis syn_keep = 1 */;
reg     [3:0]   I_CAL_LS /* synthesis syn_keep = 1 */;
reg     [2:0]   I_DEC_PS /* synthesis syn_keep = 1 */;

reg     [1:0]  I_IDDR_Q /* synthesis syn_keep = 1 */;
reg     [1:0]  I_LAST_IDDR_Q /* synthesis syn_keep = 1 */;
reg     [C_BIT_LEN_W:0]  I_ADD /* synthesis syn_keep = 1 */; //采样累加
reg     [C_BIT_LEN_W:0]  I_LAST_ADD /* synthesis syn_keep = 1 */;
reg     [C_BIT_LEN_W:0]  I_BIT_LEN /* synthesis syn_keep = 1 */;//采样累加的结果
//reg     I_BIT_LEN_FF = 1'b1;
reg     I_TEST_BIT_LEN /* synthesis syn_keep = 1 */ = 1'b0;
//reg     [4:0]  I_LAST_BIT_LEN;
reg     I_BIT_TRANS /* synthesis syn_keep = 1 */ = 1'b0; //采样累加的结果 有效
reg     I_BIT_TRANS_1 /* synthesis syn_keep = 1 */ = 1'b0;
reg     I_BIT_TRANS_2 /* synthesis syn_keep = 1 */ = 1'b0;

reg     [C_HISTOGRAM_ENTRY_W-1:0]   I_HISTOGRAM     [0:C_HISTOGRAM_ENTRIES-1] /* synthesis syn_ramstyle = "no_rw_check" */;
reg     [C_HISTOGRAM_ENTRIES-1:0]   I_HISTOGRAM_ENTRY_MAX /* synthesis syn_keep = 1 */;
reg     [C_HISTOGRAM_ENTRIES-1:0]   I_HISTOGRAM_CNT_EN /* synthesis syn_keep = 1 */;
reg     [C_BIT_LEN_W-1:0]           I_HISTOGRAM_INDEX /* synthesis syn_keep = 1 */;
reg     [C_BIT_LEN_W-1:0]           I_BIT_LEN_MAX /* synthesis syn_keep = 1 */;
reg     [C_BIT_LEN_W-1:0]           I_BIT_LEN_MIN /* synthesis syn_keep = 1 */;
reg     [C_BIT_LEN_W:0]             I_BIT_LEN_DIFF2MIN_ABS /* synthesis syn_keep = 1 */;
reg     [C_BIT_LEN_W:0]             I_BIT_LEN_DIFF2MAX_ABS /* synthesis syn_keep = 1 */;
reg     I_CAL_DONE /* synthesis syn_keep = 1 */;

reg     I_CONFIG_DONE_1 /* synthesis syn_keep = 1 */;
reg     I_CONFIG_DONE_2 /* synthesis syn_keep = 1 */;

reg     [C_CAL_CNT_W-1:0]           I_CAL_CNT /* synthesis syn_keep = 1 */;

reg     I_COMP_EN /* synthesis syn_keep = 1 */;
reg     I_CHECK_EN /* synthesis syn_keep = 1 */;

reg     I_HB_PERIOD /* synthesis syn_keep = 1 */;
reg     I_HB_PERIOD_CNT_EN /* synthesis syn_keep = 1 */;
reg     [C_HB_PERIOD_CNT_W-1:0]     I_HB_PERIOD_CNT /* synthesis syn_keep = 1 */;
reg     I_FB_PERIOD /* synthesis syn_keep = 1 */;
reg     I_BIT_PERIOD_ERR /* synthesis syn_keep = 1 */;


reg     decoded_data /* synthesis syn_keep = 1 */;
reg     decoded_en /* synthesis syn_keep = 1 */;
reg     v_sync /* synthesis syn_keep = 1 */;
reg     h_sync /* synthesis syn_keep = 1 */;
reg     I_H_SYNC_START_1 /* synthesis syn_keep = 1 */;


reg     I_DEC_START_STATUS /* synthesis syn_keep = 1 */;
reg     I_DEC_START_STATUS_1 /* synthesis syn_keep = 1 */;


reg     I_IDLE_WATI_TIMEOUT /* synthesis syn_keep = 1 */;
reg     I_IDLE_WATI_TIMEOUT_1 /* synthesis syn_keep = 1 */;
reg     [31:0]  I_IDLE_WATI_TIMEOUT_CNT /* synthesis syn_keep = 1 */;
reg     I_IDLE_WATI_TIMEOUT_P_DELAY /* synthesis syn_keep = 1 */;
reg     [3:0]   I_IDLE_WATI_TIMEOUT_P_DELAY_CNT /* synthesis syn_keep = 1 */;

reg     [5:0]   i /* synthesis syn_keep = 1 */;
//integer i;

IDDR U_IDDR
(
    .inclock         (sclock),
    .datain          (rx_data),
    .aclr            (reset),
    .dataout_h       (I_IDDR_Q0),
    .dataout_l       (I_IDDR_Q1)
);
    
//assign debug[1:0] = {I_IDDR_Q1, I_IDDR_Q0};

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_IDDR_Q <= 2'b0;
        I_LAST_IDDR_Q <= 2'b0;
    end
    else
    begin
        I_IDDR_Q[0] <= I_IDDR_Q1;
        I_IDDR_Q[1] <= I_IDDR_Q0;
        I_LAST_IDDR_Q <= I_IDDR_Q;
    end
end
//assign debug[1:0] = I_IDDR_Q[1:0];
//assign debug[1:0] = {I_IDDR_Q[0],I_LAST_IDDR_Q[0]};

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_ADD <= 5'b0;
        I_LAST_ADD <= 5'b0;
    end
    else
    begin
        I_LAST_ADD <= I_ADD;
        case(I_IDDR_Q)
        2'b00:
        begin
            if(I_LAST_IDDR_Q == 2'b11)
            begin
                I_ADD <= 5'b00010;
            end
            else
            begin
                I_ADD <= I_ADD + 5'b00010;
            end
        end
        2'b01:
        begin
            I_ADD <= 5'b00001;
        end
        2'b10:
        begin
            I_ADD <= 5'b00001;
        end
        2'b11:
        begin
            if(I_LAST_IDDR_Q == 2'b00)
            begin
                I_ADD <= 5'b00010;
            end
            else
            begin
                I_ADD <= I_ADD + 5'b00010;
            end
        end
        endcase
    end
end
//assign debug[6:2] = I_ADD[4:0];


always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_BIT_LEN <= 5'b0;
        //I_BIT_LEN_FF <= 1'b1;
        //I_LAST_BIT_LEN <= 5'b0;
        I_TEST_BIT_LEN <= 1'b0;
        I_BIT_TRANS <= 1'b0;
    end
    else
    begin
        //I_LAST_BIT_LEN <= I_BIT_LEN;
        case(I_IDDR_Q)
        2'b00:
        begin
            if(I_LAST_IDDR_Q!=2'b00)
            begin
                I_TEST_BIT_LEN <= ~I_TEST_BIT_LEN;
                I_BIT_TRANS <= 1'b1;
                if(I_LAST_IDDR_Q[1]^I_LAST_IDDR_Q[0])
                begin
                    I_BIT_LEN <= I_LAST_ADD + 5'b00001;
                    //I_BIT_LEN_FF <= 1'b0;
                end
                //else if(I_LAST_IDDR_Q == 2'b11 && I_BIT_LEN_FF == 1'b1)
                else
                begin
                    I_BIT_LEN <= I_ADD;
                end
            end
            else
            begin
                I_BIT_LEN <= I_BIT_LEN;
                //I_BIT_LEN_FF <= 1'b1;
                I_BIT_TRANS <= 1'b0;
            end
        end
        2'b01:
        begin
            //I_BIT_LEN <= I_ADD + 5'b00001;
            I_BIT_LEN <= I_BIT_LEN;
            I_BIT_TRANS <= 1'b0;
        end
        2'b10:
        begin
            //I_BIT_LEN <= I_ADD + 5'b00001;
            I_BIT_LEN <= I_BIT_LEN;
            I_BIT_TRANS <= 1'b0;
        end
        2'b11:
        begin
            if(I_LAST_IDDR_Q!=2'b11)
            begin
                I_TEST_BIT_LEN <= ~I_TEST_BIT_LEN;
                I_BIT_TRANS <= 1'b1;
                if(I_LAST_IDDR_Q[1]^I_LAST_IDDR_Q[0])
                begin
                    I_BIT_LEN <= I_LAST_ADD + 5'b00001;
                    //I//_BIT_LEN_FF <= 1'b0;
                end
                //else if(I_LAST_IDDR_Q == 2'b00 && I_BIT_LEN_FF == 1'b1)
                else
                begin
                    I_BIT_LEN <= I_ADD;
                end
            end
            else
            begin
                I_BIT_LEN <= I_BIT_LEN;
                //I_BIT_LEN_FF <= 1'b1;
                I_BIT_TRANS <= 1'b0;
            end
        end
        default:
        begin
            I_BIT_LEN <= I_BIT_LEN;
            I_BIT_TRANS <= 1'b0;
        end
        endcase
    end
end
//assign debug[6:2] = I_BIT_LEN[4:0];

//assign debug[6:3] = I_BIT_LEN[4:1];
//assign debug[2] = I_TEST_BIT_LEN;

//assign debug[6:4] = I_BIT_LEN[4:2];
//assign debug[3] = I_BIT_TRANS;

//assign debug[0] = I_TEST_BIT_LEN;
//assign debug[4:1] = I_BIT_LEN[4:1];


always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        for (i=0;i<=C_HISTOGRAM_ENTRIES-1;i=i+1)
        begin
            I_HISTOGRAM[i] <= 12'b0;
        end
        I_HISTOGRAM_ENTRY_MAX <= 31'b0;
        I_HISTOGRAM_CNT_EN <= 31'b0;
        I_BIT_TRANS_1   <= 1'b0;
        I_BIT_TRANS_2   <= 1'b0;
    end
    else
    begin
        I_BIT_TRANS_1 <= I_BIT_TRANS;
        I_BIT_TRANS_2 <= I_BIT_TRANS_1;
        if(I_CAL_PS == CAL_SYNC_FOUND)
        begin
            for (i=0;i<=C_HISTOGRAM_ENTRIES-1;i=i+1)
            begin
                I_HISTOGRAM[i] <= 12'b0;
            end
            I_HISTOGRAM_ENTRY_MAX <= 31'b0;
            I_HISTOGRAM_CNT_EN <= 31'b0;
        end
        else if(I_CAL_PS == CAL_MEASURE)
        begin
            I_HISTOGRAM_CNT_EN <= 31'b0;
            if(I_BIT_TRANS == 1'b1)
            begin
                for (i=0;i<=C_HISTOGRAM_ENTRIES-1;i=i+1)
                begin
                    if(i[4:0] == I_BIT_LEN)
                    begin
                        I_HISTOGRAM_CNT_EN[i] <= 1'b1;
                    end
                end
            end
            if (I_BIT_TRANS_1 == 1'b1)
            begin
                for (i=0;i<=C_HISTOGRAM_ENTRIES-1;i=i+1)
                begin
                    if (I_HISTOGRAM_CNT_EN[i] == 1'b1)
                    begin
                        I_HISTOGRAM[i] <= I_HISTOGRAM[i] + 1'b1;
                    end
                end
            end
            if (I_BIT_TRANS_2 == 1'b1)
            begin
                for (i=0;i<=C_HISTOGRAM_ENTRIES-1;i=i+1)
                begin
                    if(I_HISTOGRAM[i][C_HISTOGRAM_ENTRY_W-1] == 1'b1)
                    begin
                        I_HISTOGRAM_ENTRY_MAX[i] <= 1'b1;
                    end
                end
            end
        end
    end
end


always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_HISTOGRAM_INDEX <= 5'b0;
    end
    else
    begin
        case(I_CAL_PS)
        CAL_MEASURE:
        begin
            I_HISTOGRAM_INDEX <= 5'b0;
        end
        CAL_SEARCH_MIN:
        begin
            I_HISTOGRAM_INDEX <= I_HISTOGRAM_INDEX + 1'b1;
        end
        CAL_FOUND_MIN:
        begin
            I_HISTOGRAM_INDEX <= 5'b0;
        end
        CAL_SEARCH_MAX:
        begin
            I_HISTOGRAM_INDEX <= I_HISTOGRAM_INDEX - 1'b1;
        end
        default:
        begin
            I_HISTOGRAM_INDEX <= I_HISTOGRAM_INDEX;
        end
        endcase
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_BIT_LEN_MAX <= 5'b0;
    end
    else
    begin
        if (I_CAL_PS == CAL_FOUND_MAX)
        begin
            I_BIT_LEN_MAX <= I_HISTOGRAM_INDEX;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_BIT_LEN_DIFF2MAX_ABS <= 6'b0;
    end
    else
    begin
        if(I_CAL_DONE == 1'b1)
        begin
            if (I_BIT_TRANS == 1'b1)
            begin
                //I_BIT_LEN_DIFF2MAX_ABS <= ({1'b0, I_BIT_LEN} > I_BIT_LEN_MAX)? ({1'b0, I_BIT_LEN} - I_BIT_LEN_MAX):(I_BIT_LEN_MAX - {1'b0, I_BIT_LEN});
                if({1'b0, I_BIT_LEN} > I_BIT_LEN_MAX)
                begin
                    I_BIT_LEN_DIFF2MAX_ABS <= ({1'b0, I_BIT_LEN} - I_BIT_LEN_MAX);
                end
                else
                begin
                    I_BIT_LEN_DIFF2MAX_ABS <= (I_BIT_LEN_MAX - {1'b0, I_BIT_LEN});
                end
            end
            else
            begin
                I_BIT_LEN_DIFF2MAX_ABS <= I_BIT_LEN_DIFF2MAX_ABS;
            end
        end
        else
        begin
            I_BIT_LEN_DIFF2MAX_ABS <= 6'b0;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_BIT_LEN_MIN <= 5'b0;
    end
    else
    begin
        if (I_CAL_PS == CAL_FOUND_MIN)
        begin
            I_BIT_LEN_MIN <= I_HISTOGRAM_INDEX;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_BIT_LEN_DIFF2MIN_ABS <= 6'b0;
    end
    else
    begin
        if(I_CAL_DONE == 1'b1)
        begin
            if (I_BIT_TRANS == 1'b1)
            begin
                // I_BIT_LEN_DIFF2MIN_ABS <= ({1'b0, I_BIT_LEN} > I_BIT_LEN_MIN)? ({1'b0, I_BIT_LEN} - I_BIT_LEN_MIN):(I_BIT_LEN_MIN - {1'b0, I_BIT_LEN});
                if({1'b0, I_BIT_LEN} > I_BIT_LEN_MIN)
                begin
                    I_BIT_LEN_DIFF2MIN_ABS <= ({1'b0, I_BIT_LEN} - I_BIT_LEN_MIN);
                end
                else
                begin
                    I_BIT_LEN_DIFF2MIN_ABS <= (I_BIT_LEN_MIN - {1'b0, I_BIT_LEN});
                end
            end
            else
            begin
                I_BIT_LEN_DIFF2MIN_ABS <= I_BIT_LEN_DIFF2MIN_ABS;
            end
        end
        else
        begin
            I_BIT_LEN_DIFF2MIN_ABS <= 6'b0;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_CONFIG_DONE_1 <= 1'b0;
        I_CONFIG_DONE_2 <= 1'b0;
    end
    else
    begin
        I_CONFIG_DONE_1 <= config_done;
        I_CONFIG_DONE_2 <= I_CONFIG_DONE_1;
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_CAL_PS <= CAL_IDLE;
        I_CAL_LS <= CAL_IDLE;
    end
    else
    begin
        I_CAL_LS <= I_CAL_PS;
        case(I_CAL_PS)
            CAL_IDLE:
            begin
                if (I_BIT_TRANS == 1'b1)
                begin
                    I_CAL_PS <= CAL_FIND_FS;
                end
                else
                begin
                    I_CAL_PS <= I_CAL_PS;
                end
            end
            CAL_FIND_FS:
            begin
                if (I_CAL_CNT == C_CAL_CNT_FR_END)
                begin
                    I_CAL_PS <= WAIT_FOR_SENSOR_CFG;
                end
                else
                begin
                    I_CAL_PS <= I_CAL_PS;
                end
            end
            WAIT_FOR_SENSOR_CFG:
            begin
                if (I_CONFIG_DONE_2 == 1'b1)
                begin
                    I_CAL_PS <= CAL_FIND_SYNC;
                end
                else
                begin
                    I_CAL_PS <= I_CAL_PS;
                end
            end
            CAL_FIND_SYNC:
            begin
                if (I_CAL_CNT == C_CAL_CNT_SYNC)
                begin
                    I_CAL_PS <= CAL_SYNC_FOUND;
                end
                else
                begin
                    I_CAL_PS <= I_CAL_PS;
                end
            end
            CAL_SYNC_FOUND:
            begin
                I_CAL_PS <= CAL_MEASURE;
            end
            CAL_MEASURE:
            begin
                if (I_CAL_CNT == C_CAL_CNT_FR_END)
                begin
                    I_CAL_PS <= CAL_SEARCH_MIN;
                end
                else
                begin
                    I_CAL_PS <= I_CAL_PS;
                end
            end
            CAL_SEARCH_MIN:
            begin
                if (I_HISTOGRAM_ENTRY_MAX[I_HISTOGRAM_INDEX] == 1'b1)
                begin
                    I_CAL_PS <= CAL_FOUND_MIN;
                end
                else if (I_HISTOGRAM_INDEX == 5'b0)
                begin
                    I_CAL_PS <= CAL_DONE;
                end
                else
                begin
                    I_CAL_PS <= I_CAL_PS;
                end
            end
            CAL_FOUND_MIN:
            begin
                I_CAL_PS <= CAL_SEARCH_MAX;
            end
            CAL_SEARCH_MAX:
            begin
                if (I_HISTOGRAM_ENTRY_MAX[I_HISTOGRAM_INDEX] == 1'b1)
                begin
                    I_CAL_PS <= CAL_FOUND_MAX;
                end
                else if (I_HISTOGRAM_INDEX == 5'b0)
                begin
                    I_CAL_PS <= CAL_DONE;
                end
                else
                begin
                    I_CAL_PS <= I_CAL_PS;
                end
            end
            CAL_FOUND_MAX:
            begin
                I_CAL_PS <= CAL_DONE;
            end
            CAL_DONE:
            begin
                I_CAL_PS <= CAL_FIND_FS;
            end
            default:
            begin
                I_CAL_PS <= CAL_IDLE;
            end
        endcase
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_CAL_CNT <= 14'b0;
    end
    else
    begin
        case(I_CAL_PS)
        CAL_MEASURE:
        begin
            if (I_BIT_TRANS == 1'b1)
            begin
                I_CAL_CNT <= 14'b0;
            end
            else
            begin
                I_CAL_CNT <= I_CAL_CNT +1'b1;
            end
        end
        CAL_FIND_FS:
        begin
            if (I_BIT_TRANS == 1'b1)
            begin
                I_CAL_CNT <= 14'b0;
            end
            else
            begin
                I_CAL_CNT <= I_CAL_CNT +1'b1;
            end
        end
        CAL_FIND_SYNC:
        begin
            if (I_BIT_TRANS == 1'b1)
            begin
                I_CAL_CNT <= I_CAL_CNT +1'b1;
            end
        end
        default:
        begin
            I_CAL_CNT <= 14'b0;
        end
        endcase
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_CAL_DONE <= 1'b0;
    end
    else
    begin
        if (I_CAL_PS == CAL_DONE)
        begin
            I_CAL_DONE <= 1'b1;
        end
        else
        begin
            I_CAL_DONE <= I_CAL_DONE;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_COMP_EN  <= 1'b0;
        I_CHECK_EN <= 1'b0;
    end
    else
    begin
        I_CHECK_EN <= I_COMP_EN;
        if (I_CAL_DONE == 1'b1)
        begin
            I_COMP_EN <= I_BIT_TRANS;
        end
        else
        begin
            I_COMP_EN  <= 1'b0;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_HB_PERIOD <= 1'b0;
    end
    else
    begin
        if (I_COMP_EN == 1'b1)
        begin
            if (I_BIT_LEN_DIFF2MIN_ABS < I_BIT_LEN_DIFF2MAX_ABS)
            begin
                I_HB_PERIOD <= 1'b1;
            end
            else
            begin
                I_HB_PERIOD <= 1'b0;
            end
        end
        else
        begin
            I_HB_PERIOD <= 1'b0;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_FB_PERIOD <= 1'b0;
    end
    else
    begin
        if (I_COMP_EN == 1'b1)
        begin
            if (I_BIT_LEN_DIFF2MAX_ABS < I_BIT_LEN_DIFF2MIN_ABS)
            begin
                I_FB_PERIOD <= 1'b1;
            end
            else
            begin
                I_FB_PERIOD <= 1'b0;
            end
        end
        else
        begin
            I_FB_PERIOD <= 1'b0;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_BIT_PERIOD_ERR <= 1'b0;
    end
    else
    begin
        if (I_CHECK_EN == 1'b1)
        begin
            if ((I_HB_PERIOD == 1'b0) && (I_FB_PERIOD == 1'b0))
            begin
                I_BIT_PERIOD_ERR <= 1'b1;
            end
            else
            begin
                I_BIT_PERIOD_ERR <= 1'b0;
            end
        end
        else
        begin
            I_BIT_PERIOD_ERR <= I_BIT_PERIOD_ERR;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_DEC_PS <= DEC_IDLE;
    end
    else
    begin
        if(I_CAL_PS == CAL_FIND_SYNC)
        begin
            I_DEC_PS <= DEC_IDLE;
        end
        else
        begin
            case (I_DEC_PS)
            DEC_IDLE:
            begin
                if (I_CAL_PS == CAL_SYNC_FOUND)
                begin
                    I_DEC_PS <= DEC_START;
                end
                else
                begin
                    I_DEC_PS <= I_DEC_PS;
                end
            end
            DEC_START:
            begin
                if (rsync_dec == 1'b1)
                begin
                    I_DEC_PS <= DEC_START;
                end
                else if(I_FB_PERIOD == 1'b1)
                begin
                    I_DEC_PS <= DEC_SYNC;
                end
                else
                begin
                    I_DEC_PS <= I_DEC_PS;
                end
            end
            DEC_SYNC:
            begin
                if (rsync_dec == 1'b1)
                begin
                    I_DEC_PS <= DEC_START;
                end
                else if (I_FB_PERIOD  == 1'b1)
                begin
                    I_DEC_PS <= I_DEC_PS;
                end
                else if (I_HB_PERIOD  == 1'b1)
                begin
                    I_DEC_PS <= DEC_HALF_BIT;
                end
                else
                begin
                    I_DEC_PS <= I_DEC_PS;
                end
            end
            DEC_HALF_BIT:
            begin
                if (rsync_dec == 1'b1)
                begin
                    I_DEC_PS <= DEC_START;
                end
                else if (I_FB_PERIOD  == 1'b1)
                begin
                    I_DEC_PS <= DEC_ERROR;
                end
                else if (I_HB_PERIOD  == 1'b1)
                begin
                    I_DEC_PS <= DEC_SYNC;
                end
                else
                begin
                    I_DEC_PS <= I_DEC_PS;
                end
            end
            DEC_ERROR:
            begin
                I_DEC_PS <= DEC_START;
            end
            default:
            begin
                I_DEC_PS <= DEC_IDLE;
            end
            endcase
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        decoded_data <= 1'b0;
    end
    else
    begin
        if (I_DEC_PS == DEC_START)
        begin
            if (I_FB_PERIOD == 1'b1)
            begin
                decoded_data <= 1'b1;
            end
            else
            begin
                decoded_data <= 1'b0;
            end
        end
        else if (I_FB_PERIOD == 1'b1)
        begin
             decoded_data <= ~decoded_data;
        end
        else
        begin
            decoded_data <= decoded_data;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        decoded_en <= 1'b0;
    end
    else
    begin
        if (rsync_dec == 1'b1)
        begin
            decoded_en <= 1'b0;
        end
        else if(((I_DEC_PS == DEC_START) && (I_FB_PERIOD == 1'b1)) || ((I_DEC_PS == DEC_SYNC) && (I_FB_PERIOD == 1'b1)) || ((I_DEC_PS == DEC_HALF_BIT) && (I_HB_PERIOD == 1'b1)))
        begin
            decoded_en <= 1'b1;
        end
        else
        begin
            decoded_en <= 1'b0;
        end
    end
end
//assign debug[6:5] = {decoded_en,decoded_data};

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_HB_PERIOD_CNT_EN <= 1'b0;
    end
    else
    begin
        if ((I_CAL_LS == CAL_SYNC_FOUND) && (I_CAL_PS == CAL_MEASURE))
        begin
            I_HB_PERIOD_CNT_EN <= 1'b1;
        end
        else if ((I_CAL_DONE == 1'b1) && (I_DEC_PS == DEC_START) && (I_FB_PERIOD == 1'b1))
        begin
            I_HB_PERIOD_CNT_EN <= 1'b0;
        end
        else
        begin
            I_HB_PERIOD_CNT_EN <= I_HB_PERIOD_CNT_EN;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_HB_PERIOD_CNT <= 14'b0;
    end
    else
    begin
        if ((I_CAL_DONE == 1'b1) && (I_DEC_PS == DEC_START) && (I_HB_PERIOD_CNT_EN == 1'b1))
        begin
            if (I_HB_PERIOD == 1'b1)
            begin
                if (I_HB_PERIOD_CNT == C_RSYNC_PER_CNT_END)
                begin
                    I_HB_PERIOD_CNT <= I_HB_PERIOD_CNT;
                end
                else
                begin
                    I_HB_PERIOD_CNT <= I_HB_PERIOD_CNT + 1'b1;
                end
            end
            else
            begin
                I_HB_PERIOD_CNT <= I_HB_PERIOD_CNT;
            end
        end
        else
        begin
            I_HB_PERIOD_CNT <= 14'b0;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        v_sync <= 1'b0;
    end
    else
    begin
        if ((I_HB_PERIOD_CNT > 0) && (I_HB_PERIOD_CNT < C_RSYNC_PER_CNT_END))
        begin
            v_sync <= 1'b1;
        end
        else if((I_HB_PERIOD_CNT_EN == 1'b1) && (I_HB_PERIOD_CNT>= C_RSYNC_PER_CNT_END))
        begin
            v_sync <= 1'b0;
        end
        else
        begin
            v_sync <= v_sync;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_H_SYNC_START_1 <= 1'b0;
    end
    else
    begin
        I_H_SYNC_START_1 <= I_HB_PERIOD_CNT_EN;
    end
end
assign I_H_SYNC_START_P = ~I_HB_PERIOD_CNT_EN & I_H_SYNC_START_1;

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_DEC_START_STATUS <= 1'b0;
        I_DEC_START_STATUS_1 <= 1'b0;
    end
    else
    begin
        I_DEC_START_STATUS_1 <= I_DEC_START_STATUS;
        if (I_DEC_PS == DEC_START)
        begin
            I_DEC_START_STATUS <= 1'b1;
        end
        else
        begin
            I_DEC_START_STATUS <= 1'b0;
        end
    end
end
assign I_DEC_START_END_P = ~I_DEC_START_STATUS & I_DEC_START_STATUS_1;

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        h_sync <= 1'b0;
    end
    else
    begin
        if ((I_DEC_START_END_P == 1'b1) && (I_DEC_PS == DEC_SYNC) && (v_sync == 1'b0))
        begin
            h_sync <= 1'b1;
        end
        else if ((rsync_dec == 1'b1) || (line_des_end == 1'b1))
        begin
            h_sync <= 1'b0;
        end
        else
        begin
            h_sync <= h_sync;
        end
    end
end

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_IDLE_WATI_TIMEOUT <= 1'b0;
        I_IDLE_WATI_TIMEOUT_1 <= 1'b0;
        I_IDLE_WATI_TIMEOUT_CNT <= 32'b0;
    end
    else
    begin
        I_IDLE_WATI_TIMEOUT_1 <= I_IDLE_WATI_TIMEOUT;
        if(I_CAL_PS != CAL_IDLE)
        begin
            I_IDLE_WATI_TIMEOUT_CNT <= 32'b0;
        end
        else if (I_IDLE_WATI_TIMEOUT_CNT >= C_WAIT_PERIOD_MAX)
        begin
            I_IDLE_WATI_TIMEOUT_CNT <= 32'b0;
            I_IDLE_WATI_TIMEOUT <= 1'b1;
        end
        else if (tx_oe_n == 1'b1)
        begin
            I_IDLE_WATI_TIMEOUT_CNT <= I_IDLE_WATI_TIMEOUT_CNT + 1'b1;
            I_IDLE_WATI_TIMEOUT <= 1'b0;
        end
        else
        begin
            I_IDLE_WATI_TIMEOUT_CNT <= 32'b0;
            I_IDLE_WATI_TIMEOUT <= 1'b0;
        end
    end
end

//assign debug[6:2] = I_IDLE_WATI_TIMEOUT_CNT[7:3];
assign  I_IDLE_WATI_TIMEOUT_P = I_IDLE_WATI_TIMEOUT & (~I_IDLE_WATI_TIMEOUT_1);
/*
always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_IDLE_WATI_TIMEOUT_P <= 1'b0;
    end
    else
    begin
        if ((I_IDLE_WATI_TIMEOUT == 1'b1) && (I_IDLE_WATI_TIMEOUT_1 == 1'b0))
        begin
            I_IDLE_WATI_TIMEOUT_P <= 1'b1;
        end
        else
        begin
            I_IDLE_WATI_TIMEOUT_P <= 1'b0;
        end
    end
end
*/

always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        I_IDLE_WATI_TIMEOUT_P_DELAY <= 1'b0;
        I_IDLE_WATI_TIMEOUT_P_DELAY_CNT <= 4'b0;
    end
    else
    begin
        if (I_IDLE_WATI_TIMEOUT_P == 1'b1)
        begin
            I_IDLE_WATI_TIMEOUT_P_DELAY <= 1'b1;
        end
        else if (I_IDLE_WATI_TIMEOUT_P_DELAY_CNT == 4'b1010)
        begin
            I_IDLE_WATI_TIMEOUT_P_DELAY <= 1'b0;
        end
        
        if (I_IDLE_WATI_TIMEOUT_P_DELAY == 1'b1)
        begin
            if (I_IDLE_WATI_TIMEOUT_P_DELAY_CNT >= 4'b1010)
            begin
                I_IDLE_WATI_TIMEOUT_P_DELAY_CNT <= 4'b0;
            end
            else
            begin
                I_IDLE_WATI_TIMEOUT_P_DELAY_CNT <= I_IDLE_WATI_TIMEOUT_P_DELAY_CNT + 4'b0001;
            end
        end
    end
end

assign  dec_err = (I_DEC_PS == DEC_ERROR)? 1'b1 : 1'b0;
assign  frame_start = (I_CAL_PS == CAL_SYNC_FOUND) ? 1'b1 : 1'b0 ;
assign  I_CONFIG_EN = (I_CAL_PS == WAIT_FOR_SENSOR_CFG) ? 1'b1 : 1'b0 ;
assign  config_en = I_CONFIG_EN | I_IDLE_WATI_TIMEOUT_P_DELAY;
//assign  config_en = I_CONFIG_EN;

assign debug[6] = decoded_data;
assign debug[5:2] = I_BIT_LEN[4:1];
assign debug[1] = I_TEST_BIT_LEN;
assign debug[0] = I_IDDR_Q[0];


endmodule

/*
always @(posedge sclock)
begin
    if (reset == 1'b1) 
    begin
        
    end
    else
    begin
        
    end
end
*/
