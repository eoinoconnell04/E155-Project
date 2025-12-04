/*
Authors: Lattice Semiconductor (original)
         Eoin O'Connell (eoconnell@hmc.edu)
         Drake Gonzales (drgonzales@g.hmc.edu)
Date: Dec. 4, 2025
Module Function: Lattice I2S codec for audio transceiver
- Configurable data width (default 24-bit)
- Master mode clock generation
- Supports both transmit and receive modes
*/

module lscc_i2s_codec #
// -----------------------------------------------------------------------------
// Module Parameters
// -----------------------------------------------------------------------------
  (
    parameter DATA_WIDTH  = 24,
    parameter TRANSCEIVER_MODE = 1
  )
// -----------------------------------------------------------------------------
// Input/Output Ports
// -----------------------------------------------------------------------------
  (
    reset_n_i,
    lmmi_clk_i,
    conf_res_i,
    conf_ratio_i,
    conf_swap_i,
    conf_en_i,
    i2s_sd_i,
    sample_dat_i,
    sample_dat_o,
    mem_rdwr_o,
    i2s_sd_o,
    i2s_sck_o,
    i2s_ws_o
   );

input                      reset_n_i;     //-- Reset
input                      lmmi_clk_i;    //-- LMMI clock
input              [5 : 0] conf_res_i;    //-- sample resolution
input              [9 : 0] conf_ratio_i;  //-- clock divider ratio
input                      conf_swap_i;   //-- left/right sample order
input                      conf_en_i;     //-- transmitter/recevier enable
input                      i2s_sd_i;      //-- I2S serial data input
input             [31 : 0] sample_dat_i;  //-- audio data
output            [31 : 0] sample_dat_o;  //-- audio data
output                     mem_rdwr_o;    //-- sample buffer read/write
output                     i2s_sd_o;      //-- I2S serial data output
output                     i2s_sck_o;     //-- I2S clock output
output                     i2s_ws_o;      //-- I2S word select output

// -----------------------------------------------------------------------------
// Local Parameters
// -----------------------------------------------------------------------------
localparam IDLE     = 0;
localparam WAIT_CLK = 1;
localparam TRX_DATA = 2;
localparam RX_WRITE = 3;
localparam SYNC     = 4;

// -----------------------------------------------------------------------------
// Sequential Registers
// -----------------------------------------------------------------------------
reg                      i2s_clk_en_r;
reg              [9 : 0] clk_cnt_r;
reg              [4 : 0] sd_ctrl_r;
reg              [4 : 0] bit_cnt_r, bits_to_trx_r; //integer range 0 to 63;
reg                      toggle_r,neg_edge_r, ws_pos_edge_r,ws_neg_edge_r;
reg [DATA_WIDTH - 1 : 0] data_in_r;// (DATA_WIDTH - 1 downto 0);
reg                      i2s_ws_r, new_word_r;
reg                      imem_rdwr_r;
reg              [4 : 0] ws_cnt_r; // integer range 0 to 31;

reg                      i2s_sd_r;

// -----------------------------------------------------------------------------
// Wire Declarations
// -----------------------------------------------------------------------------
wire             [5 : 0] conf_res_w;
wire             [9 : 0] conf_ratio_w;
wire                     conf_swap_w;
wire                     conf_en_w;
wire                     receiver_w;

// -----------------------------------------------------------------------------
// Assign Statements
// -----------------------------------------------------------------------------
assign i2s_sd_o     = i2s_sd_r;
assign conf_res_w   = conf_res_i;
assign conf_ratio_w = conf_ratio_i;
assign conf_swap_w  = conf_swap_i;
assign conf_en_w    = conf_en_i;

assign receiver_w = (TRANSCEIVER_MODE==1)? 1'b1:1'b0;

assign i2s_sck_o = toggle_r;

