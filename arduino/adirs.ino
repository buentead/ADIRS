/* -------------------------------------------------------------------
   adirs.ino
   -------------------------------------------------------------------
   Arduino scripts processing data received from the FSUIPC LUA script
   ADIRS.lua
*/

#include <Wire.h>
#include <LedDisplay.h>
#include <max7219.h>
#include <Servo.h>

// define rotary switches
#define DATA_POS 6
#define SYS_POS 4
#define ROTARY_NEWVAL 0
#define ROTARY_OLDVAL 1
#define ROTARY_DEBOUNCE 2
#define ROTARY_RANGE 3
#define ROTARY_ADDR 4
#define ROTARY_DEBOUNCE_MIN 2

// Protocol versions
const String  VERSION    = "1.00";         // expected protocol version from FlightSimulator
const String  TALKER     = "AD";
const String  MSGVER     = "VER";
const int     MAXADIRS   = 24;
const int     MAXINBUF   = 100;
const int     MAXDATA    = 5;
const int     MAXANALOG  = 1024;
const int     TIMEOUTACK = 2000;           // time in milliseconds to wait for ACK/NAK
const long    BAUDRATE   = 115200;
const long    TIMERESENDMAX = 1000000;    // timeout before version number is sent again (in milliseconds)
const uint8_t MAXBRIGHT = 6;
const byte    ACCUMIN = 0; // 10
const byte    ACCUMAX = 98; // 105
const byte    BRKLMIN = 3; // 15
const byte    BRKLMAX = 96; // 102
const byte    BRKRMIN = 103; // 111
const byte    BRKRMAX = 8; // 24

// Dot matrix display configuration
LedDisplay adirs = LedDisplay(2, 3, 4, 5, 6, MAXADIRS);

// Define 8-digit display configuration for battery voltage
MAX7219 bat;

// Servo's of Triple Gauge
Servo servoAccu;
Servo servoBrkL;
Servo servoBrkR;

// Global variables
unsigned long gTimeResend = 0;      // time when version is being sent (again)
unsigned long gTimeHeartbeat = 0;   // timout to resend heartbeat
unsigned long gWaitForACK = 0;      // timer to wait for ACK/NAK
String  gSerialInput   = "";        // used to read serial data
String  gData[MAXDATA];             // ring buffer for commands received
String  gLCDRowNew     = "";        // Dot matrix display row to be displayed
char    gLCDRowSet[MAXADIRS + 1];   // Dot matrix display row currently active
boolean gDataAvailable = false;     // true: new command(s) in ring buffer available
boolean gLcdOn         = true;
boolean gBatOn[2]      = {false,false};
boolean gStartCmd      = false;     // '$' received to indicate start of new command
byte    gDataSerial    = 0;         // gData array index used by serial input
byte    gDataExe       = 0;         // gData array index used by command processor (state 4)
int     gState         = 0;         // State machine
int     gBatVolt[2]    = {0,0};     // Actual battery voltage
int     gRotary[2][5]  = {{0,99,0,MAXANALOG / ((DATA_POS - 1) * 2),A0},{0,99,0,MAXANALOG / ((SYS_POS - 1) * 2),A1}};
int     gRotaryWait    = 0;         // indicates which rotary switch waits for ACK/NAK

/*
   SETUP board
*/
void setup() {
  gTimeHeartbeat = millis();
  gTimeResend = millis();
  adirs.begin();
  adirs.setBrightness(MAXBRIGHT);
  bat.Begin();
  bat.MAX7219_SetBrightness(MAXBRIGHT); // min: 0, max: 15

  // start serial port at 115,2kbps and wait for port to open
  Serial.begin(BAUDRATE);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB port only
  }
  Serial.setTimeout(1000);      // timeout at default 1 second
  gSerialInput.reserve(MAXINBUF);    // recerve max length of inbound data
  adirs.clear();
  adirs.setCursor(0);
  adirs.print("Built by Adrian Buenter");
  servoAccu.attach(7);
  servoAccu.write(ACCUMIN);
  servoBrkL.attach(8);
  servoBrkL.write(BRKLMIN);
  servoBrkR.attach(9);
  servoBrkR.write(BRKRMIN);
  delay(4000);
  adirs.clear();
  gLCDRowSet[MAXADIRS + 1] = 0;
}

