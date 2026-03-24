program DelphiLexer.TokenStats;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  TokenStats in 'TokenStats.pas',
  DelphiLexer.Lexer in '..\..\source\DelphiLexer.Lexer.pas',
  DelphiLexer.Scanner in '..\..\source\DelphiLexer.Scanner.pas',
  DelphiLexer.Token in '..\..\source\DelphiLexer.Token.pas',
  DelphiLexer.Keywords in '..\..\source\DelphiLexer.Keywords.pas',
  DelphiLexer.Utils in '..\..\source\DelphiLexer.Utils.pas',
  GpCommandLineParser in '..\..\shared\GpCommandLineParser.pas';

begin

  ExitCode := TTokenStats.Run;

end.
