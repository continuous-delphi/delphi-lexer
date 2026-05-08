(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Delphi.Token.TriviaSpan;

interface

type

  // Inclusive range [FirstTokenIndex .. LastTokenIndex] into a TTokenList
  // Identifies a contiguous run of trivia tokens owned by one semantic token.
  // Empty when FirstTokenIndex = -1 (use IsEmpty / Count helpers).
  TTriviaSpan = record
    FirstTokenIndex:Integer;
    LastTokenIndex:Integer;
    function IsEmpty:Boolean;
    function Count:Integer;
    function ToDebugString:string;
  end;


const

  DEFAULT_TRIVIASPAN:TTriviaSpan = (FirstTokenIndex: -1; LastTokenIndex: -1);


implementation

uses
  System.SysUtils;


function TTriviaSpan.IsEmpty:Boolean;
begin
  Result := FirstTokenIndex = -1;
end;


function TTriviaSpan.Count:Integer;
begin
  if IsEmpty then
    Exit(0);
  Result := LastTokenIndex - FirstTokenIndex + 1;
end;

function TTriviaSpan.ToDebugString:string;
begin
  if IsEmpty then
  begin
    Result := '';
  end
  else
  begin
    Result := Format('%d:%d', [FirstTokenIndex, LastTokenIndex]);
  end;

end;


end.