/*
   Main loop
*/
void loop() {
  byte idx;
  // Evaluate new state
  gState = fStateMachine(gState,gTimeResend,gTimeHeartbeat,gDataAvailable);
  // process data
  switch (gState) {
    case 0: // Ready to send Heartbeat with version
      gState = sendHeartbeat();
      break;
    case 2:
      idx = (gDataExe + 1) % MAXDATA;
      gState = checkProtocolVersion(VERSION,gData[idx]);
      gDataExe = idx;
      gDataAvailable = (gDataSerial != gDataExe);
      break;
    case 3:
      // Process rotary switch positions
      gState = fRotaryRead(gState);
      break;
    case 4:
      idx = (gDataExe + 1) % MAXDATA;
      if (gData[idx].substring(0,7) == "$FSLCD,") {
        fFSROW(gData[idx]);
      }
      else if (gData[idx].substring(0,7) == "$FSBA1,") {
        fFSBAx(0,gData[idx]);
      }
      else if (gData[idx].substring(0,7) == "$FSBA2,") {
        fFSBAx(1,gData[idx]);
      }
      else if (gData[idx].substring(0,6) == "$FSON,") {
        fFSON(gData[idx]);
      }
      else if (gData[idx].substring(0,7) == "$FSOFF,") {
        fFSOFF(gData[idx]);
      }
      else if (gData[idx].substring(0,7) == "$FSTGV,") {
        fFSTGV(gData[idx]);
      }
      else {
        Serial.println("$ADNAK");
      }
      gDataExe = idx;
      gDataAvailable = (gDataSerial != gDataExe);
      gTimeResend = setTimeResend(gTimeResend); // reset heartbeat timer
      // Process rotary switch positions
      gState = fRotaryRead(gState);
      break;
    case 5:
      if (gDataAvailable) {
        idx = (gDataExe + 1) % MAXDATA;
        gState = fRotaryACK(gState,gData[idx]);
        gDataExe = idx;
        gDataAvailable = (gDataSerial != gDataExe);
        gTimeResend = setTimeResend(gTimeResend); // reset heartbeat timer
      }
      break;
  }
}

/*
   Serial data received
   SerialEvent occurs when new data comes in on serial RX. This
   routine runs between each time loop() was executed
*/
void serialEvent() {
  char inChar;
  boolean waitForCRLF = true;
  while (Serial.available() && waitForCRLF) {
    inChar = (char)Serial.read();
    switch (inChar) {
      case '$':
        gSerialInput = inChar;
        gStartCmd = true;
        break;
      case '\r':
        waitForCRLF = fAddCommand(waitForCRLF);
        break;
      case '\n':
        waitForCRLF = fAddCommand(waitForCRLF);
        break;
      case '@':
        waitForCRLF = fAddCommand(waitForCRLF);
        break;
      default:
        if (gSerialInput.length() != 0 && gSerialInput.length() < MAXINBUF) {
          gSerialInput += inChar;
        }
        else if (gSerialInput.length() != 0) { // length overflow
          gSerialInput = "";
        }
    } // switch case
  } // while
}

/*
   Functions
*/

// Insert new command received
boolean fAddCommand(boolean pWaitForCRLF){
  byte    idx   = (gDataSerial + 1) % MAXDATA;
  boolean rFlag = pWaitForCRLF;
  if (gStartCmd) {
    gData[idx] = gSerialInput;
    gSerialInput = "";
    gStartCmd = false;
    rFlag = false;
    gDataSerial = idx;
    gDataAvailable = true;
  }
  return rFlag;
}

// Read position of rotary switches
int fRotaryRead(int state){
  int newState = state;
  int val = 0;
  char data[40];
  // read rotary of 'DATA' and 'SYS'
  for (int i=0; i <= 1; i++){
    val = analogRead(gRotary[i][ROTARY_ADDR]);
    // Calculate new rotary position based on analog value
    gRotary[i][ROTARY_NEWVAL] = (((10 * val) / (2 * gRotary[i][ROTARY_RANGE])) + 5) / 10;
    if (gRotary[i][ROTARY_NEWVAL] != gRotary[i][ROTARY_OLDVAL]){
      (gRotary[i][ROTARY_DEBOUNCE])++;
      if (gRotary[i][ROTARY_DEBOUNCE] > ROTARY_DEBOUNCE_MIN){
        // new position set
        sprintf(data, "$ADROT,%d,%d", i, gRotary[i][ROTARY_NEWVAL]);
        Serial.println(data);
        gWaitForACK = millis() + TIMEOUTACK;
        gRotaryWait = i;
        newState = 5;
        break;
      }
    } else {
      // reset debounce counter
      gRotary[i][ROTARY_DEBOUNCE] = 0;
    }
  }
  return newState;
}

