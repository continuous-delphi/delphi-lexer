unit NumberUtils;

interface

type
  TIntArray = array of Integer;

function Sum(const Values: TIntArray): Integer;
function Max(A, B: Integer): Integer;

implementation

function Sum(const Values: TIntArray): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Low(Values) to High(Values) do
    Result := Result + Values[I];
end;

function Max(A, B: Integer): Integer;
begin
  if A >= B then
    Result := A
  else
    Result := B;
end;

end.
