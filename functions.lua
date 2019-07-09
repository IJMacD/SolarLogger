function startMonitoring ()
    monitoring = true
    if deep_sleep then
        sendReading(function () 
            time = 60 * 1000 * 1000
            time = time - tmr.now()
            print("Deep sleep for: "..time)
            node.dsleep(time, nil, nil) 
        end)
    else
        sendReading()
        sleepTmr:alarm(60 * 1000, tmr.ALARM_AUTO, function (t) sendReading() end)
    end
end


function sendReading (callback)
    local conn=net.createConnection(net.TCP, 0)
    -- conn:connect(80, "80.82.113.195") -- ijmacd.com
    conn:connect(80, "104.28.14.146") -- ijmacd.com via cloudflare
    
    conn:on("connection", function(conn)
        batt_v = getVoltage()
        batt=string.format("%2.4f", batt_v)
        solar_v = ina219:read_bus() / 1000
        solar_c = ina219:read_current() / 1000

        if solar_v < batt_v then
            gpio.write(led_output, gpio.LOW)
        else
            gpio.write(led_output, gpio.HIGH)
        end

        data="device="..node.chipid()
        .."&battery_voltage="..batt
        .."&solar_voltage="..solar_v
        .."&solar_current="..solar_c

        conn:send("POST /solar.php HTTP/1.1\r\n"
        .."Host: ijmacd.com\r\n"
        .."Connection: close\r\n"
        .."Content-Type: application/x-www-form-urlencoded\r\n"
        .."Content-Length: "..string.len(data).."\r\n" -- important
        .."\r\n"
        ..data.."\r\n")

        conn:on("sent", function () 
            print("Sent: "..node.chipid().." "..batt.." "..solar_v.." "..solar_c)
        end)
    end)

    conn:on("receive", function (conn, payload)
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

function getVoltage() 
    local sum = 0
    for i=1,10 do
        sum = sum + adc.read(0)
        tmr.delay(1000)
    end
    return sum / voltage_calibration
end 

function testConnection ()
    local status = wifi.sta.status()
    if status == wifi.STA_GOTIP then
        startMonitoring()
    elseif status == 255 then
        print("WiFI not configured. Cannot start")
    else 
        print(".")
        timer:start()
    end
end
