program Delphi.Lexer.TokenDump;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Delphi.Lexer.TokenDump.Main in 'Delphi.Lexer.TokenDump.Main.pas',
  GpCommandLineParser in '..\..\shared\GpCommandLineParser.pas',
  Delphi.Lexer in '..\..\source\Delphi.Lexer.pas',
  Delphi.Lexer.Scanner in '..\..\source\Delphi.Lexer.Scanner.pas',
  Delphi.Keywords in '..\..\source\Delphi.Keywords.pas',
  Delphi.Lexer.Utils in '..\..\source\Delphi.Lexer.Utils.pas',
  Delphi.Tokenizer in '..\..\source\Delphi.Tokenizer.pas',
  Delphi.Token in '..\..\source\Delphi.Token.pas',
  Delphi.TokenKind in '..\..\source\Delphi.TokenKind.pas',
  Delphi.TokenList in '..\..\source\Delphi.TokenList.pas',
  Delphi.Token.TriviaSpan in '..\..\source\Delphi.Token.TriviaSpan.pas';

begin

  ExitCode := TTokenDump.Run;

end.
