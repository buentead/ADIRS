----------------------------------------------------------------------
-- adirsDisplay.lua
----------------------------------------------------------------------
-- This modules updates the ADIRS display acording to the DATA and SYS
-- rotary switches and the Flight Simulator data

local adirsDisplay = {}

-- constants
local _displayTest  = '888888888888888888888888'
local _displayAlign = '------------------------'
local _displayNoMsg = 'STS - NONE'
local _displayEnter = 'STS - ENTER PPOS'
local _displayTTN   = 'HEADING --.-`     TTN %i'
local _displayRealn = 'REALN DESN %i SEC'
local _displayOFFt  = 'OFF TIME %i SEC'
local _iruOFF       = 1
local _iruNAV       = 2
local _iruATT       = 3

-- internal variables
local _serial
local _rotData = {'TEST','TKGS','PPOS','WIND','HDG','STS' }
local _rotSys  = {'OFF','IR1','IR3','IR2' }
local _labelIR = {'IR1','IR3','IR2'}
local _display = {                                 -- in Flight Simulator data are independent of IRx
    TEST = _displayTest,
    TKGS = 'TKGS',
    PPOS = 'PPOS',
    WIND = 'WIND',
    HDG = 'HDG',
    STS = _displayNoMsg
}
local _displayOn = {'',''}                          -- 1-DATA, 2-SYS
local _stateAdir = {1,0}                            -- status, timeout
local _stateIR   = {IR1 = {1,0,0}, IR2 = {1,0,0}, IR3 = {1,0,0}}  -- status, timeout/interval, counter
                                                    -- states: 1-OFF, 2-NAV aligning, 3-NAV, 4-ATT, 5-REALN, 6-OFFtim
local _timeout   = 1                                -- timeout in seconds
local _timeoutIR = 5                                -- timeout of IRUx power down
local _timeoutA1 = 8                                -- minutes to align IRU
local _timeoutA2 = 1                                -- 1 minute to align IRU (fast allign between legs)
local _fProcessACK = 0
local _fProcessNAK = 0

-- instance values
local _trueTrack   = -0.1
local _groundSpeed = 0
local _ppos        = {LAT = {'N',0,0.0}, LON = {'E',0,0.0} }
local _windKn      = 0
local _windDeg     = 0.0
local _trueHeading = 0.0

-- Set new ADIRS Display Status
local function _setStatus(status)
    if _displayOn[2] == 'OFF' and (status == 2 or status == 6) then
        _stateAdir[1] = 3      -- ADIRS display is off
    else
        _stateAdir[1] = status
    end
    _stateAdir[2] = os.clock() + _timeout
    if _stateAdir[1] ~= 4 and _stateAdir[1] ~= 5 and _stateAdir[1] ~= 7 and _stateAdir[1] ~= 8 then
        -- new status ignors ACK or NAK messages.
        _fProcessACK = 0
        _fProcessNAK = 0
    end
    return _stateAdir[1]
end

-- Get current ADIRS Display Status
local function _getStatus()
    return _stateAdir[1]
end

-- Set new IRUx Status
local function _setStatusIRU(iru, status)
    if _stateIR[iru][1] == 1 and status == 2 then
        _stateIR[iru][2] = os.clock() + 60
        _stateIR[iru][3] = _timeoutA1
    elseif _stateIR[iru][1] == 5 and status == 2 then
        _stateIR[iru][2] = os.clock() + 60
        _stateIR[iru][3] = _timeoutA2
    else
        _stateIR[iru][2] = os.clock() + 1
        _stateIR[iru][3] = _timeoutIR
    end
    _stateIR[iru][1] = status
    return _stateIR[iru][1]
end

-- Get current IRUx Status
local function _getStatusIRU(iru)
    return _stateIR[iru][1]
end

-- Get current IRUx Status Time Out
local function _getStatusTimeoutIRU(iru)
    return _stateIR[iru][2]
end

-- Check if status has timed out
local function _checkStatusTimeout()
    if os.clock() > _stateAdir[2] then
        if     _getStatus() == 4 then _setStatus(2)
        elseif _getStatus() == 5 then _setStatus(2)
        elseif _getStatus() == 7 then _setStatus(3)
        elseif _getStatus() == 8 then _setStatus(2)
        end
    end
    return _getStatus()
end

