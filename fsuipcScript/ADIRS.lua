----------------------------------------------------------------------
-- ADIRS.lua
----------------------------------------------------------------------
-- Main script executed by FSUIPC or WideFS, which communicates with
-- the Flight Simulator and with the Arduino MEGA 2560 board

-- load required muodules
bat       = require('lib/battery')
rotary    = require('lib/rotary')
adirs     = require('lib/adirsDisplay')
handshake = require('lib/handshake')
data      = require('lib/sendReceiveData')

-- global variables
hCom  = 0              -- serial communication handle

-- Data received
function evtComData(hnd, strData, strLen)
    local i
    local _msg, _init = '', false
    i,_ = strData:find("%$")
    -- verify if valid data received
    if i > 0 then
        dataRX(strData:sub(i, -3))
        _msg = data.rcvData(strData:sub(i+1, -3))
    end
end

-- Send pending data
function evtSendData()
    --TODO ensure that BAT, ADIRS, and TRIPPLE GAGE can send data with equal priority
    local _bat
    _bat = bat.sndBATData()      -- send pending data of batteries
    if not _bat then             -- _bat == nil if no data sent
        adirs.sndADIRSInfo()
    end
end

-- Battery 1
function evtBAT1(pOffset, pValue)
    -- store battery 1 voltage
    bat.evtBATxVolt('BA1', pValue)
end

-- Battery 2
function evtBAT2(pOffset, pValue)
    -- store battery 2 voltage
    bat.evtBATxVolt('BA2', pValue)
end

-- True Track (in degree)
function evtTrueTrack(pOffset, pValue)
    adirs.evtTrueTrack(math.floor(math.deg(pValue) + 0.5))
end

-- Ground Speed (knots)
function evtGroundSpeed(pOffset, pValue)
    adirs.evtGroundSpeed(math.floor((pValue / 65536 * 1.943844) + 0.5))
end

-- Position Latitude (N/S)
function evtPosLAT(pOffset, pValue)
    local _latO = ''
    -- Latitude in degrees
    local _posLat = pValue * 90.0 / ( 10001750.0 * 65536.0 * 65536.0 )
    local _latG = math.floor(_posLat)
    local _latM = (_posLat - _latG) * 60
    if _posLat > 0 then _latO = "N" else _latO = "S" end
    adirs.evtPPos('LAT', _latO, _latG, _latM)
end

-- Position Longitude (E/W)
function evtPosLON(pOffset, pValue)
    local _lonO = ''
    -- Longitude in Grad
    local _posLon = pValue * 360.0 / ( 65536.0 * 65536.0 * 65536.0 * 65536.0 )
    local _lonG = math.floor(_posLon)
    local _lonM = (_posLon - _lonG) * 60
    if _posLon > 0 then _lonO = "E" else _lonO = "W" end
    adirs.evtPPos('LON', _lonO, _lonG, _lonM)
end

-- Wind in Knots
function evtWindKn(pOffset, pValue)
    adirs.evtWindKn(pValue)
end

-- Wind Direction
function evtWindDeg(pOffset, pValue)
    adirs.evtWindDeg(math.floor((pValue * 360 / 65536) + 0.5))
end

-- True Heading
function evtHeading(pOffset, pValue)
    adirs.evtHeading(math.floor((pValue * 360 / (65536 * 65536)) + 0.5))
end

-- ACCU pressure
function evtACCUPressure(pOffset, pValue)

end

-- Left Brake
function evtLeftBrake(pOffset, pValue)

end

-- Right Brake
function evtRightBrake(pOffset, pValue)

end

-- Logging data sent to Arduino
function dataTX(msgTX)
    local _msg = "TX: '" .. msgTX .. "' - " .. os.date()
    display.show(hWnd, 8, _msg)
    print(_msg)
end

-- Logging data received from Arduino
function dataRX(msgRX)
    local _msg = "RX: '" .. msgRX .. "' - " .. os.date()
    display.show(hWnd, 9, _msg)
    print(_msg)
end

-- Terminate this script
function evtSimClose(pEvtType)
    event.cancel("evtBAT1")
    event.cancel("evtBAT2")
    event.cancel("evtTrueTrack")
    event.cancel("evtGroundSpeed")
    event.cancel("evtPosLAT")
    event.cancel("evtPosLON")
    event.cancel("evtWindKn")
    event.cancel("evtWindDeg")
    event.cancel("evtHeading")
    event.cancel("evtACCUPressure")
    event.cancel("evtLeftBrake")
    event.cancel("evtRightBrake")
    --    event.cancel("evtMainPower")
    --    event.cancel("evtGeneral")
    event.cancel("evtSimClose")
    com.close(hCom)
    display.close(hWnd)
end

-- ------------
-- Main Routine
-- ------------
-- Create the display window for 9 values, position x=700, y=300
hWnd = display.create("SYS Display and Battery", 9, 700, 300)
display.show(hWnd, 1, "Set serial port")
-- Set up serial communication
repeat
    hCom = com.open("COM7", 115200, 0)
until hCom > 0
display.show(hWnd, 1, "Set data handler")
-- Initialize modules
data.setHandler(hCom)                    -- set serial port handler
data.setFunctionDataTx(dataTX)           -- function to display sent data
bat.setDataCom(data)                     -- set instance to send data
rotary.setDataCom(data)                  -- set instance to send data
adirs.setDataCom(data)                  -- set instance to send data
handshake.setDataCom(data)               -- set instance to send data
-- Set events
display.show(hWnd, 1, "Set events")
event.sim(CLOSE, "evtSimClose")                 -- Flight Simulate closed
event.com(hCom, 20, -1, 10, "evtComData")       -- wait for the 'LF' sign
event.timer(140, "evtSendData")                 -- send data if required (max time ADIRS display 270ms)
event.offset(0x73BC, "SW",  "evtBAT1")          -- BAT1 0x73BC "SW" - voltage * 10
event.offset(0x73BE, "SW",  "evtBAT2")          -- BAT2 0x73BE "SW" - voltage * 10
event.offset(0x6040, "DBL", "evtTrueTrack")     -- magnetic track in radians (deg = rad * 180/pi)
event.offset(0x02B4, "SD",  "evtGroundSpeed")   -- ground speed as 65536*metres/sec
event.offset(0x0560, "DD", "evtPosLAT")         -- Lattitude
event.offset(0x0568, "DD", "evtPosLON")         -- Longitude
event.offset(0x0E90, "UW", "evtWindKn")         -- Ambient wind speed (at aircraft) in knots
event.offset(0x0E92, "UW", "evtWindDeg")        -- Ambient wind direction (at aircraft), *360/65536 to get degrees
event.offset(0x0580, "UD", "evtHeading")        -- Heading, *360/(65536*65536) for degrees true
event.offset(0x73A7, "UB", "evtACCUPressure")   -- Triple Brake Indicator ACCU Pressure (0-255)
event.offset(0x73A8, "UB", "evtLeftBrake")      -- Triple Brake Indicator Left Brake (0-255)
event.offset(0x73A9, "UB", "evtRightBrake")     -- Triple Brake Indicator Right Brake (0-255)
display.show(hWnd, 1, "Initialize completed")