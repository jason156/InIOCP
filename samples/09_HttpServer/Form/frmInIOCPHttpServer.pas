unit frmInIOCPHttpServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, iocp_sockets, iocp_managers, iocp_server,
  http_base, http_objects, fmIOCPSvrInfo;

type
  TFormInIOCPHttpServer = class(TForm)
    Memo1: TMemo;
    InIOCPServer1: TInIOCPServer;
    InHttpDataProvider1: TInHttpDataProvider;
    btnStart: TButton;
    btnStop: TButton;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    InDatabaseManager1: TInDatabaseManager;
    procedure FormCreate(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure InHttpDataProvider1Get(Sender: TObject; Request: THttpRequest;
      Respone: THttpRespone);
    procedure InHttpDataProvider1Post(Sender: TObject;
      Request: THttpRequest; Respone: THttpRespone);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure InHttpDataProvider1Accept(Sender: TObject; Request: THttpRequest;
      var Accept: Boolean);
    procedure InHttpDataProvider1InvalidSession(Sender: TObject;
      Request: THttpRequest; Respone: THttpRespone);
    procedure InHttpDataProvider1ReceiveFile(Sender: TObject;
      Request: THttpRequest; const FileName: string; Data: PAnsiChar;
      DataLength: Integer; State: THttpPostState);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InIOCPServer1AfterClose(Sender: TObject);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPHttpServer: TFormInIOCPHttpServer;

implementation

uses
  iocp_log, iocp_utils, iocp_msgPacks, http_utils, dm_iniocp_test;
  
{$R *.dfm}

procedure TFormInIOCPHttpServer.btnStartClick(Sender: TObject);
begin
  Memo1.Lines.Clear;
  iocp_log.TLogThread.InitLog;              // ������־

  // ע����ģ������ InDatabaseManager1
  //   ���ԣ��ò�ͬ˵����ע������ TdmInIOCPTest
  InDatabaseManager1.AddDataModule(TdmInIOCPTest, 'http_dataModule');
  InDatabaseManager1.AddDataModule(TdmInIOCPTest, 'http_dataModule2');

  InIOCPServer1.Active := True;               // ��������
  FrameIOCPSvrInfo1.Start(InIOCPServer1);     // ��ʼͳ��
end;

procedure TFormInIOCPHttpServer.btnStopClick(Sender: TObject);
begin
  InIOCPServer1.Active := False;   // ֹͣ����
  FrameIOCPSvrInfo1.Stop;          // ֹͣͳ��
  iocp_log.TLogThread.StopLog;   // ֹͣ��־
end;

procedure TFormInIOCPHttpServer.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  btnStopClick(nil);
end;

procedure TFormInIOCPHttpServer.FormCreate(Sender: TObject);
var
  WebSite: String;
begin
  // ����·��
  FAppDir := ExtractFilePath(Application.ExeName);
  WebSite := AddBackslash(InHttpDataProvider1.RootDirectory);

  MyCreateDir(FAppDir + 'log');

  MyCreateDir(WebSite + 'downloads');
  MyCreateDir(WebSite + 'uploads');
end;

procedure TFormInIOCPHttpServer.InHttpDataProvider1Accept(Sender: TObject;
  Request: THttpRequest; var Accept: Boolean);
begin
  // �������е�����
  // �ڴ��ж��Ƿ��������:
  //   Request.Method: ����
  //      Request.URI��·��/��Դ
  case Request.Method of
    hmGet:
      Accept := True; // (Request.URI = '/') or (Request.URI = '/a') or (Request.URI = '/t');
    hmPost:
      Accept := True; // (Request.URI = '/') or (Request.URI = '/a') or (Request.URI = '/t');
    else    // ������������
      Accept := True;
  end;
end;

procedure TFormInIOCPHttpServer.InHttpDataProvider1Get(Sender: TObject;
  Request: THttpRequest; Respone: THttpRespone);
var
  Stream: TStream;
  FileName: string;
begin
  // Get: ������������������

  // ϵͳ��ȫ������˹���������¼��У�����Ϊ TObject �� Sender
  // ��������ִ����ʵ����Worker�������е� TBusiWorker(Sender).DataModule
  // ����ģʵ����Ҫ�������ݿ��������������������������ݿ⣬�磺

  //  TBusiWorker(Sender).DataModule.HttpExecSQL(Request, Respone);
  //  TBusiWorker(Sender).DataModule.HttpExecQuery(Request, Respone);
  //  TBusiWorker(Sender).DataModules[1].HttpExecSQL(Request, Respone);
  //  TBusiWorker(Sender).DataModules[1].HttpExecQuery(Request, Respone);

  // �� iocp_utils.DataSetToJSON() �����ݼ�����תΪ JSON��

  // ��ϸ�뿴��ģ���൥Ԫ iocp_datModuleIB.pas��
  // �����ӵ���ģ�� mdTestDatabase.TInIOCPDataModuleTest ��ʵ����

  // 1. �����ļ� ==============================
  // InHttpDataProvider1.RootDirectory ����վ·��

  if Pos('/downloads', Request.URI) > 0 then
  begin
    FileName := FAppDir + Request.URI;
    if Request.URI = '/web_site/downloads/����-A09.txt' then
      Respone.TransmitFile(FileName)          // IE������Զ���ʾ
    else
    if Request.URI = '/web_site/downloads/httptest.exe' then
      Respone.TransmitFile(FileName)
    else
    if Request.URI = '/web_site/downloads/InIOCP����Ҫ��.doc' then
    begin
      Stream := TIOCPDocument.Create(AdjustFileName(FileName));
      Respone.SendStream(Stream);         // �����ļ������Զ��ͷţ�
    end else
    if Request.URI = '/web_site/downloads/InIOCP����Ҫ��2.doc' then
    begin
      FileName := FAppDir + '/web_site/downloads/InIOCP����Ҫ��.doc';
      Stream := TIOCPDocument.Create(AdjustFileName(FileName));
      Respone.SendStream(Stream, True);   // ѹ���ļ������Զ��ͷţ�
    end else
    if Request.URI = '/web_site/downloads/jdk-8u77-windows-i586.exe' then
    begin
      // ���Դ��ļ����أ�֧�ֶϵ�������
      Respone.TransmitFile('F:\Backup\jdk-8u77-windows-i586.exe');
    end else
    if Request.URI = '/web_site/downloads/test.jpg' then
    begin
      Respone.TransmitFile('web_site\downloads\test.jpg');
    end else        
    begin           // ���� chunk���ֿ鷢��
      Stream := TIOCPDocument.Create(AdjustFileName(FileName));
      try
        Respone.SendChunk(Stream);  // ���̷��ͣ����ͷţ��Ľ����ڲ��Զ����ͽ�����־��
      finally
        Stream.Free;
      end;
    end;

  end else

  // 2. ajax ��̬ҳ�� ==============================
  if Pos('/ajax', Request.URI) > 0 then
  begin
    if Request.URI = '/ajax/login' then    // ��¼
      Respone.TransmitFile('web_site\ajax\login.htm')
    else
    if Request.URI = '/ajax/ajax_text.txt' then
    begin
      // AJAX �����ı���IE �������룬chrome����
      if Respone.HasSession then
        Respone.TransmitFile('web_site\ajax\ajax_text.txt')
      else     //   ��ת��������� INVALID_SESSION���ͻ�������Ӧ��� 
        Respone.SetContent(HTTP_INVALID_SESSION);
    end else
    if Request.URI = '/ajax/server_time.pas' then
    begin
      // AJAX ȡ������ʱ��
      if Respone.HasSession then
        Respone.SetContent('<p>������ʱ�䣺' + GetHttpGMTDateTime + '</p>')
      else     //   ��ת��������� INVALID_SESSION���ͻ�������Ӧ���
        Respone.SetContent(HTTP_INVALID_SESSION);
    end else 
    if Request.URI = '/ajax/query_xzqh.pas' then
    begin
      // AJAX ��ѯ���ݱ�������
      // 1. ʹ��Ĭ����ģ��TBusiWorker(Sender).DataModule.HttpExecQuery(Request, Respone)
      // 2. ָ����ģ��TBusiWorker(Sender).DataModules[1].HttpExecQuery(Request, Respone)

      // ���Դ󲢷���ѯ���ݿ�
      //   ʹ�ù��� httpTest.exe��URL �ã�
      //   /ajax/query_xzqh.pas?code=110112&SQL=Select_tbl_xzqh2
      //   ʹ�� Select_tbl_xzqh2 ��Ӧ�� SQL �����ѯ����
      TBusiWorker(Sender).DataModule.HttpExecQuery(Request, Respone);

{     if Respone.HasSession then
        TBusiWorker(Sender).DataModules[1].HttpExecQuery(Request, Respone)
      else
        Respone.SetContent(HTTP_INVALID_SESSION);   }
    end else
    if Request.URI = '/ajax/quit' then     // �˳���¼
    begin
      // ɾ�� Sessions����ȫ�˳�
      //   �ο�ҳ�� ajax.htm �ĺ��� function getExit()���� GET ������״̬�� = 200
      if Respone.HasSession then
        Respone.InvalidSession;
    end;
  end else
  begin

    // 3. ��ͨҳ�� ==============================
    // �������͵ı���POST �Ĳ������벻ͬ�����벻ͬ
    if Request.URI = '/test_a.htm' then   // �ϴ��ļ��������ͣ�multipart/form-data
      Respone.TransmitFile('web_site\html\test_a.htm')
    else
    if Request.URI = '/test_b.htm' then   // �����ͣ�application/x-www-form-urlencoded
      Respone.TransmitFile('web_site\html\test_b.htm')
    else
    if Request.URI = '/test_c.htm' then   // �����ͣ�text/plain
      Respone.TransmitFile('web_site\html\test_c.htm')
    else                              // ��ҳ
    if (Request.URI = '/favicon.ico') then
      Respone.StatusCode := 204       // û�ж���
    else
      Respone.TransmitFile('web_site\html\index.htm');
  end;

end;

procedure TFormInIOCPHttpServer.InHttpDataProvider1InvalidSession(
  Sender: TObject; Request: THttpRequest; Respone: THttpRespone);
begin
  // ����� Session���� Session ��Чʱ���ô��¼�
  if Pos('/ajax', Request.URI) = 1 then
    if (Request.URI = '/ajax/login') then
      Respone.TransmitFile('web_site\ajax\login.htm')
    else
      // ����� ajax �������޷���Ӧ 302 ״̬�������� Redirect
      //   ��ת��������� INVALID_SESSION���ͻ�������Ӧ��飬
      //   Ҳ����ʹ�������������� JSON ���ݡ�
      Respone.SetContent(HTTP_INVALID_SESSION);
end;

procedure TFormInIOCPHttpServer.InHttpDataProvider1Post(Sender: TObject;
  Request: THttpRequest; Respone: THttpRespone);
begin
  // Post���Ѿ�������ϣ����ô��¼�
  //   ��ʱ��Request.Complete = True
  if Request.URI = '/ajax/login' then  // ��̬ҳ��
  begin
    with memo1.Lines do
    begin
      Add('��¼��Ϣ:');
      Add(' userName=' + Request.Params.AsString['user_name']);
      Add(' password=' + Request.Params.AsString['user_password']);
    end;
    if (Request.Params.AsString['user_name'] <> '') and
      (Request.Params.AsString['user_password'] <> '') then   // ��¼�ɹ�
    begin
      Respone.CreateSession;  // ���� Session��
      Respone.TransmitFile('web_site\ajax\ajax.htm');
    end else
      Respone.Redirect('/ajax/login');  // �ض�λ����¼ҳ��
  end else
  begin
    with memo1.Lines do
    begin
      Add('HTTP ����:');
      Add('   textline=' + Request.Params.AsString['textline']);
      Add('  textline2=' + Request.Params.AsString['textline2']);
      Add('    onefile=' + Request.Params.AsString['onefile']);
      Add('  morefiles=' + Request.Params.AsString['morefiles']);
    end;
    Respone.SetContent('<html><body>In-IOCP HTTP ����<br>�ύ�ɹ���<br>');
    Respone.AddContent('<a href="' + Request.URI + '">����</a><br></body></html>');
  end;
end;

procedure TFormInIOCPHttpServer.InHttpDataProvider1ReceiveFile(Sender: TObject;
  Request: THttpRequest; const FileName: string; Data: PAnsiChar;
  DataLength: Integer; State: THttpPostState);
var
  S: String;
begin
  // �������е�����
  // Post: �Ѿ�������ϣ��յ��ϴ����ļ������浽�ļ���
  case State of
    hpsRequest: begin       // ����״̬
      S := ExtractFileName(FileName);
      if not FileExists('web_site\uploads\' + S) then
        THttpSocket(Request.Owner).CreateStream('web_site\uploads\' + S);
    end;
    hpsRecvData: begin     // ���桢�ر��ļ���
      THttpSocket(Request.Owner).WriteStream(Data, DataLength);
      THttpSocket(Request.Owner).CloseStream;
    end;
  end;
end;

procedure TFormInIOCPHttpServer.InIOCPServer1AfterClose(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
end;

procedure TFormInIOCPHttpServer.InIOCPServer1AfterOpen(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
  Memo1.Lines.Add('ip: ' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('port: ' + IntToStr(InIOCPServer1.ServerPort));
end;

end.
