----------------------------------------------------------------------
-- tripleGauge.lua
----------------------------------------------------------------------
-- This modules controls the three servos of a triple gauge

local tripleGauge = {}

-- internal variables
local _serial
local _servo = {ACCU = 0, LEFT = 0, RIGHT = 0}      -- 1:ACCU, 2:left brake, 3:right brake
local _status = { 1, 0}                             -- status, timeout
local _timeout = 1                                  -- timeout in seconds
local _fProcessACK = 0
local _fProcessNAK = 0

-- Get status
local function _getStatus()
    return _status[1]
end

-- Set new Status
local function _setStatus(status)
    _status[1] = status
    _status[2] = os.clock() + _timeout
    if _status[1] ~= 2 and _status[1] ~= 3 then
        -- new status ignors ACK or NAK messages.
        _fProcessACK = 0
        _fProcessNAK = 0
    end
    return _status[1]
end

-- Check if status has timed out
local function _checkStatusTimeout()
    if os.clock() > _status[2] then
        if     _status[1] == 2 then _setStatus(1)
        elseif _status[1] == 3 then _setStatus(1)
        end
    end
    return _status[1]
end

-- -----------
-- Receive ACK
-- -----------

local function _rcvACK()
    if _fProcessACK ~= 0 then
        _fProcessACK()
    end
    return _status[1]
end

-- -----------
-- Receive NAK
-- -----------

local function _rcvNAK()
    if _fProcessNAK ~= 0 then
        _fProcessNAK()
    end
    return _status[1]
end

-- ----------------
-- Set servo values
-- ----------------
local function _rcvTGValue(pServo, pValue)
    local _statusNew = _checkStatusTimeout()
    _servo[pServo] = pValue
    if     _status[1] == 2 then _setStatus(3)
    elseif _status[1] == 4 then _setStatus(1)
    end
    return _servo['ACCU'] .. ',' .. _servo['LEFT'] .. ',' .. _servo['RIGHT']
end

-- -------------------
-- Receive "servo" ACK
-- -------------------
local function _rcvServoACK()
    if _status[1] == 3 then
        _setStatus(1)
    else
        _setStatus(4)
    end
end

-- -------------------
-- Receive "servo" NAK
-- -------------------
local function _rcvServoNAK()
    _setStatus(1)
end

-- -----------------
-- Send servo values
-- -----------------
local function _sndTGValues()
    local _rc  = -1
    local _msg
    _checkStatusTimeout()
    if _status[1] == 1 then
        _msg,_rc = _serial.sndData(tripleGauge, '$FSTGV,' .. _servo['ACCU'] .. ',' .. _servo['LEFT'] .. ',' .. _servo['RIGHT'])
        if _rc == 0 then
            _fProcessACK = _rcvServoACK
            _fProcessNAK = _rcvServoNAK
            _setStatus(2)
        end
    end
    return _msg, _status[1]
end

-- ----------------------------------
-- Set instance of data communication
-- ----------------------------------
local function _setDataCom(object)
    _serial = object
end

tripleGauge = {
    setDataCom   = _setDataCom,
    getStatus    = _getStatus,
    rcvACK       = _rcvACK,
    rcvNAK       = _rcvNAK,
    rcvTGValue   = _rcvTGValue,
    sndTGValues  = _sndTGValues
}
return tripleGauge
