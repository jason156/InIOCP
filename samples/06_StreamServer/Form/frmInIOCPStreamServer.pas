unit frmInIOCPStreamServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, iocp_sockets, iocp_server, fmIOCPSvrInfo;

type
  TFormInIOCPStreamServer = class(TForm)
    Memo1: TMemo;
    InIOCPServer1: TInIOCPServer;
    btnStart: TButton;
    btnStop: TButton;
    Edit1: TEdit;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    procedure FormCreate(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure InIOCPServer1DataSend(Sender: TBaseSocket; Size: Cardinal);
    procedure InIOCPServer1DataReceive(Sender: TBaseSocket;
      const Data: PAnsiChar; Size: Cardinal);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InIOCPServer1AfterClose(Sender: TObject);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPStreamServer: TFormInIOCPStreamServer;

implementation

uses
  iocp_log, iocp_utils, iocp_msgPacks, http_utils;
  
{$R *.dfm}

procedure TFormInIOCPStreamServer.btnStartClick(Sender: TObject);
begin
//  Memo1.Lines.Clear;
  iocp_log.TLogThread.InitLog;              // ������־
  InIOCPServer1.ServerAddr := Edit1.Text;     // ��ַ
  InIOCPServer1.Active := True;               // ��������
  FrameIOCPSvrInfo1.Start(InIOCPServer1);     // ��ʼͳ��
end;

procedure TFormInIOCPStreamServer.btnStopClick(Sender: TObject);
begin
  InIOCPServer1.Active := False;   // ֹͣ����
  FrameIOCPSvrInfo1.Stop;          // ֹͣͳ��
  iocp_log.TLogThread.StopLog;   // ֹͣ��־
end;

procedure TFormInIOCPStreamServer.FormCreate(Sender: TObject);
begin
  // ����·��
//  Edit1.Text := GetLocalIp;
  FAppDir := ExtractFilePath(Application.ExeName);     
  MyCreateDir(FAppDir + 'log');
end;

procedure TFormInIOCPStreamServer.InIOCPServer1AfterClose(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
end;

procedure TFormInIOCPStreamServer.InIOCPServer1AfterOpen(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
  Memo1.Lines.Add('ip: ' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('port: ' + IntToStr(InIOCPServer1.ServerPort));
end;

procedure TFormInIOCPStreamServer.InIOCPServer1DataReceive(Sender: TBaseSocket;
  const Data: PAnsiChar; Size: Cardinal);
//var
//  Stream: TFileStream;
begin
  // �յ�һ�����ݰ���δ�ؽ�����ϣ�
  // Sender: �� TStreamSocket!
  //   Data: ����
  //   Size�����ݳ���

  // ������תΪ String ��ʾ
  // SetString(S, Data, Size);
  // memo1.lines.Add(S);

  // 4 �ַ�ʽ��������

  // 1. ��ԭ����������
//  TStreamSocket(Sender).SendData(Data, Size);

  // 2. �����ı�
//  TStreamSocket(Sender).SendData('Test Text ����');

  // 3. ����һ�� htm�ļ�������ͷ+���ݣ�
{  Stream := TFileStream.Create('retrun_stream.txt', fmShareDenyWrite);  // Ҫ��������������
  TStreamSocket(Sender).SendData(Stream);   // �Զ��ͷ� Stream  }

  // 4. ֱ�Ӵ��ļ����� Handle(�����)
  TStreamSocket(Sender).SendData(InternalOpenFile('retrun_stream.txt'));

  // 5. ����һ�� Variant
//  TStreamSocket(Sender).SendDataVar(Value);  

end;

procedure TFormInIOCPStreamServer.InIOCPServer1DataSend(Sender: TBaseSocket;
  Size: Cardinal);
begin
  // ���ݳɹ�����ʱִ�д˷���
  //   Sender: TStreamSocket! ��Ҫ���� Sender
end;

end.
