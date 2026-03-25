program DelphiLexer.TokenCompare;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  TokenCompare in 'TokenCompare.pas',
  DelphiLexer.Utils in '..\..\source\DelphiLexer.Utils.pas',
  DelphiLexer.Token in '..\..\source\DelphiLexer.Token.pas',
  DelphiLexer.Scanner in '..\..\source\DelphiLexer.Scanner.pas',
  DelphiLexer.Lexer in '..\..\source\DelphiLexer.Lexer.pas',
  DelphiLexer.Keywords in '..\..\source\DelphiLexer.Keywords.pas',
  GpCommandLineParser in '..\..\shared\GpCommandLineParser.pas',
  DelphiLexer.Diff in '..\..\source\DelphiLexer.Diff.pas';

begin

  ExitCode := TTokenCompare.Run;

end.
