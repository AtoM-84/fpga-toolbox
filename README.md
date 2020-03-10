# fpga-toolbox

### i2c-master

An Inter-Integrated Circuit IP to interface I2C as a master device. The IP is based on an unique file and has to be used with a FSM which will provide the necessary informations required to communicate with a slave device:

* i_device_address : a 7-bit address for the slave device
* i_R_W : the direction Read or Write of the next transaction with the device
* i_read_byte_nb : the number of bytes to be read based on the expected transaction
* i_write_byte_nb  : the number of bytes to be written
* i_data : a byte which is the next to be sent to be changed after each data_access event

The signals and data retrieved from the IP are :
* o_busy to indicate when a transaction is occuring
* o_error to alert when an error occured (to be used with the vector o_error_code for more details)
* o_data to collect a data on data_ready signal

The signals o_data_ready and o_data_access are HIGH respectively when a new data is ready at the output and a new data collected is to be sent. A transaction is started by i2c_start and is finished when i2c_end is fired. Others signals (SCL and SDA signals) have to be connected to ports/pins.

An IP i2c-master-controller is provided to interact with in/out FIFO.
