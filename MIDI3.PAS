
{--------------------------------------}

UNIT Midi3    ;

INTERFACE

USES DOS, CRT, GRAPH ;

{ USE INCLUDE FILE MIDI4.PAS }

CONST
     BufMaxSize = 43100 ;   { This is only big enough for voice dumps }

TYPE
     Str2  = STRING [2]                                   ;
     Str3  = STRING [3]                                   ;
     Str10 = STRING [10]                                  ;
     Str12 = STRING [12]                                  ;
     Str20 = STRING [20]                                  ;

     BArr5  = ARRAY [0..5]  OF BYTE                       ;
     BArr6  = ARRAY [0..6]  OF BYTE                       ;
     BArr7  = ARRAY [0..7]  OF BYTE                       ;
     BArr8  = ARRAY [1..8]  OF BYTE                       ;
     CArr12 = ARRAY [1..12] OF CHAR                       ;

     WaveType1 = (Triangle,SawUp,SawDown,Square)               ;
     WaveType2 = (Sine,Saw1,Saw2,Saw3,Saw4,Saw5,Noise1,Noise2) ;
     OnOffType = (On,Off)                        ;

     ByteSet  = SET OF BYTE          ;
     WaveSet1 = SET OF WaveType1     ;
     WaveSet2 = SET OF WaveType2     ;
     OnOffSet = SET OF OnOffType     ;

     BufferPtr = ^BufferType                   ;

     BufferType = ARRAY [0..BufMaxSize] OF BYTE;
     SysExType  = ARRAY [0..100,0..1] OF WORD  ;

     {$I MIDI4.PAS } { Patch Specification and Type }

     OpMemType  = RECORD
                    CASE BOOLEAN OF
                         TRUE  : ( X : ARRAY [0..101] OF BYTE ) ;
                         FALSE : (
                    OStart      : BYTE                    ;
                    OSecond     : BYTE                    ;
                    OName       : CArr12                  ;
                    OData       : ARRAY [1..87] OF BYTE   ;
                    OChkSum     : BYTE                    ; )
                  END                                     ;

     PatchBulkType =  ARRAY [1..128] OF PatchType    ; { 2 * 21632 bytes }
     OpMemBulkType =  ARRAY [1..128] OF OpMemType    ; { 2 *  6582 bytes }

     PatchPtr      = ^PatchBulkType                       ;
     OpMemPtr      = ^OpMemBulkType                       ;
     {------------------------------------------------------------------}
     { FileName Extensions :          xx = 01 - 64                      }
     { Patches             : NAME.Pxx xx = patch records in the file.   }
     { Operation Memories  : NAME.Oxx xx = Op Mem records in the file   }
     {------------------------------------------------------------------}
     CharSet = SET OF CHAR                                              ;

CONST
     WaveArr1 : ARRAY [0..7] OF Str10 =
              ('Sine','Saw1','Saw2','Saw3','Saw4','Saw5','Noise1','Noise2') ;
     WaveArr2 : ARRAY [0..3] OF Str10 =
                ('Triangle','SawUp','SawDown','Square')                     ;
     KeyArr   : ARRAY [0..11] OF Str3 =
   ('C  ','Db ','D  ','Eb ','E  ','F  ','Gb ','G  ','Ab ','A  ','Bb ','B  ');
     L2 =  '                                                            '   ;
     NL        = #13#10                                    ;
     HexDigit  : ARRAY [0..15] OF CHAR = '0123456789ABCDEF'; { Hex Digits }

     PatchSize : WORD = SIZEOF ( PatchType )           ; { Patch Size }
     OpMemSize : WORD = SIZEOF ( OpMemType )           ; { OpMem Size }

     ManufacturerList : ARRAY [$00..$48] OF STRING =
   ( '','SEQUENTIAL SCI','BIG BRIAR','OCTAVE','MOOG','PASSPORT DESIGNS',
     'LEXICON','','','','','','','','','ENSONIQ','OBERHEIM','','','',
     '','','','','','','','','','','','','BONTEMPI','SIEL','','','','',
     '','','','','','','','','','','','','','','','','','','','','','','',
     '','','','KAWAI','ROLAND','KORG','YAMAHA','CASIO','','','','') ;

     SysEx  = $F0       ;   { System Exclusive Start }
     EoX    = $F7       ;   { System Exclusive End   }


VAR

      Buffer  : BufferPtr     ;          { Raw Voices in here       }
      Patch   : PatchPtr      ;
      OpMem   : OpMemPtr      ;

      PSearch : PatchType     ;          { Used for search storage }
      OSearch : OpMemType     ;          { Used for search storage }

      NumX, CharX, HexX       : CharSet  ;

      MidiCmd    : BYTE    ;
      WriteByte  : BYTE    ;  { Midi byte to send }
      ReadByte   : BYTE    ;  { Midi byte read    }
      Choice     : CHAR    ;

      CmdData    : ARRAY[0..50] OF BYTE  ; { List of Midi Commands        }
      CmdDataPos : ARRAY[0..50] OF WORD  ; { Position of the Command Data }
      HexCmdData : ARRAY[0..50] OF Str10 ;

      SysExData  : SysExType             ; { Save F0-F7 pairs in here }
      SysExNum   : BYTE                  ; { Number of F0 Commands    }

      UnitType       : BYTE  ; { 0-9 : Type of Dump : Patch Opmem Multi }
      UnitClass      : CHAR  ; { P : Patch, O : OpMem                   }
      UnitName       : Str10 ; { Patches , OpMemory,                    }
      UnitID         : Str10 ; { A-1 to H-8 version of UnitSelect       }
      UnitSelectName : Str12 ; { ASCII name of selected patch           }
      UnitCount      : BYTE  ; { Number of patches in Data              }
      UnitSelect     : BYTE  ; { Selected Patch: 1-UnitCount            }
      UnitCountChange: BYTE  ; { Change in UnitCount                    }
      UnitChkSum     : BYTE  ; { Calculated received CheckSum           }
      UnitSize       : WORD  ; { Size of patch, Opmem etc               }

      ManID      : BYTE       ;          { Manufacturer ID              }
      ManIDStr   : Str10      ;          { HexStr ID                    }
      ManName    : Str20      ;          { Manufacturer Name            }

      FileN      : String     ;          { FileName as ASCII String     }
      FileName   : FILE       ;          { Filename for save - load     }
      Dir        : Str20      ;          { Directory for Library        }
                                         { Extended Load Options        }
      XLoadPos   : BYTE       ;          { Pos to Load 1-64             }
      XLoadOption: BYTE       ;          { 0:Clear 1:Delete 2:Insert    }
      GraphDriver, GraphMode, GraphError : INTEGER  ;

      ARateM1, ALevM1        : BArr8   ;  { DCARate+Level M1 S1-S8}
      ARateM2, ALevM2        : BArr8   ;  { DCARate+Level M2 S1-S8}
      ARateM3, ALevM3        : BArr8   ;  { DCARate+Level M3 S1-S8}
      ARateM4, ALevM4        : BArr8   ;  { DCARate+Level M4 S1-S8}
      ARateM5, ALevM5        : BArr8   ;  { DCARate+Level M5 S1-S8}
      ARateM6, ALevM6        : BArr8   ;  { DCARate+Level M6 S1-S8}
      ARateM7, ALevM7        : BArr8   ;  { DCARate+Level M7 S1-S8}
      ARateM8, ALevM8        : BArr8   ;  { DCARate+Level M8 S1-S8}


{--------------------------------------------------------------------------}
 PROCEDURE GetA1H8Number ( B : BYTE )                ;
 PROCEDURE VoiceEdit                                 ;
 PROCEDURE DoGraphics                                ;
{--------------------------------------------------------------------------}

IMPLEMENTATION

{----------------------}
{ Graphics Routines    }
{----------------------}
PROCEDURE DoGraphics   ;
VAR
  PArr       : ARRAY [0..8,0..1] OF INTEGER ;
{----------------------}
{ Calculate DCA Points }
{----------------------}
PROCEDURE CalcDCAPoints ( DCANum : INTEGER; Rate, Level : BArr8 ) ;
PROCEDURE CalcPoint ( R, L : INTEGER; VAR X, Y: INTEGER ) ;
VAR Xold : INTEGER  ;
BEGIN
  Xold := X      ;
  IF R > 63 THEN BEGIN
                    R := 64 - ( R-64 ) ;
                    IF R=0 THEN R := 1 ;
                    X := (( ABS ( L-Y ) ) * R ) DIV 64 ;
                 END
                 ELSE { R < 64 }
                 BEGIN
                   IF R = 0 THEN R := 1 ;
                   X := (( ABS ( L-Y ) ) * 64 ) DIV R ;
                 END  ;
  X := Xold + X       ;
  Y := L              ;
