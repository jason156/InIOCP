unit frmInIOCPNewFeatures;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, iocp_base, iocp_clients, DB, DBClient, Grids,
  iocp_msgPacks, DBGrids;

type
  TFormInIOCPNewFeatures = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    InConnection1: TInConnection;
    InCertifyClient1: TInCertifyClient;
    InMessageClient1: TInMessageClient;
    InCustomClient1: TInCustomClient;
    InFileClient1: TInFileClient;
    InDBSQLClient1: TInDBSQLClient;
    InDBQueryClient1: TInDBQueryClient;
    InFunctionClient1: TInFunctionClient;
    btnDisconnect: TButton;
    btnLogout: TButton;
    Button4: TButton;
    Edit1: TEdit;
    Button6: TButton;
    ClientDataSet1: TClientDataSet;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    Button8: TButton;
    Button9: TButton;
    Button5: TButton;
    EditServer: TEdit;
    Button7: TButton;
    InDBConnection1: TInDBConnection;
    procedure Button2Click(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure btnLogoutClick(Sender: TObject);
    procedure InCertifyClient1ListClients(Sender: TObject; Count, No: Cardinal;
              const Client: PClientInfo);
    procedure InCertifyClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure Button1Click(Sender: TObject);
    procedure InMessageClient1MsgReceive(Sender: TObject; Socket: UInt64;
      Msg: string);
    procedure InFileClient1ReturnResult(Sender: TObject; Result: TResultParams);
    procedure FormCreate(Sender: TObject);
    procedure InDBSQLClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure Button8Click(Sender: TObject);
    procedure InFunctionClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure Button9Click(Sender: TObject);
    procedure InCertifyClient1Certify(Sender: TObject; Action: TActionType;
      ActResult: Boolean);
    procedure Button4Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure InCustomClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure InConnection1ReceiveMsg(Sender: TObject; Msg: TResultParams);
    procedure InConnection1Error(Sender: TObject; const Msg: string);
    procedure Button5Click(Sender: TObject);
    procedure InFileClient1ListFiles(Sender: TObject; ActResult: TActionResult;
      No: Integer; Result: TCustomPack);
    procedure InMessageClient1ListFiles(Sender: TObject;
      ActResult: TActionResult; No: Integer; Result: TCustomPack);
    procedure Button7Click(Sender: TObject);
    procedure EditServerDblClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormInIOCPNewFeatures: TFormInIOCPNewFeatures;

procedure GetApplicationHandle;

implementation

uses
  TlHelp32, iocp_Varis, iocp_utils;

var
  WinCount: Integer = 0;

procedure GetApplicationHandle;
var
  h:Cardinal;
  pe:PROCESSENTRY32;
  b:Boolean;
begin
  // ȡ�Լ� INIOCPNEWFEATURES.EXE �����д���
  h := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);  //��������
  if h = INVALID_HANDLE_VALUE then //failed
    Exit;

  ZeroMemory(@pe, SizeOf(pe));    //initial

  pe.dwSize := SizeOf(pe);        //important
  b := Process32First(h, pe);

  while b do
  begin
    if Pos('INIOCPNEWFEATURES.EXE', UpperCase(pe.szExeFile)) > 0 then
      Inc(WinCount);
    b := Process32Next(h, pe)
  end;
end;
  
{$R *.dfm}

procedure TFormInIOCPNewFeatures.btnDisconnectClick(Sender: TObject);
begin
  InConnection1.Active := False;
end;

procedure TFormInIOCPNewFeatures.btnLogoutClick(Sender: TObject);
begin
  InCertifyClient1.Logout;
end;

procedure TFormInIOCPNewFeatures.Button1Click(Sender: TObject);
var
  Msg: TMessagePack;
