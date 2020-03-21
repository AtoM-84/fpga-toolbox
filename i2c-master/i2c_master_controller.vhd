LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY i2c_master_controller IS
    GENERIC (
        CLK_DIV : INTEGER := 25;
        N : INTEGER := 5
    );
    PORT (
        i_clk : IN std_logic;
        i_rst_n : IN std_logic;
        i_start_i2c : IN std_logic;
        i_data_in : IN std_logic_vector (7 DOWNTO 0);
        i_device_address : IN std_logic_vector (6 DOWNTO 0);
        i_RW : IN std_logic;
        i_read_byte_nb : IN std_logic_vector(N - 1 DOWNTO 0);
        i_write_byte_nb : IN std_logic_vector(N - 1 DOWNTO 0);
        i_SDA : IN std_logic;

        o_data_out : OUT std_logic_vector (7 DOWNTO 0);
        o_busy_i2c : OUT std_logic;
        o_error_i2c : OUT std_logic;
        o_new_data_in : OUT std_logic;
        o_new_data_out : OUT std_logic;
        o_end_i2c : OUT std_logic;
        o_SDA : OUT std_logic;
        o_SCL : OUT std_logic
    );
END i2c_master_controller;

ARCHITECTURE behavioral OF i2c_master_controller IS

    COMPONENT i2c_master_rx IS
        GENERIC (
            CLK_DIV : INTEGER := 25
        );
        PORT (
            i_clk : IN std_logic;
            i_rst_n : IN std_logic;
            i_i2c_rx_start : IN std_logic;
            i_SDA : IN std_logic;

            o_data_rx_out : OUT std_logic_vector(7 DOWNTO 0);
            o_i2c_rx_ack : OUT std_logic;
            o_i2c_rx_end : OUT std_logic;
            o_i2c_rx_busy : OUT std_logic;
            o_SCL : OUT std_logic
        );
    END COMPONENT;

    COMPONENT i2c_master_tx IS
        GENERIC (
            CLK_DIV : INTEGER := 25
        );
        PORT (
            i_clk : IN std_logic;
            i_rst_n : IN std_logic;
            i_i2c_tx_start : IN std_logic;
            i_data_tx_in : IN std_logic_vector(7 DOWNTO 0);
            i_SDA : IN std_logic;

            o_i2c_tx_ack : OUT std_logic;
            o_i2c_tx_end : OUT std_logic;
            o_i2c_tx_busy : OUT std_logic;
            o_SDA : OUT std_logic;
            o_SCL : OUT std_logic
        );
    END COMPONENT i2c_master_tx;

    -- new types
    TYPE t_i2c_master_controller_fsm IS (
        ST_IDLE,
        ST_START_I2C,
        ST_ADDRESSING,
        ST_DISPATCH,
        ST_WRITE_I2C,
        ST_READ_I2C,
        ST_ERROR,
        ST_END);
    -- constant
    CONSTANT CLOCK_DIVIDER : INTEGER := 25;
    -- clock and asynchronous signals
    SIGNAL w_clk : std_logic;
    SIGNAL w_rst_n : std_logic;
    -- status signals input
    SIGNAL w_start_i2c : std_logic;
    SIGNAL r_end_i2c : std_logic;
    SIGNAL r_start_sequence : std_logic;
    SIGNAL r_dispatch : std_logic;
    SIGNAL r_write_end : std_logic;
    SIGNAL r_read_end : std_logic;
    SIGNAL r_error : std_logic;
    SIGNAL r_write_mode : std_logic;
    SIGNAL r_read_mode : std_logic;
    -- counters 
    SIGNAL r_write_counter : INTEGER RANGE 0 TO (2 ** (N - 1) + 1);
    SIGNAL r_read_counter : INTEGER RANGE 0 TO 2 ** (N - 1);
    -- data
    SIGNAL r_start_byte : std_logic_vector(7 DOWNTO 0);

    -- signals to connect to modules
    ---- status signals
    SIGNAL w_i2c_tx_start : std_logic;
    SIGNAL w_i2c_rx_start : std_logic;
    SIGNAL w_i2c_tx_ack : std_logic;
    SIGNAL w_i2c_tx_end : std_logic;
    SIGNAL w_i2c_tx_busy : std_logic;
    SIGNAL w_i2c_rx_ack : std_logic;
    SIGNAL w_i2c_rx_end : std_logic;
    SIGNAL w_i2c_rx_busy : std_logic;
    ---- data signals
    SIGNAL w_data_tx_in : std_logic_vector(7 DOWNTO 0);
    SIGNAL w_data_rx_out : std_logic_vector(7 DOWNTO 0);
    ---- pin/ports
    SIGNAL w_i_SDA_tx : std_logic;
    SIGNAL w_i_SDA_rx : std_logic;
    SIGNAL w_o_SDA_tx : std_logic;
    SIGNAL w_SCL_rx : std_logic;
    SIGNAL w_SCL_tx : std_logic;
    ---- states
    SIGNAL r_st_present : t_i2c_master_controller_fsm;
    SIGNAL w_st_next : t_i2c_master_controller_fsm;