END                   ;

VAR
  X, Y, i    : INTEGER                      ;

BEGIN
  X := 0 ; Y := 0    ;
  PArr [0][0] := X   ;
  PArr [0][1] := Y   ;

  FOR i := 1 TO 8 DO
  BEGIN
    CalcPoint ( Rate[i], Level[i], X, Y ) ;
    PArr [i][0] := X   ;
    PArr [i][1] := Y   ;
  END                  ;
END ;

{-----------------------}
PROCEDURE InitGraphics ;
BEGIN
  GraphDriver := DETECT                     ;
  INITGRAPH ( GraphDriver, GraphMode ,'')   ;
  GraphError := GRAPHRESULT                 ;
  IF GraphError <> 0 THEN
  BEGIN
     CLRSCR  ;  WRITE
     (NL,' Graphics Error : ', GRAPHERRORMSG (GraphError)) ;
     READLN ; HALT (0) ; END                               ;
END                                                        ;
{-----------------}
PROCEDURE GraphOn ;
BEGIN  SetGraphMode   ( GraphMode ) ; END ;
{-----------------}
PROCEDURE TextOn  ;
BEGIN  RestoreCRTMode ; END ;
{-----------------}

{-------------------}
{ PlotDCA Envelopes }
{-------------------}
PROCEDURE PlotDCA ;
{------------------}
{ Set Window       }
{------------------}
PROCEDURE SetWindow ( X1,X2,Y1,Y2 : INTEGER )   ;
BEGIN
  SETVIEWPORT ( X1,Y1,X2,Y2, CLIPON ) ;
END                                   ;
{------------------}
{ PlotGraphAxis    }
{------------------}
PROCEDURE PlotAxis ( Module : BYTE ) ;

VAR
  Xs, Xe, Ys, Ye  : INTEGER ;
  X, Y, i, Z      : INTEGER ;
  AStr            : Str10   ;

BEGIN
 {--------------------- Plot X Axis }
  SETCOLOR ( Yellow )  ;
  MOVETO (  40, 139 )  ;
  LINETO ( 232, 139 )  ;
  MOVETO (  40, 140 )  ;
  LINETO ( 232, 140 )  ;
  X := 32              ;
  FOR i := 1 TO 6 DO BEGIN
                       MOVETO ( 40 + X, 140 ) ;
                       LINETO ( 40 + X, 136 ) ;
                       MOVETO ( 41 + X, 140 ) ;
                       LINETO ( 41 + X, 136 ) ;
                       X := X + 32            ;
                     END                      ;
  MOVETO ( 30, 150 ) ;
  OUTTEXT  ( 'O      4OO     8OO    1OOO ')   ;

  SETCOLOR ( Cyan )     ;
 {---------------------- Horizontal Lines }
  Y := 140-16 ;
  FOR i := 1 TO 8 DO BEGIN
                       MOVETO (  43, Y ) ;
                       LINETO ( 232, Y ) ;
                       Y := Y-16         ;
                      END                ;
  {-------------------- Plot Y Axis }
  SETCOLOR ( Yellow ) ;
  MOVETO ( 39, 140 ) ;
  LINETO ( 39, 10  ) ;
  MOVETO ( 38, 140 ) ;
  LINETO ( 38, 10  ) ;
  Y := 140-16 ;
  FOR i := 1 TO 8 DO BEGIN
                       MOVETO ( 38, Y ) ;
                       LINETO ( 42, Y ) ;
                       MOVETO ( 38, Y ) ;
                       LINETO ( 42, Y ) ;
                       Y := Y-16            ;
                      END                   ;
 {---------------------- Vertical Lines }
  SETCOLOR ( Cyan )    ;
  X := 32              ;
  FOR i := 1 TO 6 DO BEGIN
                       MOVETO ( 41 + X, 138 ) ;
                       LINETO ( 41 + X, 10  ) ;
                       X := X + 32            ;
                     END                      ;

  SETCOLOR ( Yellow )   ;
  AStr := ('  16')      ;
  X := 0      ;
  Y := 138-16 ;
  Z := 16     ;
  FOR i := 1 TO 8 DO
  BEGIN
    MOVETO  ( X, Y   ) ; OUTTEXT ( AStr )      ;
    Z := Z + 16                                ;
    STR ( Z:4, AStr )                          ;
    Y := Y - 16                                ;
  END                                          ;

  SETCOLOR ( White ) ;
  MOVETO  ( 0, 104 ) ; OUTTEXT ( 'L' )    ;
  MOVETO  ( 0,  88 ) ; OUTTEXT ( 'E' )    ;
  MOVETO  ( 0,  72 ) ; OUTTEXT ( 'V' )    ;
  MOVETO  ( 0,  56 ) ; OUTTEXT ( 'E' )    ;
  MOVETO  ( 0,  40 ) ; OUTTEXT ( 'L' )    ;

  MOVETO ( 40, 162 ) ;
  OUTTEXT  ( 'MODULE [ ]       Time [S] ') ;

END        ; { PlotDCA }

VAR
  X1,X2,Y1,Y2 : INTEGER ;

BEGIN
  SETBKCOLOR ( Black )                   ;
  SetWindow ( 10, 10, 340, 210  )        ;
  PlotAxis ( 1 )                         ;
  READLN  ;
END ;
{-----------------------}
{ Plot DCA Points       }
{-----------------------}
PROCEDURE PlotDCAPoints ;
VAR
 XScaleFactor,
 YScaleFactor : INTEGER    ;
BEGIN
{ PArr contains 9 (x,y) points referenced to 0,0 }
 SETCOLOR ( White ) ;
 XScaleFactor := 3    ; { If X values in PArr > 192 }
 YScaleFactor := 1    ;

 MOVETO ( 40, 138 )  ; { Origin }
 LINETO ( (PArr[1][0] DIV XScaleFactor)+40, 138-PArr[1][1] ) ;
 LINETO ( (PArr[2][0] DIV XScaleFactor)+40, 138-PArr[2][1] ) ;
 LINETO ( (PArr[3][0] DIV XScaleFactor)+40, 138-PArr[3][1] ) ;
 LINETO ( (PArr[4][0] DIV XScaleFactor)+40, 138-PArr[4][1] ) ;

 READLN ;
END ; { PlotDCAPoints }

{----------------------------------------}
{ DoGraphics                             }
{----------------------------------------}
VAR i : INTEGER   ;

BEGIN
  InitGraphics                              ;
  SETGRAPHMODE ( GraphMode )                ;

  PlotDCA                                   ;

  CalcDCAPoints ( i, ARateM1, ALevM1 ) ;
  PlotDCAPoints ;
  CalcDCAPoints ( i, ARateM2, ALevM2 ) ;
  CalcDCAPoints ( i, ARateM3, ALevM3 ) ;
  CalcDCAPoints ( i, ARateM4, ALevM4 ) ;
  CalcDCAPoints ( i, ARateM5, ALevM5 ) ;
  CalcDCAPoints ( i, ARateM6, ALevM6 ) ;
  CalcDCAPoints ( i, ARateM7, ALevM7 ) ;
  CalcDCAPoints ( i, ARateM8, ALevM8 ) ;

  READLN                                    ;

  TextOn ;
  WRITE ('This is the Text Mode ... ')      ;
  READLN                                    ;
  CLOSEGRAPH                                ;

END ;
{----------------------}
{ Get A-1 to H-8 Number}
{----------------------}
PROCEDURE GetA1H8Number ( B : BYTE ) ;

VAR
  CharAH : CHAR  ;
BEGIN
  CharAH := 'A' ;
  WHILE B > 8 DO
  BEGIN
     B := B - 8                ;
     CharAH := SUCC ( CharAH ) ;
  END                          ;
  STR ( B:2, UnitID )   ;
  UnitID[1] := CharAH   ;
END                     ;

{----------------------}
{ Do Voice edit        }
{----------------------}
PROCEDURE VoiceEdit    ;

CONST

