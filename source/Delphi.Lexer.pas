unit Delphi.Lexer;

// TDelphiLexer -- stateless Object Pascal source lexer.
//
// Usage:
//   Lexer := TDelphiLexer.Create;
//   Tokens := Lexer.Tokenize(SourceText);
//   // ... use Tokens ...
//   Tokens.Free;
//   Lexer.Free;
//
// Guarantees:
//   - Every character of Source appears in exactly one token's Text field.
//   - Concatenating Text across all tokens reconstructs Source exactly
//     (round-trip guarantee).
//   - The final token is always tkEOF with Text = ''.
//   - Token.StartOffset is the 0-based character index of the first character
//     of the token in Source. Token.Length = System.Length(Token.Text).
//   - Keywords are classified case-insensitively (BEGIN -> tkStrictKeyword).
//   - &ident escaped identifiers are always tkIdentifier, never tkStrictKeyword|tkContextKeyword.

interface

uses
  Delphi.Token,
  Delphi.TokenList;

type
  // Stateless lexer: create, call Tokenize (or TokenizeInto), free.
  TDelphiLexer = class
  protected
    procedure TokenizeIntoEmptyList(const Source: string; const OutTokens: TTokenList);
  public
    function Tokenize(const Source: string): TTokenList;
    procedure TokenizeInto(const Source: string; const OutTokens: TTokenList);
  end;

// Returns a string of Count single-quote characters.
// This helper exists because ''' cannot be written as a string literal in
// Delphi source (three single quotes open a multiline string). Use it to
// build expected values in tests: RuntimeQuotes(3) produces '''.
function RuntimeQuotes(const Count: Integer): string; inline;

// Returns the index of the token in ATokens whose span contains AOffset
// (0-based character index into the source string).
//
// Binary search on StartOffset; O(log N).
//
// Returns -1 for:
//   - negative AOffset
//   - AOffset at or beyond the source length (the tkEOF sentinel position and
//     any value past it) -- callers should not expect a valid index for an
//     offset equal to Source.Length even though it is not "negative"
//   - empty ATokens
//
// tkEOF is never returned: its Length is 0, so the span check
// (AOffset < StartOffset + Length) is always false for it by design.
function FindTokenAtOffset(const ATokens: TTokenList; AOffset: Integer): Integer;

implementation

uses
  System.SysUtils,
  Delphi.TokenKind,
  Delphi.Keywords,
  Delphi.Lexer.Scanner;


// =========================================================================
// RuntimeQuotes
// =========================================================================

function RuntimeQuotes(const Count: Integer): string;
begin
  Result := StringOfChar(CHAR_SINGLE_QUOTE, Count);
end;


function FindTokenAtOffset(const ATokens: TTokenList; AOffset: Integer): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  if (ATokens.Count = 0) or (AOffset < 0) then
    Exit(-1);

  Lo := 0;
  Hi := ATokens.Count - 1;
  while Lo < Hi do
  begin
    Mid := (Lo + Hi + 1) div 2;
    if ATokens[Mid].StartOffset <= AOffset then
      Lo := Mid
    else
      Hi := Mid - 1;
  end;
  // Lo is the largest index with StartOffset <= AOffset.
  // Verify AOffset falls within the token's span [StartOffset .. StartOffset+Length-1].
  // Deliberately handles tkEOF: its Length is 0, so StartOffset + 0 = StartOffset,
  // and AOffset < StartOffset is false when AOffset = StartOffset -- returning -1
  // as required rather than the EOF sentinel index.
  if AOffset < ATokens[Lo].StartOffset + ATokens[Lo].Length then
    Result := Lo
  else
    Result := -1;
end;


// =========================================================================
// MakeToken
// =========================================================================

function MakeToken(AKind: TTokenKind; const AText: string; ALine, ACol, AStartOffset: Integer): TToken;
begin
  Result.Kind                       := AKind;
  Result.Text                       := AText;
  Result.Line                       := ALine;
  Result.Col                        := ACol;
  Result.StartOffset                := AStartOffset;
  Result.Length                     := System.Length(AText);
  Result.LeadingTrivia.FirstTokenIndex  := -1;
  Result.LeadingTrivia.LastTokenIndex   := -1;
  Result.TrailingTrivia.FirstTokenIndex := -1;
  Result.TrailingTrivia.LastTokenIndex  := -1;
