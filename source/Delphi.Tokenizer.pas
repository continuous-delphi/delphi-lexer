(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Delphi.Tokenizer;

interface

uses
  Delphi.Token,
  Delphi.Token.List;

type

  ITokenizer = interface
    ['{B1E09F1D-1A89-4D6C-AD90-A3B2D0CDA29F}']
    function Tokenize(const Source:string):TTokenList;
  end;

implementation

end.

