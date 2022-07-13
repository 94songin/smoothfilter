module smoothfilter(
						input						clk,
						input						rst_n,
						
						input						i_strb,
						input		[7:0]			i_data,
						
						output	reg	[7:0]	o_data,
						output	reg			o_strb,
						
						input						kernel_write,
						input		[3:0]			kernel_idx,
						input		[7:0]			kernel_data
);



reg			garbage;

reg	[3:0]	cnt; //counting input strobes
reg	[7:0]	cnt_x; /* counting coordinate	*/						
reg	[7:0]	cnt_y; /* of output				*/
reg	[7:0]	i_data_d;

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		garbage	<=	1'b1; 	//garbage value
		cnt		<= 7;
		cnt_x		<= 254;		/*reset*/
		cnt_y		<= 254;
		i_data_d <= 'b0;
	end
	else begin
		if(i_strb) begin
			cnt_x	<= (cnt_x == 255) ? 0 : cnt_x+1;
			if(cnt_x == 255) begin
				cnt_y <= (cnt_y == 255) ? 0 : cnt_y+1;		/* counter */
				if(cnt_y == 255) begin
					garbage <= 1'b0;		// finish. garbage reset
				end
			end
		end
		if(i_strb == 1'b1) begin
			cnt <= 0;
		end
		else if(cnt<7) begin
			cnt <= cnt+1;
		end
		if(i_strb == 1'b1) begin
			i_data_d <= i_data;
		end
		
	end
end

reg	[7:0]		ibuf[2:0][2:0];	// 9 reg for pixel data
wire	[7:0]		data_out;			// memory output data
integer i,j;
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i=0;i<3;i=i+1) begin
			for(j=0;j<3;j=j+1) begin
				ibuf[i][j] <= 'b0;
			end
		end
	end
	else begin
		if(cnt == 0) begin // at the cycle 0
			for(i=0;i<3;i=i+1) begin
				for(j=0;j<2;j=j+1) begin
					ibuf[i][j] <= ibuf[i][j+1];	//shifting to left
				end
			end
			ibuf[2][2] <= i_data_d;		//store new input data
		end
		if(cnt == 1) begin
			ibuf[0][2] <= data_out;	
		end										//store data from memory
		if(cnt == 2) begin
			ibuf[1][2] <= data_out;
		end
	end
end


/* memory */
wire		mem_rd = (cnt == 0) || (cnt == 1);
wire		mem_wr = (cnt == 2);

reg		[8:0]		wr_addr;
wire		[8:0]		rd_addr0 = wr_addr;
wire		[8:0]		rd_addr1 = (wr_addr<256) ? wr_addr+256 : wr_addr-256;
wire		[8:0]		rd_addr = (cnt == 0) ? rd_addr0 : rd_addr1;

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		wr_addr <= 0;
	end
	else begin
		if(mem_wr == 1'b1) begin
			wr_addr <= (wr_addr == 2*256-1) ? 0 : wr_addr + 1;
		end
	end
end

wire					cs = mem_rd | mem_wr;
wire					write_en = mem_wr;
wire		[8:0]		addr = (mem_wr == 1'b1) ? wr_addr : rd_addr;
wire		[7:0]		data_in = i_data_d;

sram #(.
				WIDTH(8),.
				DEPTH(2*256)
	) buf0 (.
				clk(clk),.
				cs(cs),.
				write_en(write_en),.
				addr(addr),.
				data_in(data_in),.
				data_out(data_out)
);

/*filter operator setting*/
reg signed	[7:0]		kernel[0:8];
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		kernel[0]	<=	8'h08;
		kernel[1]	<=	8'h10;
		kernel[2]	<=	8'h08;
		kernel[3]	<=	8'h10;
		kernel[4]	<=	8'h20;
		kernel[5]	<=	8'h10;
		kernel[6]	<=	8'h08;
		kernel[7]	<=	8'h10;
		kernel[8]	<=	8'h08;
	end
	else begin
		if(kernel_write) begin
			kernel[kernel_idx] <= kernel_data;
		end
	end
end

/*filter operation*/
reg	signed	[15:0]	mul[2:0][2:0];
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i=0;i<3;i=i+1) begin
			for(j=0;j<3;j=j+1) begin
				mul[i][j] <= 'b0;
			end
		end
	end
	else begin
		if((cnt==3)&&(garbage==1'b0)) begin //On boundary -> 0 (padding)
			mul[0][0]	<=	((cnt_y>0)&&(cnt_x>0)) 			? ibuf[0][0] * kernel[0] : 'b0;
			mul[0][1]	<=	((cnt_y>0))				 			? ibuf[0][1] * kernel[1] : 'b0;
			mul[0][2]	<=	((cnt_y>0)&&(cnt_x<255)) 		? ibuf[0][2] * kernel[2] : 'b0;
			mul[1][0]	<=	((cnt_x>0))				 			? ibuf[1][0] * kernel[3] : 'b0;
			mul[1][1]	<=											  ibuf[1][1] * kernel[4];
			mul[1][2]	<=	((cnt_x<255))						? ibuf[1][2] * kernel[5] : 'b0;
			mul[2][0]	<=	((cnt_y<255)&&(cnt_x>0)) 		? ibuf[2][0] * kernel[6] : 'b0;
			mul[2][1]	<=	((cnt_y<255))						? ibuf[2][1] * kernel[7] : 'b0;
			mul[2][2]	<=	((cnt_y<255)&&(cnt_x<255))	 	? ibuf[2][2] * kernel[8] : 'b0;
		end
	end
end

reg	signed	[19:0]	sum_in;
reg	signed	[19:0]	sum;
always@(*) begin
	sum_in = 0;
	for(i=0;i<3;i=i+1) begin
		for(j=0;j<3;j=j+1) begin
			sum_in = sum_in + mul[i][j];
		end
	end
end

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		sum <= 'b0;
	end
	else begin
		if((cnt==4)&&(garbage == 1'b0)) begin
			sum <= sum_in;
		end
	end
end

/*fixed point and rounding, saturation*/
wire	[19:0]	pd_rnd_1 = sum + (1<<6);
wire	[12:0]	pd_rnd = pd_rnd_1[19:7];
wire	[7:0]		pd_out = (pd_rnd < 0) ? 0 :
								(pd_rnd > 255) ? 255 : pd_rnd[7:0];
/*output*/
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		o_strb <= 1'b0;
		o_data <= 'b0;
	end
	else begin
		o_strb <= ((cnt == 5)&&(garbage == 1'b0));
		if((cnt==5)&&(garbage == 1'b0)) begin
			o_data <= pd_out;
		end
	end
end

endmodule
