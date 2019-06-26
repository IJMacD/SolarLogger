local M = {}
_G["ina219"] = M

local id = 0

function M:setup(address, sda, scl)
    self.address = address
    -- initialize i2c, set pins
    i2c.setup(id, sda, scl, i2c.SLOW)
end

-- user defined function: read from reg_addr content of dev_addr
local function read_reg(dev_addr, reg_addr, len)
    i2c.start(id)
    i2c.address(id, dev_addr, i2c.TRANSMITTER)
    i2c.write(id, reg_addr)
    i2c.stop(id)
    i2c.start(id)
    i2c.address(id, dev_addr, i2c.RECEIVER)
    c = i2c.read(id, len)
    i2c.stop(id)
    return c
end

local function write_reg(dev_addr, reg_addr, value, len)
    i2c.start(id)
    i2c.address(id, dev_addr, i2c.TRANSMITTER)
    i2c.write(id, reg_addr)
    i2c.write(id, bit.band(0xff, bit.rshift(value, 8)))
    i2c.write(id, bit.band(0xff, value))
    i2c.stop(id)
end

-- string of two decimal numbers
local function reg_bytes(address, reg)
    s = read_reg(address, reg, 2)
    return s:byte(1).." "..s:byte(2)
end

-- 2-byte string
function M:read_config()
    return read_reg(self.address, 0x00, 2)
end

-- shunt voltage in millivolts, signed integer
function M:read_shunt()
    return to_sint(read_reg(self.address, 0x01, 2))
end

-- bus voltage in millivolts, unsigned integer
function M:read_bus()
    return bit.rshift(to_int(read_reg(self.address, 0x02, 2)), 3) * 4
end

function M:read_power()
    return to_sint(read_reg(self.address, 0x03, 2))
end

-- current in milliamps, signed integer
function M:read_current()
    local current_lsb = 0.1 -- milliamps (set via calibration register)
    return to_sint(read_reg(self.address, 0x04, 2)) * current_lsb
end

-- 0.04096 / CURRENT_LSB * R_SHUNT
function M:read_calibration()
    return to_int(read_reg(self.address, 0x05, 2))
end

function M:write_calibration(value)
    return write_reg(self.address, 0x05, value, 2)
end

local function to_int (s)
    b1 = s:byte(1)
    b2 = s:byte(2)
    return bit.bor(bit.lshift(b1, 8), b2)
end

local function to_sint (s)
    n = to_int(s)
    if n < 0x8000 then 
        return n
    end
    return n - 0x10000
end

return M