unit TokenCompare;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DelphiLexer.Utils,
  DelphiLexer.Token,
  DelphiLexer.Diff;

type
  TTokenCompare = record
  private const
    AppName = 'DelphiLexer.TokenCompare';
    ExitCode_Success = 0;
    ExitCode_OpFailure = 1;
    ExitCode_Difference = 10;
  private
    // Derive the comparison mode name from the active ignore flags for display in output.
    class function ComparisonModeName(const Config:TFileCompareConfigOptions): string; static;
    // Return a new list containing only the tokens that survive the active
    // ignore flags. The returned list is owned by the caller.
    class function FilterTokens(const Config:TFileCompareConfigOptions; Tokens: TList<TToken>): TList<TToken>; static;
    // Return a single-line display string for a token in diff output.
    // Control characters are replaced with <TAG> codes.
    class function TokenLabel(const Tok: TToken): string; static;
    class function WriteTextOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TList<TToken>): Integer; static;
    class function WriteJsonOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TList<TToken>): Integer; static;
  public
    class function Run: Integer; static;
  end;

implementation

uses
  System.JSON,
  DelphiLexer.Lexer;


class function TTokenCompare.Run: Integer;
var
  Options: TFileCompareConfigOptions;
  Lexer: TDelphiLexer;
  TokensA, TokensB: TList<TToken>;
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Options := TCommandLineParser.ParseFileCompare(AppName, 'Compares the token streams of two Object Pascal source files');
  if Options.BaseOptions.AbortProgram then Exit(Options.BaseOptions.ExitCode);

  Result := ExitCode_Success;

  Lexer   := TDelphiLexer.Create;
  TokensA := nil;
  TokensB := nil;
  try
    TokensA := Lexer.Tokenize(Options.BaseOptions.FileContents);
    TokensB := Lexer.Tokenize(Options.SecondContents);
    case Options.BaseOptions.OutputFormat of
      TOutputFormat.ofText: Result := WriteTextOutput(Options, TokensA, TokensB);
      TOutputFormat.ofJson: Result := WriteJsonOutput(Options, TokensA, TokensB);
    else
      Assert(False, 'Invalid output format');
    end;
  finally
    TokensB.Free;
    TokensA.Free;
    Lexer.Free;
  end;
end;


class function TTokenCompare.ComparisonModeName(const Config:TFileCompareConfigOptions): string;
begin
  if not Config.IgnoreWhitespace and not Config.IgnoreEOL and not Config.IgnoreComments then
    Result := 'exact'
  else
  begin
    Result := '';
    if Config.IgnoreWhitespace then Result := Result + 'ignore-whitespace;';
    if Config.IgnoreEOL then Result := Result + 'ignore-eol;';
    if Config.IgnoreComments then Result := Result + 'ignore-comments;';

    If Result.EndsWith(';') then Result := Copy(Result, 1, Length(Result)-1);
  end;
end;


class function TTokenCompare.FilterTokens(const Config:TFileCompareConfigOptions; Tokens: TList<TToken>): TList<TToken>;
var
  Tok: TToken;
begin
  Result := TList<TToken>.Create;
  for Tok in Tokens do
  begin
    if Config.IgnoreWhitespace and (Tok.Kind = tkWhitespace) then Continue;
    if Config.IgnoreEOL and (Tok.Kind = tkEOL) then Continue;
    if Config.IgnoreComments and (Tok.Kind = tkComment) then Continue;

    Result.Add(Tok);
  end;
end;


class function TTokenCompare.TokenLabel(const Tok: TToken): string;
var
  S: string;
