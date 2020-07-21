--
-- Created by IntelliJ IDEA.
-- User: buentead
-- Date: 11/07/2020
-- Time: 17:19
-- To change this template use File | Settings | File Templates.
--

local battery = {}

-- internal variables
local _serial
local _volt    = { BA1 = 0, BA2 = 0 }
local _show    = { BA1 = false, BA2 = false }
local _status  = { BA1 = {1, 0}, BA2 = {1, 0} }     -- status, timestamp
local _timeout = 1                                  -- timeout in seconds
local _ackBat  = ''                                 -- ACK or NAK expected for 'BA1' or 'BA2'
local _fProcessACK = 0
local _fProcessNAK = 0

-- helper function to check multiple values (source: https://stackoverflow.com/questions/49501359/lua-checking-multiple-values-for-equailty)
local function _set(...)
    local ret = {}
    for _,k in ipairs({...}) do ret[k] = true end
    return ret
end

-- Set new Status
local function _setStatus(bat,status)
    _status[bat][1] = status
    _status[bat][2] = os.clock() + _timeout
    if not _set(3,4,6,12)[_status[bat][1]] then
        -- new status ignors ACK or NAK messages.
        _fProcessACK = 0
        _fProcessNAK = 0
    end
end

-- Check if status has timed out
local function _checkStatusTimeout(bat)
    if (os.clock() > _status[bat][2]) then
        if     _status[bat][1] == 3  then _status[bat][1] = 2
        elseif _status[bat][1] == 4  then _status[bat][1] = 5
        elseif _status[bat][1] == 6  then _status[bat][1] = 5
        elseif _status[bat][1] == 12 then _status[bat][1] = 11
        end
    end
end

-- nothing to do
local function _nop(bat)
end

-- -----------------
-- Event Battery OFF
-- -----------------

local _setStatusEvtBATxOFF = {
    [1]  = _nop,
    [2]  = function (bat) _show[bat] = false _setStatus(bat,1) end,
    [3]  = _nop,
    [4]  = _nop,
    [5]  = _nop,
    [6]  = _nop,
    [11] = function (bat) _show[bat] = false _setStatus(bat,5) end,
    [12] = function (bat) _show[bat] = false _setStatus(bat,4) end,
    [13] = function (bat) _show[bat] = false _setStatus(bat,5) end
}
local function _evtBATxOFF(bat)
    _checkStatusTimeout(bat)
    _setStatusEvtBATxOFF[_status[bat][1]](bat)
    return bat, _show[bat], _status[bat][1]
end

-- -----------------------
-- Receive Battery OFF ACK
-- -----------------------
local function _rcvBATxOFFACK(bat)
    _setStatus(bat,1)
end

-- -----------------------
-- Receive Battery OFF NAK
-- -----------------------
local function _rcvBATxOFFNAK(bat)
    _setStatus(bat,5)
end

-- ----------------
-- Send Battery OFF
-- ----------------

local function _sndBATxOFF(bat)
    local _rc = -1
    _checkStatusTimeout(bat)
    if _status[bat][1] == 5 then
        _ackBat = bat
        _,_rc = _serial.sndData(battery, '$FSOFF,' .. bat)
        if _rc == 0 then
            _fProcessACK = _rcvBATxOFFACK
            _fProcessNAK = _rcvBATxOFFNAK
            _setStatus(bat,6)
        end
    end
    return bat, _show[bat], _status[bat][1]
end

-- ----------------
-- Event Battery ON
-- ----------------

local _setStatusEvtBATxON = {
    [1]  = function (bat) _show[bat] = true _setStatus(bat,2) end,
    [2]  = _nop,
    [3]  = _nop,
    [4]  = _nop,
    [5]  = function (bat) _show[bat] = true _setStatus(bat,2) end,
    [6]  = _nop,
    [11] = _nop,
    [12] = _nop,
    [13] = _nop
}
local function _evtBATxON(bat)
    _checkStatusTimeout(bat)
    _setStatusEvtBATxON[_status[bat][1]](bat)
    return bat, _show[bat], _status[bat][1]
end

-- ----------------------
-- Receive Battery ON ACK
-- ----------------------
local function _rcvBATxONACK(bat)
    _setStatus(bat,11)
end

-- ----------------------
-- Receive Battery ON NAK
-- ----------------------
local function _rcvBATxONNAK(bat)
    _setStatus(bat,2)
end

-- ---------------
-- Send Battery ON
-- ---------------

local function _sndBATxON(bat)
    local _rc = -1
    _checkStatusTimeout(bat)
    if _status[bat][1] == 2 then
        _ackBat = bat
        _,_rc = _serial.sndData(battery, '$FSON,' .. bat)
        if _rc == 0 then
            _fProcessACK = _rcvBATxONACK
            _fProcessNAK = _rcvBATxONNAK
            _setStatus(bat,3)
        end
    end
    return bat, _show[bat], _status[bat][1]
end

-- ---------------------------
-- Event Battery Volt
-- ---------------------------

local _setStatusEvtBATxVolt = {
    [1]  = _nop,
    [2]  = _nop,
    [3]  = _nop,
    [4]  = _nop,
    [5]  = _nop,
    [6]  = _nop,
    [11] = _nop,
    [12] = function (bat) _setStatus(bat,11) end,
    [13] = function (bat) _setStatus(bat,11) end
}
local function _evtBATxVolt(bat, volt)
    _checkStatusTimeout(bat)
    _volt[bat] = volt
    _setStatusEvtBATxVolt[_status[bat][1]](bat)
    return bat, _volt[bat], _status[bat][1]
end

-- ------------------------
-- Receive Battery Volt ACK
-- ------------------------
local function _rcvBATxVoltACK(bat)
    _setStatus(bat,13)
end

-- ------------------------
-- Receive Battery Volt NAK
-- ------------------------
local function _rcvBATxVoltNAK(bat)
    _setStatus(bat,11)
end

-- ---------------------------
-- Send Battery Volt
-- ---------------------------

local function _sndBATxVolt(bat)
    local _rc = -1
    _checkStatusTimeout(bat)
    if _status[bat][1] == 11 then
        _ackBat = bat
        _,_rc = _serial.sndData(battery, '$FS' .. bat .. ',' .. string.format('%04i', _volt[bat]))
        if _rc == 0 then
            _fProcessACK = _rcvBATxVoltACK
            _fProcessNAK = _rcvBATxVoltNAK
            _setStatus(bat,12)
        end
    end
    return bat, _volt[bat], _status[bat][1]
end

-- -----------
-- Receive ACK
-- -----------

local function _rcvACK()
    if _fProcessACK ~= 0 then
        _fProcessACK(_ackBat)
    end
    return _ackBat, _status[_ackBat][1]
end

-- -----------
-- Receive NAK
-- -----------

local function _rcvNAK()
    if _fProcessNAK ~= 0 then
        _fProcessNAK(_ackBat)
    end
    return _ackBat, _status[_ackBat][1]
end

-- ---------------------------------
-- Send data based on battery status
-- ---------------------------------
local _funcSendBATData = {
    [2]  = function (bat) b,_,s = _sndBATxON(bat) return b,s end,
    [5]  = function (bat) b,_,s = _sndBATxOFF(bat) return b,s end,
    [11] = function (bat) b,_,s = _sndBATxVolt(bat) return b,s end
}
local function _sndBATData()
    local _bat, _stat
    --TODO: loop shouldn't always start with BA1 entry
    for bat, status in pairs(_status) do
        _checkStatusTimeout(bat)
        if _funcSendBATData[status[1]] then
            _bat, _stat = _funcSendBATData[status[1]](bat)
            break       -- send only one request in order to wait for its ACK/NAK
        end
    end
    return _bat, _stat
end

-- ----------------------------------
-- Set instance of data communication
-- ----------------------------------
local function _setDataCom(object)
    _serial = object
end

battery = {
    setDataCom  = _setDataCom,
    evtBATxOFF  = _evtBATxOFF,
    sndBATxOFF  = _sndBATxOFF,
    evtBATxON   = _evtBATxON,
    sndBATxON   = _sndBATxON,
    evtBATxVolt = _evtBATxVolt,
    sndBATxVolt = _sndBATxVolt,
    sndBATData  = _sndBATData,
    rcvACK      = _rcvACK,
    rcvNAK      = _rcvNAK
}
return battery