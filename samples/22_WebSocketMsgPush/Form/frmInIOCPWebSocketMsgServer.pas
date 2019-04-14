unit frmInIOCPWebSocketMsgServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, fmIOCPSvrInfo, iocp_managers, iocp_base,
  http_objects, iocp_server, iocp_sockets, iocp_wsClients;

type
  TFormInIOCPWsJSONMsgServer = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Memo1: TMemo;
    InIOCPServer1: TInIOCPServer;
    InHttpDataProvider1: TInHttpDataProvider;
    InWebSocketManager1: TInWebSocketManager;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InHttpDataProvider1Accept(Sender: TObject; Request: THttpRequest;
      var Accept: Boolean);
    procedure InWebSocketManager1Upgrade(Sender: TObject; const Origin: string;
      var Accept: Boolean);
    procedure InWebSocketManager1Receive(Sender: TObject; Socket: TWebSocket);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormInIOCPWsJSONMsgServer: TFormInIOCPWsJSONMsgServer;

implementation

uses
  iocp_varis, iocp_utils, iocp_log;

{$R *.dfm}

procedure TFormInIOCPWsJSONMsgServer.Button1Click(Sender: TObject);
begin
  // �°���ݱ�׼ WebSocket ��Ϣ��������Ϣ�� JSON ��װ��֧�ִ��ļ�����
  iocp_log.TLogThread.InitLog(iocp_varis.gAppPath + 'log');  // ������־
  FrameIOCPSvrInfo1.Start(InIOCPServer1);
  InIOCPServer1.Active := True;
end;

procedure TFormInIOCPWsJSONMsgServer.Button2Click(Sender: TObject);
begin
  FrameIOCPSvrInfo1.Stop;
  InIOCPServer1.Active := False;
  iocp_log.TLogThread.StopLog;  // ֹͣ��־  
end;

procedure TFormInIOCPWsJSONMsgServer.FormCreate(Sender: TObject);
begin
  InIOCPServer1.ServerAddr := 'localhost'; // '1962.168.1.196';
  InIOCPServer1.ServerPort := 80; // '12302';
  iocp_varis.gAppPath := ExtractFilePath(Application.ExeName);  // ����·��
  iocp_utils.MyCreateDir(iocp_varis.gAppPath + 'log');  // ����־Ŀ¼
end;

procedure TFormInIOCPWsJSONMsgServer.InHttpDataProvider1Accept(Sender: TObject;
  Request: THttpRequest; var Accept: Boolean);
begin
  // Accept Ĭ�� = True
end;

procedure TFormInIOCPWsJSONMsgServer.InIOCPServer1AfterOpen(Sender: TObject);
begin
//  Memo1.Lines.Clear;
  Memo1.Lines.Add('IP:' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('Port:' + IntToStr(InIOCPServer1.ServerPort));  
end;

procedure TFormInIOCPWsJSONMsgServer.InWebSocketManager1Receive(Sender: TObject; Socket: TWebSocket);
begin
  // ��ʾ��Ϣ����
  //   1. ���������Ϣ����
  //   2. InIOCP-JSON ��Ϣ�����ͣ�������ʱ���͵��� JSON �����������������ͣ�

  // Socket ���û������ܽ���������Ϣ
  if (Socket.UserName = '') then
    Socket.UserName := 'User_' + IntToStr(Socket.JSON.MsgId);

  // ��Ҫ���� ocClose!
  if Socket.OpCode in [ocText, ocBiary] then
    case Socket.MsgType of
      mtDefault:  // �������������������Ϣ
        InWebSocketManager1.Broadcast(Socket);
      mtJSON: begin
  {      // ����ͬʱ���ո���
        if Socket.JSON.HasAttachment then
          Socket.JSON.Attachment := TFileStream.Create('doc\???', fmOpenRead); }
        InWebSocketManager1.Broadcast(Socket);
  //      Memo1.Lines.Add(Socket.JSON.S['msg']);
      end;
      mtAttachment: begin
        // ���ո���ʱ Socket.JSON.Attachment <> nil
      end;
    end;

end;

procedure TFormInIOCPWsJSONMsgServer.InWebSocketManager1Upgrade(Sender: TObject;
  const Origin: string; var Accept: Boolean);
begin
  // Origin: �������� Socket ����Դ���磺www.aaa.com
  // �ڴ��ж��Ƿ���������Ϊ WebSocket��Ĭ�� Accept=True
end;

end.
