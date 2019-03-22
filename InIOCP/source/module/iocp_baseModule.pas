unit iocp_baseModule;

interface

uses
  SysUtils, Classes, DB, DBClient, Provider, IniFiles, Variants,
  iocp_base, iocp_sockets, http_objects, iocp_msgPacks, iocp_WsJSON;

type

  // ��ģ����
  // ����ʱ�ӱ���ģ�̳����࣬�������¼������ԣ��в������ݿ⣺
  //   OnApplyUpdates��OnExecQuery��OnExecSQL��OnExecStoredProcedure
  //   OnHttpExecQuery��OnHttpExecSQL

  // ����������ļ��мӵ�Ԫ���ã�MidasLib

  TExecSQLEvent      = procedure(AParams: TReceiveParams; AResult: TReturnResult) of object;
  TApplyUpdatesEvent = procedure(Params: TReceiveParams; out ErrorCount: Integer; AResult: TReturnResult) of object;
  THttpRequestEvent  = procedure(Sender: TObject; Request: THttpRequest; Respone: THttpRespone) of object;
  TWebSocketAction   = procedure(Sender: TObject; JSON: TBaseJSON; Result: TResultJSON) of object;

  TInIOCPDataModule = class(TDataModule)
  private
    { Private declarations }
    FOnApplyUpdates: TApplyUpdatesEvent;   // �� Delta ���ݸ���
    FOnExecQuery: TExecSQLEvent;           // ִ�� SELECT-SQL������һ�����ݼ�
    FOnExecStoredProc: TExecSQLEvent;      // ִ�д洢���̣����ܷ������ݼ�
    FOnExecSQL: TExecSQLEvent;             // ִ�� SQL ����������ݼ�
    FOnHttpExecQuery: THttpRequestEvent;   // ִ�� HTTP ��ѯ
    FOnHttpExecSQL: THttpRequestEvent;     // ִ�� HTTP ����
    FOnWebSocketQuery: TWebSocketAction;   // WebSocket ��ѯ
    FOnWebSocketUpdates: TWebSocketAction; // WebSocket ����
  protected
    // �������ݿ�����
    procedure InstallDatabase(const AClassName); virtual;
    procedure InterApplyUpdates(Params: TReceiveParams; out ErrorCount: Integer);
  public
    { Public declarations }
    procedure ApplyUpdates(AParams: TReceiveParams; AResult: TReturnResult);
    procedure ExecQuery(AParams: TReceiveParams; AResult: TReturnResult);
    procedure ExecSQL(AParams: TReceiveParams; AResult: TReturnResult);
    procedure ExecStoredProcedure(AParams: TReceiveParams; AResult: TReturnResult);
    procedure HttpExecQuery(Request: THttpRequest; Respone: THttpRespone);
    procedure HttpExecSQL(Request: THttpRequest; Respone: THttpRespone);
    procedure WebSocketQuery(JSON: TBaseJSON; Result: TResultJSON);
    procedure WebSocketUpdates(JSON: TBaseJSON; Result: TResultJSON);
  published
    property OnApplyUpdates: TApplyUpdatesEvent read FOnApplyUpdates write FOnApplyUpdates;
    property OnExecQuery: TExecSQLEvent read FOnExecQuery write FOnExecQuery;
    property OnExecSQL: TExecSQLEvent read FOnExecSQL write FOnExecSQL;
    property OnExecStoredProcedure: TExecSQLEvent read FOnExecStoredProc write FOnExecStoredProc;
    property OnHttpExecQuery: THttpRequestEvent read FOnHttpExecQuery write FOnHttpExecQuery;
    property OnHttpExecSQL: THttpRequestEvent read FOnHttpExecSQL write FOnHttpExecSQL;
    property OnWebSocketQuery: TWebSocketAction read FOnWebSocketQuery write FOnWebSocketQuery;
    property OnWebSocketUpdates: TWebSocketAction read FOnWebSocketUpdates write FOnWebSocketUpdates;
  end;

  TDataModuleClass = class of TInIOCPDataModule;
  
implementation
  
{$R *.dfm}

{ TInIOCPDataModule }

procedure TInIOCPDataModule.ApplyUpdates(AParams: TReceiveParams; AResult: TReturnResult);
var
  ErrorCount: Integer;
begin
  if (Self = nil) then
  begin
    AResult.ActResult := arFail;
    AResult.ErrMsg := 'δ����ģʵ��.';
  end else
  if Assigned(FOnApplyUpdates) then
    try
      if (AParams.VarCount > 0) then
        FOnApplyUpdates(AParams, ErrorCount, AResult)
      else begin
        AResult.ActResult := arFail;
        AResult.ErrMsg := 'Delta Ϊ��.';
      end;
    except
      on E: Exception do
      begin
        AResult.ActResult := arFail;
        AResult.ErrMsg := E.Message;
      end;
    end;
end;

procedure TInIOCPDataModule.ExecQuery(AParams: TReceiveParams; AResult: TReturnResult);
begin
  if (Self = nil) then
  begin
    AResult.ActResult := arFail;
    AResult.ErrMsg := 'δ����ģʵ��.';
  end else
  if Assigned(FOnExecQuery) then
    try
      FOnExecQuery(AParams, AResult);
    except
      on E: Exception do
      begin
        AResult.ActResult := arFail;
        AResult.ErrMsg := E.Message;
      end;
    end;
