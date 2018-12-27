unit dm_iniocp_test;

interface

uses
  // ʹ��ʱ��ӵ�Ԫ���� MidasLib��
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs,
  
  {$IFDEF VER320} Data.Win.ADODB {$ELSE} ADODB {$ENDIF},
  iocp_baseModule, iocp_base, iocp_objPools, iocp_sockets,
  iocp_sqlMgr, http_base, http_objects, iocp_WsJSON, Provider;

type

  // ���ݿ����
  // �� iocp_baseModule.TInIOCPDataModule �̳��½�

  // �������ݿ���¼����԰�����
  //   OnApplyUpdates��OnExecQuery��OnExecSQL��OnExecStoredProcedure
  //   OnHttpExecQuery��OnHttpExecSQL

  TdmInIOCPTest = class(TInIOCPDataModule)
    DataSetProvider1: TDataSetProvider;
    procedure InIOCPDataModuleCreate(Sender: TObject);
    procedure InIOCPDataModuleDestroy(Sender: TObject);
    procedure InIOCPDataModuleWebSocketQuery(Sender: TObject; JSON: TBaseJSON;
      Result: TResultJSON);
    procedure InIOCPDataModuleWebSocketUpdates(Sender: TObject; JSON: TBaseJSON;
      Result: TResultJSON);
  private
    { Private declarations }
    FConnection: TADOConnection;
    FQuery: TADOQuery;
    FExecSQL: TADOCommand;
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

procedure TdmInIOCPTest.InIOCPDataModuleCreate(Sender: TObject);
begin
  inherited;
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

procedure TdmInIOCPTest.InIOCPDataModuleWebSocketQuery(Sender: TObject;
  JSON: TBaseJSON; Result: TResultJSON);
begin
  // ִ�� WebSocket �Ĳ���
  FQuery.SQL.Text := 'SELECT * FROM tbl_xzqh';
  FQuery.Active := True;

  // A. �����ݼ������������͸��ͻ���
  //    �Զ�ѹ�����ͻ����Զ���ѹ
  Result.V['_data'] := DataSetProvider1.Data;
  Result.S['_table'] := 'tbl_xzqh';  // FQuery Ҫ�رգ����ش��������ݱ���ͻ���
  FQuery.Active := False;

  // ���Լ���������ϸ��
//  Result.V['_detail'] := DataSetProvider2.Data;
//  Result.S['_table2'] := 'tbl_details';
  
  // B. ����� FireDAC�����԰����ݼ����浽 JSON��
  //    �� Attachment ���ظ��ͻ��ˣ��磺
  // FQuery.SaveToFile('e:\aaa.json', sfJSON);
  // Result.Attachment := TFileStream.Create('e:\aaa.json', fmOpenRead);
  // Result.S['attach'] := 'query.dat';  //��������

  // C. �����·������ز���������Ϣ�� JSON ���ͻ��ˣ�
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
      begin
        CommitTransaction;
        Result.S['result'] := '���³ɹ�.';
      end else
      begin
        if FConnection.InTransaction then
          FConnection.RollbackTrans;
        Result.S['result'] := '����ʧ��.';
      end;
    end;
  except
    if FConnection.InTransaction then
      FConnection.RollbackTrans;
    Raise;    // �������쳣����Ҫ Raise
  end;
end;

end.