end;


// =========================================================================
// Read helpers
// =========================================================================

function ReadStringLiteral(var Sc: TScanner): string;
var
  Start: Integer;
begin
  // Precondition: at opening single quote.
  // Single-quoted strings do not cross line boundaries. If no closing quote
  // appears before the end of the current line, the string token ends at the
  // EOL and the EOL is left unconsumed for the normal EOL dispatch. This
  // prevents a malformed string from silently swallowing subsequent lines.
  Start := Sc.I;
  IncI(Sc); // consume opening '
  while Sc.I <= Sc.N do
  begin
    if Peek(Sc) = #0 then Break;
    if (Peek(Sc) = #13) or (Peek(Sc) = #10) then Break; // stop at EOL
    if Peek(Sc) = CHAR_SINGLE_QUOTE then
    begin
      if Peek(Sc, 1) = CHAR_SINGLE_QUOTE then
      begin
        IncI(Sc, 2); // doubled quote inside string
      end
      else
      begin
        IncI(Sc); // closing '
        Break;
      end;
    end
    else
      IncI(Sc);
  end;
  Result := Copy(Sc.S, Start, Sc.I - Start);
end;


// Returns the number of single quotes forming a multiline string delimiter
// at the current scanner position, or 0 if the position is not the start of
// a multiline delimiter.
//
// A multiline delimiter is an odd number of single quotes >= 3, followed by
// nothing but optional spaces/tabs and then an EOL (or EOF). Supported widths:
// 3 (standard), 5, 7, ... Each width N allows the body to contain runs of up
// to N-2 consecutive quotes at the start of a line. To embed a triple-quote
// sequence inside a multiline string, use a 5-quote delimiter; to embed five
// consecutive quotes, use a 7-quote delimiter, and so on.
//
// Even quote counts (2, 4, 6, ...) are not delimiters -- they are runs of
// escaped quotes inside a regular single-quoted string.
function DetectMultilineDelimiterLength(var Sc: TScanner): Integer;
var
  Q:        Integer;
  PosAfter: Integer;
  NextChar: Char;
begin
  Result := 0;

  // Count consecutive single quotes starting at current position.
  Q := 0;
  while Peek(Sc, Q) = CHAR_SINGLE_QUOTE do
    Inc(Q);

  // Must be odd and >= 3.
  if (Q < 3) or ((Q mod 2) = 0) then
    Exit;

  // Everything between the end of the quote run and the next EOL must be
  // spaces or tabs (the opening delimiter line may have trailing whitespace).
  PosAfter := Sc.I + Q; // 1-based index of first char after the quote run
  while PosAfter <= Sc.N do
  begin
    NextChar := Sc.S[PosAfter];
    if (NextChar = #13) or (NextChar = #10) then
      Break;                    // EOL found -- valid opener
    if not IsWhitespaceChar(NextChar) then
      Exit;                     // non-whitespace before EOL -- not a delimiter
    Inc(PosAfter);
  end;

  Result := Q;
end;


(*
  ReadMultiLineString: consume a Delphi multiline (triple-or-wider-quoted) string.

  Opening: DelimLen single quotes (3, 5, 7, ...) optionally followed by
  trailing whitespace and then an EOL. The body may span any number of lines.
  Closing: a line containing optional leading whitespace and then exactly
  DelimLen quotes where the character after them is not another quote.

  Using a wider delimiter allows the body to contain runs of fewer than
  DelimLen consecutive quotes at the start of a line. For example, a 5-quote
  delimiter allows ''' to appear on its own body line without closing the string.

  The closing delimiter may be followed by other tokens (e.g. ';') on the
  same line -- those are left unconsumed for the caller.

  Precondition: Sc positioned at the first quote of the opening delimiter.
  DelimLen is the value returned by DetectMultilineDelimiterLength.
*)
function ReadMultiLineString(var Sc: TScanner; DelimLen: Integer): string;
var
  Start:           Integer;
  SaveI:           Integer;
  SaveLine:        Integer;
  SaveCol:         Integer;
  DelimStr: string;
begin
  Start := Sc.I;

  // Consume opening delimiter (DelimLen quotes) and the optional EOL.
  IncI(Sc, DelimLen);
  ReadEOLIfPresent(Sc);

  DelimStr := RuntimeQuotes(DelimLen);

  // Scan lines until a line that begins with optional whitespace then exactly
  // DelimLen quotes followed by a non-quote character (closing delimiter).
  while Sc.I <= Sc.N do
  begin
    if Sc.AtLineStart then
    begin
      // (I-8) Save full scanner state before probing for the closing delimiter.
      SaveI           := Sc.I;
      SaveLine        := Sc.Line;
      SaveCol         := Sc.Col;

      // Skip any leading spaces/tabs on this line.
      while (Sc.I <= Sc.N) and IsWhitespaceChar(Peek(Sc)) do
        IncI(Sc);

      // Check for exactly DelimLen quotes followed by a non-quote.
      if (PeekSeq(Sc, DelimLen) = DelimStr) and
         (Peek(Sc, DelimLen) <> CHAR_SINGLE_QUOTE) then
      begin
        IncI(Sc, DelimLen); // consume closing delimiter
        Exit(Copy(Sc.S, Start, Sc.I - Start));
      end;

      // (I-8) Not a terminator -- restore full state and continue.
      // (Separate var for Sc.AtLineStart is redundant, known true)
      Sc.I           := SaveI;
      Sc.Line        := SaveLine;
      Sc.Col         := SaveCol;
      Sc.AtLineStart := True;
    end;

    IncI(Sc);
  end;

  // Unterminated multiline string: return everything up to EOF.
  Result := Copy(Sc.S, Start, Sc.I - Start);
end;


// Reads a single #nn or #$hex character literal token.
// Precondition: at '#'; next char is a digit or '$'.
function ReadCharLiteral(var Sc: TScanner): string;
var
  Start: Integer;
begin
  Start := Sc.I;
  IncI(Sc); // consume '#'
  if Peek(Sc) = '$' then
  begin
    IncI(Sc); // consume '$'
    while CharInSet(Peek(Sc), ['0'..'9', 'A'..'F', 'a'..'f']) do
      IncI(Sc);
  end
  else
  begin
    while CharInSet(Peek(Sc), ['0'..'9']) do
      IncI(Sc);
  end;
  Result := Copy(Sc.S, Start, Sc.I - Start);
end;


// Reads a binary integer literal %0101...
// Precondition: at '%'; next char is '0' or '1'.
function ReadBinaryLiteral(var Sc: TScanner): string;
var
  Start: Integer;
begin
  Start := Sc.I;
  IncI(Sc); // consume '%'
  while CharInSet(Peek(Sc), ['0', '1', '_']) do
    IncI(Sc);
  Result := Copy(Sc.S, Start, Sc.I - Start);
end;


function ReadBraceComment(var Sc: TScanner): string;
var
  Start: Integer;
begin
  Start := Sc.I; // at '{'
  IncI(Sc);      // consume '{'
  while (Sc.I <= Sc.N) and (Peek(Sc) <> '}') do
    IncI(Sc);
  if Peek(Sc) = '}' then IncI(Sc); // consume '}'
  Result := Copy(Sc.S, Start, Sc.I - Start);
end;


function ReadParenStarComment(var Sc: TScanner): string;
var
  Start: Integer;
begin
  Start := Sc.I; // at '(' with '*' following
  IncI(Sc, 2);   // consume '(*'
  while Sc.I <= Sc.N do
  begin
    if (Peek(Sc) = '*') and (Peek(Sc, 1) = ')') then
    begin
      IncI(Sc, 2); // consume '*)'
      Break;
    end;
    IncI(Sc);
  end;
  Result := Copy(Sc.S, Start, Sc.I - Start);
end;


function ReadSlashSlashComment(var Sc: TScanner): string;
var
  Start: Integer;
begin
  Start := Sc.I; // at first '/'
  IncI(Sc, 2);   // consume '//'
  while (Sc.I <= Sc.N) and (Peek(Sc) <> #13) and (Peek(Sc) <> #10) do
    IncI(Sc);
  Result := Copy(Sc.S, Start, Sc.I - Start);
end;


function ReadWhitespace(var Sc: TScanner): string;
var
  Start: Integer;
begin
  Start := Sc.I;
  while (Sc.I <= Sc.N) and IsWhitespaceChar(Peek(Sc)) do  // spaces and tabs (+VT/FF/^Z); EOL handled separately
    IncI(Sc);
  Result := Copy(Sc.S, Start, Sc.I - Start);
end;


function ReadIdentifierOrNumber(var Sc: TScanner): string;
var
  Start:           Integer;
  SaveI:           Integer;
  SaveLine:        Integer;
  SaveCol:         Integer;
  SaveAtLineStart: Boolean;
begin
  Start := Sc.I;

  // Identifier: starts with letter or underscore.
  if IsIdentStart(Peek(Sc)) then
  begin
    IncI(Sc);
    while IsIdentChar(Peek(Sc)) do
      IncI(Sc);
    Exit(Copy(Sc.S, Start, Sc.I - Start));
  end;

  // Hex literal: $HH...
  if Peek(Sc) = '$' then
  begin
    IncI(Sc); // consume '$'
    while CharInSet(Peek(Sc), ['0'..'9', 'A'..'F', 'a'..'f', '_']) do
      IncI(Sc);
    Exit(Copy(Sc.S, Start, Sc.I - Start));
  end;

  // Decimal integer or float (3  42  3.14  1.5e10  2.0e-3  1e6).
  // Underscores are allowed as digit separators in all three parts
  // (e.g. 1_000, 3.14_15, 1e1_0), matching the rule for hex/binary/octal.
  if CharInSet(Peek(Sc), ['0'..'9']) then
  begin
    // Integer part.
    while CharInSet(Peek(Sc), ['0'..'9', '_']) do
      IncI(Sc);
    // Fractional part: .digits -- guard against '..' range operator.
    // The char after '.' must be a digit (not '_') to enter this branch.
    if (Peek(Sc) = '.') and (Peek(Sc, 1) <> '.') and
       CharInSet(Peek(Sc, 1), ['0'..'9']) then
    begin
      IncI(Sc); // consume '.'
      while CharInSet(Peek(Sc), ['0'..'9', '_']) do
        IncI(Sc);
    end;
    // Exponent: e or E, optional +/-, one-or-more digits.
    // Save full scanner state before consuming 'e'/'E': if no digits follow
    // (with or without a sign), restore so the 'e' is left for the identifier
    // path. This gives '1exit' -> tkNumber('1') + tkIdentifier('exit') rather
    // than tkNumber('1e') or tkInvalid('1e') + tkIdentifier('xit').
    if CharInSet(Peek(Sc), ['e', 'E']) then
    begin
      SaveI           := Sc.I;
      SaveLine        := Sc.Line;
      SaveCol         := Sc.Col;
      SaveAtLineStart := Sc.AtLineStart;
      IncI(Sc); // consume 'e'/'E'
      if CharInSet(Peek(Sc), ['+', '-']) then
        IncI(Sc); // consume sign (tentative)
      if CharInSet(Peek(Sc), ['0'..'9', '_']) then
      begin
        while CharInSet(Peek(Sc), ['0'..'9', '_']) do
          IncI(Sc);
      end
      else
      begin
        // No digits after 'e' (or after 'e+/-'): backtrack to before 'e'.
        Sc.I           := SaveI;
        Sc.Line        := SaveLine;
        Sc.Col         := SaveCol;
        Sc.AtLineStart := SaveAtLineStart;
      end;
    end;
    Exit(Copy(Sc.S, Start, Sc.I - Start));
  end;

  // Fallback: consume one character.
  // Unreachable under current dispatch: the caller only enters this function
  // when Peek(Sc) is a letter, underscore, '$' with a following hex digit/
  // underscore, or '0'..'9' -- all of which are handled by the branches above.
  // Retained as a defensive safety net in case the dispatch changes.
  IncI(Sc);
  Result := Copy(Sc.S, Start, 1);
end;


function ReadSymbol(var Sc: TScanner): string;
var
  C1, C2: Char;
begin
  C1 := Peek(Sc);
  C2 := Peek(Sc, 1);
  // Multi-char operators MUST be tested before their single-char prefixes
  // (invariant I-13). If single chars were checked first, ':=' would produce
  // tkSymbol(':') + tkSymbol('=') rather than a single tkSymbol(':=').
  if (C1 = ':') and (C2 = '=') then begin Result := ':='; IncI(Sc, 2); Exit; end;
  if (C1 = '<') and (C2 = '=') then begin Result := '<='; IncI(Sc, 2); Exit; end;
  if (C1 = '>') and (C2 = '=') then begin Result := '>='; IncI(Sc, 2); Exit; end;
  if (C1 = '<') and (C2 = '>') then begin Result := '<>'; IncI(Sc, 2); Exit; end;
  if (C1 = '.') and (C2 = '.') then begin Result := '..'; IncI(Sc, 2); Exit; end;
  if (C1 = '<') and (C2 = '<') then begin Result := '<<'; IncI(Sc, 2); Exit; end;
  if (C1 = '>') and (C2 = '>') then begin Result := '>>'; IncI(Sc, 2); Exit; end;
  // Single-char.
  Result := C1;
  IncI(Sc);
end;


// =========================================================================
// ScanAsmBodyUntilTerminatingEnd
// =========================================================================
//
// Scans from the current scanner position to the first standalone 'end' that
// terminates a Delphi asm...end block, returning all consumed text as the body.
//
// The terminating 'end' must satisfy all of the following:
//   - Case-insensitive match of e/E, n/N, d/D.
//   - Not preceded by an identifier character (rules out 'vendor', 'lend').
//   - Not followed by an identifier character (rules out 'endian', 'endless').
//   - Not inside a //, { }, or (* *) comment or directive, or a quoted string.
//
// RC1 nesting policy: shallow -- the first valid standalone 'end' terminates
// the body regardless of any nested begin/end structure inside the asm text.
//
// On return, Sc is positioned at the 'e' of the terminating 'end', or at
// Sc.N + 1 if the source ends before a terminating 'end' is found.

function ScanAsmBodyUntilTerminatingEnd(var Sc: TScanner): string;
var
  Start:            Integer;
  PrevWasIdentChar: Boolean;
  C:                Char;
begin
  Start := Sc.I;
  PrevWasIdentChar := False;

  while Sc.I <= Sc.N do
  begin
    C := Peek(Sc);

    // Skip // line comment: consume from '//' to end of line, exclusive.
    // 'end' appearing inside a line comment does not terminate the block.
    if (C = '/') and (Peek(Sc, 1) = '/') then
    begin
      IncI(Sc, 2);
      while (Sc.I <= Sc.N) and (Peek(Sc) <> #13) and (Peek(Sc) <> #10) do
        IncI(Sc);
      PrevWasIdentChar := False;
      Continue;
    end;

    // Skip { } block comment or {$ } directive.
    // 'end' appearing inside does not terminate the block.
    if C = '{' then
    begin
      IncI(Sc); // consume '{'
      while (Sc.I <= Sc.N) and (Peek(Sc) <> '}') do
        IncI(Sc);
      if Peek(Sc) = '}' then
        IncI(Sc); // consume '}'
      PrevWasIdentChar := False;
      Continue;
    end;

    // Skip (* *) block comment or (*$ *) directive.
    // 'end' appearing inside does not terminate the block.
    if (C = '(') and (Peek(Sc, 1) = '*') then
    begin
      IncI(Sc, 2); // consume '(*'
      while Sc.I <= Sc.N do
      begin
        if (Peek(Sc) = '*') and (Peek(Sc, 1) = ')') then
        begin
          IncI(Sc, 2); // consume '*)'
          Break;
        end;
        IncI(Sc);
      end;
      PrevWasIdentChar := False;
      Continue;
    end;

    // Skip single-quoted string. Stops at EOL if unterminated on this line,
    // matching the main lexer's single-line string rule.
    // 'end' appearing inside a string does not terminate the block.
    if C = CHAR_SINGLE_QUOTE then
    begin
      IncI(Sc); // consume opening quote
      while Sc.I <= Sc.N do
      begin
        if (Peek(Sc) = #13) or (Peek(Sc) = #10) then
          Break; // unterminated string: stop at EOL
        if Peek(Sc) = CHAR_SINGLE_QUOTE then
        begin
          IncI(Sc); // consume quote
          if Peek(Sc) <> CHAR_SINGLE_QUOTE then
            Break;  // closing quote -- done
          IncI(Sc); // doubled quote inside string -- stay in string
        end
        else
          IncI(Sc);
      end;
      PrevWasIdentChar := False;
      Continue;
    end;

    // Check for standalone 'end' keyword (case-insensitive, both word boundaries).
    if (not PrevWasIdentChar) and
       CharInSet(C, ['e', 'E']) and
       CharInSet(Peek(Sc, 1), ['n', 'N']) and
       CharInSet(Peek(Sc, 2), ['d', 'D']) and
       (not IsIdentChar(Peek(Sc, 3))) then
      Break; // leave scanner at 'e' of 'end'; caller emits it as tkStrictKeyword

    PrevWasIdentChar := IsIdentChar(C);
    IncI(Sc);
  end;

  Result := Copy(Sc.S, Start, Sc.I - Start);
end;


// =========================================================================
// ApplyTriviaSpans
// =========================================================================
//
// Single O(N) pass over the flat token list produced by TokenizeInto.
// Assigns LeadingTrivia and TrailingTrivia spans to every semantic token
// (and to the tkEOF sentinel as the anchor for trailing-file trivia).
// Trivia tokens themselves retain their MakeToken-initialized empty spans.
//
// Trailing trivia: same-line tokens immediately after the semantic token,
//   through and including the first tkEOL encountered (if any).
// Leading trivia:  everything from the end of the previous token's trailing
//   span up to (but not including) the current token.

procedure ApplyTriviaSpans(Tokens: TTokenList);
var
  I, LeadFirst, J: Integer;
  T: TToken;
begin
  LeadFirst := 0;

  for I := 0 to Tokens.Count - 1 do
  begin
    if IsLexicalTrivia(Tokens[I].Kind) then
      Continue;

    // Semantic token or tkEOF sentinel at I.
    T := Tokens[I];

    // Leading trivia: [LeadFirst .. I-1]
    if I > LeadFirst then
    begin
      T.LeadingTrivia.FirstTokenIndex := LeadFirst;
      T.LeadingTrivia.LastTokenIndex  := I - 1;
    end
    else
    begin
      T.LeadingTrivia.FirstTokenIndex := -1;
      T.LeadingTrivia.LastTokenIndex  := -1;
    end;

    // Trailing trivia: scan forward through same-line trivia, stop after EOL.
    J := I + 1;
    while (J < Tokens.Count) and IsLexicalTrivia(Tokens[J].Kind) do
    begin
      if Tokens[J].Kind = tkEOL then
      begin
        Inc(J);  // include the EOL in the trailing span
        Break;
      end;
      Inc(J);
    end;
    // Trailing covers [I+1 .. J-1]
    if J > I + 1 then
    begin
      T.TrailingTrivia.FirstTokenIndex := I + 1;
      T.TrailingTrivia.LastTokenIndex  := J - 1;
    end
    else
    begin
      T.TrailingTrivia.FirstTokenIndex := -1;
      T.TrailingTrivia.LastTokenIndex  := -1;
    end;

    Tokens[I] := T;
    LeadFirst := J;
  end;
end;


// =========================================================================
// TDelphiLexer
// =========================================================================

function TDelphiLexer.Tokenize(const Source: string):TTokenList;
begin
  Result := TTokenList.Create;
  TokenizeIntoEmptyList(Source, Result);
end;


procedure TDelphiLexer.TokenizeInto(const Source: string; const OutTokens: TTokenList);
var
  Temp:TTokenList;
  StartIndex, I: Integer;
  Tok:TToken;
begin

  Temp := TTokenList.Create;
  try
    TokenizeIntoEmptyList(Source, Temp);

    StartIndex := OutTokens.Count;
    OutTokens.Capacity := StartIndex + Temp.Count;

    for I := 0 to Temp.Count - 1 do
    begin
      Tok := Temp[I];
      if not Tok.LeadingTrivia.IsEmpty then
      begin
        Inc(Tok.LeadingTrivia.FirstTokenIndex, StartIndex);
        Inc(Tok.LeadingTrivia.LastTokenIndex,  StartIndex);
      end;
      if not Tok.TrailingTrivia.IsEmpty then
      begin
        Inc(Tok.TrailingTrivia.FirstTokenIndex, StartIndex);
        Inc(Tok.TrailingTrivia.LastTokenIndex,  StartIndex);
      end;
      OutTokens.Add(Tok);
    end;
  finally
    Temp.Free;
  end;
end;


procedure TDelphiLexer.TokenizeIntoEmptyList(const Source: string; const OutTokens: TTokenList);
var
  Sc:        TScanner;
  C:         Char;
  TokText:   string;
  TokLine:   Integer; // start line of current token (captured before Read*)
  TokCol:    Integer; // start column of current token
  TokOffset: Integer; // 0-based start offset of current token
  TokStartI: Integer; // 1-based start position for Copy() (= TokOffset + 1)
  DelimLen:  Integer; // multiline string delimiter length (3, 5, 7, ...)
  KeywordInfo: TKeywordInfo;

  procedure Add(AKind: TTokenKind; const Text: string);
  var
    T: TToken;
  begin
    T := MakeToken(AKind, Text, TokLine, TokCol, TokOffset);
    OutTokens.Add(T);
  end;
  
begin
  Assert(OutTokens.Count = 0, 'TokenizeIntoEmptyList assumes list is empty'); //ApplyTriviaSpans walks entire list

  Sc.S           := Source;
  Sc.I           := 1;
  Sc.N           := Length(Source);
  Sc.Line        := 1;
  Sc.Col         := 1;
  Sc.AtLineStart := True;

  while Sc.I <= Sc.N do
  begin
    C         := Peek(Sc);
    TokLine   := Sc.Line;
    TokCol    := Sc.Col;
    TokOffset := Sc.I - 1; // 0-based
    TokStartI := Sc.I;     // 1-based; use for direct Copy()

    // --- EOL: CRLF, LF, or bare CR ---
    if (C = #13) or (C = #10) then
    begin
      if (C = #13) and (Peek(Sc, 1) = #10) then
      begin
        Add(tkEOL, #13#10);
        IncI(Sc, 2);
      end
      else
      begin
        Add(tkEOL, C);
        IncI(Sc);
      end;
      Continue;
    end;

    // --- Whitespace (space/tab/vt/ff) ---
    if IsWhitespaceChar(C) then
    begin
      TokText := ReadWhitespace(Sc);
      if TokText <> '' then
        Add(tkWhitespace, TokText);
      Continue;
    end;

    // --- Comments and compiler directives ---
    // The '$' lookahead must be checked before dispatching to the reader.
    // Both the directive and comment branches call the same reader function
    // (ReadBraceComment / ReadParenStarComment); the difference is only which
    // token kind is emitted. Checking for '$' here -- rather than inside the
    // reader -- is what distinguishes tkDirective from tkComment.
    if C = '{' then
    begin
      if Peek(Sc, 1) = '$' then
        Add(tkDirective, ReadBraceComment(Sc))
      else
        Add(tkComment, ReadBraceComment(Sc));
      Continue;
    end;

    if (C = '(') and (Peek(Sc, 1) = '*') then
    begin
      if Peek(Sc, 2) = '$' then
        Add(tkDirective, ReadParenStarComment(Sc))
      else
        Add(tkComment, ReadParenStarComment(Sc));
      Continue;
    end;

    if (C = '/') and (Peek(Sc, 1) = '/') then
    begin
      Add(tkComment, ReadSlashSlashComment(Sc));
      Continue;
    end;

    // --- String literals ---
    if C = CHAR_SINGLE_QUOTE then
    begin
      DelimLen := DetectMultilineDelimiterLength(Sc);
      if DelimLen > 0 then
        Add(tkString, ReadMultiLineString(Sc, DelimLen))
      else
        Add(tkString, ReadStringLiteral(Sc));
      Continue;
    end;

    // --- Character literal: #nn or #$hex ---
    // For the #$hex form, require at least one hex digit after '$' so that
    // bare '#$' (no digits) falls through to tkInvalid rather than producing
    // a tkCharLiteral with no code point.
    if (C = '#') and
       (CharInSet(Peek(Sc, 1), ['0'..'9']) or
        ((Peek(Sc, 1) = '$') and
         CharInSet(Peek(Sc, 2), ['0'..'9', 'A'..'F', 'a'..'f']))) then
    begin
      Add(tkCharLiteral, ReadCharLiteral(Sc));
      Continue;
    end;

    // --- Binary literal: %0101... ---
    if (C = '%') and CharInSet(Peek(Sc, 1), ['0', '1']) then
    begin
      Add(tkNumber, ReadBinaryLiteral(Sc));
      Continue;
    end;

    // --- Octal literal: &0377, &07, etc.
    //     Must come before the escaped-identifier check. ---
    if (C = '&') and CharInSet(Peek(Sc, 1), ['0'..'7']) then
    begin
      IncI(Sc); // consume '&'
      while CharInSet(Peek(Sc), ['0'..'7', '_']) do
        IncI(Sc);
      Add(tkNumber, Copy(Sc.S, TokStartI, Sc.I - TokStartI));
      Continue;
    end;

    // --- Escaped identifier: &begin, &unit, etc.
    //     Produced as tkIdentifier so keyword-casing rules never touch them. ---
    if (C = '&') and IsIdentStart(Peek(Sc, 1)) then
    begin
      IncI(Sc); // consume '&'
      while IsIdentChar(Peek(Sc)) do
        IncI(Sc);
      Add(tkIdentifier, Copy(Sc.S, TokStartI, Sc.I - TokStartI));
      Continue;
    end;

    // --- Identifier / keyword / decimal+hex+float number ---
    // '$' is only dispatched here when at least one hex digit (or underscore)
    // follows, so that bare '$' falls through to tkInvalid below.
    if IsIdentStart(C) or
       ((C = '$') and CharInSet(Peek(Sc, 1), ['0'..'9', 'A'..'F', 'a'..'f', '_'])) or
       CharInSet(C, ['0'..'9']) then
    begin
      TokText := ReadIdentifierOrNumber(Sc);
      if (TokText <> '') and IsIdentStart(TokText[1]) then
      begin
        if FindDelphiKeyword(TokText, KeywordInfo) then
        begin
          case KeywordInfo.Category of
            kcStrict:
            begin
              Add(tkStrictKeyword, TokText);  // toconsider: collect KeywordInfo.Kind, KeywordInfo.Category
              // After emitting the 'asm' keyword, switch to opaque-body capture.
              // All text up to the terminating standalone 'end' becomes a single
              // tkAsmBody token. The 'end' is left in the scanner for the next
              // iteration to emit as tkStrictKeyword in the normal way.
              if SameText(TokText, 'asm') then
              begin
                TokLine   := Sc.Line;
                TokCol    := Sc.Col;
                TokOffset := Sc.I - 1;
                Add(tkAsmBody, ScanAsmBodyUntilTerminatingEnd(Sc));
              end;
            end;
            kcDirective,
            kcVisibility:
              Add(tkContextKeyword, TokText); // toconsider: collect KeywordInfo.Kind, KeywordInfo.Category
            else
              Assert(False, 'Unhandled KeywordInfo.Category');
          end;
        end
        else
        begin
          Add(tkIdentifier, TokText);
        end;
      end
      else
      begin
        Add(tkNumber, TokText);
      end;
      Continue;
    end;

    // --- Symbols (operators and punctuation) ---
    // Only genuine Delphi operators and punctuation are tkSymbol.
    // Everything else (bare &, #, %, unmatched }, \, ~, !, ?, etc.) is
    // tkInvalid so callers can identify malformed input clearly.
    //
    // Multi-char operators (:=, <=, >=, <>, ..) are handled first inside
    // ReadSymbol and return a 2-char string; TokText[1] still routes them
    // to the correct case branch below.
    //
    // Characters that should never reach here because they were dispatched
    // earlier: #13, #10 (EOL), space, tab, {, (, followed by *, //, ', #
    // with digit/$, % with 0/1, & with ident/digit, letters, digits, $.
    TokText := ReadSymbol(Sc);
    case TokText[1] of
      '+', '-', '*', '/', '=', '<', '>', ':',
      '.', '(', ')', '[', ']', ',', ';', '@', '^':
        Add(tkSymbol, TokText);
    else
      Add(tkInvalid, TokText);
    end;
  end;

  //referenced in Add
  TokLine   := Sc.Line;
  TokCol    := Sc.Col;
  TokOffset := Sc.I - 1; // = Sc.N; one past the last character (0-based)
  Add(tkEOF, '');

  ApplyTriviaSpans(OutTokens);
end;

end.
