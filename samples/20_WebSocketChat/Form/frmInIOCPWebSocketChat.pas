unit frmInIOCPWebSocketChat;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, fmIOCPSvrInfo, iocp_managers,
  http_objects, iocp_server, iocp_sockets;

type
  TFormInIOCPWSChat = class(TForm)
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
  FormInIOCPWSChat: TFormInIOCPWSChat;

implementation

uses
  iocp_base, iocp_varis, iocp_utils, iocp_log;

{$R *.dfm}

procedure TFormInIOCPWSChat.Button1Click(Sender: TObject);
begin
  iocp_log.TLogThread.InitLog(iocp_varis.gAppPath + 'log');  // ������־
  FrameIOCPSvrInfo1.Start(InIOCPServer1);
  InIOCPServer1.Active := True;
end;

procedure TFormInIOCPWSChat.Button2Click(Sender: TObject);
begin
  FrameIOCPSvrInfo1.Stop;
  InIOCPServer1.Active := False;
  iocp_log.TLogThread.StopLog;  // ֹͣ��־  
end;

procedure TFormInIOCPWSChat.FormCreate(Sender: TObject);
begin
  iocp_varis.gAppPath := ExtractFilePath(Application.ExeName);  // ����·��
  iocp_utils.MyCreateDir(iocp_varis.gAppPath + 'log');  // ����־Ŀ¼
end;

procedure TFormInIOCPWSChat.InHttpDataProvider1Accept(Sender: TObject;
  Request: THttpRequest; var Accept: Boolean);
begin
  // Accept Ĭ�� = True
end;

procedure TFormInIOCPWSChat.InIOCPServer1AfterOpen(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Memo1.Lines.Add('IP:' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('Port:' + IntToStr(InIOCPServer1.ServerPort));  
end;

procedure TFormInIOCPWSChat.InWebSocketManager1Receive(Sender: TObject; Socket: TWebSocket);
var
  S: AnsiString;
begin
  // WebSocket �յ���Ϣ�������¼�
  // WebSocket ��֡���䣬Ĭ�ϵ� WebSocket ��Ϣδ��װ�������� JSON ��װ����

  // Socket �յ������ݷ����֣����� MsgType ��ֵ��
  //  1.    mtDefault: �� InIOCP-JSON ��װ�ı�׼ WebSocket ���ݣ�
  //  2.       mtJSON: �� InIOCP-JSON ��װ����չ JSON ��Ϣ��
  //  3. mtAttachment: �� InIOCP-JSON ��װ�ĸ�������

  // MsgType Ϊ mtDefault ʱ�� Socket ������ԣ�
  // 1��         Data�������յ�������������λ��
  // 2��FrameRecvSize�������յ������ݳ���
  // 3��    FrameSize����ǰ֡�������ܳ���
  // 4��      MsgSize����ǰ��Ϣ�ۼ��յ������ݳ��ȣ����ܺ���֡���ݣ�
  // 5��     Complete����ǰ��Ϣ�Ƿ������ϣ�True ʱ MsgSize Ϊ��Ϣ��ʵ�ʳ���
  // 6��       OpCode���������ر�ʱҲ�������¼�

  // InIOCP-JSON ��װ����Ϣ��֧�������� 1-4 �����ԣ���Ҫ���ԣ�
  //        7��  JSON: �յ��� JSON ��Ϣ
  //        8��Result: Ҫ������ JSON ��Ϣ���� SendResult ���͡�                
 
  if Socket.Complete then // ��Ϣ�������
  begin
    // ˫�ֽڵ� UTF8To ϵ�к����Ĵ�������� AnsiString Ϊ��
    // ���� S Ϊ AnsiString ���������
    SetString(S, Socket.Data, Socket.FrameRecvSize); // ����ϢתΪ String
    Socket.UserName := System.Utf8ToAnsi(S); // XE10 �������� UTF8ToString(S)

    // ��ʾ
    Memo1.Lines.Add(Socket.UserName);

    // ����ȫ���ͻ��������б�
    InWebSocketManager1.GetUserList(Socket);

    // ����ȫ���ͻ��ˣ�UserName ������
    InWebSocketManager1.Broadcast('�����ҹ㲥��' + Socket.UserName + '������.');
    
{    // 1. ������Ϣ���ͻ���
   Socket.SendData('������������' + Socket.UserName);

   // ���·�������������

    // 2. �����������Ѿ��Ǽ��û�����ȫ���û���
    //    �����б���ͻ��ˣ�JSON��ʽ���ֶ�Ϊ NAME��UTF-8 �ַ�����
    InWebSocketManager1.GetUserList(Socket);

    // 3. �㲥 Socket �յ�����Ϣ
   InWebSocketManager1.Broadcast(Socket);   

    // 4. ���յ�����Ϣ���� ToUser
    InWebSocketManager1.SendTo(Socket, 'ToUser');   

    // 5. �㲥һ���ı���Ϣ
    InWebSocketManager1.Broadcast('���Թ㲥');    

    // 6. ����һ���ı��� ToUser
    InWebSocketManager1.SendTo('ToUser', '���͸�ToUser');  

    // 7. ��ɾ���ͻ��� AAA
    Socket.Role := crAdmin;
    if (Socket.Role >= crAdmin) and (Socket.UserName <> 'USER_A') then  // ��Ȩ��
      InWebSocketManager1.Delete(Socket, 'USER_A');    }

//    mmoServer.Lines.Add('�յ� WebSocket ��Ϣ��' + S);  // �󲢷���Ҫ��ʾ   
  end;
end;

procedure TFormInIOCPWSChat.InWebSocketManager1Upgrade(Sender: TObject;
  const Origin: string; var Accept: Boolean);
begin
  // Origin: �������� Socket ����Դ���磺www.aaa.com

  // �ڴ��ж��Ƿ���������Ϊ WebSocket��Ĭ�� Accept=True
end;

end.
