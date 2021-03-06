LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY i2c_master_rx IS
    GENERIC (
        CLK_DIV : INTEGER := 25
    );
    PORT (
        i_clk : IN std_logic;
        i_rst_n : IN std_logic;
        i_i2c_rx_start : IN std_logic;
        i_SDA : IN std_logic;

        o_data_rx_out : OUT std_logic_vector(7 DOWNTO 0);
        o_i2c_rx_end : OUT std_logic;
        o_i2c_rx_busy : OUT std_logic;
        o_SDA : OUT std_logic;
        o_SCL : OUT std_logic
    );
END i2c_master_rx;

ARCHITECTURE behavioral OF i2c_master_rx IS

    TYPE t_i2c_master_rx_fsm IS (
        ST_IDLE,
        ST_START,
        ST_ACKNOWLEDGMENT,
        ST_RECEIVE_DATA,
        ST_END);
    --Counters signals--
    SIGNAL r_clock_counter : INTEGER RANGE 0 TO CLK_DIV * 4;
    SIGNAL r_bit_loop_counter : INTEGER RANGE 7 DOWNTO 0;
    --Status signals--
    SIGNAL r_i2c_rx_busy : std_logic;
    SIGNAL r_i2c_rx_done : std_logic;
    SIGNAL r_i2c_rx_active : std_logic;
    SIGNAL r_i2c_ack_done : std_logic;
    SIGNAL r_i2c_rx_end : std_logic;
    SIGNAL r_clock_active : std_logic;
    --Data signals--
    SIGNAL r_data_out : std_logic_vector(7 DOWNTO 0);
    SIGNAL r_scl_clock : std_logic;
    --FSM signals--
    SIGNAL r_st_present : t_i2c_master_rx_fsm;
    SIGNAL w_st_next : t_i2c_master_rx_fsm;

