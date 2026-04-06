unit Delphi.Token.TriviaSpan;

interface

type

  // Inclusive range [FirstTokenIndex .. LastTokenIndex] into a TTokenList
  // Identifies a contiguous run of trivia tokens owned by one semantic token.
  // Empty when FirstTokenIndex = -1 (use IsEmpty / Count helpers).
  TTriviaSpan = record
    FirstTokenIndex:Integer;
    LastTokenIndex:Integer;
    function IsEmpty:Boolean;
    function Count:Integer;
  end;


const

  DEFAULT_TRIVIASPAN:TTriviaSpan = (FirstTokenIndex: -1; LastTokenIndex: -1);


implementation

uses
  System.SysUtils;


function TTriviaSpan.IsEmpty:Boolean;
begin
  Result := FirstTokenIndex = -1;
end;


function TTriviaSpan.Count:Integer;
begin
  if IsEmpty then
    Exit(0);
  Result := LastTokenIndex - FirstTokenIndex + 1;
end;


end.