S3 ='ÃÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄ´';
S4 ='³ ÚÄÄ¿ ÚÄ¿      ÚÄÄ¿          ÚÄÄ¿          ÚÄÄ¿                 Ä¿     ÚÄÄÄ¿ ³';
S5 ='³ ³M1ÃÄ´XÃÄ¿    ³M3ÃÄÄ¿       ³M5ÃÄÄÄÄÄ¿    ³M7ÃÄÄÄÄÄ¿            ³ ÚÄ¿ ³ O ³ ³';
S6 ='³ ÀÄÄÙ ÀÂÙ ³    ÀÄÄÙ  ³       ÀÄÄÙ     ³    ÀÄÄÙ     ³           Ä´ ³M³ ³ U ³ ³';
S7 ='³  RING ³  ÃÄ A  PHASE³  ÚÄ B  MIX     ÃÄ C  MIX     ÃÄ D Ä¿      ÃÄ´IÃÄ´ T ³ ³';
S8 ='³ ÚÄÄ¿  ³  ³    ÚÄÄÂÄÄÙ  ³    ÚÄÄ¿     ³    ÚÄÄ¿     ³     ³     Ä´ ³X³ ³ P ³ ³';
S9 ='³ ³M2ÃÄÄÁÄÄÙ    ³M4ÃÄÄÄÄÄÙ    ³M6ÃÄÄÄÄÄÙ    ³M8ÃÄÄÄÄÄÙ     ³      ³ ÀÄÙ ³ U ³ ³';
S10='³ ÀÄÄÙ          ÀÄÄÙ          ÀÄÄÙ          ÀÄÄÙ           ÀÄÄ   ÄÙ     ³ T ³ ³';
S11='³                                                                       ÀÄÂÄÙ ³';
S12='³ ÚÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄ¿ ÚÄÄÄÄÄÄÄÄÄÄÄ¿  ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄ¿ ³';
S13='³ ³M1         ³ ³M3         ³ ³M5         ³ ³M7         ³  ³Total Level     ³ ³';
S14='³ ³M2         ³ ³M4         ³ ³M6         ³ ³M8         ³  ³Octave Shift    ³ ³';
S15='³ ÀÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÙ ÀÄÄÄÄÄÄÄÄÄÄÄÙ  ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ³';
S16='ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ';
S17='ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿';
S18='³ MODULATION   ³ WAVEFORM ³  DEPTH   ³  SPEED  ³  DELAY  ³ MULTI ³  AMP SENS  ³';
S19='³              ³Num  Shape³ Num Cents³ Num  Hz ³ Num Sec ³       ³  Tremelo   ³';
S20='ÃÄÄÄÄÄÂÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄ´ M1    M5   ³';
S21='³Pitch³VIBRATO ³          ³          ³         ³         ³       ³ M2    M6   ³';
S22='ÃÄÄÄÄÄÅÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄ´ M3    M7   ³';
S23='³Level³TREMELO ³          ³         %³         ³         ³       ³ M4    M8   ³';
S24='ÀÄÄÄÄÄÁÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ';

K3 ='ÃÄÄÄÄÄÄÁÄÂÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÂÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄ´';
K4 ='³DCO ENV ³ S1  S2  S3  S4  S5  S6  S7  S8 ³ ENVELOPE RANGE   ³ KEY VELOCITY   ³';
K5 ='ÃÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄ´';
K6 ='³Rate    ³000 000                         ³Depth Range³      ³Level Sens ³    ³';
K7 ='ÃÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´Depth Shift³      ³Level Curve³    ³';
K8 ='³Level[+]³                                ÃÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄ´Rate  Sens ³    ³';
K9 ='³Level[-]³                                ³ KEY FOLLOW       ³           ³    ³';
K10='ÃÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄ´';
K11='³Sust-End³                                ³ Step  ³   1   2   3   4   5   6   ³';
K12='ÃÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´ Key   ³ 000 000 000 000 000 000   ³';
K13='³ E *    ³                                ³ Level ³                           ³';
K14='ÀÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ';

K15='ÚÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÂÄÄÄÄÄÂÄÄÄÄÄÂÄÄÄÄÄÂÄÄÄÄÄÂÄÄÄÄÄÂÄÄÄÄÄÂÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿';
K16='³ DETUNE    ³Mod 1³Mod 2³Mod 3³Mod 4³Mod 5³Mod 6³Mod 7³Mod 8³                 ³';
K17='ÃÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÅÄÄÄÄÄÅÄÄÄÄÄÅÄÄÄÄÄÅÄÄÄÄÄÅÄÄÄÄÄÅÄÄÄÄÄÅÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´';
K18='³ Fixed     ³     ³     ³     ³     ³     ³     ³     ³     ³                 ³';
K19='³ Harmonic  ³     ³     ³     ³     ³     ³     ³     ³     ³                 ³';
K20='³ Octave    ³     ³     ³     ³     ³     ³     ³     ³     ³                 ³';
K21='³ Note      ³     ³     ³     ³     ³     ³     ³     ³     ³                 ³';
K22='³ Fine      ³     ³     ³     ³     ³     ³     ³     ³     ³                 ³';
K23='³ Pol+Range ³     ³     ³     ³     ³     ³     ³     ³     ³                 ³';
K24='ÀÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÁÄÄÄÄÄÁÄÄÄÄÄÁÄÄÄÄÄÁÄÄÄÄÄÁÄÄÄÄÄÁÄÄÄÄÄÁÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ';

T3 ='ÃÄÄÄÂÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄ´';
T4 ='³   ³     DCA ENVELOPE                            ³ KEY FOLLOW      ³VELOCITY ³';
T5 ='³MOD³STEP 1   2   3   4   5   6   7   8 SS ED Ampl³ 1  2  3  4  5  6³SenCurAmp³';
T6 ='ÃÄÂÄÁÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÂÄÄÂÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄ´';
T7 ='³1³Rate³                               ³  ³  ³    ³C1 C2 C3 C4 C5 C6³00  1 00 ³';
T8 ='³ ³Lev ³                               ³  ³  ³    ³00 00 00 00 00 00³         ³';
T9 ='³2³Rate³                               ³  ³  ³    ³                 ³         ³';
T10='³ ³Lev ³                               ³  ³  ³    ³                 ³         ³';
T11='³3³Rate³                               ³  ³  ³    ³                 ³         ³';
T12='³ ³Lev ³                               ³  ³  ³    ³                 ³         ³';
T13='³4³Rate³                               ³  ³  ³    ³                 ³         ³';
T14='³ ³Lev ³                               ³  ³  ³    ³                 ³         ³';
T15='³5³Rate³                               ³  ³  ³    ³                 ³         ³';
T16='³ ³Lev ³                               ³  ³  ³    ³                 ³         ³';
T17='³6³Rate³                               ³  ³  ³    ³                 ³         ³';
T18='³ ³Lev ³                               ³  ³  ³    ³                 ³         ³';
T19='³7³Rate³                               ³  ³  ³    ³                 ³         ³';
T20='³ ³Lev ³                               ³  ³  ³    ³                 ³         ³';
T21='³8³Rate³                               ³  ³  ³    ³                 ³         ³';
T22='³ ³Lev ³                               ³  ³  ³    ³                 ³         ³';
T23='ÀÄÁÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÁÄÄÁÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÙ';

H1 ='ÚÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄ¿';
H2 ='³PATCH ³Number [00] ³BankCode [A-1] ³Name  012345678901  ³Page [0]  ³ Res [L] ³';

F1 ='KEYS: [PgUpDwn] [N]ext [P]rev [E]dit [UDLR arrow] [Q]uit [1][2][3] Page        ';

R1 ='ÚÄÄ¿ ÚÄ¿     ';
R2 ='³M1ÃÄ´XÃÄ¿   ';
R3 ='ÀÄÄÙ ÀÂÙ ³   ';
R4 ='      ³  ÃÄ X';
R5 ='ÚÄÄ¿  ³  ³   ';
R6 ='³M2ÃÄÄÁÄÄÙ   ';
R7 ='ÀÄÄÙ         ';

P1 ='ÚÄÄ¿         ';
P2 ='³M3ÃÄÄ¿      ';
P3 ='ÀÄÄÙ  ³      ';
P4 ='      ³  ÚÄ X';
P5 ='ÚÄÄÂÄÄÙ  ³   ';
P6 ='³M4ÃÄÄÄÄÄÙ   ';
P7 ='ÀÄÄÙ         ';

M1 ='ÚÄÄ¿         ';
M2 ='³M5ÃÄÄÄÄÄ¿   ';
M3 ='ÀÄÄÙ     ³   ';
M4 ='         ÃÄ X';
M5 ='ÚÄÄ¿     ³   ';
M6 ='³M6ÃÄÄÄÄÄÙ   ';
M7 ='ÀÄÄÙ         ';

