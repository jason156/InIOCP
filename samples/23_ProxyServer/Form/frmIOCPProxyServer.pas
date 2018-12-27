unit frmIOCPProxyServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, iocp_server, iocp_managers, fmIOCPSvrInfo, StdCtrls,
  iocp_sockets;

type
  TFormInIOCPProxySvr = class(TForm)
    InIOCPBroker1: TInIOCPBroker;
    InIOCPServer1: TInIOCPServer;
    Button1: TButton;
    Button2: TButton;
    Memo1: TMemo;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    Label1: TLabel;
    Edit1: TEdit;
    EditPort: TEdit;
    Label2: TLabel;
    procedure InIOCPBroker1Bind(Sender: TSocketBroker; const Data: PAnsiChar;
      DataSize: Cardinal);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPProxySvr: TFormInIOCPProxySvr;

implementation

uses
  iocp_log, IniFiles, iocp_varis, iocp_utils, iocp_base, http_utils;

{$R *.dfm}

procedure TFormInIOCPProxySvr.Button1Click(Sender: TObject);
begin
  // ������־
  iocp_log.TLogThread.InitLog(FAppDir + 'log');
  iocp_utils.IniDateTimeFormat;   // ����ʱ���ʽ

  // InIOCPBroker1 �� ProxyType = ptDefault �� ReverseProxy.ServerAddr Ϊ��ʱ
  // ����ͨ����Ҫ�������û���ֱ�ӷ��ʵõ��ĵط���

  InIOCPServer1.ServerAddr := Edit1.Text;
  InIOCPServer1.ServerPort := StrToInt(EditPort.Text);
    
  InIOCPServer1.Active := True;
  FrameIOCPSvrInfo1.Start(InIOCPServer1);
end;

procedure TFormInIOCPProxySvr.Button2Click(Sender: TObject);
begin
  FrameIOCPSvrInfo1.Stop;         // ֹͣͳ��
  InIOCPServer1.Active := False;  // ֹͣ����
  iocp_log.TLogThread.StopLog;    // ֹͣ��־
end;

procedure TFormInIOCPProxySvr.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  InIOCPServer1.Active := False;
end;

procedure TFormInIOCPProxySvr.FormCreate(Sender: TObject);
begin
  // ׼��·��
  FAppDir := ExtractFilePath(Application.ExeName);
  iocp_Varis.gAppPath := FAppDir;
  MyCreateDir(FAppDir + 'log');   // ��־·��

  with TIniFile.Create(FAppDir + 'settings.ini') do
  begin
    Edit1.Text := ReadString('Options', 'LocalHost', '127.0.0.1');
    EditPort.Text := ReadString('Options', 'LocalPort', '80');

    if (ReadString('Options', 'Protocol', 'HTTP') = 'HTTP') then
      InIOCPBroker1.Protocol := tpHTTP // �������Զ�����
    else
      InIOCPBroker1.Protocol := tpNone;

    // �ڲ���Ĭ������
    InIOCPBroker1.InnerServer.ServerAddr := ReadString('Options', 'InnerServerAddr', '127.0.0.1');
    InIOCPBroker1.InnerServer.ServerPort := ReadInteger('Options', 'InnerServerPort', 1200);

    Free;
  end;

end;

procedure TFormInIOCPProxySvr.InIOCPBroker1Bind(Sender: TSocketBroker;
  const Data: PAnsiChar; DataSize: Cardinal);
begin
  //   Sender: Ϊ������� TSocketBroker
  //     Data: �յ������ݵ�ַ����ֹ�ͷţ�
  // DataSize: �յ������ݵĳ���

  // Sender �Ĺ��̣�
  //    CreateBroker: ��һ���ڲ��������

  // һ��ͨ���÷���
  //     �ڲ�ֻ��һ������ʱ����ֱ�� CreateBroker
  Sender.CreateBroker(InIOCPBroker1.InnerServer.ServerAddr,
                      InIOCPBroker1.InnerServer.ServerPort);  // ����Ĭ�ϵ��ڲ�����

  // ����HTTP��WebSocket Э����÷���
  //   1. ֻ��һ������ʱֱ���� CreateBroker��Ч����ߣ�
  //   2. �� TInIOCPBroker.Protocol = tpHTTP��ϵͳ�ڲ��Զ������������
  //      ��ȡ��ͷ�� Host ��Ϣ��������Ӧ�����ӣ�û�� Host ʱ�����ӵ�
  //      TInIOCPBroker.InnerServer ָ����������Ĭ�ϵ��ڲ���������
  //   3. TInIOCPBroker.Protocol = tpHTTP ʱЧ���Եͣ��������ڵ�ǰ�¼�д�κδ��롣

end;

procedure TFormInIOCPProxySvr.InIOCPServer1AfterOpen(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Memo1.Lines.Add('LocalHost=' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('LocalPort=' + IntToStr(InIOCPServer1.ServerPort));

  Memo1.Lines.Add('InnerServerAddr=' + InIOCPBroker1.InnerServer.ServerAddr);
  Memo1.Lines.Add('InnerServerPort=' + IntToStr(InIOCPBroker1.InnerServer.ServerPort));

  if InIOCPBroker1.Protocol = tpHTTP then
    Memo1.Lines.Add('Protocol=HTTP')
  else
    Memo1.Lines.Add('Protocol=None');

  Button1.Enabled := not InIOCPServer1.Active;
  Button2.Enabled := InIOCPServer1.Active;
end;

end.
