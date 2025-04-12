`timescale 1ns/1ps

module moore_fsm_unlocking_tb();

    // Parameters
    parameter CLOCK_PERIOD = 10; // 10ns = 100MHz clock

    // Test bench signals
    logic clk;
    logic reset;
    logic serial_valid;
    logic serial_data;
    logic serial_ready;
    logic unlock;
    logic pwd_incorrect;

    // Instantiate the Unit Under Test (UUT)
    moore_fsm_unlocking uut (
        .clk(clk),
        .reset(reset),
        .serial_data(serial_data),
        .serial_valid(serial_valid),
        .serial_ready(serial_ready),
        .unlock(unlock),
        .pwd_incorrect(pwd_incorrect)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end

    // State monitoring for debug
    string state_string;
    always_comb begin
        case (uut.current_state)
            uut.IDLE: state_string = "IDLE";
            uut.S_1: state_string = "S_1";
            uut.S_10: state_string = "S_10";
            uut.S_101: state_string = "S_101";
            uut.S_1011: state_string = "S_1011";
            uut.INCORRECT: state_string = "INCORRECT";
            default: state_string = "UNKNOWN";
        endcase
    end

    // Task to send a single bit to the FSM with timeout
    task automatic send_bit(input logic bit_value);
        automatic int timeout_count = 0;
        
        // Wait for ready with timeout
        while (serial_ready != 1'b1 && timeout_count < 10) begin
            @(posedge clk);
            timeout_count++;
            
            // If timeout occurs, report and force reset
            if (timeout_count >= 10) begin
                $display("WARNING: serial_ready timeout - forcing reset");
                reset = 1;
                @(posedge clk);
                @(posedge clk);
                reset = 0;
                @(posedge clk);
                break;
            end
        end
        
        serial_valid = 1;
        serial_data = bit_value;
        @(posedge clk);
        
        // Print current state and outputs for debugging
        $display("Time: %0t, Bit: %b, State: %s, Unlock: %b, Incorrect: %b, Ready: %b", 
                 $time, bit_value, state_string, unlock, pwd_incorrect, serial_ready);
        
        serial_valid = 0;
        @(posedge clk);
    endtask

    // Task to send a sequence of bits with reset before each sequence
    task automatic send_seq(input logic [3:0] seq);
        // All variable declarations must come first
        logic was_unlocked;
        logic was_incorrect;
        logic unlock_observed;
        logic incorrect_observed;
        int i;
        
        // Initialize variables
        was_unlocked = 0;
        was_incorrect = 0;
        unlock_observed = 0;
        incorrect_observed = 0;
        
        // Now we can have executable statements
        $display("Sending sequence: %b", seq);
        
        // Reset the FSM before sending the sequence
        reset = 1;
        repeat(2) @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        // Send each bit and monitor for unlock or incorrect signals
        for (i = 3; i >= 0; i = i - 1) begin
            send_bit(seq[i]);
            // Check if unlock or incorrect was triggered
            if (unlock && !unlock_observed) begin
                was_unlocked = 1;
                unlock_observed = 1;
            end
            
            if (pwd_incorrect && !incorrect_observed) begin
                was_incorrect = 1;
                incorrect_observed = 1;
            end
            
            // If we already detected an error, no need to continue
            if (was_incorrect) break;
        end
        
        // Wait for FSM to process and return to IDLE
        repeat(3) @(posedge clk);
        
        // Display final state after sequence
        $display("Final state after sequence %b: %s, Unlock detected: %b, Incorrect detected: %b", 
                 seq, state_string, was_unlocked, was_incorrect);
    endtask

    // Test sequence
    initial begin
        // Initialize signals
        reset = 1;
        serial_valid = 0;
        serial_data = 0;

        // Apply reset
        repeat(2) @(posedge clk);
        reset = 0;
        @(posedge clk);

        // Test Case 1: Correct unlock sequence "1011"
        $display("\n=== Test Case 1: Correct unlock sequence 1011 ===");
        send_seq(4'b1011);

        // Test Case 2: Incorrect sequence "1001" - wrong 3rd bit
        $display("\n=== Test Case 2: Incorrect sequence 1001 ===");
        send_seq(4'b1001);

        // Test Case 3: Incorrect sequence "0011" - wrong 1st bit
        $display("\n=== Test Case 3: Incorrect sequence 0011 ===");
        send_seq(4'b0011);

        // Test Case 4: Incorrect sequence "1111" - wrong 2nd bit
        $display("\n=== Test Case 4: Incorrect sequence 1111 ===");
        send_seq(4'b1111);

        // Test Case 5: Partial sequence "101" (not completing)
        $display("\n=== Test Case 5: Partial sequence 101 (incomplete) ===");
        
        // Reset the FSM before sending the sequence
        reset = 1;
        repeat(2) @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        send_bit(1);
        send_bit(0);
        send_bit(1);
        // Don't send the 4th bit - this tests if the FSM waits properly

        // End simulation after some delay
        repeat(5) @(posedge clk);
        $display("\nSimulation complete");
        $finish;
    end

    // Add waveform monitoring
    initial begin
        $display("Starting simulation");
        // Uncomment for waveform dumping if needed
        // $dumpfile("moore_unlock_fsm_waves.vcd");
        // $dumpvars(0, moore_fsm_unlocking_tb);
    end

endmodule