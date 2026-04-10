unit Test.Delphi.Lexer.TokenMetadata;

// Phase 3.4 -- Verify StartOffset and Length for tokens at various positions.
//
// StartOffset: 0-based index of the token's first character in Source.
// Length:      System.Length(Token.Text) -- character count of the token text.
//
// Smoke already covers: first token offset=0, length=len(text),
// line/col = 1/1 for first token, EOF offset = Length(Source).
// This fixture adds: token after whitespace, token after CRLF,
// multiline tokens, and a multi-token sequence offset check.

interface

uses
  DUnitX.TestFramework,
  Delphi.Token,
  Delphi.TokenList,
  Delphi.Lexer;

type

  [TestFixture]
  TTokenMetadataTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TTokenList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Token immediately after leading whitespace has correct StartOffset.
    [Test] procedure Offset_TokenAfterLeadingWhitespace;

    // Token after a CRLF EOL has correct StartOffset.
    [Test] procedure Offset_TokenAfterCRLF;

    // Token after a bare LF EOL has correct StartOffset.
    [Test] procedure Offset_TokenAfterLF;

    // Brace comment: StartOffset=0, Length = len(text).
    [Test] procedure Meta_BraceComment_OffsetAndLength;

    // Comment followed by another token: second token StartOffset is correct.
    [Test] procedure Offset_TokenAfterComment;

    // Multiline brace comment spanning two lines: StartOffset and Length.
    [Test] procedure Meta_MultilineBraceComment_OffsetAndLength;

    // String literal: StartOffset and Length.
    [Test] procedure Meta_StringLiteral_OffsetAndLength;

    // Sequence of tokens: each StartOffset = previous StartOffset + previous Length.
    [Test] procedure Meta_ConsecutiveTokensOffsetChain;

    // tkInvalid char: StartOffset and Length = 1.
    [Test] procedure Meta_InvalidChar_OffsetAndLength;

    // Symbol token '@': kind = tkSymbol, Length = 1.
    [Test] procedure Symbol_AtSign_IsSymbol;

    // Symbol token '^': kind = tkSymbol, Length = 1.
    [Test] procedure Symbol_Caret_IsSymbol;

    // Unrecognised char '!': kind = tkInvalid.
    [Test] procedure Invalid_ExclamationMark_IsInvalid;

    // Unrecognised char '\': kind = tkInvalid.
    [Test] procedure Invalid_Backslash_IsInvalid;

    // Unrecognised char '~': kind = tkInvalid.
    [Test] procedure Invalid_Tilde_IsInvalid;

    // Malformed hex prefix '$' with no digits: tkInvalid, not tkNumber.
    [Test] procedure Invalid_BareHexPrefix_IsInvalid;

    // Malformed char literal '#$' with no hex digits: both chars tkInvalid.
    [Test] procedure Invalid_CharLiteralHashDollarNoDigits_IsInvalid;
  end;

implementation

uses
  System.SysUtils,
  Delphi.TokenKind;


procedure TTokenMetadataTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TTokenMetadataTests.TearDown;
begin
  FLexer.Free;
end;


function TTokenMetadataTests.Tok(const S: string): TTokenList;
begin
  Result := FLexer.Tokenize(S);
end;


// ---------------------------------------------------------------------------

procedure TTokenMetadataTests.Offset_TokenAfterLeadingWhitespace;
// Source: '  begin' -- whitespace (2 chars) then keyword (5 chars).
var
  T: TTokenList;
begin
  T := Tok('  begin');
  try
    // T[0] = tkWhitespace '  '
    Assert.AreEqual(Ord(tkWhitespace), Ord(T[0].Kind), 'T[0] kind');
    Assert.AreEqual(0, T[0].StartOffset, 'T[0] StartOffset');
    Assert.AreEqual(2, T[0].Length, 'T[0] Length');
    // T[1] = Keyword 'begin'
    Assert.AreEqual(Ord(tkStrictKeyword), Ord(T[1].Kind), 'T[1] kind');
    Assert.AreEqual(2, T[1].StartOffset, 'T[1] StartOffset');
    Assert.AreEqual(5, T[1].Length, 'T[1] Length');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Offset_TokenAfterCRLF;
