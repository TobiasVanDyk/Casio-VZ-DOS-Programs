{ Midi2 }

CONST
        MidiPollRead = $030 ;
        MidiIntRead  = $031 ;
        MidiWrite    = $038 ;

     IOBasePort          =  $0220 ;  { Soundblaster Base Address           }
 {-------------------------------------------------------------------------}
 { DSP: 4 IO Ports (1) 226 hex WRITE  Reset DSP (write 1, 3uS, write 0)    }
 {                 (2) 22A hex READ   Read DSP Data                        }
 {                 (3) 22C hex READ   Read Buffer Status (D7=0 OK to write)}
 {                             WRITE  Write DSP Data                       }
 {                 (4) 22E hex READ   Read Data-Available (D7=1 Yes)       }
 {-------------------------------------------------------------------------}
     DSPResetPort        =  $0226 ;  { DSP Reset Port Address           }
     DSPReadDataPort     =  $022A ;  { DSP Read Data Port               }
     DSPWriteDataPort    =  $022C ;  { DSP Write Data                   }
     DSPWriteCommandPort =  $022C ;  { DSP Write Command                }
     DSPStatusPort       =  $022C ;  { DSP Read Buffer-status D7=0 OK   }
     DSPDataAvailPort    =  $022E ;  { DSP Read Data Available D7=1 yes }
     DSPAckIntPort       =  $022E ;  { Read to ACK INT                  }

      {--------------------------------------------------------}
      { DSP Midi Command : (3x hex x = 0 , 1, 8)               }
      {          3 Modes : (1) 30 hex Midi Read (POLLING)      }
      {                    (2) 31 hex Midi Read (INT driven)   }
      {                    (3) 38 Midi Write                   }
      { Bit3=1 WRITE  Bit3=0 READ Bit0=1 INT Bit0=0 Polling    }
      {--------------------------------------------------------}

IMPLEMENTATION

{-----------------------------------}
{ Convert Number to Hex String      }
{-----------------------------------}
FUNCTION DecToHex (VAR Number : WORD ) : Str10 ;

BEGIN
  IF Number > 255 THEN
  BEGIN
    DecToHex[1] :=  HexDigit [ HI (Number) DIV 16 ] ;
    DecToHex[2] :=  HexDigit [ HI (Number) MOD 16 ] ;
    DecToHex[3] :=  HexDigit [ LO (Number) DIV 16 ] ;
    DecToHex[4] :=  HexDigit [ LO (Number) MOD 16 ] ;
    DecToHex[0] :=  CHR (4)                         ; { Set Length = 4 }
  END ELSE
  BEGIN
    DecToHex[1] :=  HexDigit [ LO (Number) DIV 16 ] ;
    DecToHex[2] :=  HexDigit [ LO (Number) MOD 16 ] ;
    DecToHex[0] :=  CHR (2)                         ; { Set Length = 2 }
  END                                               ;

END ;
{-----------------------------------}
{ Convert Hex String to Number      }
{-----------------------------------}
FUNCTION HexToDec ( HexStr : Str10 ) : WORD ;

VAR
  Number                  : WORD    ;
  E                       : INTEGER ;

BEGIN
  HexStr := '$'+ HexStr               ;
  VAL (HexStr, Number, E)             ;
  IF E > 0 THEN Number := 0           ;
  HexToDec := Number                  ;
END ;

{-----------------------------}
{ Clear MainMenu Message Area }
{-----------------------------}
PROCEDURE ClearMainMenu ( First, Last : INTEGER )                     ;

CONST
  C1 = '                                                             ';

VAR
  i : INTEGER ;

BEGIN
  { Clear lines starting at Y=First , stop at Y=Last    }
  TEXTCOLOR (Yellow)                                    ;
  FOR i := First TO Last DO BEGIN
                              GOTOXY ( 10, i )          ;
                              WRITE  ( C1 )             ;
                            END                         ;
  GOTOXY ( 10, First )                                  ;
END                                                     ;

{------------------------------------}
{ Reset DSP                          }
{------------------------------------}
PROCEDURE ResetDSP ;

VAR
   Byte1, Byte2 : BYTE    ;
   n            : INTEGER ;

BEGIN
  n := 0                                            ;

  PORT [DSPResetPort] := 1                          ;
  DELAY (5)                                         ; { 3uS recommended }
  PORT [DSPResetPort] := 0                          ;

  REPEAT
    Byte2 := 0                                      ;
    DELAY (1)                                       ; { DSP Init = 100 uS }
    Byte1 := PORT [DSPDataAvailPort]                ; { Byte1 D7=1 OK     }
    IF Byte1 > 127 THEN
                   Byte2 := PORT [DSPReadDataPort]  ;
  UNTIL (Byte2 = $0AA) OR (n>1000)                  ; { 0AA = Reset OK    }

  IF Byte2 <> $0AA THEN WRITE ('Error in DSP Reset...') ;

END                                                 ; { DSPReset          }

{------------------------------}
{ Configure DSP for MIDI Mode  }
{------------------------------}
PROCEDURE ConfigureMidi ( DSPMidiCmd : BYTE ) ;

VAR
  Byte1 : BYTE  ;

BEGIN
  Byte1 := 255  ;

  REPEAT
    Byte1 := PORT [DSPStatusPort]          ;
  UNTIL Byte1 < 128                        ; { D7=0 Clear to write command }

  PORT [DSPWriteCommandPort] := DSPMidiCmd ; { Send Command                }

END                                                 ; { ConfigureMidi      }

{------------------------------}
{ Send MIDI Byte               }
{------------------------------}
PROCEDURE SendByte ( MidiByte : BYTE ) ;

VAR
  Byte1 : BYTE  ;

BEGIN
  Byte1 := 255  ;

  REPEAT
    Byte1 := PORT [DSPStatusPort]          ;
  UNTIL Byte1 < 128                        ; { D7=0 Clear to write the byte}

  PORT [DSPWriteDataPort] := MidiByte      ; { Send Byte                   }

END                                                 ; { SendByte           }

{------------------------------}
{ Receive a MIDI Byte          }
{------------------------------}
PROCEDURE GetByte  ;

VAR
  Byte1 : BYTE    ;
  n     : INTEGER ;

BEGIN
  Byte1     := 0   ;
  ReadByte  := 0   ;
  n         := 0   ;

  REPEAT
    n := n+1                                        ;
    Byte1 := PORT [DSPDataAvailPort]                ; { Byte1 D7=1 OK     }
  UNTIL (Byte1 > 127) OR (n>10000)                  ;

  IF Byte1 > 127 THEN
  BEGIN
    ReadByte := PORT [DSPReadDataPort]  ;
  END        ;

END                                                 ; { GetByte           }
{---------------------------------}
{ Calculate Patch checksum        }
{---------------------------------}
PROCEDURE DoCheckSum ( PatchNum, PatchChkSum : WORD      ;
                       HexCSum : Str10 ; Option : BYTE ) ;

CONST
  MagicNumber = 16000    ;
  H           = ' hex]'  ;

VAR
  i          : WORD ;
  ChkSum16   : WORD ;
  ChkSum7    : WORD ;
  AStr, BStr : Str10 ;

