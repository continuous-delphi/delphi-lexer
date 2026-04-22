unit Test.Delphi.Lexer.MultiSegmentStrings;

// Verifies that adjacent single-quoted string literals are emitted as
// separate tkString tokens with whitespace/EOL tokens between them,
// and that the token sequence round-trips back to the exact original source.

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Delphi.Token,
  Delphi.Token.List,
  Delphi.Lexer;

type

  [TestFixture]
  TMultiSegmentStringTests = class
  private
    FLexer: TDelphiLexer;
    function Reconstruct(const T: TTokenList): string;
    procedure CollectStrings(const T: TTokenList; out Strings: TArray<string>);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test] procedure Adjacent_Strings_On_Same_Line_Are_Separate_Tokens_And_RoundTrip;

    [Test] procedure Adjacent_Strings_With_EOL_And_Indent_Are_Separate_Tokens_And_RoundTrip;
  end;


implementation

uses
  System.Generics.Collections,
  Delphi.Token.Kind;


procedure TMultiSegmentStringTests.Setup;
begin
  FLexer := TDelphiLexer.Create;
end;


procedure TMultiSegmentStringTests.TearDown;
begin
  FLexer.Free;
end;


function TMultiSegmentStringTests.Reconstruct(const T: TTokenList): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to T.Count - 1 do
    Result := Result + T[I].Text;
end;


procedure TMultiSegmentStringTests.CollectStrings(const T: TTokenList;
  out Strings: TArray<string>);
var
  Acc: TList<string>;
  I: Integer;
begin
  Acc := TList<string>.Create;
  try
    for I := 0 to T.Count - 1 do
      if T[I].Kind = tkString then
        Acc.Add(T[I].Text);
    Strings := Acc.ToArray;
  finally
    Acc.Free;
  end;
end;


procedure TMultiSegmentStringTests.Adjacent_Strings_On_Same_Line_Are_Separate_Tokens_And_RoundTrip;
const
  // 'Hello, ' 'World' on first line; 'a''b' 'c' on second line.
  // Note: doubled quote inside 'a''b' is preserved.
  Src = 'const' + sLineBreak
      + '  S = ''Hello, '' ''World'';' + sLineBreak
      + '  T = ''a''''b'' ''c'';' + sLineBreak;
var
  T: TTokenList;
  Strings: TArray<string>;
  Text: string;
begin
  T := FLexer.Tokenize(Src);
  try
    Text := Reconstruct(T);
    Assert.AreEqual(Src, Text, False);

    CollectStrings(T, Strings);
    Assert.AreEqual(NativeInt(4), Length(Strings), 'Expected 4 string tokens');
    Assert.AreEqual('''Hello, ''', Strings[0], False);
    Assert.AreEqual('''World''',   Strings[1], False);
    Assert.AreEqual('''a''''b''',  Strings[2], False); // doubled quote preserved
    Assert.AreEqual('''c''',       Strings[3], False);
  finally
    T.Free;
  end;
end;


procedure TMultiSegmentStringTests.Adjacent_Strings_With_EOL_And_Indent_Are_Separate_Tokens_And_RoundTrip;
const
  // 'Hello,' on first line; ' world' and '!' each on their own continuation line.
  Src = 'const' + sLineBreak
      + '  S = ''Hello,'' ' + sLineBreak
      + '      '' world''' + sLineBreak
      + '      ''!'';' + sLineBreak;
var
  T: TTokenList;
  Strings: TArray<string>;
  Text: string;
begin
  T := FLexer.Tokenize(Src);
  try
    Text := Reconstruct(T);
    Assert.AreEqual(Src, Text, False);

    CollectStrings(T, Strings);
    Assert.AreEqual(NativeInt(3), Length(Strings), 'Expected 3 string tokens');
    Assert.AreEqual('''Hello,''',  Strings[0], False);
    Assert.AreEqual(''' world''',  Strings[1], False); // leading space inside literal
    Assert.AreEqual('''!''',       Strings[2], False);
  finally
    T.Free;
  end;
end;


initialization

TDUnitX.RegisterTestFixture(TMultiSegmentStringTests);

end.
