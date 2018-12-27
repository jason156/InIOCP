unit frmOuterProxyServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, fmIOCPSvrInfo, StdCtrls, iocp_managers, iocp_server, iocp_sockets;

type
  TFormIOCPOutProxySvr = class(TForm)
    Button1: TButton;
    Button2: TButton;
    InIOCPServer1: TInIOCPServer;
    InIOCPBroker1: TInIOCPBroker;
    Label1: TLabel;
    Edit1: TEdit;
    EditPort: TEdit;
    Memo1: TMemo;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Edit1DblClick(Sender: TObject);
    procedure InIOCPServer1AfterClose(Sender: TObject);
    procedure InIOCPBroker1Bind(Sender: TSocketBroker; const Data: PAnsiChar;
      DataSize: Cardinal);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormIOCPOutProxySvr: TFormIOCPOutProxySvr;

implementation

uses
  iocp_varis, iocp_log, iocp_base, iocp_utils, IniFiles;

{$R *.dfm}

procedure TFormIOCPOutProxySvr.Button1Click(Sender: TObject);
begin
  // ע�⣺TInIOCPBroker.ProxyType ����Ϊ ptOuter��
  
  // ������־
  iocp_log.TLogThread.InitLog(FAppDir + 'log');
  iocp_utils.IniDateTimeFormat;   // ����ʱ���ʽ

  InIOCPServer1.ServerAddr := Edit1.Text;
  InIOCPServer1.ServerPort := StrToInt(EditPort.Text);

  InIOCPServer1.Active := True;

  FrameIOCPSvrInfo1.Start(InIOCPServer1);
end;

procedure TFormIOCPOutProxySvr.Button2Click(Sender: TObject);
begin
  FrameIOCPSvrInfo1.Stop;         // ֹͣͳ��
  InIOCPServer1.Active := False;  // ֹͣ����
  iocp_log.TLogThread.StopLog;    // ֹͣ��־
end;

procedure TFormIOCPOutProxySvr.Edit1DblClick(Sender: TObject);
begin
  if Edit1.Text = '127.0.0.1' then
    Edit1.Text := '192.168.1.196'
  else
    Edit1.Text := '127.0.0.1';
end;

procedure TFormIOCPOutProxySvr.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  Button2Click(nil);
end;

procedure TFormIOCPOutProxySvr.FormCreate(Sender: TObject);
begin
  // ׼��·��
  FAppDir := ExtractFilePath(Application.ExeName);
  iocp_Varis.gAppPath := FAppDir;
  MyCreateDir(FAppDir + 'log');   // ��־·��

  // �������
  with TIniFile.Create(FAppDir + 'settings.ini') do
  begin
    Edit1.Text := ReadString('OuterOptions', 'LocalHost', '127.0.0.1');
    EditPort.Text := ReadString('OuterOptions', 'LocalPort', '80');

    if (ReadString('OuterOptions', 'Protocol', 'HTTP') = 'HTTP') then
      InIOCPBroker1.Protocol := tpHTTP // ���Զ���������ģ��������
    else
      InIOCPBroker1.Protocol := tpNone;

    Free;
  end;
end;

procedure TFormIOCPOutProxySvr.InIOCPBroker1Bind(Sender: TSocketBroker;
  const Data: PAnsiChar; DataSize: Cardinal);
begin
  // ˵����
  // Sender �������ͻ��ˣ������ͷ����������ӹ�����
  // ������ͨѶͨ����Sender ͨ�����ͨ���뷴�����ͨѶ��
  // ������������ڲ�������ͨѶ��

  // �ⲿ���� TInIOCPBroker ���������ã�
  //   ������ TInIOCPBroker.ProxyType = ptOuter
  //   �ڲ��Զ����ڲ����ӣ������ڴ��¼�д�κδ��룡

  // һ���ڲ�ֻ��һ���������ʱ��������������������ֵ��
  //     �����ֻ���򵥵�����ת����֧���κ�Э�飻

  // �������ʹ�� HTTP Э�飬���ж���������ʱ�������������ÿ������һ���������
  //     Ҫͬʱ�� TInIOCPBroker.Protocol = tpHTTP����Ҫ�� HTTP �ͻ�������ͷ�� Host
  //     ����Ҫ�ĵ����������¸�ʽ��
  //         Host: ����������IP:�˿�@��������־
  //     �� Host:127.0.0.1:12302@�ֹ�˾A����˼����Ҫ���ӵ� �ֹ�˾A ������ 127.0.0.1:12302

  //  ��������־���ֹ�˾A�����Ƿ������� TInIOCPBroker.BrokerId���ұ�־Ψһ��

  // �����෴�����ֻ֧�� HTTP Э�顣
  
end;

procedure TFormIOCPOutProxySvr.InIOCPServer1AfterClose(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Memo1.Lines.Add('LocalHost=' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('LocalPort=' + IntToStr(InIOCPServer1.ServerPort));

  Button1.Enabled := not InIOCPServer1.Active;
  Button2.Enabled := InIOCPServer1.Active;
end;

end.