begin
  // ȡ������Ϣ������ InMessageClient1
  Msg := TMessagePack.Create(InMessageClient1);
  Msg.Post(atTextGet);

  // ȡ������Ϣ�ļ������� InMessageClient1
  Msg := TMessagePack.Create(InMessageClient1);
  Msg.Post(atTextGetFiles);

  // ������Ϣ������ InMessageClient1
  Msg := TMessagePack.Create(InMessageClient1);
  Msg.Msg := '����Ϣ��������';
  
  Msg.CheckType := ctMD5;  // +У��
  Msg.Post(atTextSend);

  // ������Ϣ������ĳ�ˣ������� InMessageClient1
  if (Edit1.Text = 'USER_A') then
  begin
    Msg := TMessagePack.Create(InMessageClient1);
    Msg.Msg := '����һ����Ϣ�� ' + 'user_b';
    Msg.ToUser := 'user_b';  // Ŀ�ĵ�
    Msg.Post(atTextPush);
  end;
    
  Msg := TMessagePack.Create(InMessageClient1);
  Msg.Msg := '����һ����Ϣ���Լ�';
  Msg.ToUser := 'user_a';  // Ŀ�ĵ�

  Msg.CheckType := ctMurmurHash;  // +У��  
  Msg.Post(atTextPush);

  // �㲥��Ϣ������ȫ���ˣ������� InMessageClient1
  Msg := TMessagePack.Create(InMessageClient1);
  Msg.Msg := '�㲥һ����Ϣ';
  Msg.Post(atTextBroadcast);

end;

procedure TFormInIOCPNewFeatures.Button2Click(Sender: TObject);
begin
  InConnection1.ServerAddr := EditServer.Text;
  InConnection1.Active := True;
end;

procedure TFormInIOCPNewFeatures.Button3Click(Sender: TObject);
begin
  // ����ĵ�¼
  InCertifyClient1.UserName := Edit1.Text;
  InCertifyClient1.Password := 'pppp';
  InCertifyClient1.Login;
end;

procedure TFormInIOCPNewFeatures.Button4Click(Sender: TObject);
var
  Msg: TMessagePack;
begin
  // ����Ӧ����ȫ����Ϣ�����Դ�������
  // �����ֻ�����ļ����������ĸ����¼���
  // �ڲ������¼��Ĺ�������У������������ո�����
  // InFileManager1.CreateNewFile(Params.Socket);

  // Ҳ��������:
  // if Params.AttachSize > 0 then
  //   Params.CreateAttachment(save_to_path);

  // �ϴ��ļ�
  Msg := TMessagePack.Create(InFileClient1);

  // ���ļ����������ϴ��������÷�����
  //  Msg.FileName := 'DAEMON_Tools_Lite_green.rar'
  // �ڲ��Զ�����ļ��Ƿ�Ҫѹ��
  
  Msg.LoadFromFile('upload_me.exe');

  Msg.CheckType := ctMurmurHash;  // ���Լ�У��
  Msg.Post(atFileUpload);

  // �����ļ�
  Msg := TMessagePack.Create(InFileClient1);
  Msg.FileName := 'upload_me.exe';
  
  Msg.CheckType := ctMD5;  // ���Լ�У��
  Msg.Post(atFileDownload);

  // �г�����˵�ǰ·���µ��ļ�
  Msg := TMessagePack.Create(InFileClient1);
  Msg.Post(atFileList);
  
end;

procedure TFormInIOCPNewFeatures.Button5Click(Sender: TObject);
begin
  // ����Զ�����ݿ�
  InDBQueryClient1.ApplyUpdates();
end;

procedure TFormInIOCPNewFeatures.Button6Click(Sender: TObject);
var
  Msg: TMessagePack;
begin
  // ��ѯ���ݣ�SQL Ҫ�ͷ������ϣ�

  // ִ�з��������Ϊ Select_tbl_xzqh �� SQL ����, ����sql\TdmInIOCPTest.sql
  // ���صĽ���� InDBQueryClient1 �д���

  // ��ʾ��ѯ���ʱҪ�� TInDBQueryClient ��������

  // ���Խ��������˸� 1000 �� http ���ӣ���æʱ�ĵȴ�ʱ�䳤��
  //           �����ﷴ������������û�յ���������ʱ�˳���

  Msg := TMessagePack.Create(InDBQueryClient1);
  Msg.SQLName := 'Select_tbl_xzqh'; // ���ִ�Сд������TInSQLManager.GetSQL
  Msg.Post(atDBExecQuery);

  // �� SQL ���ƣ�ִ��һ�������������
  // ����sql\TdmInIOCPTest.sql
  
  Msg := TMessagePack.Create(InDBSQLClient1);
  Msg.SQLName := 'Update_xzqh'; // ���ִ�Сд
  Msg.HasParams := False;  // û�в���
  Msg.Post(atDBExecSQL);

  // ִ��һ�� Update-SQL
  Msg := TMessagePack.Create(InDBSQLClient1);
  Msg.SQL := 'UPDATE tbl_xzqh SET code = 001 WHERE code IS NULL';
  Msg.HasParams := False;  // û�в���
  Msg.Post(atDBExecSQL);
    