// Wait for rotary switches ACK/NAK
int fRotaryACK(int state, const String& pSerialInput){
  int newState = state;
  if (pSerialInput.substring(0,6) == "$FSACK") {
    gRotary[gRotaryWait][ROTARY_OLDVAL]   = gRotary[gRotaryWait][ROTARY_NEWVAL];
    gRotary[gRotaryWait][ROTARY_DEBOUNCE] = 0;
    gRotaryWait = 0;
    gWaitForACK = 0;
    newState    = 3;
  }
  else if (pSerialInput.substring(0,6) == "$FSACK") {
    gRotaryWait = 0;
    gWaitForACK = 0;
    newState    = 3;
  }
  return newState;
}

// Update State Machine
int fStateMachine(int state, unsigned long timeResend, unsigned long timeHeartbeat, boolean dataAvailable){
  int newState = state;
  switch (state) {
    case 0: // send heartbeat with version
      // no action required
      break;
    case 1: // wait for FS protocol version
      if (dataAvailable){
        newState = 2;   // FS protocol version to be verified
      }
      else if (isTimeout(timeHeartbeat)){
        newState = 0;   // send heartbeat with version
      }
      break;
    case 2: // check FS comm version
      newState = 1;     // in case state 2 wasn't successfully processed
      break;
    case 3: // FlightSim connected
      if (dataAvailable){
        newState = 4;   // read command
      }
      else if (isTimeout(timeResend)){
        newState = 0;
        gRotary[0][ROTARY_OLDVAL] = 99;
        gRotary[1][ROTARY_OLDVAL] = 99;
      }
      break;
    case 4: // process command(s) received
      if (!dataAvailable){
        newState = 3;
      }
      break;
    case 5: // wait for ACK/NAK
      if (gWaitForACK < millis()) {
        // waiting for ACK/NAK timed out
        gWaitForACK = 0;
        newState = 3;
      }
      break;
  }
  return newState;
}

// receive protocol version
int checkProtocolVersion(String protVers, const String& pSerialInput) {
  int newState = 0;
  if (pSerialInput.substring(0,7) == "$FSVER," && pSerialInput.substring(7,7 + protVers.length()) == protVers){
    Serial.println("$ADACK");
    gTimeResend = setTimeResend(gTimeResend); // reset heartbeat timer
    newState = 3;
  }
  else {
    Serial.println("$ADNACK");
  }
  return newState;
}

// Send heartbeat when x-time passed
int sendHeartbeat(){
  int newState = 1;
  Serial.println("$" + TALKER + MSGVER + "," + VERSION);
  gTimeHeartbeat = setTimeResend(gTimeHeartbeat);
  return newState;
}

// Set next timeout value
unsigned long setTimeResend(unsigned long oldTimeResend) {
  unsigned long timeResend;                   // time to resend version number
  timeResend = millis() + TIMERESENDMAX; // set next time period
  if (oldTimeResend > timeResend) {
    // Arduino is running more than 50 days (overflow of unsigned long), reset counter
    while (millis() > TIMERESENDMAX) {        // wait until actual clock also overflows, should be within <= timeResendMax
      delay(200);
    }
    timeResend = millis() + TIMERESENDMAX;
  }
  return timeResend;
}


// Verify if timout occurs
boolean isTimeout(unsigned long oldTimeResend) {
  boolean rc = false;
  if (oldTimeResend <= millis()) {
    rc = true;
  }
  else if (millis() < 5000 && oldTimeResend > (5000 + TIMERESENDMAX)) { // if reported milliseconds is < 5 seconds and board not just started (running > 5 seconds), probably an overflow occured (~50 days)
    rc = true;
  }
  //Serial.println("isTimeout: " + String(rc) + ", old:" +String(oldTimeResend) + ", act:" +String(millis()));
  return rc;
}

