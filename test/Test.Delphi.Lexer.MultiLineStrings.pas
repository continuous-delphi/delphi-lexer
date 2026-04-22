unit Test.Delphi.Lexer.MultiLineStrings;

// Multiline string edge cases.
//
// All source strings are built at runtime using RuntimeQuotes(N) because
// ''' cannot be written as a Delphi string literal (it opens a multiline
// string). Use RuntimeQuotes(3) = '''.
//
// Round-trip check is included in every test: concatenating all token
// Text fields must reproduce the original source exactly.

interface

uses
  DUnitX.TestFramework,
  Delphi.Token,
  Delphi.Token.List,
  Delphi.Lexer;

type

  [TestFixture]
  TMultiLineStringTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TTokenList;
    function RoundTrip(T: TTokenList): string;
    function CountStrings(T: TTokenList): Integer;
    function FirstString(T: TTokenList): TToken;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Closing delimiter on its own line, no trailing content.
    [Test] procedure Closing_OnOwnLine;

    // Closing delimiter followed only by whitespace -- still closes, whitespace
    // becomes the next token.
    [Test] procedure Closing_WithTrailingWhitespace;

    // Closing delimiter immediately followed by ';' -- ';' must be a separate
    // token, not consumed as part of the string.
    [Test] procedure Closing_FollowedBySemicolon;

    // Opening ''' immediately followed (after EOL) by closing ''' -- empty
    // multiline string.
    [Test] procedure Empty_OpeningThenClosing;

    // Five single quotes on a content line must not trigger early close.
    [Test] procedure Body_FiveQuotes_DoNotClose;

    // Seven single quotes on a content line must not trigger early close.
    [Test] procedure Body_SevenQuotes_DoNotClose;

    // Closing ''' less indented than the content lines -- still closes.
    [Test] procedure Closing_UnderIndented_StillCloses;

    // No EOL between content and closing ''' -- lexer treats the whole
    // remainder as an unterminated tkString (round-trip still holds).
    [Test] procedure Closing_WithoutPrecedingNewline_IsUnterminated;

    // Content lines with varying indentation -- single tkString, round-trip.
    [Test] procedure Content_VaryingIndent_RoundTrips;

    // General round-trip for a typical multiline string.
    [Test] procedure RoundTrip_TypicalMultiLineString;

    // --- Extended delimiters (5-quote, 7-quote) ---

    // 5-quote delimiter: basic open and close.
    [Test] procedure FiveQuote_OpenAndClose_IstkString;

    // 5-quote delimiter with embedded ''' on a content line -- the motivating
    // use case described in the Yukon language blog post.
    [Test] procedure FiveQuote_EmbeddedTripleQuote_IsSingleToken;

    // 5-quote delimiter: a body line whose ONLY content is ''' at line start
    // must not trigger a close (only exactly 5 quotes would close it).
    [Test] procedure FiveQuote_BodyLineWithTripleQuoteAtLineStart_DoesNotClose;

    // 7-quote delimiter with embedded ''''' (5-quote run) in the body.
    [Test] procedure SevenQuote_EmbeddedFiveQuote_IsSingleToken;

    // Even quote count (6) is not a multiline delimiter; ReadStringLiteral
    // handles it as a normal string containing two apostrophes.
    [Test] procedure EvenQuoteCount_IsNotMultilineOpener;

    // Opening ''' mid-line (after 'S = ') in a const declaration:
    // verifies IsOpeningTripleQuote fires even when not at column 1.
    [Test] procedure Ported_BasicContext_InConstDecl;

    // Five quotes in body within a const declaration context.
    [Test] procedure Ported_FiveQuotesInContext;

    // Closing ''' on same physical line as content (not at AtLineStart):
    // string is unterminated, no standalone ';' symbol.
    [Test] procedure Ported_ClosingOnSameLine_IsUnterminated;

    // The newline immediately before the closing ''' must appear in the
    // token text (the compiler strips it at evaluation, not the lexer).
    [Test] procedure Ported_FinalNewlinePreservedInToken;
  end;

implementation

