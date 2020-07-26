----------------------------------------------------------------------
-- rotary.lua
----------------------------------------------------------------------
-- This module processes the newly reported position of the rotary
-- switches from the ADITS panel: 'DATA' and 'SYS'

local rotary = {}
-- local variables
local _serial
local _adirs = require('modules/lib/adirsDisplay')
local _rotaryPosition = {-1,-1}             -- two rotary switches: 1-DATA, 2-SYS
local _fmgsOffset     = {119,125}           -- Jeehell FMGS offset
local _rotaryMaxPos   = {5,3}               -- Data: 0-5, SYS: 0-3

-- ---------------------------------------------------
-- Set new rotary position and update FlightSim offset
-- ---------------------------------------------------
local function _setRotary(rotary,position,test)
    if rotary >= 0 and rotary <= 1 and position >=0 and position <= _rotaryMaxPos[rotary+1] then
        rotary   = rotary + 1
        position = position + 1
        if _rotaryPosition[rotary] ~= position then
            -- Set new rotary position in FMGS software
            if not test then ipc.writeUB( 0x78EE, _fmgsOffset[rotary] + (position - 1) ) end
            _rotaryPosition[rotary] = position
            if _rotaryPosition[1] > 0 and _rotaryPosition[2] > 0 then
                _adirs.rcvRotaryPos(_rotaryPosition[1],_rotaryPosition[2])
            end
        end
        _serial.sndACKNAK('$FSACK')
    else
        _serial.sndACKNAK('$FSNAK')
    end
end

-- ---------------------------
-- Get current rotary position
-- ---------------------------
local function _getRotary(rotary)
    local _pos
    if rotary >= 1 and rotary <= 2 then
        _pos = _rotaryPosition[rotary]
    end
    return _pos
end

-- ----------------------------------
-- Set instance of data communication
-- ----------------------------------
local function _setDataCom(object)
    _serial = object
end

rotary = {
    setDataCom = _setDataCom,
    setRotary  = _setRotary,
    getRotary  = _getRotary
}
return rotary