end;

procedure TFormInIOCPNewFeatures.Button7Click(Sender: TObject);
begin
  Memo1.Lines.Clear;
end;

procedure TFormInIOCPNewFeatures.Button8Click(Sender: TObject);
var
  Msg: TMessagePack;
begin
  // ע������ڹ㲥��ͬʱ����������Ϣ������³����쳣��
  //     �ܿ����ǿͻ��˽����������⣬���մ�������������û���ǵ����������

  // Զ�̺���: ִ�з��� TEST_GROUP �ĵ� 1 ������
  Msg := TMessagePack.Create(InFunctionClient1);
  Msg.FunctionGroup := 'TEST_GROUP';
  Msg.FunctionIndex := 1;
  Msg.Post(atCallFunction);

  // �Զ���������ϴ�����
  Msg := TMessagePack.Create(InCustomClient1);

  Msg.Msg := '����������....';
  Msg.AsString['���ı���'] := '��������....';

  // Ҫ�ϴ�����Ҳ�Ǹ������������ InCustomManager1 ����
  //   ϵͳ�������� _stream.strm �ļ����� TBaseMessage.LoadFromStream

  Msg.LoadFromStream(TFileStream.Create('upload_me.exe', 0), True);  // ѹ���ϴ�

  Msg.Post(atCustomAction);  // �Զ������

  // �Զ���������ϴ��ļ���
  Msg := TMessagePack.Create(InCustomClient1);
  Msg.Msg := '��ʼ�ϴ��ļ�....';
  Msg.AsString['���ı���'] := '����....';

  Msg.LoadFromFile('upload_me.exe');
  Msg.Post(atCustomAction);  // �Զ������

end;

procedure TFormInIOCPNewFeatures.Button9Click(Sender: TObject);
var
  Msg: TMessagePack;
begin
  // TMessagePack ������������ TInConnection �������ͻ��������
  // ���صĽ������������ OnReturnResult �д����򲻹���
  // TInConnection �û���ѯ���ļ���ѯ�����¼������龡��ʹ��
  // �����������Action����Ӧ�Ŀͻ��������������

  // Msg ���ύ�󣬻ᱻ���뷢���̣߳���������Զ��ͷţ�

  // TMessagePack �������� InCertifyClient1
  // �� TInCertifyClient ���¼���������Ϣ

  // ��¼
  Msg := TMessagePack.Create(InCertifyClient1);
  Msg.UserName := 'user_a';
  Msg.Password := 'ppp';
  Msg.Post(atUserLogin);

  // ȡ�����û���Ϣ
  Msg := TMessagePack.Create(InCertifyClient1);
  Msg.Post(atUserQuery);

  // ��ѯĳ�û�״̬
  Msg := TMessagePack.Create(InCertifyClient1);
  Msg.ToUser := 'user_b';  // Ŀ���û�
  Msg.Post(atUserState);

end;

procedure TFormInIOCPNewFeatures.EditServerDblClick(Sender: TObject);
begin
  EditServer.Text := '127.0.0.1';
end;

procedure TFormInIOCPNewFeatures.FormCreate(Sender: TObject);
begin
  iocp_utils.IniDateTimeFormat;  // ��������ʱ���ʽ     

  EditServer.Text := '127.0.0.1'; // GetLocalIp;
  Edit1.Text := 'USER_' + AnsiChar(64 + WinCount);  // �û���

  // ׼������·��
  MyCreateDir(ExtractFilePath(Application.ExeName) + InConnection1.LocalPath);    // ��Ŀ¼

  // �����Լ�, �Ȼ��ϴ�
  CopyFile(PChar('InIOCPNewFeatures.exe'), PChar('upload_me.exe'), False);

end;

