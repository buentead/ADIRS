--
-- Created by IntelliJ IDEA.
-- User: buentead
-- Date: 15/07/2020
-- Time: 14:47
-- To change this template use File | Settings | File Templates.
--

local sendReceiveData = {}
-- local variables
local _rotary    = require('lib/rotary')
local _handshake = require('lib/handshake')
local _module               -- module waiting for ACK or NAK
local _hCom        = 0      -- handler of serial interface
local _fDataTX     = 0      -- function to display buffer in WideFS client
local _waitForACK  = 0      -- indicates that no data can be sent until ACK/NAK received or timed out
local _timeout     = 1      -- timeout in seconds

-- set serial handler
local function _setHandler(hCom)
    _hCom = hCom
end

-- set function to display transmitted data
local function _setFunctionDataTx(dataTX)
    _fDataTX = dataTX
end

-- send ACK or NAK
local function _sndACKNAK(msgBuffer)
    local _i      = 1
    local _sndLen = 0
    local _msg    = msgBuffer .. '\r\n'
    local _rc     = 0
    if _handshake.arduinoConnected() then
        if _hCom ~= 0 then
            repeat
                _sndLen = com.write(_hCom, _msg:sub(_i))
                _i = _i + _sndLen
            until _i > _msg:len()
        else
            print('\n** serial:' .. msgBuffer)
        end
        if _fDataTX ~= 0 then _fDataTX(msgBuffer) end
    end
    return _msg, _rc
end


-- send ASCII data and append CR+LF
local function _sndData(module, msgBuffer)
    local _i      = 1
    local _sndLen = 0
    local _msg    = msgBuffer .. '\r\n'
    local _rc     = -1
    _module       = module
    if _waitForACK == 0 or os.clock() > _waitForACK then _rc = 0 else _rc = _waitForACK end
    if _rc == 0 and _handshake.arduinoConnected() then
        if _hCom ~= 0 then
            repeat
                _sndLen = com.write(_hCom, _msg:sub(_i))
                _i = _i + _sndLen
            until _i > _msg:len()
        else
            print('\n** serial:' .. msgBuffer)
        end
        if _fDataTX ~= 0 then _fDataTX(msgBuffer) end
        -- check if ACK/NAK is needed
        if _module then
            _waitForACK = os.clock() + _timeout
        else
            _waitForACK = 0
        end
    end
    return _msg, _rc
end

-- Process data received: 'ccccc,vvvvvv' (no leading '$' and trailing 'CR+LF')
local function _rcvData(strData,test)
    local _rot, _pos, _idx = 0, 0, 0
    if strData:sub(1, 5) == "ADVER" then
        -- process: "ADVER,1.00"
        _handshake.rcvADVersion(strData,test)
    elseif strData:sub(1, 5) == "ADACK" then
        -- ACK received from Arduino
        if _module then
            _module.rcvACK()
        end
        _waitForACK = 0
    elseif strData:sub(1, 5) == "ADNAK" then
        -- NAK received from Arduino
        if _module then
            _module.rcvNAK()
        end
        _waitForACK = 0
    elseif strData:sub(1, 5) == "ADROT" then
        -- Rotary Positions received from Arduino: "ADROT,[0..1],[0..9]"
        _rot = tonumber(strData:sub(-3,-3)) + 1
        _pos = tonumber(strData:sub(-1,-1))
        _rotary.setRotary(_rot,_pos,test)
    else
        _sndData(nil, '$FSNAK')
    end
    return strData
end

sendReceiveData = {
    setHandler        = _setHandler,
    setFunctionDataTx = _setFunctionDataTx,
    sndACKNAK         = _sndACKNAK,
    sndData           = _sndData,
    rcvData           = _rcvData
}

return sendReceiveData