program Delphi.Lexer.TokenizeMemo;

uses
  Vcl.Forms,
  Delphi.Lexer.TokenizeMemo.MainForm in 'Delphi.Lexer.TokenizeMemo.MainForm.pas' {frmMain},
  Delphi.Token.List in '..\..\source\Delphi.Token.List.pas',
  Delphi.Token.Kind in '..\..\source\Delphi.Token.Kind.pas',
  Delphi.Tokenizer in '..\..\source\Delphi.Tokenizer.pas',
  Delphi.Token.TriviaSpan in '..\..\source\Delphi.Token.TriviaSpan.pas',
  Delphi.Token in '..\..\source\Delphi.Token.pas',
  Delphi.Lexer.Utils in '..\..\source\Delphi.Lexer.Utils.pas',
  Delphi.Lexer.Scanner in '..\..\source\Delphi.Lexer.Scanner.pas',
  Delphi.Lexer in '..\..\source\Delphi.Lexer.pas',
  Delphi.Keywords in '..\..\source\Delphi.Keywords.pas',
  GpCommandLineParser in '..\..\shared\GpCommandLineParser.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
