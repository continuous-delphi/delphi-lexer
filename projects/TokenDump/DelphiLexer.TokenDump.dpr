program DelphiLexer.TokenDump;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  TokenDump in 'TokenDump.pas',
  GpCommandLineParser in '..\..\shared\GpCommandLineParser.pas',
  DelphiLexer.Lexer in '..\..\source\DelphiLexer.Lexer.pas',
  DelphiLexer.Scanner in '..\..\source\DelphiLexer.Scanner.pas',
  DelphiLexer.Token in '..\..\source\DelphiLexer.Token.pas',
  DelphiLexer.Keywords in '..\..\source\DelphiLexer.Keywords.pas',
  DelphiLexer.Utils in '..\..\source\DelphiLexer.Utils.pas';

begin

  ExitCode := TTokenDump.Run;

end.
