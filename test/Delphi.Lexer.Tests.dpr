program Delphi.Lexer.Tests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
uses
  DUnitX.MemoryLeakMonitor.FastMM4,
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.XML.NUnit,
  {$ENDIF }
  DUnitX.TestFramework,
  Delphi.Keywords in '..\source\Delphi.Keywords.pas',
  Delphi.Lexer.Scanner in '..\source\Delphi.Lexer.Scanner.pas',
  Delphi.Lexer in '..\source\Delphi.Lexer.pas',
  Delphi.Lexer.MyersDiff in '..\source\Delphi.Lexer.MyersDiff.pas',
  Delphi.TokenKind in '..\source\Delphi.TokenKind.pas',
  Delphi.TokenList in '..\source\Delphi.TokenList.pas',
  Delphi.Token in '..\source\Delphi.Token.pas',
  Delphi.Tokenizer in '..\source\Delphi.Tokenizer.pas',
  Delphi.Token.TriviaSpan in '..\source\Delphi.Token.TriviaSpan.pas',
  Test.Delphi.Lexer.AsmBody in 'Test.Delphi.Lexer.AsmBody.pas',
  Test.Delphi.Lexer.Core in 'Test.Delphi.Lexer.Core.pas',
  Test.Delphi.Lexer.FindTokenAtOffset in 'Test.Delphi.Lexer.FindTokenAtOffset.pas',
  Test.Delphi.Lexer.Golden in 'Test.Delphi.Lexer.Golden.pas',
  Test.Delphi.Lexer.InvalidTokens in 'Test.Delphi.Lexer.InvalidTokens.pas',
  Test.Delphi.Lexer.Keywords in 'Test.Delphi.Lexer.Keywords.pas',
  Test.Delphi.Lexer.MultiLineStrings in 'Test.Delphi.Lexer.MultiLineStrings.pas',
  Test.Delphi.Lexer.MultiSegmentStrings in 'Test.Delphi.Lexer.MultiSegmentStrings.pas',
  Test.Delphi.Lexer.NumericLiterals in 'Test.Delphi.Lexer.NumericLiterals.pas',
  Test.Delphi.Lexer.QualifiedIdentifiers in 'Test.Delphi.Lexer.QualifiedIdentifiers.pas',
  Test.Delphi.Lexer.Symbols in 'Test.Delphi.Lexer.Symbols.pas',
  Test.Delphi.Lexer.TokenCompare.Myers in 'Test.Delphi.Lexer.TokenCompare.Myers.pas',
  Test.Delphi.Lexer.TokenMetadata in 'Test.Delphi.Lexer.TokenMetadata.pas',
  Test.Delphi.Lexer.TokenPosition in 'Test.Delphi.Lexer.TokenPosition.pas',
  Test.Delphi.Lexer.TriviaSpans in 'Test.Delphi.Lexer.TriviaSpans.pas',
  Test.Delphi.Lexer.Directive in 'Test.Delphi.Lexer.Directive.pas';

{ keep comment here to protect the following conditional from being removed by the IDE when adding a unit }
{$IFNDEF TESTINSIGHT}
var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
  nunitLogger : ITestLogger;
{$ENDIF}
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the test runner
    runner := TDUnitX.CreateRunner;
    //Tell the runner to use RTTI to find Fixtures
    runner.UseRTTI := True;
    //When true, Assertions must be made during tests;
    runner.FailsOnNoAsserts := False;

    //tell the runner how we will log things
    //Log to the console window if desired
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      logger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      runner.AddLogger(logger);
    end;
    //Generate an NUnit compatible XML File
    nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    runner.AddLogger(nunitLogger);

    //Run tests
    results := runner.Execute;
    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
{$ENDIF}
end.
