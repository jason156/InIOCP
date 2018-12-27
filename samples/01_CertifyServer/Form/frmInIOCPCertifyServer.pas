unit frmInIOCPCertifyServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, fmIOCPSvrInfo, iocp_base, iocp_clients, iocp_server,
  iocp_managers, iocp_sockets;

type
  TFormInIOCPCertifyServer = class(TForm)
    Memo1: TMemo;
    InIOCPServer1: TInIOCPServer;
    InConnection1: TInConnection;
    btnStart: TButton;
    btnStop: TButton;
    btnConnect: TButton;
    btnDisconnect: TButton;
    btnLogin: TButton;
    InCertifyClient1: TInCertifyClient;
    btnLogout: TButton;
    InClientManager1: TInClientManager;
    InConnection2: TInConnection;
    InCertifyClient2: TInCertifyClient;
    btnConnect2: TButton;
    btnDisconnect2: TButton;
    btnLogin2: TButton;
    btnLogout2: TButton;
    btnQueryClient: TButton;
    btnCheckState: TButton;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure InConnection1Error(Sender: TObject; const Msg: string);
    procedure btnLoginClick(Sender: TObject);
    procedure InCertifyClient1Certify(Sender: TObject; Action: TActionType;
      ActResult: Boolean);
    procedure btnLogoutClick(Sender: TObject);
    procedure InClientManager1Login(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure FormCreate(Sender: TObject);
    procedure InClientManager1Delete(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InClientManager1Logout(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InClientManager1Modify(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InClientManager1Register(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InCertifyClient1ListClients(Sender: TObject; Count, No: Cardinal;
                                          const Client: PClientInfo);
    procedure btnConnect2Click(Sender: TObject);
    procedure btnDisconnect2Click(Sender: TObject);
    procedure btnLogin2Click(Sender: TObject);
    procedure btnLogout2Click(Sender: TObject);
    procedure btnQueryClientClick(Sender: TObject);
    procedure InCertifyClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure btnCheckStateClick(Sender: TObject);
    procedure InClientManager1QueryState(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InConnection1ReceiveMsg(Sender: TObject; Msg: TResultParams);
    procedure InConnection1ReturnResult(Sender: TObject; Result: TResultParams);
    procedure InConnection1AfterConnect(Sender: TObject);
    procedure InIOCPServer1AfterClose(Sender: TObject);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPCertifyServer: TFormInIOCPCertifyServer;

implementation

uses
  iocp_log, iocp_varis, iocp_utils;

{$R *.dfm}

procedure TFormInIOCPCertifyServer.btnCheckStateClick(Sender: TObject);
begin
  // ��ѯ�û� USER_B ��״̬
  InCertifyClient1.GetUserState('USER_B');
end;

procedure TFormInIOCPCertifyServer.btnConnect2Click(Sender: TObject);
begin
  InConnection2.Active := True;
end;

procedure TFormInIOCPCertifyServer.btnConnectClick(Sender: TObject);
begin
  InConnection1.Active := True;
end;

procedure TFormInIOCPCertifyServer.btnDisconnect2Click(Sender: TObject);
begin
  InConnection2.Active := False;
end;

procedure TFormInIOCPCertifyServer.btnDisconnectClick(Sender: TObject);
begin
  InConnection1.Active := False;
end;

procedure TFormInIOCPCertifyServer.btnLogin2Click(Sender: TObject);
begin
  InCertifyClient2.Login;
end;

procedure TFormInIOCPCertifyServer.btnLoginClick(Sender: TObject);
begin
  // ע�⣺һ�� InConnection ��Ӧһ���ͻ��ˣ�
  // �û���USER_TEST��PASS-AAA
  InCertifyClient1.Login; // ��¼���� InCertifyClient1Certify �����ؽ��
end;

procedure TFormInIOCPCertifyServer.btnLogout2Click(Sender: TObject);
begin
  InCertifyClient2.Logout;
end;

procedure TFormInIOCPCertifyServer.btnLogoutClick(Sender: TObject);
begin
  InCertifyClient1.Logout;      // �˳�
end;

procedure TFormInIOCPCertifyServer.btnQueryClientClick(Sender: TObject);
begin
  // ��ѯȫ�����ӵĿͻ��ˣ�����δ��¼��
  //   �� InCertifyClient1ListClients �����ؽ����
  //   ����TInClientManager.GetClients
  InCertifyClient1.QueryClients;
end;

procedure TFormInIOCPCertifyServer.btnStartClick(Sender: TObject);
begin
  // ѹ������ʱ��Ҫ�� InIOCPServer1.PreventAttack���������� Ϊ True
  Memo1.Lines.Clear;
  iocp_log.TLogThread.InitLog;                // ������־
  InIOCPServer1.Active := True;               // ��������
  FrameIOCPSvrInfo1.Start(InIOCPServer1);     // ��ʼͳ��
end;

procedure TFormInIOCPCertifyServer.btnStopClick(Sender: TObject);
begin
  InIOCPServer1.Active := False;   // ֹͣ����
  FrameIOCPSvrInfo1.Stop;          // ֹͣͳ��
  iocp_log.TLogThread.StopLog;     // ֹͣ��־
end;

procedure TFormInIOCPCertifyServer.FormCreate(Sender: TObject);
begin
  // ׼������·��
  FAppDir := ExtractFilePath(Application.ExeName);
  iocp_utils.IniDateTimeFormat;    // ��������ʱ���ʽ

  // �ͻ������ݴ��·����2.0�����ƣ�
  iocp_Varis.gUserDataPath := FAppDir + 'client_data\';

  MyCreateDir(FAppDir + 'log');    // ��Ŀ¼
  MyCreateDir(FAppDir + 'temp');   // ��Ŀ¼

  // �����Ե��û�·��
  MyCreateDir(iocp_Varis.gUserDataPath);  // ��Ŀ¼

  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a\data');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a\msg');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a\temp');

  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b\data');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b\msg');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b\temp');

end;

procedure TFormInIOCPCertifyServer.InCertifyClient1Certify(Sender: TObject;
  Action: TActionType; ActResult: Boolean);
begin
  // �ڴ��жϵ�¼���ǳ����
  // Sender: TInCertifyClient������TInCertifyClient.HandleMsgHead
  case Action of
    atUserLogin: begin      // ��¼
      if ActResult then
        Memo1.Lines.Add(TInCertifyClient(Sender).UserName + ': ��¼�ɹ�')
      else
        Memo1.Lines.Add(TInCertifyClient(Sender).UserName + ': ��¼ʧ��');
    end;
    atUserLogout: begin     // �ǳ�
      if ActResult then
        Memo1.Lines.Add(TInCertifyClient(Sender).UserName + ': �ǳ��ɹ�')
      else
        Memo1.Lines.Add(TInCertifyClient(Sender).UserName + ': �ǳ�ʧ��');
    end;
  end;
end;

procedure TFormInIOCPCertifyServer.InCertifyClient1ListClients(Sender: TObject; Count,
  No: Cardinal; const Client: PClientInfo);
begin
  // �ڴ��г���ѯ���Ŀͻ�����Ϣ
  //  Sender��InCertifyClient
  //   Count������
  //      No: ��ǰ���
  //  Client���ͻ�����Ϣ PClientInfo
  //  ����iocp_base.TClientInfo��TInFileClient.HandleFeedback��
  //      TInBaseClient.ListReturnFiles 
  memo1.Lines.Add(IntToStr(No) + '/' + IntToStr(Count) + ', ' + Client^.Name + '  ->  ' +
             IntToStr(Cardinal(Client^.Socket)) { ����˵� Socket } + ', ' +
             Client^.PeerIPPort + ', ' + DateTimeToStr(Client^.LoginTime) + ', ' +
             DateTimeToStr(Client^.LogoutTime));
end;

procedure TFormInIOCPCertifyServer.InCertifyClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // ���������ؽ��
  // Result �Ƿ���˷��صĽ����
  // Result.Action �ǿͻ��˷������������
  // Result.ActResult �Ƿ���˷��صĽ��ֵ
  case Result.Action of
    atUserState:  // ��ѯ�û�״̬
      if Result.ActResult = arOnline then
        Memo1.Lines.Add(Result.ToUser + ': ���ߣ��ѵ�¼��')
      else
        Memo1.Lines.Add(Result.ToUser + ': ���ߣ�δ��¼��');
  end;
end;

procedure TFormInIOCPCertifyServer.InClientManager1Delete(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �����Ĳ����� Params, �ɸ����Լ�����������޸ģ�
  // Params.UserName �Ƿ���������û�����Params.ToUser �Ǵ�ɾ�����û���
  // ����iocp_clients.TInCertifyClient.Delete  
end;

procedure TFormInIOCPCertifyServer.InClientManager1Login(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �ͻ��˵�¼������ʺ����룡
  //   ���Խ��������� TInDatabaseManager
  if Params.Password <> '' then // ����
  begin
    Result.Msg := '��¼�ɹ�';   // ����һ����Ϣ
    Result.Role := crAdmin;     // ���Թ㲥Ҫ�õ�Ȩ�ޣ�2.0�ģ�
    Result.ActResult := arOK;
    
    // �Ǽ�����, �Զ������û�����·����ע��ʱ����
    InClientManager1.Add(Params.Socket, crAdmin);

    // ��������Ϣ�����������루���ܺ��ļ�������Ϣ��
    // Ҳ�����ڿͻ��˷��� arTextGet ȡ������Ϣ
  //  InMessageManager1.ReadMsgFile(Params, Result);
  end else
  begin
    Result.Msg := '��¼ʧ��';
    Result.ActResult := arFail;  // arErrUser �ǷǷ��û����ᱻ�Ͽ�
  end;
end;

procedure TFormInIOCPCertifyServer.InClientManager1Logout(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �����Ĳ����� Params,
  // Params.UserName �Ƿ���������û���
  // ��: iocp_clients.TInCertifyClient.Logout

  // ���� Result.ActResult Ϊ��ֵ��
  // �ڲ���ִ�� logout������TInClientManager.Execute
end;

procedure TFormInIOCPCertifyServer.InClientManager1Modify(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �����Ĳ����� Params
  // Params.UserName �Ƿ���������û�����Params.ToUser �Ǵ��޸ĵ��û���
  // ����iocp_clients.TInCertifyClient.Modify
end;

procedure TFormInIOCPCertifyServer.InClientManager1QueryState(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �����Ĳ����� Params
  // Params.UserName �Ƿ���������û�����Params.ToUser �Ǵ���ѯ���û�����2.0�ģ�
  // ����iocp_clients.TInCertifyClient.GetUserState

  //  Ҫ�Ȳ�ѯ�û��Ƿ���������ݿ⣡
  Result.ToUser := Params.ToUser;
  if InClientManager1.Logined(Params.ToUser) then
    Result.ActResult := arOnline    // ����
  else
    Result.ActResult := arOffline;  // ����
    
end;

procedure TFormInIOCPCertifyServer.InClientManager1Register(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �����Ĳ����� Params
  // Params.UserName �Ƿ���������û�����Params.ToUser �Ǵ�ע����û�����2.0�ģ�
  // ����iocp_clients.TInCertifyClient.Register

  // ע�����û������ݿ⣨�����������ݿ����ӣ�

  // ������
  //   INSERT INTO xxx (user_name, password, Role) VALUES (
  //     Params.UserName, Params.Password, Integer(Params.Role))��
  // ���ã�
  //   TBusiWorker(Sender).DataModule.ExecSQL(Params, Result);

  // �û�������Ŀ¼Ϊ iocp_varis.gUserDataPath��Ҫ�����½�
  // �û� Params.ToUser ���ļ�Ŀ¼���ٽ�������Ŀ¼��
  //   1. ToUser\Data: �����Ҫ�ļ�
  //   2. ToUser\Msg:  ���������Ϣ�ļ�
  //   3. ToUser\Temp: ��Ż�������ʱ�ļ�
  //  ���������ļ�

{  MyCreateDir(iocp_varis.gUserDataPath + Params.ToUser);
  MyCreateDir(iocp_varis.gUserDataPath + Params.ToUser + '\data');
  MyCreateDir(iocp_varis.gUserDataPath + Params.ToUser + '\msg');
  MyCreateDir(iocp_varis.gUserDataPath + Params.ToUser + '\temp'); }

  Result.ActResult := arOK;

end;

procedure TFormInIOCPCertifyServer.InConnection1AfterConnect(Sender: TObject);
begin
  btnDisconnect.Enabled := True;
end;

procedure TFormInIOCPCertifyServer.InConnection1Error(Sender: TObject; const Msg: string);
begin
  // �����쳣���м����쳣���Զ��Ͽ����ӣ�
  // ����TInConnection.DoServerError��TInConnection.DoThreadFatalError
  Memo1.Lines.Add(Msg);
end;

procedure TFormInIOCPCertifyServer.InConnection1ReceiveMsg(Sender: TObject;  Msg: TResultParams);
begin
  // ���ǽ���������Ϣ���¼�������û��Ϣ����
end;

procedure TFormInIOCPCertifyServer.InConnection1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
{  ������ķ���������Ϣʱ�����ڴ��¼����ؽ��
  Msg := TMessagePack.Create(InConnection1);  // ������ InConnection1
  Msg.Post(arTextSend);  }
end;

procedure TFormInIOCPCertifyServer.InIOCPServer1AfterClose(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
end;

procedure TFormInIOCPCertifyServer.InIOCPServer1AfterOpen(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
  memo1.Lines.Add('IP:' + InIOCPServer1.ServerAddr);
  memo1.Lines.Add('Port:' + IntToStr(InIOCPServer1.ServerPort));
end;

end.
