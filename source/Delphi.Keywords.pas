unit Delphi.Keywords;

// Delphi reserved-word list and binary-search classification.
//
// Authoritative list from Embarcadero
//   https://docwiki.embarcadero.com/RADStudio/en/Fundamental_Syntactic_Elements_%28Delphi%29

interface

type

  TKeywordCategory = (
    kcStrict,       // true reserved words
    kcDirective,    // custom directives that are contextually keywords
    kcVisibility    // class-scope visibility keywords
  );


  TKeywordKind = (
    kwNone,

    // Strict/HardKeywords : cannot be redefined or used as identifiers
    // Always reserved, global meaning.
    kwAnd, kwArray, kwAs, kwAsm, kwBegin, kwCase, kwClass, kwConst,
    kwConstructor, kwDestructor, kwDispinterface, kwDiv, kwDo, kwDownto,
    kwElse, kwEnd, kwExcept, kwExports, kwFile, kwFinalization, kwFinally,
    kwFor, kwFunction, kwGoto, kwIf, kwImplementation, kwIn, kwInherited,
    kwInitialization, kwInline, kwInterface, kwIs, kwLabel, kwLibrary,
    kwMod, kwNil, kwNot, kwObject, kwOf, kwOr, kwPacked, kwProcedure,
    kwProgram, kwProperty, kwRaise, kwRecord, kwRepeat, kwResourcestring,
    kwSet, kwShl, kwShr, kwString, kwThen, kwThreadvar, kwTo, kwTry, kwType,
    kwUnit, kwUntil, kwUses, kwVar, kwWhile, kwWith, kwXor,

    // Contextual / SoftKeywords / DirectiveKeywords: context-dependent, can be identifiers elsewhere
    (* docwiki:
       Delphi has more than one type of directive.
       One meaning for "directive" is a word that is sensitive in specific locations within source code.
       This type of directive has special meaning in the Delphi language, but, unlike a reserved word,
       appears only in contexts where user-defined identifiers cannot occur.
       Hence -- although it is inadvisable to do so -- you can define an identifier that looks exactly
       like a directive.

       Docwiki Note: the words `at` and `on` also have special meanings, and should be treated as reserved words.
       BUT at and on can be used as identifiers without error, so they are contextual instead of strict keywords
    *)
    // Note: `align` currently not on official list, but should be
    //   https://embt.atlassian.net/servicedesk/customer/portal/1/RSS-5167)
    // Note: inline + library are contextual but already flagged as strict above
    kwAbsolute, kwAbstract, kwAlign, kwAssembler, kwAt, kwCdecl, kwContains, kwDefault,
    kwDelayed, kwDeprecated, kwDispid, kwDynamic, kwExperimental, kwExport,
    kwExternal, kwFar, kwFinal, kwForward, kwHelper, kwImplements, kwIndex,
    kwLocal, kwMessage, kwName, kwNear, kwNodefault, kwNoreturn, kwOn,kwOperator,
    kwOut, kwOverload, kwOverride, kwPackage, kwPascal, kwPlatform, kwRead,
    kwReadonly, kwReference, kwRegister, kwReintroduce, kwRequires, kwResident,
    kwSafecall, kwSealed, kwStatic, kwStdcall, kwStored, kwStrict,
    kwUnsafe, kwVarargs, kwVirtual, kwWinapi, kwWrite, kwWriteonly,

    // Visibility: class-socpe-only visibility specifiers
    // otherwise treated as directives
    kwAutomated, kwPrivate, kwProtected, kwPublic, kwPublished
  );
  //Note: The keyword phrase `of object` (and others) are deferred to handling by parser


  TKeywordInfo = record
    Name: PChar;
    Kind: TKeywordKind;
    Category: TKeywordCategory;
  end;

