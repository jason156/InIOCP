unit frmInIOCPFileSvrClient;

interface

{$I in_iocp.inc}

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, iocp_base, iocp_clients, iocp_msgPacks, StdCtrls, ExtCtrls, ComCtrls;

type
  TFormInIOCPFileSvrClient = class(TForm)
    Memo1: TMemo;
    InConnection1: TInConnection;
    InCertifyClient1: TInCertifyClient;
    InFileClient1: TInFileClient;
    btnLogin: TButton;
    edtLoginUser: TEdit;
    btnConnect: TButton;
    btnDisconnect: TButton;
    btnLogout: TButton;
    btnUpload: TButton;
    btnDownload: TButton;
    btnQueryFiles: TButton;
    btnSetDir: TButton;
    lblFileName: TLabel;
    lblcancel: TLabel;
    ListView1: TListView;
    BtnCancel: TButton;
    btnRestart: TButton;
    btnClearList: TButton;
    btnUpChunk: TButton;
    btnDownChunk: TButton;
    Button1: TButton;
    Button2: TButton;
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure btnLoginClick(Sender: TObject);
    procedure InCertifyClient1Certify(Sender: TObject; Action: TActionType;
      ActResult: Boolean);
    procedure btnLogoutClick(Sender: TObject);
    procedure btnUploadClick(Sender: TObject);
    procedure InFileClient1ReturnResult(Sender: TObject; Result: TResultParams);
    procedure btnQueryFilesClick(Sender: TObject);
    procedure btnDownloadClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnSetDirClick(Sender: TObject);
    procedure InFileClient1WaitForAnswer(Sender: TObject;
      Result: TResultParams);
    procedure InCertifyClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure InFileClient2ReturnResult(Sender: TObject; Result: TResultParams);
    procedure InConnection1Error(Sender: TObject; const Msg: string);
    procedure InFileClient1ListFiles(Sender: TObject; ActResult: TActionResult;
      No: Integer; Result: TCustomPack);
    procedure InConnection1AddWork(Sender: TObject; Msg: TClientParams);
    procedure ListView1Click(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
    procedure btnRestartClick(Sender: TObject);
    procedure InConnection1DataSend(Sender: TObject; MsgId, MsgSize,
      CurrentSize: Int64);
    procedure InConnection1DataReceive(Sender: TObject; MsgId, MsgSize,
      CurrentSize: Int64);
    procedure btnClearListClick(Sender: TObject);
    procedure btnUpChunkClick(Sender: TObject);
    procedure btnDownChunkClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { Private declarations }
    FToUserName: string;
    FSvrSocket: Cardinal;
    FFileName: String;
    FFromClient: String;
    FMsgId: String;
    FFileList: TStrings;
    procedure ShowProgress(MsgId, MsgSize, CurrentSize: Int64);
  public
    { Public declarations }
  end;

var
  FormInIOCPFileSvrClient: TFormInIOCPFileSvrClient;

implementation

uses
  iocp_utils;
  
{$R *.dfm}

procedure TFormInIOCPFileSvrClient.BtnCancelClick(Sender: TObject);
begin
  // ȡ��ָ����Ϣ��ŵ����񣬱���� 64 λ
  //   ������Ƕϵ����������޷��ָ�������ֻ������ִ��
  //   ����� atFileDownload�����󷢳���Ҳ�޷����Ʒ���˲�����
  //   Ҳ���޷�ȡ����ֻ�жϿ�������
  InConnection1.CancelWork(StrToInt64(FMsgId)); // ����˵��
end;

procedure TFormInIOCPFileSvrClient.btnClearListClick(Sender: TObject);
begin
  Memo1.Lines.Clear;
  ListView1.Items.Clear;
  ListView1Click(Self);
end;

procedure TFormInIOCPFileSvrClient.btnConnectClick(Sender: TObject);
begin
  InConnection1.Active := True;
end;

procedure TFormInIOCPFileSvrClient.btnDisconnectClick(Sender: TObject);
begin
  InConnection1.Active := False;
end;

procedure TFormInIOCPFileSvrClient.btnDownChunkClick(Sender: TObject);
var
  Msg: TMessagePack;
begin
  // TInFileClient û������������ TMessagePack
  Msg := TMessagePack.Create(InFileClient1);
  Msg.FileName := 'winxp20161209.GHO';
//  Msg.CheckType := ctMurmurHash;  // ���Լ�У���룬�ֿ鴫�䲻֧��ѹ����
  Msg.Post(atFileDownChunk);
end;

procedure TFormInIOCPFileSvrClient.btnDownloadClick(Sender: TObject);
begin
  // �����ļ������·��: InConnection1.LocalPath
  InFileClient1.Download('upload_me.exe');
end;

procedure TFormInIOCPFileSvrClient.btnLoginClick(Sender: TObject);
begin
  InCertifyClient1.UserName := edtLoginUser.Text;
  InCertifyClient1.Password := 'pppp';
  InCertifyClient1.Login;
end;

procedure TFormInIOCPFileSvrClient.btnLogoutClick(Sender: TObject);
begin
  InCertifyClient1.Logout;
end;

procedure TFormInIOCPFileSvrClient.btnQueryFilesClick(Sender: TObject);
var
  i: Integer;
  Files: TStrings;
begin
  // ��ѯ����˵�ǰĿ¼���ļ�

  // 1. ������������ InFileClient1ListFiles ��ʾ
  InFileClient1.ListFiles; 

  // 2. ������������ʽ���أ�δʵ�֣�
{  InConnection1.BlockMode := True;

  Files := TStringList.Create;
  InFileClient1.ListFiles(Files);

  for i := 0 to Files.Count - 1 do
    InFileClient1.Download(Files.Strings[i]);

  Files.Free;     }
  
end;

procedure TFormInIOCPFileSvrClient.btnRestartClick(Sender: TObject);
var
  Action: TActionType;
  Item: TListItem;
begin
  // �ϵ��������ָ�����������ȫ�¿�ʼ
  //  TInFileClient û���������������� TMessagePack
  //  �ϵ�����ʱҪʹ��Ψһ�� MsgId�������޸ģ���
  Item := ListView1.Selected;
  Action := TActionType(StrToInt(Item.SubItems[2]));
  case Action of
    atFileUpload:     // ֻ�������ϴ���
      with TMessagePack.Create(InFileClient1) do
      begin
        LoadFromFile(Item.SubItems[0]);
        Post(atFileUpload);
      end;
    atFileUpChunk:    // �����ϴ�
      with TMessagePack.Create(InFileClient1) do
      begin
        MsgId := StrToInt64(Item.SubItems[1]);  // ��֤ MsgId Ψһ����
        LoadFromFile(Item.SubItems[0]);
        Post(atFileUpChunk);
      end;
    atFileDownload:   // ֻ���������أ�
      with TMessagePack.Create(InFileClient1) do
      begin
        FileName := Item.SubItems[0];
        Post(atFileDownload);
      end;
    atFileDownChunk:  // ��������
      with TMessagePack.Create(InFileClient1) do
      begin
        MsgId := StrToInt64(Item.SubItems[1]); // ��֤ MsgId Ψһ����
        FileName := Item.SubItems[0];
        Post(atFileDownChunk);
      end;
    else
      Memo1.Lines.Add('��������, �޷���������.');
  end;
end;

procedure TFormInIOCPFileSvrClient.btnUpChunkClick(Sender: TObject);
var
  Msg: TMessagePack;
begin
  // TInFileClient û������������ TMessagePack
  Msg := TMessagePack.Create(InFileClient1);
  Msg.LoadFromFile('F:\Backup\Ghost\winxp20161209.GHO');
//  Msg.CheckType := ctMurmurHash;  // ���Լ�У���룬�ֿ鴫�䲻֧��ѹ����
  Msg.Post(atFileUpChunk);
end;

procedure TFormInIOCPFileSvrClient.btnUploadClick(Sender: TObject);
begin
  // �ϴ��ļ�������ڷ���˵��û�����·��
  //   �������Ӽ���all_in_one
  InFileClient1.Upload('F:\Backup\Ghost\WIN-7-20140920.GHO');  // upload_me.exe
end;

procedure TFormInIOCPFileSvrClient.Button1Click(Sender: TObject);
var
  Msg: TCustomPack;
begin
{  Msg := TCustomPack.Create;
  Msg.Initialize('test.txt');

  Msg.AsString['aaaa'] := 'aaaaaaaaaaaaaaaaaaaa22';
  Msg.AsInt64['_offset'] := 123546;
  Msg.AsInt64['_offsetHigh'] := 923546;

  Msg.SaveToFile('test.txt'); }  
end;

procedure TFormInIOCPFileSvrClient.Button2Click(Sender: TObject);
begin
  // ��ѯ�ļ��������ļ������б�
  // ������ʱ�ڲ��Զ����浽 FFileList��
  //   ��������� InFileClient1ListFiles �б����ļ����� FFileList
  // �� InFileClient1ReturnResult ����һ���أ�֮���ͷ� FFileList
  FFileList := TStringlist.Create;
  InFileClient1.ListFiles(FFileList);
end;

procedure TFormInIOCPFileSvrClient.btnSetDirClick(Sender: TObject);
begin
  if InFileClient1.Tag = 0 then  // ������Ŀ¼
  begin
    InFileClient1.SetDir('sub'); // ���� sub ��Ŀ¼
    InFileClient1.Tag := 1;
    btnSetDir.Caption := 'cd ..';
  end else
  begin
    InFileClient1.SetDir('..');  // ���ظ�ĸ¼
    InFileClient1.Tag := 0;
    btnSetDir.Caption := 'cd sub';    
  end;
end;

procedure TFormInIOCPFileSvrClient.FormCreate(Sender: TObject);
begin
  iocp_utils.IniDateTimeFormat;        // ��������ʱ���ʽ
  
  // ��������Ϊ upload_me.exe                    
  CopyFile(PChar(Application.ExeName), PChar('upload_me.exe'), False);

  MyCreateDir(InConnection1.LocalPath); // �����ļ����·��
end;

procedure TFormInIOCPFileSvrClient.InCertifyClient1Certify(Sender: TObject;
  Action: TActionType; ActResult: Boolean);
begin
  case Action of
    atUserLogin:       // ��¼
      if ActResult then begin
        Memo1.Lines.Add(InConnection1.UserName + '��¼�ɹ�');
    //    Timer1.Enabled := True;
      end else
        Memo1.Lines.Add(InConnection1.UserName + '��¼ʧ��');
    atUserLogout:      // �ǳ�
      if ActResult then
        Memo1.Lines.Add(InConnection1.UserName + '�ǳ��ɹ�')
      else
        Memo1.Lines.Add(InConnection1.UserName + '�ǳ�ʧ��');
  end;
end;

procedure TFormInIOCPFileSvrClient.InCertifyClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  if Result.AsBoolean['inf'] then   // �������ļ�Ҫ����
  begin
    // �����ж����Ҫ���б�ÿ�ļ��� ";" ��β
    FFromClient := '';
    lblFileName.Caption := Result.Msg; // AsString['msg'];
    lblFileName.Caption := Copy(lblFileName.Caption, 1, Pos(';', lblFileName.Caption) - 1);
    lblFileName.Cursor := crHandPoint;
  end;
end;

procedure TFormInIOCPFileSvrClient.InConnection1AddWork(Sender: TObject; Msg: TClientParams);
  function CheckWorkExists: Boolean;
  var
    i: Integer;
    Item: TListItem;
  begin
    // ����Ӧ����Ϣ MsgId
    for i := 0 to ListView1.Items.Count - 1 do
    begin
      Item := ListView1.Items[i];
      if Item.SubItems[1] = IntToStr(Msg.MsgId) then  // �ҵ���Ӧ���
      begin
        Result := True;
        Exit;
      end;
    end;
    Result := False;
  end;
var
  Item: TListItem;
begin
  // ��������ʱ������ô˹��̣����԰� Msg ��Ϣ�����б���ʾ
  if (Msg.Action in [atFileList..atFileShare]) and not CheckWorkExists then
  begin
    Item := ListView1.Items.Add;
    Item.Caption := IntToStr(Item.Index + 1);

    if Msg.Action in [atFileUpload, atFileUpChunk] then  // �ϴ����ϵ��ϴ�
      Item.SubItems.Add(Msg.AttachFileName)
    else
      Item.SubItems.Add(Msg.FileName);

    Item.SubItems.Add(IntToStr(Msg.MsgId));  // ��Ϣ��
    Item.SubItems.Add(IntToStr(Integer(Msg.Action)));  // ��������
    Item.SubItems.Add('...');  // ִ�н����־
  end;
end;

procedure TFormInIOCPFileSvrClient.InConnection1DataReceive(Sender: TObject;
  MsgId, MsgSize, CurrentSize: Int64);
begin
  // ��������ʾ���ս���
  ShowProgress(MsgId, MsgSize, CurrentSize);
end;

procedure TFormInIOCPFileSvrClient.InConnection1DataSend(Sender: TObject; MsgId,
  MsgSize, CurrentSize: Int64);
begin
  // ��������ʾ�ӷ�������
  ShowProgress(MsgId, MsgSize, CurrentSize);
end;

procedure TFormInIOCPFileSvrClient.InConnection1Error(Sender: TObject;
  const Msg: string);
begin
  memo1.Lines.Add(Msg);
end;

procedure TFormInIOCPFileSvrClient.InFileClient1ListFiles(Sender: TObject;
  ActResult: TActionResult; No: Integer; Result: TCustomPack);
begin
  // ��ѯ�ļ��ķ��ؽ��
  // atFileList, atTextGetFiles ��������ִ�б��¼�,��ִ�� OnReturnResult  
  case ActResult of
    arFail:
      Memo1.Lines.Add('Ŀ¼������.');
    arEmpty:
      Memo1.Lines.Add('Ŀ¼Ϊ��.');
    arExists: begin // �г�����˵�ǰ����·���µ��ļ�
//      if Assigned(FFileList) then  // ������������ -> ���浽�б��Ա�����
//        FFileList.Add(Result.AsString['name']);
      Memo1.Lines.Add(IntToStr(No) + ': ' +
                      Result.AsString['name'] + ', ' +
                      IntToStr(Result.AsInt64['size']) + ', ' +
                      DateTimeToStr(Result.AsDateTime['CreationTime']) + ', ' +
                      DateTimeToStr(Result.AsDateTime['LastWriteTime']) + ', ' +
                      Result.AsString['dir']);
    end;
  end;
end;

procedure TFormInIOCPFileSvrClient.InFileClient1ReturnResult(Sender: TObject; Result: TResultParams);
  procedure MarkListView(Flag: string);
  var
    i: Integer;
    Item: TListItem;
  begin
    // �����ϴ����ؽ������־һ���б�
    for i := 0 to ListView1.Items.Count - 1 do
    begin
      Item := ListView1.Items[i];
      if Item.SubItems[1] = IntToStr(Result.MsgId) then  // �ҵ���Ӧ���
      begin
        Item.SubItems[3] := Flag;
        Break;
      end;
    end;
  end;
  procedure DownloadFiles;
  var
    i: Integer;  
  begin
    // �����б��е��ļ�
    for i := 0 to FFileList.Count - 1 do
      InFileClient1.Download(FFileList.Strings[i]);
  end;
begin
  case Result.Action of
    atFileSetDir:
      case Result.ActResult of
        arOK:
          Memo1.Lines.Add('����Ŀ¼�ɹ�.');
        arMissing:
          Memo1.Lines.Add('Ŀ¼������.');
        arFail:
          Memo1.Lines.Add('Ŀ¼���ƴ���.');
      end;

    atFileDownload, atFileDownChunk:
      case Result.ActResult of    // �ļ�������
        arFail:
          Memo1.Lines.Add('���������򿪵�ǰ·�����ļ�ʧ��.');
        arMissing:
          Memo1.Lines.Add('����������ǰ·�����ļ�������/��ʧ.');
        arOK: begin
          MarkListView('V');
          Memo1.Lines.Add('�����ļ����.');
          lblFileName.Cursor := crDefault;
        end;
      end;
                          
    atFileUpload, atFileUpChunk:
      case Result.ActResult of  // 2.0 ������ arExists �Ľ����
        arFail: begin
          MarkListView('X');
          Memo1.Lines.Add('���������ļ��쳣.');
        end;
        arOK: begin
          MarkListView('V');
          Memo1.Lines.Add('�ϴ��ļ����.');
          lblFileName.Cursor := crDefault;
        end;
      end;
    atFileList:  // ��ѯ�ļ�����һ�����ļ�
      if Assigned(FFileList) then
        try
          DownloadFiles;
        finally
          FreeAndNil(FFileList);
        end;
  end;
end;

procedure TFormInIOCPFileSvrClient.InFileClient1WaitForAnswer(Sender: TObject;
  Result: TResultParams);
begin
  // ���Ǳ������յ�����Ϣ
  //    ���� InFileClient1 ���ڴ������ݣ�Ӧ���� InFileClient2 �ϴ����أ�
  
  // 1. ���������������յ����շ�������Ӧ��
{  case Result.ActResult of
    arOK:       // �Է�ѡ����գ��ӳٴ����ļ����Է�
      InFileClient2.SendOnline(Result.FileName, Result.FromUser);
    arCancel:
      Memo1.Lines.Add('�Է��ܾ�����.');
  end;

  // 2. ���շ�������״̬�����յ��Է���������Ϣ��ѯ���Ƿ�Ҫ�����ļ�
  
  case Result.ActResult of
    arRequest: begin   // 1. �յ�������Ϣ
      // ���������Ϣ
      FSvrSocket := Result.Owner;      // ���ͷ���Ӧ����˵� TIOCPSocket
      FFileName := Result.FileName;
      FFromClient := Result.FromUser;
      lblFileName.Caption := ExtractFileName(FFileName);
      lblFileName.Cursor := crHandPoint;
      lblcancel.Cursor := crHandPoint;
      Memo1.Lines.Add('�Ƿ�����ļ���' + lblFileName.Caption +
                      '? ���ԣ�' + FFromClient);
    end;

    arWakeUp: begin   // 2. �յ�������Ϣ
      FFileName := Result.Msg; // AsString['msg'];   // ֻ��һ���ļ�
      FFileName := Copy(FFileName, 1, Pos(';', FFileName) - 1);
      InFileClient2.DownOnlineFile(FFileName);       // ����һ������
    end;
  end;     }

end;

procedure TFormInIOCPFileSvrClient.InFileClient2ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  if Result.Action = atFileDownload then
    case Result.ActResult of    // �ļ�������
      arMissing:
        Memo1.Lines.Add('�������ļ�������/��ʧ.');
      arOK: begin
        Memo1.Lines.Add('�����ļ����.');
        lblFileName.Cursor := crDefault;
      end;
    end;
end;

procedure TFormInIOCPFileSvrClient.ListView1Click(Sender: TObject);
begin
  BtnCancel.Enabled := ListView1.Selected <> nil;
  BtnRestart.Enabled := BtnCancel.Enabled;
  if ListView1.Selected <> nil  then
    FMsgId := ListView1.Selected.SubItems[1];
end;

procedure TFormInIOCPFileSvrClient.ShowProgress(MsgId, MsgSize, CurrentSize: Int64);
var
  i: Integer;
  Item: TListItem;
begin
  // �����ϴ����ؽ������־һ���б�
  for i := 0 to ListView1.Items.Count - 1 do
  begin
    Item := ListView1.Items[i];
    if Item.SubItems[1] = IntToStr(MsgId) then  // �ҵ���Ӧ���
    begin
      Item.SubItems[3] := Formatfloat('00.00', CurrentSize * 100 / MsgSize) + '%';
      Break;
    end;
  end;
end;

end.
