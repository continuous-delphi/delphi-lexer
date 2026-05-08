(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Delphi.SyntaxHighlighter.SynEdit;

// TSynDelphiLexerHighlighter -- SynEdit syntax highlighter backed by
// delphi-lexer's TDelphiLexer.  Delegates all tokenization to the lexer
// and maps TTokenKind to SynEdit highlight attributes.
//
// Usage:
//   var HL := TSynDelphiLexerHighlighter.Create(SynEdit1);
//   SynEdit1.Highlighter := HL;
//
// The highlighter owns a TDelphiLexer instance and re-tokenizes each
// line as SynEdit requests it.  Multi-line comment/string state is
// tracked via SynEdit's Range mechanism.

interface

uses
  System.Classes, System.SysUtils,
  SynEditCodeFolding, SynEditHighlighter, SynEditTypes, SynFunc,
  Delphi.Lexer, Delphi.Token, Delphi.Token.Kind, Delphi.Token.List;

type

  // Range state carried between lines for multi-line constructs.
  TDelphiRange = (
    drNone,           // normal code
    drBraceComment,   // inside { } comment
    drParenStarComment, // inside (* *) comment
    drString          // inside multi-line string (triple-quoted)
  );

  TSynDelphiLexerHighlighter = class(TSynCustomCodeFoldingHighlighter)
  private
    FLexer: TDelphiLexer;
    FTokens: TTokenList;
    FTokenIndex: Integer;
    FLineText: string;
    FLineNumber: Integer;
    FRange: TDelphiRange;      // incoming range (set by SetRange before SetLine)
    FNextRange: TDelphiRange;  // outgoing range (computed in SetLine, returned by GetRange)
    // Attributes
    FKeywordAttr: TSynHighlighterAttributes;
    FIdentifierAttr: TSynHighlighterAttributes;
    FNumberAttr: TSynHighlighterAttributes;
    FStringAttr: TSynHighlighterAttributes;
    FCharAttr: TSynHighlighterAttributes;
    FCommentAttr: TSynHighlighterAttributes;
    FDirectiveAttr: TSynHighlighterAttributes;
    FSymbolAttr: TSynHighlighterAttributes;
    FWhitespaceAttr: TSynHighlighterAttributes;
    FAsmAttr: TSynHighlighterAttributes;
    function CurrentToken: TToken;
  protected
    function GetSampleSource: string; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    class function GetLanguageName: string; override;
    class function GetFriendlyLanguageName: string; {$IF CompilerVersion >= 35}override;{$IFEND}

    function GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes; override;
    function GetTokenKind: TSynNativeInt; override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetEol: Boolean; override;
    procedure SetLine(const NewValue: string; LineNumber: TSynNativeInt); override;
    procedure Next; override;
    function GetRange: Pointer; override;
    procedure SetRange(Value: Pointer); override;
    procedure ResetRange; override;
    function FlowControlAtLine(Lines: TStrings; Line: TSynNativeInt): TSynFlowControl; override;
    procedure ScanForFoldRanges(FoldRanges: TSynFoldRanges; LinesToScan: TStrings; FromLine: TSynNativeInt; ToLine: TSynNativeInt); override;
  end;

implementation

uses
  Vcl.Graphics;


constructor TSynDelphiLexerHighlighter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLexer := TDelphiLexer.Create;
  FTokens := TTokenList.Create;
  FRange := drNone;
  fCaseSensitive := True;

  FKeywordAttr := TSynHighlighterAttributes.Create('Keyword', 'Keyword');
  FKeywordAttr.Style := [fsBold];
  FKeywordAttr.Foreground := clNavy;
  AddAttribute(FKeywordAttr);

  FIdentifierAttr := TSynHighlighterAttributes.Create('Identifier', 'Identifier');
  AddAttribute(FIdentifierAttr);

  FNumberAttr := TSynHighlighterAttributes.Create('Number', 'Number');
  FNumberAttr.Foreground := clBlue;
  AddAttribute(FNumberAttr);

  FStringAttr := TSynHighlighterAttributes.Create('String', 'String');
  FStringAttr.Foreground := clPurple;
  AddAttribute(FStringAttr);

  FCharAttr := TSynHighlighterAttributes.Create('Character', 'Character');
  FCharAttr.Foreground := clPurple;
  AddAttribute(FCharAttr);

  FCommentAttr := TSynHighlighterAttributes.Create('Comment', 'Comment');
  FCommentAttr.Style := [fsItalic];
  FCommentAttr.Foreground := clGreen;
  AddAttribute(FCommentAttr);

  FDirectiveAttr := TSynHighlighterAttributes.Create('Directive', 'Directive');
  FDirectiveAttr.Foreground := clTeal;
  AddAttribute(FDirectiveAttr);

  FSymbolAttr := TSynHighlighterAttributes.Create('Symbol', 'Symbol');
  AddAttribute(FSymbolAttr);

  FWhitespaceAttr := TSynHighlighterAttributes.Create('Whitespace', 'Whitespace');
  AddAttribute(FWhitespaceAttr);

  FAsmAttr := TSynHighlighterAttributes.Create('Assembler', 'Assembler');
  FAsmAttr.Foreground := clGray;
  AddAttribute(FAsmAttr);

  SetAttributesOnChange(DefHighlightChange);
end;


destructor TSynDelphiLexerHighlighter.Destroy;
begin
  FTokens.Free;
  FLexer.Free;
  inherited;
end;


class function TSynDelphiLexerHighlighter.GetLanguageName: string;
begin
  Result := 'Delphi 13 Forence+ (via delphi-lexer)';
end;


class function TSynDelphiLexerHighlighter.GetFriendlyLanguageName: string;
begin
  Result := 'Delphi 13';
end;


function TSynDelphiLexerHighlighter.GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes;
begin
  case Index of
    SYN_ATTR_KEYWORD:    Result := FKeywordAttr;
    SYN_ATTR_IDENTIFIER: Result := FIdentifierAttr;
    SYN_ATTR_COMMENT:    Result := FCommentAttr;
    SYN_ATTR_WHITESPACE: Result := FWhitespaceAttr;
    SYN_ATTR_STRING:     Result := FStringAttr;
    SYN_ATTR_SYMBOL:     Result := FSymbolAttr;
  else
    Result := nil;
  end;
end;


procedure TSynDelphiLexerHighlighter.SetLine(const NewValue: string; LineNumber: TSynNativeInt);

  // Find the position of the closer in the line for multi-line ranges.
  // Returns the 0-based index AFTER the closer, or -1 if not found.
  function FindCloser(const S: string; RangeKind: TDelphiRange): Integer;
  begin
    Result := -1;
    case RangeKind of
      drBraceComment:
      begin
        var P := Pos('}', S);
        if P > 0 then Result := P; // index after '}'
      end;
      drParenStarComment:
      begin
        var P := Pos('*)', S);
        if P > 0 then Result := P + 1; // index after '*)'
      end;
      drString:
      begin
        var P := Pos('''''''', S); // triple-quote closer
        if P > 0 then Result := P + 2;
      end;
    end;
  end;

var
  RestStart: Integer;
  RangeToken: TToken;
  RangeClosed: Boolean;
begin
  FLineText := NewValue;
  FLineNumber := LineNumber;
  FTokenIndex := -1;
  FNextRange := drNone;
  RangeClosed := False;

  FTokens.Clear;

  if FRange <> drNone then
  begin
    // Inside a multi-line comment or string from the previous line.
    // Find where the closer is (if any) on this line.
    RestStart := FindCloser(NewValue, FRange);
    if RestStart < 0 then
    begin
      // No closer: the entire line is part of the multi-line construct.
      // Propagate range directly -- don't rely on token-based detection.
      FNextRange := FRange;
      RangeToken := Default(TToken);
      if FRange in [drBraceComment, drParenStarComment] then
        RangeToken.Kind := tkComment
      else
        RangeToken.Kind := tkString;
      RangeToken.Text := NewValue;
      RangeToken.StartOffset := 0;
      RangeToken.Length := System.Length(NewValue);
      if System.Length(NewValue) > 0 then
        FTokens.Add(RangeToken);
    end
    else
    begin
      RangeClosed := True;
      // Closer found: emit the range portion, then lex the rest.
      if RestStart > 0 then
      begin
        RangeToken := Default(TToken);
        if FRange in [drBraceComment, drParenStarComment] then
          RangeToken.Kind := tkComment
        else
          RangeToken.Kind := tkString;
        RangeToken.Text := Copy(NewValue, 1, RestStart);
        RangeToken.StartOffset := 0;
        RangeToken.Length := RestStart;
        FTokens.Add(RangeToken);
      end;
      // Lex the remainder after the closer.
      var Rest := Copy(NewValue, RestStart + 1, MaxInt);
      if Rest <> '' then
      begin
        var RestTokens := TTokenList.Create;
        try
          FLexer.TokenizeInto(Rest, RestTokens, False);
          for var I := 0 to RestTokens.Count - 1 do
          begin
            var T := RestTokens[I];
            T.StartOffset := T.StartOffset + RestStart;
            FTokens.Add(T);
          end;
        finally
          RestTokens.Free;
        end;
      end;
    end;
  end
  else
  begin
    // Normal line: tokenize directly.
    FLexer.TokenizeInto(NewValue, FTokens, False);
  end;

  // Remove trailing tkEOL/tkEOF tokens (SynEdit handles line ends).
  while (FTokens.Count > 0) and
    (FTokens[FTokens.Count - 1].Kind in [tkEOL, tkEOF]) do
    FTokens.Delete(FTokens.Count - 1);

  // Compute the outgoing range for the next line (unless already set
  // by the no-closer path above).
  if (FNextRange = drNone) and (FTokens.Count > 0) then
  begin
    var Last := FTokens[FTokens.Count - 1];
    case Last.Kind of
      tkComment:
      begin
        if (System.Length(Last.Text) >= 1) and (Last.Text[1] = '{') and
          (Last.Text[System.Length(Last.Text)] <> '}') then
          FNextRange := drBraceComment
        else if (System.Length(Last.Text) >= 2) and
          (Last.Text[1] = '(') and (Last.Text[2] = '*') and
          not ((System.Length(Last.Text) >= 4) and
            (Last.Text[System.Length(Last.Text) - 1] = '*') and
            (Last.Text[System.Length(Last.Text)] = ')')) then
          FNextRange := drParenStarComment;
      end;
      tkString:
      begin
        if (System.Length(Last.Text) >= 3) and
          (Last.Text[1] = '''') and (Last.Text[2] = '''') and
          (Last.Text[3] = '''') and
          not ((System.Length(Last.Text) >= 6) and
            (Last.Text[System.Length(Last.Text) - 2] = '''') and
            (Last.Text[System.Length(Last.Text) - 1] = '''') and
            (Last.Text[System.Length(Last.Text)] = '''')) then
          FNextRange := drString;
      end;
    end;
  end;
  // If we were inside a range and no closer was found, propagate.
  if (FNextRange = drNone) and (FRange <> drNone) and not RangeClosed and
    (FTokens.Count > 0) then
  begin
    var Last := FTokens[FTokens.Count - 1];
    if not (Last.Kind in [tkComment, tkString]) then
      FNextRange := FRange;
  end
  else if (FRange <> drNone) and not RangeClosed and (FTokens.Count = 0) then
    FNextRange := FRange;

  // Call inherited LAST: DoSetLine sets fLine/fLineLen/Run, then
  // calls Next which advances FTokenIndex from -1 to 0.
  // FTokens must be populated before this point.
  FRange := FNextRange;
  inherited SetLine(NewValue, LineNumber);
end;


procedure TSynDelphiLexerHighlighter.Next;
begin
  fTokenPos := Run;
  Inc(FTokenIndex);
  if (FTokenIndex >= 0) and (FTokenIndex < FTokens.Count) then
  begin
    fTokenPos := FTokens[FTokenIndex].StartOffset;
    Run := fTokenPos + System.Length(FTokens[FTokenIndex].Text);
  end
  else
  begin
    // Past all tokens: advance Run beyond line length to signal EOL.
    Run := fLineLen + 1;
  end;
  inherited;
end;


function TSynDelphiLexerHighlighter.GetEol: Boolean;
begin
  Result := Run > fLineLen;
end;


function TSynDelphiLexerHighlighter.CurrentToken: TToken;
begin
  if (FTokenIndex >= 0) and (FTokenIndex < FTokens.Count) then
    Result := FTokens[FTokenIndex]
  else
    Result := Default(TToken);
end;


function TSynDelphiLexerHighlighter.GetTokenKind: TSynNativeInt;
begin
  Result := Ord(CurrentToken.Kind);
end;


function TSynDelphiLexerHighlighter.GetTokenAttribute: TSynHighlighterAttributes;
begin
  if FTokenIndex >= FTokens.Count then
    Result := nil  // past end: no attribute
  else
  case CurrentToken.Kind of
    tkStrictKeyword,
    tkContextKeyword:   Result := FKeywordAttr;
    tkIdentifier:       Result := FIdentifierAttr;
    tkNumber:           Result := FNumberAttr;
    tkString:           Result := FStringAttr;
    tkCharLiteral:      Result := FCharAttr;
    tkComment:          Result := FCommentAttr;
    tkDirective:        Result := FDirectiveAttr;
    tkSymbol:           Result := FSymbolAttr;
    tkWhitespace:       Result := FWhitespaceAttr;
    tkAsmBody:          Result := FAsmAttr;
  else
    Result := FIdentifierAttr;
  end;
end;


function TSynDelphiLexerHighlighter.GetRange: Pointer;
begin
  // SynEdit initializes line ranges to nil and uses that value to mean
  // "not scanned yet".  Keep even drNone non-nil so an initial full-text load
  // does not stop range propagation before a later multi-line string.
  Result := Pointer(NativeInt(Ord(FNextRange)) + 1);
end;


procedure TSynDelphiLexerHighlighter.SetRange(Value: Pointer);
begin
  if Value = nil then
    FRange := drNone
  else
    FRange := TDelphiRange(NativeInt(Value) - 1);
end;


procedure TSynDelphiLexerHighlighter.ResetRange;
begin
  FRange := drNone;
  FNextRange := drNone;
end;


function TSynDelphiLexerHighlighter.FlowControlAtLine(Lines: TStrings; Line: TSynNativeInt): TSynFlowControl;
var
  LineTokens: TTokenList;
  I: Integer;
  IncomingRange: TDelphiRange;

  function RangeFromPointer(Value: Pointer): TDelphiRange;
  begin
    if Value = nil then
      Result := drNone
    else
      Result := TDelphiRange(NativeInt(Value) - 1);
  end;

begin
  Result := fcNone;
  if (Line < 1) or (Line > Lines.Count) then
    Exit;

  if Line > 1 then
    IncomingRange := RangeFromPointer(GetLineRange(Lines, Line - 2))
  else
    IncomingRange := drNone;
  if IncomingRange <> drNone then
    Exit;

  LineTokens := TTokenList.Create;
  try
    FLexer.TokenizeInto(Lines[Line - 1], LineTokens, False);
    for I := 0 to LineTokens.Count - 1 do
    begin
      if LineTokens[I].Kind = tkIdentifier then
      begin
        var S := LowerCase(LineTokens[I].Text);
        if S = 'exit' then
          Exit(fcExit)
        else if S = 'break' then
          Exit(fcBreak)
        else if S = 'continue' then
          Exit(fcContinue);
      end;
    end;
  finally
    LineTokens.Free;
  end;
end;

procedure TSynDelphiLexerHighlighter.ScanForFoldRanges(FoldRanges: TSynFoldRanges; LinesToScan: TStrings; FromLine, ToLine: TSynNativeInt);
const
  FT_Block = 1;
  FT_CodeDeclaration = 16;
  FT_Implementation = 18;
var
  Line: TSynNativeInt;
  LineTokens: TTokenList;
  I: Integer;
  J: Integer;
  CurLine: string;
  UpperLine: string;
  TokenLower: string;
  PrevCodeToken: string;
  BlockDepth: Integer;
  StructDepth: Integer;
  DeclBodyDepths: array of Integer;

  function Emit: Boolean;
  begin
    Result := Line >= FromLine;
  end;

  function NextCodeToken(Index: Integer): string;
  begin
    Result := '';
    while Index < LineTokens.Count do
    begin
      if not (LineTokens[Index].Kind in [tkWhitespace, tkEOL, tkEOF]) then
        Exit(LowerCase(LineTokens[Index].Text));
      Inc(Index);
    end;
  end;

  procedure PushDeclaration;
  var
    L: Integer;
  begin
    L := System.Length(DeclBodyDepths);
    SetLength(DeclBodyDepths, L + 1);
    DeclBodyDepths[L] := -1;
  end;

  procedure PopDeclaration;
  var
    L: Integer;
  begin
    L := System.Length(DeclBodyDepths);
    if L > 0 then
      SetLength(DeclBodyDepths, L - 1);
  end;

begin
  LineTokens := TTokenList.Create;
  try
    BlockDepth := 0;
    StructDepth := 0;
    SetLength(DeclBodyDepths, 0);

    for Line := 0 to ToLine do
    begin
      CurLine := Trim(LinesToScan.ItemsNative[Line]);
      if CurLine = '' then
      begin
        if Emit then
          FoldRanges.NoFoldInfo(Line + 1);
        Continue;
      end;

      UpperLine := UpperCase(CurLine);
      if Pos('{$REGION', UpperLine) = 1 then
      begin
        if Emit then
          FoldRanges.StartFoldRange(Line + 1, FoldRegionType);
        Continue;
      end;
      if Pos('{$ENDREGION', UpperLine) = 1 then
      begin
        if Emit then
          FoldRanges.StopFoldRange(Line + 1, FoldRegionType);
        Continue;
      end;

      LineTokens.Clear;
      FLexer.TokenizeInto(LinesToScan.ItemsNative[Line], LineTokens, False);

      PrevCodeToken := '';
      for I := 0 to LineTokens.Count - 1 do
      begin
        if LineTokens[I].Kind in [tkWhitespace, tkEOL, tkEOF, tkComment,
          tkDirective, tkString, tkCharLiteral] then
          Continue;

        TokenLower := LowerCase(LineTokens[I].Text);

        if TokenLower = 'implementation' then
        begin
          if Emit then
            FoldRanges.StartFoldRange(Line + 1, FT_Implementation);
        end
        else if (TokenLower = 'begin') or (TokenLower = 'case') or
          (TokenLower = 'try') or (TokenLower = 'asm') then
        begin
          if Emit then
            FoldRanges.StartFoldRange(Line + 1, FT_Block);
          Inc(BlockDepth);
          if TokenLower = 'begin' then
            for J := System.Length(DeclBodyDepths) - 1 downto 0 do
              if DeclBodyDepths[J] < 0 then
              begin
                DeclBodyDepths[J] := BlockDepth;
                Break;
              end;
        end
        else if TokenLower = 'end' then
        begin
          if BlockDepth > 0 then
          begin
            if Emit then
              FoldRanges.StopFoldRange(Line + 1, FT_Block);
            if (System.Length(DeclBodyDepths) > 0) and
              (DeclBodyDepths[System.Length(DeclBodyDepths) - 1] = BlockDepth) then
            begin
              if Emit then
                FoldRanges.StopFoldRange(Line + 1, FT_CodeDeclaration);
              PopDeclaration;
            end;
            Dec(BlockDepth);
          end
          else if StructDepth > 0 then
          begin
            if Emit then
              FoldRanges.StopFoldRange(Line + 1, FT_CodeDeclaration);
            Dec(StructDepth);
          end;
        end
        else if (TokenLower = 'procedure') or (TokenLower = 'function') or
          (TokenLower = 'constructor') or (TokenLower = 'destructor') then
        begin
          if Emit then
            FoldRanges.StartFoldRange(Line + 1, FT_CodeDeclaration);
          PushDeclaration;
        end
        else if ((TokenLower = 'class') or (TokenLower = 'record') or
          (TokenLower = 'interface')) and (PrevCodeToken = '=') and
          (NextCodeToken(I + 1) <> 'of') then
        begin
          if Emit then
            FoldRanges.StartFoldRange(Line + 1, FT_CodeDeclaration);
          Inc(StructDepth);
        end;

        PrevCodeToken := TokenLower;
      end;
    end;
  finally
    LineTokens.Free;
  end;
end;

function TSynDelphiLexerHighlighter.GetSampleSource: string;
begin
  Result :=
    'unit Sample;'#13#10 +
    ''#13#10 +
    'interface'#13#10 +
    ''#13#10 +
    'type'#13#10 +
    '  TFoo = class'#13#10 +
    '  private'#13#10 +
    '    FValue: Integer;'#13#10 +
    '  public'#13#10 +
    '    procedure DoWork(const S: string);'#13#10 +
    '  end;'#13#10 +
    ''#13#10 +
    'implementation'#13#10 +
    ''#13#10 +
    '{ TFoo }'#13#10 +
    ''#13#10 +
    'procedure TFoo.DoWork(const S: string);'#13#10 +
    'begin'#13#10 +
    '  FValue := Length(S); // compute length'#13#10 +
    '  {$IFDEF DEBUG}'#13#10 +
    '  WriteLn(''Value = '', FValue);'#13#10 +
    '  {$ENDIF}'#13#10 +
    'end;'#13#10 +
    ''#13#10 +
    'end.';
end;


end.
