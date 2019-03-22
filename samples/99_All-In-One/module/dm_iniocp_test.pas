unit dm_iniocp_test;

interface

uses
  // ʹ��ʱ��ӵ�Ԫ���� MidasLib��
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, DB, DBClient, Provider,
  // ADODB �ĸ߰汾�� Data.Win.ADODB
  {$IF CompilerVersion >= 32} Data.Win.ADODB, {$ELSE} ADODB, {$IFEND}
  iocp_baseModule, iocp_base, iocp_objPools, iocp_sockets,
  iocp_sqlMgr, http_base, http_objects, iocp_WsJSON, MidasLib;

type

  // ���ݿ����
  // �� iocp_baseModule.TInIOCPDataModule �̳��½�

  // �������ݿ���¼����԰�����
  //   OnApplyUpdates��OnExecQuery��OnExecSQL��OnExecStoredProcedure
  //   OnHttpExecQuery��OnHttpExecSQL

  TdmInIOCPTest = class(TInIOCPDataModule)
    DataSetProvider1: TDataSetProvider;
    InSQLManager1: TInSQLManager;
    procedure InIOCPDataModuleCreate(Sender: TObject);
    procedure InIOCPDataModuleDestroy(Sender: TObject);
    procedure InIOCPDataModuleApplyUpdates(Params: TReceiveParams;
      out ErrorCount: Integer; AResult: TReturnResult);
    procedure InIOCPDataModuleExecQuery(AParams: TReceiveParams;
      AResult: TReturnResult);
    procedure InIOCPDataModuleExecSQL(AParams: TReceiveParams;
      AResult: TReturnResult);
    procedure InIOCPDataModuleExecStoredProcedure(AParams: TReceiveParams;
      AResult: TReturnResult);
    procedure InIOCPDataModuleHttpExecQuery(Sender: TObject;
      Request: THttpRequest; Respone: THttpRespone);
    procedure InIOCPDataModuleHttpExecSQL(Sender: TObject;
      Request: THttpRequest; Respone: THttpRespone);
    procedure InIOCPDataModuleWebSocketQuery(Sender: TObject; JSON: TBaseJSON;
      Result: TResultJSON);
    procedure InIOCPDataModuleWebSocketUpdates(Sender: TObject; JSON: TBaseJSON;
      Result: TResultJSON);
  private
    { Private declarations }
    FConnection: TADOConnection;
    FQuery: TADOQuery;
    FExecSQL: TADOCommand;
    FCurrentSQLName: String;
    procedure CommitTransaction;
  public
    { Public declarations }
  end;

