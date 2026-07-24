(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Test.Delphi.Lexer.ReadAllText;

// Integration tests for TLexerUtils.ReadAllText. Each test writes an exact byte
// sequence to a temp file, then reads it back, so the deterministic read path
// (BOM-authoritative, pure-Pascal UTF-8 validation, lossless CP1252 fallback)
// is exercised end to end without relying on any RTL decode variance.

interface

uses
  DUnitX.TestFramework;

type

  [TestFixture]
  TReadAllTextTests = class
  private
    FFile: string;
    // Write raw bytes to the fixture file and return its path.
    procedure WriteBytes(const Values: array of Byte);
    function ReadUtf8(ASkipAnsiFallback: Boolean = False): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- BOM-less UTF-8 default path ---

    [Test] procedure BomlessValidUtf8_DecodesAsUtf8;
    [Test] procedure BomlessUtf8Multibyte_EAcute_DecodesAsUtf8;
    [Test] procedure BomlessCP1252_FallsBackLossless;
    [Test] procedure BomlessCP1252_SkipFallback_Raises;
    [Test] procedure BomlessCP1252_UndefinedByte_NotReplacement;

    // --- BOM authoritative ---

    [Test] procedure Utf8Bom_Stripped_DecodesBody;
    [Test] procedure Utf8Bom_InvalidBody_Raises;
    [Test] procedure Utf16LEBom_DecodesAsUtf16;
    [Test] procedure Utf16BEBom_DecodesAsUtf16;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Delphi.Lexer.Utils;


procedure TReadAllTextTests.Setup;
begin
  FFile := TPath.GetTempFileName;
end;


procedure TReadAllTextTests.TearDown;
begin
  if TFile.Exists(FFile) then
    TFile.Delete(FFile);
end;


procedure TReadAllTextTests.WriteBytes(const Values: array of Byte);
var
  Bytes: TBytes;
  I: Integer;
begin
  SetLength(Bytes, Length(Values));
  for I := 0 to High(Values) do
    Bytes[I] := Values[I];
  TFile.WriteAllBytes(FFile, Bytes);
end;


function TReadAllTextTests.ReadUtf8(ASkipAnsiFallback: Boolean): string;
begin
  Result := TLexerUtils.ReadAllText(FFile, TEncoding.UTF8, ASkipAnsiFallback);
end;


// ---------------------------------------------------------------------------
// BOM-less UTF-8 default path
// ---------------------------------------------------------------------------

procedure TReadAllTextTests.BomlessValidUtf8_DecodesAsUtf8;
begin
  // 'unit A;'
  WriteBytes([$75, $6E, $69, $74, $20, $41, $3B]);
  Assert.AreEqual('unit A;', ReadUtf8);
end;


procedure TReadAllTextTests.BomlessUtf8Multibyte_EAcute_DecodesAsUtf8;
var
  S: string;
begin
  // 0xC3 0xA9 is VALID UTF-8 for U+00E9; it must decode as ONE char, not as the
  // two CP1252 bytes 0xC3 0xA9.
  WriteBytes([$C3, $A9]);
  S := ReadUtf8;
  Assert.AreEqual(NativeInt(1), Length(S), 'one code point');
  Assert.AreEqual($00E9, Integer(Word(Ord(S[1]))), 'U+00E9 e-acute');
end;


procedure TReadAllTextTests.BomlessCP1252_FallsBackLossless;
var
  S: string;
begin
  // Smart-quoted "x": 0x93 'x' 0x94 -- invalid UTF-8, so the CP1252 fallback
  // fires and maps 0x93/0x94 to U+201C/U+201D losslessly.
  WriteBytes([$93, $78, $94]);
  S := ReadUtf8;
  Assert.AreEqual(NativeInt(3), Length(S), 'three code points');
  Assert.AreEqual($201C, Integer(Word(Ord(S[1]))), '0x93 -> U+201C');
  Assert.AreEqual($0078, Integer(Word(Ord(S[2]))), 'x');
  Assert.AreEqual($201D, Integer(Word(Ord(S[3]))), '0x94 -> U+201D');
end;


procedure TReadAllTextTests.BomlessCP1252_SkipFallback_Raises;
begin
  // Same invalid-UTF-8 body, but SkipAnsiFallback suppresses the fallback.
  WriteBytes([$93, $78, $94]);
  Assert.WillRaise(
    procedure
    begin
      ReadUtf8(True);
    end,
    EEncodingError,
    'invalid UTF-8 with SkipAnsiFallback must raise');
end;


procedure TReadAllTextTests.BomlessCP1252_UndefinedByte_NotReplacement;
var
  S: string;
begin
  // 0x81 is a CP1252-undefined byte and also invalid UTF-8. The lossless
  // fallback maps it to U+0081, never to the U+FFFD replacement char.
  WriteBytes([$81]);
  S := ReadUtf8;
  Assert.AreEqual($0081, Integer(Word(Ord(S[1]))), '0x81 -> U+0081, not U+FFFD');
end;


// ---------------------------------------------------------------------------
// BOM authoritative
// ---------------------------------------------------------------------------

procedure TReadAllTextTests.Utf8Bom_Stripped_DecodesBody;
begin
  // EF BB BF + 'unit A;'
  WriteBytes([$EF, $BB, $BF, $75, $6E, $69, $74, $20, $41, $3B]);
  Assert.AreEqual('unit A;', ReadUtf8, 'BOM stripped, body decoded');
end;


procedure TReadAllTextTests.Utf8Bom_InvalidBody_Raises;
begin
  // A declared UTF-8 BOM with an invalid body is a deterministic error, never a
  // silent replacement or an ANSI reinterpretation.
  WriteBytes([$EF, $BB, $BF, $93]);
  Assert.WillRaise(
    procedure
    begin
      ReadUtf8;
    end,
    EEncodingError,
    'BOM-declared UTF-8 with invalid body must raise');
end;


procedure TReadAllTextTests.Utf16LEBom_DecodesAsUtf16;
begin
  // FF FE + 'Hi' little-endian -- must decode via UTF-16, never the UTF-8/ANSI path.
  WriteBytes([$FF, $FE, $48, $00, $69, $00]);
  Assert.AreEqual('Hi', ReadUtf8);
end;


procedure TReadAllTextTests.Utf16BEBom_DecodesAsUtf16;
begin
  // FE FF + 'Hi' big-endian.
  WriteBytes([$FE, $FF, $00, $48, $00, $69]);
  Assert.AreEqual('Hi', ReadUtf8);
end;


end.
