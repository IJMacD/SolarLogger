function getVoltage() 
    local sum = 0
    for i=1,10 do
        sum = sum + adc.read(0)
        tmr.delay(1000)
    end
    return sum / 701.8
end 


id  = 0
sda = 2
scl = 1

address = 0x42

deep_sleep = false

-- initialize i2c, set pin1 as sda, set pin2 as scl
i2c.setup(id, sda, scl, i2c.SLOW)
    
--srv=net.createServer(net.TCP) 
--srv:listen(80,function(conn) 
--    conn:on("receive",function(conn,payload) 
--        val = getVoltage()
--        --print(payload) 
--        print("Request: "..val)
--        conn:send("<h1>" .. val .. "v</h1>")
--    end) 
--    conn:on("sent",function(conn)   
--        conn:close()
--    end)
--end)

-- user defined function: read from reg_addr content of dev_addr
function read_reg(dev_addr, reg_addr, len)
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

function write_reg(dev_addr, reg_addr, value, len)
    i2c.start(id)
    i2c.address(id, dev_addr, i2c.TRANSMITTER)
    i2c.write(id, reg_addr)
    i2c.write(id, bit.band(0xff, bit.rshift(value, 8)))
    i2c.write(id, bit.band(0xff, value))
    i2c.stop(id)
end

function reg_bytes(address, reg)
    s = read_reg(address, reg, 2)
    return s:byte(1).." "..s:byte(2)
end

function read_config(address)
    return read_reg(address, 0x00, 2)
end

function read_shunt(address)
    return to_sint(read_reg(address, 0x01, 2))
end

-- bus voltage in millivolts
function read_bus(address)
    return bit.rshift(to_int(read_reg(address, 0x02, 2)), 3) * 4
end

function read_power(address)
    return to_sint(read_reg(address, 0x03, 2))
end

-- current in milliamps
function read_current(address)
    local current_lsb = 0.1 -- milliamps
    return to_sint(read_reg(address, 0x04, 2)) * current_lsb
end

function read_calibration(address)
    return to_int(read_reg(address, 0x05, 2))
end

function write_calibration(address, value)
    return write_reg(address, 0x05, value, 2)
end

function to_int (s)
    b1 = s:byte(1)
    b2 = s:byte(2)
    return bit.bor(bit.lshift(b1, 8), b2)
end

function to_sint (s)
    n = to_int(s)
    if n > 0x7fff then
        return n - 0xffff
    end
    return n
end

function sendReading (callback)
    conn=net.createConnection(net.TCP, 0)
    -- conn:connect(80, "80.82.113.195") -- ijmacd.com
    conn:connect(80, "104.28.14.146") -- ijmacd.com via cloudflare
    
    conn:on("connection", function(conn)
        batt=getVoltage()
        solar_v = read_bus(address) / 1000
        solar_c = read_current(address) / 1000
        data="battery_voltage="..batt
        .."&solar_voltage="..solar_v
        .."&solar_current="..solar_c
        conn:send("POST /solar.php HTTP/1.1\r\n"
        .."Host: ijmacd.com\r\n"
        .."Connection: close\r\n"
        .."Content-Type: application/x-www-form-urlencoded\r\n"
        .."Content-Length: "..string.len(data).."\r\n" -- important
        .."\r\n"
        ..data.."\r\n")
        --conn:send("GET /solar.php?solar_voltage="..val.." HTTP/1.1\r\n"
        --.."Host: ijmacd.com\r\n"
        --.."Connection: close\r\n"
        --.."\r\n")
        conn:on("sent", function () 
            print("Sent: "..batt.." "..solar_v.." "..solar_c)
            --conn:close()
        end)
    end)
    conn:on("receive", function (conn, payload)
        --print(payload)
        for i in string.gmatch(payload, "HTTP/1.1 [^\r\n]+") do
            print(i)
        end
        conn:close()
        if type(callback) == 'function' then callback() end
    end)
    conn:on("disconnection", function (conn, error) 
        print("Disconnected: "..error)
    end)
end

function resend ()
    sendReading()
end

timer=tmr.create()
sleepTmr=tmr.create()

function testConnection ()
    status = wifi.sta.status()
    if status == wifi.STA_GOTIP then
        if deep_sleep then
            sendReading(function () 
                time = 60 * 1000 * 1000
                time = time - tmr.now()
                print("Deep sleep for: "..time)
                node.dsleep(time, nil, nil) 
            end)
        else
            sendReading()
            sleepTmr:alarm(60 * 1000, tmr.ALARM_AUTO, resend)
        end
    elseif status == 255 then
        print("WiFI not configured. Cannot start")
    else 
        print(".")
        timer:start()
    end
end

write_calibration(address, 0x1000)
timer:alarm(100, tmr.ALARM_SEMI, testConnection)


--while wifi.sta.status() == wifi.STA_CONNECTING do
--    print(wifi.sta.status())
--    tmr.delay(500 * 1000)
--end


function scan_i2c ()
    for i=0,127 do
        i2c.start(0)
        if i2c.address(id, i, i2c.TRANSMITTER) then
            print(i..": ACK")
        else
            print(i..": no response")
        end
    end
end
    

--scan_i2c()
--local config = read_config(address)
--print("Config: "        ..config:byte(1).." "..config:byte(2))
--print("Shunt Voltage: " ..read_shunt(address))
--print("Bus Voltage: "   ..read_bus(address))
--print("Power: "         ..read_power(address))
--print("Current: "       ..read_current(address))
--print("Calibration: "   ..read_calibration(address))
--print("Calibration: "   ..read_calibration(address))

