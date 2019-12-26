module IDDR(
    inclock,
    datain,
    aclr,
    dataout_h,
    dataout_l
);


input wire    inclock;
input wire    datain;
input wire    aclr;
output reg    dataout_h;
output reg    dataout_l;

reg    neg_reg_out;





always@(posedge inclock or negedge aclr)
begin
if (aclr)
    begin
    dataout_h <= 0;
    end
else
    begin
    dataout_h <= datain;
    end
end


always@(negedge inclock or negedge aclr)
begin
if (aclr)
    begin
    neg_reg_out <= 0;
    end
else
    begin
    neg_reg_out <= datain;
    end
end


always@(inclock or neg_reg_out)
begin
if (inclock)
    dataout_l <= neg_reg_out;
end


endmodule
