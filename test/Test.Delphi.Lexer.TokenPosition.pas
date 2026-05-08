(*

  delphi-lexer
  https://github.com/continuous-delphi/delphi-lexer

  A lightweight, lossless lexer for Delphi source code.
  Includes TokenDump, TokenStats, and TokenCompare utilities
  plus a syntax highlighter for SynEdit.

  License: MIT
  Copyright (c) 2026 Darian Miller

*)

unit Test.Delphi.Lexer.TokenPosition;

// Tests that the lexer stamps correct Line and Col on every token.

interface

uses
  DUnitX.TestFramework,
  Delphi.Token,
  Delphi.Token.List,
  Delphi.Lexer;

type

  [TestFixture]
  TTokenPositionTests = class
  private
    FLexer: TDelphiLexer;
    function Tok(const S: string): TTokenList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test] procedure FirstToken_Line1_Col1;
    [Test] procedure TokenAfterWhitespace_HasCorrectCol;
    [Test] procedure TokenAfterCRLF_IsLine2_Col1;
    [Test] procedure TokenAfterLF_IsLine2_Col1;
    [Test] procedure TokenAfterBareCR_IsLine2_Col1;
    [Test] procedure MultipleLines_LineNumbers_AreCorrect;
  end;

implementation


procedure TTokenPositionTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TTokenPositionTests.TearDown;
begin
  FLexer.Free;
end;


function TTokenPositionTests.Tok(const S: string): TTokenList;
begin
  Result := FLexer.Tokenize(S);
end;


procedure TTokenPositionTests.FirstToken_Line1_Col1;
var
  T: TTokenList;
begin
  T := Tok('begin');
  try
    Assert.AreEqual(1, T[0].Line, 'Line');
    Assert.AreEqual(1, T[0].Col,  'Col');
  finally
    T.Free;
  end;
end;


procedure TTokenPositionTests.TokenAfterWhitespace_HasCorrectCol;
var
  T: TTokenList;
begin
  // '  end' -> tkWhitespace(Col=1), tkKeyword(Col=3)
  T := Tok('  end');
  try
    Assert.AreEqual(1, T[0].Line, 'ws Line');
    Assert.AreEqual(1, T[0].Col,  'ws Col');
    Assert.AreEqual(1, T[1].Line, 'kw Line');
    Assert.AreEqual(3, T[1].Col,  'kw Col');
  finally
    T.Free;
  end;
end;


procedure TTokenPositionTests.TokenAfterCRLF_IsLine2_Col1;
var
  T: TTokenList;
begin
  // [0]=begin L1C1, [1]=EOL L1C6, [2]=end L2C1, [3]=EOF
  T := Tok('begin'#13#10'end');
  try
    Assert.AreEqual(2, T[2].Line, 'Line');
    Assert.AreEqual(1, T[2].Col,  'Col');
  finally
    T.Free;
  end;
end;


procedure TTokenPositionTests.TokenAfterLF_IsLine2_Col1;
var
  T: TTokenList;
begin
  // [0]=begin L1C1, [1]=EOL L1C6, [2]=end L2C1, [3]=EOF
  T := Tok('begin'#10'end');
  try
    Assert.AreEqual(2, T[2].Line, 'Line');
    Assert.AreEqual(1, T[2].Col,  'Col');
  finally
    T.Free;
  end;
end;


procedure TTokenPositionTests.TokenAfterBareCR_IsLine2_Col1;
var
  T: TTokenList;
begin
  // [0]=begin L1C1, [1]=EOL L1C6 (bare CR), [2]=end L2C1, [3]=EOF
  T := Tok('begin'#13'end');
  try
    Assert.AreEqual(2, T[2].Line, 'Line');
    Assert.AreEqual(1, T[2].Col,  'Col');
  finally
    T.Free;
  end;
end;


procedure TTokenPositionTests.MultipleLines_LineNumbers_AreCorrect;
var
  T: TTokenList;
begin
  // 'if'#10'then'#10'else'
  // [0]=if L1, [1]=EOL, [2]=then L2, [3]=EOL, [4]=else L3, [5]=EOF
  T := Tok('if'#10'then'#10'else');
  try
    Assert.AreEqual(1, T[0].Line, 'if Line');
    Assert.AreEqual(2, T[2].Line, 'then Line');
    Assert.AreEqual(3, T[4].Line, 'else Line');
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TTokenPositionTests);

end.