BEGIN
    o_i2c_rx_end <= r_i2c_rx_end;
    o_i2c_rx_busy <= r_i2c_rx_busy;
    o_SCL <= r_scl_clock;
    -- i2c clock divider
    p_clock_counter : PROCESS (i_clk, i_rst_n, r_clock_active)
    BEGIN
        IF (i_rst_n = '0') THEN
            r_clock_counter <= 0;
            r_scl_clock <= '1';
        ELSIF rising_edge(i_clk) THEN
            IF (r_clock_active = '1') THEN
                IF (r_clock_counter = 0) THEN
                    r_scl_clock <= '0';
                    r_clock_counter <= r_clock_counter + 1;
                ELSIF (r_clock_counter = CLK_DIV) THEN
                    r_scl_clock <= '1';
                    r_clock_counter <= r_clock_counter + 1;
                ELSIF (r_clock_counter = CLK_DIV * 3) THEN
                    r_scl_clock <= '0';
                    r_clock_counter <= r_clock_counter + 1;
                ELSIF (r_clock_counter = CLK_DIV * 4 - 1) THEN
                    r_clock_counter <= 0;
                ELSE
                    r_clock_counter <= r_clock_counter + 1;
                END IF;
            ELSIF (r_clock_active = '0') THEN
                r_clock_counter <= 0;
                r_scl_clock <= '1';
            END IF;
        END IF;
    END PROCESS p_clock_counter;

    p_bit_loop_counter : PROCESS (i_clk, i_rst_n, r_i2c_rx_active, r_clock_counter)
    BEGIN
        IF (i_rst_n = '0') THEN
            r_bit_loop_counter <= 7;
            r_i2c_rx_done <= '0';
        ELSIF rising_edge(i_clk) THEN
            IF (r_i2c_rx_active = '1') THEN
                IF (r_clock_counter = 0) THEN
                    r_i2c_rx_done <= '0';
                ELSIF (r_clock_counter = CLK_DIV * 2) THEN
                    r_data_out(r_bit_loop_counter) <= i_SDA;
                    r_i2c_rx_done <= '0';
                ELSIF (r_clock_counter = CLK_DIV * 4 - 2) THEN
                    IF (r_bit_loop_counter = 0) THEN
                        r_i2c_rx_done <= '1';
                    ELSE
                        r_i2c_rx_done <= '0';
                        r_bit_loop_counter <= r_bit_loop_counter - 1;
                    END IF;
                END IF;
            ELSE
                r_bit_loop_counter <= 7;
                r_i2c_rx_done <= '0';
            END IF;
        END IF;
    END PROCESS p_bit_loop_counter;
    ----------------------------------------------------------------
    p_acknowledgment : PROCESS (i_clk, i_rst_n, r_i2c_rx_active)
    BEGIN
        IF (i_rst_n = '0') THEN
            r_i2c_ack_done <= '0';
            o_SDA <= '1';
        ELSIF rising_edge(i_clk) THEN
            IF (i_i2c_rx_start = '1') THEN
                o_data_rx_out <= (OTHERS => '0');
                o_SDA <= '1';
            END IF;
            IF (r_i2c_rx_active = '0') THEN
                IF (r_clock_counter = 0) THEN
                    o_SDA <= '1';
                    r_i2c_ack_done <= '0';
                ELSIF (r_clock_counter = CLK_DIV - 2) THEN
                    o_SDA <= '0';
                    r_i2c_ack_done <= '0';
                ELSIF (r_clock_counter = CLK_DIV * 4 - 2) THEN
                    o_SDA <= '1';
                    o_data_rx_out <= r_data_out;
                    r_i2c_ack_done <= '1';
                END IF;
            END IF;
        END IF;
    END PROCESS p_acknowledgment;
    -------------------------------------------------------------------

    -- State changer and FSM
    p_state : PROCESS (i_clk, i_rst_n)
    BEGIN
        IF (i_rst_n = '0') THEN
            r_st_present <= ST_IDLE;
        ELSIF (rising_edge(i_clk)) THEN
            r_st_present <= w_st_next;
        END IF;
    END PROCESS p_state;

    p_fsm : PROCESS (r_st_present, i_i2c_rx_start, r_i2c_ack_done, r_i2c_rx_done)
    BEGIN
        CASE r_st_present IS
            WHEN ST_IDLE =>
                r_i2c_rx_busy <= '0';
                r_clock_active <= '0';
                r_i2c_rx_active <= '0';
                r_i2c_rx_end <= '0';
                IF (i_i2c_rx_start = '1') THEN
                    w_st_next <= ST_START;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_START =>
                r_i2c_rx_busy <= '1';
                r_clock_active <= '0';
                r_i2c_rx_active <= '0';
                r_i2c_rx_end <= '0';
                IF (i_i2c_rx_start = '0') THEN
                    w_st_next <= ST_RECEIVE_DATA;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_RECEIVE_DATA =>
                r_i2c_rx_busy <= '1';
                r_clock_active <= '1';
                r_i2c_rx_active <= '1';
                r_i2c_rx_end <= '0';
                IF (r_i2c_rx_done = '1') THEN
                    w_st_next <= ST_ACKNOWLEDGMENT;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_ACKNOWLEDGMENT =>
                r_i2c_rx_busy <= '1';
                r_clock_active <= '1';
                r_i2c_rx_active <= '0';
                r_i2c_rx_end <= '0';
                IF (r_i2c_ack_done = '1') THEN
                    w_st_next <= ST_END;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_END =>
                r_i2c_rx_busy <= '1';
                r_clock_active <= '0';
                r_i2c_rx_active <= '0';
                r_i2c_rx_end <= '1';
                w_st_next <= ST_IDLE;

            WHEN OTHERS =>
                r_i2c_rx_busy <= '0';
                r_clock_active <= '0';
                r_i2c_rx_active <= '0';
                r_i2c_rx_end <= '0';
                w_st_next <= ST_IDLE;

        END CASE;
    END PROCESS p_fsm;
END behavioral;