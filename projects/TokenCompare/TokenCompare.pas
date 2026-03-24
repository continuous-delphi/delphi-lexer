unit TokenCompare;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DelphiLexer.Utils,
  DelphiLexer.Token;

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

type
  TDiffKind = (dkMismatch, dkMissingInA, dkMissingInB);

  TDiffEntry = record
    Kind:   TDiffKind;
    IndexA: Integer;  // -1 for dkMissingInA
    IndexB: Integer;  // -1 for dkMissingInB
    TokA:   TToken;   // valid for dkMismatch, dkMissingInB
    TokB:   TToken;   // valid for dkMismatch, dkMissingInA
  end;

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
  MaxI:        Integer;
  I:           Integer;
  HasA, HasB:  Boolean;
  TokA, TokB:  TToken;
  Entry:       TDiffEntry;
  Equal:       Boolean;
begin

  FilteredA := FilterTokens(Config, RawA);
  FilteredB := FilterTokens(Config, RawB);
  Diffs     := TList<TDiffEntry>.Create;
  try
    // Comparison pass.
    TotalDiffs := 0;
    MaxI := FilteredA.Count;
    if FilteredB.Count > MaxI then MaxI := FilteredB.Count;

    for I := 0 to MaxI - 1 do
    begin
      HasA := I < FilteredA.Count;
      HasB := I < FilteredB.Count;

      if HasA and HasB then
      begin
        TokA := FilteredA[I];
        TokB := FilteredB[I];
        if (TokA.Kind <> TokB.Kind) or (TokA.Text <> TokB.Text) then
        begin
          Inc(TotalDiffs);
          if (Diffs.Count < Config.MaxDiffs) then
          begin
            Entry := Default(TDiffEntry);
            Entry.Kind := dkMismatch; Entry.IndexA := I; Entry.IndexB := I;
            Entry.TokA := TokA; Entry.TokB := TokB;
            Diffs.Add(Entry);
          end;
          if Config.StopAfterFirstDiff then Break;
        end;
      end
      else if HasA then  // B is shorter
      begin
        Inc(TotalDiffs);
        if (Diffs.Count < Config.MaxDiffs) then
        begin
          Entry := Default(TDiffEntry);
          Entry.Kind := dkMissingInB; Entry.IndexA := I; Entry.IndexB := -1;
          Entry.TokA := FilteredA[I];
          Diffs.Add(Entry);
        end;
        if Config.StopAfterFirstDiff then Break;
      end
      else  // A is shorter
      begin
        Inc(TotalDiffs);
        if (Diffs.Count < Config.MaxDiffs) then
        begin
          Entry := Default(TDiffEntry);
          Entry.Kind := dkMissingInA; Entry.IndexA := -1; Entry.IndexB := I;
          Entry.TokB := FilteredB[I];
          Diffs.Add(Entry);
        end;
        if Config.StopAfterFirstDiff then Break;
      end;
    end;

    Equal := TotalDiffs = 0;

    // Header.
    WriteLn('');
    WriteLn(AppName);
    WriteLn('formatVersion: ', '1.0.0'); // Bump if TEXT output structure changes
    WriteLn(Format('%-18s : %s', ['File A', Config.BaseOptions.FileName]));
    WriteLn(Format('%-18s : %s', ['File B', Config.SecondFile]));
    WriteLn(Format('%-18s : %s', ['Mode',   ComparisonModeName(Config)]));
    WriteLn(Format('%-18s : %s', ['Equal', if Equal then 'yes' else 'no']));
    if FilteredA.Count = FilteredB.Count then
      WriteLn(Format('%-18s : %d',     ['Compared Tokens', FilteredA.Count]))
    else
      WriteLn(Format('%-18s : %d / %d', ['Compared Tokens', FilteredA.Count, FilteredB.Count]));
    WriteLn(Format('%-18s : %d', ['Diff Count', TotalDiffs]));

    if Config.StopAfterFirstDiff and (TotalDiffs >= 1) then
      WriteLn('(stopped after first difference)');
    if (not Config.StopAfterFirstDiff) and (Config.MaxDiffs > 0) and (TotalDiffs > Config.MaxDiffs) then
      WriteLn(Format('(showing first %d of %d differences)', [Config.MaxDiffs, TotalDiffs]));

    // Diff entries.
    if Diffs.Count > 0 then
    begin
      WriteLn;
      WriteLn('Differences:');
      for I := 0 to Diffs.Count - 1 do
      begin
        Entry := Diffs[I];
        WriteLn;
        WriteLn(Format('  [%d]', [I + 1]));
        case Entry.Kind of
          dkMismatch:
          begin
            WriteLn(Format('  %-16s : %d', ['Index A', Entry.IndexA]));
            WriteLn(Format('  %-16s : %d', ['Index B', Entry.IndexB]));
            WriteLn(Format('  %-16s : %s', ['A', TokenLabel(Entry.TokA)]));
            WriteLn(Format('  %-16s : %s', ['B', TokenLabel(Entry.TokB)]));
          end;
          dkMissingInB:
          begin
            WriteLn(Format('  %-16s : %s', ['Type',    'missing-token-in-b']));
            WriteLn(Format('  %-16s : %d', ['Index A', Entry.IndexA]));
            WriteLn(Format('  %-16s : %s', ['A',       TokenLabel(Entry.TokA)]));
          end;
          dkMissingInA:
          begin
            WriteLn(Format('  %-16s : %s', ['Type',    'missing-token-in-a']));
            WriteLn(Format('  %-16s : %d', ['Index B', Entry.IndexB]));
            WriteLn(Format('  %-16s : %s', ['B',       TokenLabel(Entry.TokB)]));
          end;
        end;
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
  MaxI:        Integer;
  I:           Integer;
  HasA, HasB:  Boolean;
  TokA, TokB:  TToken;
  Entry:       TDiffEntry;
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
  Diffs     := TList<TDiffEntry>.Create;
  try
    // Comparison pass.
    TotalDiffs := 0;
    MaxI := FilteredA.Count;
    if FilteredB.Count > MaxI then MaxI := FilteredB.Count;

    for I := 0 to MaxI - 1 do
    begin
      HasA := I < FilteredA.Count;
      HasB := I < FilteredB.Count;

      if HasA and HasB then
      begin
        TokA := FilteredA[I];
        TokB := FilteredB[I];
        if (TokA.Kind <> TokB.Kind) or (TokA.Text <> TokB.Text) then
        begin
          Inc(TotalDiffs);
          if (Diffs.Count < Config.MaxDiffs) then
          begin
            Entry := Default(TDiffEntry);
            Entry.Kind := dkMismatch; Entry.IndexA := I; Entry.IndexB := I;
            Entry.TokA := TokA; Entry.TokB := TokB;
            Diffs.Add(Entry);
          end;
          if Config.StopAfterFirstDiff then Break;
        end;
      end
      else if HasA then
      begin
        Inc(TotalDiffs);
        if (Diffs.Count < Config.MaxDiffs) then
        begin
          Entry := Default(TDiffEntry);
          Entry.Kind := dkMissingInB; Entry.IndexA := I; Entry.IndexB := -1;
          Entry.TokA := FilteredA[I];
          Diffs.Add(Entry);
        end;
        if Config.StopAfterFirstDiff then Break;
      end
      else
      begin
        Inc(TotalDiffs);
        if (Diffs.Count < Config.MaxDiffs) then
        begin
          Entry := Default(TDiffEntry);
          Entry.Kind := dkMissingInA; Entry.IndexA := -1; Entry.IndexB := I;
          Entry.TokB := FilteredB[I];
          Diffs.Add(Entry);
        end;
        if Config.StopAfterFirstDiff then Break;
      end;
    end;

    Equal := TotalDiffs = 0;

    Root := TJSONObject.Create;
    try

      Root.AddPair('toolName', AppName);
      Root.AddPair('formatVersion', '1.0.0');  // Bump if JSON output structure changes
      Root.AddPair('fileA', Config.BaseOptions.FileName);
      Root.AddPair('fileB', Config.SecondFile);

      Options := TJSONObject.Create;
      Options.AddPair('encoding',          Config.BaseOptions.Encoding.EncodingName);
      Options.AddPair('ignoreWhitespace',  TJSONBool.Create(Config.IgnoreWhitespace));
      Options.AddPair('ignoreEOL',         TJSONBool.Create(Config.IgnoreEOL));
      Options.AddPair('ignoreComments',    TJSONBool.Create(Config.IgnoreComments));
      Options.AddPair('stopAfterFirstDiff', TJSONBool.Create(Config.StopAfterFirstDiff));
      Options.AddPair('maxDiffs',          TJSONNumber.Create(Config.MaxDiffs));
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
      for I := 0 to Diffs.Count - 1 do
      begin
        Entry   := Diffs[I];
        DiffObj := TJSONObject.Create;

        case Entry.Kind of
          dkMismatch:
          begin
            DiffObj.AddPair('diffType', 'token-mismatch');
            DiffObj.AddPair('indexA',   TJSONNumber.Create(Entry.IndexA));
            DiffObj.AddPair('indexB',   TJSONNumber.Create(Entry.IndexB));

            TokObj := TJSONObject.Create;
            TokObj.AddPair('kind',        TokenKindName(Entry.TokA.Kind));
            TokObj.AddPair('text',        Entry.TokA.Text);
            TokObj.AddPair('line',        TJSONNumber.Create(Entry.TokA.Line));
            TokObj.AddPair('col',         TJSONNumber.Create(Entry.TokA.Col));
            TokObj.AddPair('startOffset', TJSONNumber.Create(Entry.TokA.StartOffset));
            TokObj.AddPair('length',      TJSONNumber.Create(Entry.TokA.Length));
            DiffObj.AddPair('tokenA', TokObj);

            TokObj := TJSONObject.Create;
            TokObj.AddPair('kind',        TokenKindName(Entry.TokB.Kind));
            TokObj.AddPair('text',        Entry.TokB.Text);
            TokObj.AddPair('line',        TJSONNumber.Create(Entry.TokB.Line));
            TokObj.AddPair('col',         TJSONNumber.Create(Entry.TokB.Col));
            TokObj.AddPair('startOffset', TJSONNumber.Create(Entry.TokB.StartOffset));
            TokObj.AddPair('length',      TJSONNumber.Create(Entry.TokB.Length));
            DiffObj.AddPair('tokenB', TokObj);
          end;

          dkMissingInB:
          begin
            DiffObj.AddPair('diffType', 'missing-token-in-b');
            DiffObj.AddPair('indexA',   TJSONNumber.Create(Entry.IndexA));

            TokObj := TJSONObject.Create;
            TokObj.AddPair('kind',        TokenKindName(Entry.TokA.Kind));
            TokObj.AddPair('text',        Entry.TokA.Text);
            TokObj.AddPair('line',        TJSONNumber.Create(Entry.TokA.Line));
            TokObj.AddPair('col',         TJSONNumber.Create(Entry.TokA.Col));
            TokObj.AddPair('startOffset', TJSONNumber.Create(Entry.TokA.StartOffset));
            TokObj.AddPair('length',      TJSONNumber.Create(Entry.TokA.Length));
            DiffObj.AddPair('tokenA', TokObj);
          end;

          dkMissingInA:
          begin
            DiffObj.AddPair('diffType', 'missing-token-in-a');
            DiffObj.AddPair('indexB',   TJSONNumber.Create(Entry.IndexB));

            TokObj := TJSONObject.Create;
            TokObj.AddPair('kind',        TokenKindName(Entry.TokB.Kind));
            TokObj.AddPair('text',        Entry.TokB.Text);
            TokObj.AddPair('line',        TJSONNumber.Create(Entry.TokB.Line));
            TokObj.AddPair('col',         TJSONNumber.Create(Entry.TokB.Col));
            TokObj.AddPair('startOffset', TJSONNumber.Create(Entry.TokB.StartOffset));
            TokObj.AddPair('length',      TJSONNumber.Create(Entry.TokB.Length));
            DiffObj.AddPair('tokenB', TokObj);
          end;
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