assign  mem_rdwr_o   = imem_rdwr_r;
assign  sample_dat_o = {{(32-DATA_WIDTH){1'b0}}, data_in_r};

// -----------------------------------------------------------------------------
// Sequential Blocks
// -----------------------------------------------------------------------------

//-- I2S clock enable generation, master mode. The clock is a fraction of the
//-- LMMI bus clock, determined by the conf_ratio_w value.
always@(posedge lmmi_clk_i)
  if(reset_n_i == 1'b0) begin
    i2s_clk_en_r <= 1'b0;
    clk_cnt_r    <= 1;
    neg_edge_r   <= 1'b0;
    toggle_r     <= 1'b0;
  end else begin
    if (conf_en_w ==1'b0) begin       //-- disabled
       i2s_clk_en_r <= 1'b0;
       clk_cnt_r    <= 1;
       neg_edge_r   <= 1'b0;
       toggle_r     <= 1'b0;
    end else begin                   //  -- enabled
      if (clk_cnt_r < conf_ratio_w) begin
        clk_cnt_r    <= (clk_cnt_r + 1) % 1024;
        i2s_clk_en_r <= 1'b0;
      end else begin
        clk_cnt_r    <= 1;
        i2s_clk_en_r <= 1'b1;
        neg_edge_r   <= !neg_edge_r;
      end
      toggle_r <= neg_edge_r;
    end
  end


//-- Process to generate word select signal, master mode
assign  i2s_ws_o = i2s_ws_r;
always@ (posedge lmmi_clk_i) begin
  if(reset_n_i == 1'b0) begin
    i2s_ws_r      <= 1'b0;
    ws_cnt_r      <= 0;
    ws_pos_edge_r <= 1'b0;
    ws_neg_edge_r <= 1'b0;
  end else begin
    if (conf_en_w == 1'b0) begin
      i2s_ws_r      <= 1'b0;
      ws_cnt_r      <= 0;
      ws_pos_edge_r <= 1'b0;
      ws_neg_edge_r <= 1'b0;
    end else begin
      if ((i2s_clk_en_r == 1'b1) && (toggle_r == 1'b1)) begin
        if (ws_cnt_r < bits_to_trx_r) begin
          ws_cnt_r <= ws_cnt_r + 1;
        end else begin
          i2s_ws_r <= !i2s_ws_r;
          ws_cnt_r <= 0;
          if (i2s_ws_r == 1'b1) begin
            ws_neg_edge_r <= 1'b1;
          end else begin
            ws_pos_edge_r <= 1'b1;
          end
        end
      end else begin
        ws_pos_edge_r <= 1'b0;
        ws_neg_edge_r <= 1'b0;
      end
    end
  end
end

//-- Process to receive data on i2s_sd_i, or transmit data on i2s_sd_o
always@(posedge lmmi_clk_i) begin
  if(reset_n_i == 1'b0) begin
    imem_rdwr_r   <= 1'b0;
    sd_ctrl_r     <= IDLE;
    data_in_r     <= 0;
    bit_cnt_r     <= 0;
    bits_to_trx_r <= 0;
    new_word_r    <= 1'b0;
    i2s_sd_r      <= 1'b0;
  end else begin
    if (conf_en_w == 1'b0) begin          //-- codec disabled
      imem_rdwr_r   <= 1'b0;
      sd_ctrl_r     <= IDLE;
      data_in_r     <= 0;
      bit_cnt_r     <= 0;
      bits_to_trx_r <= 0;
      new_word_r    <= 1'b0;
      i2s_sd_r      <= 1'b0;
    end else begin
      case (sd_ctrl_r)
        IDLE : begin
          imem_rdwr_r <= 1'b0;
          if ((conf_res_w > 7) && (conf_res_w <= DATA_WIDTH)) begin
            bits_to_trx_r <= conf_res_w - 1;
          end else begin
            bits_to_trx_r <= 7;
          end
          if ((ws_pos_edge_r == 1'b1 & conf_swap_w == 1'b1) ||
            (ws_neg_edge_r == 1'b1 & conf_swap_w == 1'b0)) begin
            if (receiver_w == 1'b1) begin        //-- recevier
              sd_ctrl_r <= WAIT_CLK;
            end else begin
              imem_rdwr_r <= 1'b1;  //-- read first data if transmitter
              sd_ctrl_r   <= TRX_DATA;
            end
          end
        end
        WAIT_CLK : begin        //-- wait for first bit after WS
          bit_cnt_r  <= 0;
          new_word_r <= 1'b0;
          data_in_r  <= 0;
          if ((i2s_clk_en_r == 1'b1) && (neg_edge_r == 1'b0)) begin
            sd_ctrl_r <= TRX_DATA;
          end
        end
        TRX_DATA : begin         //-- transmit/receive serial data
          imem_rdwr_r <= 1'b0;
          if ((ws_pos_edge_r == 1'b1) || (ws_neg_edge_r == 1'b1)) begin
            new_word_r <= 1'b1;
          end

          //-- recevier operation
          if (receiver_w == 1'b1) begin
            if ((i2s_clk_en_r == 1'b1) && (neg_edge_r == 1'b1)) begin
              if ((bit_cnt_r < bits_to_trx_r) && (new_word_r == 1'b0)) begin
                bit_cnt_r                            <= bit_cnt_r + 1;
                data_in_r[bits_to_trx_r - bit_cnt_r] <= i2s_sd_i;
              end else begin
                imem_rdwr_r                          <= 1'b1;
                data_in_r[bits_to_trx_r - bit_cnt_r] <= i2s_sd_i;
                sd_ctrl_r                            <= RX_WRITE;
              end
            end
          end
          //-- transmitter operation
          if (receiver_w == 1'b0) begin
            if ((i2s_clk_en_r == 1'b1) && (neg_edge_r == 1'b0)) begin
              if ((bit_cnt_r < bits_to_trx_r) && (new_word_r == 1'b0)) begin
                bit_cnt_r <= bit_cnt_r + 1;
                i2s_sd_r  <= sample_dat_i[bits_to_trx_r - bit_cnt_r];
              end else begin
                bit_cnt_r <= bit_cnt_r + 1;
                if (bit_cnt_r > bits_to_trx_r) begin
                  i2s_sd_r <= 1'b0;
                end else begin
                  i2s_sd_r <= sample_dat_i[0];
                end
                //-- transmitter address counter
                imem_rdwr_r <= 1'b1;
                sd_ctrl_r   <= SYNC;
              end
            end
          end
        end
        RX_WRITE : begin         //-- write received word to sample buffer
          imem_rdwr_r <= 1'b0;
          sd_ctrl_r <= SYNC;
        end
        SYNC : begin            //-- synchronise with next word
          imem_rdwr_r <= 1'b0;
          bit_cnt_r   <= 0;
          if ((ws_pos_edge_r ==1'b1) || (ws_neg_edge_r == 1'b1)) begin
            new_word_r <= 1'b1;
          end

          new_word_r <= 1'b0;
          data_in_r  <= 0;
          sd_ctrl_r  <= TRX_DATA;
        end
        default: begin sd_ctrl_r  <= IDLE; end
      endcase
    end
  end
end

endmodule

