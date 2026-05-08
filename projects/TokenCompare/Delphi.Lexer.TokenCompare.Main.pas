(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Delphi.Lexer.TokenCompare.Main;

interface

uses
  Delphi.Token,
  Delphi.Token.List,
  Delphi.Lexer.Utils,
  Delphi.Lexer.MyersDiff;

type
  TTokenCompare = record
  private const
    AppName = 'Delphi.Lexer.TokenCompare';
    ExitCode_Success = 0;
    ExitCode_OpFailure = 1;
    ExitCode_Difference = 10;
    ExitCode_TooManyDiffs = 11;  // comparison aborted: edit distance exceeded threshold
  private
    class function ParseCommandLine: TFileCompareConfigOptions; static;
    class procedure ShowUsage; static;
    // Derive the comparison mode name from the active ignore flags for display in output.
    class function ComparisonModeName(const Config:TFileCompareConfigOptions): string; static;
    // Return a new list containing only the tokens that survive the active
    // ignore flags. The returned list is owned by the caller.
    class function FilterTokens(const Config:TFileCompareConfigOptions; Tokens: TTokenList): TTokenList; static;
    // Return a single-line display string for a token in diff output.
    // Control characters are replaced with <TAG> codes.
    class function TokenLabel(const Tok: TToken): string; static;
    class function WriteTextOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TTokenList): Integer; static;
    class function WriteJsonOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TTokenList): Integer; static;
  public
    class function Run: Integer; static;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  Delphi.Token.Kind,
  Delphi.Lexer;

class procedure TTokenCompare.ShowUsage;
begin
  WriteLn(AppName);
  WriteLn('Compares the token streams of two Object Pascal source files');
  WriteLn('A command-line utility for delphi-lexer from Continuous-Delphi');
  WriteLn('https://github.com/continuous-delphi/delphi-lexer');
  WriteLn('MIT Licensed. Copyright (C) 2026, Darian Miller');
  WriteLn;
  WriteLn('Usage:');
  WriteLn('  ', ExtractFileName(ParamStr(0)), ' <file-a> <file-b> [options]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -t, --ignore-trivia        Ignore whitespace and EOL tokens');
  WriteLn('      --ignore-whitespace-eol  Alias for --ignore-trivia');
  WriteLn('  -w, --ignore-whitespace    Ignore whitespace tokens');
  WriteLn('  -e, --ignore-eol           Ignore EOL tokens');
  WriteLn('  -c, --ignore-comments      Ignore comment tokens');
  WriteLn('  -x, --stop-after-first-diff  Stop after the first difference');
  WriteLn('      --max-diffs:<n>        Limit reported differences, 0 means unlimited');
  WriteLn('  --encoding:<name>          Source encoding: utf-8, utf-16, utf-16be, ansi, ascii, default');
  WriteLn('  --format:<name>            Output format: text or json');
  WriteLn('  -a, --no-ansi-fallback     Do not retry file reads with ANSI/Windows-1252');
  WriteLn('  -?, --help                 Show this help and exit');
end;

class function TTokenCompare.ParseCommandLine: TFileCompareConfigOptions;
var
  I: Integer;
  Arg: string;
  Value: string;
  EncodingName: string;
  FormatName: string;