// Source: 'x'#13#10'y' -- 4 chars total.
// T[0]=tkIdent 'x' offset=0 len=1
// T[1]=tkEOL #13#10 offset=1 len=2
// T[2]=tkIdent 'y' offset=3 len=1
var
  T: TTokenList;
begin
  T := Tok('x'#13#10'y');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'T[0] kind');
    Assert.AreEqual(0, T[0].StartOffset, 'T[0] offset');
    Assert.AreEqual(1, T[0].Length, 'T[0] length');

    Assert.AreEqual(Ord(tkEOL), Ord(T[1].Kind), 'T[1] kind');
    Assert.AreEqual(1, T[1].StartOffset, 'T[1] offset');
    Assert.AreEqual(2, T[1].Length, 'T[1] length');

    Assert.AreEqual(Ord(tkIdentifier), Ord(T[2].Kind), 'T[2] kind');
    Assert.AreEqual(3, T[2].StartOffset, 'T[2] offset');
    Assert.AreEqual(1, T[2].Length, 'T[2] length');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Offset_TokenAfterLF;
// Source: 'x'#10'y' -- 3 chars total.
var
  T: TTokenList;
begin
  T := Tok('x'#10'y');
  try
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[0].Kind), 'T[0] kind');
    Assert.AreEqual(0, T[0].StartOffset, 'T[0] offset');

    Assert.AreEqual(Ord(tkEOL), Ord(T[1].Kind), 'T[1] kind');
    Assert.AreEqual(1, T[1].StartOffset, 'T[1] offset');
    Assert.AreEqual(1, T[1].Length, 'T[1] length');

    Assert.AreEqual(Ord(tkIdentifier), Ord(T[2].Kind), 'T[2] kind');
    Assert.AreEqual(2, T[2].StartOffset, 'T[2] offset');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Meta_BraceComment_OffsetAndLength;
// Source: '{hello}' -- 7 chars.
var
  T: TTokenList;
begin
  T := Tok('{hello}');
  try
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(0, T[0].StartOffset, 'StartOffset');
    Assert.AreEqual(7, T[0].Length, 'Length');
    Assert.AreEqual(7, System.Length(T[0].Text), 'len(Text)');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Offset_TokenAfterComment;
// Source: '{hi}X' -- comment (4) then identifier (1).
var
  T: TTokenList;
begin
  T := Tok('{hi}X');
  try
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'T[0] kind');
    Assert.AreEqual(0, T[0].StartOffset, 'T[0] offset');
    Assert.AreEqual(4, T[0].Length, 'T[0] length');

    Assert.AreEqual(Ord(tkIdentifier), Ord(T[1].Kind), 'T[1] kind');
    Assert.AreEqual(4, T[1].StartOffset, 'T[1] offset');
    Assert.AreEqual(1, T[1].Length, 'T[1] length');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Meta_MultilineBraceComment_OffsetAndLength;
// Source: '{line1'#13#10'line2}' -- 13 chars.
// Even though the comment spans two lines, StartOffset=0 and Length=13.
var
  T: TTokenList;