{ var
    dmInIOCPTest: TdmInIOCPTest; // ע��, ע�ᵽϵͳ���Զ���ʵ�� }

implementation

uses
  iocp_Varis, iocp_utils;

{$R *.dfm}

procedure TdmInIOCPTest.CommitTransaction;
begin
//  GlobalLock.Acquire;   // Ado �������
//  try
    if FConnection.InTransaction then
      FConnection.CommitTrans;
    if not FConnection.InTransaction then
      FConnection.BeginTrans;
{  finally
    GlobalLock.Release;
  end;  }
end;

procedure TdmInIOCPTest.InIOCPDataModuleApplyUpdates(Params: TReceiveParams;
  out ErrorCount: Integer; AResult: TReturnResult);
begin
  // �� DataSetPrivoder.Delta ����

  if not FConnection.InTransaction then
    FConnection.BeginTrans;

  try
    try
      // �°�ı䣺
      //  ��һ���ֶ�Ϊ�û����� _UserName��
      //  �Ժ��ֶ�Ϊ Delta ���ݺ� Int64(DataSetProvider) ֵ���ɶԳ��֣���
      //  Delta �����ж����������ֻ��һ����

      // �ο���TBaseMessage.LoadFromVariant
      //  Params.Fields[0]���û��� _UserName
      //  Params.Fields[1].AsObject����Ӧ Params.Fields[2] �� DataSetProvider
      //  Params.Fields[2].Name���ֶ����ƣ�������
      //  Params.Fields[2].AsVariant��Delta ����

 {     TDataSetProvider(Params.Fields[1].AsObject).ApplyUpdates(
                       Params.Fields[2].AsVariant, 0, ErrorCount);    }

      // ִ�и���ĸ��·���
      InterApplyUpdates(Params, ErrorCount);
    finally
      if ErrorCount = 0 then
      begin
        CommitTransaction;
        AResult.ActResult := arOK;
      end else
      begin
        if FConnection.InTransaction then
          FConnection.RollbackTrans;
        AResult.ActResult := arFail;
        AResult.AsInteger['ErrorCount'] := ErrorCount;
      end;
    end;
  except
    if FConnection.InTransaction then
      FConnection.RollbackTrans;
    Raise;    // �������쳣����Ҫ Raise
  end;
end;

procedure TdmInIOCPTest.InIOCPDataModuleCreate(Sender: TObject);
begin
  inherited;

  // �� InSQLManager1.SQLs װ�� SQL ��Դ�ļ����ı��ļ���
  InSQLManager1.SQLs.LoadFromFile('sql\' + ClassName + '.sql');

  // Ϊ������룬�°汾���� ADO ���� access ���ݿ⣨�ں������������ݱ�
  FConnection := TADOConnection.Create(Self);
  FConnection.LoginPrompt := False;

  // ע�� Access-ODBC������ ODBC ����
  if DirectoryExists('data') then
    RegMSAccessDSN('acc_db', iocp_varis.gAppPath + 'data\acc_db.mdb', 'InIOCP����')
  else  // ����Ϊ����ʱ
    RegMSAccessDSN('acc_db', iocp_varis.gAppPath + '..\00_data\acc_db.mdb', 'InIOCP����');
    
  SetMSAccessDSN(FConnection, 'acc_db');
  
  FQuery := TADOQuery.Create(Self);
  FExecSQL := TADOCommand.Create(Self);

  FQuery.Connection := FConnection;
  FExecSQL.Connection := FConnection;

  // �Զ����� SQL ����
  FQuery.ParamCheck := True;
  FExecSQL.ParamCheck := True;

  DataSetProvider1.DataSet := FQuery;
  FConnection.Connected := True;
end;

procedure TdmInIOCPTest.InIOCPDataModuleDestroy(Sender: TObject);
begin
  inherited;
  FQuery.Free;
  FExecSQL.Free;
  FConnection.Free;
end;

procedure TdmInIOCPTest.InIOCPDataModuleExecQuery(AParams: TReceiveParams;
  AResult: TReturnResult);
var
  SQLName: String;
begin
  // ��ѯ����
  // �������쳣����

  if not FConnection.InTransaction then
    FConnection.BeginTrans;

  // 2.0 Ԥ���� SQL��SQLName ����
  //     ���ҷ��������Ϊ SQLName �� SQL ��䣬ִ��
  //     Ҫ�Ϳͻ��˵��������

  SQLName := AParams.SQLName;
  if (SQLName = '') then  // ���� SQL��δ�ؾ��� SELECT-SQL��
    with FQuery do
    begin
      SQL.Clear;
      SQL.Add(AParams.SQL);
      Active := True;
    end
  else
  if (SQLName <> FCurrentSQLName) then
  begin
    FCurrentSQLName := SQLName;
    with FQuery do
    begin
      SQL.Clear;
      SQL.Add(InSQLManager1.GetSQL(SQLName));
      Active := True;
    end;
  end;

  // �°�Ľ���
  //   ��һ�����ݼ�ת��Ϊ�������ظ��ͻ��ˣ�ִ�н��Ϊ arOK
  // AResult.LoadFromVariant([���ݼ�a, ���ݼ�b, ���ݼ�c], ['���ݱ�a', '���ݱ�b', '���ݱ�c']);
  //   ���ݱ�n �� ���ݼ�n ��Ӧ�����ݱ����ƣ����ڸ���
  // ����ж�����ݼ�����һ��Ϊ����
  
  AResult.LoadFromVariant([DataSetProvider1], ['tbl_xzqh']);
  AResult.ActResult := arOK;

  FQuery.Active := False;   // �ر�
end;

procedure TdmInIOCPTest.InIOCPDataModuleExecSQL(AParams: TReceiveParams;
  AResult: TReturnResult);
var
  SQLName: string;
begin
  // ִ�� SQL
  // �������쳣����
  if not FConnection.InTransaction then
    FConnection.BeginTrans;

  try

    // ȡ SQL
    SQLName := AParams.SQLName;
    if (SQLName = '') then  // �� SQL
      FExecSQL.CommandText := AParams.SQL
    else
    if (SQLName <> FCurrentSQLName) then  // ������
    begin
      FCurrentSQLName := SQLName;
      FExecSQL.CommandText := InSQLManager1.GetSQL(SQLName);
    end;

    if not AParams.HasParams then  // �ͻ����趨��û�в�����
    begin
      FExecSQL.Execute;  // ֱ��ִ��
    end else
      with FExecSQL do
      begin  // ������ֵ
        Parameters.ParamByName('picutre').LoadFromStream(AParams.AsStream['picture'], ftBlob);
        Parameters.ParamByName('code').Value := AParams.AsString['code'];
        Execute;
      end;

    CommitTransaction;
    AResult.ActResult := arOK;  // ִ�гɹ� arOK
  except
    if FConnection.InTransaction then
      FConnection.RollbackTrans;
    Raise;    // �������쳣����Ҫ Raise
  end;
end;

procedure TdmInIOCPTest.InIOCPDataModuleExecStoredProcedure(
  AParams: TReceiveParams; AResult: TReturnResult);
begin
  // ִ�д洢����
  try
    // ���Ǵ洢�������ƣ�
    // ProcedureName := AParams.StoredProcName;
    // ����TInDBQueryClient.ExecStoredProc
    //     TInDBSQLClient.ExecStoredProc

    // �����������ݼ���
    // AResult.LoadFromVariant(DataSetProvider1.Data);

    if AParams.StoredProcName = 'ExecuteStoredProc2' then  // ���Դ洢���̣�����δʵ�֣�
      InIOCPDataModuleExecQuery(AParams, AResult)     // ����һ�����ݼ�
    else
      AResult.ActResult := arOK;
  except
    if FConnection.InTransaction then
      FConnection.RollbackTrans;
    Raise;    // �������쳣����Ҫ Raise
  end;
end;

procedure TdmInIOCPTest.InIOCPDataModuleHttpExecQuery(Sender: TObject;
  Request: THttpRequest; Respone: THttpRespone);
var
  i: Integer;
  SQLName: String;
begin
  // Http ����������ִ�� SQL ��ѯ���� Respone ���ؽ��
  with FQuery do
  try
    try

      // �� SQL ���Ʋ��Ҷ�Ӧ�� SQL �ı�
      // Http �� Request.Params û��Ԥ�� sql, sqlName ����
      SQLName := Request.Params.AsString['SQL'];

      if (FCurrentSQLName <> SQLName) then   // ���Ƹı䣬���� SQL
      begin
        SQL.Clear;
        SQL.Add(InSQLManager1.GetSQL(SQLName));
        FCurrentSQLName := SQLName;
      end;

      // �� Request.ConectionState �� Respone.ConectionState
      // �������״̬�Ƿ�����, �����������ٲ�ѯ����
      if Request.SocketState then  // �ɰ棺ConnectionState
      begin
        // ͨ��һ��ĸ�ֵ������
        // Select xxx from ttt where code=:code and no=:no and datetime=:datetime
        for i := 0 to Parameters.Count - 1 do
          Parameters.Items[i].Value := Request.Params.AsString[Parameters.Items[i].Name];
        Active := True;
      end;

      // ת��ȫ����¼Ϊ JSON���� Respone ����
      //   С���ݼ����ã�
      //      Respone.CharSet := hcsUTF8;  // ָ���ַ���
      //      Respone.SendJSON(iocp_utils.DataSetToJSON(FQuery, Respone.CharSet))
      //   �Ƽ��� Respone.SendJSON(FQuery)���ֿ鷢��
      // ����iocp_utils ��Ԫ DataSetToJSON��LargeDataSetToJSON��InterDataSetToJSON
      if Request.SocketState then
      begin
        Respone.SendJSON(FQuery);  // ��Ĭ���ַ��� gb2312
//        Respone.SendJSON(FQuery, hcsUTF8);  // תΪ UTF-8 �ַ���
      end;

    finally
      Active := False;
    end;
  except
    Raise;
  end;
end;

procedure TdmInIOCPTest.InIOCPDataModuleHttpExecSQL(Sender: TObject;
  Request: THttpRequest; Respone: THttpRespone);
begin
  // Http ����������ִ�� SQL ����� Respone ���ؽ��
end;

procedure TdmInIOCPTest.InIOCPDataModuleWebSocketQuery(Sender: TObject; JSON: TBaseJSON; Result: TResultJSON);
begin
  // ִ�� WebSocket �Ĳ���
  FQuery.SQL.Text := 'SELECT * FROM tbl_xzqh';
  FQuery.Active := True;

  // A. �����ݼ������������͸��ͻ���
  //    �Զ�ѹ�����ͻ����Զ���ѹ
  Result.V['_data'] := DataSetProvider1.Data;
  Result.S['_table'] := 'tbl_xzqh';  
  FQuery.Active := False;  // FQuery Ҫ�رգ����ش��������ݱ���ͻ���

  // ���Լ���������ϸ��
//  Result.V['_detail'] := DataSetProvider2.Data;
//  Result.S['_table2'] := 'tbl_details';

  // B. ����� FireDAC�����԰����ݼ����浽 JSON��
  //    �� Attachment ���ظ��ͻ��ˣ��磺
  // FQuery.SaveToFile('e:\aaa.json', sfJSON);
  // Result.Attachment := TFileStream.Create('e:\aaa.json', fmOpenRead);
  // Result.S['attach'] := 'query.dat';  //��������

  // C. �����·������ز����ֶ�������Ϣ�� JSON ���ͻ��ˣ�
  // Result.DataSet := FQuery;  // ������ϻ��Զ��ر� FQuery
  
end;

procedure TdmInIOCPTest.InIOCPDataModuleWebSocketUpdates(Sender: TObject;
  JSON: TBaseJSON; Result: TResultJSON);
var
  ErrorCount: Integer;
begin
  if not FConnection.InTransaction then
    FConnection.BeginTrans;
  try
    try
      // _delta �ǿͻ��˴������ı������
      DataSetProvider1.ApplyUpdates(JSON.V['_delta'], 0, ErrorCount);
    finally
      if ErrorCount = 0 then
        CommitTransaction
      else
      if FConnection.InTransaction then
        FConnection.RollbackTrans;
    end;
  except
    if FConnection.InTransaction then
      FConnection.RollbackTrans;
    Raise;    // �������쳣����Ҫ Raise
  end;
end;

end.
