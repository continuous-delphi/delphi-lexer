unit Delphi.Tokenizer;

interface

uses
  Delphi.Token,
  Delphi.Token.List;

type

  ITokenizer = interface
    ['{B1E09F1D-1A89-4D6C-AD90-A3B2D0CDA29F}']
    function Tokenize(const Source:string):TTokenList;
  end;

implementation

end.