-- Check if IRx is powering OFF
local function _checkIRUPowerDown(iru)
    local _updRequired
    local _statusNew = _getStatus()
    for k, v in pairs(_stateIR) do
        _updRequired = false
        if v[1] == 5 and v[3] == 0 then
            -- Realn Desn completed --> state6
            _setStatusIRU(k,6)
            _updRequired = true
        elseif v[1] == 6 and v[3] == 0 then
            -- OFF time completed --> state1
            _setStatusIRU(k,1)
            _updRequired = true
        elseif (v[1] == 5 or v[1] == 6) and os.clock() > v[2] then
            -- countdown of power off sequence
            _stateIR[k][3] = v[3] - 1
            _stateIR[k][2] = os.clock() + 1
            _updRequired = true
        elseif v[1] == 2 and v[3] > 0 and os.clock() > v[2] then
            -- waiting for IRU alignment
            _stateIR[k][3] = _stateIR[k][3] - 1
            _stateIR[k][2] = os.clock() + 60
            _updRequired = true
        end
        if _displayOn[2] == k and _updRequired then
            if _statusNew == 4 then
                _statusNew = _setStatus(5)
            elseif _statusNew == 6 then
                _statusNew = _setStatus(2)
            end
        end
    end
    return _statusNew
end

-- ----------------------------------------------------
-- Check if new data received currently being displayed
-- ----------------------------------------------------
local function _rcvFSUpdShown(rcvData)
    local _statusNew = _checkStatusTimeout()
    if _displayOn[2] ~= 'OFF' and (_displayOn[1] == rcvData or _displayOn[2] == rcvData) then
        if _statusNew == 4 then
            _statusNew = _setStatus(5)
        elseif _statusNew == 6 then
            _statusNew = _setStatus(2)
        end
    end
    return _statusNew
end

-- ---------------------------------------
-- Rotary positions of DATA / SYS received
-- ---------------------------------------
local function _rcvRotaryPosDisplay(data,sys)
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
        if (_getStatus() == 4 or _getStatus() == 5) then
            _statusNew = _setStatus(5)
        else
            _statusNew = _setStatus(2)
        end
    end
    return _statusNew
end

-- --------------------------------
-- Rotary Positions of IRx received
-- --------------------------------
local function _rcvRotaryPosIR(iru, pos)
    local _statusNew
    local _iru = _labelIR[iru]
    if pos == _iruOFF then
        _setStatusIRU(_iru, 5)
    elseif pos == _iruNAV then
        _setStatusIRU(_iru, 2)
    elseif pos == _iruATT then
        _setStatusIRU(_iru, 4)
    end
    _statusNew = _rcvFSUpdShown(_iru)
    return _statusNew
end

-- -------------------------------------
-- Receive "send ADIRS OFF Display" ACK
-- -------------------------------------
local function _rcvADIRSOffACK()
    if _getStatus() == 8 then
        _setStatus(2)
    else
        _setStatus(9)
    end
end

-- -------------------------------------
-- Receive "send ADIRS OFF Display" NAK
-- -------------------------------------
local function _rcvADIRSOffNAK()
    if _getStatus() == 8 then
        _setStatus(2)
    else
        _setStatus(3)
    end
end

-- -------------------------------------
-- Receive "send ADIRS Info Display" ACK
-- -------------------------------------
local function _rcvADIRSInfoACK()
    if _getStatus() == 5 then
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
    _checkIRUPowerDown()
    _checkStatusTimeout()
    if _getStatus() == 2 then

        -- DATA set to 'TEST'
        if _displayOn[1] == 'TEST' then
            _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. _display[_displayOn[1]])

        -- IRU is OFF
        elseif _stateIR[_displayOn[2]][1] == 1 then
            _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD, ')

        -- IRU is aligning
        elseif _stateIR[_displayOn[2]][1] == 2 then
            if _displayOn[1] == 'HDG' then
                _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. string.format(_displayTTN, _stateIR[_displayOn[2]][3]))
            elseif _displayOn[1] == 'STS' then
                _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. _displayEnter)
            else
                _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. _displayAlign)
            end

        -- IRU is aligned (NAV mode)
        elseif _stateIR[_displayOn[2]][1] == 3 then
            if _displayOn[1] == 'STS' then
                _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. _displayNoMsg)
            else
                _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. _display[_displayOn[1]])
            end

        -- IRU is in ATT mode
        elseif _stateIR[_displayOn[2]][1] == 4 then
            if _displayOn[1] == 'STS' then
                _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. _displayNoMsg)
            else
                _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. _displayAlign)
            end

        -- Power Down - realign
        elseif _stateIR[_displayOn[2]][1] == 5 then
            _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. string.format(_displayRealn, _stateIR[_displayOn[2]][3]))

        -- Power Down - OFF time
        elseif _stateIR[_displayOn[2]][1] == 6 then
            _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,' .. string.format(_displayOFFt, _stateIR[_displayOn[2]][3]))

        -- unknown IRU status
        else
            _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD,ERROR: unknown _stateIR')
        end

        if _rc == 0 then
            _fProcessACK = _rcvADIRSInfoACK
            _fProcessNAK = _rcvADIRSInfoNAK
            _setStatus(4)
        end
    elseif _getStatus() == 3 then
        _msg,_rc = _serial.sndData(adirsDisplay, '$FSLCD, ')
        if _rc == 0 then
            _fProcessACK = _rcvADIRSOffACK
            _fProcessNAK = _rcvADIRSOffNAK
            _setStatus(7)
        end
    end
    return _msg, _getStatus()