VAR
  M12Str1, M34Str1, M56Str1, M78Str1  : Str20   ;  { RING PHASE MIX        }
  M12Str2, M34Str2, M56Str2, M78Str2  : Str20   ;  { M1(M2) M1+M2 M1+M1xM2 }
  M34EP,   M56EP,   M78EP             : BOOLEAN ;  { Ext Phase ON OFF      }
  W1,W2,W3,W4,W5,W6,W7,W8             : Str10   ;  { Sine,Saw1-5,Noise1-2  }
  Wn1,Wn2,Wn3,Wn4,Wn5,Wn6,Wn7,Wn8     : BYTE    ;  { Number of wave 1-8    }
  OctaveStr                           : Str10   ;  { -2,-1,0,+1,+2         }
  TotalVolume                         : BYTE    ;  { 0-99                  }
  VibWave, TremWave                   : Str10   ;  { Wave 1-4              }
  VibWaveNum, TremWaveNum             : BYTE    ;  { Wave Number 1-4       }
  VibDepth, TremDepth                 : BYTE    ;  { 00-99                 }
  VibRate, TremRate                   : BYTE    ;  { 00-99                 }
  VibDelay, TremDelay                 : BYTE    ;  { 00-99                 }
  VibDepth1, TremDepth1               : REAL    ;  { Cents and %           }
  VibRate1, TremRate1                 : REAL    ;  { Herz frequency        }
  VibDelay1, TremDelay1               : REAL    ;  { Seconds               }
  VibMulti, TremMulti                 : BOOLEAN ;  { 0 Off 1 On            }
  AmpSensitivity                      : BArr8   ;  { 0-7 Tremelo M1-M8     }
  ORate, OLev                         : BArr8   ;  { DCORate+Level S1-S8   }
  Oed                                 : Str2    ;  { S1-S8 DCO ED Point    }
  Oss                                 : Str2    ;  { S1-S8 DCO SS Point    }
  OedNum, OssNum                      : BYTE    ;  { 1-8                   }
  DCOLevRange                         : BYTE    ;  { 0-63 DCO Level Shift  }
  DCOLevShft                          : Str10   ;  { Narrow Wide           }
  AM1ed,AM2ed,AM3ed,AM4ed,
  AM5ed,AM6ed,AM7ed,AM8ed             : Str2    ;  { S1-S8 DCA ED point    }
  AM1ss,AM2ss,AM3ss,AM4ss,
  AM5ss,AM6ss,AM7ss,AM8ss             : Str2    ;  { S1-S8 DCA SS point    }
  AM18TotDepth                        : BArr8   ;  { M1-M8 DCA Tot Depth   }
  FineT, NoteT,  PolT,
  FixT,  RangeT, OctT                 : BArr8   ;  { Detuning Params       }
  HarmT                               : ARRAY [1..8] OF REAL               ;
  FixTStr, PolTStr, HarmTStr          : ARRAY [1..8] OF Str10              ;
  DCOKFKey                            : ARRAY [1..6] OF Str3               ;
  DCOKFLev                            : ARRAY [1..6] OF BYTE               ;
  DCOKFCurve, DCOKFSens               : BYTE    ;  { DCO Key Follow        }
  ResHi                               : BOOLEAN ;  { True 0-127 else 0-99  }
  Rec                                 : WORD    ;
  Choice                              : CHAR    ;
  Key                                 : INTEGER ;
  Page                                : INTEGER ;
{-----------------------------------------------------------------}
{       VOICEDIT                                                  }
{          GETVIBRATOINFO                                         }
{          GETTREMELOINFO                                         }
{          GETDCOINFO                                             }
{          GETDCAINFO                                             }
{          GETOCTAVEINFO                                          }
{          GETWAVEINFO                                            }
{             GETWAVE                                             }
{          GETMXMYINFO                                            }
{          DISPHEADERFOOTER                                       }
{               EXTRACTMXMYCONFIG                                 }
{          DISPLAYP1                                              }
{          FILLP1                                                 }
{               DISPLAYMIX                                        }
{               DISPLAYPHASE                                      }
{               DISPLAYRING                                       }
{               DISPLAYEXTPHASE                                   }
{               DISPLAYMODNUM                                     }
{          DISPLAYP2                                              }
{          FILLP2                                                 }
{          DISPLAYP3                                              }
{          FILLP3                                                 }
{          DOKEY                                                  }
{          GETKEY                                                 }
{          GETINFO                                                }
{-----------------------------------------------------------------}
{-------------------------------}
{ Display Header and Footer     }
{-------------------------------}
PROCEDURE DispHeaderFooter ( Page : CHAR ) ;

BEGIN

  TEXTCOLOR ( Yellow )    ;
  CLRSCR                  ;
  WRITE  ( H1,NL,H2 )     ;
  GOTOXY ( 1,25 )         ;
  TEXTCOLOR ( LightGray ) ;
  WRITE  ( F1 )           ;
  TEXTCOLOR ( White )                                   ;
  GOTOXY (17,2 ) ; WRITE ( UnitSelect:2 )               ;
  GOTOXY (32,2 ) ; WRITE ( UnitID[1], '-', UnitID[2] )  ;
  GOTOXY (44,2 ) ; WRITE ( Patch^[Rec].PName:12 )       ;
  GOTOXY (65,2 ) ; WRITE ( Page )                       ;
  GOTOXY (76,2 ) ; WRITE ( 'L' )                        ;
  TEXTCOLOR ( Yellow )                                  ;
  GOTOXY ( 1,3 )                                        ;
END ;
{-------------------------------------------------------}
{ Display Pages 1, 2 and 3                              }
{-------------------------------------------------------}
PROCEDURE DisplayP1 ;
BEGIN
  DispHeaderFooter ( '1' ) ;
  WRITE ( S3, NL,S4, NL,S5, NL,S6, NL,S7, NL,S8, NL,S9, NL,S10,NL,S11,NL ) ;
  WRITE ( S12,NL,S13,NL,S14,NL,S15,NL,S16,NL,S17,NL,S18,NL,
          S19,NL,S20,NL,S21,NL,S22,NL,S23,NL,S24 ) ;
END ;

PROCEDURE DisplayP2 ;
BEGIN
  DispHeaderFooter ( '2' ) ;
  WRITE ( K3, NL,K4, NL,K5, NL,K6, NL,K7, NL,K8, NL,K9, NL ) ;
  WRITE ( K10,NL,K11,NL,K12,NL,K13,NL,K14,NL,K15,NL,K16,NL,K17,NL,K18,NL,
          K19,NL,K20,NL,K21,NL,K22,NL,K23,NL,K24 ) ;
END ;

PROCEDURE DisplayP3 ;
BEGIN
  DispHeaderFooter ( '3' ) ;
  WRITE ( T3, NL,T4, NL,T5, NL,T6, NL,T7, NL,T8, NL,T9, NL ) ;
  WRITE ( T10,NL,T11,NL,T12,NL,T13,NL,T14,NL,T15,NL,T16,NL,T17,NL,T18,NL,
          T19,NL,T20,NL,T21,NL,T22,NL,T23 ) ;
END ;
{-------------------------------}
{ Get Detuning Parameters       }
{-------------------------------}
PROCEDURE GetDetuneInfo ;
VAR
  A, B        : BYTE    ;
  i, n        : INTEGER ;
  T           : INTEGER ;
  AStr        : Str10   ;

CONST
  Harm : ARRAY [1..32] OF REAL =
 (0   ,1    ,12/8 ,2    ,18/8 ,20/8 ,22/8 ,3    ,25/8 ,26/8 ,
 27/8 ,28/8 ,29/8 ,30/8 ,31/8 ,4    ,65/16,66/16,67/16,68/16,
 69/16,70/16,71/16,72/16,73/16,74/16,75/16,76/16,77/16,78/16,79/16,5 ) ;
 {----------------------------------------}
 { Notes =  x/12                          }
 {         2     with x = Note 0 - 11     }
 {----------------------------------------}
 Note  : ARRAY [0..11] OF REAL =
 (1,1.0595,1.1225,1.1892,1.2599,1.3348,1.4142,1.4983,1.5874,1.6818,1.7818,
 1.8877 ) ;

