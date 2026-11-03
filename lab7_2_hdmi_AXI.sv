`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ECE-Illinois
// Engineer: Zuofu Cheng
// 
// Create Date: 06/08/2023 12:21:05 PM
// Design Name: 
// Module Name: hdmi_text_controller_v1_0_AXI
// Project Name: ECE 385 - hdmi_text_controller
// Target Devices: 
// Tool Versions: 
// Description: 
// This is a modified version of the Vivado template for an AXI4-Lite peripheral,
// rewritten into SystemVerilog for use with ECE 385.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.02 - File modified to be more consistent with generated template
// Revision 11/18 - Made comments less confusing
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1 ns / 1 ps

module hdmi_text_controller_v1_0_AXI #
(

    // Parameters of Axi Slave Bus Interface S_AXI
    // Modify parameters as necessary for access of full VRAM range

    // Width of S_AXI data bus
    parameter integer C_S_AXI_DATA_WIDTH	= 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH	= 16
)
(
    // Users to add ports here

    // User ports ends

    // Global Clock Signal
    input logic  S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input logic  S_AXI_ARESETN,
    // Write address (issued by master, acceped by Slave)
    input logic [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    // Write channel Protection type. This signal indicates the
        // privilege and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
    input logic [2 : 0] S_AXI_AWPROT,
    // Write address valid. This signal indicates that the master signaling
        // valid write address and control information.
    input logic  S_AXI_AWVALID,
    // Write address ready. This signal indicates that the slave is ready
        // to accept an address and associated control signals.
    output logic  S_AXI_AWREADY,
    // Write data (issued by master, acceped by Slave) 
    input logic [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    // Write strobes. This signal indicates which byte lanes hold
        // valid data. There is one write strobe bit for each eight
        // bits of the write data bus.    
    input logic [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    // Write valid. This signal indicates that valid write
        // data and strobes are available.
    input logic  S_AXI_WVALID,
    // Write ready. This signal indicates that the slave
        // can accept the write data.
    output logic  S_AXI_WREADY,
    // Write response. This signal indicates the status
        // of the write transaction.
    output logic [1 : 0] S_AXI_BRESP,
    // Write response valid. This signal indicates that the channel
        // is signaling a valid write response.
    output logic  S_AXI_BVALID,
    // Response ready. This signal indicates that the master
        // can accept a write response.
    input logic  S_AXI_BREADY,
    // Read address (issued by master, acceped by Slave)
    input logic [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether the
        // transaction is a data access or an instruction access.
    input logic [2 : 0] S_AXI_ARPROT,
    // Read address valid. This signal indicates that the channel
        // is signaling valid read address and control information.
    input logic  S_AXI_ARVALID,
    // Read address ready. This signal indicates that the slave is
        // ready to accept an address and associated control signals.
    output logic  S_AXI_ARREADY,
    // Read data (issued by slave)
    output logic [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    // Read response. This signal indicates the status of the
        // read transfer.
    output logic [1 : 0] S_AXI_RRESP,
    // Read valid. This signal indicates that the channel is
        // signaling the required read data.
    output logic  S_AXI_RVALID,
    // Read ready. This signal indicates that the master can
        // accept the read data and response information.
    input logic  S_AXI_RREADY,
    
    input  logic [10:0]  vram_addr,
    output logic [31:0] vram_data,
    //output logic [31:0] color,
    output logic [31:0] palette [0:7],
    input logic  [31:0] framecount,
    input logic  [9:0] drawX,
    input logic  [9:0] drawY
);

//@@ Port A is AXI; Port B is colormapper
logic [3:0]  bram_wea;
// @@ addr are now 12 bits long
logic [10:0] bram_addra;
logic [31:0] bram_douta;
logic [11:0] write_word_addr;
logic [11:0] read_word_addr;
//logic [31:0] color_reg;
logic        write_ok;
logic        read_ok;

//assign color = color_reg; //@@no longer need in 7.2, we using palette no

//@@ calc write& read word addr
assign write_word_addr = axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
assign read_word_addr  = axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];

//@@ FSM decides when writing is allowed
always_comb begin
    if ((read_state == IDLE) &&
        !(S_AXI_ARVALID && read_ok)) begin
        write_ok = 1'b1;
    end
    else begin
        write_ok = 1'b0;
    end
end

//@@ FSM decides when reading is ok
always_comb begin
    if ((read_state == IDLE) && aw_en && !axi_awready && !axi_wready && !axi_bvalid && !(S_AXI_AWVALID && S_AXI_WVALID)) begin
        read_ok = 1'b1;
    end
    else begin
        read_ok = 1'b0;
    end
end

//@@ Select BRAM Port A address
always_comb begin
    if (read_state != IDLE)
        bram_addra = read_word_addr;
    else if (axi_arready && S_AXI_ARVALID)
        bram_addra =S_AXI_ARADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
    else
        bram_addra = write_word_addr;
end

//@@ Generate BRAM byte-write enables
always_comb begin
    if (S_AXI_ARESETN && slv_reg_wren && (write_word_addr < 12'h4B0)) 
    begin
        bram_wea = S_AXI_WSTRB;
    end
    else begin
        bram_wea = 4'b0000;
    end
end

// @@ new block memory BRAM implement
blk_mem_gen_0 vram_bram (
    //AXI
    .clka  (S_AXI_ACLK),
    .ena   (1'b1),
    .wea   (bram_wea),
    .addra (bram_addra[11:0]),
    .dina  (S_AXI_WDATA),
    .douta (bram_douta),

    //color mapper
    .clkb  (S_AXI_ACLK),
    .enb   (1'b1),
    .web   (4'b0000),
    .addrb (vram_addr),
    .dinb  (32'b0),
    .doutb (vram_data)
);

// AXI4LITE signals
logic  [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
logic  axi_awready;
logic  axi_wready;
logic  [1 : 0] 	axi_bresp;
logic  axi_bvalid;
logic  [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
logic  axi_arready;
logic  [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
logic  [1 : 0] 	axi_rresp;
logic  	axi_rvalid;

//@@ AXI read FSM
typedef enum logic [1:0] {
    IDLE,       //@@waiting for a new AXI read
    READ,       //@@ Allow BRAM to read address
    WAIT_R,      //@@ waiting for ready signal
    RESPOND     //@@ respond to microblaze (wirte to microblaze)
} read_state_t;

read_state_t read_state;


// Example-specific design signals
// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
// ADDR_LSB is used for addressing 32/64 bit registers/memories
// ADDR_LSB = 2 for 32 bits (n downto 2)
// ADDR_LSB = 3 for 64 bits (n downto 3)
localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
localparam integer OPT_MEM_ADDR_BITS = 11;
//----------------------------------------------
//-- Signals for user logic register space example
//------------------------------------------------
//-- Number of Slave Registers 4
//logic [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
//logic [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
//logic [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
//logic [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
//
//Note: the provided Verilog template had the registered declared as above, but in order to give 
//students a hint we have replaced the 4 individual registers with an unpacked array of packed logic. 
//Note that you as the student will still need to extend this to the full register set needed for the lab.
//logic [C_S_AXI_DATA_WIDTH-1:0] slv_regs[604];   //@@old 7.1 code
logic	 slv_reg_rden;
logic	 slv_reg_wren;
logic	 aw_en;

// I/O Connections assignments

assign S_AXI_AWREADY	= axi_awready;
assign S_AXI_WREADY	= axi_wready;
assign S_AXI_BRESP	= axi_bresp;
assign S_AXI_BVALID	= axi_bvalid;
assign S_AXI_ARREADY = axi_arready;
assign S_AXI_RDATA	= axi_rdata;
assign S_AXI_RRESP	= axi_rresp;
assign S_AXI_RVALID	= axi_rvalid;
// Implement axi_awready generation
// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
// de-asserted when reset is low.

always_ff @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_awready <= 1'b0;
      aw_en <= 1'b1;
    end 
  else
    begin    
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en && write_ok)
        begin
          // slave is ready to accept write address when 
          // there is a valid write address and write data
          // on the write address and data bus. This design 
          // expects no outstanding transactions. 
          axi_awready <= 1'b1;
          aw_en <= 1'b0;
        end
        else if (S_AXI_BREADY && axi_bvalid)
            begin
              aw_en <= 1'b1;
              axi_awready <= 1'b0;
            end
      else           
        begin
          axi_awready <= 1'b0;
        end
    end 
end       

// Implement axi_awaddr latching
// This process is used to latch the address when both 
// S_AXI_AWVALID and S_AXI_WVALID are valid. 

always_ff @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_awaddr <= 0;
    end 
  else
    begin    
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en && write_ok)
        begin
          // Write Address latching 
          axi_awaddr <= S_AXI_AWADDR;
        end
    end 
end       

// Implement axi_wready generation
// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
// de-asserted when reset is low. 

always_ff @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_wready <= 1'b0;
    end 
  else
    begin    
      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en && write_ok)
        begin
          // slave is ready to accept write data when 
          // there is a valid write address and write data
          // on the write address and data bus. This design 
          // expects no outstanding transactions. 
          axi_wready <= 1'b1;
        end
      else
        begin
          axi_wready <= 1'b0;
        end
    end 
end   

// Implement memory mapped register select and write logic generation
// The write data is accepted and written to memory mapped registers when
// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
// select byte enables of slave registers while writing.
// These registers are cleared when reset (active low) is applied.
// Slave register write enable is asserted when valid address and data are available
// and the slave is ready to accept the write address and write data.
assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

//@@ reset color register instead of the whole slv_reg here, these need changes too
//always_ff @(posedge S_AXI_ACLK) begin
//    if (S_AXI_ARESETN == 1'b0) begin
//        color_reg <= 32'b0;
//    end else if (slv_reg_wren && write_word_addr == 12'h4B0) 
//    begin
//        for (int i = 0; i < 4; i++) begin
//            if (S_AXI_WSTRB[i])
//                color_reg[i*8 +: 8] <= S_AXI_WDATA[i*8 +: 8];
//        end
//    end
//end
//@@ above modified to work with week 1, but week 2 needs revision, shown below:
always_ff @(posedge S_AXI_ACLK)
begin
    if (S_AXI_ARESETN == 1'b0) 
    begin
        for (int i=0; i<8;i++)
        begin
            palette[i] <= 32'b0;
        end
    end 
    else if (slv_reg_wren && write_word_addr >= 12'h800 && write_word_addr <= 12'h807) //@check inrange
    begin
        for (int i = 0; i < 4; i++) begin
            if (S_AXI_WSTRB[i])
                palette[write_word_addr & 2'b11][i*8 +: 8] <= S_AXI_WDATA[i*8 +: 8];
        end
    end
end

// Implement write response logic generation
// The write response and response valid signals are asserted by the slave 
// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
// This marks the acceptance of address and indicates the status of 
// write transaction.

always_ff @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_bvalid  <= 0;
      axi_bresp   <= 2'b0;
    end 
  else
    begin    
      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
        begin
          // indicates a valid write response is available
          axi_bvalid <= 1'b1;
          axi_bresp  <= 2'b0; // 'OKAY' response 
        end                   // work error responses in future
      else
        begin
          if (S_AXI_BREADY && axi_bvalid) 
            //check if bready is asserted while bvalid is high) 
            //(there is a possibility that bready is always asserted high)   
            begin
              axi_bvalid <= 1'b0; 
            end  
        end
    end
end   

// Implement axi_arready generation
// axi_arready is asserted when the slave can accept a read address.
//@@FSM handshake-ready signal (transition)
assign axi_arready = read_ok;

//@@ put in the right addr to read
always_ff @(posedge S_AXI_ACLK)
begin
    if (S_AXI_ARESETN == 1'b0) 
    begin
        axi_araddr <= '0;
    end else if (axi_arready && S_AXI_ARVALID) begin
        axi_araddr <= S_AXI_ARADDR;
    end
end

// Implement axi_arvalid generation
// axi_rvalid indicates that valid read data and response are available.
assign slv_reg_rden = axi_arready && S_AXI_ARVALID;
logic [31:0] read_nonvram_data; //@@ the extra special things to read outside of vram (601-604)
logic read_is_vram;
logic [31:0] read_response_data;
always_comb 
begin
//@@ accounting for the x800 - x807 range of color palette
    read_nonvram_data = 32'b0;
    if (S_AXI_ARADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]>= 12'h800 && S_AXI_ARADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]<= 12'h807)
    begin
        read_nonvram_data =palette[S_AXI_ARADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]- 12'h800];
    end
    else 
    begin
        case (S_AXI_ARADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]) //@@ modified from old one
            12'h808: read_nonvram_data = framecount;
            12'h809: read_nonvram_data = {22'b0, drawX};
            12'h80A: read_nonvram_data = {22'b0, drawY};
            default: read_nonvram_data = 32'b0;
        endcase
    end
end
//always_comb begin
//    case (S_AXI_ARADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
//        10'h800: read_nonvram_data = color_reg;
//        default: read_nonvram_data = 32'b0;
//    endcase
//end

// Output register or memory read data
always_ff @(posedge S_AXI_ACLK) 
begin
    if (S_AXI_ARESETN == 1'b0) 
    begin
        read_state         <= IDLE;
        read_is_vram       <= 1'b0;
        read_response_data <= 32'b0;
        axi_rdata          <= 32'b0;
        axi_rvalid         <= 1'b0;
        axi_rresp          <= 2'b00;
    end
    else 
    begin
        case (read_state)

            IDLE: 
            begin
                axi_rvalid <= 1'b0;

                if (slv_reg_rden) 
                begin
                    read_is_vram <=
                        (S_AXI_ARADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] < 12'h4B0); //@@changed every 'd600 to 'h4B0

                    read_response_data <= read_nonvram_data;

                    read_state <= READ;
                end
            end

            READ:
            begin
                read_state <= WAIT_R;
            end

            WAIT_R: 
            begin
                axi_rdata <= read_is_vram ? bram_douta : read_response_data;

                axi_rresp  <= 2'b00; //@@ok
                axi_rvalid <= 1'b1;

                read_state <= RESPOND; 
            end

            RESPOND: 
            begin
                if (axi_rvalid && S_AXI_RREADY) begin
                    axi_rvalid <= 1'b0;
                    read_state <= IDLE;
                end
            end

            default: read_state <= IDLE;
        endcase
    end
end

// Add user logic here

// User logic ends

endmodule

