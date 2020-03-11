LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY i2c_master IS
    GENERIC (
        CLK_DIV : INTEGER := 25;
        N : INTEGER := 32 --Max byte number read/written
    );
    PORT (
        i_clk : IN std_logic; -- system clock
        i_rst : IN std_logic; -- asynhcronous reset signal
        i_i2c_start : IN std_logic; -- start signal (from FSM)
        i_device_address : IN std_logic_vector(6 DOWNTO 0); -- device address evaluated when start signal is high
        i_read_byte_nb : IN INTEGER RANGE 0 TO N - 1;
        i_write_byte_nb : IN INTEGER RANGE 0 TO N - 1;
        i_R_W : IN std_logic; -- Conventions are read = 1, write = 0 from I2C conventions
        i_data : IN std_logic_vector(7 DOWNTO 0); -- data input to i2c assessed when data_access is high
        i_sda : IN std_logic; -- serial data from slave - same pin as o_sda

        o_data : OUT std_logic_vector(7 DOWNTO 0); -- data out from i2c to assess when data_ready is high
        o_busy : OUT std_logic; -- busy signal when i2c master interface is out of idle state
        o_error : OUT std_logic; -- error signal to evaluate error code
        o_error_code : OUT std_logic_vector(3 DOWNTO 0); -- error code to detect abnormal behavior
        o_data_access : OUT std_logic; -- data access signal to evaluate i_data
        o_data_ready : OUT std_logic; -- data ready to signal when o_data can be evaluated
        o_i2c_end : OUT std_logic; -- end of transmission signal
        o_scl : OUT std_logic; -- serial clock from master - default to HIGH
        o_sda : OUT std_logic -- serial data from master - same pin as o_sda
    );
END i2c_master;

ARCHITECTURE behavioral OF i2c_master IS

    TYPE t_i2c_master_fsm IS (
        ST_IDLE,
        ST_START,
        ST_ADDRESSING,
        ST_ACKNOWLEDGMENT,
        ST_COUNTERS_STATUS,
        ST_WRITE_DATA,
        ST_READ_DATA,
        ST_ERROR,
        ST_END);

    --Counters signals--
    SIGNAL r_clock_counter : INTEGER RANGE 0 TO CLK_DIV * 4; -- counter to divide clock
    SIGNAL r_bit_loop_counter : INTEGER RANGE 7 DOWNTO 0; -- bit counter to iterate on a byte
    SIGNAL r_write_counter : INTEGER RANGE 0 TO 31; -- number of word (bytes) to be written
    SIGNAL r_read_counter : INTEGER RANGE 0 TO 31; -- number of word (bytes) to be read
    SIGNAL r_timeout_counter : std_logic_vector(15 DOWNTO 0); --timeout counter in case of no received words while waiting one
    --Status signals--
    SIGNAL r_busy : std_logic; -- busy status
    SIGNAL r_error : std_logic; -- error status
    SIGNAL r_error_code : std_logic_vector(2 DOWNTO 0);
    SIGNAL w_i2c_start : std_logic;
    --Data signals--
    SIGNAL r_data_in : std_logic_vector(7 DOWNTO 0); -- register to collect new data to be written
    SIGNAL r_data_out : std_logic_vector(7 DOWNTO 0);
    SIGNAL w_data_out : std_logic;
    SIGNAL r_data_ready : std_logic;
    SIGNAL r_data_access : std_logic;
    SIGNAL r_divided_clock : std_logic;
    --FSM signals--
    SIGNAL r_st_present : t_i2c_master_fsm; -- present state
    SIGNAL w_st_next : t_i2c_master_fsm; -- next state

