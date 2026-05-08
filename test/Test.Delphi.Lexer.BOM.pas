(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Test.Delphi.Lexer.BOM;

// Tests for UTF-8 BOM (U+FEFF) handling.
//
// A BOM at the very start of the source is emitted as tkBOM (lexical trivia)
// so that round-trip fidelity is preserved and downstream tools can detect or
// strip it by policy. A BOM appearing anywhere else in the source is emitted
// as tkInvalid.

interface

uses
  DUnitX.TestFramework,
  Delphi.Token,
  Delphi.Token.List,
  Delphi.Lexer;

type

  [TestFixture]
  TBOMTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TTokenList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- tkBOM at start of file ---

    [Test] procedure BOM_AtStart_ProducesTkBOM;
    [Test] procedure BOM_AtStart_TextIsFEFF;
    [Test] procedure BOM_AtStart_OffsetIsZero;
    [Test] procedure BOM_AtStart_LengthIsOne;
    [Test] procedure BOM_AtStart_LineAndColAreOne;
    [Test] procedure BOM_BeforeKeyword_BothTokensCorrect;
    [Test] procedure BOM_Only_ProducesBOMPlusEOF;

    // --- tkInvalid for mid-file BOM ---

    [Test] procedure BOM_MidFile_IsInvalid;
    [Test] procedure BOM_AfterWhitespace_IsInvalid;

    // --- Round-trip ---

    [Test] procedure RoundTrip_BOMAtStart_PreservesSource;
    [Test] procedure RoundTrip_BOMPlusCode_PreservesSource;
    [Test] procedure RoundTrip_MidFileBOM_PreservesSource;

    // --- Trivia ---

    [Test] procedure BOM_IsLexicalTrivia;
    [Test] procedure BOM_IsLeadingTriviaOfFirstToken;
  end;

implementation

uses
  System.SysUtils,
  Delphi.Token.Kind;


const
  BOM_CHAR = #$FEFF;


procedure TBOMTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TBOMTests.TearDown;
begin
  FLexer.Free;
end;


function TBOMTests.Tok(const S: string): TTokenList;
begin
  Result := FLexer.Tokenize(S);
end;


// ---------------------------------------------------------------------------
// tkBOM at start of file
// ---------------------------------------------------------------------------

procedure TBOMTests.BOM_AtStart_ProducesTkBOM;
var
  T: TTokenList;
begin
  T := Tok(BOM_CHAR + 'unit A;');
  try
    Assert.AreEqual(Ord(tkBOM), Ord(T[0].Kind), 'first token should be tkBOM');
  finally
    T.Free;
  end;
end;


procedure TBOMTests.BOM_AtStart_TextIsFEFF;
var
  T: TTokenList;
begin
  T := Tok(BOM_CHAR + 'x');
  try
    Assert.AreEqual(BOM_CHAR, T[0].Text, 'tkBOM text');
  finally
    T.Free;
  end;
end;


procedure TBOMTests.BOM_AtStart_OffsetIsZero;
var
  T: TTokenList;
begin
  T := Tok(BOM_CHAR + 'x');
  try
    Assert.AreEqual(0, T[0].StartOffset, 'tkBOM StartOffset');
  finally
    T.Free;
  end;
end;


procedure TBOMTests.BOM_AtStart_LengthIsOne;
var
  T: TTokenList;
begin
  T := Tok(BOM_CHAR + 'x');
  try
    Assert.AreEqual(1, T[0].Length, 'tkBOM Length');
  finally
    T.Free;
  end;
end;


procedure TBOMTests.BOM_AtStart_LineAndColAreOne;
var
  T: TTokenList;
begin
  T := Tok(BOM_CHAR + 'x');
  try
    Assert.AreEqual(1, T[0].Line, 'tkBOM Line');
    Assert.AreEqual(1, T[0].Col, 'tkBOM Col');
  finally
    T.Free;
  end;
end;


procedure TBOMTests.BOM_BeforeKeyword_BothTokensCorrect;
var
  T: TTokenList;
begin
  T := Tok(BOM_CHAR + 'begin');
  try
    Assert.AreEqual(Ord(tkBOM), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('begin', T[1].Text, '[1] text');
    Assert.AreEqual(1, T[1].StartOffset, '[1] StartOffset');
  finally
    T.Free;
  end;
end;


procedure TBOMTests.BOM_Only_ProducesBOMPlusEOF;
var
  T: TTokenList;
begin
  T := Tok(BOM_CHAR);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'BOM + EOF');
    Assert.AreEqual(Ord(tkBOM), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual(Ord(tkEOF), Ord(T[1].Kind), '[1] kind');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// tkInvalid for mid-file BOM
// ---------------------------------------------------------------------------

procedure TBOMTests.BOM_MidFile_IsInvalid;
var
  T: TTokenList;
begin
  T := Tok('x' + BOM_CHAR + 'y');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[1].Kind), '[1] kind = tkInvalid');
    Assert.AreEqual(BOM_CHAR, T[1].Text, '[1] text');
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[2].Kind), '[2] kind');
  finally
    T.Free;
  end;
