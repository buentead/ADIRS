----------------------------------------------------------------------
-- unitTesting.lua
----------------------------------------------------------------------
-- Testing all functions of the modules called by the main FSUIPC scripts ADIRS.lua

lunit     = require('luaunit')
bat       = require('lib/battery')
rotary    = require('lib/rotary')
adirs     = require('lib/adirsDisplay')
tg        = require('lib/tripleGauge')
handshake = require('lib/handshake')
data      = require('lib/sendReceiveData')

bat.setDataCom(data)                     -- set instance to send data
rotary.setDataCom(data)                  -- set instance to send data
adirs.setDataCom(data)                   -- set instance to send data
tg.setDataCom(data)                      -- set instance to send data
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
        lunit.assertEquals(data.rcvData('ADROT,5,1'),'ADROT,5,1')      -- from external 0 to 4 allowed
        lunit.assertEquals(rotary.getRotary(6),nil)                    -- internal 1 and 2 allowed
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(data.rcvData('ADROT,0,2',true),'ADROT,0,2') -- internal DATA-PPOS
        lunit.assertEquals(data.rcvData('ADROT,2,1',true),'ADROT,2,1') -- internal IR1
        lunit.assertEquals(data.rcvData('ADROT,3,1',true),'ADROT,3,1') -- internal IR3
        lunit.assertEquals(data.rcvData('ADROT,4,1',true),'ADROT,4,1') -- internal IR2
        lunit.assertEquals(rotary.getRotary(1),3)
        lunit.assertEquals(rotary.getRotary(2),2)
        lunit.assertEquals(rotary.getRotary(3),2)
        lunit.assertEquals(rotary.getRotary(4),2)
        lunit.assertEquals(rotary.getRotary(5),2)
        lunit.assertEquals(adirs.rcvIRAligned('IR1', true),2)           -- IR1 aligned
        lunit.assertEquals(adirs.rcvIRAligned('IR2', true),2)           -- IR2 aligned
        lunit.assertEquals(adirs.rcvIRAligned('IR3', true),2)           -- IR3 aligned
        lunit.assertEquals(adirs.rcvRotaryPosDisplay(rotary.getRotary(1),rotary.getRotary(2)),2)  -- check status 'pending ADIRS update'
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
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,STS - NONE\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        data.rcvData('ADNAK')
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,STS - NONE\r\n')
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
    function Test040Adirs:test100()
        lunit.assertEquals(data.rcvData('ADROT,0,1',true),'ADROT,0,1') -- internal DATA-TKGS
        lunit.assertEquals(data.rcvData('ADROT,1,0',true),'ADROT,1,0') -- internal SYS-OFF
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,TKGS\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtTrueTrack(180),'TK 180`   0KTS')
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,TK 180`   0KTS\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtGroundSpeed(250),'TK 180` 250KTS')
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,TK 180` 250KTS\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(data.rcvData('ADROT,0,0',true),'ADROT,0,0') -- internal DATA-TEST
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,888888888888888888888888\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtTrueTrack(90),'TK 090` 250KTS')
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(data.rcvData('ADROT,0,1',true),'ADROT,0,1') -- internal DATA-TKGS
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,TK 090` 250KTS\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
    end

    function Test040Adirs:test110()
        lunit.assertEquals(data.rcvData('ADROT,0,2',true),'ADROT,0,2') -- internal DATA-PPOS
        lunit.assertEquals(data.rcvData('ADROT,1,0',true),'ADROT,1,0') -- internal SYS-OFF
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,PPOS\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtPPos('LAT', 'N', 12, 3.4),"N 12` 3.40'  E000` 0.00'")
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),"$FSLCD,N 12` 3.40'  E000` 0.00'\r\n")
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtPPos('LON', 'W', 1, 23.45),"N 12` 3.40'  W001`23.45'")
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),"$FSLCD,N 12` 3.40'  W001`23.45'\r\n")
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(data.rcvData('ADROT,0,0',true),'ADROT,0,0') -- internal DATA-TEST
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,888888888888888888888888\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtPPos('LAT', 'S', 123, 0.0),"S123` 0.00'  W001`23.45'")
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(data.rcvData('ADROT,0,2',true),'ADROT,0,2') -- internal DATA-TKGS
        lunit.assertEquals(adirs.sndADIRSInfo(),"$FSLCD,S123` 0.00'  W001`23.45'\r\n")
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
    end

    function Test040Adirs:test120()
        lunit.assertEquals(data.rcvData('ADROT,0,3',true),'ADROT,0,3') -- internal DATA-PPOS
        lunit.assertEquals(data.rcvData('ADROT,1,0',true),'ADROT,1,0') -- internal SYS-OFF
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,WIND\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtWindKn(2),"WIND   2KTS / 000`")
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),"$FSLCD,WIND   2KTS / 000`\r\n")
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtWindDeg(213),"WIND   2KTS / 213`")
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),"$FSLCD,WIND   2KTS / 213`\r\n")
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(data.rcvData('ADROT,0,0',true),'ADROT,0,0') -- internal DATA-TEST
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,888888888888888888888888\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtWindKn(425),"WIND 425KTS / 213`")
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(data.rcvData('ADROT,0,3',true),'ADROT,0,3') -- internal DATA-PPOS
        lunit.assertEquals(adirs.sndADIRSInfo(),"$FSLCD,WIND 425KTS / 213`\r\n")
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
    end

    function Test040Adirs:test130()
        lunit.assertEquals(data.rcvData('ADROT,0,4',true),'ADROT,0,4') -- internal DATA-HDG
        lunit.assertEquals(data.rcvData('ADROT,1,0',true),'ADROT,1,0') -- internal SYS-OFF
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,HDG\r\n')
        lunit.assertEquals(adirs.getStatus(),4)                        -- Status 4 - wait for 'ACK'
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtHeading(1),"HEADING 001`")
        lunit.assertEquals(adirs.evtHeading(0),"HEADING 000`")
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),"$FSLCD,HEADING 000`\r\n")
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtHeading(359),"HEADING 359`")
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),"$FSLCD,HEADING 359`\r\n")
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(data.rcvData('ADROT,0,0',true),'ADROT,0,0') -- internal DATA-TEST
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,888888888888888888888888\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(adirs.evtHeading(180),"HEADING 180`")
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
        lunit.assertEquals(data.rcvData('ADROT,0,4',true),'ADROT,0,4') -- internal DATA-HDG
        lunit.assertEquals(adirs.sndADIRSInfo(),"$FSLCD,HEADING 180`\r\n")
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
    end

    function Test040Adirs:test140()
        lunit.assertEquals(data.rcvData('ADROT,0,4',true),'ADROT,0,4') -- internal DATA-HDG
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(data.rcvData('ADROT,1,0',true),'ADROT,1,0') -- internal SYS-OFF
        lunit.assertEquals(adirs.getStatus(),3)                        -- Status 3 - pending ADIRS OFF
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD, \r\n')
        lunit.assertEquals(adirs.getStatus(),7)                        -- Status 7 - wait for 'ACK' of display OFF
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),9)                        -- Status 9 - Display is OFF
        lunit.assertEquals(adirs.evtHeading(90),"HEADING 090`")
        lunit.assertEquals(adirs.getStatus(),9)                        -- Status 9 - Display remains OFF
        lunit.assertEquals(adirs.sndADIRSInfo(),nil)
        lunit.assertEquals(adirs.getStatus(),9)                        -- Status 9 - Display remains OFF
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),"$FSLCD,HEADING 090`\r\n")
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS display updated
    end
