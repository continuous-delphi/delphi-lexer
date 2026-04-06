unit directive_usage;

interface

type

  TMytest = class
  public
    procedure DoSomething;
  end;

implementation

{ TMytest }

procedure TMytest.DoSomething;
begin
  {$IFDEF DEBUG}
  WriteLn('Debug');
  {$ELSE}
  WriteLn('Not Debug');
  {$ENDIF}
end;

end.
