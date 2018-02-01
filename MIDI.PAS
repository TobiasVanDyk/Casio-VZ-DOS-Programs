
PROGRAM Midi          ;

{--------------------------------------------}
{ Use the UNITS : MIDI1.PAS ( MIDI1.TPU )    }
{                 MIDI3.PAS ( MIDI3.TPU )    }
{ Midi1 includes the file MIDI2.PAS          }
{ Midi3 includes the file MIDI4.PAS          }
{--------------------------------------------}

USES Midi1, Midi3, DOS, CRT ;

{---------------------------}
{ Initialise UnitParameters }
{---------------------------}
PROCEDURE SetUpUnit         ;

BEGIN
  IF (UnitType=1) OR (UnitType=2) THEN
      BEGIN
        UnitClass := 'P'       ;
        UnitSize  := PatchSize ;
        UnitName  := 'Patches ';
      END                                                           ;

  IF (UnitType=3) OR (UnitType=4) THEN
      BEGIN
        UnitClass := 'O'       ;
        UnitSize  := OpMemSize ;
        UnitName  := 'OpMemory';
      END                                                           ;
END                                                                 ;


{-----------------------------------}
{ File Services                     }
{-----------------------------------}
PROCEDURE OpenFiles (VAR FileName : FILE; T : BYTE ) ;

VAR
  FileExt        : STRING [4] ;
  FileNLen       : INTEGER    ;
  NameOK         : BOOLEAN    ;
  ExtVal         : INTEGER    ;
  ExtStr         : Str10      ;
  N              : BYTE       ;
{-----------------------------}
{ Do Filename Interpretation  }
{-----------------------------}
FUNCTION CheckName : BOOLEAN  ;

VAR
  i, E             : INTEGER    ;

BEGIN
  FileNLen := LENGTH ( FileN )                                ;
  FOR i := 0 TO FileNLen DO FileN [i] := UPCASE ( FileN [i] ) ;

  FileExt := COPY ( FileN, FileNLen - 3, 4 ) ;
  ExtStr  := COPY ( FileN, FileNLen - 1, 2 ) ;
  VAL ( ExtStr, ExtVal, E )                  ;

  CheckName := (( FileExt[2] IN CharX ) AND ( ExtVal < 65 ) AND ( E=0 ) ) ;

  UnitCountChange := ExtVal                                  ;
END  ;
{-----------------------------}
BEGIN  { Open File }

NameOK := FALSE               ;

