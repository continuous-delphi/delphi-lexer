(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Delphi.SourceIO;

// Self-contained, pure-Pascal source-decoding primitives.
//
// This is a trimmed subset of the canonical Delphi.SourceIO unit (home repo:
// delphi-source-io). Only the three helpers needed by TLexerUtils.ReadAllText
// are lifted here so the lexer carries no external dependency:
//
//   DetectBom          -- authoritative byte-prefix BOM check.
//   IsValidUtf8        -- pure-Pascal UTF-8 well-formedness check.
//   DecodeAnsiLossless -- total per-byte Windows-1252 (WHATWG index) decode.
//
// The point of validating and decoding in pure Pascal is determinism: the RTL
// is used only for the whole-string conversion of ALREADY-VALIDATED bytes
// (TEncoding.UTF8.GetString), never to decide validity. That removes every
// dependence on which RTL version raises on invalid UTF-8, on Windows
// MultiByteToWideChar best-fit mapping of CP1252's undefined bytes, and on the
// RTL reader's implicit BOM handling.

interface

uses
  System.SysUtils;

type
  TBomKind = (bomNone, bomUtf8, bomUtf16LE, bomUtf16BE);

  TSourceIO = class
    // Real byte-prefix BOM check on the raw bytes. PreambleLen is set to the
    // number of BOM bytes (0 when none). Note: a UTF-32LE stream also begins
    // FF FE (00 00); UTF-32 is out of scope and is seen as UTF-16LE.
    class function DetectBom(const Bytes: TBytes; out PreambleLen: Integer): TBomKind; static;

    // Pure-Pascal UTF-8 well-formedness check: rejects stray/overlong
    // sequences, surrogate code points, and values > U+10FFFF. Empty input
    // (from StartIndex) is valid.
    class function IsValidUtf8(const Bytes: TBytes; StartIndex: Integer = 0): Boolean; static;

    // Total Windows-1252 decode (WHATWG index): the 5 undefined bytes map to
    // their byte value. Every byte 0x00..0xFF decodes to exactly one code
    // point; cannot throw, cannot lose a byte.
    class function DecodeAnsiLossless(const Bytes: TBytes): string; static;
  end;

implementation

const
  // 0x80..0x9F: WHATWG windows-1252 code points; the 5 undefined slots hold
  // the byte value (0x81, 0x8D, 0x8F, 0x90, 0x9D -> U+0081, U+008D, U+008F,
  // U+0090, U+009D).
  CP1252_High: array[$80..$9F] of Word = (
    $20AC, $0081, $201A, $0192, $201E, $2026, $2020, $2021,   // 0x80..0x87  (0x81 -> U+0081)
    $02C6, $2030, $0160, $2039, $0152, $008D, $017D, $008F,   // 0x88..0x8F  (0x8D, 0x8F -> selves)
    $0090, $2018, $2019, $201C, $201D, $2022, $2013, $2014,   // 0x90..0x97  (0x90 -> U+0090)
    $02DC, $2122, $0161, $203A, $0153, $009D, $017E, $0178);  // 0x98..0x9F  (0x9D -> U+009D)


class function TSourceIO.DetectBom(const Bytes: TBytes; out PreambleLen: Integer): TBomKind;
begin
  PreambleLen := 0;
  if (Length(Bytes) >= 3) and (Bytes[0] = $EF) and (Bytes[1] = $BB) and (Bytes[2] = $BF) then
  begin
    PreambleLen := 3;
    Exit(bomUtf8);
  end;
  if (Length(Bytes) >= 2) and (Bytes[0] = $FF) and (Bytes[1] = $FE) then
  begin
    PreambleLen := 2;
    Exit(bomUtf16LE);
  end;
  if (Length(Bytes) >= 2) and (Bytes[0] = $FE) and (Bytes[1] = $FF) then
  begin
    PreambleLen := 2;
    Exit(bomUtf16BE);
  end;
  Result := bomNone;
end;


class function TSourceIO.IsValidUtf8(const Bytes: TBytes; StartIndex: Integer): Boolean;
var
  I, N, Len, J: Integer;
  B: Byte;
begin
  Len := Length(Bytes);
  I := StartIndex;
  while I < Len do
  begin
    B := Bytes[I];
    if B <= $7F then
    begin
      Inc(I);
      Continue;
    end
    else if (B >= $C2) and (B <= $DF) then
      N := 1                             // 2-byte sequence
    else if (B >= $E0) and (B <= $EF) then
      N := 2                             // 3-byte sequence
    else if (B >= $F0) and (B <= $F4) then
      N := 3                             // 4-byte sequence
    else
      Exit(False);                       // $80..$C1 (stray/overlong) or $F5..$FF

    if I + N >= Len then
      Exit(False);                       // truncated sequence

    // First continuation byte carries the range constraints that reject
    // overlong encodings, surrogate code points, and values above U+10FFFF
    // (Unicode 15 Table 3-7).
    case B of
      $E0: if (Bytes[I + 1] < $A0) or (Bytes[I + 1] > $BF) then Exit(False);
      $ED: if (Bytes[I + 1] < $80) or (Bytes[I + 1] > $9F) then Exit(False);
      $F0: if (Bytes[I + 1] < $90) or (Bytes[I + 1] > $BF) then Exit(False);
      $F4: if (Bytes[I + 1] < $80) or (Bytes[I + 1] > $8F) then Exit(False);
    else
      if (Bytes[I + 1] < $80) or (Bytes[I + 1] > $BF) then Exit(False);
    end;

    // Any remaining continuation bytes must be plain 0x80..0xBF.
    for J := 2 to N do
      if (Bytes[I + J] < $80) or (Bytes[I + J] > $BF) then
        Exit(False);

    Inc(I, N + 1);
  end;
  Result := True;
end;


class function TSourceIO.DecodeAnsiLossless(const Bytes: TBytes): string;
var
  I: Integer;
  B: Byte;
begin
  SetLength(Result, Length(Bytes));
  for I := 0 to High(Bytes) do
  begin
    B := Bytes[I];
    if (B >= $80) and (B <= $9F) then
      Result[I + 1] := Char(CP1252_High[B])
    else
      Result[I + 1] := Char(B);          // identity: agrees with CP1252 and Latin-1
  end;
end;


end.