end;

procedure TInIOCPDataModule.ExecSQL(AParams: TReceiveParams; AResult: TReturnResult);
begin
  if (Self = nil) then
  begin
    AResult.ActResult := arFail;
    AResult.ErrMsg := 'δ����ģʵ��.';
  end else
  if Assigned(FOnExecSQL) then
    try
      FOnExecSQL(AParams, AResult);
    except
      on E: Exception do
      begin
        AResult.ActResult := arFail;
        AResult.ErrMsg := E.Message;
      end;
    end;
end;

procedure TInIOCPDataModule.ExecStoredProcedure(AParams: TReceiveParams; AResult: TReturnResult);
begin
  if (Self = nil) then
  begin
    AResult.ActResult := arFail;
    AResult.ErrMsg := 'δ����ģʵ��.';
  end else
  if Assigned(FOnExecStoredProc) then
    try
      FOnExecStoredProc(AParams, AResult);
    except
      on E: Exception do
      begin
        AResult.ActResult := arFail;
        AResult.ErrMsg := E.Message;
      end;
    end;
end;

procedure TInIOCPDataModule.HttpExecQuery(Request: THttpRequest; Respone: THttpRespone);
begin
  if (Self = nil) then        // ���� JSON ��ʽ���쳣
  begin
    Respone.SendJSON('{"Error":"δ����ģʵ��."}');
  end else
  if Assigned(FOnHttpExecQuery) then
    try
      FOnHttpExecQuery(Self, Request, Respone);
    except
      on E: Exception do      // ���� JSON ��ʽ���쳣
        Respone.SendJSON('{"Error":"' + E.Message + '"}');
    end;
end;

procedure TInIOCPDataModule.HttpExecSQL(Request: THttpRequest; Respone: THttpRespone);
begin
  if (Self = nil) then       // ���� JSON ��ʽ���쳣
  begin
    Respone.SendJSON('{"Error":"δ����ģʵ��."}');
  end else
  if Assigned(FOnHttpExecSQL) then
    try
      FOnHttpExecSQL(Self, Request, Respone);
    except
      on E: Exception do     // ���� JSON ��ʽ���쳣
        Respone.SendJSON('{"Error":"' + E.Message + '"}');
    end;
end;

procedure TInIOCPDataModule.InstallDatabase(const AClassName);
begin
  // �����������ģ����ͬһ�����ݿ���������������ʱ�����ݿ�
  // ����� TInIOCPDataModule���ڴ�дͨ�õ��������ݿ����ӷ�����
  // ������ü��ɡ�
{  with TIniFile.Create('db_options.ini') do
  begin
    DatabaseConnection.DatabaseName := ReadString(AClassName, 'DatabaseName', '');
    ... ...
  end; }
end;

procedure TInIOCPDataModule.InterApplyUpdates(Params: TReceiveParams; out ErrorCount: Integer);
var
  i: Integer;
  oDataSetProvider: TDataSetProvider;
  DeltaField: TVarField;
begin
  // �� Delta �������ݱ�
  // �°�ı䣺
  //   ��һ���ֶ�Ϊ�û����� _UserName��
  //   �Ժ��ֶ�Ϊ Delta ���ݺ� Int64(DataSetProvider) ֵ���ɶԳ��֣���
  //   Delta �����ж����������ֻ��һ����
  // ������ DataSetProvider/Variant Ԫ�أ�����Ϊ Null����
  for i := 1 to (Params.VarCount - 1) div 2 do  // ��һ�ֶ�Ϊ�û����� _UserName
  begin
    oDataSetProvider := TDataSetProvider(Params.Fields[i * 2 - 1].AsObject); // 1,3,5
    DeltaField := Params.Fields[i * 2];  // 2,4,6
    if (DeltaField.IsNull = False) then
      oDataSetProvider.ApplyUpdates(DeltaField.AsVariant, 0, ErrorCount);
  end;
end;

procedure TInIOCPDataModule.WebSocketQuery(JSON: TBaseJSON; Result: TResultJSON);
begin
  if (Self = nil) then       // ���� JSON ��ʽ���쳣
  begin
    Result.S['Error'] := 'δ����ģʵ��.';
  end else
  if Assigned(FOnWebSocketQuery) then
    try
      FOnWebSocketQuery(Self, JSON, Result);
    except
      on E: Exception do     // ���� JSON ��ʽ���쳣
        Result.S['Error'] := E.Message;
    end;
end;

procedure TInIOCPDataModule.WebSocketUpdates(JSON: TBaseJSON; Result: TResultJSON);
begin
  if (Self = nil) then
    Result.S['Error'] := 'δ����ģʵ��.'
  else
  if Assigned(FOnWebSocketUpdates) then
    try
      FOnWebSocketUpdates(Self, JSON, Result);
    except
      on E: Exception do     // ���� JSON ��ʽ���쳣
        Result.S['Error'] := E.Message;
    end;
end;

end.
