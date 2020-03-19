# fpga-toolbox

## i2c-master

An Inter-Integrated Circuit IP to interface I2C as a master device. The IP is based on two lower level modules, i2c_master_tx and i2c_master_rx.

### i2c_master_controller

The controller module is in charge of 
 * checking for errors (nack),
 * building the first message from 7-bit slave address and R/W bit,
 * controlling status of modules tx and rx (busy state),
 * starting the transaction with i_i2c_rx_start or i_i2c_tx_start,
 * retrieving data and/or ack on i_i2c_rx_end or i_i2c_tx_end,
 * returning an i2c_master interface availability status.

### i2c_master_tx

The i2c_master_tx module pushes on serial i2c bus the data at i_data on an i2c_tx_start event. The acknoledgment from slave is retrieved by sampling o_i2c_tx_ack on o_i2c_tx_end event. Do not attempt to use during a busy state (o_i2c_tx_busy = 1), otherwise the command would be ignored.

Transmission uses o_SDA pin but i_SDA pin is also used for acknowledgment purpose. The o_SCL pin is the clock signal for the master to trigger the slave to sample the master data.

### i2c_master_rx

The i2c_master_rx collects data on i2c serial bus and delivers it at o_data on an i2c_rx_start event. The acknoledgment and the data from slave is retrieved on o_i2c_rx_end event. Attempting a new cycle during a busy state (o_i2c_rx_busy = 1) will not affect the on-going process. The data collected will be associated with the start event triggered during the last o_i2c_rx_busy = 0 state.

Data reception only uses i_SDA pin for data sampling and acknowledgment. The o_SCL pin is the clock signal for the slave to send back its data.