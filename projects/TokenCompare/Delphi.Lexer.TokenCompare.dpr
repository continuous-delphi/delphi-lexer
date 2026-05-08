program Delphi.Lexer.TokenCompare;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Delphi.Lexer.TokenCompare.Main in 'Delphi.Lexer.TokenCompare.Main.pas',
  Delphi.Lexer.Utils in '..\..\source\Delphi.Lexer.Utils.pas',
  Delphi.Lexer.Scanner in '..\..\source\Delphi.Lexer.Scanner.pas',
  Delphi.Lexer in '..\..\source\Delphi.Lexer.pas',
  Delphi.Keywords in '..\..\source\Delphi.Keywords.pas',
  Delphi.Lexer.MyersDiff in '..\..\source\Delphi.Lexer.MyersDiff.pas',
  Delphi.Token.Kind in '..\..\source\Delphi.Token.Kind.pas',
  Delphi.Token.List in '..\..\source\Delphi.Token.List.pas',
  Delphi.Token in '..\..\source\Delphi.Token.pas',
  Delphi.Tokenizer in '..\..\source\Delphi.Tokenizer.pas',
  Delphi.Token.TriviaSpan in '..\..\source\Delphi.Token.TriviaSpan.pas';

begin

  ExitCode := TTokenCompare.Run;

end.