BEGIN
  {--------------------------------}
  { Calculate 16 bit CheckSum      }
  {--------------------------------}
  ChkSum16 := 0 ;
  IF UnitClass = 'P' THEN FOR i := 1 TO PatchSize-2 DO
                     ChkSum16 := ChkSum16+Patch^ [PatchNum].X [i];
  IF UnitClass = 'O' THEN FOR i := 1 TO OpMemSize-2 DO
                     ChkSum16 := ChkSum16+OpMem^ [PatchNum].X [i];
  AStr := DecToHex (ChkSum16) ;
  {--------------------------------}
  { Calculate 7 bit CheckSum       }
  {--------------------------------}
  ChkSum7 := MagicNumber - ChkSum16 ;         { 16000 = Magic Number }
  ChkSum7 := ChkSum7 AND 127        ;         { Leave only lower 7 bits }
  UnitChkSum := ChkSum7             ;
  BStr  := DecToHex (ChkSum7)       ;

  IF Option = 1 THEN
  BEGIN
    GOTOXY ( 10,19 )                                            ;
    WRITE ('Chksum: Send [', HexCSum:2, ']',
                 '  Receive [', AStr:4, '] [' , BStr:2, ']' )   ;
  END                                                           ;

END ;

{-----------------------------------------}
{ Display Dump Info                       }
{-----------------------------------------}
PROCEDURE DoDump ;

CONST
D1=' 旼컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴커';
D2=' � HexDump  Current Patch : 12 of 64 Name : 012345678912                  �';
D3=' 쳐컴컴컴컴컫컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴캑';
D4=' � Location � 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 �';
D5=' 쳐컴컴컴컴컵컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴캑';
D6=' �          �                                                             �';
D7=' 쳐컴컴컴컴컨컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴캑';
D8=' � [PgDwn-PgUp] Page Down-Up  [End-Home]  [Esc] Quit  [RETURN] Edit Mode  �';
D9=' 읕컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴켸';
     PosX: ARRAY [0..19] OF BYTE =
           (15,18,21,24,27,30,33,36,39,42,45,48,51,54,57,60,63,66,69,72) ;
     PosY: ARRAY [0..16] OF BYTE =
           (06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22) ;

VAR
  i, k, n, m,p  : WORD  ;
  HexNum        : WORD  ;
  AStr          : Str10 ;
  Key1, Key2    : CHAR  ;
  PatchNum      : BYTE  ;
  PosXY         : ARRAY [0..340,0..1] OF BYTE ; { 340 Hex Area Position XY }
  MaxRow        : BYTE  ;
  LastRow       : WORD  ;
  MaxSize       : WORD  ;

{---------------------------------------}
PROCEDURE EditHexDump ( PatchNum : BYTE ) ;

VAR
  KeyB             : CHAR      ;
  xy, c, m         : INTEGER   ;
  Change           : BOOLEAN   ;
  HexStr           : Str10     ;
  Number           : BYTE      ;
  Start            : WORD      ;
  N                : WORD      ;