begin
  S := Tok.Text;
  // Todo: use TLexerUtils.SafeText
  S := StringReplace(S, #13#10, '<CRLF>', [rfReplaceAll]);
  S := StringReplace(S, #13,    '<CR>',   [rfReplaceAll]);
  S := StringReplace(S, #10,    '<LF>',   [rfReplaceAll]);
  S := StringReplace(S, #9,     '<TAB>',  [rfReplaceAll]);
  Result := TokenKindName(Tok.Kind) + ' "' + S + '"';
end;


class function TTokenCompare.WriteTextOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TList<TToken>): Integer;
var
  FilteredA, FilteredB: TList<TToken>;
  Diffs:       TList<TDiffEntry>;
  TotalDiffs:  Integer;
  UsedFallback: Boolean;
  I:           Integer;
  DisplayIdx:  Integer;
  Entry, Next: TDiffEntry;
  Equal:       Boolean;
begin
  FilteredA := FilterTokens(Config, RawA);
  FilteredB := FilterTokens(Config, RawB);
  Diffs     := BuildDiffList(FilteredA, FilteredB,
                 Config.MaxDiffs, Config.StopAfterFirstDiff,
                 TotalDiffs, UsedFallback);
  try
    Equal := TotalDiffs = 0;

    // Header.
    WriteLn('');
    WriteLn(AppName);
    WriteLn('formatVersion: ', '2.0.0'); // Bump if TEXT output structure changes
    WriteLn(Format('%-18s : %s', ['File A', Config.BaseOptions.FileName]));
    WriteLn(Format('%-18s : %s', ['File B', Config.SecondFile]));
    WriteLn(Format('%-18s : %s', ['Mode',   ComparisonModeName(Config)]));
    WriteLn(Format('%-18s : %s', ['Equal', if Equal then 'yes' else 'no']));
    if FilteredA.Count = FilteredB.Count then
      WriteLn(Format('%-18s : %d',     ['Compared Tokens', FilteredA.Count]))
    else
      WriteLn(Format('%-18s : %d / %d', ['Compared Tokens', FilteredA.Count, FilteredB.Count]));
    WriteLn(Format('%-18s : %d', ['Diff Count', TotalDiffs]));

    if UsedFallback then
      WriteLn('(warning: input too large for Myers diff; sequential algorithm used)');
    if Config.StopAfterFirstDiff and (TotalDiffs >= 1) then
      WriteLn('(stopped after first difference)');
    if (not Config.StopAfterFirstDiff) and (TotalDiffs > Diffs.Count) then
      WriteLn(Format('(showing first %d of %d differences)', [Diffs.Count, TotalDiffs]));

    // Diff entries.
    if Diffs.Count > 0 then
    begin
      WriteLn;
      WriteLn('Differences:');
      I          := 0;
      DisplayIdx := 1;
      while I < Diffs.Count do
      begin
        Entry := Diffs[I];
        WriteLn;

        // Adjacent dkMissingInB + dkMissingInA -> display as substitution.
        if (Entry.Kind = dkMissingInB)
          and (I + 1 < Diffs.Count)
          and (Diffs[I + 1].Kind = dkMissingInA) then
        begin
          Next := Diffs[I + 1];
          WriteLn(Format('  [%d]  substitution', [DisplayIdx]));
          WriteLn(Format('    %-14s : %d', ['Index A', Entry.IndexA]));
          WriteLn(Format('    %-14s : %d', ['Index B', Next.IndexB]));
          WriteLn(Format('    %-14s : %s', ['A', TokenLabel(Entry.Tok)]));
          WriteLn(Format('    %-14s : %s', ['B', TokenLabel(Next.Tok)]));
          Inc(I, 2);
        end
        else
        begin
          WriteLn(Format('  [%d]', [DisplayIdx]));
          case Entry.Kind of
            dkMissingInB:
            begin
              WriteLn(Format('    %-14s : %s', ['Type',    'missing-token-in-b']));
              WriteLn(Format('    %-14s : %d', ['Index A', Entry.IndexA]));
              WriteLn(Format('    %-14s : %s', ['A',       TokenLabel(Entry.Tok)]));
            end;
            dkMissingInA:
            begin
              WriteLn(Format('    %-14s : %s', ['Type',    'missing-token-in-a']));
              WriteLn(Format('    %-14s : %d', ['Index B', Entry.IndexB]));
              WriteLn(Format('    %-14s : %s', ['B',       TokenLabel(Entry.Tok)]));
            end;
          end;
          Inc(I);
        end;

        Inc(DisplayIdx);
      end;
    end;

  finally
    FilteredA.Free;
    FilteredB.Free;
    Diffs.Free;
  end;

  if Equal then Result := ExitCode_Success else Result := ExitCode_Difference;

  WriteLn('');
  WriteLn('Exit Code: ', Result);
end;


class function TTokenCompare.WriteJsonOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TList<TToken>): Integer;
var
  FilteredA, FilteredB: TList<TToken>;
  Diffs:       TList<TDiffEntry>;
  TotalDiffs:  Integer;
  UsedFallback: Boolean;
  I:           Integer;
  Entry, Next: TDiffEntry;
  Equal:       Boolean;
  Root:        TJSONObject;
  Options:     TJSONObject;
  Summary:     TJSONObject;
  DiffsArr:    TJSONArray;
  DiffObj:     TJSONObject;
  TokObj:      TJSONObject;
begin
  FilteredA := FilterTokens(Config, RawA);
  FilteredB := FilterTokens(Config, RawB);
  Diffs     := BuildDiffList(FilteredA, FilteredB,
                 Config.MaxDiffs, Config.StopAfterFirstDiff,
                 TotalDiffs, UsedFallback);
  try
    Equal := TotalDiffs = 0;

    Root := TJSONObject.Create;
    try

      Root.AddPair('toolName', AppName);
      Root.AddPair('formatVersion', '2.0.0');  // Bump if JSON output structure changes
      Root.AddPair('fileA', Config.BaseOptions.FileName);
      Root.AddPair('fileB', Config.SecondFile);

      Options := TJSONObject.Create;
      Options.AddPair('encoding',           Config.BaseOptions.Encoding.EncodingName);
      Options.AddPair('ignoreWhitespace',   TJSONBool.Create(Config.IgnoreWhitespace));
      Options.AddPair('ignoreEOL',          TJSONBool.Create(Config.IgnoreEOL));
      Options.AddPair('ignoreComments',     TJSONBool.Create(Config.IgnoreComments));
      Options.AddPair('stopAfterFirstDiff', TJSONBool.Create(Config.StopAfterFirstDiff));
      Options.AddPair('maxDiffs',           TJSONNumber.Create(Config.MaxDiffs));
      Options.AddPair('usedFallback',       TJSONBool.Create(UsedFallback));
      Root.AddPair('options', Options);

      Summary := TJSONObject.Create;
      Summary.AddPair('equal',               TJSONBool.Create(Equal));
      Summary.AddPair('comparisonMode',      ComparisonModeName(Config));
      Summary.AddPair('rawTokenCountA',      TJSONNumber.Create(RawA.Count));
      Summary.AddPair('rawTokenCountB',      TJSONNumber.Create(RawB.Count));
      Summary.AddPair('comparedTokenCountA', TJSONNumber.Create(FilteredA.Count));
      Summary.AddPair('comparedTokenCountB', TJSONNumber.Create(FilteredB.Count));
      Summary.AddPair('diffCount',           TJSONNumber.Create(TotalDiffs));
      Root.AddPair('summary', Summary);

      DiffsArr := TJSONArray.Create;
      I := 0;
      while I < Diffs.Count do
      begin
        Entry   := Diffs[I];
        DiffObj := TJSONObject.Create;

        // Adjacent dkMissingInB + dkMissingInA -> emit as substitution object.
        if (Entry.Kind = dkMissingInB)
          and (I + 1 < Diffs.Count)
          and (Diffs[I + 1].Kind = dkMissingInA) then
        begin
          Next := Diffs[I + 1];
          DiffObj.AddPair('diffType', 'substitution');
          DiffObj.AddPair('indexA',   TJSONNumber.Create(Entry.IndexA));
          DiffObj.AddPair('indexB',   TJSONNumber.Create(Next.IndexB));

          TokObj := TJSONObject.Create;
          TokObj.AddPair('kind',        TokenKindName(Entry.Tok.Kind));
          TokObj.AddPair('text',        Entry.Tok.Text);
          TokObj.AddPair('line',        TJSONNumber.Create(Entry.Tok.Line));
          TokObj.AddPair('col',         TJSONNumber.Create(Entry.Tok.Col));
          TokObj.AddPair('startOffset', TJSONNumber.Create(Entry.Tok.StartOffset));
          TokObj.AddPair('length',      TJSONNumber.Create(Entry.Tok.Length));
          DiffObj.AddPair('tokenA', TokObj);

          TokObj := TJSONObject.Create;
          TokObj.AddPair('kind',        TokenKindName(Next.Tok.Kind));
          TokObj.AddPair('text',        Next.Tok.Text);
          TokObj.AddPair('line',        TJSONNumber.Create(Next.Tok.Line));
          TokObj.AddPair('col',         TJSONNumber.Create(Next.Tok.Col));
          TokObj.AddPair('startOffset', TJSONNumber.Create(Next.Tok.StartOffset));
          TokObj.AddPair('length',      TJSONNumber.Create(Next.Tok.Length));
          DiffObj.AddPair('tokenB', TokObj);

          Inc(I, 2);
        end
        else
        begin
          case Entry.Kind of
            dkMissingInB:
            begin
              DiffObj.AddPair('diffType', 'missing-token-in-b');
              DiffObj.AddPair('indexA',   TJSONNumber.Create(Entry.IndexA));

              TokObj := TJSONObject.Create;
              TokObj.AddPair('kind',        TokenKindName(Entry.Tok.Kind));
              TokObj.AddPair('text',        Entry.Tok.Text);
              TokObj.AddPair('line',        TJSONNumber.Create(Entry.Tok.Line));
              TokObj.AddPair('col',         TJSONNumber.Create(Entry.Tok.Col));
              TokObj.AddPair('startOffset', TJSONNumber.Create(Entry.Tok.StartOffset));
              TokObj.AddPair('length',      TJSONNumber.Create(Entry.Tok.Length));
              DiffObj.AddPair('tokenA', TokObj);
            end;

            dkMissingInA:
            begin
              DiffObj.AddPair('diffType', 'missing-token-in-a');
              DiffObj.AddPair('indexB',   TJSONNumber.Create(Entry.IndexB));

              TokObj := TJSONObject.Create;
              TokObj.AddPair('kind',        TokenKindName(Entry.Tok.Kind));
              TokObj.AddPair('text',        Entry.Tok.Text);
              TokObj.AddPair('line',        TJSONNumber.Create(Entry.Tok.Line));
              TokObj.AddPair('col',         TJSONNumber.Create(Entry.Tok.Col));
              TokObj.AddPair('startOffset', TJSONNumber.Create(Entry.Tok.StartOffset));
              TokObj.AddPair('length',      TJSONNumber.Create(Entry.Tok.Length));
              DiffObj.AddPair('tokenB', TokObj);
            end;
          end;

          Inc(I);
        end;

        DiffsArr.Add(DiffObj);
      end;
      Root.AddPair('diffs', DiffsArr);

      WriteLn(Root.Format(2));
    finally
      Root.Free;
    end;

  finally
    FilteredA.Free;
    FilteredB.Free;
    Diffs.Free;
  end;

  if Equal then Result := ExitCode_Success else Result := ExitCode_Difference;
end;

end.