begin
  Result := Default(TFileCompareConfigOptions);
  Result.BaseOptions.AbortProgram := True;

  EncodingName := 'utf-8';
  FormatName := 'text';

  for I := 1 to ParamCount do
  begin
    Arg := ParamStr(I);

    if SameText(Arg, '-?') or SameText(Arg, '--help') then
    begin
      ShowUsage;
      Result.BaseOptions.ExitCode := 0;
      Exit;
    end
    else if SameText(Arg, '-a') or SameText(Arg, '--no-ansi-fallback') then
      Result.BaseOptions.SkipAnsiFallback := True
    else if SameText(Arg, '-t') or SameText(Arg, '--ignore-trivia') or SameText(Arg, '--ignore-whitespace-eol') then
    begin
      Result.IgnoreWhitespace := True;
      Result.IgnoreEOL := True;
    end
    else if SameText(Arg, '-w') or SameText(Arg, '--ignore-whitespace') then
      Result.IgnoreWhitespace := True
    else if SameText(Arg, '-e') or SameText(Arg, '--ignore-eol') then
      Result.IgnoreEOL := True
    else if SameText(Arg, '-c') or SameText(Arg, '--ignore-comments') then
      Result.IgnoreComments := True
    else if SameText(Arg, '-x') or SameText(Arg, '--stop-after-first-diff') then
      Result.StopAfterFirstDiff := True
    else if TLexerUtils.TryReadOptionValue(Arg, '--encoding', Value) then
      EncodingName := Value
    else if TLexerUtils.TryReadOptionValue(Arg, '--format', Value) then
      FormatName := Value
    else if TLexerUtils.TryReadOptionValue(Arg, '--max-diffs', Value) then
    begin
      if not TryStrToInt(Value, Result.MaxDiffs) then
      begin
        WriteLn('error: invalid integer for --max-diffs: ', Value);
        Result.BaseOptions.ExitCode := ExitCode_OpFailure;
        Exit;
      end;
    end
    else if (Arg <> '') and (Arg[1] = '-') then
    begin
      WriteLn('error: unknown option: ', Arg);
      Result.BaseOptions.ExitCode := ExitCode_OpFailure;
      Exit;
    end
    else if Result.BaseOptions.FileName = '' then
      Result.BaseOptions.FileName := Arg
    else if Result.SecondFile = '' then
      Result.SecondFile := Arg
    else
    begin
      WriteLn('error: too many input files');
      Result.BaseOptions.ExitCode := ExitCode_OpFailure;
      Exit;
    end;
  end;

  if (Result.BaseOptions.FileName = '') or (Result.SecondFile = '') then
  begin
    ShowUsage;
    Result.BaseOptions.ExitCode := ExitCode_OpFailure;
    Exit;
  end;

  Result.BaseOptions.Encoding := TLexerUtils.ResolveEncoding(EncodingName);
  if not Assigned(Result.BaseOptions.Encoding) then
  begin
    WriteLn('error: unknown encoding: ', EncodingName);
    WriteLn('Supported: utf-8, utf-16, utf-16be, ansi, ascii, default');
    Result.BaseOptions.ExitCode := ExitCode_OpFailure;
    Exit;
  end;

  if SameText(FormatName, 'json') then
    Result.BaseOptions.OutputFormat := TOutputFormat.ofJson
  else if SameText(FormatName, 'text') then
    Result.BaseOptions.OutputFormat := TOutputFormat.ofText
  else
  begin
    WriteLn('error: unknown format: ', FormatName);
    WriteLn('Supported formats: text, json');
    Result.BaseOptions.ExitCode := ExitCode_OpFailure;
    Exit;
  end;

  if not TFile.Exists(Result.BaseOptions.FileName) then
  begin
    WriteLn('error: file not found: ', Result.BaseOptions.FileName);
    Result.BaseOptions.ExitCode := ExitCode_OpFailure;
    Exit;
  end;
  if not TFile.Exists(Result.SecondFile) then
  begin
    WriteLn('error: file not found: ', Result.SecondFile);
    Result.BaseOptions.ExitCode := ExitCode_OpFailure;
    Exit;
  end;

  try
    Result.BaseOptions.FileContents := TLexerUtils.ReadAllText(
      Result.BaseOptions.FileName,
      Result.BaseOptions.Encoding,
      Result.BaseOptions.SkipAnsiFallback);
    Result.SecondContents := TLexerUtils.ReadAllText(
      Result.SecondFile,
      Result.BaseOptions.Encoding,
      Result.BaseOptions.SkipAnsiFallback);
  except
    on E: Exception do
    begin
      WriteLn('error: could not read file: ', E.Message);
      Result.BaseOptions.ExitCode := ExitCode_OpFailure;
      Exit;
    end;
  end;

  if Result.StopAfterFirstDiff then
    Result.MaxDiffs := 1
  else if Result.MaxDiffs <= 0 then
    Result.MaxDiffs := MaxInt;

  Result.BaseOptions.AbortProgram := False;
end;

class function TTokenCompare.Run: Integer;
var
  Options: TFileCompareConfigOptions;
  Lexer: TDelphiLexer;
  TokensA, TokensB: TTokenList;
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Options := ParseCommandLine;
  if Options.BaseOptions.AbortProgram then Exit(Options.BaseOptions.ExitCode);

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
      Result := ExitCode_OpFailure;
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


class function TTokenCompare.FilterTokens(const Config:TFileCompareConfigOptions; Tokens: TTokenList): TTokenList;
var
  Tok: TToken;
begin
  Result := TTokenList.Create;
  for Tok in Tokens do
  begin
    if Config.IgnoreWhitespace and (Tok.Kind = tkWhitespace) then Continue;
    if Config.IgnoreEOL and (Tok.Kind = tkEOL) then Continue;
    if Config.IgnoreComments and (Tok.Kind = tkComment) then Continue;

    Result.Add(Tok);
  end;
end;


class function TTokenCompare.TokenLabel(const Tok: TToken): string;
begin
  Result := Format('%s "%s"', [TokenKindName(Tok.Kind), TLexerUtils.SafeText(Tok.Text)]);
end;


class function TTokenCompare.WriteTextOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TTokenList): Integer;
var
  FilteredA, FilteredB: TTokenList;
  Diffs:              TList<TDiffEntry>;
  TotalDiffs:         Integer;
  UsedFallback:       Boolean;
  AbortedTooManyDiffs: Boolean;
  I:                  Integer;
  DisplayIdx:         Integer;
  Entry, Next:        TDiffEntry;
  Equal:              Boolean;