end

-- -----------
-- Receive ACK
-- -----------

local function _rcvACK()
    if _fProcessACK ~= 0 then
        _fProcessACK()
    end
    return _getStatus()
end

-- -----------
-- Receive NAK
-- -----------

local function _rcvNAK()
    if _fProcessNAK ~= 0 then
        _fProcessNAK()
    end
    return _getStatus()
end

-- -----------
-- Update TKGS
-- -----------
local function _updTKGS()
    local _statusNew
    _display['TKGS'] = string.format('TK %05.1f` %3iKTS', _trueTrack, _groundSpeed)
    _statusNew = _rcvFSUpdShown('TKGS')
    return _statusNew
end
-- ----------------
-- Event True Track
-- ----------------
local function _evtTrueTrack(deg)
    local _statusNew = _getStatus()
    if _trueTrack ~= deg then
        _trueTrack = deg
        _statusNew = _updTKGS()
    end
    return _display['TKGS'], _statusNew
end

-- ------------------
-- Event Ground Speed
-- ------------------
local function _evtGroundSpeed(knots)
    local _statusNew = _getStatus()
    if _groundSpeed ~= knots then
        _groundSpeed = knots
        _statusNew = _updTKGS()
    end
    return _display['TKGS'], _statusNew
end

-- ----------------------
-- event Present Position
-- ----------------------
local function _evtPPos(coord,coordO,coordG,coordM)
    local _statusNew = _getStatus()
    if _ppos[coord][1] ~= coordO or _ppos[coord][2] ~= coordG or _ppos[coord][3] ~= coordM then
        _ppos[coord][1] = coordO
        _ppos[coord][2] = coordG
        _ppos[coord][3] = coordM
        _display['PPOS'] = string.format(" %s%3i`%4.1f'  %s%03i`%4.1f'",
            _ppos['LAT'][1], _ppos['LAT'][2], _ppos['LAT'][3],
            _ppos['LON'][1], _ppos['LON'][2], _ppos['LON'][3]
        )
        _statusNew = _rcvFSUpdShown('PPOS')
    end
    return _display['PPOS'], _statusNew
end

-- -------------------
-- Update Wind display
-- -------------------
local function _updWind()
    local _statusNew
    _display['WIND'] = string.format('WIND %3iKTS / %03i`', _windKn, _windDeg)
    _statusNew = _rcvFSUpdShown('WIND')
    return _statusNew
end

-- ---------------------
-- Ambient Wind in Knots
-- ---------------------
local function _evtWindKn(knots)
    local _statusNew = _getStatus()
    if _windKn ~= knots then
        _windKn = knots
        _statusNew = _updWind()
    end
    return _display['WIND'], _statusNew
end

-- ----------------------
-- Ambient Wind Direction
-- ----------------------
local function _evtWindDeg(deg)
    local _statusNew = _getStatus()
    if _windDeg ~= deg then
        _windDeg = deg
        _statusNew = _updWind()
    end
    return _display['WIND'], _statusNew
end

-- ------------
-- True Heading
-- ------------
local function _evtHeading(deg)
    local _statusNew = _getStatus()
    if _trueHeading ~= deg then
        _trueHeading = deg
        _display['HDG'] = string.format('HEADING %05.1f`', _trueHeading)
        _statusNew = _rcvFSUpdShown('HDG')
    end
    return _display['HDG'], _statusNew
end

-- ----------------------
-- IRx alignment received
-- ----------------------
local function _rcvIRAligned(iru, aligned)
    local _statusNew = _getStatus()
    -- Check Status Timeout to allow IRx ALIGN LED to turn on
    if aligned and _getStatusIRU(iru) == 2 and os.clock() > (_getStatusTimeoutIRU(iru) - 59) then
        _setStatusIRU(iru, 3)
        _statusNew = _rcvFSUpdShown(iru)
    end
    return _statusNew
end

-- ----------------------------------
-- Set instance of data communication
-- ----------------------------------
local function _setDataCom(object)
    _serial = object
end

adirsDisplay = {
    setDataCom          = _setDataCom,
    rcvRotaryPosDisplay = _rcvRotaryPosDisplay,
    rcvRotaryPosIR      = _rcvRotaryPosIR,
    rcvIRAligned        = _rcvIRAligned,
    sndADIRSInfo        = _sndADIRSInfo,
    rcvACK              = _rcvACK,
    rcvNAK              = _rcvNAK,
    evtTrueTrack        = _evtTrueTrack,
    evtGroundSpeed      = _evtGroundSpeed,
    evtPPos             = _evtPPos,
    evtWindKn           = _evtWindKn,
    evtWindDeg          = _evtWindDeg,
    evtHeading          = _evtHeading,
    getStatus           = _getStatus,
    getStatusIRU        = _getStatusIRU,
    __setStatusIRU      = _setStatusIRU         -- for unit testing only!
}
return adirsDisplay