BEGIN
    o_busy <= r_busy;
    w_i2c_start <= i_i2c_start;
    --condition à mettre sur ligne SDA pour état de repos?
    o_sda <= w_data_out;
    o_scl <= r_divided_clock;

    -- counters

    p_read_counter : PROCESS (i_clk, i_rst)
    BEGIN
        IF (i_rst = '1') THEN
            r_read_counter := 0;
        ELSIF w_i2c_start = '1' THEN
            r_read_counter <= i_read_byte_nb;
        ELSIF --(condition de décrément à voir en fin d'étape READ) THEN
            r_read_counter <= r_read_counter - 1;
            o_data <= r_data_out;
            --penser a enchainer le r_data_ready
        ELSE
            r_read_counter <= r_read_counter;
        END IF;
    END PROCESS p_read_counter;

    p_write_counter : PROCESS (i_clk, i_rst)
    BEGIN
        IF (i_rst = '1') THEN
            r_write_counter := 0;
        ELSIF w_i2c_start = '1' THEN
            r_write_counter <= i_write_byte_nb;
        ELSIF --(condition de décrément à voir en fin d'étape WRITE) THEN
            r_write_counter <= r_write_counter - 1;
            r_data_in <= i_data;
            --penser à enchainer le r_data_access
        ELSE
            r_write_counter <= r_write_counter;
        END IF;
    END PROCESS p_write_counter;

    p_clock_counter : PROCESS (i_clk, i_rst)
    BEGIN
        IF (i_rst = '0') THEN
            r_clock_counter = 0;
            r_divided_clock = '1';
        ELSIF rising_edge(clk) THEN
            IF (r_clock_active = '1') THEN
                IF (r_clock_counter = 0) THEN
                    r_divided_clock <= '0';
                ELSIF (r_clock_counter = CLK_DIV/4) THEN
                    r_divided_clock <= '1';
                    r_clock_counter := r_clock_counter + 1;
                ELSIF (r_clock_counter = CLK_DIV * 3/4) THEN
                    r_divided_clock <= '0';
                    r_clock_counter := r_clock_counter + 1;
                ELSIF (r_clock_counter = CLK_DIV) THEN
                    r_clock_counter := 0;
                ELSE
                    r_clock_counter := r_clock_counter + 1;
                END IF;
            ELSIF (r_clock_active = '0') THEN
                r_clock_counter := 0;
                r_divided_clock = '1';
            END IF;
        END IF;
    END PROCESS p_clock_counter;

    p_bit_loop_counter : PROCESS (i_clk, i_rst)
    BEGIN
        IF (i_rst = '0') THEN
            r_bit_loop_counter := 7;
        ELSIF rising_edge(clk) THEN
            IF (r_clock_active = '1') THEN
                IF (r_clock_counter = 0) THEN
                    -- on présente à la sortie la valeur du bit de data
                    w_data_out <= r_data_out(r_bit_loop_counter);
                ELSIF (r_clock_counter = CLK_DIV) THEN
                    r_bit_loop_counter := r_bit_loop_counter - 1;
                ELSIF (r_clock_counter = CLK_DIV & r_bit_loop_counter = 0) THEN
                    r_bit_loop_counter := 7;
                END IF;
            END IF;
        END IF;
    END PROCESS p_bit_loop_counter;

    -- State changer and FSM
    p_state : PROCESS (i_clk, i_rst)
    BEGIN
        IF (i_rst = '0') THEN
            r_st_present <= ST_RESET;
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
                IF (w_i2c_start = '1') THEN
                    w_st_next <= ST_START;
                ELSE
                    w_st_next <= r_st_present;
                END IF;
            WHEN ST_START =>
                r_busy <= '1';
                r_error <= '0';
            WHEN ST_ADDRESSING =>
                r_busy <= '1';
                r_error <= '0';
            WHEN ST_ACKNOWLEDGMENT =>
                r_busy <= '1';
                r_error <= '0';
            WHEN ST_COUNTERS_STATUS =>
                r_busy <= '1';
                r_error <= '0';
            WHEN ST_WRITE_DATA =>
                r_busy <= '1';
                r_error <= '0';
            WHEN ST_READ_DATA =>
                r_busy <= '1';
                r_error <= '0';

            WHEN ST_ERROR =>
                r_busy <= '1';
                r_error <= '1';

            WHEN ST_END =>
                r_busy <= '1';
                r_error <= '0';
            WHEN OTHERS =>
                r_busy <= '0';
                r_error <= '0';
                w_st_next <= r_st_present;
        END CASE;
    END PROCESS p_fsm;

END behavioral;