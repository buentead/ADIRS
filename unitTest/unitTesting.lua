--
-- Created by IntelliJ IDEA.
-- User: buentead
-- Date: 11/07/2020
-- Time: 17:22
-- To change this template use File | Settings | File Templates.
--

lunit     = require('luaunit')
bat       = require('lib/battery')
rotary    = require('lib/rotary')
handshake = require('lib/handshake')
data      = require('lib/sendReceiveData')

bat.setDataCom(data)                     -- set instance to send data
rotary.setDataCom(data)                  -- set instance to send data
handshake.setDataCom(data)               -- set instance to send data

Test010Handshake = {}
    -- establish connection
    local _msg  = ''
    local _init = false
    function Test010Handshake:test010()
        _msg = data.rcvData('ADVer,1.00')
        lunit.assertEquals(_msg,'ADVer,1.00')
        lunit.assertEquals(handshake.arduinoConnected(),false)
        _msg = data.rcvData('ADVER,1.00')
        lunit.assertEquals(_msg,'ADVER,1.00')
        data.rcvData('ADACK')
        lunit.assertEquals(handshake.arduinoConnected(),true)
        _bat, _volt, _stat = bat.evtBATxVolt('BA1',0001)
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_volt,0001)
        lunit.assertEquals(_stat,2)
        _bat, _volt, _stat = bat.evtBATxVolt('BA2',0002)
        lunit.assertEquals(_bat,'BA2')
        lunit.assertEquals(_volt,0002)
        lunit.assertEquals(_stat,2)
    end
-- end of table 'TestInitialize'

Test020Battery = {}
    local _bat  = ''
    local _volt = ''
    local _show = false
    local _stat  = 0
    -- Switch immediately ON/OFF -> OFF
    function Test020Battery:test010()
        bat.evtBATxOFF('BA1')
        bat.evtBATxON('BA1')
        _bat, _show, _stat = bat.evtBATxOFF('BA1')
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_show,false)
        lunit.assertEquals(_stat,1)
    end
    -- Switch ON with one NAK -> ON
    function Test020Battery:test020()
        _bat, _show, _stat = bat.evtBATxON('BA1')
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_show,true)
        lunit.assertEquals(_stat,2)
        _bat, _stat = bat.sndBATData()
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_stat,3)
        data.rcvData('ADNAK')
        _bat, _stat = bat.sndBATData()
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_stat,3)
        data.rcvData('ADACK')
        _bat, _, _stat = bat.evtBATxON('BA1')
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_stat,11)
    end
    -- Send Volt with one NAK and one ACK, receive new Volt
    function Test020Battery:test100()
        _bat, _volt, _stat = bat.evtBATxVolt('BA1', 123)
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_volt,123)
        lunit.assertEquals(_stat,11)
        _bat, _volt, _stat = bat.sndBATxVolt('BA1')
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_volt,123)
        lunit.assertEquals(_stat,12)
        _bat, _volt, _stat = bat.evtBATxVolt('BA1', 4567)
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_volt,4567)
        lunit.assertEquals(_stat,11)
        data.rcvData('ADACK')
        _bat, _volt, _stat = bat.sndBATxVolt('BA1')
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_volt,4567)
        lunit.assertEquals(_stat,12)
        data.rcvData('ADACK')
        _bat, _, _stat = bat.evtBATxON('BA1')
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_stat,13)
        _bat, _volt, _stat = bat.evtBATxVolt('BA1', 890)
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_volt,890)
        lunit.assertEquals(_stat,11)
    end
    -- Switch OFF with NAK and ON before sending OFF -> ON
    function Test020Battery:test200()
        bat.evtBATxOFF('BA1')
        bat.sndBATxOFF('BA1')
        data.rcvData('ADNAK')
        _bat, _show, _stat = bat.evtBATxON('BA1')
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_show,true)
        lunit.assertEquals(_stat,2)
        bat.sndBATxON('BA1')
        data.rcvData('ADACK')
        _bat, _, _stat = bat.evtBATxON('BA1')
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_stat,11)
    end
    -- Switch both batteries on and display volt
    function Test020Battery:test300()
        _bat, _volt, _stat = bat.evtBATxVolt('BA2', 275)
        lunit.assertEquals(_bat,'BA2')
        lunit.assertEquals(_volt,275)
        lunit.assertEquals(_stat,2)
        _bat, _volt, _stat = bat.evtBATxVolt('BA1', 279)
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_volt,279)
        lunit.assertEquals(_stat,11)
        bat.evtBATxON('BA2')    -- switch on BA2 display
        bat.evtBATxON('BA1')    -- no impact, as BA1 is already in state 11 (previous test200)
        _bat, _stat = bat.sndBATData()  -- will send volt 27.9 of BA1
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_stat,12)
        data.rcvData('ADACK')
        _bat, _stat = bat.sndBATData()  -- will switch on BA1 display
        lunit.assertEquals(_bat,'BA2')
        lunit.assertEquals(_stat,3)
        data.rcvData('ADACK')
        _bat, _stat = bat.sndBATData()  --  send volt 27.5 of BA2
        lunit.assertEquals(_bat,'BA2')
        lunit.assertEquals(_stat,12)
        data.rcvData('ADACK')
        _bat, _, _stat = bat.evtBATxON('BA2')
        lunit.assertEquals(_bat,'BA2')
        lunit.assertEquals(_stat,13)
    end
-- end of table 'TestBattery'

Test030Rotary = {}
    -- Rotary switch changed
    function Test030Rotary:test010()
        lunit.assertEquals(data.rcvData('ADROT,2,1'),'ADROT,2,1')      -- from external 0 and 1 allowed
        lunit.assertEquals(rotary.getRotary(3),nil)                    -- internal 1 and 2 allowed
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal #1
        lunit.assertEquals(data.rcvData('ADROT,0,2',true),'ADROT,0,2') -- internal #2
        lunit.assertEquals(rotary.getRotary(1),2)
        lunit.assertEquals(rotary.getRotary(2),1)
    end
-- end of table 'TestInitialize'

os.exit( lunit.LuaUnit.run() )