begin
  FilteredA := FilterTokens(Config, RawA);
  FilteredB := FilterTokens(Config, RawB);
  Diffs     := BuildDiffList(FilteredA, FilteredB,
                 Config.MaxDiffs, Config.StopAfterFirstDiff,
                 TotalDiffs, UsedFallback, AbortedTooManyDiffs);
  try
    Equal := (TotalDiffs = 0) and not AbortedTooManyDiffs;

    // Header.
    WriteLn('');
    WriteLn(AppName);
    WriteLn('formatVersion: ', '2.1.0'); // Bump if TEXT output structure (or logic) changes
    WriteLn(Format('%-18s : %s', ['File A', Config.BaseOptions.FileName]));
    WriteLn(Format('%-18s : %s', ['File B', Config.SecondFile]));
    WriteLn(Format('%-18s : %s', ['Mode',   ComparisonModeName(Config)]));
    WriteLn(Format('%-18s : %s', ['Equal', if Equal then 'yes' else 'no']));
    if FilteredA.Count = FilteredB.Count then
      WriteLn(Format('%-18s : %d',     ['Compared Tokens', FilteredA.Count]))
    else
      WriteLn(Format('%-18s : %d / %d', ['Compared Tokens', FilteredA.Count, FilteredB.Count]));
    if AbortedTooManyDiffs then
      WriteLn(Format('%-18s : %s', ['Diff Count', '(unknown; aborted)']))
    else
      WriteLn(Format('%-18s : %d', ['Diff Count', TotalDiffs]));

    if AbortedTooManyDiffs then
      WriteLn(Format('(aborted: edit distance exceeds %d%% of token count; are these the right files?)',
        [MAX_MYERS_EDIT_DISTANCE_PCT]));
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

  if AbortedTooManyDiffs then
    Result := ExitCode_TooManyDiffs
  else if Equal then
    Result := ExitCode_Success
  else
    Result := ExitCode_Difference;

  WriteLn('');
  WriteLn('Exit Code: ', Result);
end;


class function TTokenCompare.WriteJsonOutput(const Config:TFileCompareConfigOptions; RawA, RawB: TTokenList): Integer;
var
  FilteredA, FilteredB: TTokenList;
  Diffs:               TList<TDiffEntry>;
  TotalDiffs:          Integer;
  UsedFallback:        Boolean;
  AbortedTooManyDiffs: Boolean;
  I:                   Integer;
  Entry, Next:         TDiffEntry;
  Equal:               Boolean;
  Root:                TJSONObject;
  Options:             TJSONObject;
  Summary:             TJSONObject;
  DiffsArr:            TJSONArray;
  DiffObj:             TJSONObject;
  TokObj:              TJSONObject;
begin
  FilteredA := FilterTokens(Config, RawA);
  FilteredB := FilterTokens(Config, RawB);
  Diffs     := BuildDiffList(FilteredA, FilteredB,
                 Config.MaxDiffs, Config.StopAfterFirstDiff,
                 TotalDiffs, UsedFallback, AbortedTooManyDiffs);
  try
    Equal := (TotalDiffs = 0) and not AbortedTooManyDiffs;

    Root := TJSONObject.Create;
    try

      Root.AddPair('toolName', AppName);
      Root.AddPair('formatVersion', '2.1.0');  // Bump if JSON output structure (or logic) changes
      Root.AddPair('fileA', Config.BaseOptions.FileName);
      Root.AddPair('fileB', Config.SecondFile);

      Options := TJSONObject.Create;
      Options.AddPair('encoding',           Config.BaseOptions.Encoding.EncodingName);
      Options.AddPair('ignoreWhitespace',   TJSONBool.Create(Config.IgnoreWhitespace));
      Options.AddPair('ignoreEOL',          TJSONBool.Create(Config.IgnoreEOL));
      Options.AddPair('ignoreComments',     TJSONBool.Create(Config.IgnoreComments));
      Options.AddPair('stopAfterFirstDiff', TJSONBool.Create(Config.StopAfterFirstDiff));
      Options.AddPair('maxDiffs',           TJSONNumber.Create(Config.MaxDiffs));
      Options.AddPair('usedFallback',         TJSONBool.Create(UsedFallback));
      Options.AddPair('abortedTooManyDiffs', TJSONBool.Create(AbortedTooManyDiffs));
      Root.AddPair('options', Options);

      Summary := TJSONObject.Create;
      Summary.AddPair('equal',               TJSONBool.Create(Equal));
      Summary.AddPair('comparisonMode',      ComparisonModeName(Config));
      Summary.AddPair('rawTokenCountA',      TJSONNumber.Create(RawA.Count));
      Summary.AddPair('rawTokenCountB',      TJSONNumber.Create(RawB.Count));
      Summary.AddPair('comparedTokenCountA', TJSONNumber.Create(FilteredA.Count));
      Summary.AddPair('comparedTokenCountB', TJSONNumber.Create(FilteredB.Count));
      // diffCount is -1 (unknown) when AbortedTooManyDiffs is true.
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

  if AbortedTooManyDiffs then
    Result := ExitCode_TooManyDiffs
  else if Equal then
    Result := ExitCode_Success
  else
    Result := ExitCode_Difference;
end;

end.
