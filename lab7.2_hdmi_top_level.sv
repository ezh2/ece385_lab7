//Provided HDMI_Text_controller_v1_0 for HDMI AXI4 IP 
//Fall 2024 Distribution

//Modified 3/10/24 by Zuofu
//Updated 11/18/24 by Zuofu


`timescale 1 ns / 1 ps

module hdmi_text_controller_v1_0 #
(
    // Parameters of Axi Slave Bus Interface S00_AXI
    // Modify parameters as necessary for access of full VRAM range

    parameter integer C_AXI_DATA_WIDTH	= 32,
    parameter integer C_AXI_ADDR_WIDTH	= 16 
)
(
    // Users to add ports here

    output logic hdmi_clk_n,
    output logic hdmi_clk_p,
    output logic [2:0] hdmi_tx_n,
    output logic [2:0] hdmi_tx_p,

    // User ports ends
    // Do not modify the ports beyond this line


    // Ports of Axi Slave Bus Interface AXI
    input logic  axi_aclk,
    input logic  axi_aresetn,
    input logic [C_AXI_ADDR_WIDTH-1 : 0] axi_awaddr,
    input logic [2 : 0] axi_awprot,
    input logic  axi_awvalid,
    output logic  axi_awready,
    input logic [C_AXI_DATA_WIDTH-1 : 0] axi_wdata,
    input logic [(C_AXI_DATA_WIDTH/8)-1 : 0] axi_wstrb,
    input logic  axi_wvalid,
    output logic  axi_wready,
    output logic [1 : 0] axi_bresp,
    output logic  axi_bvalid,
    input logic  axi_bready,
    input logic [C_AXI_ADDR_WIDTH-1 : 0] axi_araddr,
    input logic [2 : 0] axi_arprot,
    input logic  axi_arvalid,
    output logic  axi_arready,
    output logic [C_AXI_DATA_WIDTH-1 : 0] axi_rdata,
    output logic [1 : 0] axi_rresp,
    output logic  axi_rvalid,
    input logic  axi_rready
);

//additional logic variables as necessary to support VGA, and HDMI modules.
logic clk_25MHz, clk_125MHz, clk, clk_100MHz;
logic locked;
logic [9:0] drawX, drawY, ballxsig, ballysig, ballsizesig;

logic hsync, vsync, vde;
logic [3:0] red, green, blue;
logic reset_ah;
    
assign reset_ah = ~axi_aresetn;


logic [10:0] font_addr;
logic [7:0] font_data;
logic [7:0] character_code;
logic [3:0] FGD_IDX;
logic [3:0] BKG_IDX;
logic [1:0] byte_ind;
logic [10:0] word_ind; //@@ changed to 11bits
logic [11:0] char_ind;
logic [31:0] vram;
logic [31:0] palette[0:7];

assign char_ind = (drawY/16)*80+(drawX/8);
assign word_ind = char_ind/2;
assign byte_ind = char_ind[0];

always_comb begin
    character_code = 7'd0;
    FGD_IDX = 4'd0;
    BKG_IDX = 4'd0;
    if(byte_ind == 1'b0)
    begin
        character_code = vram [15:8]; //@@changed for 7.2
        FGD_IDX =vram[7:4];
        BKG_IDX =vram[3:0];
    end
    else
    begin
        character_code = vram [31:24]; //@@changed for 7.2
        FGD_IDX = vram [19:16];
        BKG_IDX = vram [23:20];
    end
end
logic font_pix;
assign font_addr = {character_code[6:0], drawY[3:0]};
//assign font_addr = {7'd65, drawY[3:0]};
assign font_pix = font_data[7-drawX[2:0]];


// Instantiation of Axi Bus Interface AXI
hdmi_text_controller_v1_0_AXI # ( 
    .C_S_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH)
) hdmi_text_controller_v1_0_AXI_inst (
    .vram_addr(word_ind),
    .vram_data(vram),
    .palette(palette), //@@ changed color to palette; todo: account for packed
    .framecount(framecount),
    .drawX(drawX),
    .drawY(drawY),
    .S_AXI_ACLK(axi_aclk),
    .S_AXI_ARESETN(axi_aresetn),
    .S_AXI_AWADDR(axi_awaddr),
    .S_AXI_AWPROT(axi_awprot),
    .S_AXI_AWVALID(axi_awvalid),
    .S_AXI_AWREADY(axi_awready),
    .S_AXI_WDATA(axi_wdata),
    .S_AXI_WSTRB(axi_wstrb),
    .S_AXI_WVALID(axi_wvalid),
    .S_AXI_WREADY(axi_wready),
    .S_AXI_BRESP(axi_bresp),
    .S_AXI_BVALID(axi_bvalid),
    .S_AXI_BREADY(axi_bready),
    .S_AXI_ARADDR(axi_araddr),
    .S_AXI_ARPROT(axi_arprot),
    .S_AXI_ARVALID(axi_arvalid),
    .S_AXI_ARREADY(axi_arready),
    .S_AXI_RDATA(axi_rdata),
    .S_AXI_RRESP(axi_rresp),
    .S_AXI_RVALID(axi_rvalid),
    .S_AXI_RREADY(axi_rready)
);
clk_wiz_0 clk_wiz_inst (
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .reset(reset_ah),
        .locked(locked),
        .clk_in1(axi_aclk)
    );
vga_controller vga (
        .pixel_clk(clk_25MHz),
        .reset(reset_ah),
        .hs(hsync),
        .vs(vsync),
        .active_nblank(vde),
        .drawX(drawX),
        .drawY(drawY)
    );   
hdmi_tx_0 vga_to_hdmi (
        //Clocking and Reset
        .pix_clk(clk_25MHz),
        .pix_clkx5(clk_125MHz),
        .pix_clk_locked(locked),
        .rst(reset_ah),
        //Color and Sync Signals
        .red(red),
        .green(green),
        .blue(blue),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
        
        //aux Data (unused)
        .aux0_din(4'b0),
        .aux1_din(4'b0),
        .aux2_din(4'b0),
        .ade(1'b0),
        
        //Differential outputs
        .TMDS_CLK_P(hdmi_clk_p),
        .TMDS_CLK_N(hdmi_clk_n),
        .TMDS_DATA_P(hdmi_tx_p),
        .TMDS_DATA_N(hdmi_tx_n)         
    );
logic pixel;
assign pixel=font_pix^character_code[7];

always_comb begin
    if (!pixel) //@@ background
    begin
        red = BKG_IDX%2==0 ? palette[BKG_IDX/2][11:8]: palette[BKG_IDX/2][27:24];
        green = BKG_IDX%2==0 ? palette[BKG_IDX/2][7:4]: palette[BKG_IDX/2][23:20];
        blue= BKG_IDX%2==0 ? palette[BKG_IDX/2][3:0] : palette[BKG_IDX/2][19:16];
    end

    else //@@ foreground
    begin
        red = FGD_IDX%2==0 ? palette[FGD_IDX/2][11:8]: palette[FGD_IDX/2][27:24];
        green = FGD_IDX%2==0 ? palette[FGD_IDX/2][7:4]: palette[FGD_IDX/2][23:20];
        blue = FGD_IDX%2==0 ? palette[FGD_IDX/2][3:0]:palette[FGD_IDX/2][19:16];
    end
end

logic [31:0] framecount;
logic vsync_old;
always_ff @(posedge clk_125MHz or posedge reset_ah)
begin
    if (reset_ah)
    begin
        vsync_old <= 1'b0;
        framecount <= 0;
    end
    else
    begin
        vsync_old <= vsync;
        if (vsync_old && !vsync)
        begin
            framecount <= framecount + 1;
        end
    end
end    
//color_mapper color_instance(
//        .BallX(0),
//        .BallY(0),
//        .DrawX(drawX),
//        .DrawY(drawY),
//        .Ball_size(0),
//        .Red(red),
//        .Green(green),
//        .Blue(blue)
//    );
font_rom font_rom_inst (
    .addr(font_addr),
    .data(font_data)
);

//Instiante clocking wizard, VGA sync generator modules, and VGA-HDMI IP here. For a hint, refer to the provided
//top-level from the previous lab. You should get the IP to generate a valid HDMI signal (e.g. blue screen or gradient)
//prior to working on the text drawing.

// User logic ends

endmodule