uses
  System.SysUtils,
  Delphi.TokenKind,
  Delphi.Lexer.Scanner;

const
  CRLF = #13#10;


procedure TMultiLineStringTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TMultiLineStringTests.TearDown;
begin
  FLexer.Free;
end;


function TMultiLineStringTests.Tok(const S: string): TTokenList;
begin
  Result := FLexer.Tokenize(S);
end;


function TMultiLineStringTests.RoundTrip(T: TTokenList): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to T.Count - 1 do
    Result := Result + T[I].Text;
end;


// ---------------------------------------------------------------------------

procedure TMultiLineStringTests.Closing_OnOwnLine;
var
  Q3, Src: string;
  T: TTokenList;
begin
  Q3  := RuntimeQuotes(3);
  Src := Q3 + CRLF + 'hello' + CRLF + Q3;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, T[0].Text, 'text covers full source');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.Closing_WithTrailingWhitespace;
var
  Q3, Src, Trail: string;
  T: TTokenList;
begin
  Q3    := RuntimeQuotes(3);
  Trail := '   ';
  Src   := Q3 + CRLF + 'hello' + CRLF + Q3 + Trail;
  T := Tok(Src);
  try
    // String token ends right after the closing '''; trailing spaces are
    // a separate tkWhitespace token.
    Assert.AreEqual(NativeInt(3), T.Count, 'count: string + whitespace + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'T[0] kind');
    Assert.AreEqual(Q3 + CRLF + 'hello' + CRLF + Q3, T[0].Text, 'string text');
    Assert.AreEqual(Ord(tkWhitespace), Ord(T[1].Kind), 'T[1] kind');
    Assert.AreEqual(Trail, T[1].Text, 'trailing whitespace');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.Closing_FollowedBySemicolon;
var
  Q3, Src: string;
  T: TTokenList;
begin
  Q3  := RuntimeQuotes(3);
  Src := Q3 + CRLF + 'content' + CRLF + Q3 + ';';
  T := Tok(Src);
  try
    // String token, then ';' as separate tkSymbol, then EOF.
    Assert.AreEqual(NativeInt(3), T.Count, 'count: string + semicolon + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'T[0] kind');
    Assert.AreEqual(Q3 + CRLF + 'content' + CRLF + Q3, T[0].Text, 'string text');
    Assert.AreEqual(Ord(tkSymbol), Ord(T[1].Kind), 'T[1] kind');
    Assert.AreEqual(';', T[1].Text, 'semicolon text');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.Empty_OpeningThenClosing;
var
  Q3, Src: string;
  T: TTokenList;
begin
  Q3  := RuntimeQuotes(3);
  Src := Q3 + CRLF + Q3;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: empty string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, T[0].Text, 'text');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.Body_FiveQuotes_DoNotClose;
var
  Q3, Src: string;
  T: TTokenList;
begin
  Q3  := RuntimeQuotes(3);
  // Body line has ''''' (5 quotes): the 4th quote after a line-start probe
  // disqualifies it as a closing delimiter.
  Src := Q3 + CRLF + RuntimeQuotes(5) + CRLF + Q3;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, T[0].Text, 'text covers full source');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.Body_SevenQuotes_DoNotClose;
var
  Q3, Src: string;
  T: TTokenList;
begin
  Q3  := RuntimeQuotes(3);
  Src := Q3 + CRLF + RuntimeQuotes(7) + CRLF + Q3;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, T[0].Text, 'text covers full source');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.Closing_UnderIndented_StillCloses;
var
  Q3, Src: string;
  T: TTokenList;
begin
  Q3  := RuntimeQuotes(3);
  // Content is deeply indented; closing ''' is at column 1.
  // The lexer must still find the closing delimiter regardless of
  // relative indentation.
  Src := Q3 + CRLF + '      deepcontent' + CRLF + Q3;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, T[0].Text, 'text');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.Closing_WithoutPrecedingNewline_IsUnterminated;
var
  Q3, Src: string;
  T: TTokenList;
