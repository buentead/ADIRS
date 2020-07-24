----------------------------------------------------------------------
-- unitTesting.lua
----------------------------------------------------------------------
-- Testing all functions of the modules called by the main FSUIPC scripts ADIRS.lua

lunit     = require('luaunit')
bat       = require('modules/lib/battery')
rotary    = require('modules/lib/rotary')
adirs     = require('modules/lib/adirsDisplay')
handshake = require('modules/lib/handshake')
data      = require('modules/lib/sendReceiveData')

bat.setDataCom(data)                     -- set instance to send data
rotary.setDataCom(data)                  -- set instance to send data
adirs.setDataCom(data)                   -- set instance to send data
handshake.setDataCom(data)               -- set instance to send data

Test010Handshake = {}
    -- establish connection
    local _msg  = ''
    local _init = false
    local _bat  = ''
    local _volt = ''
    local _stat  = 0
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
        bat.evtBATxON('BA2')                -- switch on BA2 display
        bat.evtBATxON('BA1')                -- no impact, as BA1 is already in state 11 (previous test200)
        _bat, _stat = bat.sndBATData()      -- will send volt 27.9 of BA1
        lunit.assertEquals(_bat,'BA1')
        lunit.assertEquals(_stat,12)
        data.rcvData('ADACK')
        _bat, _stat = bat.sndBATData()      -- will switch on BA1 display
        lunit.assertEquals(_bat,'BA2')
        lunit.assertEquals(_stat,3)
        data.rcvData('ADACK')
        _bat, _stat = bat.sndBATData()      --  send volt 27.5 of BA2
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
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(data.rcvData('ADROT,0,2',true),'ADROT,0,2') -- internal DATA-PPOS
        lunit.assertEquals(rotary.getRotary(1),3)
        lunit.assertEquals(rotary.getRotary(2),2)
        lunit.assertEquals(adirs.rcvRotaryPos(rotary.getRotary(1),rotary.getRotary(2)),2)  -- check status 'pending ADIRS update'
    end
-- end of table 'Test030Rotary'

Test040Adirs = {}
-- Rotary switch changed
    function Test040Adirs:test010()
        lunit.assertEquals(data.rcvData('ADROT,0,0',true),'ADROT,0,0') -- internal DATA-TEST
        lunit.assertEquals(data.rcvData('ADROT,1,0',true),'ADROT,1,0') -- internal SYS-OFF
        lunit.assertEquals(adirs.getStatus(),3)                        -- Status 3 - ADIRS display off
        lunit.assertEquals(data.rcvData('ADROT,0,0',true),'ADROT,0,0') -- internal DATA-TEST
        lunit.assertEquals(data.rcvData('ADROT,1,0',true),'ADROT,1,0') -- internal SYS-OFF
        lunit.assertEquals(adirs.getStatus(),3)                        -- Status 3 - ADIRS display off
    end
    function Test040Adirs:test020()
        lunit.assertEquals(data.rcvData('ADROT,0,0',true),'ADROT,0,0') -- internal DATA-TEST
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,888888888888888888888888\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADNAK')
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,888888888888888888888888\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
    end
    function Test040Adirs:test030()
        lunit.assertEquals(data.rcvData('ADROT,0,1',true),'ADROT,0,1') -- internal DATA-TKGS
        lunit.assertEquals(data.rcvData('ADROT,1,2',true),'ADROT,1,2') -- internal SYS-IR3
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,TKGS\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADNAK')
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,TKGS\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
    end
    function Test040Adirs:test040()
        lunit.assertEquals(data.rcvData('ADROT,0,2',true),'ADROT,0,2') -- internal DATA-PPOS
        lunit.assertEquals(data.rcvData('ADROT,1,3',true),'ADROT,1,3') -- internal SYS-IR2
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,PPOS\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADNAK')
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,PPOS\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
    end
    function Test040Adirs:test050()
        lunit.assertEquals(data.rcvData('ADROT,0,3',true),'ADROT,0,3') -- internal DATA-WIND
        lunit.assertEquals(data.rcvData('ADROT,1,2',true),'ADROT,1,2') -- internal SYS-IR3
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,WIND\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADNAK')
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,WIND\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
    end
    function Test040Adirs:test060()
        lunit.assertEquals(data.rcvData('ADROT,0,4',true),'ADROT,0,4') -- internal DATA-HDG
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,HDG\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADNAK')
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,HDG\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
    end
    function Test040Adirs:test060()
        lunit.assertEquals(data.rcvData('ADROT,0,5',true),'ADROT,0,5') -- internal DATA-STS
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,No Messages\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADNAK')
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,No Messages\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
    end
    function Test040Adirs:test070()
        lunit.assertEquals(data.rcvData('ADROT,0,2',true),'ADROT,0,2') -- internal DATA-PPOS
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,PPOS\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        lunit.assertEquals(data.rcvData('ADROT,0,1',true),'ADROT,0,1') -- internal DATA-TKGS
        lunit.assertEquals(adirs.getStatus(),5)                        -- Status 5 - Unexpected change received
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,TKGS\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
    end
-- end of table 'Test040Adirs'

os.exit( lunit.LuaUnit.run() )