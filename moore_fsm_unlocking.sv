module moore_fsm_unlocking (
    input logic clk,
    input logic reset,
    input logic serial_data,
    input logic serial_valid,
    output logic unlock,
    output logic pwd_incorrect,
    output logic serial_ready
);

    // States require more states in Moore FSM since output depends only on state
    enum logic [2:0] {
        IDLE = 3'b000,     // Initial state
        S_1 = 3'b001,      // Got 1
        S_10 = 3'b010,     // Got 10
        S_101 = 3'b011,    // Got 101
        S_1011 = 3'b100,   // Got 1011 (unlocked)
        INCORRECT = 3'b101 // Wrong input received
    } current_state, next_state;

    // Counter for timeout in error and unlock states
    logic [1:0] timeout_counter;
    logic timeout_reset, timeout_enable;

    // 1. State Sequencer (Sequential Logic)
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Timeout counter for error and unlock state
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            timeout_counter <= 2'b00;
        else if (timeout_reset)
            timeout_counter <= 2'b00;
        else if (timeout_enable)
            timeout_counter <= timeout_counter + 2'b01;
        else
            timeout_counter <= timeout_counter; // Explicitly hold value
    end

    // 2. Next-State Decoder (Combinational Logic)
    always_comb begin
        next_state = current_state; // Default: hold state
        timeout_enable = 1'b0;
        timeout_reset = 1'b0;
        
        case (current_state)
            IDLE: begin
                if (serial_valid) begin
                    if (serial_data == 1'b1)
                        next_state = S_1;
                    else
                        next_state = INCORRECT;
                end
                timeout_reset = 1'b1; // Reset timeout counter in IDLE
            end
            
            S_1: begin
                if (serial_valid) begin
                    if (serial_data == 1'b0)
                        next_state = S_10;
                    else
                        next_state = INCORRECT;
                end
            end
            
            S_10: begin
                if (serial_valid) begin
                    if (serial_data == 1'b1)
                        next_state = S_101;
                    else
                        next_state = INCORRECT;
                end
            end
            
            S_101: begin
                if (serial_valid) begin
                    if (serial_data == 1'b1)
                        next_state = S_1011;
                    else
                        next_state = INCORRECT;
                end
            end
            
            S_1011: begin
                // Auto-return to IDLE after one clock cycle
                timeout_enable = 1'b1;
                if (timeout_counter >= 2'b01)
                    next_state = IDLE;
            end
            
            INCORRECT: begin
                // Auto-return to IDLE after one clock cycle
                timeout_enable = 1'b1;
                if (timeout_counter >= 2'b01)
                    next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // 3. Output Decoder (Combinational Logic) - Only depends on current state
    always_comb begin
        // Default outputs
        unlock = 1'b0;
        pwd_incorrect = 1'b0;
        serial_ready = 1'b1;
        
        case (current_state)
            IDLE: begin
                unlock = 1'b0;
                pwd_incorrect = 1'b0;
                serial_ready = 1'b1;
            end
            
            S_1, S_10, S_101: begin
                unlock = 1'b0;
                pwd_incorrect = 1'b0;
                serial_ready = 1'b1;
            end
            
            S_1011: begin
                unlock = 1'b1;
                pwd_incorrect = 1'b0;
                serial_ready = 1'b0; // Not ready during unlock
            end
            
            INCORRECT: begin
                unlock = 1'b0;
                pwd_incorrect = 1'b1;
                serial_ready = 1'b0; // Not ready during error
            end
            
            default: begin
                unlock = 1'b0;
                pwd_incorrect = 1'b0;
                serial_ready = 1'b1;
            end
        endcase
    end

endmodule