begin
  Q3  := RuntimeQuotes(3);
  // Closing ''' is on the same physical line as content (no EOL before it).
  // The lexer never sees AtLineStart while scanning the content+closing chars,
  // so it consumes the entire source as an unterminated tkString.
  Src := Q3 + CRLF + 'content' + Q3;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: unterminated string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, T[0].Text, 'unterminated: text = entire source');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.Content_VaryingIndent_RoundTrips;
var
  Q3, Src: string;
  T: TTokenList;
begin
  Q3  := RuntimeQuotes(3);
  Src := Q3 + CRLF +
         'line1' + CRLF +
         '  line2' + CRLF +
         '    line3' + CRLF +
         '  line4' + CRLF +
         Q3;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, T[0].Text, 'text covers full source');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.RoundTrip_TypicalMultiLineString;
var
  Q3, Src: string;
  T: TTokenList;
begin
  Q3  := RuntimeQuotes(3);
  Src := Q3 + CRLF +
         '  Hello, world!' + CRLF +
         '  Line two.' + CRLF +
         Q3;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


function TMultiLineStringTests.CountStrings(T: TTokenList): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to T.Count - 1 do
    if T[I].Kind = tkString then Inc(Result);
end;


function TMultiLineStringTests.FirstString(T: TTokenList): TToken;
var
  I: Integer;
begin
  for I := 0 to T.Count - 1 do
    if T[I].Kind = tkString then Exit(T[I]);
  Result.Kind := tkEOF;
  Result.Text := '';
end;


// ---------------------------------------------------------------------------
// Extended delimiters
// ---------------------------------------------------------------------------

procedure TMultiLineStringTests.FiveQuote_OpenAndClose_IstkString;
var
  Q5, Src: string;
  T: TTokenList;
begin
  Q5  := RuntimeQuotes(5);
  Src := Q5 + CRLF + 'hello' + CRLF + Q5;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, T[0].Text, 'text covers full source');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.FiveQuote_EmbeddedTripleQuote_IsSingleToken;
var
  Q3, Q5, Src: string;
  T: TTokenList;
begin
  Q3 := RuntimeQuotes(3);
  Q5 := RuntimeQuotes(5);
  // Replicates the blog example:
  //   '''''
  //   some text
  //   and now '''
  //   some more text
  //   '''''
  // The ''' mid-line and the ''' on its own line must not close the string.
  Src := Q5 + CRLF +
         'some text' + CRLF +
         'and now ' + Q3 + CRLF +
         'some more text' + CRLF +
         Q5;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, T[0].Text, 'full source in one token');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.FiveQuote_BodyLineWithTripleQuoteAtLineStart_DoesNotClose;
var
  Q3, Q5, Src: string;
  T: TTokenList;
begin
  Q3 := RuntimeQuotes(3);
  Q5 := RuntimeQuotes(5);
  // Body line is exactly ''' at AtLineStart with nothing after it.
  // With a 5-quote delimiter, only ''''' would close -- ''' must not.
  Src := Q5 + CRLF + Q3 + CRLF + Q5;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, T[0].Text, 'text');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.SevenQuote_EmbeddedFiveQuote_IsSingleToken;
var
  Q5, Q7, Src: string;
  T: TTokenList;
begin
  Q5 := RuntimeQuotes(5);
  Q7 := RuntimeQuotes(7);
  Src := Q7 + CRLF +
         'some text' + CRLF +
         'embedded: ' + Q5 + CRLF +
         'more text' + CRLF +
         Q7;
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(Src, T[0].Text, 'full source in one token');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.EvenQuoteCount_IsNotMultilineOpener;
var
  Src: string;
  T:   TTokenList;
begin
  // Six quotes: even count, so DetectMultilineDelimiterLength returns 0.
  // ReadStringLiteral handles it: '' (opening quote, doubled '', doubled '',
  // closing quote). Result: tkString containing two apostrophes.
  Src := RuntimeQuotes(6);
  T := Tok(Src);
  try
    Assert.AreEqual(NativeInt(2), T.Count, 'count: string + EOF');
    Assert.AreEqual(Ord(tkString), Ord(T[0].Kind), 'kind');
    Assert.AreEqual(RuntimeQuotes(6), T[0].Text, 'text = all 6 quotes');
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
  finally
    T.Free;
  end;
