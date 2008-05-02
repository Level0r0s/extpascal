unit ExtPascal;

interface

uses
  Classes, FCGIApp;

type
  TExtThread = class(TFCGIThread)
  private
    PJS      : integer;
    Sequence : cardinal;
    JSName   : string;
    JSClass  : TClass;
    procedure SetItems(JS, pName : string; pClass : TClass);
  public
    procedure AddJS(JS : string);
  published
    procedure Home; override;
  end;

  ArrayOfString  = array of string;
  ArrayOfInteger = array of Integer;

  ExtObject = class;
  ArrayOfExtObject = array of ExtObject;
  TExtObjectClass = class of ExtObject;

  ExtObject = class
  protected
    procedure CreateVar(JS : string);
    procedure AddJS(JS : string);
    function VarToJSON(A : array of const) : string; overload;
    function VarToJSON(Exts : ArrayOfExtObject) : string; overload;
    function VarToJSON(Strs : ArrayOfString) : string; overload;
    function VarToJSON(Ints : ArrayOfInteger) : string; overload;
    procedure SetLength(var A : ArrayOfExtObject; ExtObjectClass : TExtObjectClass; NewLength : Integer; Attribute : string = '');
    function IfOtherClass(B : Boolean; DefaultClass, OtherClass : TExtObjectClass) : TExtObjectClass;
    function SetJSName : string;
  public
    JSName : string;
    procedure Init;
    constructor Create(JS : string = '');
    constructor JSFunction(Params, Body : string);
  end;

  HTMLElement = class(ExtObject) end;
  StyleSheet = class(ExtObject) end;
  RegExp = class(ExtObject) end;
  CSSRule = class(ExtObject) end;
  XMLDocument = class(ExtObject) end;
  NodeList = class(ExtObject) end;
  Region = type string;
  NativeMenu = ExtObject;
  el = type string; // doc fault
  Event = class(ExtObject) end;
  HTMLNode = ExtObject;
  _Constructor = class(ExtObject) end;
  _Class = class(ExtObject) end;
  ExtLibRegion = Region; //doc fault
  visMode = Integer; // doc fault
  The = ExtObject; // doc fault
  This = ExtObject; // doc fault
  airNativeMenu = ExtObject;
  X = ExtObject; // doc fault
  N1 = ExtObject; // doc fault
  N2 = ExtObject; // doc fault
  Layout = ExtObject; // Poor hierarchy definition
  Id = ExtObject;// doc fault
  iPageX = ExtObject; // doc fault
  iPageY = ExtObject; // doc fault
  ExtGridGrid = ExtObject; // doc fault
  TreeSelectionModel = ExtObject; // doc fault
  SelectionModel = ExtObject; // doc fault
  DataSource = ExtObject; // doc fault

const
  NoCreate = pointer(1);

procedure SetLength(var Arr; NewLength : Integer; ExtObjectClass: TExtObjectClass = nil);
function Extract(Delims : array of string; S : string; var Matches : TStringList) : boolean; // Mimics preg_match php function
function Explode(Delim : char; S : string) : TStringList; // Mimics explode php function

implementation

uses
  SysUtils, StrUtils;

{ TExtThread }

// Self-translating
procedure TExtThread.AddJS(JS : string);
var
  I : integer;
begin
  I := 1;
  if Response = '' then
    PJS := 0
  else
    if JS[length(JS)] = ';' then begin // Command
      if not(Response[PJS-1] in ['{', ';']) then
        PJS := PosEx('}', Response, PJS + 1)
    end
    else begin // set attribute
      if Response[PJS -1] <> '{' then JS := ',' + JS;
      I := pos('}', JS);
    end;
  insert(JS, Response, PJS);
  PJS := PosEx('}', Response, PJS + I);
end;

procedure TExtThread.Home; begin
  AddJS('<html><title>' + Application.Title + '</title>' +
    '<link rel=stylesheet href=/trabalho/extpascal/ext-all.css />' +
    '<script src=/trabalho/extpascal/ext-base.js></script>' +
    '<script src=/trabalho/extpascal/ext-all.js></script>'  +
    '<script>Ext.onReady(function(){});</script>' +
    '<body><div id=content></div></body></html>');
end;

procedure TExtThread.SetItems(JS, pName: string; pClass: TClass); begin
  JSName  := pName;
  JSClass := pClass;
  AddJS(JS);
end;

{ ExtObject }

procedure ExtObject.AddJS(JS : string); begin
  if JS <> '' then TExtThread(CurrentFCGIThread).AddJS(JS);
end;

constructor ExtObject.Create(JS : string); begin
  AddJS(JS)
end;

procedure ExtObject.CreateVar(JS : string); begin
  AddJS('var ' + SetJSName + '=new ' + JS);
