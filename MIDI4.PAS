
{ MIDI4.PAS : INCLUDE FILE in MIDI3.PAS }

 {--------------------------------------------------------------------------}
 { Curve 1 : y = 1.0671 x ^1.0483 (power curve) Add 1 every four values     }
 {           i.e. level 0=0, 4=5, 12=15, 26=34, 97=124, 99=127 max          }
 {--------------------------------------------------------------------------}
 { Convert Levels, Rate Scale from 00-99 to 00-127 :                        }
 {                 FileValue(00-7F) = INTEGER (Value(00-99) x 1.28)         }
 {--------------------------------------------------------------------------}
 { A001      : D0-D7  : Ext Phase On-Off: ON: 01=M4M3 02=M5M6 04=M7M8 07=All}
 { A002      : D0-D2  : Module 1 Wave   : 8 = Sine            [ xxxx x000 ] }
 {                                        9 = Saw1            [ xxxx x001 ] }
 {                                        A = Saw2            [ xxxx x010 ] }
 {                                        B = Saw3            [ xxxx x011 ] }
 {                                        C = Saw4            [ xxxx x100 ] }
 {                                        D = Saw5            [ xxxx x101 ] }
 {                                        E = Noise1          [ xxxx x110 ] }
 {                                        F = Noise2          [ xxxx x111 ] }
 { A002      : D3-D5  : Module 2 Wave   : 000-111 as above    [ xx00 0xxx ] }
 { A002      : D6-D7  : MixRingPhaseM1M2: 8 = Ring  M2+M1xM2  [ 10xx xxxx ] }
 {                                        4 = Phase M2(M1)    [ 01xx xxxx ] }
 {                                        0 = Mix   M1+M2     [ 00xx xxxx ] }
 { A003      : D0-D2  : Module 3 Wave   : 000-111 as above    [ xxxx x000 ] }
 { A003      : D3-D5  : Module 4 Wave   : 000-111 as above    [ xx00 0xxx ] }
 { A003      : D4-D7  : MixRingPhaseM3M4: 8 = Ring  M3+M3xM4  [ 1000 xxxx ] }
 {                                        4 = Phase M3(M4)    [ 0100 xxxx ] }
 {                                        0 = Mix   M3+M4     [ 0000 xxxx ] }
 { A004      : D0-D2  : Module 5 Wave   : 000-111 as above    [ xxxx x000 ] }
 { A004      : D3-D5  : Module 6 Wave   : 000-111 as above    [ xx00 0xxx ] }
 { A004      : D4-D7  : MixRingPhaseM5M6: 8 = Ring  M5+M5xM6  [ 1000 xxxx ] }
 {                                        4 = Phase M5(M6)    [ 0100 xxxx ] }
 {                                        0 = Mix   M5+M6     [ 0000 xxxx ] }
 { A005      : D0-D2  : Module 5 Wave   : 000-111 as above    [ xxxx x000 ] }
 { A005      : D3-D5  : Module 6 Wave   : 000-111 as above    [ xx00 0xxx ] }
 { A005      : D4-D7  : MixRingPhaseM7M8: 8 = Ring  M7+M7xM8  [ 1000 xxxx ] }
 {                                        4 = Phase M7(M8)    [ 0100 xxxx ] }
 {                                        0 = Mix   M7+M8     [ 0000 xxxx ] }
 {***************}
 {* DETUNE      *}
 {***************}
 {--------------------------------------------------------------------------}
 { 2 MODES : (1) PITCH FIX OFF ( Harmonic mode )                            }
 {               A006 : D0-D1 : 00 = Pitch Fix Off                          }
 {                    : D2-D7 : Fine Tune 00-63                             }
 {               A007 : D7    : Polarity (+ = 1) (- = 0)                    }
 {                    : D0-D6 : Note + Octave (12Notes=1Octave)             }
 {           (2) PITCH FIX ON ( Constant Pitch Mode )                       }
 {               A006 : D0-D1 : (X1)    = 10 = 2                            }
 {                              (X1/16) = 11 = 3                            }
 {                    : D2-D7 : Fine Tune 00-63                             }
 {               A007 : D7    : Pol always = 1 = +                          }
 {                    : D0-D6 : Note + Octave                               }
 {                                                                          }
 { Frequency : Fine 63  = 1 Note  ( Note = 100 Cents Change Fine = 1.6 cents}
 {             12 Notes = 1 Octave ( Max 5 Octaves                          }
 { A007 : (Mask out D7) : 00-0B = Oct0 Notes 0-11                           }
 {                        0C-17 = Oct1 Notes 0-11                           }
 {                        18-23 = Oct2                                      }
 {                        24-2F = Oct3                                      }
 {                        30-3B = Oct4                                      }
 {                        3C-47 = Oct5                                      }
 { Harmonics : ( 1/64 - 64 ) : [ Harmonic A = A x Frequency ]               }
 { Harm   1 : 2 : 3 : 4 : 5 : 6 : 7 : 8 : 9 : 10: 11: 12: 13: 14: 15: 16:   }
 { Oct    0  01  01  02  02  02  02  03  03   03  03  03  03  03  03  04    }
 { Note   0  00  07  00  03  07  09  00  02   03  05  07  08  09  10  00    }
 { Fine   0  00  01  00  55  01  44  00  03   55  33  01  20  44  56  00    }
 { Pol    +  +   +   +   +   +   +   +   +    +   +   +   +   +   +   +     }
 {                                                                          }
 { Harmonic 1/2 : 1/3 : 1/4 : 1/5                                           }
 { Oct       01   01    02    02                                            }
 { Note      00   07    00    03                                            }
 { Fine      00   01    00    55                                            }
 { Pol       -    -     -     -                                             }
 {
 { A006-A007 : D0-D15 : Detune M1       :                                   }
 { A008-A009 : D0-D15 : Detune M2       :                                   }
 {                                                                          }
 { A020-A021 : D0-D15 : Detune M3       :                                   }
 {**************}
 {* BLOCK S1   *}
 {**************)
 {------------ DCA ENV M1-M8 S1 RATE ---------------------------------------}
 { A022      : D0-D6  : DCAEnv S1Rate M1: 00 = Rate 00  Ratio 1.28 to 99    }
 { A022      : D7     : ?? The Sax has Bit 7 set in M3, M4, M7, M8          }
 {                                                                          }
 { A029      : D0-D6  : DCAEnv S1Rate M8: 00 = Rate 00  Ratio 1.28 to 99    }
 {-----------}

 { A030      : D0-D7  : DCOEnv S1Rate   : 00 = Rate 00 7F= Rate 99          }

 {------------ DCA ENV M1-M8 S1 LEVEL --------------------------------------}
 { A031      : D0-D6  : DCAEnv S1LevelM1: 00 = Level 00 7F = Level 99       }
 { A031      : D7     : DCAEnv SS S1    : 0 = SS off 1 SS on                }
 { A032      : D0-D6  : DCAEnv S1LevelM2: 00 = Level 00 7F = Level 99       }
 { A032      : D7     : DCAEnv SS S1    : 0 = SS off 1 SS on                }
 {                                                                          }
 { A037      : D0-D6  : DCAEnv S1LevelM7: 00 = Level 00 7F = Level 99       }
 { A037      : D7     : DCAEnv SS S1    : 0 = SS off 1 SS on                }
 { A038      : D0-D6  : DCAEnv S1LevelM8: 00 = Level 00 7F = Level 99       }
 { A038      : D7     : DCAEnv SS S1    : 0 = SS off 1 SS on                }
 {-----------}

 { A039      : D0-D6  : DCOEnv S1Level  : 00 = Level 00 7F = Level 99       }
 { A039      : D7     : DCO SS S1       : 0 = SS off 1 = SS on              }
 {**************}
 {* BLOCK S2   *}
 {**************)
 {----------- DCA Env RATE S2 ----------------------------------------------}
 { A040      : D0-D7  : DCAEnv S2Rate M1: 00 = Rate 00  Ratio 1.28 = 99     }
 { A047      : D0-D7  : DCAEnv S2Rate M8:                                   }
 {-----------}

 { A048      : D0-D7  : DCOEnv S2Rate   : 00 = Rate 00 7F= Rate 99          }

 {------------ DCA ENV M1-M8 S2 LEVEL --------------------------------------}
 { A049      : D0-D6  : DCAEnv S2LevelM1: 00 = Level 00 7F = Level 99       }
 { A049      : D7     : DCAEnv SS S2    : 0 = SS off 1 SS on                }
 {                                                                          }
 { A056      : D0-D6  : DCAEnv S2LevelM8: 00 = Level 00 7F = Level 99       }
 { A056      : D7     : DCAEnv SS S2    : 0 = SS off 1 SS on                }
 {-----------}

 { A057      : D0-D6  : DCOEnv S2Level  : 00 = Level 00 7F = Level 99       }
 { A057      : D7     : DCO SS S2       : 0 = SS off 1 = SS on              }
 {**************}
 {* BLOCK S3   *}
 {**************)
 {------------ DCA ENV M1-M8 S3 RATE ---------------------------------------}
 { A058      :        : DCAEnv S3Rate M1:                                   }
 { A065      :        : DCAEnv S3Rate M8:                                   }
 {-----------}

 { A066      : D0-D7  : DCOEnv S3Rate   : 00 = Rate 00 7F= Rate 99          }

 {------------ DCA ENV M1-M8 S3 LEVEL --------------------------------------}
 { A067      : D0-D6  : DCAEnv S3LevelM1:                                   }
 { A067      : D7     : DCAEnv SS S3    : 0 = SS off 1 SS on                }
 {                                                                          }
 { A074      : D0-D6  : DCAEnv S3LevelM8:                                   }
 { A074      : D7     : DCAEnv SS S3    : 0 = SS off 1 SS on                }
 {-----------}

 { A075      : D0-D6  : DCOEnv S3Level  : 00 = Level 00 7F = Level 99       }
 { A075      : D7     : DCO SS S3       : 0 = SS off 1 = SS on              }
 {**************}
 {* BLOCK S4   *}
 {**************)
 {------------ DCA ENV M1-M8 S4 RATE ---------------------------------------}
 { A076      :        : DCAEnv S4Rate M1:                                   }
 { A083      :        : DCAEnv S4Rate M8:                                   }
 {-----------}

 { A084      : D0-D7  : DCOEnv S4Rate   : 00 = Rate 00 7F= Rate 99          }

 {------------ DCA ENV M1-M8 S4 LEVEL --------------------------------------}
 { A085      : D0-D6  : DCAEnv S4LevelM1:                                   }
 { A085      : D7     : DCAEnv SS S4    : 0 = SS off 1 SS on                }
 {                                                                          }
 { A092      : D0-D6  : DCAEnv S4LevelM8:                                   }
 { A092      : D7     : DCAEnv SS S4    : 0 = SS off 1 SS on                }
 {-----------}

 { A093      : D0-D6  : DCOEnv S4Level  : 00 = Level 00 7F = Level 99       }
 { A093      : D7     : DCO SS S4       : 0 = SS off 1 = SS on              }
 {**************}
 {* BLOCK S5   *}
 {**************)
 {------------ DCA ENV M1-M8 S5 RATE ---------------------------------------}
 { A094      :        : DCAEnv S5Rate M1:                                   }
 { A101      :        : DCAEnv S5Rate M8:                                   }
 {-----------}

 { A102      : D0-D7  : DCOEnv S5Rate   : 00 = Rate 00 7F= Rate 99          }

 {------------ DCA ENV M1-M8 S5 LEVEL --------------------------------------}
 { A103      : D0-D6  : DCAEnv S5LevelM1:                                   }
 { A103      : D7     : DCAEnv SS S5    : 0 = SS off 1 SS on                }
 {                                                                          }
 { A110      : D0-D6  : DCAEnv S5LevelM8:                                   }
 { A110      : D7     : DCAEnv SS S5    : 0 = SS off 1 SS on                }
 {-----------}

 { A111      : D0-D6  : DCOEnv S6Level  : 00 = Level 00 7F = Level 99       }
 { A111      : D7     : DCO SS S6       : 0 = SS off 1 = SS on              }
 {**************}
 {* BLOCK S6   *}
 {**************)
 {------------ DCA ENV M1-M8 S6 RATE ---------------------------------------}
 { A112      :        : DCAEnv S6Rate M1:                                   }
 { A119      :        : DCAEnv S6Rate M8:                                   }
 {-----------}

 { A120      : D0-D7  : DCOEnv S6Rate   : 00 = Rate 00 7F= Rate 99          }

 {------------ DCA ENV M1-M8 S6 LEVEL --------------------------------------}
 { A121      : D0-D6  : DCAEnv S6LevelM1:                                   }
 { A121      : D7     : DCAEnv SS S6    : 0 = SS off 1 SS on                }
 {                                                                          }
 { A128      : D0-D6  : DCAEnv S6LevelM8:                                   }
 { A128      : D7     : DCAEnv SS S6    : 0 = SS off 1 SS on                }
 {-----------}

 { A129      : D0-D6  : DCOEnv S6Level  : 00 = Level 00 7F = Level 99       }
 { A129      : D7     : DCO SS S6       : 0 = SS off 1 = SS on              }
 {**************}
 {* BLOCK S7   *}
 {**************)
 {------------ DCA ENV M1-M8 S7 RATE ---------------------------------------}
 { A130      :        : DCAEnv S7Rate M1:                                   }
 { A137      :        : DCAEnv S7Rate M8:                                   }
 {-----------}

 { A138      : D0-D7  : DCOEnv S7Rate   : 00 = Rate 00 7F= Rate 99          }

 {------------ DCA ENV M1-M8 S7 LEVEL --------------------------------------}
 { A139      : D0-D6  : DCAEnv S7LevelM1:                                   }
 { A139      : D7     : DCAEnv SS S7    : 0 = SS off 1 SS on                }
 {                                                                          }
 { A146      : D0-D6  : DCAEnv S7LevelM8:                                   }
 { A146      : D7     : DCAEnv SS S7    : 0 = SS off 1 SS on                }
 {-----------}

 { A147      : D0-D6  : DCOEnv S7Level  : 00 = Level 00 7F = Level 99       }
 { A147      : D7     : DCO SS S7       : 0 = SS off 1 = SS on              }
 {**************}
 {* BLOCK S8   *}
 {**************)
 { A148      :        : DCAEnv RelrateM1:                                   }
 { A155      :        : DCAEnv RelRateM8:                                   }

 { A156      : D0-D7  : DCOEnv S8Rate   : 00 = Rate 00 7F= Rate 99          }

 { A157      :        : DCAEnv Rel levM1:                                   }
 { A164      ;        : DCAEnv Rel levM8:                                   }

 { A165      : D0-D6  : DCOEnv S8Level  : 00 = Level 00 7F = Level 99       }
 { A165      : D7     : DCO SS S8       : 0 = SS off 1 = SS on              }
 {**********************}
 { ED Points + AMP SENS }
 {**********************}
 { A166      : D5-D7  : DCAEnv Ed M1    : 0x=S1 1x=S2  .... 7x=S8           }
 { A166      : D0-D2  : AMP Sens. M1    : x0=0 x7=7                         }
 {                                                                          }
 { A173      : D5-D7  : DCAEnv Ed M8    : 0x=S1 1x=S2  .... 7x=S8           }
 { A173      : D0-D2  : AMP Sens. M8    : x0=0 x7=7                         }

 { A174      : D5-D7  : DCOEnv EDpoint  : 00=S1 10=S2 20=S3....70=S8        }

 { A175      : D0-D7  : Total Level     : 00 = Level 99 [ x000 0000 ]       }
 {                                        63 = Level 00 [ x110 0011 ]       }
 {*********************}
 { DCA Env Total Depth }
 {*********************}
 { A176      : D0-D6  : DCA Tot Depth M1: 00 = 99 7F = 99                   }
 { A176      : D7     :                                                     }
 {                                                                          }
 { A183      : D0-D6  : DCA Tot Depth M8: 00 = 99 7F = 99                   }
 { A183      : D7     :                                                     }
 {********************}
 { DCO Total Depth    }
 {********************}
 { A184      : D7     : DCO Narrow Wide : 1 = Wide 0 = Narrow               }
 { A184      : D0-D5  : DCO Depth 0-63  : 00 = 63 3F = 00                   }
 {********************}
 {* DCO Key Follow   *}
 {********************}
 { A281      : D0-D7  : DCOKeyFollow P1 : 00=KeyC0 78=KeyC9 10 Oct=120 keys }
 { A282      : D0-D5  : DCOKeyFollow Lev: 00 = 63  3F = 00                  }
 {                                                                          }
 { A291      : D0-D7  : DCOKeyFollow P6 : 00=KeyC0 78=KeyC9                 }
 { A292      : D0-D5  : DCOKeyFollow Lev: 00 = 63  3F = 00                  }
 {********************}
 {* DCO Key Follow   *}
 {********************}
 { A313      : D0-D4  : KF Sensitivity 0 = 0  1F = 31                       }
 { A313      : D5-D7  : KF Curve 1-8  0x Cur1 2x Cur2 Cx Cur7 Ex Cur8       }

 { A314      : D5-D7  : DCA Curve 1-8   : 00 = Curve 1  [ 000x xxxx ]       }
 {                                        20 = Curve 2  [ 001x xxxx ]       }
 {                                        40 = Curve 3  [ 010x xxxx ]       }
 {                                        60 = Curve 4  [ 011x xxxx ]       }
 {                                        80 = Curve 5  [ 100x xxxx ]       }
 {                                        A0 = Curve 6  [ 101x xxxx ]       }
 {                                        C0 = Curve 7  [ 110x xxxx ]       }
 {                                        E0 = Curve 8  [ 111x xxxx ]       }
 { A314      : D0-D4  : DCA Sensitivity : 00 = Sens 0   [ xxx0 0000 ]       }
 {                                        1F = Sens 31  [ xxx1 1111 ]       }
 { A315      : D5-D7  : Octave Range    : C0 = Oct +2   [ 110x xxxx ]       }
 {                                        .. = Oct +1   [           ]       }
 {                                        80 = Oct  0   [ 100x xxxx ]       }
 {                                        20 = Oct -1   [ 001x xxxx ]       }
 {                                        .. = Oct -2   [           ]       }
 { A315      : D3     : Vibrato Multi   : 1 = Multi On  [ xxxx 1xxx ]       }
 {                                        0 = Multi Off [ xxxx 0xxx ]       }
 { A315      : D0-D1  : Vibrato Wave    : 0(8) Triangle [ xxxx xx00 ]       }
 {                                        1(9) Saw Up   [ xxxx xx01 ]       }
 {                                        2(A) Saw Down [ xxxx xx10 ]       }
 {                                        3(B) Square   [ xxxx xx11 ]       }
 { A316      : D0-D7  : Vibrato depth   : 00 = depth 00 [ x000 0000 ]       }
 {                                        63 = depth 99 [ x110 0011 ]       }
 { A317      : D0-D7  : Vibrato rate    : 00 = rate 00  [ x000 0000 ]       }
 {                                        63 = rate 99  [ x110 0011 ]       }
 { A318      : D0-D7  : Vibrato delay   : 00 = delay 00 [ x000 0000 ]       }
 {                                        63 = delay 99 [ x110 0011 ]       }
 { A319      : D3     : Tremelo Multi   : 1 = Multi On  [ xxxx 1xxx ] (08)  }
 {                                        0 = Multi Off [ xxxx 0xxx ] (00)  }
 { A319      : D0-D1  : Tremelo Wave    : 0(8) Triangle [ xxxx xx00 ]       }
 {                                        1(9) Saw Up   [ xxxx xx01 ]       }
 {                                        2(A) Saw Down [ xxxx xx10 ]       }
 {                                        3(B) Square   [ xxxx xx11 ]       }
 { A320      : D0-D7  : Tremelo depth   : 00 = depth 00 [ x000 0000 ]       }
 {                                        63 = depth 99 [ x110 0011 ]       }
 { A321      : D0-D7  : Tremelo rate    : 00 = rate 00  [ x000 0000 ]       }
 {                                        63 = rate 99  [ x110 0011 ]       }
 { A322      : D0-D7  : Tremelo delay   : 00 = delay 00 [ x000 0000 ]       }
 {                                        63 = delay 99 [ x110 0011 ]       }
 { A323-A334 : B0-B11 : Voice Name      : 12 Char A-Z 0-9 -/.               }
 { A337      : D0-D7  : CheckSum        : (16000-ByteTotal(1-336)) AND 127  }
 {--------------------------------------------------------------------------}

     BlockType = RECORD
                 CASE BYTE OF
                 0 : ( X       : ARRAY [1..17] OF BYTE ;
                       DCOSS   : BYTE                  ) ;
                 1 : ( DCARate : ARRAY [1..8]  OF BYTE ;
                       DCORate : BYTE                  ;
                       DCALevel: ARRAY [1..8]  OF BYTE ;
                       DCOLevel: BYTE                  ) ;
                 END                                     ;

     DetuneType = RECORD
                  CASE BYTE OF
                  0 : ( Fine  : BYTE   ;
                        Note  : BYTE ) ;
                  1 : ( Fix   : BYTE   ;
                        Pol   : BYTE ) ;
                  3 : ( Detune: WORD ) ;
                  END                  ;


     PatchType = RECORD
                 CASE BYTE OF
                 0: ( X       : ARRAY [0..337] OF BYTE ) ;
                 1: ( Z1      : BYTE                     ;
                      ExtPhase: BYTE                     ;
                      M1M2Conf: BYTE                     ; { A002 }
                      M3M4Conf: BYTE                     ; { A003 }
                      M5M6Conf: BYTE                     ; { A004 }
                      M7M8Conf: BYTE                   ) ; { A005 }
                 2: ( Y1      : BYTE                     ; { A000 }
                      Y2      : BYTE                     ; { A001 }

                      M12Wave : BYTE                     ; { A002 }
                      M34Wave : BYTE                     ; { A003 }
                      M56Wave : BYTE                     ; { A004 }
                      M78Wave : BYTE                     ; { A005 }
                      Detune  : ARRAY[1..8] OF DetuneType; { A006-A021}

                      S1      : BlockType                ; { A022 }
                      S2      : BlockType                ; { A040 }
                      S3      : BlockType                ; { A058 }
                      S4      : BlockType                ; { A076 }
                      S5      : BlockType                ; { A094 }
                      S6      : BlockType                ; { A112 }
                      S7      : BlockType                ; { A130 }
                      S8      : BlockType                ; { A148 }
                      DCAEd   : BArr8                    ; { A166 }
                      DCOED   : BYTE                     ; { A174 }
                      TotLevel: 00..99                   ; { A175 }
                      DCATotD : BArr8                    ; { A176 }
                      DCODepth: BYTE                     ; { A184 }
                      Y5      : ARRAY [1..130] OF BYTE   ;
                      Octave  : -2..2                  ) ; { A315 }

                 3: ( PStart  : BYTE                     ;
                      PData1  : ARRAY [1..165] OF BYTE   ;
                      AmpSens : BArr8                    ; { A166 }
                      Pdata2  : ARRAY [174..280] OF BYTE ; { A174 }
                      DCOKF   : ARRAY [1..6] OF WORD     ; { A281 }
                      Pdata3  : ARRAY [293..312] OF BYTE ; { A293 }
                      DCOKF1  : BYTE                     ; { A313 }
                      Pdata4  : BYTE                     ; { A314 }
                      Vibrato : RECORD CASE BYTE OF
                                0: ( Multi  : $00..$08 ) ; { A315 }
                                1: ( Wave   : BYTE       ; { A315 }
                                     Depth  : 00..99     ; { A316 }
                                     Rate   : 00..99     ; { A317 }
                                     Delay  : 00..99 )   ; { A318 } END ;
                      Tremelo : RECORD CASE BYTE OF
                                0: ( Multi  : $00..$08 ) ; { A319 }
                                1: ( Wave   : BYTE       ; { A319 }
                                     Depth  : 00..99     ; { A320 }
                                     Rate   : 00..99     ; { A321 }
                                     Delay  : 00..99 )   ; { A322 } END ;
                      PName   : CArr12                   ; { A323 }
                      PEnd    : WORD                     ; { A335 }
                      PChkSum : BYTE                     ; { A337 } )   ;
                   END                                   ;
