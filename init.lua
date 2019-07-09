id  = 0
sda = 2 -- GPIO4
scl = 1 -- GPIO5
led_output = 4 -- GPIO2

address = 0x42

deep_sleep = false
wifi_polling = false
monitoring = false

if node.chipid() == 1714520 then
    voltage_calibration = 701.8 -- 1714520
else 
    voltage_calibration = 813.7 -- 3422737
end

timer=tmr.create()
sleepTmr=tmr.create()

dofile("functions.lua")

if not wifi_polling then
    wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function (data)
        print("Got IP: " .. data.IP)
        startMonitoring()
    end)
end

gpio.write(led_output, gpio.HIGH)
gpio.mode(led_output, gpio.OUTPUT)

ina219 = require("ina219")

ina219:setup(address, sda, scl)
print(ina219:read_config())
ina219:set_adc_res(ina219.ADC_BUS, 0xC)
print(ina219:read_config())
ina219:write_calibration(0x1000)

if not monitoring then
    local ip = wifi.sta.getip()
    if ip ~= nil then
        print("Have IP: "..ip)
        startMonitoring()
    elseif wifi_polling then
        timer:alarm(100, tmr.ALARM_SEMI, testConnection)
    end
end


