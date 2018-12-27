unit iocp_reg;

interface

uses           
  Classes, DesignIntf, DesignEditors, ToolIntf, ToolsAPI, EditIntf,
  ExptIntf, iocp_Server, iocp_managers, iocp_clients, iocp_sqlMgr,
  iocp_wsClients, iocp_baseModule;
                               
type

  { TInSQLManager �༭�� }

  TInSQLManagerEditor = class(TComponentEditor)
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

procedure Register;

implementation

uses
  frmInSQLMgrEditor;  // SQL �༭����Ԫ�����趨����·��
  
procedure Register;
begin
  RegisterComponents('InIOCP���������(�����)', [TInIOCPServer, TInIOCPBroker,
                     TInClientManager, TInMessageManager, TInFileManager,
                     TInDatabaseManager, TInCustomManager, TInRemoteFunctionGroup,
                     TInHttpDataProvider, TInWebSocketManager, TInSQLManager]);

  RegisterComponents('InIOCP���������(�ͻ���)', [TInConnection,
                     TInEchoClient, TInCertifyClient, TInMessageClient,
                     TInFileClient, TInCustomClient, TInFunctionClient,
                     TInDBConnection, TInDBQueryClient, TInDBSQLClient,
                     TInWSConnection]);

  RegisterComponentEditor(TInSQLManager, TInSQLManagerEditor);
  RegisterCustomModule(TInIOCPDataModule, TCustomModule);
end;

{ TInSQLManagerEditor }

procedure TInSQLManagerEditor.ExecuteVerb(Index: Integer);
begin
  inherited;
  case Index of
    0:
      if EditInSQLManager(TInSQLManager(Component)) then
        Designer.Modified;
  end;
end;

function TInSQLManagerEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'SQL �༭��(&E)...';
    1: Result := 'SQL �༭��(&E)...';
  end;
end;

function TInSQLManagerEditor.GetVerbCount: Integer;
begin
  Result := 2;
end;

end.

