`include "synchronizer.v"
`include "read_ptr_hold.v"
`include "write_ptr_hold.v"
module async_fifo#(parameter width = 32, depth = 45)(

    input wire write_clk, read_clk, write_resetn, read_resetn, write_enable, read_enable,
    input wire[width-1 : 0] write_data,

    output reg full_flag, empty_flag,
    output reg [width-1 : 0] read_data
    );

  
    reg [$clog2(depth)-1:0] async_write_ptr, sync_write_ptr, async_read_ptr, sync_read_ptr;
    reg [$clog2(depth)-1:0] checked_write_ptr, checked_read_ptr;
    reg [width-1:0] fifo [0:depth-1];
    
    // In the next 2 always blocks, we suppose that the two resets come together
    // If one of them only comes, it will cause some issues in the reading or writing operation
    // To solve this issue check comments in the next lines
    always@(posedge write_clk, negedge write_resetn) 
    begin
        if(!write_resetn) // or with read_resetn  to solve the issue mentioned above
        begin
            checked_write_ptr <= 0;
            full_flag <= 0;
        end
    end

    always@(posedge read_clk, negedge read_resetn) 
    begin
        if(!read_resetn) // or with write_resetn to solve the issue mentioned above
        begin
            checked_read_ptr <= 0;
            empty_flag <= 1;
            read_data <= 0;
        end
    end
    
    always@(posedge write_clk) 
    begin
        if(write_enable & !full_flag)
        begin
            fifo[checked_write_ptr] <= write_data;
            if(checked_write_ptr == depth - 1)
                checked_write_ptr <= 0;
            else
                checked_write_ptr <= checked_write_ptr + 1;
        end
    end
    
    always@(posedge read_clk) 
    begin
        if(read_enable & !empty_flag) 
        begin
            read_data <= fifo[checked_read_ptr];
            if(checked_read_ptr == depth - 1)
                checked_read_ptr <= 0;
            else
                checked_read_ptr <= checked_read_ptr + 1;
        end
    end
    
    write_ptr_hold WH(
        .gray_read_ptr(sync_read_ptr),
        .gray_write_ptr(async_write_ptr),
        .binary_write_ptr(checked_write_ptr),
        .full_flag(full_flag)
        );

    synchronizer SYNC0(
        .clk(write_clk), 
        .resetn(write_resetn), 
        .d_in(async_read_ptr), 
        .d_out(sync_write_ptr)
        );

    synchronizer SYNC1(
        .clk(read_clk), 
        .resetn(read_resetn), 
        .d_in(async_write_ptr), 
        .d_out(sync_read_ptr)
        );

    read_ptr_hold RH(
        .gray_write_ptr(sync_write_ptr), 
        .gray_read_ptr(async_read_ptr), 
        .binary_read_ptr(checked_read_ptr), 
        .empty_flag(empty_flag)
        );
endmodule