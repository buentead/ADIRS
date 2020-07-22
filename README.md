# ADIRS, BAT, Triple Gauge
This project relates to an Airbus A320 home built cockpit. It covers the following instruments:
- Battery: BAT1 and BAT2 displays in the overhead panel
- ADIRS (Air Data Inertial Reference System): The display and the `DATA` and `SYS` rotary switches in the overhead panel.
- Triple Gauge: drives three servos of a triple gauge such as from [Skalarki electronics Ltd](https://www.skalarki-electronics.eu/onlineshop/product/42-tripple-gauge.html).

The full project documentation can be found [here](/docu/projectDocumentation.md).

## Scope of the project

### Battery Displays
The hardware (schematics, PCB, components) required to mount the battery display into an existing overhead panel.

### ADIRS Display and Rotary Switches
The hardware (schematics, PCB, components) required to mount the ADIRS display (24 characters) as well as the decoding of the two rotary switches using analogue inputs.

### Triple Gauge
No hardware components included.

### Arduino Script
The script required to control the above displays and instrument using an Arduino MEGA 2560.

### FSUIPC LUA Script
The LUA scripts which builds the interface between the Flight Simulator and the Arduino Board.