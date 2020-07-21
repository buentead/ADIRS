# ADIRS, BAT, Triple Gauge
This project relates to an Airbus A320 home built cockpit. It covers the following instruments:
- Battery: BAT1 and BAT2 displays in the overhead panel
- ADIRS (Air Data Inertial Reference System): The display and the `DATA` and `SYS` rotary switches in the overhead panel.
- Triple Gauge: drives the three servos of a triple gauge such as from [Skalarki electronics Ltd](https://www.skalarki-electronics.eu/onlineshop/product/42-tripple-gauge.html).

## Prerequisites
In order to fully leverage this project, the following components must be in place:
- One of the two listed flight simulators: [PREPAR3D from Lockheed Martin](https://www.prepar3d.com/), or Microsoft Flight Simulator X
- A registered version of [FSUIPC from Pete & John Dowson's Software](http://www.fsuipc.com/)
- [A320 FMGS software from JeeHell](https://soarbywire.com/fmgs/), which replicates the real Airbus A320's Flight Management & Guidance System (FMGS) and main electronic instruments
- Arduino MEGA 2560 and the Arduino IDE
- Triple Gauge powered by 3 servos, or at least 3 servos to verify the correct positions of the needles.

## Scope of the project

### Battery Displays
The hardware (schematics, PCB, components) required to mount the battery display into an existing overhead panel.

### ADIRS Display and Rotary Switches
The hardware (schematics, PCB, components) required to mount the ADIRS display (24 characters) as well as the decoding of the two rotary switches using analogue inputs.

### Triple Gauge
No hardware components included.

### Arduino Script
The script required to control the above displays and instrument

### The LUA Script
The LUA scripts which builds the interface between the Flight Simulator and the Arduino Board.