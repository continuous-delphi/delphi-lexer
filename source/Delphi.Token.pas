unit Delphi.Token;

interface

uses
  Delphi.TokenKind,
  Delphi.Token.TriviaSpan;

type

  TToken = record
    Kind:TTokenKind;
    Text:string; // Characters of this token, as they appear in the source
    Line:Integer; // 1-based line number of the first character
    Col:Integer; // 1-based column number of the first character
    StartOffset:Integer; // 0-based absolute character index into source
    Length:Integer; // character count of Text: equals `System.Length(Text)`
    LeadingTrivia:TTriviaSpan; // trivia tokens immediately before this token
    TrailingTrivia:TTriviaSpan; // same-line trivia tokens after this token (incl. EOL)

    constructor Create(const AKind:TTokenKind; const AText:string; const ALine:Integer = -1; const ACol:Integer = -1; const AStartOffset:Integer = 0; const ALength:Integer = 0);
    procedure Reset;
  end;

  //helper used in tree export
  TTriviaText = record
    Whitespace:string;
    InactiveCode:string;
  end;


implementation

constructor TToken.Create(const AKind:TTokenKind; const AText:string; const ALine:Integer = -1; const ACol:Integer = -1; const AStartOffset:Integer = 0; const ALength:Integer = 0);
begin
  Self.Kind := AKind;
  Self.Text := AText;
  Self.Line := ALine;
  Self.Col := ACol;
  Self.StartOffset := AStartOffset;
  Self.Length := ALength;
  Self.LeadingTrivia := DEFAULT_TRIVIASPAN;
  Self.TrailingTrivia := DEFAULT_TRIVIASPAN;
end;

procedure TToken.Reset;
begin
  Self := Default(TToken);
  Self.Line := -1;
  Self.Col := -1;
  Self.LeadingTrivia := DEFAULT_TRIVIASPAN;
  Self.TrailingTrivia := DEFAULT_TRIVIASPAN;
end;

end.

