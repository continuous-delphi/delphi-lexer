unit DelphiLexer.Scanner;

// Internal scanner record and low-level helpers used by TDelphiLexer.
// Not part of the public API -- subject to change without notice.
//
// AtLineStart design:
//   TScanner.AtLineStart is maintained by IncI. It is True at position 1
//   (start of source) and after consuming any EOL character or sequence.
//
//   EOL rules in IncI:
//     #10        -- line break; Line++, Col=1, AtLineStart=True.
//     #13 not followed by #10 -- bare CR line break; same as #10.
//     #13 followed by #10    -- CR of a CRLF pair; Col++, AtLineStart=False.
//                              The subsequent #10 then does the line break.
//     Any other char         -- Col++, AtLineStart=False.
//
//   This keeps CRLF as a single logical line break (Line advances exactly
//   once for the pair) while also correctly advancing Line for bare CR,
//   matching the public lexer contract that all three EOL forms produce
//   tkEOL and move to the next line.
//
//   This replaces the original backwards-scanning IsAtLineStart heuristic,
//   which had a CRLF detection bug and was fragile near the start of source.

interface

uses
  System.SysUtils; // CharInSet must be in interface uses for inline expansion

const
  CHAR_TAB          = #9;
  CHAR_SPACE        = #32;
  CHAR_VERT_TAB = #11;  //historical whitespace
  CHAR_FORMFEED = #12;  //historical whitespace
  CHAR_SINGLE_QUOTE = #39;

type
  TScanner = record
    S:           string;
    I:           Integer;   // 1-based current position in S
    N:           Integer;   // Length(S)
    Line:        Integer;   // 1-based current line number
    Col:         Integer;   // 1-based current column number
    AtLineStart: Boolean;   // True at position 1 and after consuming LF
  end;

// Advance Sc.I by Count characters, maintaining Line, Col, and AtLineStart.
procedure IncI(var Sc: TScanner; Count: Integer = 1);

// Return character at Sc.I + Offset without advancing. Returns #0 out of range.
function Peek(var Sc: TScanner; Offset: Integer = 0): Char;

// Return Count characters starting at Sc.I. Returns '' if fewer remain.
function PeekSeq(var Sc: TScanner; const Count: Integer): string;

// Consume a CR, LF, or CRLF at the current position and return it.
// Returns '' if not positioned at an EOL.
function ReadEOLIfPresent(var Sc: TScanner): string;

function IsWhitespaceChar(const C: Char): Boolean; inline;
function IsIdentStart(C: Char): Boolean;
function IsIdentChar(C: Char): Boolean;

implementation

uses
  System.Character;


procedure IncI(var Sc: TScanner; Count: Integer = 1);
var
  J: Integer;
begin
  for J := 1 to Count do
  begin
    if Sc.I <= Sc.N then
    begin
      if Sc.S[Sc.I] = #10 then
      begin
        // LF -- line break.
        Inc(Sc.Line);
        Sc.Col := 1;
        Sc.AtLineStart := True;
      end
      else if (Sc.S[Sc.I] = #13) and
              not ((Sc.I < Sc.N) and (Sc.S[Sc.I + 1] = #10)) then
      begin
        // Bare CR (not part of a CRLF pair) -- line break.
        Inc(Sc.Line);
        Sc.Col := 1;
        Sc.AtLineStart := True;
      end
      else
      begin
        // Any other character, or the CR of a CRLF pair.
        Inc(Sc.Col);
        Sc.AtLineStart := False;
      end;
    end;
    Inc(Sc.I);
  end;
end;


function Peek(var Sc: TScanner; Offset: Integer = 0): Char;
var
  P: Integer;
begin
  P := Sc.I + Offset;
  if (P >= 1) and (P <= Sc.N) then
    Result := Sc.S[P]
  else
    Result := #0;
end;


function PeekSeq(var Sc: TScanner; const Count: Integer): string;
begin
  if (Sc.I + Count - 1) > Sc.N then
    Exit('');
  Result := Copy(Sc.S, Sc.I, Count);
end;


function ReadEOLIfPresent(var Sc: TScanner): string;
begin
  Result := '';
  if Sc.I <= Sc.N then
  begin
    if (Sc.S[Sc.I] = #13) and (Sc.I + 1 <= Sc.N) and (Sc.S[Sc.I + 1] = #10) then
    begin
      Result := #13#10;
      IncI(Sc, 2);
      Exit;
    end;
    if (Sc.S[Sc.I] = #10) or (Sc.S[Sc.I] = #13) then
    begin
      Result := Sc.S[Sc.I];
      IncI(Sc);
    end;
  end;
end;


function IsWhitespaceChar(const C: Char): Boolean;
begin
  Result := CharInSet(C, [CHAR_SPACE, CHAR_TAB, CHAR_VERT_TAB, CHAR_FORMFEED]);
end;


function IsIdentStart(C: Char): Boolean;
begin
  Result := (C = '_') or C.IsLetter;
end;


function IsIdentChar(C: Char): Boolean;
begin
  Result := (C = '_') or C.IsLetterOrDigit;
end;


end.