end;


procedure TBOMTests.BOM_AfterWhitespace_IsInvalid;
var
  T: TTokenList;
begin
  // BOM preceded by a space is not at position 0, so it is invalid.
  T := Tok(' ' + BOM_CHAR + 'x');
  try
    Assert.AreEqual(Ord(tkWhitespace), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[1].Kind), '[1] kind = tkInvalid');
    Assert.AreEqual(BOM_CHAR, T[1].Text, '[1] text');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Round-trip
// ---------------------------------------------------------------------------

procedure TBOMTests.RoundTrip_BOMAtStart_PreservesSource;
var
  Src, Rebuilt: string;
  T: TTokenList;
  I: Integer;
begin
  Src := BOM_CHAR;
  T := Tok(Src);
  try
    Rebuilt := '';
    for I := 0 to T.Count - 1 do
      Rebuilt := Rebuilt + T[I].Text;
    Assert.AreEqual(Src, Rebuilt, 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TBOMTests.RoundTrip_BOMPlusCode_PreservesSource;
var
  Src, Rebuilt: string;
  T: TTokenList;
  I: Integer;
begin
  Src := BOM_CHAR + 'unit Foo;';
  T := Tok(Src);
  try
    Rebuilt := '';
    for I := 0 to T.Count - 1 do
      Rebuilt := Rebuilt + T[I].Text;
    Assert.AreEqual(Src, Rebuilt, 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TBOMTests.RoundTrip_MidFileBOM_PreservesSource;
var
  Src, Rebuilt: string;
  T: TTokenList;
  I: Integer;
begin
  Src := 'a' + BOM_CHAR + 'b';
  T := Tok(Src);
  try
    Rebuilt := '';
    for I := 0 to T.Count - 1 do
      Rebuilt := Rebuilt + T[I].Text;
    Assert.AreEqual(Src, Rebuilt, 'round-trip');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Trivia
// ---------------------------------------------------------------------------

procedure TBOMTests.BOM_IsLexicalTrivia;
begin
  Assert.IsTrue(IsLexicalTrivia(tkBOM), 'tkBOM should be lexical trivia');
end;


procedure TBOMTests.BOM_IsLeadingTriviaOfFirstToken;
var
  T: TTokenList;
begin
  T := Tok(BOM_CHAR + 'x');
  try
    // T[0] = tkBOM, T[1] = tkIdentifier 'x', T[2] = tkEOF
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual(0, T[1].LeadingTrivia.FirstTokenIndex, 'leading first');
    Assert.AreEqual(0, T[1].LeadingTrivia.LastTokenIndex, 'leading last');
  finally
    T.Free;
  end;
end;


end.