procedure TFormInIOCPNewFeatures.InCertifyClient1Certify(Sender: TObject;
  Action: TActionType; ActResult: Boolean);
begin
  // �ڴ��жϵ�¼���ǳ����
  case Action of
    atUserLogin: begin   // ��¼
      if ActResult then
        Memo1.Lines.Add(InConnection1.UserName + ': ��¼�ɹ�')
      else
        Memo1.Lines.Add(InConnection1.UserName + ': ��¼ʧ��');
    end;
    atUserLogout: begin  // �ǳ�
      if ActResult then
        Memo1.Lines.Add(InConnection1.UserName + ': �ǳ��ɹ�')
      else
        Memo1.Lines.Add(InConnection1.UserName + ': �ǳ�ʧ��');
    end;
  end;
end;

procedure TFormInIOCPNewFeatures.InCertifyClient1ListClients(Sender: TObject; Count,
  No: Cardinal; const Client: PClientInfo);
begin
  // �ڴ��г���ѯ���Ŀͻ�����Ϣ
  memo1.Lines.Add(IntToStr(No) + '/' + IntToStr(Count) + ', ' +
             Client^.Name + '  ->  ' + IntToStr(Cardinal(Client^.Socket)));

end;

procedure TFormInIOCPNewFeatures.InCertifyClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // ���������ؽ�����û�״̬
  case Result.Action of
    atUserState:  // ��ѯ�û�״̬
      if Result.ActResult = arOnline then
        Memo1.Lines.Add('���ߣ��ѵ�¼��')
      else
        Memo1.Lines.Add('���ߣ�δ��¼��');
  end;
end;

procedure TFormInIOCPNewFeatures.InConnection1Error(Sender: TObject;
  const Msg: string);
begin
  Memo1.Lines.Add('�쳣��' + Msg);
end;

procedure TFormInIOCPNewFeatures.InConnection1ReceiveMsg(Sender: TObject;
  Msg: TResultParams);
begin
  Memo1.Lines.Add('�յ���Ϣ��' + Msg.Msg + ', ����' + Msg.UserName);
end;

procedure TFormInIOCPNewFeatures.InCustomClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  if Result.ActResult = arOK then
    Memo1.Lines.Add('ִ�гɹ�.')
  else
    Memo1.Lines.Add('ִ��ʧ��.' + Result.ErrMsg);
end;

procedure TFormInIOCPNewFeatures.InDBSQLClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  if Result.ActResult = arOK then
    Memo1.Lines.Add('ִ�гɹ�.')
  else
    Memo1.Lines.Add('ִ��ʧ��.' + Result.ErrMsg);
end;

procedure TFormInIOCPNewFeatures.InFileClient1ListFiles(Sender: TObject;
  ActResult: TActionResult; No: Integer; Result: TCustomPack);
begin
  // �г���ǰ����Ŀ¼���ļ�
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

procedure TFormInIOCPNewFeatures.InFileClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  case Result.Action of
    atFileDownload:
      case Result.ActResult of    // �ļ�������
        arMissing:
          Memo1.Lines.Add('�������ļ�������/��ʧ.');
        arOK:
          Memo1.Lines.Add('�����ļ����.');
      end;
    atFileUpload:
      case Result.ActResult of
        arFail:
          Memo1.Lines.Add('����˽��ļ�ʧ��.');
        arOK:
          Memo1.Lines.Add('�ϴ��ļ����.');
      end;
  end;
end;

procedure TFormInIOCPNewFeatures.InFunctionClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  if Result.ActResult = arOK then
    Memo1.Lines.Add('ִ�к����ɹ�.')
  else
    Memo1.Lines.Add('ִ�к���ʧ��.');
end;

procedure TFormInIOCPNewFeatures.InMessageClient1ListFiles(Sender: TObject;
  ActResult: TActionResult; No: Integer; Result: TCustomPack);
begin
  // atGetMsgFiles �ķ��ؽ��
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

procedure TFormInIOCPNewFeatures.InMessageClient1MsgReceive(Sender: TObject; Socket: UInt64;
  Msg: string);
begin
  // ����������Ϣ
  Memo1.Lines.Add('�յ������ͻ�����Ϣ��' + Msg);   // ���� Socket

end;

end.
