# Editor for the Casio VZ10m synth circa 1990

<img src="https://github.com/TobiasVanDyk/Casio-VZ-DOS-Programs/blob/master/casiovz10m.jpg" width="600" height="221" />

```
MIDI.PAS: Use the UNITS : MIDI1.PAS and MIDI3.PAS 
 
Midi1 includes the file MIDI2.PAS         
Midi3 includes the file MIDI4.PAS  
```

Links:

https://groups.yahoo.com/neo/groups/CZsynth/info

http://www.synthzone.com/casio.htm     

### Upgrading with an internal 4MB RAM Card:
An Alliance Memory AS6C4008 55PCN SRAM Memory 4Mbit Static RAM chip was added to the Casio VZ10m as shown below. The process is also documented in AS6C4008-SRAM-Install.pdf.

Six banks of the RAM card can be selected via a slider switch that was mounted in the previous RAM slot on the front panel.

<img src="https://github.com/TobiasVanDyk/Casio-VZ-DOS-Programs/blob/master/ram1.jpg" width="1088" height="613" />

<img src="https://github.com/TobiasVanDyk/Casio-VZ-DOS-Programs/blob/master/ram2.jpg" width="1088" height="613" />

<img src="https://github.com/TobiasVanDyk/Casio-VZ-DOS-Programs/blob/master/ram3.jpg" width="1088" height="613" />

Unfortunately the only contruction notes i made was on the connections of the 40-pin Dtype ribbon cable connector:

<img src="https://github.com/TobiasVanDyk/Casio-VZ-DOS-Programs/blob/master/DConnector.jpg" width="600" height="1000" />

The RAM Card schematic:

<img src="https://github.com/TobiasVanDyk/Casio-VZ-DOS-Programs/blob/master/CasioRA500 RAMcard.jpg" width="751" height="576" />

#### To load each bank with its own set of patches put the slider switch in poistion 1 and then by using MidiOX:

* Load file for example Vzcard10.syx will have D3=Anna Strings
* Make sure both internal and card memory protect is off. sys exc = ENA
* Then use LOAD, MIDI, Press execute and then in MidiOX pres  send/receive sysex
* NB: THE SOUND Vzcard10.syx IS NOW LOADED IN THE INTERNAL MEMORY - MUST NOW COPY IT TO THE CARD!!!!
* DO that by pressing SAVE, CARD, Press execute
* Test by pressing Card button and check if D3 = Ana Strings

Now switch the slider to its next position and repeat 5 more times...