BEGIN
  FOR i := 1 TO 8 DO
  BEGIN
    A := ( Patch^[Rec].Detune[i].Fine ) AND $FC         ; { Leave D2-D7 }
    FineT [i] := A SHR 2                                ; { Move D2-D7:D0-D5}
    B         := ( Patch^[Rec].Detune[i].Note ) AND $7F ; { Leave D0-D6 }
    A         := ( Patch^[Rec].Detune[i].Pol  ) AND $80 ; { Leave D7    }
    PolT  [i] := A SHR 7                                ; { Now 0-1     }
    FixT  [i] := ( Patch^[Rec].Detune[i].Fix  ) AND $03 ; { Leave D0-D1 }
    IF FixT [i] = 0 THEN BEGIN
                           FixTStr [i] := 'Off' ;
                           IF PolT [i] = 0 THEN PolTStr [i] := ' [-]' ;
                           IF PolT [i] = 1 THEN PolTStr [i] := ' [+]' ;
                         END                                          ;
    IF FixT [i] > 0 THEN BEGIN
                           FixTStr [i] := 'On'                           ;
                           IF FixT [i] = 2 THEN PolTStr [i] := ' [x1]'   ;
                           IF FixT [i] = 3 THEN PolTStr [i] := 'x1|16'   ;
                         END                                             ;

    OctT  [i] := B DIV 12       ; { Convert Octaves 0-5 }
    NoteT [i] := B MOD 12       ; { Leave Notes 0-11    }
    END                         ;

    FOR n := 1 TO 8 DO
    BEGIN
      i := 0                              ;
      REPEAT i := i+1 ;
      UNTIL (Harm[i] > OctT[n]) OR (i>32) ;
      T := i                              ;
      i := -1                             ;
      REPEAT i:= i+1                      ;
      UNTIL (Note[ NoteT[n] ]+OctT[n]-1 <= Harm[i+T]) OR (i>11) ;
      HarmT[n] := i+T-1                                         ;
      STR ( HarmT[n]:1:0, AStr )                                ;
      IF PolT [n] = 0 THEN HarmTStr [n] := '1|'+ AStr
                      ELSE HarmTStr [n] := AStr                 ;
    END                                                         ;

END ;
{-------------------------}
{ Get DCO Key Follow Info }
{-------------------------}
PROCEDURE GetDCOKFInfo ;
VAR
  A : BYTE       ;
  i, n : INTEGER ;
  AStr : Str10   ;

BEGIN
  FOR i := 1 TO 6 DO
  BEGIN
    DCOKFLev [i] := 63-HI(Patch^[Rec].DCOKF[i]) ; { 2nd byte ot the word }

    A := LO(Patch^[Rec].DCOKF[i])               ; { 1st part }
    n := 0 ;
    WHILE A > 11 DO BEGIN
                      A := A-12 ;
                      INC (n)   ;
                    END         ;
    DCOKFKey[i] := KeyArr [A]   ;
    STR ( n , AStr )            ;
    DCOKFKey[i][3] := AStr[1]   ;
  END                           ;

  DCOKFSens  := Patch^[Rec].DCOKF1 AND $1F ; { Leave D0-D5 }
  DCOKFCurve := Patch^[Rec].DCOKF1 AND $E0 ; { Leave D5-D7 }
  DCOKFCurve := (DCOKFCurve SHR 5) + 1     ; { Curve 1-8   }

END ;
{-------------------------------}
{ Get DCO Env Info              }
{-------------------------------}
PROCEDURE GetDCOInfo            ;
VAR
  A, B, i : INTEGER          ;
  F       : LONGINT          ;
  Z       : BYTE             ;

BEGIN
  A := 30                       ;
  B := 39                       ;
  OssNum := 10                  ; { Put OssNum out of Range 1-8 }
  OedNum := 10                  ;

  FOR i := 1 TO 8 DO BEGIN
                       ORate [i] := Patch^[Rec].X[A] ; { 00-7F : 00-99   }
                       OLev  [i] := Patch^[Rec].X[B] ; { 00-7F : -63-+63 }
                       IF OLev [i] > 127 THEN
                          BEGIN
                            STR ( i:2, Oss )            ;
                            OssNum := i                 ;
                            Oss  [1] := 'S'             ;
                            OLev [i] := OLev[i] AND $7F ;
                          END                           ;
                       IF NOT ResHi THEN
                          BEGIN
                            F := ( ORate [i] * 100 ) DIV 128  ;
                            ORate [i] := F                    ;
                          END                                 ;
                       A := A+18                          ;
                       B := B+18                          ;
                     END                                  ;

  A := Patch^[Rec].DCOEd                               ;
  A := A SHR 4                                         ;
  STR ( (A+1):2, Oed )                                 ;
  OedNum := A+1                                        ;
  Oed [1] := 'S'                                       ;

  Z           := Patch^[Rec].DCODepth AND $3F             ; { Leave D0-D5 }
  DCOLevRange := ( 63 - Z )                               ; { 0=63 63=0   }
  Z           := Patch^[Rec].DCODepth AND $80             ; { Leave D7    }
  IF A=1 THEN DCOLevShft:='Wide' ELSE DCOLevShft:='Narrow';

END ;

{-------------------------------}
{ Get DCA Level + Rate Info     }
{-------------------------------}
PROCEDURE GetDCAInfo ;

VAR
 A, i, G : INTEGER ;

PROCEDURE GetDCARateLevel ( VAR B, C: BArr8; VAR D, E: Str2 ; Y: INTEGER ) ;

VAR A, i : INTEGER ;
    X    : BYTE    ;
    F    : LONGINT ;

BEGIN
  E := '  '   ;
  A := 22 + Y ;
  FOR i := 1 TO 8 DO BEGIN
                       B [i] := Patch^[Rec].X[A] AND $7F  ; { Leave D0-D6 }
                       C [i] := Patch^[Rec].X[A+9] ;
                       IF C [i] > 127 THEN BEGIN
                                             STR ( i:2, E )        ;
                                             E[1] := 'S'           ;
                                             C[i] := C[i] AND $7F  ;
                                           END                     ;
                       { Convert 0-127 to 0-99                     }
                       IF NOT ResHi THEN
                          BEGIN
                            F := ( B[i] * 100 ) DIV 128  ;
                            B[i] := F                    ;
                            F := ( C[i] * 100 ) DIV 128  ;
                            C[i] := F                    ;
                          END                            ;
                       A := A+18                         ;
                     END                                 ;

   X := Patch^[Rec].DCAed[Y]     ;
   X := X AND $F0                ; { Leave D4-D7 }
   X := X SHR 4                  ;
   STR ( (X+1):2, D )            ;
   D[1] := 'S'                   ;

END ;

BEGIN

   GetDCARateLevel ( ARateM1, ALevM1, AM1ed, AM1ss, 0 ) ;
   GetDCARateLevel ( ARateM2, ALevM2, AM2ed, AM2ss, 1 ) ;
   GetDCARateLevel ( ARateM3, ALevM3, AM3ed, AM3ss, 2 ) ;
   GetDCARateLevel ( ARateM4, ALevM4, AM4ed, AM4ss, 3 ) ;
   GetDCARateLevel ( ARateM5, ALevM5, AM5ed, AM5ss, 4 ) ;
   GetDCARateLevel ( ARateM6, ALevM6, AM6ed, AM6ss, 5 ) ;
   GetDCARateLevel ( ARateM7, ALevM7, AM7ed, AM7ss, 6 ) ;
   GetDCARateLevel ( ARateM8, ALevM8, AM8ed, AM8ss, 7 ) ;

   FOR i := 1 TO 8 DO BEGIN
                        G := Patch^[Rec].DCATotD[i] AND $7F ; { Leave D0-D6 }
                        G := 127-G                          ; { 0=99 7F=0   }
                        IF NOT ResHi THEN G:=(G*100) DIV 128; { 0-7F=0-99   }
                        AM18TotDepth [i] := G               ;
                      END                                   ;
END ;
{-------------------------------}
{ Get VibratoInfo               }
{-------------------------------}
PROCEDURE GetVibratoInfo ;

CONST
  WaveArr: ARRAY [0..3] OF Str10 = ('Triangle','Saw-Up','Saw-Down','Square');
VAR
  A : BYTE ;

BEGIN
  WITH Patch^[Rec].Vibrato DO
  BEGIN
     A := Multi AND $08                                    ; { Leave D3 }
     IF A = 1 THEN VibMulti := TRUE ELSE VibMulti := FALSE ;
     A := Wave AND $03                                     ; { Leave D0,D1 }

     VibWave    := WaveArr [A]                             ; { 0-3        }
     VibWaveNum := A + 1                                   ; { 1-4        }
     VibDepth   := Depth                                   ;
     VibRate    := Rate                                    ;
     VibDelay   := Delay                                   ;

     VibDepth1 := Depth*15     ; { 99 = 1485 cents = 1.49 semi-tones }
     VibRate1  := Rate / 1.8   ; { 99 = 55 Herz frequency            }
     VibDelay1 := Delay / 18   ; { 99 = 5.5 seconds                  }
  END                          ; { WITH                              }
END                                                                  ;
{-------------------------------}
{ Get Tremelo                   }
{-------------------------------}
PROCEDURE GetTremeloInfo ;

CONST
  WaveArr: ARRAY [0..3] OF Str10 = ('Triangle','Saw-Up','Saw-Down','Square');
VAR
  A, i : BYTE ;

