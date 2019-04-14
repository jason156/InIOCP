unit frmInIOCPMessageServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, fmIOCPSvrInfo, iocp_base, iocp_clients, iocp_server,
  iocp_sockets, iocp_managers, iocp_msgPacks, ExtCtrls, Buttons;

type
  TFormInIOCPMessageServer = class(TForm)
    Memo1: TMemo;
    InIOCPServer1: TInIOCPServer;
    InConnection1: TInConnection;
    btnStart: TButton;
    btnStop: TButton;
    btnConnect: TButton;
    btnDisconnect: TButton;
    btnSend: TButton;
    InMessageManager1: TInMessageManager;
    InMessageClient1: TInMessageClient;
    EditTarget: TEdit;
    btnBroad: TButton;
    InClientManager1: TInClientManager;
    InCertifyClient1: TInCertifyClient;
    btnLogin: TButton;
    btnLogout: TButton;
    EditUserName: TEdit;
    edtPort: TEdit;
    lbl1: TLabel;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Bevel1: TBevel;
    Bevel2: TBevel;
    BitBtn1: TBitBtn;
    InFileManager1: TInFileManager;
    BitBtn2: TBitBtn;
    BitBtn3: TBitBtn;
    InCustomManager1: TInCustomManager;
    InCustomClient1: TInCustomClient;
    Button1: TButton;
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure InConnection1Error(Sender: TObject; const Msg: string);
    procedure btnSendClick(Sender: TObject);
    procedure btnBroadClick(Sender: TObject);
    procedure btnLoginClick(Sender: TObject);
    procedure InClientManager1Login(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure FormCreate(Sender: TObject);
    procedure InMessageClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure btnLogoutClick(Sender: TObject);
    procedure InCertifyClient1Certify(Sender: TObject; Action: TActionType;
      ActResult: Boolean);
    procedure InMessageManager1Receive(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure EditUserNameDblClick(Sender: TObject);
    procedure InMessageClient1MsgReceive(Sender: TObject; Socket: UInt64;
      Msg: string);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InMessageManager1Broadcast(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure InMessageManager1Get(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InMessageManager1GetFiles(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InMessageManager1Push(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InConnection1ReceiveMsg(Sender: TObject; Msg: TResultParams);
    procedure InCertifyClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure BitBtn1Click(Sender: TObject);
    procedure InMessageClient1ListFiles(Sender: TObject;
      ActResult: TActionResult; No: Integer; Result: TCustomPack);
    procedure BitBtn2Click(Sender: TObject);
    procedure BitBtn3Click(Sender: TObject);
    procedure InIOCPServer1AfterClose(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure InCustomManager1Receive(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InIOCPServer1Connect(Sender: TObject; Socket: TBaseSocket);
    procedure InIOCPServer1Disconnect(Sender: TObject; Socket: TBaseSocket);
  private
    { Private declarations }
    FAppDir: String;
    FLastMsgId: UInt64;  // ���ؼ�¼�����������Ϣ���
  public
    { Public declarations }
  end;

var
  FormInIOCPMessageServer: TFormInIOCPMessageServer;
  InstanceCount: Integer;

implementation

uses
  iocp_log, iocp_varis, iocp_utils;

{$R *.dfm}

procedure TFormInIOCPMessageServer.BitBtn1Click(Sender: TObject);
begin
  // ȡ������Ϣ���� InMessageClient1.OnReturnResult ����
  InMessageClient1.Get;
end;

procedure TFormInIOCPMessageServer.BitBtn2Click(Sender: TObject);
begin
  // �г��û��ڷ���˵���Ϣ�ļ���
  // �� InMessageClient1.OnListFiles ������
  InMessageClient1.GetMsgFiles;
end;

procedure TFormInIOCPMessageServer.BitBtn3Click(Sender: TObject);
var
  Msg: TMessagePack;
begin
  // ��������ֱ�ӷ�����Ϣ
  Msg := TMessagePack.Create(InMessageClient1); // ����Ϊ InMessageClient1
  Msg.Msg := '��������Ϣ.';
  Msg.Post(atTextSend);                              

  // ������Ϣ
  Msg := TMessagePack.Create(InMessageClient1); // ����Ϊ InMessageClient1
  Msg.Msg := '��������Ϣ+����.';
  Msg.LoadFromFile('doc\jediapilib.inc'); // ˳��Ӹ�����
  Msg.Post(atTextSend);

end;

procedure TFormInIOCPMessageServer.btnBroadClick(Sender: TObject);
begin
  // ����ԱȨ�޲��ܹ㲥
  InMessageClient1.Broadcast('�㲥��Ϣ��... ...');
end;

procedure TFormInIOCPMessageServer.btnConnectClick(Sender: TObject);
begin
  InConnection1.Active := True;
end;

procedure TFormInIOCPMessageServer.btnDisconnectClick(Sender: TObject);
begin
  InConnection1.Active := False;
end;

procedure TFormInIOCPMessageServer.btnLoginClick(Sender: TObject);
begin
  InCertifyClient1.UserName := EditUserName.Text;
  InCertifyClient1.Password := 'AAABBB';
  InCertifyClient1.Login;
end;

procedure TFormInIOCPMessageServer.btnLogoutClick(Sender: TObject);
begin
  InCertifyClient1.Logout;
end;

procedure TFormInIOCPMessageServer.btnSendClick(Sender: TObject);
begin
  // �������б���������໥֮�����Ϣ����
  // ��Ϣ�ķ�����Ϊ InConnection.UserName���ڲ��Զ�����
  // �� InConnection.OnReceiveMsg �д��������յ���Ϣ��������Ϣ��
  if EditTarget.Text <> '' then
    InMessageClient1.SendMsg('���Ƿ��� ' + EditTarget.Text + ' ����Ϣ.', EditTarget.Text)
  else
    InMessageClient1.SendMsg('����Ϣ������ˣ������壩');
end;

procedure TFormInIOCPMessageServer.btnStartClick(Sender: TObject);
begin
  Memo1.Lines.Clear;
  
  iocp_log.TLogThread.InitLog;   // ������־

  InIOCPServer1.ServerPort := StrToInt(edtPort.Text);
  InIOCPServer1.Active := True;  // ��������

  FrameIOCPSvrInfo1.Start(InIOCPServer1);  // ��ʼͳ��

end;

procedure TFormInIOCPMessageServer.btnStopClick(Sender: TObject);
begin
  InIOCPServer1.Active := False; // ֹͣ����
  FrameIOCPSvrInfo1.Stop;        // ֹͣͳ��
  iocp_log.TLogThread.StopLog;   // ֹͣ��־
end;

procedure TFormInIOCPMessageServer.Button1Click(Sender: TObject);
begin
  // �����Զ�����Ϣ�� EditTarget
  //   ��: InCustomManager1Receive��InConnection1ReceiveMsg
  with InCustomClient1 do
  begin
    Params.ToUser := EditTarget.Text; // Ŀ��
    Params.AsString['xxxx'] := '�����Զ�����Ϣ, aaaa 1234667890, bbb';
    Post;
  end;
end;

procedure TFormInIOCPMessageServer.EditUserNameDblClick(Sender: TObject);
begin
  EditUserName.Text := 'USER_b';
end;

procedure TFormInIOCPMessageServer.FormCreate(Sender: TObject);
begin
  if InstanceCount = 1 then
  begin
    EditUserName.Text := 'user_b';
    EditTarget.Text := 'user_a';
    btnStart.Enabled := False;
    btnStop.Enabled := False;
  end;

  FLastMsgId := 0;

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

procedure TFormInIOCPMessageServer.InCertifyClient1Certify(Sender: TObject;
  Action: TActionType; ActResult: Boolean);
begin
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

procedure TFormInIOCPMessageServer.InCertifyClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
var
  i, k: Integer;
  Msg: TReceivePack;  // ������Ϣ��
  Reader: TMessageReader;  // ������Ϣ�Ķ���
begin
  // ��¼ʱ���������������������Ϣ�������ﴦ��
  if Assigned(Result.Attachment) then // �и�����������������Ϣ��������
  begin
    Memo1.Lines.Add('��������Ϣ.');
    Msg := TReceivePack.Create;
    Reader := TMessageReader.Create;
    try
      // Attachment �Ѿ��رգ���δ�ͷ�
      // ���ļ������������Ϣ�ļ� -> Count = 0
      Reader.Open(Result.Attachment.FileName);

      // �����ǰ��������� MsgId ���浽���̣�
      // ��¼ǰ���벢���� LastMsgId = ???��������
      // ��Ϣ�ļ��ж����� LastMsgId �����Ϣ��

      for i := 0 to Reader.Count - 1 do
      begin
        if Reader.Extract(Msg, FLastMsgId) then  // ������ LastMsgId �����Ϣ
          for k := 0 to Msg.Count - 1 do
            with Msg.Fields[k] do
              Memo1.Lines.Add(Name + '=' + AsString);
      end;

      // ����������Ϣ��
      if Msg.Action <> atUnknown then
        FLastMsgId := Msg.MsgId;

    finally
      Msg.Free;
      Reader.Free;
    end;
  end;
end;

procedure TFormInIOCPMessageServer.InClientManager1Login(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �ͻ��˵�¼������ʺ����룡
  //   ���Խ��������� TInDatabaseManager

  // ����Ԥ���� user_a��user_b �����û�������Ŀ¼
  // �������û���ʱ��Ҫ����Ӧ������Ŀ¼

  if Params.Password <> '' then // ����
  begin
    Result.Msg := '��¼�ɹ�';   // ����һ����Ϣ
    Result.Role := crAdmin;     // ���Թ㲥Ҫ�õ�Ȩ�ޣ�2.0�ģ�
    Result.ActResult := arOK;
    
    // �Ǽ�����, �Զ������û�����·����ע��ʱ����
    InClientManager1.Add(Params.Socket, crAdmin);

    // ��������Ϣ�����������루���ܺ��ļ�������Ϣ��
    // Ҳ�����ڿͻ��˷��� arTextGet ȡ������Ϣ
    InMessageManager1.ReadMsgFile(Params, Result);
  end else
  begin
    Result.Msg := '��¼ʧ��';
    Result.ActResult := arFail;  // arErrUser �ǷǷ��û����ᱻ�Ͽ�
  end;
end;

procedure TFormInIOCPMessageServer.InConnection1Error(Sender: TObject;
  const Msg: string);
begin
  // ���ط�������ͻ��˵ĸ����쳣��
  // ����TInConnection.DoServerError��TInConnection.DoThreadFatalError
  Memo1.Lines.Add(Msg);
end;

procedure TFormInIOCPMessageServer.InConnection1ReceiveMsg(Sender: TObject;
  Msg: TResultParams);
begin
  // �����ﴦ���յ���������Ϣ������������Ϣ��
  case Msg.Action of
    atTextPush, atTextBroadcast:
      { Memo1.Lines.Add('�յ�������Ϣ��' + Msg.Msg + ', ���ԣ�' + Msg.UserName) } ;
    atCustomAction:  // �Զ�����Ϣ
      Memo1.Lines.Add(Msg.AsString['xxxx']);
  end;
end;

procedure TFormInIOCPMessageServer.InCustomManager1Receive(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
var
  oSocket: TIOCPSocket;
begin
  // �յ��Զ�����Ϣ
  if InClientManager1.Logined(Params.ToUser, oSocket) then
  begin
    InMessageManager1.PushMsg(Params, oSocket); // = Params.Socket.Push(oSocket);
    Result.ActResult := arOK; // Ͷ�ų�ȥ�ˣ�����֪�����
  end else
    Result.ActResult := arOffline;   // �Է�����
end;

procedure TFormInIOCPMessageServer.InIOCPServer1AfterClose(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
end;

procedure TFormInIOCPMessageServer.InIOCPServer1AfterOpen(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
  memo1.Lines.Add('IP:' + InIOCPServer1.ServerAddr);
  memo1.Lines.Add('Port:' + IntToStr(InIOCPServer1.ServerPort));
end;

procedure TFormInIOCPMessageServer.InIOCPServer1Connect(Sender: TObject;
  Socket: TBaseSocket);
begin
  // ʹ�� Data ���ԣ���չһ�¹���
  // ���ֹ�������ֱ�� Socket.Close;
{  Socket.Data := TInMemStream.Create;   }
end;

procedure TFormInIOCPMessageServer.InIOCPServer1Disconnect(Sender: TObject;
  Socket: TBaseSocket);
begin
  // Ҫ�ж��ͷ� Data ������
  // ϵͳĬ�ϵĿͻ��˶����� THttpSocket��
  // Socket ��Դת��Ϊ��ӦЭ��� TBaseSocket �󣬻�ر� Socket��
  // ��ʱҪ�ж�һ�£���� Socket.Connected = False ������Դת����� Socket�����ô���
{  if Socket.Connected and Assigned(Socket.Data) then
    TInMemStream(Socket.Data).Free;   }
end;

procedure TFormInIOCPMessageServer.InMessageClient1ListFiles(Sender: TObject;
  ActResult: TActionResult; No: Integer; Result: TCustomPack);
begin
  // atFileList, atTextGetFiles ��������ִ�б��¼�,��ִ�� OnReturnResult
  case ActResult of
    arFail:
      Memo1.Lines.Add('Ŀ¼������.');
    arEmpty:
      Memo1.Lines.Add('Ŀ¼Ϊ��.');
    arExists:  // �г�����˵�ǰ����·���µ��ļ�
      Memo1.Lines.Add(IntToStr(No) + ': ' +
                      Result.AsString['name'] + ', ' +
                      IntToStr(Result.AsInt64['size']) + ', ' +
                      DateTimeToStr(Result.AsDateTime['CreationTime']) + ', ' +
                      DateTimeToStr(Result.AsDateTime['LastWriteTime']) + ', ' +
                      Result.AsString['dir']);
  end;
end;

procedure TFormInIOCPMessageServer.InMessageClient1MsgReceive(Sender: TObject;
  Socket: UInt64; Msg: string);
begin
  // �յ������ͻ���������Ϣ�������ģ�
  Memo1.Lines.Add(InConnection1.UserName + ' �յ� ' + IntToStr(Socket) + ' ����Ϣ��' + Msg);
end;

procedure TFormInIOCPMessageServer.InMessageClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // �����������¼�
  // atFileList ��������ִ�� OnListFiles,��ִ�б��¼�    
  case Result.ActResult of
    arOK:
      Memo1.Lines.Add('��Ϣ���ͳɹ�.' + Result.Msg);
    arOffline:
      Memo1.Lines.Add('�������Է�����.');
  end;

  // ������������Ϣ
  InCertifyClient1ReturnResult(Sender, Result);
end;

procedure TFormInIOCPMessageServer.InMessageManager1Broadcast(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �㲥��������Ϣ��ȫ���ͻ���
  //       ����Ϣд��ȫ���ͻ��˵ķ��㲻���У����ﲻ����
//  Memo1.Lines.Add(Params.Msg);
  // �㲥�����пͻ��ˣ�����δ��¼�����յ�
  InMessageManager1.Broadcast(Params);
end;

procedure TFormInIOCPMessageServer.InMessageManager1Get(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ȡ������Ϣ���ͻ��˷��� arTextGet ����
  InMessageManager1.ReadMsgFile(Params, Result);  // δ����������Ϣ
  Result.Msg := '����������Ϣ��';
  Result.ActResult := arOK;
end;

procedure TFormInIOCPMessageServer.InMessageManager1GetFiles(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ������Ϣ��СΪ 2m������ʱ�ļ������������������ļ��������г�,
  // ����InternalOpenMsgFile
  // ���ļ�������ȡ��Ϣ���ͻ��˻�������Ϣ����� OnListFiles ��ʾ
  InFileManager1.ListFiles(Params.Socket, True);
end;

procedure TFormInIOCPMessageServer.InMessageManager1Push(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
var
  oSocket: TIOCPSocket;
begin
  // ������Ϣ�������ͻ���: ToUser��TargetUser

  // �õ�������������ʱ������ JSON ��ʽ����Ϣ
//  mmoServer.Lines.Add(Params.ToJSON);

  // �ȱ��浽��Ϣ�ļ�
  InMessageManager1.SaveMsgFile(Params);

  if InClientManager1.Logined(Params.ToUser, oSocket) then
  begin
    InMessageManager1.PushMsg(Params, oSocket); // = Params.Socket.Push(oSocket);
    Result.ActResult := arOK; // Ͷ�ų�ȥ�ˣ�����֪�����
  end else
    Result.ActResult := arOffline;   // �Է�����

end;

procedure TFormInIOCPMessageServer.InMessageManager1Receive(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �������ʱ����ʾ
  Memo1.Lines.Add('�������յ���Ϣ��' + Params.Msg); //

  // ��һ���ļ������������ظ��ͻ��ˣ��ͻ��˴��·��:
  //   InConnection1.LocalPath
  Result.LoadFromFile('doc\jediapilib.inc');

  Result.ActResult := arOK;

  // ��Ϣ������û�������ո����ķ��������������ַ������ո�����

  // 1. �Ƽ����ļ�������
  if (Params.AttachSize > 0) then
    InFileManager1.CreateNewFile(Params.Socket); // ���浽�û�������·��
//  InFileManager1.CreateNewFile(Params.Socket, True); // ���浽�û�����ʱ·��

  // 2. Ҳ����ֱ��ָ�����·��
{  if (Params.AttachSize > 0) then
    Params.CreateAttachment(iocp_varis.gUserDataPath +
                          Params.UserName + '\temp\');    }

end;

end.
