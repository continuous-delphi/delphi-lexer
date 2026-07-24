(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Test.Delphi.SourceIO;

// Direct tests of the pure-Pascal decoding primitives in Delphi.SourceIO:
// DetectBom, IsValidUtf8, and DecodeAnsiLossless. These are OS-/RTL-version
// independent, so the golden byte->code-point expectations below are exact.

interface

uses
  DUnitX.TestFramework;

type

  [TestFixture]
  TSourceIOTests = class
  private
    // Decode a single byte through DecodeAnsiLossless and return its code point.
    function DecodeOne(B: Byte): Word;
  public
    // --- DecodeAnsiLossless: golden CP1252 table ---

    [Test] procedure Decode_Euro_0x80;
    [Test] procedure Decode_SmartQuotes_0x91_0x92;
    [Test] procedure Decode_EnDashEmDash_0x96_0x97;
    [Test] procedure Decode_UndefinedBytes_MapToByteValue;
    [Test] procedure Decode_LowAscii_Identity;
    [Test] procedure Decode_HighLatin1_Identity;
    [Test] procedure Decode_AllBytes_NoLossNoReplacement;
    [Test] procedure Decode_Empty_ReturnsEmpty;

    // --- IsValidUtf8 ---

    [Test] procedure Utf8_Empty_IsValid;
    [Test] procedure Utf8_Ascii_IsValid;
    [Test] procedure Utf8_TwoByte_EAcute_IsValid;
    [Test] procedure Utf8_LoneContinuation_IsInvalid;
    [Test] procedure Utf8_Truncated_IsInvalid;
    [Test] procedure Utf8_Overlong_IsInvalid;
    [Test] procedure Utf8_Surrogate_IsInvalid;
    [Test] procedure Utf8_CP1252Bytes_AreInvalid;
    [Test] procedure Utf8_StartIndex_SkipsPrefix;

    // --- DetectBom ---

    [Test] procedure Bom_Utf8_Detected;
    [Test] procedure Bom_Utf16LE_Detected;
    [Test] procedure Bom_Utf16BE_Detected;
    [Test] procedure Bom_None_WhenAbsent;
    [Test] procedure Bom_None_WhenEmpty;
    [Test] procedure Bom_Utf16LE_NotMistakenForUtf8;
  end;

implementation

uses
  System.SysUtils,
  Delphi.SourceIO;


function MakeBytes(const Values: array of Byte): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do
    Result[I] := Values[I];
end;


function TSourceIOTests.DecodeOne(B: Byte): Word;
var
  S: string;
begin
  S := TSourceIO.DecodeAnsiLossless(MakeBytes([B]));
  Result := Word(Ord(S[1]));
end;


// ---------------------------------------------------------------------------
// DecodeAnsiLossless: golden CP1252 table
// ---------------------------------------------------------------------------

procedure TSourceIOTests.Decode_Euro_0x80;
begin
  Assert.AreEqual($20AC, Integer(DecodeOne($80)), '0x80 -> U+20AC (euro)');
end;


procedure TSourceIOTests.Decode_SmartQuotes_0x91_0x92;
begin
  Assert.AreEqual($2018, Integer(DecodeOne($91)), '0x91 -> U+2018');
  Assert.AreEqual($2019, Integer(DecodeOne($92)), '0x92 -> U+2019');
end;


procedure TSourceIOTests.Decode_EnDashEmDash_0x96_0x97;
begin
  Assert.AreEqual($2013, Integer(DecodeOne($96)), '0x96 -> U+2013 (en dash)');
  Assert.AreEqual($2014, Integer(DecodeOne($97)), '0x97 -> U+2014 (em dash)');
end;


procedure TSourceIOTests.Decode_UndefinedBytes_MapToByteValue;
begin
  // The five CP1252-undefined bytes must map to their byte value, not U+FFFD.
  Assert.AreEqual($0081, Integer(DecodeOne($81)), '0x81 -> U+0081');
  Assert.AreEqual($008D, Integer(DecodeOne($8D)), '0x8D -> U+008D');
  Assert.AreEqual($008F, Integer(DecodeOne($8F)), '0x8F -> U+008F');
  Assert.AreEqual($0090, Integer(DecodeOne($90)), '0x90 -> U+0090');
  Assert.AreEqual($009D, Integer(DecodeOne($9D)), '0x9D -> U+009D');
end;


procedure TSourceIOTests.Decode_LowAscii_Identity;
begin
  Assert.AreEqual($0041, Integer(DecodeOne($41)), '0x41 -> U+0041 (A)');
  Assert.AreEqual($0000, Integer(DecodeOne($00)), '0x00 -> U+0000');
  Assert.AreEqual($007F, Integer(DecodeOne($7F)), '0x7F -> U+007F');
end;


procedure TSourceIOTests.Decode_HighLatin1_Identity;
begin
  // 0xA0..0xFF agree byte-for-byte with Latin-1 / CP1252.
  Assert.AreEqual($00E9, Integer(DecodeOne($E9)), '0xE9 -> U+00E9 (e-acute)');
  Assert.AreEqual($00A0, Integer(DecodeOne($A0)), '0xA0 -> U+00A0 (nbsp)');
  Assert.AreEqual($00FF, Integer(DecodeOne($FF)), '0xFF -> U+00FF');
end;


procedure TSourceIOTests.Decode_AllBytes_NoLossNoReplacement;
var
  Bytes: TBytes;
  S: string;
  I: Integer;
begin
  SetLength(Bytes, 256);
  for I := 0 to 255 do
    Bytes[I] := Byte(I);
  S := TSourceIO.DecodeAnsiLossless(Bytes);
  // Every byte produces exactly one code point (no dropped or added chars)...
  Assert.AreEqual(NativeInt(256), Length(S), 'all 256 bytes decode 1:1');
  // ...and none decodes to the U+FFFD replacement character.
  for I := 1 to 256 do
    Assert.AreNotEqual($FFFD, Integer(Word(Ord(S[I]))), 'byte ' + IntToStr(I - 1) + ' must not be U+FFFD');
end;


procedure TSourceIOTests.Decode_Empty_ReturnsEmpty;
begin
  Assert.AreEqual('', TSourceIO.DecodeAnsiLossless(nil), 'empty input -> empty string');
end;


// ---------------------------------------------------------------------------
// IsValidUtf8
// ---------------------------------------------------------------------------

procedure TSourceIOTests.Utf8_Empty_IsValid;
begin
  Assert.IsTrue(TSourceIO.IsValidUtf8(nil), 'empty is valid');
end;


procedure TSourceIOTests.Utf8_Ascii_IsValid;
begin
  Assert.IsTrue(TSourceIO.IsValidUtf8(MakeBytes([$75, $6E, $69, $74])), 'ASCII "unit" is valid');
end;


procedure TSourceIOTests.Utf8_TwoByte_EAcute_IsValid;
begin
  // 0xC3 0xA9 is the UTF-8 encoding of U+00E9 (e-acute).
  Assert.IsTrue(TSourceIO.IsValidUtf8(MakeBytes([$C3, $A9])), '0xC3 0xA9 is valid UTF-8');
end;


procedure TSourceIOTests.Utf8_LoneContinuation_IsInvalid;
begin
  Assert.IsFalse(TSourceIO.IsValidUtf8(MakeBytes([$80])), 'lone continuation byte is invalid');
end;


procedure TSourceIOTests.Utf8_Truncated_IsInvalid;
begin
  Assert.IsFalse(TSourceIO.IsValidUtf8(MakeBytes([$C3])), 'truncated 2-byte sequence is invalid');
end;


procedure TSourceIOTests.Utf8_Overlong_IsInvalid;
begin
  // 0xC0 0x80 is an overlong encoding of U+0000.
  Assert.IsFalse(TSourceIO.IsValidUtf8(MakeBytes([$C0, $80])), 'overlong encoding is invalid');
end;


procedure TSourceIOTests.Utf8_Surrogate_IsInvalid;
begin
  // 0xED 0xA0 0x80 would encode the surrogate U+D800.
  Assert.IsFalse(TSourceIO.IsValidUtf8(MakeBytes([$ED, $A0, $80])), 'surrogate code point is invalid');
end;


procedure TSourceIOTests.Utf8_CP1252Bytes_AreInvalid;
begin
  // Smart quotes 0x93 0x94 around 'x' -- a classic legacy-CP1252 body that is
  // NOT valid UTF-8, so the ANSI fallback must fire.
  Assert.IsFalse(TSourceIO.IsValidUtf8(MakeBytes([$93, $78, $94])), 'CP1252 smart quotes are invalid UTF-8');
end;


procedure TSourceIOTests.Utf8_StartIndex_SkipsPrefix;
begin
  // Skipping a 3-byte UTF-8 BOM prefix leaves valid ASCII.
  Assert.IsTrue(TSourceIO.IsValidUtf8(MakeBytes([$EF, $BB, $BF, $41]), 3), 'validation honours StartIndex');
end;


// ---------------------------------------------------------------------------
// DetectBom
// ---------------------------------------------------------------------------

procedure TSourceIOTests.Bom_Utf8_Detected;
var
  PreLen: Integer;
begin
  Assert.AreEqual(Ord(bomUtf8), Ord(TSourceIO.DetectBom(MakeBytes([$EF, $BB, $BF, $41]), PreLen)), 'UTF-8 BOM');
  Assert.AreEqual(3, PreLen, 'UTF-8 preamble length');
end;


procedure TSourceIOTests.Bom_Utf16LE_Detected;
var
  PreLen: Integer;
begin
  Assert.AreEqual(Ord(bomUtf16LE), Ord(TSourceIO.DetectBom(MakeBytes([$FF, $FE, $41, $00]), PreLen)), 'UTF-16LE BOM');
  Assert.AreEqual(2, PreLen, 'UTF-16LE preamble length');
end;


procedure TSourceIOTests.Bom_Utf16BE_Detected;
var
  PreLen: Integer;
begin
  Assert.AreEqual(Ord(bomUtf16BE), Ord(TSourceIO.DetectBom(MakeBytes([$FE, $FF, $00, $41]), PreLen)), 'UTF-16BE BOM');
  Assert.AreEqual(2, PreLen, 'UTF-16BE preamble length');
end;


procedure TSourceIOTests.Bom_None_WhenAbsent;
var
  PreLen: Integer;
begin
  Assert.AreEqual(Ord(bomNone), Ord(TSourceIO.DetectBom(MakeBytes([$75, $6E, $69, $74]), PreLen)), 'no BOM');
  Assert.AreEqual(0, PreLen, 'no preamble');
end;


procedure TSourceIOTests.Bom_None_WhenEmpty;
var
  PreLen: Integer;
begin
  Assert.AreEqual(Ord(bomNone), Ord(TSourceIO.DetectBom(nil, PreLen)), 'empty input -> no BOM');
  Assert.AreEqual(0, PreLen, 'no preamble');
end;


procedure TSourceIOTests.Bom_Utf16LE_NotMistakenForUtf8;
var
  PreLen: Integer;
begin
  // FF FE is a UTF-16LE BOM and must never be routed through the UTF-8 path.
  Assert.AreNotEqual(Ord(bomUtf8), Ord(TSourceIO.DetectBom(MakeBytes([$FF, $FE]), PreLen)), 'FF FE is not UTF-8');
end;


end.