BEGIN
  WITH Patch^[Rec].Tremelo DO
  BEGIN
     A := Multi AND $08                                    ; { Leave D3 }
     IF A = 1 THEN TremMulti:= TRUE ELSE TremMulti:= FALSE ;
     A := Wave AND $03                                     ; { Leave D0,D1 }
     TremWave    := WaveArr [A]                            ; { 0-3        }
     TremWaveNum := A + 1                                  ; { 1-4        }
     TremDepth   := Depth                                  ;
     TremRate    := Rate                                   ;
     TremDelay   := Delay                                  ;

     TremDepth1 := Depth / 2.2  ; { 99 = 45 percent        }
     TremRate1  := Rate  / 1.8  ; { 99 = 55 Herz           }
     TremDelay1 := Delay / 18   ; { 99 = 5.5 seconds       }
     {------------------------}
     { AMP Sensitivity        }
     {------------------------}
     FOR i := 1 TO 8 DO
     AmpSensitivity[i] := Patch^[Rec].AmpSens[i] AND $07   ; { Leave D0-D2 }

  END                                                      ;
END                                                        ;

{-------------------------------}
{ Get Octave Information        }
{-------------------------------}
PROCEDURE GetOctaveInfo  ;
VAR
  A : BYTE ;
BEGIN
  A := Patch^[Rec].Octave AND $E0   ; { Leave D5-D7 }
  OctaveStr := '??'                 ;
  IF A = $C0 THEN OctaveStr := '+2' ;
  IF A = $A0 THEN OctaveStr := '+1' ;
  IF A = $80 THEN OctaveStr := '+O' ;
  IF A = $20 THEN OctaveStr := '-1' ;
  IF A = $00 THEN OctaveStr := '-2' ;
END ;

{-------------------------------}
{ Get M1-M8 Wave Shape          }
{-------------------------------}
PROCEDURE GetWAveInfo ( VAR W1,W2,W3,W4,W5,W6,W7,W8         : Str10  ;
                        VAR Wn1,Wn2,Wn3,Wn4,Wn5,Wn6,Wn7,Wn8 : BYTE ) ;
VAR
  C  : BYTE  ;

PROCEDURE GetWave (VAR StrA,StrB: Str10; VAR A,B: BYTE; C: BYTE );
BEGIN
  A    := C AND $07                ; { Leave D0-D2 }
  StrA := WaveArr1 [A]             ;
  B    := C AND $38                ; { Leave D3-D5 }
  B    := B SHR 3                  ; { D3-D5=D0-D2 }
  StrB := WaveArr1 [B]             ;
  INC (A)                          ; { WaveNumber 1-8 }
  INC (B)                          ;
END                                ;

BEGIN
  GetWave ( W1, W2, Wn1, Wn2, Patch^[Rec].M12Wave ) ;  { Modules 1 and 2 }
  GetWave ( W3, W4, Wn3, Wn4, Patch^[Rec].M34Wave ) ;
  GetWave ( W5, W6, Wn5, Wn6, Patch^[Rec].M56Wave ) ;
  GetWave ( W7, W8, Wn7, Wn8, Patch^[Rec].M78Wave ) ;  { Modules 7 and 8 }
END                                                 ;
{-------------------------------------------------------------------}
{ Get MxMy Configuration Info                                       }
{-------------------------------------------------------------------}
PROCEDURE GetMxMyInfo ( VAR M12Str1, M34Str1, M56Str1, M78Str1 : Str20 ;
                        VAR M12Str2, M34Str2, M56Str2, M78Str2 : Str20 ;
                        VAR M34EP,  M56EP,  M78EP  : BOOLEAN ) ;
VAR
  a   : BYTE               ;
  Rec : WORD               ;

{--------------------------}
{ Get Ring Phase Mix Info  }
{--------------------------}
PROCEDURE ExtractMxMyConfig ( VAR AStr,BStr: Str20; A: BYTE; B: BOOLEAN ) ;

CONST
  RingStr      : Str20 = 'M +M xM ' ;
  PhaseStr     : Str20 = 'M (M )'   ;
  MixStr       : Str20 = 'M +M '    ;

VAR
  ExtCode      : CHAR               ;
  CStr         : Str20              ;

BEGIN
  ExtCode := BStr[3] ;

  A := A AND $C0 ;  { Mask out all except D7 D6 i.e. 80 40 or 00 }
  A := A SHR 4   ;  { Move hi nibble to lo = 08 or 04 or 00      }

  IF A = 8 THEN BEGIN
                AStr        := 'RING '    ;
                RingStr[2]  := BStr[2]    ;
                RingStr[5]  := BStr[1]    ;
                RingStr[8]  := BStr[2]    ;
                CStr        := RingStr    ;  { M2 + M1 x M2 }
              END                         ;

  IF A = 4 THEN BEGIN
                AStr        := 'PHASE'    ;
                PhaseStr[2] := BStr[2]    ;
                PhaseStr[5] := BStr[1]    ;
                CStr        := PhaseStr   ;  { M2 ( M1 )   }
              END                         ;

  IF A = 0 THEN BEGIN
                AStr        := 'MIX'      ;
                MixStr[2]   := BStr[1]    ;
                MixStr[5]   := BStr[2]    ;
                CStr        := MixStr     ;
              END                         ;

   IF B THEN BStr := ExtCode + '(' + CStr + ')' ELSE BStr := CStr ;
   BStr := BStr + #26 + SUCC ( ExtCode )                          ;

END                                       ; { ExtractMxMyConfig }

BEGIN
  Rec := UnitSelect                                              ;

  a := Patch^[Rec].ExtPhase    { External Phase On Off }         ;

  IF (a AND 01) > 0 THEN M34EP := TRUE ELSE M34EP := FALSE     ;
  IF (a AND 02) > 0 THEN M56EP := TRUE ELSE M56EP := FALSE     ;
  IF (a AND 04) > 0 THEN M78EP := TRUE ELSE M78EP := FALSE     ;

  M12Str2 := '12@'  { '@'+1='A' }                                                  ;
  ExtractMxMyConfig ( M12Str1, M12Str2, Patch^[Rec].M1M2Conf, FALSE ) ;
  M34Str2 := '34A'                                                    ;
  ExtractMxMyConfig ( M34Str1, M34Str2, Patch^[Rec].M3M4Conf, M34EP ) ;
  M56Str2 := '56B'                                                    ;
  ExtractMxMyConfig ( M56Str1, M56Str2, Patch^[Rec].M5M6Conf, M56EP ) ;
  M78Str2 := '78C'                                                    ;
  ExtractMxMyConfig ( M78Str1, M78Str2, Patch^[Rec].M7M8Conf, M78EP ) ;

END ;
{---------------------}
{ Display Params P2   }
{---------------------}
PROCEDURE FillP2 ;

VAR i, X, Y, n : INTEGER ;

BEGIN
  Y := 6  ;
  X := 11 ;
  n := 0  ;
  TEXTCOLOR ( Cyan )     ;
  FOR i := 1 TO 8 DO
      BEGIN
        IF (OedNum=i) OR (OssNum=i) THEN
            BEGIN
              GOTOXY ( X, Y+5 )                  ;
              TEXTCOLOR ( White )                ;
              IF OssNum=OedNum THEN WRITE ('S+E')
                 ELSE BEGIN IF OedNum=i THEN WRITE ('End')
                                        ELSE WRITE ('Sus'); END;
                 TEXTCOLOR ( LightGray )            ;
            END                                  ;
        GOTOXY ( X, Y  ) ; WRITE ( ORate[i]:3 )  ;
        {----------------------------------------}
        { 0 - 63 = (-64) - (-1)                  }
        { 64-127 = +0    - + 63                  }
        {----------------------------------------}
        IF OLev[i]>63 THEN BEGIN { +Number 63-127}
        GOTOXY ( X, Y+2) ;
        WRITE ('+', (OLev[i]-64):2) ; END     ;
        IF OLev[i]<64 THEN BEGIN { -Number 0-63  }
        GOTOXY ( X, Y+3) ;
        WRITE ('-',(64-OLev[i]):2) ; END      ;

        X := X + 4                               ;
      END                                        ;

      TEXTCOLOR ( Cyan )                         ;
      GOTOXY ( 56,6 ) ; WRITE ( DCOLevShft  )    ; { Wide-Narrow }
      GOTOXY ( 56,7 ) ; WRITE ( DCOLevRange )    ; { 0 - 63      }

      X := 15 ; Y := 18 ;
      FOR n:=1 TO 8 DO BEGIN GOTOXY (X,Y); WRITE (FixTStr[n])  ;X:=X+6; END;
      X := 15 ; INC ( Y ) ;
      FOR n:=1 TO 8 DO BEGIN GOTOXY (X,Y); WRITE (HarmTStr[n]) ;X:=X+6; END;
      X := 15 ; INC (Y)   ;
      FOR n:=1 TO 8 DO BEGIN GOTOXY (X,Y); WRITE (OctT[n])     ;X:=X+6; END;
      X := 15 ; INC (Y)   ;
      FOR n:=1 TO 8 DO BEGIN GOTOXY (X,Y); WRITE (NoteT[n])    ;X:=X+6; END;
      X := 15 ; INC (Y)   ;
      FOR n:=1 TO 8 DO BEGIN GOTOXY (X,Y); WRITE (FineT[n])    ;X:=X+6; END;
      X := 14 ; INC (Y)   ;
      FOR n:=1 TO 8 DO BEGIN GOTOXY (X,Y); WRITE (PolTStr[n])  ;X:=X+6; END;

      X := 53 ; Y := 12 ;
      FOR i := 1 TO 6 DO
      BEGIN
        GOTOXY ( X,Y  ) ; WRITE ( DCOKFKey [i] ) ;
        GOTOXY ( X,Y+1) ; WRITE ( DCOKFLev [i] ) ;
        X := X+4                                 ;
      END                                        ;
      GOTOXY ( 76,6 ) ; WRITE ( DCOKFSens )      ;
      GOTOXY ( 76,7 ) ; WRITE ( DCOKFCurve)      ;