const

  DELPHI_STRICT_KEYWORD_COUNT = 64;
  DELPHI_DIRECTIVE_KEYWORD_COUNT = 54;
  DELPHI_VISIBILITY_KEYWORD_COUNT = 5;
  //123 keywords
  DELPHI_TOTAL_KEYWORDS = DELPHI_STRICT_KEYWORD_COUNT + DELPHI_DIRECTIVE_KEYWORD_COUNT + DELPHI_VISIBILITY_KEYWORD_COUNT;


  // Sorted alphabetically for binary search
  DELPHI_KEYWORDS: array[0..(DELPHI_TOTAL_KEYWORDS-1)] of TKeywordInfo = (
    (Name: 'absolute';        Kind: kwAbsolute;         Category: kcDirective),
    (Name: 'abstract';        Kind: kwAbstract;         Category: kcDirective),
    (Name: 'align';           Kind: kwAlign;            Category: kcDirective),
    (Name: 'and';             Kind: kwAnd;              Category: kcStrict),
    (Name: 'array';           Kind: kwArray;            Category: kcStrict),
    (Name: 'as';              Kind: kwAs;               Category: kcStrict),
    (Name: 'asm';             Kind: kwAsm;              Category: kcStrict),
    (Name: 'assembler';       Kind: kwAssembler;        Category: kcDirective),
    (Name: 'at';              Kind: kwAt;               Category: kcDirective),
    (Name: 'automated';       Kind: kwAutomated;        Category: kcVisibility),
    (Name: 'begin';           Kind: kwBegin;            Category: kcStrict),
    (Name: 'case';            Kind: kwCase;             Category: kcStrict),
    (Name: 'cdecl';           Kind: kwCdecl;            Category: kcDirective),
    (Name: 'class';           Kind: kwClass;            Category: kcStrict),
    (Name: 'const';           Kind: kwConst;            Category: kcStrict),
    (Name: 'constructor';     Kind: kwConstructor;      Category: kcStrict),
    (Name: 'contains';        Kind: kwContains;         Category: kcDirective),
    (Name: 'default';         Kind: kwDefault;          Category: kcDirective),
    (Name: 'delayed';         Kind: kwDelayed;          Category: kcDirective),
    (Name: 'deprecated';      Kind: kwDeprecated;       Category: kcDirective),
    (Name: 'destructor';      Kind: kwDestructor;       Category: kcStrict),
    (Name: 'dispid';          Kind: kwDispid;           Category: kcDirective),
    (Name: 'dispinterface';   Kind: kwDispinterface;    Category: kcStrict),
    (Name: 'div';             Kind: kwDiv;              Category: kcStrict),
    (Name: 'do';              Kind: kwDo;               Category: kcStrict),
    (Name: 'downto';          Kind: kwDownto;           Category: kcStrict),
    (Name: 'dynamic';         Kind: kwDynamic;          Category: kcDirective),
    (Name: 'else';            Kind: kwElse;             Category: kcStrict),
    (Name: 'end';             Kind: kwEnd;              Category: kcStrict),
    (Name: 'except';          Kind: kwExcept;           Category: kcStrict),
    (Name: 'experimental';    Kind: kwExperimental;     Category: kcDirective),
    (Name: 'export';          Kind: kwExport;           Category: kcDirective),
    (Name: 'exports';         Kind: kwExports;          Category: kcStrict),
    (Name: 'external';        Kind: kwExternal;         Category: kcDirective),
    (Name: 'far';             Kind: kwFar;              Category: kcDirective),
    (Name: 'file';            Kind: kwFile;             Category: kcStrict),
    (Name: 'final';           Kind: kwFinal;            Category: kcDirective),
    (Name: 'finalization';    Kind: kwFinalization;     Category: kcStrict),
    (Name: 'finally';         Kind: kwFinally;          Category: kcStrict),
    (Name: 'for';             Kind: kwFor;              Category: kcStrict),
    (Name: 'forward';         Kind: kwForward;          Category: kcDirective),
    (Name: 'function';        Kind: kwFunction;         Category: kcStrict),
    (Name: 'goto';            Kind: kwGoto;             Category: kcStrict),
    (Name: 'helper';          Kind: kwHelper;           Category: kcDirective),
    (Name: 'if';              Kind: kwIf;               Category: kcStrict),
    (Name: 'implementation';  Kind: kwImplementation;   Category: kcStrict),
    (Name: 'implements';      Kind: kwImplements;       Category: kcDirective),
    (Name: 'in';              Kind: kwIn;               Category: kcStrict),
    (Name: 'index';           Kind: kwIndex;            Category: kcDirective),
    (Name: 'inherited';       Kind: kwInherited;        Category: kcStrict),
    (Name: 'initialization';  Kind: kwInitialization;   Category: kcStrict),
    (Name: 'inline';          Kind: kwInline;           Category: kcStrict),
    (Name: 'interface';       Kind: kwInterface;        Category: kcStrict),
    (Name: 'is';              Kind: kwIs;               Category: kcStrict),
    (Name: 'label';           Kind: kwLabel;            Category: kcStrict),
    (Name: 'library';         Kind: kwLibrary;          Category: kcStrict),
    (Name: 'local';           Kind: kwLocal;            Category: kcDirective),
    (Name: 'message';         Kind: kwMessage;          Category: kcDirective),
    (Name: 'mod';             Kind: kwMod;              Category: kcStrict),
    (Name: 'name';            Kind: kwName;             Category: kcDirective),
    (Name: 'near';            Kind: kwNear;             Category: kcDirective),
    (Name: 'nil';             Kind: kwNil;              Category: kcStrict),
    (Name: 'nodefault';       Kind: kwNodefault;        Category: kcDirective),
    (Name: 'noreturn';        Kind: kwNoreturn;         Category: kcDirective),
    (Name: 'not';             Kind: kwNot;              Category: kcStrict),
    (Name: 'object';          Kind: kwObject;           Category: kcStrict),
    (Name: 'of';              Kind: kwOf;               Category: kcStrict),
    (Name: 'on';              Kind: kwOn;               Category: kcDirective),
    (Name: 'operator';        Kind: kwOperator;         Category: kcDirective),
    (Name: 'or';              Kind: kwOr;               Category: kcStrict),
    (Name: 'out';             Kind: kwOut;              Category: kcDirective),
    (Name: 'overload';        Kind: kwOverload;         Category: kcDirective),
    (Name: 'override';        Kind: kwOverride;         Category: kcDirective),
    (Name: 'package';         Kind: kwPackage;          Category: kcDirective),
    (Name: 'packed';          Kind: kwPacked;           Category: kcStrict),
    (Name: 'pascal';          Kind: kwPascal;           Category: kcDirective),
    (Name: 'platform';        Kind: kwPlatform;         Category: kcDirective),
    (Name: 'private';         Kind: kwPrivate;          Category: kcVisibility),
    (Name: 'procedure';       Kind: kwProcedure;        Category: kcStrict),
    (Name: 'program';         Kind: kwProgram;          Category: kcStrict),
    (Name: 'property';        Kind: kwProperty;         Category: kcStrict),
    (Name: 'protected';       Kind: kwProtected;        Category: kcVisibility),
    (Name: 'public';          Kind: kwPublic;           Category: kcVisibility),
    (Name: 'published';       Kind: kwPublished;        Category: kcVisibility),
    (Name: 'raise';           Kind: kwRaise;            Category: kcStrict),
    (Name: 'read';            Kind: kwRead;             Category: kcDirective),
    (Name: 'readonly';        Kind: kwReadonly;         Category: kcDirective),
    (Name: 'record';          Kind: kwRecord;           Category: kcStrict),
    (Name: 'reference';       Kind: kwReference;        Category: kcDirective),
    (Name: 'register';        Kind: kwRegister;         Category: kcDirective),
    (Name: 'reintroduce';     Kind: kwReintroduce;      Category: kcDirective),
    (Name: 'repeat';          Kind: kwRepeat;           Category: kcStrict),
    (Name: 'requires';        Kind: kwRequires;         Category: kcDirective),
    (Name: 'resident';        Kind: kwResident;         Category: kcDirective),
    (Name: 'resourcestring';  Kind: kwResourcestring;   Category: kcStrict),
    (Name: 'safecall';        Kind: kwSafecall;         Category: kcDirective),
    (Name: 'sealed';          Kind: kwSealed;           Category: kcDirective),
    (Name: 'set';             Kind: kwSet;              Category: kcStrict),
    (Name: 'shl';             Kind: kwShl;              Category: kcStrict),
    (Name: 'shr';             Kind: kwShr;              Category: kcStrict),
    (Name: 'static';          Kind: kwStatic;           Category: kcDirective),
    (Name: 'stdcall';         Kind: kwStdcall;          Category: kcDirective),
    (Name: 'stored';          Kind: kwStored;           Category: kcDirective),
    (Name: 'strict';          Kind: kwStrict;           Category: kcDirective),
    (Name: 'string';          Kind: kwString;           Category: kcStrict),
    (Name: 'then';            Kind: kwThen;             Category: kcStrict),
    (Name: 'threadvar';       Kind: kwThreadvar;        Category: kcStrict),
    (Name: 'to';              Kind: kwTo;               Category: kcStrict),
    (Name: 'try';             Kind: kwTry;              Category: kcStrict),
    (Name: 'type';            Kind: kwType;             Category: kcStrict),
    (Name: 'unit';            Kind: kwUnit;             Category: kcStrict),
    (Name: 'unsafe';          Kind: kwUnsafe;           Category: kcDirective),
    (Name: 'until';           Kind: kwUntil;            Category: kcStrict),
    (Name: 'uses';            Kind: kwUses;             Category: kcStrict),
    (Name: 'var';             Kind: kwVar;              Category: kcStrict),
    (Name: 'varargs';         Kind: kwVarargs;          Category: kcDirective),
    (Name: 'virtual';         Kind: kwVirtual;          Category: kcDirective),
    (Name: 'while';           Kind: kwWhile;            Category: kcStrict),
    (Name: 'winapi';          Kind: kwWinapi;           Category: kcDirective),
    (Name: 'with';            Kind: kwWith;             Category: kcStrict),
    (Name: 'write';           Kind: kwWrite;            Category: kcDirective),
    (Name: 'writeonly';       Kind: kwWriteonly;        Category: kcDirective),
    (Name: 'xor';             Kind: kwXor;              Category: kcStrict)
  );

function FindDelphiKeyword(const S: string; out Info: TKeywordInfo): Boolean;
function IsDelphiKeyword(const S: string): Boolean;


implementation

uses
  System.SysUtils,
  System.Generics.Collections;

var
  _KeywordDict:TDictionary<string, TKeywordInfo>;

procedure BuildKeywordDictionary;
var
  KI:TKeywordInfo;
begin
  _KeywordDict := TDictionary<string, TKeywordInfo>.Create;
  for KI in DELPHI_KEYWORDS do
    _KeywordDict.Add(KI.Name, KI);
end;

function FindDelphiKeyword(const S: string; out Info: TKeywordInfo): Boolean;
begin
  Info := Default(TKeywordInfo);
  Result := _KeywordDict.TryGetValue(S.ToLowerInvariant, Info);
end;


function IsDelphiKeyword(const S: string): Boolean;
var
  Info: TKeywordInfo;
begin
  Result := FindDelphiKeyword(S, Info);
end;


initialization
  BuildKeywordDictionary;

finalization
  _KeywordDict.Free;

end.