end;

function ExtObject.IfOtherClass(B: Boolean; DefaultClass, OtherClass : TExtObjectClass): TExtObjectClass; begin
  if B then
    Result := DefaultClass
  else
    Result := OtherClass
end;

procedure ExtObject.Init; begin end;

function ExtObject.SetJSName : string; begin
  with TExtThread(CurrentFCGIThread) do begin
    JSName := Self.ClassName + IntToStr(Sequence);
    Result := JSName;
    inc(Sequence)
  end;
end;

constructor ExtObject.JSFunction(Params, Body: string); begin
  JSName := 'function (' + Params + '){' + Body + '}'
end;

procedure ExtObject.SetLength(var A: ArrayOfExtObject; ExtObjectClass: TExtObjectClass; NewLength : Integer; Attribute : string = '');
var
  I, OldLen : integer;
begin
  OldLen := high(A) + 1;
  if ExtObjectClass <> NoCreate then for I := NewLength to high(A) do A[I].Free;
  System.SetLength(A, NewLength);
  if ExtObjectClass <> NoCreate then for I := OldLen to high(A) do A[I] := ExtObjectClass.Create;
  if Attribute <> '' then TExtThread(CurrentFCGIThread).SetItems(Attribute + ':[]', JSName, ClassType);
end;

procedure SetLength(var Arr; NewLength : Integer; ExtObjectClass: TExtObjectClass = nil);
var
  A : ArrayOfExtObject absolute Arr;
  I, OldLen : integer;
begin
  OldLen := high(A) + 1;
  if ExtObjectClass <> nil then for I := NewLength to high(A) do A[I].Free;
  System.SetLength(A, NewLength);
  if ExtObjectClass <> nil then for I := OldLen to high(A) do A[I] := ExtObjectClass.Create;
end;

function ExtObject.VarToJSON(A : array of const): string;
var
  I : integer;
begin
  Result := '';
  for I := 0 to high(A) do begin
    with A[I] do
      case VType of
        vtInteger: Result := Result + IntToStr(VInteger);
        vtAnsiString:
          if string(VAnsiString) <> '' then
            Result := Result + '"' + string(VAnsiString) + '"'
          else
            continue;
        vtObject:
          if VObject <> nil then
            Result := Result + ExtObject(VObject).JSName
          else
            continue;
        vtBoolean: Result := Result + IfThen(VBoolean, 'true', 'false');
        vtString:
          if VString^ <> '' then
            Result := Result + '"' + VString^ + '"'
          else
            continue;
        vtExtended: Result := Result + FloatToStr(VExtended^);
        vtVariant:
          if string(VVariant^) <> '' then
            Result := Result + string(VVariant^)
          else
            continue
      end;
    if I < high(A) then Result := Result + ',';
  end;
end;

function ExtObject.VarToJSON(Exts : ArrayOfExtObject): string;
var
  I : integer;
begin
  Result := '';
  for I := 0 to high(Exts) do begin
    Result := Result + Exts[I].JSName;
    if I < high(Exts) then Result := Result + ',';
  end;
end;

function ExtObject.VarToJSON(Strs : ArrayOfString): string;
var
  I : integer;
begin
  Result := '';
  for I := 0 to high(Strs) do begin
    Result := Result + '"' + Strs[I] + '"';
    if I < high(Strs) then Result := Result + ',';
  end;
end;

function ExtObject.VarToJSON(Ints : ArrayOfInteger): string;
var
  I : integer;
begin
  Result := '';
  for I := 0 to high(Ints) do begin
    Result := Result + IntToStr(Ints[I]);
    if I < high(Ints) then Result := Result + ',';
  end;
end;

// Mimics preg_match php function
function Extract(Delims : array of string; S : string; var Matches : TStringList) : boolean;
var
  I, J : integer;
begin
  Result := false;
  if Matches <> nil then Matches.Clear;
  J := 1;
  for I := 0 to high(Delims) do begin
    J := posex(Delims[I], S, J);
    if J = 0 then
      exit
    else
      inc(J, length(Delims[I]));
  end;
  J := 1;
  for I := 0 to high(Delims)-1 do begin
    J := posex(Delims[I], S, J);
    inc(J, length(Delims[I]));
    Matches.Add(trim(copy(S, J, posex(Delims[I+1], S, J)-J)));
  end;
  Result := true
end;

// Mimics explode php function
function Explode(Delim : char; S : string) : TStringList;
var
  I : integer;
begin
  Result := TStringList.Create;
  Result.StrictDelimiter := true;
  Result.Delimiter := Delim;
  Result.DelimitedText := S;
  for I := 0 to Result.Count-1 do Result[I] := trim(Result[I]);
end;

end.
