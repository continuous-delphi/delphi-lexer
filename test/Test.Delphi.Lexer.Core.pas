(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Test.Delphi.Lexer.Core;

// Core tests covers: keyword classification, basic tokenization, round-trip guarantee.
// Detailed per-feature tests are added later

interface

uses
  DUnitX.TestFramework,
  Delphi.Token,
  Delphi.Token.List,
  Delphi.Lexer;

type

  [TestFixture]
  TLexerCoreTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TTokenList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- Keyword classification ---

    [Test] procedure Keywords_BeginIsKeyword;
    [Test] procedure Keywords_OutIsKeyword;
    [Test] procedure Keywords_AllUpperCaseIsKeyword;
    [Test] procedure Keywords_MixedCaseIsKeyword;
    [Test] procedure Keywords_PlainIdentifierIsNotKeyword;

    // --- Basic tokenization ---

    [Test] procedure Tokenize_SingleKeyword_ProducesKeywordPlusEOF;
    [Test] procedure Tokenize_Identifier_ProducesIdentifier;
    [Test] procedure Tokenize_EscapedIdentifier_ProducesIdentifierNotKeyword;
    [Test] procedure Tokenize_DecimalNumber_ProducesNumber;
    [Test] procedure Tokenize_HexNumber_ProducesNumber;
    [Test] procedure Tokenize_StringLiteral_ProducesString;
    [Test] procedure Tokenize_LineComment_ProducesComment;
    [Test] procedure Tokenize_BraceDirective_ProducesDirective;
    [Test] procedure Tokenize_BraceComment_ProducesComment;

    // --- Token metadata ---

    [Test] procedure Token_StartOffset_IsZeroForFirst;
    [Test] procedure Token_Length_MatchesTextLength;
    [Test] procedure Token_LineAndCol_AreOneBasedForFirst;
    [Test] procedure EOF_AlwaysPresent_AsLastToken;
    [Test] procedure EOF_StartOffset_EqualToSourceLength;

    // --- Round-trip guarantee ---

    [Test] procedure RoundTrip_SimpleAssignment_ReproducesSource;
    [Test] procedure RoundTrip_MultiLineSource_ReproducesSource;
  end;

implementation

uses
  Delphi.Token.Kind,
  Delphi.Keywords;


procedure TLexerCoreTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TLexerCoreTests.TearDown;
begin
  FLexer.Free;
end;


function TLexerCoreTests.Tok(const S: string): TTokenList;
begin
  Result := FLexer.Tokenize(S);
end;


// --- Keyword classification ---

procedure TLexerCoreTests.Keywords_BeginIsKeyword;
begin
  Assert.IsTrue(IsDelphiKeyword('begin'));
end;

procedure TLexerCoreTests.Keywords_OutIsKeyword;
begin
  Assert.IsTrue(IsDelphiKeyword('out'));
end;

procedure TLexerCoreTests.Keywords_AllUpperCaseIsKeyword;
begin
  Assert.IsTrue(IsDelphiKeyword('BEGIN'));
end;

procedure TLexerCoreTests.Keywords_MixedCaseIsKeyword;
begin
  Assert.IsTrue(IsDelphiKeyword('Begin'));
end;

procedure TLexerCoreTests.Keywords_PlainIdentifierIsNotKeyword;
begin
  Assert.IsFalse(IsDelphiKeyword('MyClass'));
end;


// --- Basic tokenization ---

procedure TLexerCoreTests.Tokenize_SingleKeyword_ProducesKeywordPlusEOF;
var
  T: TTokenList;
begin
  T := Tok('begin');
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Ord(kwBegin),         Ord(T[0].KeywordKind), 'keywordKind');
    Assert.AreEqual('begin', T[0].Text, 'text');
    Assert.AreEqual(Ord(tkEOF), Ord(T[1].Kind), 'eof kind');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.Tokenize_Identifier_ProducesIdentifier;
var
  T: TTokenList;
begin
  T := Tok('MyVar');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('MyVar', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.Tokenize_EscapedIdentifier_ProducesIdentifierNotKeyword;
var
  T: TTokenList;
begin
  T := Tok('&begin');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('&begin', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.Tokenize_DecimalNumber_ProducesNumber;
var
  T: TTokenList;
begin
  T := Tok('42');
  try
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('42', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.Tokenize_HexNumber_ProducesNumber;
var
  T: TTokenList;
begin
  T := Tok('$FF');
  try
    Assert.AreEqual(Ord(tkNumber), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('$FF', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.Tokenize_StringLiteral_ProducesString;
var
  T: TTokenList;
begin
  T := Tok('''hello''');
  try
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('''hello''', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.Tokenize_LineComment_ProducesComment;
var
  T: TTokenList;
begin
  T := Tok('// remark');
  try
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.Tokenize_BraceDirective_ProducesDirective;
var
  T: TTokenList;
begin
  T := Tok('{$IFDEF WIN32}');
  try
    Assert.AreEqual(Ord(tkDirective), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.Tokenize_BraceComment_ProducesComment;
var
  T: TTokenList;
begin
  T := Tok('{normal comment}');
  try
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
  finally
    T.Free;
  end;
end;


// --- Token metadata ---

procedure TLexerCoreTests.Token_StartOffset_IsZeroForFirst;
var
  T: TTokenList;
begin
  T := Tok('begin');
  try
    Assert.AreEqual(0, T[0].StartOffset, 'StartOffset');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.Token_Length_MatchesTextLength;
var
  T: TTokenList;
begin
  T := Tok('begin');
  try
    Assert.AreEqual(5, T[0].Length, 'Length');
    Assert.AreEqual(System.Length(T[0].Text), T[0].Length, 'Length = len(Text)');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.Token_LineAndCol_AreOneBasedForFirst;
var
  T: TTokenList;
begin
  T := Tok('begin');
  try
    Assert.AreEqual(1, T[0].Line, 'Line');
    Assert.AreEqual(1, T[0].Col, 'Col');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.EOF_AlwaysPresent_AsLastToken;
var
  T: TTokenList;
begin
  T := Tok('');
  try
    Assert.AreEqual(NativeInt(1), T.Count, 'count');
    Assert.AreEqual(Ord(tkEOF), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;

procedure TLexerCoreTests.EOF_StartOffset_EqualToSourceLength;
const
  Src = 'begin';
var
  T: TTokenList;
begin
  T := Tok(Src);
  try
    var Eof := T.Last;
    Assert.AreEqual(Ord(tkEOF), Ord(Eof.Kind), 'kind');
    Assert.AreEqual(System.Length(Src), Eof.StartOffset, 'EOF offset');
  finally
    T.Free;
  end;
end;


// --- Round-trip guarantee ---

procedure TLexerCoreTests.RoundTrip_SimpleAssignment_ReproducesSource;
const
  Src = 'X := 42;';
var
  T: TTokenList;
  Rebuilt: string;
  I: Integer;
begin
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

procedure TLexerCoreTests.RoundTrip_MultiLineSource_ReproducesSource;
const
  Src = 'if X > 0 then'#13#10'  Y := X;'#13#10;
var
  T: TTokenList;
  Rebuilt: string;
  I: Integer;
begin
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


initialization

TDUnitX.RegisterTestFixture(TLexerCoreTests);

end.
