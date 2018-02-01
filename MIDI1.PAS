
{--------------------------------------}

UNIT Midi1    ;

INTERFACE

USES Midi3, DOS, CRT ;

{--------------------------------------------------------------------------}
 PROCEDURE ClrLine ( Line : INTEGER )           ;
 PROCEDURE SelectPatch ( UnitType : BYTE )      ;
 PROCEDURE DoSearchStore (P1 : BYTE)            ;
 PROCEDURE DoSinglePatchRead ( UnitType : BYTE) ;
 PROCEDURE PatchName ( UnitNum : WORD ; VAR Scroll : BYTE ; Option : BYTE ) ;
 PROCEDURE PatchDecode ( UnitStart, UnitNum : WORD ) ;
 PROCEDURE DoBulkWrite                               ;
 PROCEDURE PutLine ( S : STRING ; Line : INTEGER )   ;
 PROCEDURE PatchEncode ( UnitNum : WORD )            ;
 PROCEDURE DoWrite                                   ;
{--------------------------------------------------------------------------}
 FUNCTION  DecToHex (VAR Number : WORD ) : Str10   ;
 FUNCTION  HexToDec ( HexStr : Str10 ) : WORD      ;
 PROCEDURE ClearMainMenu ( First, Last : INTEGER ) ;
 PROCEDURE ResetDSP                                ;
 PROCEDURE ConfigureMidi ( DSPMidiCmd : BYTE )     ;
 PROCEDURE SendByte ( MidiByte : BYTE )            ;
 PROCEDURE GetByte                                 ;
 PROCEDURE DoCheckSum (PatchNum,PatchChkSum: WORD;HexCSum:Str10;Option:BYTE);
 PROCEDURE DoDump                                       ;
 PROCEDURE BankEdit (Option : BYTE )                    ;
 PROCEDURE ClearPatch ( RecNum : Byte )                 ;
 PROCEDURE MovePatch ( RecNum : BYTE ; Option : BYTE )  ;
 PROCEDURE DoSearch (P1 : BYTE)                         ;
 PROCEDURE DoBufferDump                                 ;
 PROCEDURE RenamePatch ( RecNum : BYTE )                ;
 PROCEDURE SelectDrive                                  ;
 PROCEDURE SelectManufacturer                           ;
{---------------------------------------------------------------}
{$I Midi2 }

{------------------------}
{ Store unit for Search  }
{------------------------}
PROCEDURE DoSearchStore (P1 : BYTE) ;

BEGIN
  IF UnitSelect = 0 THEN EXIT ;
  IF UnitClass = 'P' THEN PSearch := Patch^[P1] ;
  IF UnitClass = 'O' THEN OSearch := OpMem^[P1] ;
END ;


{-----------------------}
{ Select a patch        }
{-----------------------}
PROCEDURE SelectPatch ( UnitType : BYTE )     ;

CONST
 S =     '       '                    ;
 S1=S+ '旼컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴커' ;
 S2=S+ '�                                                                �' ;
 S3=S+ '쳐컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴캑' ;
 S4=S+ '읕컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴켸' ;

VAR
  i, n   : WORD      ;
  Scroll : BYTE      ;
  AStr   : Str10     ;
  ErrorNum : INTEGER ;

BEGIN

  IF UnitCount = 0 THEN EXIT                               ;
  TEXTCOLOR (Yellow)      ;
  CLRSCR                  ;

  WRITE   ( NL, S1, NL )                                   ;
  FOR i := 1 TO 16 DO WRITE ( S2, NL )                     ;
  WRITE   ( S3, NL, S2, NL, S2, NL, S2, NL, S2, NL, S4 )   ;

  GOTOXY ( 10,20 )  ;
  WRITE  (UnitName,' LIST [ ', UnitCount, ' ]' )                     ;
  GOTOXY ( 10, 21 ) ; TEXTCOLOR ( White )                            ;
  WRITE ( 'Select ', UnitName, ' number [ 1 - ',UnitCount, ' ] : ' ) ;

  n      := 0                           ; { n = VoicePos in Data }
  Scroll := 1                           ;
  GOTOXY ( 10,3 )                       ;

  FOR i := 1 TO UnitCount DO PatchName ( i, Scroll, 1 )         ;

  REPEAT
    GOTOXY ( 45,21 ) ; READLN ( Astr )   ;
    VAL ( AStr, UnitSelect, ErrorNum )                               ;
  UNTIL (ErrorNum=0) AND (UnitSelect<=UnitCount) AND (UnitSelect>0);

  If UnitClass='P' THEN UnitSelectName := Patch^ [UnitSelect]. PName     ;
  If UnitClass='O' THEN UnitSelectName := OpMem^ [UnitSelect]. OName     ;

  GetA1H8Number ( UnitSelect )                                           ;

END  ;
{------------------------}
{ Clear the line in Line }
{------------------------}
PROCEDURE ClrLine ( Line : INTEGER ) ;

CONST
  Blank =  '               '           ;

BEGIN
  GOTOXY ( 10, Line )                  ;
  WRITE  ( Blank+Blank+Blank+Blank )   ;
  GOTOXY ( 10, Line )                  ;
END                                    ;
END .