end;


// ---------------------------------------------------------------------------
// Phase 5: ported tests
// ---------------------------------------------------------------------------

procedure TMultiLineStringTests.Ported_BasicContext_InConstDecl;
// Opening ''' appears after '  S = ' on the same line (not at column 1).
// IsOpeningTripleQuote must still recognise it because nothing follows '''
// on that line. Verifies exactly one tkString token covering opening through
// closing ''', round-trip exact.
var
  Q3, Src: string;
  T: TTokenList;
  StrTok: TToken;
begin
  Q3 := RuntimeQuotes(3);
  Src := 'const' + sLineBreak
       + '  S = ' + Q3 + sLineBreak
       + 'line 1' + sLineBreak
       + 'line 2' + sLineBreak
       + Q3 + ';' + sLineBreak;
  T := Tok(Src);
  try
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
    Assert.AreEqual(1, CountStrings(T), 'exactly one tkString token');
    StrTok := FirstString(T);
    Assert.AreEqual(Q3, Copy(StrTok.Text, 1, 3), 'starts with '''+ Q3 +'''');
    Assert.AreEqual(Q3,
      Copy(StrTok.Text, Length(StrTok.Text) - 2, 3), 'ends with '''+ Q3 +'''');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.Ported_FiveQuotesInContext;
// Five single quotes in a body line within a const declaration context.
var
  Q3, Src: string;
  T: TTokenList;
begin
  Q3  := RuntimeQuotes(3);
  Src := 'const' + sLineBreak
       + '  S = ' + Q3 + sLineBreak
       + 'before' + sLineBreak
       + 'a ' + RuntimeQuotes(5) + ' triple inside' + sLineBreak
       + 'after' + sLineBreak
       + Q3 + ';' + sLineBreak;
  T := Tok(Src);
  try
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
    Assert.AreEqual(1, CountStrings(T), 'exactly one tkString token');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.Ported_ClosingOnSameLine_IsUnterminated;
// Closing ''' is on the same physical line as 'line 1' content (not at line
// start). The lexer must NOT treat it as a closing delimiter.
// Result: the string token swallows everything through the final EOL;
// no standalone ';' symbol token is produced.
var
  Q3, Src: string;
  T: TTokenList;
  I, SemiCount: Integer;
begin
  Q3  := RuntimeQuotes(3);
  Src := 'const' + sLineBreak
       + '  S = ' + Q3 + sLineBreak
       + 'line 1 ' + Q3 + ';' + sLineBreak;
  T := Tok(Src);
  try
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
    Assert.AreEqual(1, CountStrings(T), 'exactly one tkString token');

    SemiCount := 0;
    for I := 0 to T.Count - 1 do
      if (T[I].Kind = tkSymbol) and (T[I].Text = ';') then
        Inc(SemiCount);
    Assert.AreEqual(0, SemiCount, 'no standalone semicolon token');
  finally
    T.Free;
  end;
end;


procedure TMultiLineStringTests.Ported_FinalNewlinePreservedInToken;
// The newline immediately before the closing ''' must be present in the
// tkString token text. The compiler strips it at value evaluation, but
// the lexer must preserve it for round-trip fidelity.
var
  Q3, Src: string;
  T: TTokenList;
  StrTok: TToken;
begin
  Q3  := RuntimeQuotes(3);
  Src := 'const' + sLineBreak
       + '  S = ' + Q3 + sLineBreak
       + 'line 1' + sLineBreak
       + 'line 2' + sLineBreak
       + Q3 + ';' + sLineBreak;
  T := Tok(Src);
  try
    Assert.AreEqual(Src, RoundTrip(T), 'round-trip');
    Assert.AreEqual(1, CountStrings(T), 'one tkString token');

    StrTok := FirstString(T);
    // The token text must end with <newline>''' where newline is sLineBreak.
    Assert.IsTrue(
      StrTok.Text.EndsWith(sLineBreak + Q3),
      'string token text must include the final newline before closing '''+ Q3 +'''');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TMultiLineStringTests);

end.
