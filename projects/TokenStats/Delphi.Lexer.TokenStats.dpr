program Delphi.Lexer.TokenStats;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Delphi.Lexer.TokenStats.Main in 'Delphi.Lexer.TokenStats.Main.pas',
  Delphi.Lexer in '..\..\source\Delphi.Lexer.pas',
  Delphi.Lexer.Scanner in '..\..\source\Delphi.Lexer.Scanner.pas',
  Delphi.Keywords in '..\..\source\Delphi.Keywords.pas',
  Delphi.Lexer.Utils in '..\..\source\Delphi.Lexer.Utils.pas',
  GpCommandLineParser in '..\..\shared\GpCommandLineParser.pas',
  Delphi.Token.Kind in '..\..\source\Delphi.Token.Kind.pas',
  Delphi.Token.List in '..\..\source\Delphi.Token.List.pas',
  Delphi.Token in '..\..\source\Delphi.Token.pas',
  Delphi.Tokenizer in '..\..\source\Delphi.Tokenizer.pas',
  Delphi.Token.TriviaSpan in '..\..\source\Delphi.Token.TriviaSpan.pas';

begin

  ExitCode := TTokenStats.Run;

end.
