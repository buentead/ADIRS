----------------------------------------------------------------------
-- handshake.lua
----------------------------------------------------------------------
-- This module establishes the communication with the Arduino board.
-- It esnures a protocol restart when needed.

local handshake = {}
-- local variables
local _serial
local _bat    = require('modules/lib/battery')
local _status = 1

-- ---------------------------------
-- Arduino protocol version received
-- ---------------------------------
local function _rcvADVersion(strData)
    local _rc = -1
    _status = 4 -- set temporarily to 'connected' to exchange data
    _,_rc = _serial.sndData(handshake, '$FSVER,' .. strData:sub(-4, -1))
    if _rc == 0 then
        _status = 3
    else
        _status = 2
    end
    return _rc
end

-- ------------------------
-- Check Arduino connection
-- ------------------------
local function _arduinoConnected()
    if _status == 4 then
        return true
    else
        return false
    end
end

-- -----------
-- Receive ACK
-- -----------

local function _rcvACK()
    if _status == 3 then
        _status = 4
        _bat.evtBATxON('BA1')
        _bat.evtBATxON('BA2')
    end
end

-- -----------
-- Receive NAK
-- -----------

local function _rcvNAK()
    if _status == 3 then
        _status = 1
    end
end

-- ----------------------------------
-- Set instance of data communication
-- ----------------------------------
local function _setDataCom(object)
    _serial = object
end


handshake = {
    setDataCom       = _setDataCom,
    rcvADVersion     = _rcvADVersion,
    arduinoConnected = _arduinoConnected,
    rcvACK           = _rcvACK,
    rcvNAK           = _rcvNAK
}
return handshake