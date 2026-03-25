UNIT NumberUtils;

INTERFACE

TYPE

  ///<summary> Custom TIntArray summary </summary>
  TIntArray = array of Integer;

function Sum(const Values: TIntArray): Integer;
function Max(A, B: Integer): Integer; deprecated;

implementation

function Sum(const Values: TIntArray): Integer;  {EOL Comment}
var
  I: Integer;
begin
  Result := 0;
  for I := Low(Values) to High(Values) do
    Result := Result + Values[I];
end;

function Max(A, B: Integer): Integer;
begin
  (*
    extra comments
    here
  *)
  if A >= B then
    Result := A
  else
    Result := B;
end;

end.
