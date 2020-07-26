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

-- instance values
local _trueTrack   = 0
local _groundSpeed = 0
local _ppos        = {LAT = {'N',0,0.0}, LON = {'E',0,0.0} }
local _windKn      = 0
local _windDeg     = 0
local _trueHeading = 0

-- Set new Status
local function _setStatus(status)
    if _displayOn[2] == 'OFF' and (status == 2 or status == 6) then
        _status[1] = 3      -- ADIRS display is off
    else
        _status[1] = status
    end
    _status[2] = os.clock() + _timeout
    if _status[1] ~= 4 and _status[1] ~= 5 and _status[1] ~= 7 and _status[1] ~= 8 then
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
        elseif _status[1] == 7 then _status[1] = 3
        elseif _status[1] == 8 then _status[1] = 2
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
    if _displayNewData then
        if (_status[1] == 4 or _status[1] == 5) then
            _statusNew = _setStatus(5)
        else
            _statusNew = _setStatus(2)
        end
    end
    return _statusNew
end

-- -------------------------------------
-- Receive "send ADIRS OFF Display" ACK
-- -------------------------------------
local function _rcvADIRSOffACK()
    if _status[1] == 8 then
        _setStatus(2)
    else
        _setStatus(9)
    end
end

-- -------------------------------------
-- Receive "send ADIRS OFF Display" NAK
-- -------------------------------------
local function _rcvADIRSOffNAK()
    if _status[1] == 8 then
        _setStatus(2)
    else
        _setStatus(3)
    end
end

-- -------------------------------------
-- Receive "send ADIRS Info Display" ACK
-- -------------------------------------
local function _rcvADIRSInfoACK()
    if _status[1] == 5 then
        _setStatus(2)
    else
        _setStatus(6)
    end
end

-- -------------------------------------
-- Receive "send ADIRS Info Display" NAK
-- -------------------------------------
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
        if _statusIR[_displayOn[2]] == 1 then   -- verify if IRx is ON
            _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. _display[_displayOn[1]])
        else
            _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD, ')
        end
        if _rc == 0 then
            _fProcessACK = _rcvADIRSInfoACK
            _fProcessNAK = _rcvADIRSInfoNAK
            _setStatus(4)
        end
    elseif _status[1] == 3 then
        _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD, ')
        if _rc == 0 then
            _fProcessACK = _rcvADIRSOffACK
            _fProcessNAK = _rcvADIRSOffNAK
            _setStatus(7)
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

-- ----------------------------------------------------
-- Check if new data received currently being displayed
-- ----------------------------------------------------
local function _rcvFSUpdShown(rcvData)
    local _statusNew = _checkStatusTimeout()
    if _displayOn[1] == rcvData then
        if _status[1] == 4 then
            _statusNew = _setStatus(5)
        elseif _status[1] == 6 then
            _statusNew = _setStatus(2)
        end
    end
    return _statusNew
end

-- -----------
-- Update TKGS
-- -----------
local function _updTKGS()
    local _rc
    _display['TKGS'] = string.format('TK %03i` %3iKTS', _trueTrack, _groundSpeed)
    _rc = _rcvFSUpdShown('TKGS')
    return _rc
end
-- ----------------
-- Event True Track
-- ----------------
local function _evtTrueTrack(deg)
    local _statusNew
    _trueTrack = deg
    _statusNew = _updTKGS()
    return _display['TKGS'], _statusNew
end

-- ------------------
-- Event Ground Speed
-- ------------------
local function _evtGroundSpeed(knots)
    local _statusNew
    _groundSpeed = knots
    _statusNew = _updTKGS()
    return _display['TKGS'], _statusNew
end

-- ----------------------
-- event Present Position
-- ----------------------
local function _evtPPos(coord,coordO,coordG,coordM)
    _ppos[coord][1] = coordO
    _ppos[coord][2] = coordG
    _ppos[coord][3] = coordM
    _display['PPOS'] = string.format("%s%3i`%5.2f'  %s%03i`%5.2f'",
        _ppos['LAT'][1], _ppos['LAT'][2], _ppos['LAT'][3],
        _ppos['LON'][1], _ppos['LON'][2], _ppos['LON'][3]
    )
    return _display['PPOS'], _rcvFSUpdShown('PPOS')
end

-- -------------------
-- Update Wind display
-- -------------------
local function _updWind()
    local _rc
    _display['WIND'] = string.format('WIND %3iKTS / %03i`', _windKn, _windDeg)
    _rc = _rcvFSUpdShown('WIND')
    return _rc
end

-- ---------------------
-- Ambient Wind in Knots
-- ---------------------
local function _evtWindKn(knots)
    local _statusNew
    _windKn = knots
    _statusNew = _updWind()
    return _display['WIND'], _statusNew
end

-- ----------------------
-- Ambient Wind Direction
-- ----------------------
local function _evtWindDeg(deg)
    local _statusNew
    _windDeg = deg
    _statusNew = _updWind()
    return _display['WIND'], _statusNew
end

-- ------------
-- True Heading
-- ------------
local function _evtHeading(deg)
    _trueHeading = deg
    _display['HDG'] = string.format('HEADING %03i`', _trueHeading)
    return _display['HDG'], _rcvFSUpdShown('HDG')
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
    evtTrueTrack = _evtTrueTrack,
    evtGroundSpeed = _evtGroundSpeed,
    evtPPos      = _evtPPos,
    evtWindKn    = _evtWindKn,
    evtWindDeg   = _evtWindDeg,
    evtHeading   = _evtHeading,
    getStatus    = _getStatus
}
return adirsDisplay