begin
  T := Tok('{line1'#13#10'line2}');
  try
    Assert.AreEqual(Ord(tkComment), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(0, T[0].StartOffset, 'StartOffset');
    Assert.AreEqual(14, T[0].Length, 'Length'); // {(1)+line1(5)+CRLF(2)+line2(5)+}(1) = 14
    Assert.AreEqual(1, T[0].Line, 'Line (start of comment)');
    Assert.AreEqual(1, T[0].Col, 'Col (start of comment)');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Meta_StringLiteral_OffsetAndLength;
// Source: "'hello'" -- 7 chars (including the two single quotes).
var
  T: TTokenList;
begin
  T := Tok('''hello''');
  try
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(0, T[0].StartOffset, 'StartOffset');
    Assert.AreEqual(7, T[0].Length, 'Length');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Meta_ConsecutiveTokensOffsetChain;
// Source: 'ab cd ef' -- three identifiers separated by spaces.
// Each token's StartOffset must equal the previous StartOffset + Length.
var
  Src: string;
  T: TTokenList;
  I: Integer;
  ExpectedOffset: Integer;
begin
  Src := 'ab cd ef';
  T := Tok(Src);
  try
    ExpectedOffset := 0;
    for I := 0 to T.Count - 1 do
    begin
      Assert.AreEqual(ExpectedOffset, T[I].StartOffset,
        'offset of token ' + IntToStr(I));
      Assert.AreEqual(System.Length(T[I].Text), T[I].Length,
        'length of token ' + IntToStr(I));
      Inc(ExpectedOffset, T[I].Length);
    end;
    // Final ExpectedOffset should equal Length(Src) (EOF has Length=0).
    Assert.AreEqual(System.Length(Src), ExpectedOffset, 'sum of lengths = source length');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Meta_InvalidChar_OffsetAndLength;
// Source: '!x' -- '!' is tkInvalid at offset 0, 'x' is identifier at offset 1.
var
  T: TTokenList;
begin
  T := Tok('!x');
  try
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), 'T[0] kind');
    Assert.AreEqual(0, T[0].StartOffset, 'T[0] offset');
    Assert.AreEqual(1, T[0].Length, 'T[0] length');
    Assert.AreEqual(Ord(tkIdentifier), Ord(T[1].Kind), 'T[1] kind');
    Assert.AreEqual(1, T[1].StartOffset, 'T[1] offset');
  finally
    T.Free;
  end;
end;


// Phase 3.3 verification -- symbol dispatch

procedure TTokenMetadataTests.Symbol_AtSign_IsSymbol;
var
  T: TTokenList;
begin
  T := Tok('@X');
  try
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('@', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Symbol_Caret_IsSymbol;
var
  T: TTokenList;
begin
  // '^' is always tkSymbol; hat-notation char literals are resolved by the parser.
  T := Tok('^P');
  try
    Assert.AreEqual(Ord(tkSymbol), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('^', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Invalid_ExclamationMark_IsInvalid;
var
  T: TTokenList;
begin
  T := Tok('!');
  try
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('!', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Invalid_Backslash_IsInvalid;
var
  T: TTokenList;
begin
  T := Tok('\');
  try
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('\', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Invalid_Tilde_IsInvalid;
var
  T: TTokenList;
begin
  T := Tok('~');
  try
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('~', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Invalid_BareHexPrefix_IsInvalid;
var
  T: TTokenList;
begin
  // '$' with nothing after it is not a valid hex literal.
  T := Tok('$');
  try
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), 'kind');
    Assert.AreEqual('$', T[0].Text, 'text');
  finally
    T.Free;
  end;
end;


procedure TTokenMetadataTests.Invalid_CharLiteralHashDollarNoDigits_IsInvalid;
var
  T: TTokenList;
begin
  // '#$' with no following hex digits is not a valid char literal.
  // The lexer emits tkInvalid for '#' and then tkInvalid for '$'.
  T := Tok('#$');
  try
    Assert.AreEqual(NativeInt(3), T.Count, 'tkInvalid(#) + tkInvalid($) + tkEOF');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[0].Kind), '[0] kind');
    Assert.AreEqual('#', T[0].Text, '[0] text');
    Assert.AreEqual(Ord(tkInvalid), Ord(T[1].Kind), '[1] kind');
    Assert.AreEqual('$', T[1].Text, '[1] text');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TTokenMetadataTests);

end.