END ;
{---------------------}
{ Display Params P3   }
{---------------------}
PROCEDURE FillP3 ;
VAR
  X, Y : INTEGER ;

PROCEDURE WriteDCA ( B, C: BArr8; X, Y: INTEGER; S, T: Str2; Q: BYTE ) ;
VAR i : INTEGER ;

BEGIN
  FOR i := 1 TO 8 DO
  BEGIN
    GOTOXY ( X,Y   ) ; WRITE ( B [i]:3 ) ;
    TEXTCOLOR ( LightGray )              ;
    GOTOXY ( X,Y+1 ) ; WRITE ( C [i]:3 ) ;
    TEXTCOLOR ( Cyan )                   ;
    X := X+4         ;
  END                ;
  TEXTCOLOR ( White );
  GOTOXY ( X,   Y+1 ); WRITE ( S:2 ) ;
  GOTOXY ( X+3, Y+1 ); WRITE ( T:2 ) ;
  TEXTCOLOR ( Cyan ) ;
  GOTOXY ( X+6, Y   ); WRITE ( Q:3 ) ;

END ;

BEGIN
  TEXTCOLOR ( Cyan )                                    ;

  Y := 7  ;  X := 9                                     ;
  WriteDCA (ARateM1, ALevM1, X, Y, AM1ss, AM1ed, AM18TotDepth[1] ); INC(Y,2);
  WriteDCA (ARateM2, ALevM2, X, Y, AM2ss, AM2ed, AM18TotDepth[2] ); INC(Y,2);
  WriteDCA (ARateM3, ALevM3, X, Y, AM3ss, AM3ed, AM18TotDepth[3] ); INC(Y,2);
  WriteDCA (ARateM4, ALevM4, X, Y, AM4ss, AM4ed, AM18TotDepth[4] ); INC(Y,2);
  WriteDCA (ARateM5, ALevM5, X, Y, AM5ss, AM5ed, AM18TotDepth[5] ); INC(Y,2);
  WriteDCA (ARateM6, ALevM6, X, Y, AM6ss, AM6ed, AM18TotDepth[6] ); INC(Y,2);
  WriteDCA (ARateM7, ALevM7, X, Y, AM7ss, AM7ed, AM18TotDepth[7] ); INC(Y,2);
  WriteDCA (ARateM8, ALevM8, X, Y, AM8ss, AM8ed, AM18TotDepth[8] ); INC(Y,2);

END ;
{------------------------}
{ Display Params P1      }
{------------------------}
PROCEDURE FillP1         ;

VAR i, X, Y, n : INTEGER ;

PROCEDURE DisplayMix ( XPos : INTEGER ) ;
BEGIN  GOTOXY ( Xpos, 4 ) ; WRITE (M1)   ;
       GOTOXY ( Xpos, 5 ) ; WRITE (M2)   ;
       GOTOXY ( Xpos, 6 ) ; WRITE (M3)   ;
       GOTOXY ( Xpos, 7 ) ; WRITE (M4)   ;
       GOTOXY ( Xpos, 8 ) ; WRITE (M5)   ;
       GOTOXY ( Xpos, 9 ) ; WRITE (M6)   ;
       GOTOXY ( Xpos, 10) ; WRITE (M7)   ; END ;

PROCEDURE DisplayPhase ( XPos : INTEGER ) ;
BEGIN  GOTOXY ( Xpos, 4 ) ; WRITE (P1)   ;
       GOTOXY ( Xpos, 5 ) ; WRITE (P2)   ;
       GOTOXY ( Xpos, 6 ) ; WRITE (P3)   ;
       GOTOXY ( Xpos, 7 ) ; WRITE (P4)   ;
       GOTOXY ( Xpos, 8 ) ; WRITE (P5)   ;
       GOTOXY ( Xpos, 9 ) ; WRITE (P6)   ;
       GOTOXY ( Xpos, 10) ; WRITE (P7)   ; END ;

PROCEDURE DisplayRing ( XPos : INTEGER ) ;
BEGIN  GOTOXY ( Xpos, 4 ) ; WRITE (R1)   ;
       GOTOXY ( Xpos, 5 ) ; WRITE (R2)   ;
       GOTOXY ( Xpos, 6 ) ; WRITE (R3)   ;
       GOTOXY ( Xpos, 7 ) ; WRITE (R4)   ;
       GOTOXY ( Xpos, 8 ) ; WRITE (R5)   ;
       GOTOXY ( Xpos, 9 ) ; WRITE (R6)   ;
       GOTOXY ( Xpos, 10) ; WRITE (R7)   ; END ;

PROCEDURE DisplayExtPhase ( XPos : INTEGER )   ;
BEGIN
  GOTOXY ( XPos, 6 ) ; WRITE ( '³' ) ;
  GOTOXY ( XPos, 5 ) ; WRITE ( 'Ú' ) ;
  GOTOXY ( XPos+1,5) ; WRITE ( 'Ä' ) ;
  GOTOXY ( XPos+2,5) ; WRITE ( '´' ) ;
END                                  ;
PROCEDURE DisplayModNum ;
BEGIN
  GOTOXY ( 4,5 ) ; WRITE ( 'M1' ) ;
  GOTOXY ( 4,9 ) ; WRITE ( 'M2' ) ;
  GOTOXY (18,5 ) ; WRITE ( 'M3' ) ;
  GOTOXY (18,9 ) ; WRITE ( 'M4' ) ;
  GOTOXY (32,5 ) ; WRITE ( 'M5' ) ;
  GOTOXY (32,9 ) ; WRITE ( 'M6' ) ;
  GOTOXY (46,5 ) ; WRITE ( 'M7' ) ;
  GOTOXY (46,9 ) ; WRITE ( 'M8' ) ;

  GOTOXY (15,7 ) ; WRITE ( 'A' ) ;
  GOTOXY (29,7 ) ; WRITE ( 'B' ) ;
  GOTOXY (43,7 ) ; WRITE ( 'C' ) ;
  GOTOXY (57,7 ) ; WRITE ( 'D' ) ;
