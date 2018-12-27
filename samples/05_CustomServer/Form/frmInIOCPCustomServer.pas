unit frmInIOCPCustomServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, fmIOCPSvrInfo, iocp_base, iocp_clients, iocp_server,
  iocp_managers, iocp_sockets;

type
  TFormInIOCPCustomServer = class(TForm)
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
    btnCustomSend: TButton;
    btnExecRemFunction: TButton;
    InCustomClient1: TInCustomClient;
    InFunctionClient1: TInFunctionClient;
    InCustomManager1: TInCustomManager;
    InRemoteFunctionGroup1: TInRemoteFunctionGroup;
    InRemoteFunctionGroup2: TInRemoteFunctionGroup;
    InFunctionClient2: TInFunctionClient;
    btnCall2: TButton;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    InFileManager1: TInFileManager;
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
    procedure InClientManager1Logout(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure btnExecRemFunctionClick(Sender: TObject);
    procedure btnCustomSendClick(Sender: TObject);
    procedure InCustomManager1Receive(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InCustomClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure InRemoteFunctionGroup1Execute(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure btnCall2Click(Sender: TObject);
    procedure InFunctionClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure InRemoteFunctionGroup2Execute(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure InFunctionClient2ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure InCustomManager1AttachBegin(Sender: TObject;
      Params: TReceiveParams);
    procedure InCustomManager1AttachFinish(Sender: TObject;
      Params: TReceiveParams);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InIOCPServer1AfterClose(Sender: TObject);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPCustomServer: TFormInIOCPCustomServer;

implementation

uses
  iocp_log, iocp_varis, iocp_utils;

{$R *.dfm}

procedure TFormInIOCPCustomServer.btnCall2Click(Sender: TObject);
begin
  // ����˵� InRemoteFunctionGroup2 Ҫ���� InCustomManager1

  // ִ��Զ�̺����� TEST_GROUP2 ��Ӧ�ĵ�  2 ������
  InFunctionClient2.Call('TEST_GROUP2', 2);
end;

procedure TFormInIOCPCustomServer.btnConnectClick(Sender: TObject);
begin
  InConnection1.Active := True;
end;

procedure TFormInIOCPCustomServer.btnCustomSendClick(Sender: TObject);
begin
  // ����������ǰ����ܷ��࿪����
  //   TInCustomClient �����û��Զ��������
  //  ���Ͳ����Զ��壬����˵Ĳ����Զ���

  with InCustomClient1 do
  begin
    Params.DateTime := Now; // ʱ��
    Params.Msg := 'һ���ı���Ϣ';

    Params.AsBoolean['boolean'] := True;
    Params.AsInteger['integer'] := 9999;
    Params.AsString['string'] := '�ı�����';

    // ����С�ļ������ַ������У�AsStream �ķ�����Ҫ�ͷ�����
  //  Params.AsStream['stream'] := TFileStream.Create('InIOCPС��������׼�.txt', fmOpenRead);
    Params.AsDocument['doc'] := 'doc\jediapilib.inc';

    // �Ӹ��ļ����ͣ�����������֧�ִ��ļ���
    Params.LoadFromFile('doc\jediapilib.inc');
    
    Post;
  end;
end;

procedure TFormInIOCPCustomServer.btnDisconnectClick(Sender: TObject);
begin
  InConnection1.Active := False;
end;

procedure TFormInIOCPCustomServer.btnExecRemFunctionClick(Sender: TObject);
begin
  // ����˵� InRemoteFunctionGroup1 Ҫ���� InCustomManager1

  // ִ��Զ�̺����� TEST_GROUP ��Ӧ�ĵ� 1 ������
  InFunctionClient1.Call('TEST_GROUP', 1);

end;

procedure TFormInIOCPCustomServer.btnLoginClick(Sender: TObject);
begin
  // USER_TEST��PASS-AAA
  // ע�⣺һ�� InConnection ��Ӧһ���ͻ��ˣ�
  InCertifyClient1.Login;         // ��¼���� InCertifyClient1Certify �����ؽ��
end;

procedure TFormInIOCPCustomServer.btnLogoutClick(Sender: TObject);
begin
  InCertifyClient1.Logout;      // �˳�
end;

procedure TFormInIOCPCustomServer.btnStartClick(Sender: TObject);
begin
  Memo1.Lines.Clear;
  iocp_log.TLogThread.InitLog;              // ������־
  iocp_utils.IniDateTimeFormat;               // ����ʱ���ʽ
  InIOCPServer1.Active := True;               // ��������
  FrameIOCPSvrInfo1.Start(InIOCPServer1);     // ��ʼͳ��
end;

procedure TFormInIOCPCustomServer.btnStopClick(Sender: TObject);
begin
  InIOCPServer1.Active := False;   // ֹͣ����
  FrameIOCPSvrInfo1.Stop;          // ֹͣͳ��
  iocp_log.TLogThread.StopLog;   // ֹͣ��־
end;

procedure TFormInIOCPCustomServer.FormCreate(Sender: TObject);
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

procedure TFormInIOCPCustomServer.InCertifyClient1Certify(Sender: TObject;
  Action: TActionType; ActResult: Boolean);
begin
  // �ڴ��жϵ�¼���ǳ����
  case Action of
    atUserLogin:       // ��¼
      if ActResult then
        Memo1.Lines.Add(InConnection1.UserName + ' ��¼�ɹ�')
      else
        Memo1.Lines.Add(InConnection1.UserName + ' ��¼ʧ��');
    atUserLogout:      // �ǳ�
      if ActResult then
        Memo1.Lines.Add(InConnection1.UserName + ' �ǳ��ɹ�')
      else
        Memo1.Lines.Add(InConnection1.UserName + ' �ǳ�ʧ��');
  end;
end;

procedure TFormInIOCPCustomServer.InClientManager1Login(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �ͻ��˵�¼������ʺ����룡
  //   ���Խ��������� TInDatabaseManager
  if Params.password <> '' then // ���� AsString['password']
  begin
    Result.Msg := 'Login OK';   // ����һ����Ϣ
    Result.Role := crAdmin;     // ���Թ㲥Ҫ�õ�Ȩ��
    Result.ActResult := arOK;
    
    // �Ǽ����ԡ������û����ƹ���·��
    InClientManager1.Add(Params.Socket, crAdmin);

    // ��������Ϣʱ���루���ļ�������
  end else
  begin
    Result.Msg := 'Login Fail';
    Result.ActResult := arFail; // ���� arErrUser �ᱻ�ر�
  end;
end;

procedure TFormInIOCPCustomServer.InClientManager1Logout(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �����Ĳ����� Params, �ο� iocp_clients.TInCertifyClient.Logout��
  //   �ɸ����Լ�����������޸ģ�
  // �����Ƿ�������ڲ����˳���logout������TInClientManager.Execute
end;

procedure TFormInIOCPCustomServer.InConnection1Error(Sender: TObject;
  const Msg: string);
begin
  Memo1.Lines.Add(Msg);  // ��ʾ�쳣��ʾ
end;

procedure TFormInIOCPCustomServer.InCustomClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // ��������������

   // ������ʽ����С�ļ���2.0 ���������ã�Ҫ�ͷţ���
  with TMemoryStream(Result.AsStream['doc']) do
    try
      SaveToFile('temp\_���ص�С�ļ�.txt');
    finally
      Free;
    end;

  Memo1.Lines.Add('�ͻ����յ������' + Result.Msg);

end;

procedure TFormInIOCPCustomServer.InCustomManager1AttachBegin(Sender: TObject;
  Params: TReceiveParams);
begin
  // TInCustomManager �����˿�ʼ���ո����ķ���
  // �����Ϣ�������������������ļ���������ʱ Params.Attachment = nil
 
  Memo1.Lines.Add('׼�����ո�����' + Params.FileName);

  // 1. �Ƽ����ļ������������浽�û�����ʱ·��
  InFileManager1.CreateNewFile(Params.Socket, True);

  // 2. Ҳ����ֱ��ָ�����·��
//  Params.CreateAttachment(iocp_varis.gUserDataPath +
//                          Params.UserName + '\temp\');
end;

procedure TFormInIOCPCustomServer.InCustomManager1AttachFinish(Sender: TObject;
  Params: TReceiveParams);
begin
  // TInCustomManager �����˸���������ϵķ���
  //   Params.Attachment���� TIOCPDocument �ļ�����
  //   �ڴ˲�Ҫ Free ������ϵͳ�Զ��ͷţ�
  Memo1.Lines.Add('����������ϣ�' + Params.Attachment.FileName);
end;

procedure TFormInIOCPCustomServer.InCustomManager1Receive(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ���ݲ��������Զ��������� Result ��������

  Memo1.Lines.Add('����ˣ�');
  Memo1.Lines.Add('msg=' + Params.Msg);
  Memo1.Lines.Add('dateTime=' + DateTimeToStr(Params.DateTime));

  Memo1.Lines.Add('boolean=' + BoolToStr(Params.AsBoolean['boolean']));
  Memo1.Lines.Add('integer=' + IntToStr(Params.AsInteger['integer']));
  Memo1.Lines.Add('string=' + Params.AsString['string']);

  // ������ʽ����С�ļ���2.0 ���������ã�Ҫ�ͷţ���
  with TMemoryStream(Params.AsStream['doc']) do
    try
      SaveToFile('temp\�յ�С�ļ�.txt');
    finally
      Free;
    end;

  // ����һ�����ݸ��ͻ���
  Result.Msg := '������ִ�гɹ���';
  Result.AsDocument['doc'] := 'temp\�յ�С�ļ�.txt';   // ����С�ļ�

  // ���԰��ļ������������ظ��ͻ���
  Result.LoadFromFile('doc\jediapilib.inc');
    
  // �ɸ�����Ҫ���� ActResult
  Result.ActResult := arOK;

end;

procedure TFormInIOCPCustomServer.InFunctionClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  case Result.ActResult of
    arOK: begin
      Memo1.Lines.Add('�ͻ��ˣ�aaa=' + Result.AsString['aaa']);
      // ������ʽ����С�ļ�
      with TMemoryStream(Result.AsStream['doc']) do
        try
          SaveToFile('temp\_���÷���С�ļ�.txt');
        finally
          Free;
        end;
    end;
    arMissing:
      Memo1.Lines.Add('�����鲻���ڣ�');
    arFail:
      Memo1.Lines.Add('ִ��Զ�̺���ʧ��');
  end;
end;

procedure TFormInIOCPCustomServer.InFunctionClient2ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  case Result.ActResult of
    arOK:
      Memo1.Lines.Add('�ͻ��ˣ�call2=' + Result.AsString['call2']);
    arMissing:
      Memo1.Lines.Add('�����鲻����');
  end;
end;

procedure TFormInIOCPCustomServer.InIOCPServer1AfterClose(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
end;

procedure TFormInIOCPCustomServer.InIOCPServer1AfterOpen(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
  Memo1.Lines.Add('ip: ' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('port: ' + IntToStr(InIOCPServer1.ServerPort));
end;

procedure TFormInIOCPCustomServer.InRemoteFunctionGroup1Execute(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ִ��Զ�̺�������ĳһ��ŵĹ���
  case Params.FunctionIndex of
    1: begin
      Result.AsString['aaa'] := 'call remote function group 1-1.';
      Result.AsDocument['doc'] := 'doc\jediapilib.inc';  // ����С�ļ�
      Result.ActResult := arOK;    // �������������
    end;
    2: begin
      // ������������
      Result.ActResult := arOK;
    end;
    else
      Result.ActResult := arFail;
  end;
end;

procedure TFormInIOCPCustomServer.InRemoteFunctionGroup2Execute(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ִ��Զ�̺�������ĳһ��ŵĹ���
  case Params.FunctionIndex of
    1: begin
      Result.ActResult := arOK;
    end;
    2: begin
      Result.AsString['call2'] := 'call remote function group 2-2.';
      Result.ActResult := arOK;
    end;
  end;
end;

end.