REPEAT

  FileExt := '. 01'                         ;
  ExtStr  :=   '01'                         ;
  ClrLine ( 19 )                            ;
  {-----------------------------------------}
  { LOAD + EXTENDED LOAD                    }
  {-----------------------------------------}
  IF (T=0) OR (T=4) THEN
  BEGIN
    WRITE   ('Filename for Load : '); READLN (FileN) ;
    NameOK := CheckName                              ;

    IF NameOK THEN
    BEGIN
      IF Dir = 'Current' THEN  ASSIGN ( FileName, FileN )
                             ELSE  ASSIGN ( FileName, Dir+'\'+FileN ) ;
      {$I-}  RESET ( FileName, 1 )        ;     { Blockread size = 1 byte }
      {$I+}
      IF IORESULT<>0 THEN BEGIN
                            ClrLine ( 20 ) ; WRITE ('File not found..')  ;
                            DELAY (1000)                                 ;
                            ClrLine ( 20 ) ;                             ;
                            NameOK := FALSE                              ;
                          END                                            ;
                      END                                                ;

      IF T=0 THEN
      BEGIN
        UnitClass := FileExt [2]                                     ;
        IF ExtVal < 64 THEN UnitType  := 1 ELSE UnitType := 2        ;
        UnitCount := ExtVal                                          ;
      END                                                            ;

      IF T=4 THEN
      BEGIN
        IF FileExt [2] <> UnitClass THEN NameOK := FALSE ;
        N := XLoadPos + ExtVal                           ;
        IF (N>UnitCount) AND (N<65) THEN UnitCount := N  ;
      END                                                ;

      IF (UnitClass = 'O') THEN INC ( UnitType , 2 )     ;

      SetUpUnit                                          ;

  END                               ;     { T=0 }
  {---------------------------------}
  { SAVE                            }
  {---------------------------------}
  IF T=1 THEN
  BEGIN
    WRITE   ('FileName for save : ') ; READLN (FileN) ;

    IF ( LENGTH ( FileN ) < 9 ) THEN NameOK := TRUE   ;

    FileExt[2] := UnitClass          ;

    IF (UnitType=2) OR (UnitType=4) THEN
                        BEGIN
                           STR ( UnitCount:2, ExtStr )              ;
                           IF UnitCount < 10 THEN ExtStr[1] := '0'  ;
                           FileExt [3] := ExtStr [1]                ;
                           FileExt [4] := ExtStr [2]                ;
                        END                                         ;

    FileN  := FileN + FileExt       ;

    IF Dir='Current' THEN  ASSIGN ( FileName, FileN )
                           ELSE  ASSIGN ( FileName, Dir+'\'+FileN ) ;
    REWRITE (  FileName, 1 )          ; { 1 Parameter = Blockread 1 byte }

  END                                 ; { T=1 }
  {----------------------------------}
  { APPEND                           }
  {----------------------------------}
  IF T=2 THEN
  BEGIN

    WRITE   ('FileName to append to : ') ; READLN (FileN) ;

    NameOK := CheckName                                   ;

    IF (UnitType=1) OR (UnitType=3) THEN INC ( ExtVal )            ;
    IF (UnitType=2) OR (UnitType=4) THEN INC ( ExtVal, UnitCount ) ;

    IF ExtVal > 99 THEN NameOK := FALSE                            ;
    STR ( ExtVal:2, ExtStr )                                       ;
    IF ExtVal < 10 THEN ExtStr[1] := '0'                           ;

    IF NameOK THEN BEGIN
                     IF Dir='Current' THEN ASSIGN ( FileName, FileN )
                        ELSE  ASSIGN ( FileName, Dir+'\'+FileN )    ;

                     FileExt[0] := #2                       ;
                     FileExt    := FileExt + ExtStr         ;
                     FileN [0]  := CHAR (FileNLen - 4)      ;
                     FileN := FileN + FileExt               ;

                     IF Dir='Current' THEN RENAME ( FileName, FileN )
                        ELSE  RENAME ( FileName, Dir+'\'+FileN )    ;

                     RESET   (  FileName, 1  )              ;
                     SEEK    (  FileName, UnitSize )        ;
                   END                                      ;

  END                                                       ;  { T=2 }
UNTIL NameOK                                                ;

END ;
{---------------------------------------------------------}
{ Save Files                                              }
{---------------------------------------------------------}
PROCEDURE SaveFile (VAR FileName : FILE ; RecNum : BYTE  ) ;

VAR
    Count, n : INTEGER ;

BEGIN

  REPEAT
  { -------------------- Write Data                                      }
  CASE UnitType OF
  1 : BLOCKWRITE (FileName, Patch^[RecNum], PatchSize, Count)              ;
  2 : BLOCKWRITE (FileName, Patch^[1],      PatchSize*64, Count)           ;
  3 : BLOCKWRITE (FileName, OpMem^[RecNum], OpMemSize, Count)              ;
  4 : BLOCKWRITE (FileName, OpMem^[1],      OpMemSize*64, Count)           ;
  END                                                                      ;

  UNTIL Count > 0                          ;

  ClrLine ( 20 )                           ;
  WRITE  ('Saved : ', Count , ' bytes. ' ) ;
  DELAY (1000)                             ;

  CLOSE ( FileName )                       ;

END ;
{---------------------------------------------------------}
{ Load Files                                              }
{ RecNum = 0 : Load at Pos 1 and clear all Existing Units }
{---------------------------------------------------------}
PROCEDURE LoadFile ( VAR FileName : FILE ; RecNum : BYTE ) ;

VAR
    Count, n : INTEGER ;
    Str1     : Str10   ;
    i        : WORD    ;

BEGIN

  Count := 0 ;

  REPEAT

    IF RecNum = 0 THEN
    BEGIN
      RecNum := 1                  ;
      UnitCount := UnitCountChange ;
      ClearPatch (0)               ; { Clear all }
    END                            ;

    UnitSelect  := RecNum          ;

    { ------------------- Read Data read from the file     }
    CASE UnitClass OF
    'P': BLOCKREAD (FileName,Patch^[RecNum],UnitCountChange*PatchSize,Count);
    'O': BLOCKREAD (FileName,OpMem^[RecNum],UnitCountChange*OpMemSize,Count);
    END                                                                     ;

  UNTIL Count > 0 ;

  ClrLine ( 20 )                       ;
  WRITE ('Loaded : ',Count,' bytes. ') ;
  DELAY (1000)                         ;

  CLOSE ( FileName )                   ;

  IF UnitClass = 'P' THEN UnitSelectName := Patch^ [RecNum].PName ;
  IF UnitClass = 'O' THEN UnitSelectName := OpMem^ [RecNum].OName ;

END ;
{----------------------------}
{ Rename Files               }
{----------------------------}
PROCEDURE RenameFile         ;

VAR
  AStr       : STRING [30]   ;
  OldFile,
  NewFile    : STRING [20]   ;
  i, Space   : INTEGER       ;
  ErrorCode  : INTEGER       ;

BEGIN

  i     := 0                                          ;
  Space := 0                                          ;
  ClearMainMenu (18,22)                               ;
  WRITE  ( 'Enter [ OLD-Filename NEW-Filename ] : ' ) ;
  READLN ( AStr )                                     ;

  REPEAT
    IF AStr [i] = ' ' THEN Space := i             ;
    INC ( i )                                     ;
  UNTIL ( Space > 1 ) OR  ( i > LENGTH ( AStr ))  ;

  OldFile := COPY ( AStr, 1, Space-1 )            ;
  NewFile := COPY ( AStr, Space+1, LENGTH (AStr)) ;

  GOTOXY ( 10, 20 )                               ;
  {-----------------------------------------}
  { Erase any existing NEW Name Files First }
  {-----------------------------------------}
  {$I-}
  IF Dir='Current' THEN  ASSIGN ( FileName, NewFile )
                         ELSE  ASSIGN ( FileName, Dir+'\'+NewFile ) ;
  CLOSE  ( FileName          )                         ;
  ERASE  ( FileName          )                         ;
  IF IORESULT = 0
     THEN WRITE  ('Duplicate ', NewFile, ' deleted..') ;
  {$I+}
  DELAY  ( 1000 )                                      ;
  {$I-}
  IF Dir='Current' THEN BEGIN
                                ASSIGN ( FileName, OldFile )  ;
                                RENAME ( FileName, NewFile )  ;
                               END
                         ELSE  BEGIN
                                 ASSIGN ( FileName, Dir+'\'+OldFile );
                                 RENAME ( FileName, Dir+'\'+NewFile );
                               END                                         ;
  ErrorCode := IORESULT        ;
  {$I+}
  IF ErrorCode <> 0 THEN
  BEGIN
    ClrLine ( 20 )               ;
    WRITE ('Error in Rename.. ') ;
    DELAY ( 1000 )               ;
  END                            ;

  FileN := NewFile               ;

END ;

{----------------------------}
{ Delete Files               }
{----------------------------}
PROCEDURE DeleteFile         ;

VAR
  DelFile    : STRING [20]   ;
  ErrorCode  : INTEGER       ;

BEGIN

  ClearMainMenu (18,22)                           ;
  WRITE  ( 'Enter Filename to delete : ' )        ;
  READLN ( DelFile )                              ;

  ClrLine ( 20 )        ;
  {---------------------}
  { Erase existing File }
  {---------------------}
  {$I-}
  IF Dir='Current' THEN  ASSIGN ( FileName, DelFile )
                         ELSE  ASSIGN ( FileName, Dir+'\'+DelFile ) ;
  CLOSE  ( FileName          )                         ;
  ERASE  ( FileName          )                         ;
  ErrorCode := IORESULT                                ;
  {$I+}
  IF ErrorCode <> 0
     THEN WRITE  ('File : ', DelFile, ' not found..')  ;

  DELAY  ( 1000 )                                      ;
END ;
{----------------------------}
{ Directory of Files         }
{----------------------------}
PROCEDURE FileList ( Dir : Str20 ) ;             { Directory List }

VAR
  n, p       : BYTE      ;
  TotalSize  : LONGINT   ;
  SearchFile : SEARCHREC ;
  FileStr    : STRING[40];
  FileName   : FILE      ;
  StartAddr  : WORD      ;
  SizeAddr   : WORD      ;
  Path       : PATHSTR   ;
  Directory  : DIRSTR    ;
  Name       : NAMESTR   ;
  Ext        : EXTSTR    ;
  TypeStr    : STRING[20];
  SizeStr    : Str10     ;
  E, SizeNum : INTEGER   ;
  i          : INTEGER   ;
  MidiSearch : BOOLEAN   ;
  MidiFound  : BOOLEAN   ;

BEGIN
  n         := 1     ;
  p         := 1     ;
  TotalSize := 0     ;
  MidiSearch:= FALSE ;

  ClearMainMenu (18,22)                                         ;
  WRITE  ( 'Search pattern: Default ( Midi only : *M* ) : ')    ;

  READLN (      FileStr )                                       ;

  GOTOXY ( 10,19) ;
  WRITE ('Current Path  : [ ', Dir, ' ]' )                ;

  FOR i := 1 TO LENGTH ( FileStr ) DO
                FileStr [i] := UPCASE ( FileStr [i] )           ;

  IF FileStr = '' THEN FileStr := '*M*'            ;  { Default }

  IF FileStr = '*M*' THEN BEGIN
                             MidiSearch := TRUE                 ;
                             FileStr    := '*.*'                ;
                          END                                   ;

  IF Dir <> 'Current' THEN FileStr := Dir + '\' + FileStr ;

  PutLine ( '[ENTER] for next page.... ' , 21 )               ;

  ClearMainMenu (10,16)                                       ;
  WRITE
  ('Num Filename.Ext   Size  Description          Content ' ) ;
  {'### NNNNNNNN.EEE.SSSSSS..12345678901234567890.NNN     ' }

  WINDOW ( 9,11,69,16 )                           ;
  TEXTCOLOR (White)                               ;

  FINDFIRST ( FileStr, 0, SearchFile )             ;  { Find 1st File  }
  FSPLIT ( SearchFile.Name, Directory, Name, Ext ) ;  { Split PathName }
  {------------------------------------------}
  { Main Display Loop                        }
  {------------------------------------------}
  WHILE DOSERROR = 0 DO
  BEGIN
    TypeStr   := ' '                                           ;
    MidiFound := FALSE                                         ;
    {----------------------------------------------------------}
    { Check if Midi or Voice File                              }
    {----------------------------------------------------------}
    IF ( LENGTH (Ext) = 4 ) AND ( Ext[2] IN CharX ) AND
       ( Ext[3] IN NumX )   AND ( Ext[4] IN NumX )  THEN
    BEGIN
      CASE Ext[2] OF 'P' : TypeStr := 'Patch ( Voice )  : '    ;
                     'O' : TypeStr := 'Operation Memory : '    ;
                     'M' : TypeStr := 'Multi-Area Setup : '    ;
                     'X' : TypeStr := 'Midi Bulk Data   : '    ;
      END                                                      ;
      IF TypeStr <> ' ' THEN BEGIN
                               MidiFound := TRUE               ;
                               SizeStr := COPY (Ext, 3, 2 )    ;
                               VAL  ( SizeStr, SizeNum, E )    ;
                             END                               ;
    END                                                        ;
    {----------------------------------------------------------}
    { Display File Information                                 }
    {----------------------------------------------------------}
    IF ( MidiSearch AND MidiFound ) OR ( NOT MidiSearch ) THEN
    BEGIN
      WRITE (n:4, ' ', Name:8, Ext:4, ' ', SearchFile.Size:6 )   ;
      IF MidiFound THEN WRITE (' ', TypeStr:20, ' ', SizeNum:3 ) ;
      TotalSize := TotalSize + SearchFile.Size                   ;

      IF p < 6 THEN WRITELN ;
      IF p = 6 THEN BEGIN
                       p := 0            ;
                       Choice := READKEY ;
                       WRITELN           ;
                     END                 ;
      INC (n)                                         ;
      INC (p)                                         ;
    END                                               ;

    FINDNEXT ( SearchFile )                           ;
    FSPLIT ( SearchFile.Name, Directory, Name, Ext )  ;  { Split PathName }

  END ;

  WINDOW (1,1,80,25)   ;
  GOTOXY ( 10,21 )     ;
  WRITE ( 'List Size   :  ', TotalSize:8, ' '           ) ;
  WRITE (' Disk Free : ',    DISKFREE(0):8, ' bytes..' )  ;
  Choice := READKEY                                       ;

END ;

{-----------------------}
{ MainMenu              }
{-----------------------}
PROCEDURE MainMenu                  ;

CONST
  S  = '       '                    ;
  S1 = S + 'ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿' ;
  S2 = S + '³            Ü    Ü Ü       Ü                        SoftSound ³' ;
  S3 = S + '³   ÛÛßßÛßßÛ Ü ÜÜÜÛ Ü Ü   Ü Ü ÜÜÜ ÜÜÜ                          ³' ;
  S4 = S + '³   ÛÛ  Û  Û Û ÛÜÜÛ Û Û Ü Û Û ÛÜÜ ÛÜÜ PATCH LIBRARIAN          ³' ;
  S5 = S + '³   ÛÛ  Û  ß          ßßßßß   ÜÜÛ ÛÜÜ VOICE EDITOR             ³' ;
  S6 = S + '³   ÛÛ                                MIDI  ANALYZER           ³' ;
  S7 = S + 'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ' ;
  S8 = S + 'ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿' ;
  S9 = S + '³ MAIN MENU Drive                              Edit    Clear   ³' ;
  S10= S + '³           Select                             Name    Quit    ³' ;
  S11= S + '³           Files                              Print           ³' ;
  S12= S + '³           Upload                             Help            ³' ;
  S13= S + '³           DownLoad                                           ³' ;
  S14= S + '³ Memory:   Compare                                            ³' ;
  S15= S + '³           Machine                        Select Option :     ³' ;
  S16= S + 'ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´' ;
  S17= S + '³                                                              ³' ;
  S18= S + '³                                                              ³' ;
  S19= S + '³                                                              ³' ;
  S20= S + '³                                                              ³' ;
  S21= S + '³                                                              ³' ;
  S22= S + 'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ' ;

  L1 =       'UPLOAD : Enter Sub-Option ( 1 - 8 ) : '                       ;
  L2 =       '                                                            ' ;
  L3 =       '[PATCH] [OP MEM] [OP MEM+PATCH] [MULTI CH] [OTHER MIDI DATA]' ;
  L4 =       '1 Solo  3 Solo   5 Multi:64+64  6 Solo     7 Sys Exclusive  ' ;
  L5 =       '2 Multi 4 Multi                            8 Midi Data      ' ;

  F1 =       'FILE SERVICES :  Enter Sub-Option ( S - U )   :        '      ;
  F2 =       '[ Save ]   [ Load ]   [ Append save ]  [ Extend load ] '      ;
  F3 =       '[ Rename ] [ Delete ] [ File list ]    [ User Dir ]    '      ;

  X1 =       'EXTENDED LOAD: Enter Sub-Option ( 1 - 3 ) : '                ;
  X2 =       'Load Position: 1 Start   2 Specified Pos    3 End         '  ;
  X3 =       'Note : Overwrite any existing unit at specified position. '  ;
  X4 =       '       Create a unit space in Edit Mode for insertion.    '  ;

  E1 =       'EDIT : Enter Sub-Option  :  '                                ;
  E2 =       'InterUnit : [Buffer Display] [Parameter]  [Hex Dump]      '  ;
  E3 =       'InterBank : [Insert] [Delete] [Copy] [Move] [Xchange]     '  ;
  E4 =       'Unit = single unit edit  Bank = Unit movement inside Bank '  ;

  D1 =       'DOWNLOAD : Enter Sub-Option ( 1 - 3 ) :  '                   ;
  D2 =       '1 Selected Patch   2 Patch Bank [64]   3 Hex Byte Xmit    '  ;

  LF0 = #10     ; { LF        }
  LF1 = #10#8   ; { LF + 1.BS }
  LF2 = #10#8#8 ; { LF + 2.BS }

VAR
  Choice1, Choice2 : CHAR  ;

{-------------------------}
{ Display upload options  }
{-------------------------}
PROCEDURE UploadSubMenu   ;

BEGIN
  TEXTCOLOR (Yellow)                                          ;
  PutLine ( L2, 19 )            ;
  PutLine ( L3, 20 )            ;
  PutLine ( L4, 21 )            ;
  PutLine ( L5, 22 )            ;
  TEXTCOLOR (White)                                           ;
  GOTOXY ( 10, 21 )            ; WRITE  ('1',LF1,'2')         ;
  GOTOXY ( 18, 21 )            ; WRITE  ('3',LF1,'4')         ;
  GOTOXY ( 27, 21 )            ; WRITE  ('5')                 ;
  GOTOXY ( 42, 21 )            ; WRITE  ('6')                 ;
  GOTOXY ( 53, 21 )            ; WRITE  ('7',LF1,'8')         ;
  PutLine ( L1, 18 )           ;
END                                                           ;
{---------------------------}
{ Display download options  }
{---------------------------}
PROCEDURE DownLoadSubMenu   ;

BEGIN
  TEXTCOLOR (Yellow)                                          ;
  PutLine ( L2, 19 )           ;
  PutLine ( D2, 20 )           ;
  TEXTCOLOR (White)                                           ;
  GOTOXY ( 10, 20 )            ; WRITE  ('1')                 ;
  GOTOXY ( 29, 20 )            ; WRITE  ('2')                 ;
  GOTOXY ( 48, 20 )            ; WRITE  ('3')                 ;
  PutLine ( D1, 18 )           ;
END                                                           ;
{-----------------------}
{ Display edit options  }
{-----------------------}
PROCEDURE EditSubMenu   ;

BEGIN
  TEXTCOLOR (Yellow)                                          ;
  PutLine ( L2, 19 )           ;
  PutLine ( E2, 20 )           ;
  PutLine ( E3, 21 )           ;
  PutLine ( E4, 22 )           ;
  TEXTCOLOR (White)                                           ;
  GOTOXY ( 23, 20 )            ; WRITE  ('B',LF1,'I')         ;
  GOTOXY ( 40, 20 )            ; WRITE  ('P')                 ;
  GOTOXY ( 53, 20 )            ; WRITE  ('H')                 ;
  GOTOXY ( 32, 21 )            ; WRITE  ('D')                 ;
  GOTOXY ( 41, 21 )            ; WRITE  ('C')                 ;
  GOTOXY ( 48, 21 )            ; WRITE  ('M')                 ;
  GOTOXY ( 55, 21 )            ; WRITE  ('X')                 ;
  PutLine ( E1, 18 )           ;
END                                                           ;
{-------------------------------------}
{ Display extended File load options  }
{-------------------------------------}
PROCEDURE ExLoadSubMenu               ;

VAR Choice : Str10                    ;
    Ok     : BOOLEAN                  ;
    E, i   : INTEGER                  ;

BEGIN
  Ok := FALSE                                                 ;

  TEXTCOLOR (Yellow)                                          ;
  PutLine ( L2, 19 )           ;
  PutLine ( X2, 20 )           ;
  PutLine ( X3, 21 )           ;
  PutLine ( X4, 22 )           ;
  TEXTCOLOR (White)                                           ;
  GOTOXY ( 25, 20 )            ; WRITE  ('1')         ;
  GOTOXY ( 35, 20 )            ; WRITE  ('2')         ;
  GOTOXY ( 54, 20 )            ; WRITE  ('3')         ;
  {---------------------------------------------------}
  { Get XLoadPos : 1-64                               }
  {     XLoadOption : 0 Clear All 1 Delete > 1 Delete }
  {---------------------------------------------------}
  REPEAT

    PutLine ( X1, 18 )              ;
    Choice [1] := UPCASE (READKEY)  ;

    IF ( Choice[1] IN ['1','2','3'] ) THEN
         BEGIN
           Ok := TRUE ;
           XLoadPos    := ORD ( Choice [1] ) - ORD ('0') ; { 1, 2, 3 }

           IF Choice[1] = '3' THEN XloadPos := UnitCount         ;

           IF Choice[1] = '2' THEN      { Load at specified position }
           REPEAT
             FOR i := 19 TO 21 DO
             BEGIN
               GOTOXY ( 10,i ) ; WRITE (L2) ;
             END                            ;
             GOTOXY ( 10,21 )                                    ;
             WRITE  ( 'Enter Position (1-', UnitCount, ') : ' )  ;
             READLN (Choice)                                     ;
             VAL ( Choice, XLoadPos, E )                         ;
           UNTIL (E=0) AND (XLoadPos>0) AND (XLoadPos<=UnitCount);

    END    { End If }                                               ;
  UNTIL Ok                                                          ;
END                                                                 ;
{--------------------------------}
{ Display File Services options  }
{--------------------------------}
PROCEDURE FilesSubMenu           ;

BEGIN
  TEXTCOLOR (Yellow)                                          ;
  PutLine ( L2, 19 )           ;
  PutLine ( F2, 20 )           ;
  PutLine ( F3, 21 )           ;
  TEXTCOLOR (White)                                           ;
  GOTOXY ( 12, 20 )            ; WRITE  ('S',LF1,'R')         ;
  GOTOXY ( 23, 20 )            ; WRITE  ('L',LF1,'D')         ;
  GOTOXY ( 34, 20 )            ; WRITE  ('A',LF1,'F')         ;
  GOTOXY ( 51, 20 )            ; WRITE  ('E',LF1,'U')         ;
  PutLine ( F1, 18 )           ;
END                                                           ;

BEGIN                      { Main Menu }

 REPEAT
   TEXTBACKGROUND ( Blue ) ;
   TEXTCOLOR (Yellow)      ;
   WINDOW (1,1,80,25)      ;
   CLRSCR                  ;

   WRITE
 ( NL, S1 ,NL,S2 ,NL,S3 ,NL,S4 ,NL,S5 ,NL,S6 ,NL,S7 ,NL,S8 ,NL,S9 ,NL,
   S10,NL,S11,NL,S12,NL,S13,NL,S14,NL,S15,NL,S16,NL,S17,NL,S18,NL,
   S19,NL,S20,NL,S21,NL,S22 ) ;

   GOTOXY ( 20,10 ) ; TEXTCOLOR (White) ;
   WRITE ( 'D',LF1,'S',LF1,'F',LF1,'U',LF0,'o',LF1,LF1,'M' ) ;
   GOTOXY ( 24,15 ) ; WRITE ('ar')                           ;
   GOTOXY ( 55,10 ) ;
   WRITE ( 'E',LF1,'N',LF1,'P',LF1,'H' )                     ;
   GOTOXY ( 63,10 ) ;
   WRITE ( 'C',LF1,'Q' )                                     ;
   {---------------------------------------------}
   { Display Status and Selected Options         }
   {---------------------------------------------}
   IF UnitSelect > 0 THEN
      BEGIN
        IF UnitClass='P' THEN UnitSelectName := Patch^[UnitSelect].PName    ;
        IF UnitClass='O' THEN UnitSelectName := OpMem^[UnitSelect].OName    ;
      END                                                                   ;

   TEXTCOLOR ( Cyan )                                                     ;
   GOTOXY ( 29,10 ); WRITE ( '[', Dir, ']')                               ;
   GOTOXY ( 29,11 ); WRITE ( '[' , UnitSelect , ':', UnitCount,
                             ' ', UnitSelectName,' (',UnitID,')',']' )    ;
   GOTOXY ( 29,12 ); WRITE ( '[', FileN, ']')                             ;
   GOTOXY ( 29,15 );
   IF UnitClass = 'P' THEN WRITE ( '[', PSearch.Pname, ']' )              ;
   IF UnitClass = 'O' THEN WRITE ( '[', OSearch.Oname, ']' )              ;
   GOTOXY ( 29,16 ); WRITE ( '[', ManName, ' : ', ManIDStr, ' ]' )        ;
   {------------------------------}
   { Display Memory               }
   {------------------------------}
   GOTOXY ( 10,16 )               ;
   WRITE  ( '[', MAXAVAIL:5, ']' );

   TEXTCOLOR ( White )            ;
   GOTOXY ( 51,16 )               ;
   WRITE ( 'Select Option : ' )   ;

   Choice1 := UPCASE (READKEY)                                  ;
   IF Choice1 <> #13 THEN WRITE (Choice1)                       ;

   CASE Choice1 OF
   'U' : BEGIN                         { Upload-Read Midi Data  }
           UploadSubMenu                                        ;
           Choice2  := UPCASE (READKEY) ; WRITE  ( Choice2 )    ;
           UnitType := ( ORD (Choice2) ) - 48                   ;
           SetUpUnit                                            ;
           ClearMainMenu ( 18,22 )                              ;
           IF (UnitType>0) AND (UnitType<9) THEN
              DoSinglePatchRead ( UnitType )                    ;
         END                                                    ;
   'O' : BEGIN          { Download-Write Midi Data     }
           ClearMainMenu ( 18,22 )                                 ;
           DownLoadSubMenu                                         ;
           Choice2  := UPCASE (READKEY) ; WRITE  ( Choice2 )       ;
           UnitType := ORD (Choice2) - 48                          ;
           SetUpUnit                                               ;
           CASE Choice2 OF '1': DoBulkWrite  ;       { SinglePatch }
                           '2': DoBulkWrite  ;       { Bankpatch   }
                           '3': DoWrite      ;       { Hex Send    }
           END                                                     ;
         END                                           ;
   'N' : BEGIN          { (Re) Name Unit               }
           RenamePatch ( UnitSelect )                 ;
         END                                           ;
   'C' : BEGIN          { Clear Patch Contents         }
           ClearPatch ( UnitSelect )                  ;
         END                                           ;
   'S' : BEGIN          { Download-Write Midi Data     }
           SelectPatch ( 1 )                      ;
         END                                           ;
   'D' : BEGIN          { Drive selectiom for Midi Data}
           SelectDrive                                 ;
         END                                           ;
   'M' : BEGIN          { Machine-Manufacturer Select  }
           SelectManufacturer                          ;
         END                                           ;
   'A' : BEGIN                { Search-Compare Execute }
           ClearMainMenu ( 18,22 )                                ;
           WRITE (' Selected Unit compared with stored Unit....') ;
           DoSearch ( UnitSelect )                    ;
         END                                           ;
   'R' : BEGIN                { Search-Compare Store   }
           ClearMainMenu ( 18,22 )                                ;
           WRITE (' Selected Unit stored for Search-Compare....') ;
           DELAY ( 500 )                                          ;
           DoSearchStore ( UnitSelect )                          ;
         END                                           ;
   'I' : BEGIN      { Midi Information       }
                           ;
                         END                           ;
   'T':BEGIN                      { Test   }
         { Test                              ; } { Include TestCasio.pas }
       END                                 ;
   'Q' : BEGIN      { Exit to DOS            }
           EXIT                              ;
         END                                 ;
   'E' : BEGIN      { Editor                 }
           ClearMainMenu ( 18,22 )                                 ;
           EditSubMenu                                             ;
           Choice2  := UPCASE (READKEY) ; WRITE  ( Choice2 )       ;
           CASE Choice2 OF 'P': VoiceEdit    ;       { Params      }
                           'H': DoDump       ;       { Hex Dump    }
                           'B': DoBufferDump ;       { Raw Dump    }
                           'D': BankEdit (0) ;       { Delete Unit }
                           'M': BankEdit (1) ;       { Move Unit   }
                           'I': BankEdit (2) ;       { Insert      }
                           'C': BankEdit (3) ;       { Copy        }
                           'X': BankEdit (4) ;       { Exchange    }
           END                                                     ;
         END                                 ;
   #13 : BEGIN    ; END ;           { RETURN }
   'F' : BEGIN     { File Services           }
           ClearMainMenu ( 18,22 )                                 ;
           FilesSubMenu                                            ;
           Choice2  := UPCASE (READKEY) ; WRITE  ( Choice2 )       ;
           CASE Choice2 OF 'S':BEGIN                      { Save   }
                                 OpenFiles ( FileName , 1 )        ;
                                 SaveFile (FileName, UnitSelect ) ;
                               END                                 ;
                           'A':BEGIN                      { Append }
                                 OpenFiles ( FileName , 2 )        ;
                                 SaveFile (FileName, UnitSelect ) ;
                               END                                 ;
                           'L':BEGIN                      { Load   }
                                 XLoadPos := 1                     ;
                                 OpenFiles ( FileName , 0 )        ;
                                 LoadFile  ( FileName , 0 )        ;
                                 SetUpUnit                         ;
                                 { Clear all before load           }
                               END                                 ;
                           'E':BEGIN                    { SpecLoad }
                                 ClearMainMenu ( 18,22 )           ;
                                 ExLoadSubMenu                     ;
                                 OpenFiles ( FileName , 4 )        ;
                                 LoadFile  ( FileName, XloadPos )  ;
                                 SetUpUnit                         ;
                               END                                 ;
                           'F':BEGIN                      { Dir    }
                                 FileList ( Dir )                  ;
                               END                                 ;
                           'U':BEGIN                      { Dir    }
                                 SelectDrive                       ;
                               END                                 ;
                           'R':BEGIN                      { Rename }
                                 RenameFile                        ;
                               END                                 ;
                           'D':BEGIN                      { Delete }
                                   DeleteFile                      ;
                               END                                 ;
           END              {  CASE : Choice2   }                  ;
         END                {  CASE : Choice1 F }                  ;
    ELSE BEGIN             { Invalid Choice                        }
            WRITE (#8, '***')                ;
            DELAY (500)                      ;
         END                                 ;
   END                                                      ;
  UNTIL Choice = 'X'                                        ;
 END ;

{-----------------------------------------}
{ Main                                    }
{-----------------------------------------}
BEGIN

   ResetDSP                                  ;

   NumX  := [ '0'..'9' ]                     ;
   CharX := [ 'P', 'O', 'M', 'X' ]           ;
   HexX  := [ '0'..'9','A'..'F'  ]           ;

   WriteByte := 0                            ;
   ReadByte  := 0                            ;
   UnitSelectName := 'Not-Selected'          ;
   PSearch.PName  := 'Empty       '          ;
   OSearch.OName  := 'Empty       '          ;
   ManName     := 'Manufacturer'             ;
   ManIDStr    := '00'                       ;
   ManID       := 0                          ;
   UnitCount   := 0                          ;
   UnitSelect  := 0                          ;
   UnitName    := 'Patches'                  ;
   UnitID      := '  '                       ;
   UnitSize    :=  PatchSize                 ;
   FileN       := ' '                        ;
   Dir         := 'Current'                  ;
   {-----------------------------------------} { Check memory }
   IF MAXAVAIL<(BufMaxSize + (PatchSize)*128 + (OpMemSize)*128) THEN
   BEGIN
     WRITELN ('Not enough free memory [ ', MAXAVAIL, ' ]' ) ;
     WRITELN ('Terminate any other installed programs.' )   ;
     HALT (1)                                               ;
   END                                                      ;

   GETMEM ( Patch  , SIZEOF (PatchBulkType )  )             ;
   GETMEM ( OpMem  , SIZEOF (OpMemBulkType )  )             ;
   GETMEM ( Buffer , SIZEOF (BufferType)      )             ;

   MainMenu                            ;

END.


