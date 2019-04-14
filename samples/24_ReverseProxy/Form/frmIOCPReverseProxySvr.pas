unit frmIOCPReverseProxySvr;

interface

uses         
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, iocp_server, iocp_managers, fmIOCPSvrInfo, StdCtrls,
  iocp_sockets;

type
  TFormInIOCPRecvProxySvr = class(TForm)
    InIOCPBroker1: TInIOCPBroker;
    InIOCPServer1: TInIOCPServer;
    Button1: TButton;
    Button2: TButton;
    Memo1: TMemo;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    Edit1: TEdit;
    Label1: TLabel;
    EditPort: TEdit;
    procedure InIOCPBroker1Bind(Sender: TSocketBroker; const Data: PAnsiChar;
      DataSize: Cardinal);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Edit1DblClick(Sender: TObject);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPRecvProxySvr: TFormInIOCPRecvProxySvr;
  ProxyWindowCount: Integer = 1;
  
implementation

uses
  iocp_log, iocp_varis, iocp_base, iocp_utils, http_utils, IniFiles;

{$R *.dfm}

procedure TFormInIOCPRecvProxySvr.Button1Click(Sender: TObject);
begin
  // TInIOCPBroker.ProxyType = ptDefault �� OuterServer.ServerAddr ��Ϊ��ʱ
  // �Ƿ������Ҫ�������ܷ����ⲿ����������ĵط���
  // ���������������ⲿ�������������ⲿ���������ӣ�
  // ͨ����Щ�������ڲ��������ͨѶ��

  // ������־
  iocp_log.TLogThread.InitLog(FAppDir + 'log');
  iocp_utils.IniDateTimeFormat;   // ����ʱ���ʽ

  InIOCPServer1.ServerAddr := Edit1.Text;
  InIOCPServer1.ServerPort := StrToInt(EditPort.Text);
  InIOCPServer1.Active := True;

  FrameIOCPSvrInfo1.Start(InIOCPServer1);
end;

procedure TFormInIOCPRecvProxySvr.Button2Click(Sender: TObject);
begin
  FrameIOCPSvrInfo1.Stop;         // ֹͣͳ��
  InIOCPServer1.Active := False;  // ֹͣ����
  iocp_log.TLogThread.StopLog;    // ֹͣ��־
end;

procedure TFormInIOCPRecvProxySvr.Edit1DblClick(Sender: TObject);
begin
  if Edit1.Text = '127.0.0.1' then
    Edit1.Text := '192.168.1.196'
  else
    Edit1.Text := '127.0.0.1';
end;

procedure TFormInIOCPRecvProxySvr.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  Button2Click(nil);
end;

procedure TFormInIOCPRecvProxySvr.FormCreate(Sender: TObject);
begin
  // ׼��·��
  FAppDir := ExtractFilePath(Application.ExeName);
  iocp_Varis.gAppPath := FAppDir;
  MyCreateDir(FAppDir + 'log');   // ��־·��

  // �������
  with TIniFile.Create(FAppDir + 'settings.ini') do
  begin
    Edit1.Text := ReadString('ReverseOptions', 'LocalHost', '127.0.0.1');
    EditPort.Text := ReadString('ReverseOptions', 'LocalPort', '900');

    if (ReadString('ReverseOptions', 'Protocol', 'HTTP') = 'HTTP') then
      InIOCPBroker1.Protocol := tpHTTP // ���Զ���������ģ��������
    else
      InIOCPBroker1.Protocol := tpNone;

    InIOCPBroker1.BrokerId := ReadString('ReverseOptions', 'BrokerId', '�ֹ�˾A');
    InIOCPBroker1.InnerServer.ServerAddr := ReadString('ReverseOptions', 'InnerServerAddr', '127.0.0.1');
    InIOCPBroker1.InnerServer.ServerPort := ReadInteger('ReverseOptions', 'InnerServerPort', 3060);

    InIOCPBroker1.OuterServer.ServerAddr := ReadString('OuterOptions', 'LocalHost', '127.0.0.1');
    InIOCPBroker1.OuterServer.ServerPort := ReadInteger('OuterOptions', 'LocalPort', 900);

    Free;
  end;  
end;

procedure TFormInIOCPRecvProxySvr.InIOCPBroker1Bind(Sender: TSocketBroker;
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

procedure TFormInIOCPRecvProxySvr.InIOCPServer1AfterOpen(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Memo1.Lines.Add('LocalHost=' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('LocalPort=' + IntToStr(InIOCPServer1.ServerPort));
  Memo1.Lines.Add('BrokerId=' + InIOCPBroker1.BrokerId);
  Memo1.Lines.Add('InnerServerAddr=' + InIOCPBroker1.InnerServer.ServerAddr);
  Memo1.Lines.Add('InnerServerPort=' + IntToStr(InIOCPBroker1.InnerServer.ServerPort));
  Memo1.Lines.Add('OuterServerAddr=' + InIOCPBroker1.OuterServer.ServerAddr);
  Memo1.Lines.Add('OuterServerPort=' + IntToStr(InIOCPBroker1.OuterServer.ServerPort));

  Button1.Enabled := not InIOCPServer1.Active;
  Button2.Enabled := InIOCPServer1.Active;
end;

end.