/*
   PROCESS COMMANDS
*/

// $FSLCD - set dot matrix text
void fFSROW(const String& pSerialInput) {
  String row = pSerialInput.substring(7);
  gLCDRowNew = row.substring(0,MAXADIRS);
  displayADIRS();
  Serial.println("$ADACK");
}
// write text to dot matrix display
void displayADIRS(){
  // Sending all 24 characters (e.g. adirs.print("string")) takes about 265ms - 270ms.
  // To ensure fast update cycles, only characters that changed will be sent to the display.
  byte strLen = gLCDRowNew.length();
  if (gLcdOn){
    // process buffer and send character if changed
    for (int i = 0; i < MAXADIRS; i++){
      if (i < strLen){
        // compare old buffer with new buffer
        if (gLCDRowSet[i] != gLCDRowNew[i]){
          gLCDRowSet[i] = gLCDRowNew[i];
          adirs.setCursor(i);
          adirs.write(gLCDRowSet[i]);
        }
      }
      else {
        // new buffer shorter than max buffer -> fill with space
        if (gLCDRowSet[i] != ' '){
          gLCDRowSet[i] = ' ';
          adirs.setCursor(i);
          adirs.write(gLCDRowSet[i]);
        }
      }
    }
  }
}

// $FSBAx - set 4 digit display
void fFSBAx(int batIdx, const String& pSerialInput){
  if (pSerialInput.length() == 11){
    gBatVolt[batIdx] = pSerialInput.substring(7,11).toInt();
    displayVolt();
    Serial.println("$ADACK");
  }
  else {
    Serial.println("$ADNACK");
  }
}
// write voltage to 7-seg, 8 digit, serial display
void displayVolt(){
  char data[17];          // 8 digits, 8 decimal points, termination 0x00
  char batx[2][9];        // 4 digits, 4 decimal places, termination 0x00
  // process each BAT
  for (int i=0; i <= 1; i++){
    if (gBatOn[i]){
      sprintf(batx[i], "%3d.%d", gBatVolt[i]/10, gBatVolt[i]%10);
    }
    else {
      batx[i][0] = 0;     // empty string
    }
  }
  sprintf(data, "%4s%4s", batx[0], batx[1]);
  bat.DisplayText(data, 1);
}

// Displays on
void fFSON(const String& pSerialInput){
  if (pSerialInput.substring(6,9) == "LCD"){
    gLcdOn = true;
    displayADIRS();
  }
  else if (pSerialInput.substring(6,9) == "BA1"){
    gBatOn[0] = true;
    displayVolt();
  }
  else if (pSerialInput.substring(6,9) == "BA2"){
    gBatOn[1] = true;
    displayVolt();
  }
  Serial.println("$ADACK");
}

// Displays off
void fFSOFF(const String& pSerialInput){
  if (pSerialInput.substring(7,10) == "LCD"){
    gLcdOn = false;
    adirs.clear();
    for (int i = 0; i < MAXADIRS; i++){
      gLCDRowSet[i] = ' ';
    }
  }
  else if (pSerialInput.substring(7,10) == "BA1"){
    gBatOn[0] = false;
    displayVolt();
  }
  else if (pSerialInput.substring(7,10) == "BA2"){
    gBatOn[1] = false;
    displayVolt();
  }
  Serial.println("$ADACK");
}

// Set Triple Gauge Servo's
void fFSTGV(const String& pSerialInput) {
  byte i1 = 0;
  byte i2 = 0;
  int  tgv = 0;

  i1 = pSerialInput.indexOf(',', 7);
  tgv = (pSerialInput.substring(7, i1)).toInt();
  servoAccu.write(map(tgv,0,255,ACCUMIN,ACCUMAX));
  i1++;
  i2 = pSerialInput.indexOf(',', i1);
  tgv = (pSerialInput.substring(i1, i2)).toInt();
  servoBrkL.write(map(tgv,0,255,BRKLMIN,BRKLMAX));
  i2++;
  tgv = (pSerialInput.substring(i2)).toInt();
  servoBrkR.write(map(tgv,0,255,BRKRMIN,BRKRMAX));
  Serial.println("$ADACK");
}