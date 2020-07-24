----------------------------------------------------------------------
-- adirsDisplay.lua
----------------------------------------------------------------------
-- This modules updates the ADIRS display acording to the DATA and SYS
-- rotary switches and the Flight Simulator data

local adirsDisplay = {}

-- internal variables
local _serial
local _rotData = {'TEST','TKGS','PPOS','WIND','HDG','STS' }
local _rotSys  = {'OFF','IR1','IR3','IR2' }
local _statusIR = {IR1 = 1, IR2 = 1, IR3 = 1}       -- 0-OFF, 1-ON, 2-going OFF1, 3-going OFF2
local _display  = {
    TEST = '888888888888888888888888',
    TKGS = 'TKGS',
    PPOS = 'PPOS',
    WIND = 'WIND',
    HDG = 'HDG',
    STS = 'No Messages'
}  -- in Flight Simulator data are independent of IRx
local _displayOn = {'',''}                          -- 1-DATA, 2-SYS
local _status = { 1, 0}                             -- status, timeout
local _timeout = 1                                  -- timeout in seconds
local _fProcessACK = 0
local _fProcessNAK = 0


-- Set new Status
local function _setStatus(status)
    if _displayOn[2] == 'OFF' and (status == 2 or status == 6) then
        _status[1] = 3      -- ADIRS display is off
    else
        _status[1] = status
    end
    _status[2] = os.clock() + _timeout
    if _status[1] ~= 4 and _status[2] ~= 5 then
        -- new status ignors ACK or NAK messages.
        _fProcessACK = 0
        _fProcessNAK = 0
    end
    return _status[1]
end

-- Check if status has timed out
local function _checkStatusTimeout()
    if os.clock() > _status[2] then
        if     _status[1] == 4 then _status[1] = 2
        elseif _status[1] == 5 then _status[1] = 2
        end
    end
    return _status[1]
end

-- -------------------------
-- Rotary positions received
-- -------------------------
local function _rcvRotaryPos(data,sys)
    local _displayNewData = false
    local _statusNew = _checkStatusTimeout()
    if _displayOn[1] ~= _rotData[data] then
        _displayOn[1] = _rotData[data]
        _displayNewData = true
    end
    if _displayOn[2] ~= _rotSys[sys] then
        _displayOn[2] = _rotSys[sys]
        _displayNewData = true
    end
    if _displayNewData == true then
        if (_status[1] == 4 or _status[1] == 5) then
            _statusNew = _setStatus(5)
        else
            _statusNew = _setStatus(2)
        end
    end
    return _statusNew
end

-- -----------------------------------
-- Receive send ADIRS Info Display ACK
-- -----------------------------------
local function _rcvADIRSInfoACK()
    if _status[1] == 5 then
        _setStatus(2)
    else
        _setStatus(6)
    end
end

-- -----------------------------------
-- Receive send ADIRS Info Display NAK
-- -----------------------------------
local function _rcvADIRSInfoNAK()
    _setStatus(2)
end

-- --------------------------
-- Send ADIRS info to display
-- --------------------------

local function _sndADIRSInfo()
    local _rc  = -1
    local _msg
    _checkStatusTimeout()
    if _status[1] == 2 then
        if _statusIR[_displayOn[2]] == 1 then
            _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. _display[_displayOn[1]])
        else
            _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD, ')
        end
        if _rc == 0 then
            _fProcessACK = _rcvADIRSInfoACK
            _fProcessNAK = _rcvADIRSInfoNAK
            _setStatus(4)
        end
    end
    return _msg, _status[1]
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

-- ------------------
-- Get current status
-- ------------------
local function _getStatus()
    return _status[1]
end

-- ----------------------------------
-- Set instance of data communication
-- ----------------------------------
local function _setDataCom(object)
    _serial = object
end

adirsDisplay = {
    setDataCom   = _setDataCom,
    rcvRotaryPos = _rcvRotaryPos,
    sndADIRSInfo = _sndADIRSInfo,
    rcvACK       = _rcvACK,
    rcvNAK       = _rcvNAK,
    getStatus    = _getStatus
}
return adirsDisplay
