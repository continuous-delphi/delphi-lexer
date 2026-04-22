unit Test.Delphi.Lexer.Golden;

// Golden round-trip tests.
//
// Each test loads a .pas file from test/golden/, tokenizes it, and verifies:
//   1. Round-trip: concatenating all token texts reproduces the original source.
//   2. StartOffset chain: each token's StartOffset equals the running byte offset.
//   3. Token.Length = System.Length(Token.Text) for every token.
//   4. Last token is tkEOF.
//
// Additional per-file spot-checks:
//   keywords.pas  -- exactly 66 tkKeyword tokens
//   literals.pas  -- at least one each of tkNumber, tkString, tkCharLiteral
//   comments.pas  -- at least one tkComment and at least one tkDirective
//   operators.pas -- multi-char operators (:=, .., <>, <=, >=) are single tokens
//
// Golden file location: test/golden/ (two levels above the test executable).

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  Delphi.Token,
  Delphi.Token.List,
  Delphi.Token.Kind,
  Delphi.Lexer;

type

  [TestFixture]
  TGoldenTests = class
  private
    FLexer:     TDelphiLexer;
    FGoldenDir: string;
    function  LoadGolden(const FileName: string): string;
    procedure CheckStandard(const Src, GoldenName: string);
    function  CountKind(Tokens: TTokenList; Kind: TTokenKind): Integer;
    function  FindTokenIndex(Tokens: TTokenList; const Text: string): Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test] procedure Golden_Minimal;
    [Test] procedure Golden_StrictKeywords;
    [Test] procedure Golden_DirectiveKeywords;
    [Test] procedure Golden_VisibilityKeywords;
    [Test] procedure Golden_Literals;
    [Test] procedure Golden_Comments;
    [Test] procedure Golden_Operators;
    [Test] procedure Golden_RealUnit;
  end;


implementation
uses
  Delphi.Keywords;


