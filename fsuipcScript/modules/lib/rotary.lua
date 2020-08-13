----------------------------------------------------------------------
-- rotary.lua
----------------------------------------------------------------------
-- This module processes the newly reported position of the rotary
-- switches from the ADITS panel: 'DATA' and 'SYS'

local rotary = {}
-- local variables
local _serial
local _adirs = require('lib/adirsDisplay')
local _rotaryPosition = {-1,-1,-1,-1,-1}        -- 5 rotary switches: 1-DATA, 2-SYS, 3-IR1, 4-IR3, 5-IR2
local _fmgsOffset     = {119,125,110,116,113}   -- Jeehell FMGS offset
local _rotaryMaxPos   = {5,3,2,2,2}             -- Data: 0-5, SYS: 0-3, IRx: 0-2

-- ---------------------------------------------------
-- Set new rotary position and update FlightSim offset
-- ---------------------------------------------------
local function _setRotary(rotary,position,test)
    if rotary >= 0 and rotary < 5 and position >=0 and position <= _rotaryMaxPos[rotary+1] then
        rotary   = rotary + 1
        position = position + 1
        if _rotaryPosition[rotary] ~= position then
            -- Set new rotary position in FMGS software
            if not test then ipc.writeUB( 0x78EE, _fmgsOffset[rotary] + (position - 1) ) end
            _rotaryPosition[rotary] = position
            if rotary <= 2 and _rotaryPosition[1] > 0 and _rotaryPosition[2] > 0 then
                _adirs.rcvRotaryPosDisplay(_rotaryPosition[1],_rotaryPosition[2])
            elseif rotary > 2 then
                _adirs.rcvRotaryPosIR(rotary - 2, position)
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
    if rotary >= 1 and rotary <= 5 then
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