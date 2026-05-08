(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Delphi.Lexer.TokenizeMemo.MainForm;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Delphi.Token.List;


type

  TfrmMain = class(TForm)
    memSource:TMemo;
    butTokenize:TButton;
    memTokens:TMemo;
    labSourceCode:TLabel;
    labStatus:TLabel;
    procedure FormCreate(Sender:TObject);
    procedure butTokenizeClick(Sender:TObject);
  public
    function CreateTokens(const SourceCode:string):TTokenList;
    procedure DumpTokens(const TokenList:TTokenList; const Destination:TStrings);
  end;

var
  frmMain:TfrmMain;

implementation

uses
  System.SysUtils,
  Delphi.Token,
  Delphi.Token.Kind,
  Delphi.Lexer,
  Delphi.Lexer.Utils;

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender:TObject);
begin
  ReportMemoryLeaksOnShutdown := True;
end;

procedure TfrmMain.butTokenizeClick(Sender:TObject);
var
  Tokens:TTokenList;
begin
  Tokens := CreateTokens(memSource.Text);
  try
    DumpTokens(Tokens, memTokens.Lines);
  finally
    Tokens.Free;
  end;
end;

function TfrmMain.CreateTokens(const SourceCode:string):TTokenList;
var
  Lexer:TDelphiLexer;
begin

  Lexer := TDelphiLexer.Create;
  try
    Result := Lexer.Tokenize(SourceCode);
  finally
    Lexer.Free;
  end;

  labStatus.Caption := Format('%d Tokens', [Result.Count]);
end;

procedure TfrmMain.DumpTokens(const TokenList:TTokenList; const Destination:TStrings);
var
  I:Integer;
  Token:TToken;
  Line:string;
  LineVal, ColVal:string;
begin
  Destination.BeginUpdate;
  try
    Destination.Clear;
    Destination.Add(Format('%5s  %-17s  %6s  %6s  %6s  %6s  %11s  %11s  %s',
        ['Idx', 'Kind', 'Line', 'Column', 'Offset', 'Length', 'LeadTrivia', 'TrailTrivia', 'Text']));

    Destination.Add(StringOfChar('-', 5) + '  ' + StringOfChar('-', 17) + '  ' + StringOfChar('-', 6) + '  ' +
      StringOfChar('-', 6) + '  ' + StringOfChar('-', 6) + '  ' + StringOfChar('-', 6) + '  ' +
      StringOfChar('-', 11) + '  ' + StringOfChar('-', 11) + '  ' + StringOfChar('-', 48));

    for I := 0 to TokenList.Count - 1 do
    begin
      Token := TokenList[i];

      LineVal := Token.Line.ToString;
      ColVal := Token.Col.ToString;

      Line := Format('%5d  %-17s  %6s  %6s  %6d  %6d  %11s  %11s  %s',
        [I, TokenKindName(Token.Kind), LineVal, ColVal, Token.StartOffset,
          Token.Length, Token.LeadingTrivia.ToDebugString, Token.TrailingTrivia.ToDebugString,
          TLexerUtils.SafeText(Token.Text)]);
      Destination.Add(Line);
    end;
  finally
    Destination.EndUpdate;
  end;
end;

end.

