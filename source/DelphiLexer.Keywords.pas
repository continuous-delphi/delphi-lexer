unit DelphiLexer.Keywords;

// Delphi reserved-word list and binary-search classification.
//
// Policy:
//
//   Only TRUE reserved words belong here -- words the Delphi compiler
//   rejects as plain identifiers and which require &-escaping to use as
//   identifiers (e.g. &begin, &type). Contextual (directive) keywords
//   tokenize as tkIdentifier and are NOT included.
//
// Contextual keywords deliberately absent (tokenize as tkIdentifier):
//
//   absolute, abstract, assembler, async, automated, cdecl, contains,
//   default, delayed, deprecated, dispid, dynamic, experimental, export,
//   external, far, final, forward, helper, implements, index, local,
//   message, name, near, nodefault, noreturn, operator, overload, override,
//   package, pascal, platform, private, protected, public, published, read,
//   readonly, reference, register, reintroduce, requires, resident,
//   safecall, sealed, static, stdcall, stored, strict, unsafe, varargs,
//   virtual, winapi, write, writeonly.
//
// Verify DELPHI_KEYWORDS and make final decision on these:
//
//   'out'      -- IS a reserved word (function/procedure parameter modifier);
//                 included.
//   'on'       -- IS a reserved word (exception handler label in try/except);
//                 included. Florence docwiki note: "at and on also have
//                 special meanings, and should be treated as reserved words."
//   'at'       -- IS a reserved word (address clause in raise...at);
//                 included. Same docwiki note as 'on' above.
//   'inline'   -- IS a reserved word; included. Same version note as 'out'.
//   'operator' -- contextual keyword only; NOT included; tokenizes as
//                 tkIdentifier.

interface

// Returns True if S is a Delphi reserved word (case-insensitive).
function IsDelphiKeyword(const S: string): Boolean;

implementation

uses
  System.SysUtils;

const
  // Full Delphi reserved-word list, sorted ascending for binary search.
  // 67 entries (indices 0..66).
  DELPHI_KEYWORDS: array[0..66] of string = (
    'and', 'array', 'as', 'asm', 'at',
    'begin',
    'case', 'class', 'const', 'constructor',
    'destructor', 'dispinterface', 'div', 'do', 'downto',
    'else', 'end', 'except', 'exports',
    'file', 'finalization', 'finally', 'for', 'function',
    'goto',
    'if', 'implementation', 'in', 'inherited', 'initialization', 'inline',
    'interface', 'is',
    'label', 'library',
    'mod',
    'nil', 'not',
    'object', 'of', 'on', 'or', 'out',
    'packed', 'procedure', 'program', 'property',
    'raise', 'record', 'repeat', 'resourcestring',
    'set', 'shl', 'shr', 'string',
    'then', 'threadvar', 'to', 'try', 'type',
    'unit', 'until', 'uses',
    'var',
    'while', 'with',
    'xor'
  );


function IsDelphiKeyword(const S: string): Boolean;
var
  Lo, Hi, Mid, Cmp: Integer;
  Lower: string;
begin
  Lower := LowerCase(S);
  Lo := Low(DELPHI_KEYWORDS);
  Hi := High(DELPHI_KEYWORDS);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    Cmp := CompareStr(Lower, DELPHI_KEYWORDS[Mid]);
    if Cmp = 0 then Exit(True)
    else if Cmp < 0 then Hi := Mid - 1
    else Lo := Mid + 1;
  end;
  Result := False;
end;


end.
