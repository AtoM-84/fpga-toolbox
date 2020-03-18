LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY i2c_master IS
    GENERIC (
        CLK_DIV : INTEGER := 25;
        N : INTEGER := 6 --Max byte number read/written
    );
    PORT (
        i_clk : IN std_logic; -- system clock
        i_rstb : IN std_logic; -- asynhcronous reset signal
        i_i2c_start : IN std_logic; -- start signal (from higher level FSM)
        i_device_address : IN std_logic_vector(6 DOWNTO 0); -- device address evaluated when rising_edge on i_i2c_start signal
        i_read_byte_nb : IN std_logic_vector(N - 1 DOWNTO 0); -- number of bytes to be read/evaluated when rising_edge on i_i2c_start signal
        i_write_byte_nb : IN std_logic_vector(N - 1 DOWNTO 0); --number of bytes to be written/when rising_edge on i_i2c_start signal
        i_RW : IN std_logic; -- Conventions are read = 1, write = 0 from I2C conventions/when rising_edge on i_i2c_start signal
        i_data : IN std_logic_vector(7 DOWNTO 0); -- data input to i2c assessed when rising_edge on o_data_access/to be updated after each o_data_access event
        i_SDA : IN std_logic; -- serial data from slave - same pin as o_sda

        o_busy : OUT std_logic; -- busy signal when i2c-master is out of idle state
        o_error : OUT std_logic; -- error signal (acknowledgment not received)
        o_data_access : OUT std_logic; -- data access signal to evaluate i_data
        o_data_ready : OUT std_logic; -- data ready to signal when new data available at o_data
        o_data : OUT std_logic_vector(7 DOWNTO 0); -- data out from i2c to assess when data_ready is high
        o_i2c_end : OUT std_logic; -- end of transmission signal
        o_SCL : OUT std_logic; -- serial clock from master - default to HIGH
        o_SDA : OUT std_logic -- serial data from master - same pin as i_sda
    );
END i2c_master;

ARCHITECTURE behavioral OF i2c_master IS

    TYPE t_i2c_master_fsm IS (
        ST_IDLE,
        ST_START,
        ST_ACKNOWLEDGMENT,
        ST_COUNTERS_STATUS,
        ST_WRITE_DATA,
        ST_READ_DATA,
        ST_ERROR,
        ST_END);

    --Counters signals--
    SIGNAL r_clock_counter : INTEGER RANGE 0 TO CLK_DIV * 4; -- counter to divide clock
    SIGNAL r_bit_loop_counter : INTEGER RANGE 7 DOWNTO 0; -- bit counter to iterate on a byte
    SIGNAL r_write_counter : std_logic_vector(N - 1 DOWNTO 0); -- number of word (bytes) to be written
    SIGNAL r_read_counter : std_logic_vector(N - 1 DOWNTO 0); -- number of word (bytes) to be read
    --Status signals--
    SIGNAL r_busy : std_logic; -- busy status
    SIGNAL r_read_mode : std_logic; -- reading data
    SIGNAL r_write_mode : std_logic; -- writing data
    SIGNAL r_read_write_done : std_logic; -- r/w done, acknowledgment to do
    SIGNAL r_error : std_logic; -- error status error on acknoledgment
    SIGNAL w_i2c_start : std_logic; -- start input signal
    SIGNAL r_i2c_end : std_logic; -- status signal to state end of i2c transaction
    SIGNAL w_device_address : std_logic_vector(6 DOWNTO 0); -- address to provide when starting i2c
    SIGNAL w_read_byte_nb : std_logic_vector(N - 1 DOWNTO 0);  -- nb of bytes to read to provide when starting i2c
    SIGNAL w_write_byte_nb : std_logic_vector(N - 1 DOWNTO 0); -- nb of bytes to be written to provide when starting i2c
    SIGNAL w_RW : std_logic; -- R/W signal to be added to device adresse when starting i2c
    SIGNAL r_ack : std_logic; -- acknowledgment value read on the i2c serial bus
    SIGNAL r_clock_active : std_logic; -- divided clock is active (during read/writec/ack state)
    --Data signals--
    SIGNAL r_data : std_logic_vector(7 DOWNTO 0); -- internal register for current data exchange
    SIGNAL w_data_in : std_logic_vector(7 DOWNTO 0); -- data from the systemto push into i2c master at start up and after each data_access event
    SIGNAL w_data_out : std_logic_vector(7 DOWNTO 0); -- data to pop out the i2c master IP into the system
    SIGNAL r_data_ready : std_logic; -- data ready to be read
    SIGNAL r_data_access : std_logic; -- data collected from data in
    SIGNAL w_sda_o : std_logic; -- wire to pin for data output
    SIGNAL w_sda_i : std_logic; -- wire to pin for data input
    SIGNAL r_divided_clock : std_logic;
    --FSM signals--
    SIGNAL r_st_present : t_i2c_master_fsm; -- present state
    SIGNAL w_st_next : t_i2c_master_fsm; -- next state