END                              ;
{--------------------------------}
BEGIN                   { FillP1 }
  TEXTCOLOR (White) ;
  GOTOXY (74,13) ; WRITE ( TotalVolume:2 )              ;
  GOTOXY (74,14) ; WRITE ( OctaveStr:2 )                ;

  IF M12Str1[1] = 'R' THEN DisplayRing  (3) ;
  IF M12Str1[1] = 'P' THEN DisplayPhase (3) ;
  IF M12Str1[1] = 'M' THEN DisplayMix   (3) ;

  IF M34Str1[1] = 'R' THEN DisplayRing  (17) ;
  IF M34Str1[1] = 'P' THEN DisplayPhase (17) ;
  IF M34Str1[1] = 'M' THEN DisplayMix   (17) ;

  IF M56Str1[1] = 'R' THEN DisplayRing  (31) ;
  IF M56Str1[1] = 'P' THEN DisplayPhase (31) ;
  IF M56Str1[1] = 'M' THEN DisplayMix   (31) ;

  IF M78Str1[1] = 'R' THEN DisplayRing  (45) ;
  IF M78Str1[1] = 'P' THEN DisplayPhase (45) ;
  IF M78Str1[1] = 'M' THEN DisplayMix   (45) ;

  IF M34EP THEN DisplayExtPhase ( 15 ) ;
  IF M56EP THEN DisplayExtPhase ( 29 ) ;
  IF M78EP THEN DisplayExtPhase ( 43 ) ;
  {--------------------------------------}
  { Write RING-MIX and M1+M2xM2          }
  {--------------------------------------}
  TEXTCOLOR ( Cyan )                     ;
  GOTOXY ( 4,7 ) ; WRITE ( M12Str1 )     ;
  GOTOXY (18,7 ) ; WRITE ( M34Str1 )     ;
  GOTOXY (32,7 ) ; WRITE ( M56Str1 )     ;
  GOTOXY (46,7 ) ; WRITE ( M78Str1 )     ;

  GOTOXY ( 3,11) ; WRITE ( M12Str2 )     ;
  GOTOXY (17,11) ; WRITE ( M34Str2 )     ;
  GOTOXY (31,11) ; WRITE ( M56Str2 )     ;
  GOTOXY (45,11) ; WRITE ( M78Str2 )     ;
  {--------------------------------------}
  { Display OutPut Combination           }
  {--------------------------------------}
  IF NOT M34EP THEN BEGIN GOTOXY ( 64,4 ) ; WRITE ('A') ; END ;
  IF NOT M56EP THEN BEGIN GOTOXY ( 64,6 ) ; WRITE ('B') ; END ;
  IF NOT M78EP THEN BEGIN GOTOXY ( 64,8 ) ; WRITE ('C') ; END ;
                          GOTOXY ( 64,10) ; WRITE ('D') ;
  {-----------------------------}
  { M1-M8                       }
  {-----------------------------}
  DisplayModNum                 ;
  {-----------------------------}
  { Display Mx Wave Type        }
  {-----------------------------}
  GOTOXY (  4,13 )  ; WRITE ( 'M1 ', Wn1, ' ', W1 ) ;
  GOTOXY (  4,14 )  ; WRITE ( 'M2 ', Wn2, ' ', W2 ) ;
  GOTOXY ( 18,13 )  ; WRITE ( 'M3 ', Wn3, ' ', W3 ) ;
  GOTOXY ( 18,14 )  ; WRITE ( 'M4 ', Wn4, ' ', W4 ) ;
  GOTOXY ( 32,13 )  ; WRITE ( 'M5 ', Wn5, ' ', W5 ) ;
  GOTOXY ( 32,14 )  ; WRITE ( 'M6 ', Wn6, ' ', W6 ) ;
  GOTOXY ( 46,13 )  ; WRITE ( 'M7 ', Wn7, ' ', W7 ) ;
  GOTOXY ( 46,14 )  ; WRITE ( 'M8 ', Wn8, ' ', W8 ) ;
  {-----------------------------}

  GOTOXY (17,21); WRITE (VibWaveNum,  ' ', VibWave       ) ;
  GOTOXY (17,23); WRITE (TremWaveNum, ' ', TremWave      ) ;
  GOTOXY (29,21); WRITE (VibDepth:2,  ' ', VibDepth1:6:1 ) ;
  GOTOXY (29,23); WRITE (TremDepth:2, ' ', TremDepth1:4:1) ;
  GOTOXY (40,21); WRITE (VibRate:2,   ' ', VibRate1:5:1  ) ;
  GOTOXY (40,23); WRITE (TremRate:2,  ' ', TremRate1:5:1 ) ;
  GOTOXY (50,21); WRITE (VibDelay:2,  ' ', VibDelay1:4:1 ) ;
  GOTOXY (50,23); WRITE (TremDelay:2, ' ', TremDelay1:4:1) ;
  GOTOXY (61,21); IF VibMulti  THEN WRITE ('On') ELSE WRITE ( 'Off' ) ;
  GOTOXY (61,23); IF TremMulti THEN WRITE ('On') ELSE WRITE ( 'Off' ) ;
  {-----------------------}
  { Amp Sensitivity 0-7   }
  {-----------------------}
  Y := 20 ; X := 71 ;
  FOR i := 1 TO 4 DO BEGIN
                  GOTOXY (   X,Y ) ; WRITE (AmpSensitivity  [i]:1) ;
                  GOTOXY ( X+6,Y ) ; WRITE (AmpSensitivity[i+4]:1) ;
                  INC ( Y )        ; END                           ;

  TEXTCOLOR ( White ) ;

END ;
{--------------------}
{ GetVoiceInfo       }
{--------------------}
PROCEDURE GetInfo ;

BEGIN
    GetMxMyInfo ( M12Str1, M34Str1, M56Str1, M78Str1 ,
                  M12Str2, M34Str2, M56Str2, M78Str2 ,
                  M34EP,   M56EP,   M78EP            ) ;
    GetWaveInfo ( W1,W2,W3,W4,W5,W6,W7,W8,Wn1,Wn2,Wn3,Wn4,Wn5,Wn6,Wn7,Wn8 );
    GetOctaveInfo  ;
    TotalVolume :=  $63 - Patch^[Rec].TotLevel         ;
    GetVibratoInfo                                     ;
    GetTremeloInfo                                     ;
    GetDCAInfo                                         ;
    GetDCOInfo                                         ;
    GetDCOKFInfo                                       ;
    GetDetuneInfo                                      ;
END ;

{--------------------------}
{ ReadKey                  }
{--------------------------}
FUNCTION GetKey ( C1 : CHAR ) : INTEGER ;

VAR C2 : CHAR ;

BEGIN
  GetKey := 0 ;

  IF C1> #0 THEN CASE C1 OF '1' : GetKey := 1 ;  { Page 1           }
                            '2' : GetKey := 2 ;  { Page 2           }
                            '3' : GetKey := 3 ;  { Page 3           }
                    #27,'X','Q' : GetKey := 4 ;  { Quit             }
                            'E' : GetKey := 5 ;  { Edit Mode        }
                            'R' : GetKey := 6 ;  { Toggle HiRes Mode}
                        #13,'D' : GetKey := 7 ;  { Next Patch       }
                            'U' : GetKey := 8 ;  { Previous Patch   }
                            'G' : GetKey := 9 ;  { Graphics         }
                             END                                    ;

  IF C1= #0 THEN BEGIN
                 C2 := UPCASE (READKEY) ;        { Special Keys       }
                 CASE C2 OF #73 : GetKey := 8 ;  { PageUp Prev Patch  }
                            #81 : GetKey := 7 ;  { PageDwn Next Patch }
                 END                                                  ;
                 END                                                  ;
END ;
{------------------------}
{ DoKey                  }
{------------------------}
PROCEDURE DoKey ( N : INTEGER ) ;

BEGIN
    CASE N OF 1 : BEGIN DisplayP1     ;
                        Page := 1     ;
                        FillP1        ;  END  ;
              2 : BEGIN DisplayP2     ;
                        Page := 2     ;
                        FillP2        ;  END  ;
              3 : BEGIN DisplayP3     ;
                        Page := 3     ;
                        FillP3        ;  END  ;
              4 : Exit                ;
              5 : ;
              6 : BEGIN ResHi := ResHi XOR TRUE                    ;
                        GOTOXY ( 76,2 )                            ;
                        TEXTCOLOR ( White )                        ;
                        IF ResHi THEN WRITE ('H') ELSE WRITE ('L') ;
                        TEXTCOLOR ( Cyan )                         ;
                        GetInfo                                    ;
                        IF Page=1 THEN FillP1  ;
                        IF Page=2 THEN FillP2  ;
                        IF Page=3 THEN FillP3  ;
                  END                          ;
              7 : BEGIN IF Rec <= UnitCount THEN
                                       BEGIN
                                       INC (Rec)          ;
                                       INC (UnitSelect)   ; END ;
                  GetA1H8Number (UnitSelect)  ;
                  DisplayP1                   ;
                  GetInfo                     ;
                  FillP1                      ; END ;
              8 : BEGIN IF Rec > 1 THEN BEGIN
                                        DEC (Rec)         ;
                                        DEC (UnitSelect)  ; END ;
                  GetA1H8Number (UnitSelect)  ;
                  DisplayP1                   ;
                  GetInfo                     ;
                  FillP1                      ; END ;
              9 : DoGraphics                  ;
              END                                               ;
END ;
{------------------------------------------------------}
{ Voice Edit                                           }
{------------------------------------------------------}
BEGIN
  Rec := UnitSelect                                    ;
  ResHi := FALSE                                       ;
  Choice := '1'                                        ; { Display Page 1 }
  GetInfo                                              ;

  REPEAT
    Key    := GetKey ( Choice )                        ;
    DoKey ( Key )                                      ;
    Choice := UPCASE (READKEY)                         ;
  UNTIL (Choice='Q') OR (Key=4)                        ;

END ;

END .