BEGIN
    N := MaxRow * 20                ;
    TEXTCOLOR      (Red)            ;
    TEXTBACKGROUND (Green)          ;
    xy := 0                         ;
    Change := FALSE                 ;

    GOTOXY ( 3, 24) ; WRITE
 (' EDIT MODE: [Enter] [End-Home] [Up-Down-Left-RightArr] Value [00-FF]  ') ;

    REPEAT
      GOTOXY ( PosXY [xy,0], PosXY [xy,1] )  ;
      HexStr[1] := UPCASE (READKEY) ;
      CASE HexStr[1] OF
              '0'..'9' ,
              'A'..'F' : BEGIN
                            WRITE (HexStr[1])                        ;
                            REPEAT HexStr[2] := UPCASE (READKEY)     ;
                            UNTIL ( HexStr[2] IN HexX )              ;
                            WRITE (HexStr[2])                        ;
                            HexStr[0] := CHR (2)                     ;
                            Number := HexToDec (HexStr)              ;
                            IF (Number=0) THEN WRITE (#8#8,'..')     ;

                            IF UnitClass = 'P' THEN
                               Patch^ [PatchNum].X [xy] := Number       ;
                            IF UnitClass = 'O' THEN
                               OpMem^ [PatchNum].X [xy] := Number       ;

                            IF NOT Change THEN
                            BEGIN
                              GOTOXY ( PosXY[MaxSize-1,0],
                                       PosXY[MaxSize-1,1] )          ;
                              WRITE  ( '**' )                        ;
                              Change := TRUE                         ;
                            END                                      ;
                            IF (UnitClass='P')AND(xy<335)AND(xy>322) THEN
                            BEGIN
                              GOTOXY ( 45 + (xy - 322) , 2 )         ;
                              WRITE  ( CHAR (Number) )               ;
                            END                                      ;
                            IF (UnitClass='O')AND(xy<14)AND(xy>1) THEN
                            BEGIN
                              GOTOXY ( 45 + (xy - 2) , 2 )           ;
                              WRITE  ( CHAR (Number) )               ;
                            END                                      ;
                            INC (xy)                                 ;
                         END                                         ;
              #00: BEGIN
                     KeyB := READKEY ;     { 2 code for special keys }
                     CASE KeyB OF
                          #71 : { Home        } xy := 0              ;
                          #79 : { End         } xy := MaxSize-1      ;
                          #72 : { Up Arrow    } IF xy < 20 THEN
                                  xy := xy + N  ELSE xy := xy - 20   ;
                          #80 : { Down Arrow  } IF xy > LastRow THEN
                                  xy := xy - N  ELSE xy := xy + 20   ;
                          #75 : { Left Arrow  } xy := xy - 1         ;
                          #77 : { Right Arrow } xy := xy + 1         ;
                      END          ; { Case KeyB                     }

                   END   ; { Case HexStr[1] = #0 }
          #27,#13: BEGIN
                     TEXTCOLOR (Yellow)    ;
                     TEXTBACKGROUND (Blue) ;
                     Exit ;
                   END                 ;
          END    ;         { Case HexStr[1]      }

          IF xy <  0   THEN xy := 0   ;
          IF xy >= MaxSize-1 THEN xy := MaxSize-1 ;

   UNTIL HexStr[1] = #27 ;

   END  ;

{-----------------------------------------}
BEGIN

   FOR i := 0 TO 16 DO
            FOR n := 0 TO 19 DO
                PosXY [ n+i*20, 0 ] := PosX [n] ;

   FOR i := 0 TO 16 DO
            FOR n := 0 TO 19 DO
                PosXY [ n+i*20, 1 ] := PosY [i] ;

  WINDOW (1,1,80,25 ) ; CLRSCR ;
  TEXTCOLOR ( Yellow )         ;

  p        := 0 ;
  PatchNum := 1 ;

  IF UnitClass = 'P' THEN BEGIN
                            MaxRow  := 16      ; { 17*20 = 340 }
                            LastRow := 319     ;
                            MaxSize := 338     ;
                            UnitName:= 'Patch' ;
                          END                  ;

  IF UnitClass = 'O' THEN BEGIN
                            MaxRow  := 5       ; {  6*20 = 120 }
                            LastRow := 99      ;
                            MaxSize := 102     ;
                            UnitName:= 'OpMem' ;
                          END                  ;

  WRITE ( D1,NL,D2,NL,D3,NL,D4,NL,D5,NL )   ;
  FOR i := 0 TO 16 DO WRITE ( D6,NL )       ;
  WRITE ( D7,NL,D8,NL,D9 )                  ;
  TEXTCOLOR (White)                         ;
  GOTOXY ( 21,2 )                           ;
  WRITE  ( UnitName )                       ;

  REPEAT

  DoCheckSum ( PatchNum, 0, ' ', 0 )                             ;
  IF UnitClass = 'P' THEN Patch^[PatchNum].PChkSum := UnitChkSum    ;
  IF UnitClass = 'O' THEN OpMem^[PatchNum].OChkSum := UnitChkSum    ;

    FOR i := 0 TO MaxRow DO
    BEGIN

       GOTOXY ( 7, 6+i   )           ;
       WRITE  ( i*20+p:5 )           ;

       FOR n := 0 TO 19 DO
       BEGIN

         GOTOXY ( 15+3*n, 6+i )                                  ;
         k := n + (i*20)                                         ;

         IF UnitClass = 'P' THEN HexNum := Patch^[PatchNum].X [ k ] ;
         IF UnitClass = 'O' THEN HexNum := OpMem^[PatchNum].X [ k ] ;

         AStr := DecToHex (HexNum)                               ;
         IF HexNum < 16 THEN DELETE (Astr, 1, 1)                 ;
         IF ( k < MaxSize ) THEN IF (HexNum <> 0) THEN
              WRITE (AStr:2, ' ' ) ELSE WRITE  ('..', ' ' )      ;
       END                                                       ;
    END                                                          ;

    GOTOXY ( 29,2 ) ; WRITE ( PatchNum:2,' of ', UnitCount:2 )  ;

    GOTOXY ( 45,2 ) ;
    IF UnitClass = 'P' THEN WRITE ( Patch^[PatchNum].PName:12       )  ;
    IF UnitClass = 'O' THEN WRITE ( OpMem^[PatchNum].OName:12       )  ;

    Key1 := UPCASE (READKEY)                                     ;
    IF Key1 = #13 THEN BEGIN
                       EditHexDump (PatchNum)          ; { Return}
                       GOTOXY ( 1, 24) ; WRITE (D8)              ;
                       TEXTCOLOR (White)                         ;
                       END                                       ;
    IF Key1 = #0 THEN BEGIN
                      Key2 := READKEY                            ;
                      IF Key2 = #73 THEN DEC(PatchNum)           ; { PgUp  }
                      IF Key2 = #81 THEN INC(PatchNum)           ; { PgDwn }
                      IF Key2 = #71 THEN PatchNum := 1           ; { Home  }
                      IF Key2 = #79 THEN PatchNum := UnitCount  ; { End   }
                      IF PatchNum = 0  THEN PatchNum := 1        ;
                      IF PatchNum = 65 THEN PatchNum := 64       ;
                      p := (PatchNum - 1) * MaxSize              ;
                      END                                        ;

  UNTIL (Key1 = 'Q') OR (Key1 = #27 )                            ;

END                                                              ;
{-----------------------------------}
{ Unit Manipulation in Bank         }
{-----------------------------------}
PROCEDURE BankEdit (Option : BYTE ) ;
VAR
  AStr, BStr, CStr    : Str10   ;
  P1, P2, P3          : BYTE    ;
  E, F, G, m, n, i    : INTEGER ;

BEGIN

  ClearMainMenu (18,22) ;
  {-------------------------------------}
  { Delete a Patch(es)                  }
  {-------------------------------------}
  IF Option = 0 THEN
  BEGIN
    IF UnitCount = 0 THEN
    BEGIN
      WRITE ('Nothing to Delete..... ') ;
      DELAY (500)                       ;
      EXIT                              ;
    END                                 ;
    REPEAT
      F  := 0               ;
      P2 := 1               ;
      UnitCountChange :=  1    ;
      PutLine ( 'Note : Enter range of patches as XX-YY   ' , 19 )     ;
      GOTOXY ( 10, 18 ) ; WRITE
      ( 'Enter Patch Number to DELETE ( 1 - ', UnitCount, ' ) : ' )    ;
      READLN ( AStr )                                                  ;
      n := POS ( '-', AStr )                                           ;
      IF n>0 THEN
      BEGIN
        BStr := COPY ( Astr, n+1, LENGTH (AStr) - n )                  ;
        VAL ( BStr, P2, F )                                            ;
        DELETE (AStr, n, LENGTH (AStr) - n + 1 )                       ;
      END                                                              ;
      VAL ( AStr, P1, E )                                              ;
      IF n > 0 THEN UnitCountChange := P2-P1+1                            ;
    UNTIL (E=0) AND (F=0) AND
          (P1<=UnitCount) AND (P1>0)  AND
          (P2<=UnitCount) AND (P2>0)                                  ;

    MovePatch ( P1, 1 )                                       ;
    UnitCount := UnitCount-UnitCountChange                     ;
    IF UnitSelect > UnitCount THEN UnitSelect := UnitCount;
  END     { Option = 0 }                                      ;
  {---------------------------------}
  { Move a Patch                    }
  {---------------------------------}
  IF Option = 1 THEN
  BEGIN
    IF UnitCount < 2 THEN
    BEGIN
      WRITE ('Nothing to Move..... ')   ;
      DELAY (500)                       ;
      EXIT                              ;
    END                                 ;
    REPEAT
      F  := 0                 ;
      P2 := 1                 ;
      ClearMainMenu ( 18,22 ) ; WRITE
      ( 'FORMAT : [ SOURCE-DESTINATION-COUNT ] each in (1-', UnitCount, ')');
      PutLine ('For Example : 5-10-3 Insert Units 5+6 at pos 10+11.', 19 )  ;
      PutLine ('Enter MOVE Parameters : ' , 20 )                            ;
      READLN ( AStr )                                                       ;

      n := POS ( '-', AStr )                                              ;
      BStr := COPY ( Astr, n+1, LENGTH (AStr) - n )      ;
      m := POS ('-', BStr  )                             ;
      CStr := COPY ( BStr, m+1, LENGTH (BStr) - m )      ;
      DELETE (BStr, m, LENGTH (BStr) - m + 1 )           ;
      DELETE (AStr, n, LENGTH (AStr) - n + 1 )           ;

      { Move Number } VAL ( CStr, P3, G )                ;
      { Destination } VAL ( BStr, P2, F )                ;
      { Origin      } VAL ( AStr, P1, E )                ;

    UNTIL (E=0) AND (F=0) AND (G=0)   AND
          (P1<=UnitCount) AND (P1>0)  AND
          (P2<=UnitCount) AND (P2>0)  AND (P1<>P2)       ;

    IF (P1>P2) THEN BEGIN
                      UnitCountChange := P3                   ;
                      MovePatch ( P2, 2 ) ;    { Move Down }
                      UnitCount := UnitCount + P3;
                      { Copy into empty space  }
                      FOR n := 0 TO P3-1 DO
                      BEGIN
                        IF UnitClass = 'P' THEN
                           Patch^[P2+n] := Patch^[P1+n+P3]    ;
                        IF UnitClass = 'O' THEN
                           OpMem^[P2+n] := OpMem^[P1+n+P3]    ;
                      END                                     ;
                      { Delete old patches }
                      MovePatch ( P1+P3, 1 )                  ;
                      UnitCount := UnitCount-P3               ;
                    END  ; { P1 > P2 }

    IF (P1<P2) THEN BEGIN
                      UnitCountChange := P2-P1 ;
                      { Save lower down patches first }

                      FOR i := 1 TO P3 DO
                      BEGIN
                        IF UnitClass = 'P' THEN
                           Patch^[UnitCount+i] := Patch^[P1+i-1] ;
                        IF UnitClass = 'O' THEN
                           OpMem^[UnitCount+i] := OpMem^[P1+1-1] ;
                      END                                        ;

                      FOR i := 1 TO UnitCountChange DO
                      BEGIN
                        IF UnitClass = 'P' THEN
                           Patch^[P1+i-1] := Patch^[P1+i+P3-1] ;
                        IF UnitClass = 'O' THEN
                           OpMem^[P1+i-1] := OpMem^[P1+i+P3-1] ;
                      END                                      ;

                      { Restore lower down patches }
                      FOR i := 1 TO P3 DO
                      BEGIN
                        IF UnitClass = 'P' THEN
                           Patch^[P2+i-1]:=Patch^[UnitCount+i];
                        IF UnitClass = 'O' THEN
                           OpMem^[P2+i-1]:=OpMem^[UnitCount+i];
                      END                                     ;
                      IF (P2-P1+P3) > UnitCount THEN
                         UnitCount := P2-P1+P3                ;
                    END ; { P1 < P2 }

  END     { Option = 1 }                                             ;
  {---------------------------------}
  { Copy a Patch                    }
  {---------------------------------}
  IF Option = 3 THEN
  BEGIN
    IF UnitCount = 0 THEN
    BEGIN
      WRITE ('Nothing to Copy..... ') ;
      DELAY (500)                       ;
      EXIT                              ;
    END                                 ;
    REPEAT
      F  := 0               ;
      P2 := 1               ;
      PutLine ( 'Note : Destination will get a copy of source. ' , 19 );
      GOTOXY ( 10,18 )      ;  WRITE
      ('Enter Source-Destination Number for COPY ( 1-', UnitCount, ' ) : ');
      READLN ( AStr )                                                       ;
      n := POS ( '-', AStr )                                                ;
      BStr := COPY ( Astr, n+1, LENGTH (AStr) - n )                  ;
      VAL ( BStr, P2, F )                                            ;
      DELETE (AStr, n, LENGTH (AStr) - n + 1 )                       ;
      VAL ( AStr, P1, E )                                            ;
    UNTIL (E=0) AND (F=0) AND
          (P1<=UnitCount) AND (P1>0)  AND
          (P2<=UnitCount) AND (P2>0)                                ;

    Patch^[P2] := Patch^[P1]                                         ;

  END     { Option = 3 }                                             ;
  {-----------------------------------}
  { Insert a space(s)                 }
  {-----------------------------------}
  IF Option = 2 THEN
  BEGIN
    IF UnitCount = 0 THEN
    BEGIN
      WRITE ('Nothing to Insert into..... ') ;
      DELAY (500)                            ;
      EXIT                                   ;
    END                                      ;
    REPEAT
      F  := 0               ;
      P2 := 1               ;
      UnitCountChange :=  1    ;
      PutLine ( 'Note : Enter range as XX-YY   ' , 19 )                   ;
      GOTOXY ( 10,18 )      ;  WRITE
      ( 'Enter Position Number to INSERT a space ( 1 - ', UnitCount, ' ) :  ' )  ;
      READLN ( AStr )                                                     ;
      n := POS ( '-', AStr )                                              ;
      IF n>0 THEN
      BEGIN
        BStr := COPY ( Astr, n+1, LENGTH (AStr) - n )                  ;
        VAL ( BStr, P2, F )                                            ;
        DELETE (AStr, n, LENGTH (AStr) - n + 1 )                       ;
      END                                                              ;
      VAL ( AStr, P1, E )                                              ;
      IF n > 0 THEN UnitCountChange := P2-P1+1                            ;
    UNTIL (E=0) AND (F=0) AND
          (P1<=UnitCount) AND (P1>0)  AND
          (P2<=UnitCount) AND (P2>0)                                  ;

    MovePatch ( P1, 2 )                                       ;
    UnitCount := UnitCount+UnitCountChange                     ;
  END     { Option = 2 }                                      ;

  {-----------------------------------}
  { ExChange 2 Units                  }
  {-----------------------------------}
  IF Option = 4 THEN
  BEGIN
    IF UnitCount < 3 THEN
    BEGIN
      WRITE ('Nothing to Exchange ..... ') ;
      DELAY (1000)                         ;
      EXIT                                 ;
    END                                    ;
    REPEAT
      GOTOXY ( 10,18 )      ;  WRITE
      ( 'Enter 2 Units for exchange [ N1-N2 ] (1 - ', UnitCount, ') : ')  ;
      READLN ( AStr )                                                     ;
      n := POS ( '-', AStr )                                              ;
      BStr := COPY ( Astr, n+1, LENGTH (AStr) - n )                  ;
      VAL ( BStr, P2, F )                                            ;
      DELETE (AStr, n, LENGTH (AStr) - n + 1 )                       ;
      VAL ( AStr, P1, E )                                            ;
    UNTIL (E=0) AND (F=0) AND
          (P1<=UnitCount) AND (P1>0)  AND
          (P2<=UnitCount) AND (P2>0)                                  ;

    IF UnitClass = 'P' THEN BEGIN
                              Patch^[UnitCount+1] := Patch^[P1]          ;
                              Patch^[P1]          := Patch^[P2]          ;
                              Patch^[P2]          := Patch^[UnitCount+1] ;
                            END                                          ;
    IF UnitClass = 'O' THEN BEGIN
                              OpMem^[UnitCount+1] := OpMem^[P1]          ;
                              OpMem^[P1]          := OpMem^[P2]          ;
                              OpMem^[P2]          := OpMem^[UnitCount+1] ;
                            END                                          ;
  END     { Option = 4 }                                      ;

END                                                           ;
{-------------------------------------}
{ Clear Patch 1-64 ( 0: All Patches)  }
{-------------------------------------}
PROCEDURE ClearPatch ( RecNum : Byte ) ;

VAR
  i        : INTEGER ;
  ClearAll : BOOLEAN ;

BEGIN
    IF ( UnitSelect=0 ) AND ( RecNum <> 0 ) THEN
                         BEGIN
                              ClearMainMenu ( 18,22 )          ;
                              WRITE ( 'Select patch first..' ) ;
                              DELAY (1000)                     ;
                              EXIT                             ;
                          END                                  ;
   ClearAll := FALSE  ;

   IF RecNum = 0  THEN
   BEGIN
     RecNum := 1      ;
     Clearall := TRUE ;
   END                ;

   IF UnitClass = 'P' THEN
   BEGIN
     Patch^[RecNum].PStart   := 0                                     ;
     FOR i := 1 TO 322 DO Patch^[RecNum].X[i] := 0                    ;
     FOR i := 1 TO 12  DO Patch^[RecNum].PName[i] := '*'              ;
     Patch^[RecNum].PChkSum := 0                                      ;
     IF ClearAll THEN FOR i := 2 TO 64 DO Patch^[i] := Patch^[RecNum] ;
   END                                                                ;

   IF UnitClass = 'O' THEN
   BEGIN
     OpMem^[RecNum].OStart   := 0                                     ;
     FOR i := 1 TO 322 DO OpMem^[RecNum].OData[i] := 0                ;
     FOR i := 1 TO 12  DO OpMem^[RecNum].OName[i] := '*'              ;
     OpMem^[RecNum].OChkSum := 0                                      ;
     IF ClearAll THEN FOR i := 2 TO 64 DO OpMem^[i] := OpMem^[RecNum] ;
   END                                                                ;

END                                                                 ;
{------------------------------------}
{ 2 : Expand bank to make a space    }
{ 1 : Contract bank to fill space    }
{------------------------------------}
PROCEDURE  MovePatch ( RecNum : BYTE ; Option : BYTE )  ;
VAR
  i : WORD ;

BEGIN

  IF Option = 2 THEN                { Insert space : Move patches up }
  BEGIN
    FOR i := UnitCount DOWNTO RecNum DO
             BEGIN
               IF UnitClass = 'P' THEN
                  Patch^ [i + UnitCountChange] := Patch^ [i] ;
               IF UnitClass = 'O' THEN
                  OpMem^ [i + UnitCountChange] := OpMem^ [i] ;
             END                                                            ;
    FOR i := RecNum TO RecNum + UnitCountChange - 1 DO
                        ClearPatch (i)                  ;
  END                                                   ;


  IF Option = 1 THEN                { Delete : Move patches down }
  BEGIN
    FOR i := RecNum TO UnitCount-UnitCountChange DO
             BEGIN
               IF UnitClass = 'P' THEN
                  Patch^ [i] := Patch^ [i+UnitCountChange]   ;
               IF UnitClass = 'O' THEN
                  OpMem^ [i] := OpMem^ [i+UnitCountChange]   ;
             END                                             ;
    FOR i := UnitCount-UnitCountChange+1 TO UnitCount DO
                        ClearPatch (i)                  ;
  END                                                   ;

END ;
{---------------------------------------}
{ Search for difference in 2 DataArrays }
{---------------------------------------}
PROCEDURE DoSearch (P1 : BYTE) ;

VAR
  i, n, m, k, q  : WORD    ;
  AStr, BStr     : Str10   ;
  Diff           : WORD    ;
  UnitSize       : WORD    ;
  B              : BYTE    ;

BEGIN

  IF UnitSelect = 0 THEN EXIT ;

  IF UnitClass = 'P' THEN UnitSize := PatchSize ;
  IF UnitClass = 'O' THEN UnitSize := OpMemSize ;

  i   := 0  ;
  k   := 0  ;
  q   := 0  ;
  Diff:= 0  ;

  ClearMainMenu ( 10,16 ) ;
  ClearMainMenu ( 18,22 ) ;
  TEXTCOLOR ( Yellow )    ;
        { NNN AA BB   NNN AA BB   NNN AA BB   NNN AA BB   NNN AA BB }
  WRITE ('Pos Byte    Pos Byte    Pos Byte    Pos Byte    Pos Byte');
  TEXTCOLOR ( White )     ;

  FOR i := 0 TO UnitSize-1 DO
  BEGIN
    IF UnitClass = 'P' THEN B := Patch^[P1].X[i] ;
    IF UnitClass = 'O' THEN B := OpMem^[P1].X[i] ;

    IF B <> PSearch.X[i] THEN
    BEGIN

      IF UnitClass = 'P' THEN n  := Patch^[P1].X[i]  ;
      IF UnitClass = 'O' THEN n  := OpMem^[P1].X[i]  ;

      AStr := DecToHex ( n )        ;
      m    := PSearch .X[i]          ;
      BStr := DecToHex ( m )        ;
      IF k > 6 THEN BEGIN
                      INC (q)       ;
                      k := 0        ;
                    END             ;
      IF q > 4 THEN BEGIN q := 0    ; TEXTCOLOR ( Cyan ) ; END ;
      GOTOXY ( 10 + q*12 , 10 + k ) ;
      WRITE ( i:3, ' ', AStr:2, ' ', BStr:2 )         ;
      k := k + 1                                      ;
      INC ( Diff )                                    ;
    END                                               ;
  END ;

  GOTOXY ( 10,20 ) ; TEXTCOLOR ( Yellow )                    ;
  IF k = 0 THEN WRITE (       ' No difference detected... ')
           ELSE WRITE ( Diff, ' Locations different ...   ') ;

  AStr [1] := READKEY ;

END   ;
{-----------------------------------------}
{ Display Buffer Dump Info                }
{-----------------------------------------}
PROCEDURE DoBufferDump ;

VAR
  i, k, n, p    : WORD  ;
  HexNum        : WORD  ;
  Start         : WORD  ;
  AStr          : Str10 ;

BEGIN
  CLRSCR ;
  p := 0 ;

  WRITE  ('Start Location of dump (0-',BufMaxSize,') : ') ;
  READLN (Start)                                 ;

  REPEAT

    CLRSCR                                                                  ;
    WRITELN
    ('Number 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19') ;

    FOR i := 0 TO 19 DO
    BEGIN
       WRITELN                     ;
       WRITE ( i*20+p:5, '  ') ;

       FOR n := 0 TO 19 DO
       BEGIN
         k := n + (i*20)                                         ;
         HexNum := Buffer^ [ k + p ]                             ;
         AStr := DecToHex (HexNum)                               ;
         IF HexNum < 16 THEN DELETE (Astr, 1, 1)                 ;
         IF (HexNum <> 0) THEN WRITE (AStr:2, ' ' )
         ELSE WRITE  ('..', ' ' )                                ;
       END                                                       ;
    END                                                          ;
    Choice := UPCASE (READKEY)                                   ;
    p := p + 400                                                 ;
  UNTIL (Choice = 'Q') OR ( p > BufMaxSize )                     ;

END                                                              ;

{---------------------}
{ Re - name Patch     }
{---------------------}
PROCEDURE RenamePatch ( RecNum : BYTE )   ;
VAR
  AStr : Str20       ;
  i, l : INTEGER     ;

BEGIN
  REPEAT
    ClearMainMenu ( 18,22 )                   ;
    IF UnitSelect = 0 THEN BEGIN
                              WRITE ( 'Select patch first..' ) ;
                              DELAY (1000)                     ;
                              EXIT                             ;
                            END                                ;
    PutLine ('Use Characters ( A-Z, 0-9, /-. )', 20 ) ;
    PutLine ('Maximum of 12 characters .', 21       )  ;
    GOTOXY ( 10,18 )                           ;
    IF UnitClass = 'P' THEN WRITE
       ('Enter new name for Patch : ', Patch^[RecNum].PName , ' : ' ) ;
    IF UnitClass = 'O' THEN WRITE
       ('Enter new name for OpMem : ', OpMem^[RecNum].OName , ' : ' ) ;
    READLN ( AStr )                                                      ;
    l := LENGTH (AStr)                                                   ;
    IF UnitClass = 'P' THEN
    BEGIN
      FOR i := 1 TO 12 DO Patch^[RecNum].PName[i] := ' '                   ;
      FOR i := 1 TO l DO Patch^[RecNum].PName[i] := AStr[i]                ;
    END                                                                    ;
    IF UnitClass = 'O' THEN
    BEGIN
      FOR i := 1 TO 12 DO OpMem^[RecNum].OName[i] := ' '                   ;
      FOR i := 1 TO l DO OpMem^[RecNum].OName[i] := AStr[i]                ;
    END                                                                    ;
  UNTIL ( l < 13  )                                                      ;

END                                            ;
{------------------------------------}
{ Select drive for Midi Info         }
{------------------------------------}
PROCEDURE SelectDrive ; { Drive + Path in Directory }

BEGIN
  REPEAT
    ClearMainMenu ( 18,22 )                                         ;
    PutLine ( 'Enter drive as X: \ SubDir1 \ Subdir2 where :     ' , 20 ) ;
    PutLine ( 'SubDir1 and 2 max of 8 characters                 ' , 21 ) ;
    PutLine ( 'Select Drive:Path (used for Midi Data) : ' , 18 )           ;
    READLN ( Dir )                                            ;
  UNTIL LENGTH (Dir) < 21                                     ;

  IF LENGTH (Dir) = 0 THEN Dir := 'Current'             ;

END ;

{-----------------------------------}
{ Select Machine Manufacturer       }
{-----------------------------------}
PROCEDURE SelectManufacturer ;

VAR
  n    : WORD    ;
  i, l : INTEGER ;
  AStr : Str10   ;

BEGIN
  ClearMainMenu ( 18,22 )                            ;
  WRITE ( 'Enter Manufacturer Name :  ' )            ;
  READLN ( Astr )                                    ;
  l := LENGTH ( AStr )                               ;
  IF l = 0 THEN EXIT                                 ;
  FOR i := 1 TO l DO AStr [i] := UPCASE ( AStr [i] ) ;

  FOR i := $00 TO $48 DO
  BEGIN
    IF POS ( AStr, ManufacturerList[i] ) = 1 THEN n := i ;
  END                                                    ;

  AStr := DecToHex ( n )                                                   ;
  TEXTCOLOR ( White )                                                      ;
  GOTOXY ( 10,20 )                                                         ;
  WRITE  ('FOUND: Manufacturer ', ManufacturerList[n], ' ID : ', AStr,' ' );

  ManID := n                                                               ;
  ManIDStr := AStr                                                         ;
  ManName  := ManufacturerList [n]                                         ;

  DELAY (1000)                                                             ;

END                                                                        ;
{-----------------------------------}
{ Write Midi Data                   }
{-----------------------------------}
PROCEDURE DoWrite ;

BEGIN
ClearMainMenu ( 18,22 )              ;

REPEAT

  PutLine  ( 'Byte to send :  ',18 ) ;
  READLN   ( Writebyte )             ;
  ConfigureMidi (MidiWrite)          ;
  SendByte ( WriteByte )             ;

UNTIL WriteByte = $FF                ;
END                                  ;  { DoWrite }
{--------------------------------------------------------}
{ Convert to Raw Dump Format                             }
{ PatchNum   : Patch Number 1-64 in Patch                }
{--------------------------------------------------------}
PROCEDURE PatchEncode ( UnitNum : WORD )    ;

CONST
  {----------------------------------------------------------------------}
  { Header1 used for single Patch Dumps                                  }
  { Header2 , 3 used for Bank Patch Dumps followed at end by SysExTail1  }
  { Header4 used by single Operation Memory Dumps                        }
  { Header5 , 3 used for Bank OpMem Dumps followed at end by SysExTail1  }
  {----------------------------------------------------------------------}
  { STANDARD MIDI SUBSTATUS FORMATS :                                    }
  {                         $35 MIDAPR                                   }
  {                         $40 MIDSWF Want to send file                 }
  {                         $41 MIDRQF Request File                      }
  {                         $42 MIDDAT Data Follows                      }
  {                         $43 MIDACK Midi Acknowledge                  }
  {                         $45 MIDEOF End of File                       }
  {                         $4E MIDERR Error in File                     }
  {                         $4F MIDRJC Rejection                         }
  {----------------------------------------------------------------------}
  { Format: Byte 0   : SysEx Start                                       }
  {         Byte 1-3 : Maufacturer ID ( Casio = 44 hex )                 }
  {                    ( New allocation is 3 byte ID )                   }
  {         Byte 4   : Hi nibble : SubStatus 1=Send 0=Receive file       }
  {                    Lo nibble : MidiChannel Ch1=0, Ch2=1 etc.         }
  {         Byte 5   : Format Type 1 = Opmem Single                      }
  {                                0 = Patch Single                      }
  {         Byte 6-7 : Usually Byte Count MSB+LSB                        }
  {----------------------------------------------------------------------}

  SysExHead1 : BArr5 = ( SysEx, $44, $03, $00, $70, $00 { $40 } { Data } ) ;
  SysExHead2 : BArr7 = ( SysEx, $44, $03, $00, $70, $70, $00, EoX        ) ;
  SysExHead3 : BArr5 = ( SysEx, $44, $03, $00, $70, $74 { Data }         ) ;
  SysExHead4 : BArr5 = ( SysEx, $44, $03, $00, $70, $01 { $40 } { Data } ) ;
  SysExHead5 : BArr7 = ( SysEx, $44, $03, $00, $70, $70, $01, EoX        ) ;
  SysExTail1 : BArr6 = ( SysEx, $44, $03, $00, $70, $71, EoX             ) ;

VAR
  i, n, m, s        : WORD ;
  C                 : BYTE ;

BEGIN

  FOR i := 0 TO BufMaxSize DO Buffer^[i] := 0 ;

  { Decode into Buffer Position 0 }
  {-------------------------------------}
  { Write Header                        }
  {-------------------------------------}
  IF (UnitType = 1) OR (UnitType = 3) THEN
  BEGIN
    IF UnitType = 1 THEN
       FOR i := 0 TO 5 DO Buffer^[i] := SysExHead1[i] ; { BUFFER 0-5        }
    IF UnitType = 3 THEN
       FOR i := 0 TO 5 DO Buffer^[i] := SysExHead4[i] ; { BUFFER 0-5        }
    Buffer^[i+1] := $40                               ; { BUFFER 6 = 40 hex }
    n := 7                                            ; { BUFFER 7          }
  END                                                 ;

  IF UnitType = 2 THEN
  BEGIN
    FOR i := 0 TO 7  DO Buffer^[i]:=SysExHead2 [i]    ; { BUFFER 0-7       }
    FOR i := 8 TO 13 DO Buffer^[i]:=SysExHead3 [i-8]  ; { BUFFER 8-13      }
    UnitNum := 1                                      ; { Start at 1st Rec }
    n       := 14                                     ; { BUFFER 14        }
    m       := 64                                     ; { 64 Patches       }
    s       := 1                                      ; { Ignore first byte}
  END                                                 ;

  {-------------------------------------}
  { Decode every 2 bytes in BUFFER as   }
  { one byte in DATA                    }
  {-------------------------------------}
  IF (UnitType=1) OR (UnitType=3) THEN
  BEGIN
    FOR i := 1 TO (UnitSize-2) DO       { BUFFER 7 - 673 or 7 - 201 }
    BEGIN
      IF UnitType = 1 THEN
      BEGIN
        Buffer^[n]   := ( Patch^ [UnitNum]. X[i]) DIV 16 ;
        Buffer^[n+1] := ( Patch^ [UnitNum]. X[i]) MOD 16 ;
      END                                                ;
      IF UnitType = 3 THEN
      BEGIN
        Buffer^[n]   := ( OpMem^ [UnitNum]. X[i]) DIV 16 ;
        Buffer^[n+1] := ( OpMem^ [UnitNum]. X[i]) MOD 16 ;
      END                                                ;
      INC ( n, 2 )                                       ;
    END                                                  ;
    IF UnitType = 1 THEN C  := Patch^ [UnitNum].PChkSum  ;
    IF UnitType = 3 THEN C  := OpMem^ [UnitNum].OChkSum  ;
    Buffer^ [ ( 2 * UnitSize ) + 3 ] := C                ;
    Buffer^ [ ( 2 * UnitSize ) + 4 ] := EoX              ;
  END                                                    ;

  IF UnitType = 2 THEN
  BEGIN
      FOR m := 1 TO 64 DO
      BEGIN
          FOR i := 1 TO (UnitSize-2) DO { BUFFER 14 to 64*673 }
          BEGIN
              Buffer^[n]   := ( Patch^[UnitNum].X[i]) DIV 16 ;
              Buffer^[n+1] := ( Patch^[UnitNum].X[i]) MOD 16 ;
              INC ( n, 2 )                                   ;
          END                                                ;
          Buffer^[n] := Patch^[UnitNum].PChkSum              ;
          INC (n)                                            ;
          INC (UnitNum)                                      ;
      END                                                    ;
      m := 43086                                             ;
      Buffer^ [m] := EoX                                     ;
      FOR i := 0 TO 6 DO Buffer^[m+1+i] := SysExTail1[i]     ;
  END                                                        ;

END ;
{----------------------------}
{ Display the String at Line }
{----------------------------}
PROCEDURE PutLine ( S : STRING ; Line : INTEGER ) ;

BEGIN
  GOTOXY ( 10,Line ) ;
  WRITE  ( S )       ;
END                  ;
{------------------------------}
{ DownLoad Bulk Dumps          }
{------------------------------}
PROCEDURE DoBulkWrite ;

CONST

  S1 = 'CASIO VZ-10M DOWNLOAD SETUP : Single Patch Dump         ' ;
  S2 = '[1] Set Internal Memory protection to OFF (MENU 3-01)   ' ;
  S3 = '[2] Midi System Exclusive Data ENABLED    (MENU 3-04)   ' ;
  S4 = '[3] The current COMPARE-RECALL Patch will be overwritten' ;
  S5 = '    by the patch being transmitted. (Press CMP/RCL key) ' ;

  T1 = 'CASIO VZ-10M DOWNLOAD SETUP : Patch Bank Dump           ' ;
  T4 = '[3] Set Save-Load to : LOAD-MIDI-VOICE    (MENU 3-02)   ' ;
  T5 = '    Press the Casio YES Key before the computer RETURN  ' ;
  T6 = '[4] The current 64 patchbank will be replaced by the new' ;
  T7 = '    Note that the dump will take 20 seconds to complete.' ;

VAR
  S, i : WORD                  ;

BEGIN
   ClearMainMenu ( 10,16 )     ;
   TEXTCOLOR ( LightGray )     ;

   IF UnitType = 1 THEN BEGIN PutLine ( S1,10 ) ; PutLine ( S2, 11 ) ;
                              PutLine ( S3,12 ) ; PutLine ( S4, 13 ) ;
                              PutLine ( S5,14 ) ; END                ;
   IF UnitType = 2 THEN BEGIN PutLine ( T1,10 ) ; PutLine ( S2, 11 ) ;
                              PutLine ( S3,12 ) ; PutLine ( T4, 13 ) ;
                              PutLine ( T5,14 ) ; PutLine ( T6, 15 ) ;
                              PutLine ( T7,16 ) ; END                ;

   ClearMainMenu ( 18,22 )                  ;
   TEXTCOLOR ( White )                      ;
   WRITE ( 'Press any key to continue ...') ;
   Choice := READKEY                        ;

   WRITE ( 'Encoding ...  ' )       ;

   PatchEncode ( UnitSelect )       ;

   WRITE ( 'Transmitting ...  ' )   ;

   IF (UnitType=1) OR (UnitType=3) THEN S := ( UnitSize + 2 ) * 2 ;
   IF (UnitType=2)                 THEN S := 43094                ;

     FOR i := 0 TO S DO
     BEGIN
       ConfigureMidi (MidiWrite)          ;
       SendByte ( Buffer^[i] )            ;
     END                                  ;

END ;
{--------------------------------------------------------}
{ Convert to Voice Format                                }
{ Calculate CheckSum                                     }
{ PatchStart : Start of encoded (raw) Patch              }
{ PatchNum   : Patch Number 1-64 in Patch                }
{--------------------------------------------------------}
PROCEDURE PatchDecode ( UnitStart, UnitNum : WORD ) ;

VAR
  i, n        : WORD ;
  UnitEnd     : WORD ;
  Choice      : CHAR ;
  UnitLen     : WORD ;
  ChkSum      : WORD  ;
  AStr, BStr  : Str10 ;

BEGIN

  UnitLen := UnitSize - 2                ;

  UnitEnd := UnitStart + UnitLen * 2 + 1 ; { Dump Size = 673 or 101 bytes }
  ChkSum  := Buffer^ [ UnitEnd + 1 ]     ; { Transmitted CheckSum         }
  AStr    := DecToHex ( ChkSum )         ;
  {-------------------------------------}
  { Decode every 2 bytes in BUFFER as   }
  { one byte in DATA                    }
  {-------------------------------------}
  n := UnitStart  ;
  i := 0          ;
  REPEAT
    IF UnitClass='P' THEN Patch^[UnitNum].X[i]:=Buffer^[n]*16+Buffer^[n+1] ;
    IF UnitClass='O' THEN OpMem^[UnitNum].X[i]:=Buffer^[n]*16+Buffer^[n+1] ;
    INC (n,2)        ;
    INC (i)          ;
  UNTIL i >  UnitLen ;
  {-------------------------------------}
  { Calculate the Checksum in Data      }
  {-------------------------------------}
  IF UnitClass = 'P' THEN Patch^ [UnitNum].PChkSum := ChkSum    ;
  IF UnitClass = 'O' THEN OpMem^ [UnitNum].OChkSum := ChkSum    ;

  DoCheckSum ( UnitNum, ChkSum, AStr, 1 ) ;

END ;
{---------------------------}
{ Write Patch Name          }
{---------------------------}
PROCEDURE PatchName ( UnitNum : WORD ; VAR Scroll : BYTE ; Option : BYTE ) ;

VAR
  Row, Col  : BYTE        ;
  Scr       : BYTE        ;
  Choice    : CHAR        ;
  X, Y      : INTEGER     ;

BEGIN
  Choice := ' '                                             ;
  IF Option = 0 THEN X := 28 ELSE X := 64 ; { Number of Units displayed }
  Y := X DIV 4                            ; { 7 or 16                   }

  WINDOW ( 9, 10-(7*Option), 69+(2*Option), 16+(3*Option) )               ;
  Scr := ( ( UnitNum + X - 1 ) MOD X )                                    ;
  Row := ( ( Scr + Y ) MOD Y ) + 1                                        ;
  Col := ( Scr DIV Y ) * ( 15 + Option ) + 1                              ;

  GOTOXY ( Col , Row )                                                    ;
  TEXTCOLOR (White)                                                       ;
  IF UnitClass = 'P' THEN WRITE ( UnitNum:2, ' ', Patch^ [UnitNum].PName );
  IF UnitClass = 'O' THEN WRITE ( UnitNum:2, ' ', OpMem^ [UnitNum].OName );
  WINDOW ( 1,1,80,25 )                                                    ;
  TEXTCOLOR (Yellow)                                                      ;

  IF Scroll = 0 THEN                    Choice := READKEY   ;
  IF Scroll = 1 THEN IF KEYPRESSED THEN Choice := READKEY   ;
  IF Choice = #27 THEN Scroll := Scroll XOR 1               ;

END                                           ;

{--------------------------------------}
{ Read Single Patch Midi Data          }
{--------------------------------------}
PROCEDURE DoSinglePatchRead ( UnitType : BYTE) ;

CONST
  S   = ' '        ;
  SS  = '  '       ;
  BS5 = #8#8#8#8#8 ;

  S1 = 'CASIO VZ-10M UPLOAD SETUP : Single Patch Dump              ' ;
  S2 = '[1] Set Midi System Exclusive Data ENABLED    (MENU 3-04)  ' ;
  S3 = '[2] Press PC key first, then Bank Select key(s) [A-1]-[H-8]' ;
  S4 = '    in desired sequence to transmit patche(s) 1 at a time. ' ;
  S5 = '[3] Make sure that NORMAL MODE is selected.                ' ;

  T1 = 'CASIO VZ-10M UPLOAD SETUP : Patch Bank Dump                ' ;
  T3 = '[2] Set Save-Load to : SAVE-MIDI-VOICE        (MENU 3-02)  ' ;
  T4 = '[3] Press PC Key first then Casio YES Key to transmit the  ' ;
  T5 = '    64 Voice bank of patches ( 20 seconds to complete )    ' ;

  U4 = '    in desired sequence to transmit Op Mem(s) 1 at a time. ' ;
  U5 = '[3] Make sure that OPERATION MEMORY MODE is selected.      ' ;

VAR
   n, i, k, m : WORD                       ;
   CountF0    : BYTE                       ; { Number of F0 received   }
   CountF7    : BYTE                       ; { Number of F7 received   }
   PosF0      : ARRAY [0..65] OF WORD      ; { Loc of F0 bytes         }
   PosF7      : ARRAY [0..65] OF WORD      ; { Loc of F7 bytes         }
   CountData  : WORD                       ; { Number of Data received }
   Choice     : CHAR                       ;
   Scroll     : BYTE                       ;
   AStr       : Str20                      ;
   BStr       : Str10                      ;

BEGIN
   {---------------------------------------------}
   { Initialise variables and storage            }
   {---------------------------------------------}
   FOR i := 0 TO BufMaxSize DO Buffer^[i] := 0         ;

   ClearPatch (0)                                 ; { Clear all }

   UnitSelectName := 'Not-Selected'            ;
   UnitSelect := 0                         ;
   UnitCount  := 0                         ;

   ClearMainMenu ( 10,16 )     ;
   TEXTCOLOR ( LightGray )     ;

   IF UnitType = 1 THEN BEGIN PutLine ( S1,10 ) ; PutLine ( S2, 11 ) ;
                              PutLine ( S3,12 ) ; PutLine ( S4, 13 ) ;
                              PutLine ( S5,14 ) ; END                ;
   IF UnitType = 3 THEN BEGIN PutLine ( S1,10 ) ; PutLine ( S2, 11 ) ;
                              PutLine ( S3,12 ) ; PutLine ( U4, 13 ) ;
                              PutLine ( U5,14 ) ; END                ;
   IF UnitType = 2 THEN BEGIN PutLine ( T1,10 ) ; PutLine ( S2, 11 ) ;
                              PutLine ( T3,12 ) ; PutLine ( T4, 13 ) ;
                              PutLine ( T5,14 ) ; END                ;

   ClearMainMenu ( 18,22 )                  ;
   TEXTCOLOR ( White )                      ;
   WRITE ( 'Press any key to continue ...') ;
   Choice := READKEY                        ;

   WRITE ( 'Loading ...  ' )                                          ;
   PutLine ('Press [Q] when finished ( or to abort read ) ... ', 20 ) ;
   SOUND (150) ; DELAY (300) ; NOSOUND                                ;

   ResetDSP                            ;
   ConfigureMidi (MidiPollRead)        ;

   {-------------------------------------------------------}
   { Loop until System Exclusive Command Byte              }
   {-------------------------------------------------------}
    REPEAT GetByte ; UNTIL ReadByte = $F0 ;
    Buffer^ [0]   := $F0                  ;
    CountF0       := 1                    ;
    CountF7       := 0                    ;
    PosF0 [0]     := 0                    ;
    n             := 1                    ;
   {-------------------------------------------------------}
   { Main Read Loop                                        }
   {-------------------------------------------------------}
   REPEAT
     GetByte                                    ;
     {------------------------------------------}
     { Status Byte received                     }
     {------------------------------------------}
     IF (ReadByte>127) THEN                         { Status Byte if D7 = 1 }
     BEGIN
       CASE ReadByte OF
            EoX   : BEGIN                     { EOX Status Byte       }
                      PosF7 [CountF7] := n  ;
                      INC ( CountF7 )       ;
                    END                     ;
            SysEx : BEGIN                     { SysEx Status Byte    }
                      PosF0 [CountF0] := n  ;
                      INC ( CountF0 )       ;
                    END                     ;
            END                             ; { Case ReadByte  }
     END                                           ; { ReadByte > 127 }

     Buffer^[n] := ReadByte                           ;
     INC ( n )                                        ;
     IF KEYPRESSED THEN Choice := UPCASE (READKEY)    ;

   UNTIL (Choice='Q') OR (n>BufMaxSize)               ;

   {---------------------------------------------------}
   { Display Results of Upload                         }
   {---------------------------------------------------}
   k         :=  CountF7 + CountF0                     ;
   CountData :=  n - k                                 ;
   ClearMainMenu ( 18,22 )                             ;
   WRITE ( 'Upload: DATA '          , '[' , CountData , ']',
                 '  STATUS (F0 F7) ', '[' ,         k , ']',
                 '  TOTAL '         , '[' ,       n-1 , ']'  )  ;

   IF CountF0 <> CountF7 THEN WRITE ('Error:Sys-Excl [F0-F7 unpaired]. ') ;
   {------------------------------------}
   { Check Manufacturer                 }
   {------------------------------------}
   IF ManID <> 0 THEN
   BEGIN
     m := Buffer^ [ PosF0 [0] + 1 ]                                        ;
     BStr := DecToHex ( m )                                                ;
     AStr := ManufacturerList [m]                                          ;
     IF m <> ManID THEN BEGIN
                          GOTOXY ( 10, 20 ) ; TEXTCOLOR ( White )          ;
                          WRITE  ('Received : ', AStr,' ID:', BStr,'...' ) ;
                        END                                                ;
   END                                                                     ;
  {-------------------------------------}
  { Decode received Data                }
  { Write received Checksums            }
  { Write received Patchnames           }
  {-------------------------------------}
  ClearMainMenu ( 10, 16 )              ;
  Scroll := 0                           ;  { Do not scroll at first }
  PutLine ('[RETURN] Next-Patch   [ESC] Auto-scroll toggle ', 21 )  ;

  IF (UnitType=1) OR (UnitType=3) THEN
  BEGIN
      FOR i := 0 TO ( CountF0 - 1 ) DO
      BEGIN
         m := PosF0 [i] + 5                     ; { F0 44 03 70 00 header   }
         PatchDecode ( m , i+1 )                ; { i+1 = Patch Record 1-64 }
         PatchName ( i+1, Scroll, 0 )           ;
       END                                      ;
    END                                         ;

    IF (UnitType=2) OR (UnitType=4) THEN
    BEGIN
      m := PosF0 [1] + 4                        ; { F0 44 03 70 74 header   }
      FOR i := 0 TO 63 DO
      BEGIN
         PatchDecode ( m , i+1 )                ; { i+1 = Patch Record 1-64 }
         Patch^ [i+1]. X[0] := $40              ;
         PatchName ( i+1 , Scroll, 0 )          ;
         m := m + ( UnitSize * 2) - 3           ; { 673 or 201 }
       END                                      ;
    END                                         ;


    SOUND (200)       ; DELAY (300) ; NOSOUND                           ;
    GOTOXY ( 10, 21 ) ; WRITE
    ('[ ', i+1, ' ] ',UnitName,' received [Any key for main menu] ')    ;
    UnitCount := i + 1                                                  ;
    Choice := READKEY                                                   ;

END ;              { DoRead }