BEGIN
    w_i2c_start <= i_i2c_start;
    w_device_address <= i_device_address;
    w_read_byte_nb <= i_read_byte_nb;
    w_write_byte_nb <= i_write_byte_nb;
    w_RW <= i_RW;
    w_data_in <= i_data;
    w_sda_i <= i_SDA;

    o_busy <= r_busy;
    o_error <= r_error;
    o_data_access <= r_data_access;
    o_data_ready <= r_data_ready;
    o_data <= w_data_out;
    o_i2c_end <= r_i2c_end;
    o_SCL <= r_divided_clock;
    o_SDA <= w_sda_o;

    -- counters
    p_clock_counter : PROCESS (i_clk, i_rstb, r_clock_active)
    BEGIN
        IF (i_rstb = '0') THEN
            r_clock_counter <= 0;
            r_divided_clock <= '1';
        ELSIF rising_edge(i_clk) THEN
            IF (r_clock_active = '1') THEN
                IF (r_clock_counter = 0) THEN
                    r_divided_clock <= '0';
                ELSIF (r_clock_counter = CLK_DIV) THEN
                    r_divided_clock <= '1';
                    r_clock_counter <= r_clock_counter + 1;
                ELSIF (r_clock_counter = CLK_DIV * 3) THEN
                    r_divided_clock <= '0';
                    r_clock_counter <= r_clock_counter + 1;
                ELSIF (r_clock_counter = CLK_DIV * 4) THEN
                    r_clock_counter <= 0;
                ELSE
                    r_clock_counter <= r_clock_counter + 1;
                END IF;
            ELSIF (r_clock_active = '0') THEN
                r_clock_counter <= 0;
                r_divided_clock <= '1';
            END IF;
        END IF;
    END PROCESS p_clock_counter;

    p_bit_loop_counter : PROCESS (i_clk, i_rstb, r_clock_active, r_clock_counter, r_write_mode, r_read_mode, r_read_write_done)
    BEGIN
        IF (i_rstb = '0') THEN
            r_bit_loop_counter <= 7;
            w_sda_o <= '1';
        ELSIF rising_edge(i_clk) THEN
            IF ((r_clock_active = '1') AND (r_read_write_done = '0')) THEN
                IF (r_clock_counter = 0) THEN
                    IF (r_write_mode = '1') THEN
                        w_sda_o <= r_data(r_bit_loop_counter);
                    ELSIF (r_write_mode = '0') THEN
                        w_sda_o <= '1';
                    END IF;
                ELSIF (r_clock_counter = CLK_DIV * 2) THEN
                    IF (r_read_mode = '1') THEN
                        r_data(r_bit_loop_counter) <= w_sda_i;
                    ELSIF (r_read_mode = '0') THEN
                        r_data <= r_data;
                    END IF;
                ELSIF (r_clock_counter = CLK_DIV * 4) THEN
                    IF (r_bit_loop_counter = 0) THEN
                        r_bit_loop_counter <= 7;
                        r_read_write_done <= '1';
                    ELSE
                        r_bit_loop_counter <= r_bit_loop_counter - 1;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS p_bit_loop_counter;

    p_addressing_start : PROCESS (i_clk, i_rstb, w_i2c_start)
    BEGIN
        IF (i_rstb = '0') THEN
            r_data <= (OTHERS => '0');
        ELSIF rising_edge(i_clk) THEN
            IF (w_i2c_start = '1') THEN
                r_data <= std_logic_vector(shift_left(resize(unsigned(w_device_address), r_data'length), 1)) & w_RW;
                r_write_counter <= std_logic_vector(unsigned(r_write_counter) + 1);
            ELSE
                r_data <= r_data;
            END IF;
        END IF;
    END PROCESS p_addressing_start;

    p_read_counter : PROCESS (i_clk, i_rstb, r_read_mode, r_bit_loop_counter)
    BEGIN
        IF (i_rstb = '1') THEN
            r_read_counter <= (OTHERS => '0');
            r_data_ready <= '0';
        ELSIF (w_i2c_start = '1') THEN
            r_read_counter <= w_read_byte_nb;
        ELSIF (r_read_mode = '1' AND r_bit_loop_counter = 0) THEN
            r_read_counter <= std_logic_vector(unsigned(r_read_counter) - 1);
            w_data_out <= r_data;
            r_data_ready <= '1';
        ELSE
            r_read_counter <= r_read_counter;
            r_data_ready <= '0';
        END IF;
    END PROCESS p_read_counter;

    p_write_counter : PROCESS (i_clk, i_rstb, r_write_mode, r_bit_loop_counter)
    BEGIN
        IF (i_rstb = '1') THEN
            r_write_counter <= (OTHERS => '0');
            r_data_access <= '0';
        ELSIF (w_i2c_start = '1') THEN
            r_write_counter <= w_write_byte_nb;
        ELSIF (r_write_mode = '1' AND r_bit_loop_counter = 0) THEN
            r_write_counter <= std_logic_vector(unsigned(r_write_counter) - 1);
            r_data <= w_data_in;
            r_data_access <= '1';
        ELSE
            r_write_counter <= r_write_counter;
            r_data_access <= '0';
        END IF;
    END PROCESS p_write_counter;

    p_acknowledgement : PROCESS (i_clk, i_rstb, r_clock_counter, r_read_write_done)
    BEGIN
        IF (i_rstb = '0') THEN
            r_ack <= '0';
        ELSIF rising_edge(i_clk) THEN
            IF (r_read_write_done = '1' AND r_clock_counter = CLK_DIV * 2) THEN
                r_ack <= NOT(w_sda_i);
            ELSIF (r_clock_counter = CLK_DIV * 4) THEN
                r_read_write_done <= '0';
            END IF;
        END IF;
    END PROCESS p_acknowledgement;
    -- State changer and FSM
    p_state : PROCESS (i_clk, i_rstb, w_i2c_start, r_read_write_done, r_ack, r_write_counter, r_read_counter)
    BEGIN
        IF (i_rstb = '0') THEN
            r_st_present <= ST_IDLE;
        ELSIF (rising_edge(i_clk)) THEN
            r_st_present <= w_st_next;
        END IF;
    END PROCESS p_state;

    p_fsm : PROCESS (r_st_present)
    BEGIN
        CASE r_st_present IS
            WHEN ST_IDLE =>
                r_busy <= '0';
                r_error <= '0';
                r_clock_active <= '0';
                IF (w_i2c_start = '1') THEN
                    w_st_next <= ST_START;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_START =>
                r_busy <= '1';
                r_error <= '0';
                r_clock_active <= '0';
                IF (w_i2c_start = '0') THEN
                    w_st_next <= ST_WRITE_DATA;
                    r_write_mode <= '1';
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_ACKNOWLEDGMENT =>
                r_busy <= '1';
                r_error <= '0';
                r_clock_active <= '1';
                IF (r_read_write_done = '0') THEN
                    IF (r_ack = '1') OR (r_ack = '0' AND (r_read_counter = (OTHERS => '0'))) THEN
                        w_st_next <= ST_COUNTERS_STATUS;
                    ELSE
                        w_st_next <= ST_ERROR;
                    END IF;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_COUNTERS_STATUS =>
                r_busy <= '1';
                r_error <= '0';
                r_clock_active <= '0';
                IF (r_write_counter = (OTHERS => '0')) THEN
                    IF (r_read_counter = (OTHERS => '0')) THEN
                        w_st_next <= ST_END;
                        r_i2c_end <= '1';
                    ELSE
                        w_st_next <= ST_READ_DATA;
                        r_read_mode <= '1';
                    END IF;
                ELSE
                    w_st_next <= ST_WRITE_DATA;
                    r_write_mode <= '1';
                END IF;

            WHEN ST_WRITE_DATA =>
                r_busy <= '1';
                r_error <= '0';
                r_clock_active <= '1';
                IF (r_read_write_done = '1') THEN
                    w_st_next <= ST_ACKNOWLEDGMENT;
                    r_write_mode <= '0';
                    r_data_access <= '0';
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_READ_DATA =>
                r_busy <= '1';
                r_error <= '0';
                r_clock_active <= '1';
                IF (r_read_write_done = '1') THEN
                    w_st_next <= ST_ACKNOWLEDGMENT;
                    r_read_mode <= '0';
                    r_data_ready <= '0';
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_ERROR =>
                r_busy <= '1';
                r_error <= '0';
                r_clock_active <= '0';
                IF (r_error = '0') THEN
                    w_st_next <= ST_IDLE;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_END =>
                r_busy <= '1';
                r_error <= '0';
                r_clock_active <= '0';
                r_i2c_end <= '0';
                IF (r_i2c_end = '0') THEN
                    w_st_next <= ST_IDLE;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN OTHERS =>
                r_busy <= '0';
                r_error <= '0';
                r_clock_active <= '0';
                w_st_next <= r_st_present;

        END CASE;
    END PROCESS p_fsm;

END behavioral;