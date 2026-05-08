(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Delphi.Token.List;

interface

uses
  System.Generics.Collections,
  Delphi.Token,
  Delphi.Token.TriviaSpan;

type

  TTokenList = class(TList<TToken>)
  public
    ///<summary> Appends to self, from alternating (Kind, Text) pairs.
    // Pairs must have an even count: Pairs[0]=Kind(Integer), Pairs[1]=Text(string),
    // Pairs[2]=Kind, Pairs[3]=Text, ...
    // Each token gets Length set from its Text and trivia spans set to the
    // canonical empty value (-1, -1).
    // Raises EArgumentException when the pair count is odd. </summary>
    procedure AppendTokenArray(const Pairs:array of const);
    function TriviaSpanText(const Span:TTriviaSpan):TTriviaText;
  end;



implementation

uses
  System.Math,
  System.SysUtils,
  Delphi.Token.Kind;


procedure TTokenList.AppendTokenArray(const Pairs:array of const);
var
  I:Integer;
  Tok:TToken;
begin
  if Length(Pairs) mod 2 <> 0 then
    raise EArgumentException.Create('AppendTokenArray: pair count must be even');

  I := 0;
  while I < Length(Pairs) do
  begin
    Tok.Reset;
    Tok.Kind := TTokenKind(Pairs[I].VInteger);
    case Pairs[I + 1].VType of
      vtChar:Tok.Text := string(Pairs[I + 1].VChar);
      vtWideChar:Tok.Text := string(Pairs[I + 1].VWideChar);
      vtUnicodeString:Tok.Text := string(Pairs[I + 1].VUnicodeString);
      else
        raise EArgumentException.CreateFmt(
          'BuildTokenList: unsupported text VType %d at pair index %d',
          [Pairs[I + 1].VType, I + 1]);
    end;
    Tok.Length := System.Length(Tok.Text);
    Tok.LeadingTrivia := DEFAULT_TRIVIASPAN;
    Tok.TrailingTrivia := DEFAULT_TRIVIASPAN;
    Self.Add(Tok);
    Inc(I, 2);
  end;
end;

(*
function TTokenList.Clone:TTokenList;
var
  I:Integer;
begin
  Result := TTokenList.Create;
  Result.Capacity := Self.Count;
  for I := 0 to Self.Count - 1 do
    Result.Add(Self.Tokens[I]);
end;
*)

// Concatenates the text of all tokens within a trivia span.
// Returns empty string for empty spans.
function TTokenList.TriviaSpanText(const Span:TTriviaSpan):TTriviaText;
var
  I:Integer;
begin
  Result := Default(TTriviaText);

  if Span.IsEmpty then Exit;

  for I := Span.FirstTokenIndex to Min(Span.LastTokenIndex, Self.Count - 1) do
  begin
    if Self[I].Kind = tkInactiveCode then
    begin
      Result.InactiveCode := Result.InactiveCode + Self[I].Text;
    end
    else
    begin
      Result.Whitespace := Result.Whitespace + Self[I].Text;
    end;
  end;
end;


end.

