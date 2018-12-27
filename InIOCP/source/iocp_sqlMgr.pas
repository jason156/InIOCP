(*
 * iocp ����� SQL ����������ѡ��
 *)

unit iocp_sqlMgr;

interface

uses
  Classes, SysUtils,
  iocp_lists;

type

  // һ�� SQL �������

  TSQLObject = class(TObject)
  private
    FSQL: TStrings;     // SQL ����
    FSQLText: String;   // SQL ����(����ʱ)
    FSQLName: String;   // ����
    procedure ToStringEx;
  public
    constructor Create(const AName: String);
    destructor Destroy; override;
    property SQL: TStrings read FSQL;
    property SQLName: String read FSQLName;
  end;

  // һ�� SQL ����Ĺ�����

  TInSQLManager = class(TComponent)
  private
    FNames: TInList;          // SQL �����б�
    FSQLs: TStrings;          // SQL �ı��ļ���Դ

    function GetCount: Integer;
    function GetItems(Index: Integer): TSQLObject;
    procedure ClearNames;
    procedure OnSQLChange(Sender: TObject);
    procedure SetSQLs(const Value: TStrings);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetSQL(Index: Integer): String; overload;
    function GetSQL(const AName: String): String; overload;
  public
    property Items[Index: Integer]: TSQLObject read GetItems;
  published
    property Count: Integer read GetCount;
    property SQLs: TStrings read FSQLs write SetSQLs;
  end;

implementation
  
{ TSQLObject }

constructor TSQLObject.Create(const AName: String);
begin
  inherited Create;
  FSQLName := AName;
  FSQL := TStringList.Create;
end;

destructor TSQLObject.Destroy;
begin
  if Assigned(FSQL) then
    FSQL.Free;
  inherited;
end;

procedure TSQLObject.ToStringEx;
begin
  FSQLText := FSQL.Text;
  FSQL.Clear;  // Ҳ���
end;

{ TInSQLManager }

procedure TInSQLManager.OnSQLChange(Sender: TObject);
var
  i: Integer;
  S: String;
  SQLObj: TSQLObject;
begin
  // FSQLs ���ݸı䣬��ȡ��������
  if (FSQLs.Count = 0) then
    Exit;

  // ��ȡ SQL ����
  // ÿһ Section Ϊһ�����Section Ϊ����

  ClearNames;
  SQLObj := nil;

  for i := 0 to FSQLs.Count - 1 do
  begin
    S := Trim(FSQLs.Strings[i]);
    if (Length(S) >= 3) and (S[1] = '[') and (S[Length(S)] = ']') then  // Section ��ʼ
    begin
      SQLObj := TSQLObject.Create(Copy(S, 2, Length(S) - 2));    // ���ִ�Сд
      FNames.Add(SQLObj);
    end else
    if Assigned(SQLObj) then
    begin
      if (csDestroying in ComponentState) then
        SQLObj.FSQL.Add(S)
      else
      if (Length(S) > 0) and (S[1] <> '/') then
        SQLObj.FSQL.Add(S);
    end;
  end;

  // ����״̬��������תΪ String����� FSQLs
  if not (csDesigning in ComponentState) then
  begin
    for i := 0 to FNames.Count - 1 do
      TSQLObject(FNames.Items[i]).ToStringEx;
    FSQLs.Clear;
  end;
end;

procedure TInSQLManager.ClearNames;
var
  i: Integer;
begin
  // ��� SQL ������
  for i := 0 to FNames.Count - 1 do
    TSQLObject(FNames.Items[i]).Free;
  FNames.Clear;
end;

constructor TInSQLManager.Create(AOwner: TComponent);
begin
  inherited;
  FNames := TInList.Create;
  FSQLs := TStringList.Create;
  TStringList(FSQLs).OnChange := OnSQLChange;
end;

destructor TInSQLManager.Destroy;
begin
  ClearNames;
  FNames.Free;
  FSQLs.Free;
  inherited;
end;

function TInSQLManager.GetCount: Integer;
begin
  Result := FNames.Count;
end;

function TInSQLManager.GetItems(Index: Integer): TSQLObject;
begin
  Result := TSQLObject(FNames.Items[Index]);
end;

function TInSQLManager.GetSQL(Index: Integer): String;
begin
  // ����״̬���ã�
  Result := TSQLObject(FNames.Items[Index]).FSQLText;
end;

function TInSQLManager.GetSQL(const AName: String): String;
var
  i: Integer;
  Obj: TSQLObject;
begin
  // ����״̬���ã�
  for i := 0 to FNames.Count - 1 do
  begin
    Obj := TSQLObject(FNames.Items[i]);
    if (AName = Obj.FSQLName) then  // ���ִ�Сд
    begin
      Result := Obj.FSQLText;
      Exit;
    end;
  end;;
end;

procedure TInSQLManager.SetSQLs(const Value: TStrings);
begin
  ClearNames;
  FSQLs.Clear;
  if Assigned(Value) then
    FSQLs.AddStrings(Value);
end;

end.
