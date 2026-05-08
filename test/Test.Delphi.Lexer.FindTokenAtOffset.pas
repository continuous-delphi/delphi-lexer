(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Test.Delphi.Lexer.FindTokenAtOffset;

// Tests for FindTokenAtOffset.
//
// FindTokenAtOffset(Tokens, Offset) returns the index of the token whose span
// [StartOffset .. StartOffset + Length - 1] contains Offset (0-based).
// Returns -1 for negative offsets, offsets at or past the tkEOF position,
// and empty token lists.
//
// Test source 'abc def' produces:
//   [0] tkIdentifier('abc')   offset=0, len=3   -- covers 0,1,2
//   [1] tkWhitespace(' ')     offset=3, len=1   -- covers 3
//   [2] tkIdentifier('def')   offset=4, len=3   -- covers 4,5,6
//   [3] tkEOF                 offset=7, len=0   -- not returned

interface

uses
  DUnitX.TestFramework,
  Delphi.Token,
  Delphi.Token.Kind,
  Delphi.Token.List,
  Delphi.Lexer;

type

  [TestFixture]
  TFindTokenAtOffsetTests = class
  private
    FLexer:  TDelphiLexer;
    FTokens: TTokenList;
    procedure Lex(const S: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- Correct index returned ---
    [Test] procedure FirstCharOfFirstToken_ReturnsIndex0;
    [Test] procedure LastCharOfFirstToken_ReturnsIndex0;
    [Test] procedure ExactlyAtTokenBoundary_ReturnsNextToken;
    [Test] procedure MiddleOfToken_ReturnsCorrectIndex;
    [Test] procedure WhitespaceToken_ReturnsItsIndex;
    [Test] procedure LastCharOfLastRealToken_ReturnsItsIndex;

    // --- Out-of-range returns -1 ---
    [Test] procedure NegativeOffset_ReturnsMinusOne;
    [Test] procedure AtEOFOffset_ReturnsMinusOne;
    [Test] procedure PastEOFOffset_ReturnsMinusOne;
    [Test] procedure EmptyList_ReturnsMinusOne;

    // --- Edge cases ---
    [Test] procedure SingleCharSource_OffsetZero_ReturnsIndex0;
    [Test] procedure SingleCharSource_OffsetOne_ReturnsMinusOne;
    [Test] procedure EmptySource_OffsetZero_ReturnsMinusOne;
    [Test] procedure LargeNegativeOffset_ReturnsMinusOne;
    [Test] procedure MaxIntOffset_ReturnsMinusOne;
    [Test] procedure MultiLineSource_OffsetInsideEOL_ReturnsEOLToken;
    [Test] procedure ManyTokens_LastRealTokenFound;
    [Test] procedure OnlyWhitespaceSource_OffsetInMiddle;
  end;

implementation


procedure TFindTokenAtOffsetTests.Setup;
begin
  FLexer  := TDelphiLexer.Create;
  FTokens := nil;
end;


procedure TFindTokenAtOffsetTests.TearDown;
begin
  FTokens.Free;
  FLexer.Free;
end;


procedure TFindTokenAtOffsetTests.Lex(const S: string);
begin
  FTokens.Free;
  FTokens := FLexer.Tokenize(S);
end;


// ---------------------------------------------------------------------------
// Correct index returned
// ---------------------------------------------------------------------------

procedure TFindTokenAtOffsetTests.FirstCharOfFirstToken_ReturnsIndex0;
begin
  Lex('abc def');
  Assert.AreEqual(0, FindTokenAtOffset(FTokens, 0), 'offset 0 -> [0] abc');
end;


procedure TFindTokenAtOffsetTests.LastCharOfFirstToken_ReturnsIndex0;
begin
  Lex('abc def');
  // 'abc' spans offsets 0,1,2; offset 2 is the last char.
  Assert.AreEqual(0, FindTokenAtOffset(FTokens, 2), 'offset 2 -> [0] abc');
end;


procedure TFindTokenAtOffsetTests.ExactlyAtTokenBoundary_ReturnsNextToken;
begin
  Lex('abc def');
  // Offset 3 is the first char of the whitespace token, not the last of 'abc'.
  Assert.AreEqual(1, FindTokenAtOffset(FTokens, 3), 'offset 3 -> [1] whitespace');
end;


procedure TFindTokenAtOffsetTests.MiddleOfToken_ReturnsCorrectIndex;
begin
  Lex('abc def');
  // 'def' spans offsets 4,5,6; offset 5 is the middle char 'e'.
  Assert.AreEqual(2, FindTokenAtOffset(FTokens, 5), 'offset 5 -> [2] def');
end;


procedure TFindTokenAtOffsetTests.WhitespaceToken_ReturnsItsIndex;
begin
  Lex('abc def');
  Assert.AreEqual(1, FindTokenAtOffset(FTokens, 3), 'offset 3 -> [1] whitespace');
end;


procedure TFindTokenAtOffsetTests.LastCharOfLastRealToken_ReturnsItsIndex;
begin
  Lex('abc def');
  // 'def' ends at offset 6; that is still inside [2], not at tkEOF.
  Assert.AreEqual(2, FindTokenAtOffset(FTokens, 6), 'offset 6 -> [2] def');
end;


// ---------------------------------------------------------------------------
// Out-of-range returns -1
// ---------------------------------------------------------------------------

procedure TFindTokenAtOffsetTests.NegativeOffset_ReturnsMinusOne;
begin
  Lex('abc def');
  Assert.AreEqual(-1, FindTokenAtOffset(FTokens, -1), 'offset -1 -> -1');
end;


procedure TFindTokenAtOffsetTests.AtEOFOffset_ReturnsMinusOne;
begin
  Lex('abc def');
  // 'abc def' is 7 chars; tkEOF.StartOffset = 7, Length = 0.
  Assert.AreEqual(-1, FindTokenAtOffset(FTokens, 7), 'offset 7 (EOF) -> -1');
end;


procedure TFindTokenAtOffsetTests.PastEOFOffset_ReturnsMinusOne;
begin
  Lex('abc def');
  Assert.AreEqual(-1, FindTokenAtOffset(FTokens, 100), 'offset 100 -> -1');
end;


procedure TFindTokenAtOffsetTests.EmptyList_ReturnsMinusOne;
var
  Empty: TTokenList;
begin
  Empty := TTokenList.Create;
  try
    Assert.AreEqual(-1, FindTokenAtOffset(Empty, 0), 'empty list -> -1');
  finally
    Empty.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Edge cases
// ---------------------------------------------------------------------------

procedure TFindTokenAtOffsetTests.SingleCharSource_OffsetZero_ReturnsIndex0;
begin
  Lex('x');
  // [0] tkIdentifier('x') offset=0, len=1; [1] tkEOF offset=1, len=0
  Assert.AreEqual(0, FindTokenAtOffset(FTokens, 0), 'single-char: offset 0 -> [0]');
end;


procedure TFindTokenAtOffsetTests.SingleCharSource_OffsetOne_ReturnsMinusOne;
begin
  Lex('x');
  // Offset 1 is the tkEOF position -- no character there.
  Assert.AreEqual(-1, FindTokenAtOffset(FTokens, 1), 'single-char: offset 1 -> -1');
end;


procedure TFindTokenAtOffsetTests.EmptySource_OffsetZero_ReturnsMinusOne;
begin
  Lex('');
  // Empty source: only tkEOF at offset 0 with Length 0 -- no characters at all.
  Assert.AreEqual(-1, FindTokenAtOffset(FTokens, 0), 'empty source: offset 0 -> -1');
end;


procedure TFindTokenAtOffsetTests.LargeNegativeOffset_ReturnsMinusOne;
begin
  Lex('abc def');
  Assert.AreEqual(-1, FindTokenAtOffset(FTokens, -1000000), 'large negative -> -1');
end;


procedure TFindTokenAtOffsetTests.MaxIntOffset_ReturnsMinusOne;
begin
  Lex('abc def');
  Assert.AreEqual(-1, FindTokenAtOffset(FTokens, MaxInt), 'MaxInt -> -1');
end;


procedure TFindTokenAtOffsetTests.MultiLineSource_OffsetInsideEOL_ReturnsEOLToken;
var
  EolIdx: Integer;
begin
  // 'ab' + CRLF + 'cd' => offsets: ab=0,1  CR=2  LF=3  cd=4,5
  Lex('ab' + #13#10 + 'cd');
  // Offset 2 is the CR of the CRLF EOL token.
  EolIdx := FindTokenAtOffset(FTokens, 2);
  Assert.IsTrue(EolIdx >= 0, 'should find a token at offset 2');
  Assert.AreEqual(Ord(tkEOL), Ord(FTokens[EolIdx].Kind), 'offset 2 -> tkEOL');
  // Offset 3 is the LF of the same CRLF token.
  Assert.AreEqual(EolIdx, FindTokenAtOffset(FTokens, 3), 'offset 3 -> same EOL token');
end;


procedure TFindTokenAtOffsetTests.ManyTokens_LastRealTokenFound;
var
  Idx: Integer;
begin
  // 'a b c d e f g h i j' => 19 tokens (10 idents + 9 spaces) + EOF = 20.
  // Last real token 'j' is at offset 18.
  Lex('a b c d e f g h i j');
  Idx := FindTokenAtOffset(FTokens, 18);
  Assert.IsTrue(Idx >= 0, 'should find token at offset 18');
  Assert.AreEqual('j', FTokens[Idx].Text, 'last ident found');
  // One past the last char should be -1 (EOF).
  Assert.AreEqual(-1, FindTokenAtOffset(FTokens, 19), 'offset 19 -> -1 (EOF)');
end;


procedure TFindTokenAtOffsetTests.OnlyWhitespaceSource_OffsetInMiddle;
var
  Idx: Integer;
begin
  // '     ' (5 spaces) => [0] tkWhitespace len=5, [1] tkEOF.
  Lex('     ');
  Idx := FindTokenAtOffset(FTokens, 2);
  Assert.AreEqual(0, Idx, 'offset 2 in whitespace -> [0]');
  Idx := FindTokenAtOffset(FTokens, 4);
  Assert.AreEqual(0, Idx, 'offset 4 in whitespace -> [0]');
  Assert.AreEqual(-1, FindTokenAtOffset(FTokens, 5), 'offset 5 -> -1 (EOF)');
end;


initialization

TDUnitX.RegisterTestFixture(TFindTokenAtOffsetTests);

end.