procedure TGoldenTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
  // The test exe lives at test\Win32\Debug\; go up two levels to reach test\.
  FGoldenDir := IncludeTrailingPathDelimiter(
    ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\golden'));
end;


procedure TGoldenTests.TearDown;
begin
  FLexer.Free;
end;


function TGoldenTests.LoadGolden(const FileName: string): string;
begin
  Result := TFile.ReadAllText(FGoldenDir + FileName, TEncoding.UTF8);
end;


procedure TGoldenTests.CheckStandard(const Src, GoldenName: string);
var
  Tokens:         TTokenList;
  I:              Integer;
  RoundTrip:      string;
  ExpectedOffset: Integer;
begin
  Tokens := FLexer.Tokenize(Src);
  try
    // 1. Round-trip: concatenation of all token texts must reproduce Src.
    RoundTrip := '';
    for I := 0 to Tokens.Count - 1 do
      RoundTrip := RoundTrip + Tokens[I].Text;
    Assert.AreEqual(Src, RoundTrip, GoldenName + ': round-trip');

    // 2. StartOffset chain + Length.
    ExpectedOffset := 0;
    for I := 0 to Tokens.Count - 1 do
    begin
      Assert.AreEqual(ExpectedOffset, Tokens[I].StartOffset,
        GoldenName + '[' + IntToStr(I) + ']: StartOffset');
      Assert.AreEqual(System.Length(Tokens[I].Text), Tokens[I].Length,
        GoldenName + '[' + IntToStr(I) + ']: Length');
      Inc(ExpectedOffset, Tokens[I].Length);
    end;

    // 3. Last token is tkEOF.
    Assert.AreEqual(Ord(tkEOF), Ord(Tokens.Last.Kind),
      GoldenName + ': last token is tkEOF');
  finally
    Tokens.Free;
  end;
end;


function TGoldenTests.CountKind(Tokens: TTokenList;
  Kind: TTokenKind): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Tokens.Count - 1 do
    if Tokens[I].Kind = Kind then
      Inc(Result);
end;


function TGoldenTests.FindTokenIndex(Tokens: TTokenList;
  const Text: string): Integer;
var
  I: Integer;
begin
  for I := 0 to Tokens.Count - 1 do
    if Tokens[I].Text = Text then
      Exit(I);
  Result := -1;
end;


// ---------------------------------------------------------------------------

procedure TGoldenTests.Golden_Minimal;
var
  Src: string;
begin
  Src := LoadGolden('minimal.pas');
  CheckStandard(Src, 'minimal');
end;


procedure TGoldenTests.Golden_StrictKeywords;
var
  Src:    string;
  Tokens: TTokenList;
  Count:  Integer;
begin
  Src := LoadGolden('keywords_strict.txt');
  CheckStandard(Src, 'strict keyword list');

  Tokens := FLexer.Tokenize(Src);
  try
    Count := CountKind(Tokens, tkStrictKeyword);
    Assert.AreEqual(DELPHI_STRICT_KEYWORD_COUNT, Count, 'tkStrictKeyword count');
  finally
    Tokens.Free;
  end;
end;


procedure TGoldenTests.Golden_DirectiveKeywords;
var
  Src:    string;
  Tokens: TTokenList;
  Count:  Integer;
begin
  Src := LoadGolden('keywords_directive.txt');
  CheckStandard(Src, 'directive keyword list');

  Tokens := FLexer.Tokenize(Src);
  try
    Count := CountKind(Tokens, tkContextKeyword);
    Assert.AreEqual(DELPHI_DIRECTIVE_KEYWORD_COUNT, Count, 'keywords: Directive/tkContextKeyword count');
  finally
    Tokens.Free;
  end;
end;

procedure TGoldenTests.Golden_VisibilityKeywords;
var
  Src:    string;
  Tokens: TTokenList;
  Count:  Integer;
begin
  Src := LoadGolden('keywords_visibility.txt');
  CheckStandard(Src, 'visibility keyword list');

  Tokens := FLexer.Tokenize(Src);
  try
    Count := CountKind(Tokens, tkContextKeyword);
    Assert.AreEqual(DELPHI_VISIBILITY_KEYWORD_COUNT, Count, 'keywords: Visibility/tkContextKeyword count');
  finally
    Tokens.Free;
  end;
end;

procedure TGoldenTests.Golden_Literals;
var
  Src:    string;
  Tokens: TTokenList;
begin
  Src := LoadGolden('literals.txt');
  CheckStandard(Src, 'literals');

  Tokens := FLexer.Tokenize(Src);
  try
    Assert.IsTrue(CountKind(Tokens, tkNumber)      > 0, 'literals: tkNumber present');
    Assert.IsTrue(CountKind(Tokens, tkString)      > 0, 'literals: tkString present');
    Assert.IsTrue(CountKind(Tokens, tkCharLiteral) > 0, 'literals: tkCharLiteral present');
  finally
    Tokens.Free;
  end;
end;


procedure TGoldenTests.Golden_Comments;
var
  Src:    string;
  Tokens: TTokenList;
begin
  Src := LoadGolden('comments.txt');
  CheckStandard(Src, 'comments');

  Tokens := FLexer.Tokenize(Src);
  try
    Assert.IsTrue(CountKind(Tokens, tkComment)   > 0, 'comments: tkComment present');
    Assert.IsTrue(CountKind(Tokens, tkDirective) > 0, 'comments: tkDirective present');
  finally
    Tokens.Free;
  end;
end;


procedure TGoldenTests.Golden_Operators;
var
  Src:    string;
  Tokens: TTokenList;
  Idx:    Integer;
begin
  Src := LoadGolden('operators.txt');
  CheckStandard(Src, 'operators');

  // Verify that each multi-char operator appears as a single tkSymbol token.
  Tokens := FLexer.Tokenize(Src);
  try
    Idx := FindTokenIndex(Tokens, ':=');
    Assert.IsTrue(Idx >= 0, 'operators: := found');
    Assert.AreEqual(Ord(tkSymbol), Ord(Tokens[Idx].Kind), 'operators: := is tkSymbol');

    Idx := FindTokenIndex(Tokens, '..');
    Assert.IsTrue(Idx >= 0, 'operators: .. found');
    Assert.AreEqual(Ord(tkSymbol), Ord(Tokens[Idx].Kind), 'operators: .. is tkSymbol');

    Idx := FindTokenIndex(Tokens, '<>');
    Assert.IsTrue(Idx >= 0, 'operators: <> found');
    Assert.AreEqual(Ord(tkSymbol), Ord(Tokens[Idx].Kind), 'operators: <> is tkSymbol');

    Idx := FindTokenIndex(Tokens, '<=');
    Assert.IsTrue(Idx >= 0, 'operators: <= found');
    Assert.AreEqual(Ord(tkSymbol), Ord(Tokens[Idx].Kind), 'operators: <= is tkSymbol');

    Idx := FindTokenIndex(Tokens, '>=');
    Assert.IsTrue(Idx >= 0, 'operators: >= found');
    Assert.AreEqual(Ord(tkSymbol), Ord(Tokens[Idx].Kind), 'operators: >= is tkSymbol');
  finally
    Tokens.Free;
  end;
end;


procedure TGoldenTests.Golden_RealUnit;
var
  Src: string;
begin
  Src := LoadGolden('real_unit.pas');
  CheckStandard(Src, 'real_unit');
end;


initialization

TDUnitX.RegisterTestFixture(TGoldenTests);

end.