-- end of table 'Test040Adirs'

Test050Servo = {}
    -- Servo updates
    function Test050Servo:test010()
        lunit.assertEquals(tg.rcvTGValue('ACCU',1),'1,0,0')
        lunit.assertEquals(tg.getStatus(),1)
        lunit.assertEquals(tg.sndTGValues(),'$FSTGV,1,0,0\r\n')
        lunit.assertEquals(tg.getStatus(),2)
        data.rcvData('ADACK')
        lunit.assertEquals(tg.getStatus(),4)
    end
    function Test050Servo:test020()
        lunit.assertEquals(tg.rcvTGValue('LEFT',2),'1,2,0')
        lunit.assertEquals(tg.getStatus(),1)
        lunit.assertEquals(tg.sndTGValues(),'$FSTGV,1,2,0\r\n')
        lunit.assertEquals(tg.getStatus(),2)
        lunit.assertEquals(tg.rcvTGValue('RIGHT',3),'1,2,3')
        lunit.assertEquals(tg.getStatus(),3)
        lunit.assertEquals(tg.sndTGValues(),nil)
        data.rcvData('ADACK')
        lunit.assertEquals(tg.getStatus(),1)
        lunit.assertEquals(tg.sndTGValues(),'$FSTGV,1,2,3\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(tg.getStatus(),4)
        lunit.assertEquals(tg.sndTGValues(),nil)
    end
    function Test050Servo:test030()
        lunit.assertEquals(tg.rcvTGValue('ACCU',200),'200,2,3')
        lunit.assertEquals(tg.rcvTGValue('LEFT',255),'200,255,3')
        lunit.assertEquals(tg.rcvTGValue('RIGHT',254),'200,255,254')
        lunit.assertEquals(tg.getStatus(),1)
        lunit.assertEquals(tg.sndTGValues(),'$FSTGV,200,255,254\r\n')
        lunit.assertEquals(tg.getStatus(),2)
        lunit.assertEquals(tg.sndTGValues(),nil)
        data.rcvData('ADACK')
        lunit.assertEquals(tg.getStatus(),4)
        lunit.assertEquals(tg.rcvTGValue('LEFT',0),'200,0,254')
        lunit.assertEquals(tg.rcvTGValue('RIGHT',0),'200,0,0')
        lunit.assertEquals(tg.getStatus(),1)
        lunit.assertEquals(tg.sndTGValues(),'$FSTGV,200,0,0\r\n')
        lunit.assertEquals(tg.getStatus(),2)
        lunit.assertEquals(tg.sndTGValues(),nil)
        lunit.assertEquals(tg.getStatus(),2)
        data.rcvData('ADNAK')
        lunit.assertEquals(tg.getStatus(),1)
        data.rcvData('ADACK')
        lunit.assertEquals(tg.getStatus(),1)
        lunit.assertEquals(tg.sndTGValues(),'$FSTGV,200,0,0\r\n')
        lunit.assertEquals(tg.getStatus(),2)
        data.rcvData('ADACK')
        lunit.assertEquals(tg.getStatus(),4)
        lunit.assertEquals(tg.sndTGValues(),nil)
    end
-- end of table 'Test050Servo'

Test060IRU = {}
    function Test060IRU:test010()   -- Set SYS to IR1, Switch IR1 OFF
        lunit.assertEquals(data.rcvData('ADROT,0,4',true),'ADROT,0,4') -- internal DATA-HDG
        lunit.assertEquals(data.rcvData('ADROT,1,1',true),'ADROT,1,1') -- internal SYS-IR1
        lunit.assertEquals(data.rcvData('ADROT,2,0',true),'ADROT,2,0') -- internal IR1 to NAV
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        adirs.__setStatusIRU('IR1',1)
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD, \r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS up to date
    end
    function Test060IRU:test020()   -- New Heading but IR1 remains OFF
        lunit.assertEquals(adirs.evtHeading(91),"HEADING 091`")
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD, \r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS up to date
    end
    function Test060IRU:test030()   -- Switch IR1 to NAV (aligning)
        lunit.assertEquals(data.rcvData('ADROT,2,1',true),'ADROT,2,1') -- internal IR1 to NAV
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,HEADING --.-`     TTN 7\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS up to date
    end
    function Test060IRU:test040()   -- Switch IR1 OFF / NAV for fast alignment
        lunit.assertEquals(data.rcvData('ADROT,2,0',true),'ADROT,2,0') -- internal IR1 to NAV
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,REALN DESN 5 SEC\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS up to date
        lunit.assertEquals(data.rcvData('ADROT,2,1',true),'ADROT,2,1') -- internal IR1 to NAV
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,HEADING --.-`     TTN 1\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS up to date
    end
    function Test060IRU:test050()   -- IR1 is aligned
        lunit.assertEquals(adirs.rcvIRAligned('IR1', true),2)
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,HEADING 091`\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS up to date
    end
    function Test060IRU:test060()   -- Switch IR1 to ATT, DATA to PPOS
        lunit.assertEquals(data.rcvData('ADROT,2,2',true),'ADROT,2,2') -- internal IR1 to ATT
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(data.rcvData('ADROT,0,2',true),'ADROT,0,2') -- internal DATA to PPOS
        lunit.assertEquals(adirs.getStatus(),2)                        -- Status 2 - pending ADIRS update
        lunit.assertEquals(adirs.sndADIRSInfo(),'$FSLCD,------------------------\r\n')
        data.rcvData('ADACK')
        lunit.assertEquals(adirs.getStatus(),6)                        -- Status 6 - ADIRS up to date
    end

-- end of table 'Test060IRU'
os.exit( lunit.LuaUnit.run() )