BEGIN
    w_start_i2c <= i_start_i2c;
    w_clk <= i_clk;
    w_rst_n <= i_rst_n;
    o_busy_i2c <= w_i2c_tx_busy OR w_i2c_rx_busy;
    o_error_i2c <= r_error;
    o_end_i2c <= r_end_i2c;
    o_SDA <= w_o_SDA_rx WHEN (r_read_mode = '1') ELSE
        w_o_SDA_tx WHEN (r_write_mode = '1');
    i_SDA <= w_i_SDA_rx WHEN (r_read_mode = '1') ELSE
        w_i_SDA_tx WHEN (r_write_mode = '1');
    o_SCL <= w_SCL_rx WHEN (r_read_mode = '1') ELSE
        w_SCL_tx WHEN (r_write_mode = '1');

    u_i2c_master_tx : i2c_master_tx
    GENERIC MAP(
        CLK_DIV => CLOCK_DIVIDER
    )
    PORT MAP(
        i_clk => w_clk,
        i_rst_n => w_rst_n,
        i_i2c_tx_start => w_i2c_tx_start,
        i_data_tx_in => w_data_tx_in,
        o_i2c_tx_ack => w_i2c_tx_ack,
        o_i2c_tx_end => w_i2c_tx_end,
        o_i2c_tx_busy => w_i2c_tx_busy,
        i_SDA => w_i_SDA_tx,
        o_SDA => w_o_SDA_tx,
        o_SCL => w_SCL_tx
    );

    u_i2c_master_rx : i2c_master_rx
    GENERIC MAP(
        CLK_DIV => CLOCK_DIVIDER
    )
    PORT MAP(
        i_clk => w_clk,
        i_rst_n => w_rst_n,
        i_i2c_rx_start => w_i2c_rx_start,
        o_data_rx_out => w_data_rx_out,
        o_i2c_rx_ack => w_i2c_rx_ack,
        o_i2c_rx_end => w_i2c_rx_end,
        o_i2c_rx_busy => w_i2c_rx_busy,
        i_SDA => w_i_SDA_rx,
        o_SCL => w_SCL_rx
    );

    p_load_and_build_start_sequence : PROCESS (i_clk, i_rst_n, w_start_i2c)
    BEGIN
        IF (i_rst_n = '0') THEN
            r_start_byte <= (OTHERS => '0');
        ELSIF rising_edge(i_clk) THEN
            IF (w_start_i2c = '1') THEN
                r_start_byte <= i_device_address & i_RW;
            ELSE
                r_start_byte <= r_start_byte;
            END IF;
        END IF;
    END PROCESS p_load_and_build_start_sequence;

    p_dispatch : PROCESS (i_clk, i_rst_n, w_start_i2c)
    BEGIN
        IF (i_rst_n = '0') THEN
            r_write_counter <= 0;
            r_read_counter <= 0;
            r_write_end <= '0';
            r_read_end <= '0';
        ELSIF rising_edge(i_clk) THEN
            IF (w_start_i2c = '1') THEN
                r_write_counter <= to_integer(unsigned(i_write_byte_nb)) + 1;
                r_read_counter <= to_integer(unsigned(i_read_byte_nb));
                r_write_end <= '0';
                r_read_end <= '0';
            ELSIF (w_start_i2c = '0') THEN
                IF (r_dispatch = '1') THEN
                    IF (r_write_counter = 0) THEN
                        r_write_end <= '1';
                        IF (r_read_counter = 0) THEN
                            r_read_end <= '1';
                        ELSE
                            r_read_counter <= r_read_counter - 1;
                        END IF;
                    ELSE
                        r_write_counter <= r_write_counter - 1;
                    END IF;
                ELSE
                    r_write_end <= '0';
                    r_read_end <= '0';
                    r_read_counter <= r_read_counter;
                    r_write_counter <= r_write_counter;
                END IF;
            END IF;
        END IF;
    END PROCESS p_dispatch;

    p_data_update : PROCESS (i_clk, i_rst_n, r_write_mode, r_read_mode)
    BEGIN
        IF (i_rst_n = '0') THEN
            o_data_out <= (OTHERS => '0');
            w_data_tx_in <= (OTHERS => '0');
            w_i2c_tx_start <= '0';
            w_i2c_rx_start <= '0';
        ELSIF rising_edge(i_clk) THEN
            IF (r_write_mode = '1') THEN
                IF (w_i2c_tx_end = '0' AND w_i2c_tx_busy = '0') THEN
                    w_i2c_tx_start <= '1';
                    o_new_data_in <= '1';
                    w_data_tx_in <= i_data_in;
                ELSE
                    w_i2c_tx_start <= '0';
                    o_new_data_in <= '0';
                END IF;
            ELSIF (r_read_mode = '1') THEN
                IF (w_i2c_rx_end = '1') THEN
                    o_new_data_out <= '1';
                    o_data_out <= w_data_rx_out;
                ELSIF (w_i2c_rx_end = '0' AND w_i2c_rx_busy = '0') THEN
                    w_i2c_rx_start <= '1';
                END IF;
            ELSIF (r_start_sequence = '1') THEN
                IF (w_i2c_tx_end = '0' AND w_i2c_tx_busy = '0') THEN
                    w_data_tx_in <= r_start_byte;
                    w_i2c_tx_start <= '1';
                ELSE
                    w_i2c_tx_start <= '0';
                END IF;
            ELSE
                w_data_tx_in <= (OTHERS => '0');
                o_data_out <= (OTHERS => '0');
                w_i2c_tx_start <= '0';
                w_i2c_rx_start <= '0';
            END IF;
        END IF;
    END PROCESS p_data_update;

    -- State changer and FSM
    p_state : PROCESS (i_clk, i_rst_n)
    BEGIN
        IF (i_rst_n = '0') THEN
            r_st_present <= ST_IDLE;
        ELSIF (rising_edge(i_clk)) THEN
            r_st_present <= w_st_next;
        END IF;
    END PROCESS p_state;

    p_fsm : PROCESS (r_st_present, w_start_i2c, w_i2c_tx_end, w_i2c_tx_ack, r_write_end, r_read_end, w_i2c_rx_end, w_i2c_rx_ack, w_i2c_tx_busy, w_i2c_rx_busy)
    BEGIN
        CASE r_st_present IS
            WHEN ST_IDLE =>
                r_start_sequence <= '0';
                r_dispatch <= '0';
                r_write_mode <= '0';
                r_read_mode <= '0';
                r_error <= '0';
                r_end_i2c <= '0';
                IF (w_start_i2c = '1') THEN
                    w_st_next <= ST_START_I2C;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_START_I2C =>
                r_start_sequence <= '1';
                r_dispatch <= '0';
                r_write_mode <= '0';
                r_read_mode <= '0';
                r_error <= '0';
                r_end_i2c <= '0';
                IF (w_start_i2c = '0') THEN
                    w_st_next <= ST_ADDRESSING;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_ADDRESSING =>
                r_start_sequence <= '0';
                r_dispatch <= '0';
                r_write_mode <= '0';
                r_read_mode <= '0';
                r_error <= '0';
                r_end_i2c <= '0';
                IF (w_i2c_tx_end = '1') THEN
                    IF (w_i2c_tx_ack = '1') THEN
                        w_st_next <= ST_ERROR;
                    ELSE
                        w_st_next <= ST_DISPATCH;
                    END IF;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_DISPATCH =>
                r_start_sequence <= '0';
                r_dispatch <= '1';
                r_write_mode <= '0';
                r_read_mode <= '0';
                r_error <= '0';
                r_end_i2c <= '0';
                IF (r_write_end = '1') THEN
                    IF (r_read_end = '1') THEN
                        w_st_next <= ST_END;
                    ELSE
                        w_st_next <= ST_READ_I2C;
                    END IF;
                ELSE
                    w_st_next <= ST_WRITE_I2C;
                END IF;

            WHEN ST_WRITE_I2C =>
                r_start_sequence <= '0';
                r_dispatch <= '0';
                r_write_mode <= '1';
                r_read_mode <= '0';
                r_error <= '0';
                r_end_i2c <= '0';
                IF (w_i2c_tx_end = '1') THEN
                    IF (w_i2c_tx_ack = '1') THEN
                        w_st_next <= ST_ERROR;
                    ELSE
                        w_st_next <= ST_DISPATCH;
                    END IF;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_READ_I2C =>
                r_start_sequence <= '0';
                r_dispatch <= '0';
                r_write_mode <= '0';
                r_read_mode <= '1';
                r_error <= '0';
                r_end_i2c <= '0';
                IF (w_i2c_rx_end = '1') THEN
                    IF (w_i2c_rx_ack = '1') THEN
                        w_st_next <= ST_ERROR;
                    ELSE
                        w_st_next <= ST_DISPATCH;
                    END IF;
                ELSE
                    w_st_next <= r_st_present;
                END IF;

            WHEN ST_ERROR =>
                r_start_sequence <= '0';
                r_dispatch <= '0';
                r_write_mode <= '0';
                r_read_mode <= '0';
                r_error <= '1';
                r_end_i2c <= '0';
                w_st_next <= ST_IDLE;

            WHEN ST_END =>
                r_start_sequence <= '0';
                r_dispatch <= '0';
                r_write_mode <= '0';
                r_read_mode <= '0';
                r_error <= '0';
                r_end_i2c <= '0';
                IF (w_i2c_tx_busy = '1' OR w_i2c_rx_busy = '1') THEN
                    w_st_next <= r_st_present;
                ELSE
                    w_st_next <= ST_IDLE;
                END IF;

            WHEN OTHERS =>
                r_start_sequence <= '0';
                r_dispatch <= '0';
                r_write_mode <= '0';
                r_read_mode <= '0';
                r_error <= '0';
                r_end_i2c <= '0';
                w_st_next <= ST_IDLE;

        END CASE;
    END PROCESS p_fsm;

END behavioral;