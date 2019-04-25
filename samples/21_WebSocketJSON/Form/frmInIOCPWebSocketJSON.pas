unit frmInIOCPWebSocketJSON;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, fmIOCPSvrInfo, iocp_managers, iocp_base,
  http_objects, iocp_server, iocp_sockets, iocp_wsClients;

type
  TFormInIOCPWsJSON = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Memo1: TMemo;
    InIOCPServer1: TInIOCPServer;
    InHttpDataProvider1: TInHttpDataProvider;
    InWebSocketManager1: TInWebSocketManager;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    Button3: TButton;
    InDatabaseManager1: TInDatabaseManager;
    InFileManager1: TInFileManager;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InHttpDataProvider1Accept(Sender: TObject; Request: THttpRequest;
      var Accept: Boolean);
    procedure InWebSocketManager1Upgrade(Sender: TObject; const Origin: string;
      var Accept: Boolean);
    procedure InWebSocketManager1Receive(Sender: TObject; Socket: TWebSocket);
    procedure InWSConnection1ReceiveData(Sender: TObject; const Msg: string);
    procedure InWSConnection1ReceiveMsg(Sender: TObject; Msg: TJSONResult);
    procedure InWSConnection1ReturnResult(Sender: TObject; Result: TJSONResult);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormInIOCPWsJSON: TFormInIOCPWsJSON;

implementation

uses
  iocp_varis, iocp_utils, iocp_log, dm_iniocp_test;

{$R *.dfm}

procedure TFormInIOCPWsJSON.Button1Click(Sender: TObject);
begin
  // �°���ݱ�׼ WebSocket ��Ϣ��������Ϣ�� JSON ��װ��֧�ִ��ļ�����

  // �� TInIOCPDataModule �̳��µ���ģ TdmInIOCPTest��
  //    ע����ģ���ͼ��ɣ�ϵͳ�Զ�����ģʵ����
  //    ֹͣ����ʱ�������ģ�б�
  InDatabaseManager1.AddDataModule(TdmInIOCPTest, 'ADO_xzqh');

  iocp_log.TLogThread.InitLog(iocp_varis.gAppPath + 'log');  // ������־
  FrameIOCPSvrInfo1.Start(InIOCPServer1);
  InIOCPServer1.Active := True;
end;

procedure TFormInIOCPWsJSON.Button2Click(Sender: TObject);
begin
  FrameIOCPSvrInfo1.Stop;
  InIOCPServer1.Active := False;
  iocp_log.TLogThread.StopLog;  // ֹͣ��־  
end;

procedure TFormInIOCPWsJSON.Button3Click(Sender: TObject);
begin
  InIOCPServer1AfterOpen(nil);
end;

procedure TFormInIOCPWsJSON.FormCreate(Sender: TObject);
begin
  iocp_varis.gAppPath := ExtractFilePath(Application.ExeName);  // ����·��
  iocp_utils.MyCreateDir(iocp_varis.gAppPath + 'log');  // ����־Ŀ¼
end;

procedure TFormInIOCPWsJSON.InHttpDataProvider1Accept(Sender: TObject;
  Request: THttpRequest; var Accept: Boolean);
begin
  // Accept Ĭ�� = True
end;

procedure TFormInIOCPWsJSON.InIOCPServer1AfterOpen(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Memo1.Lines.Add('IP:' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('Port:' + IntToStr(InIOCPServer1.ServerPort));
end;

procedure TFormInIOCPWsJSON.InWebSocketManager1Receive(Sender: TObject; Socket: TWebSocket);
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

  // ������ SendResult �����������ݸ��ͻ��ˣ�

  case Socket.MsgType of  // 3�����͵�����
    mtJSON: // 1. InIOCP ��չ�� JSON ��Ϣ����ʱ Socket.Complete = True��
      case Socket.JSON.Action of
        33:  // �㲥
          InWebSocketManager1.Broadcast(Socket);

        11: begin  // ִ�����ݿ��ѯ
          Memo1.Lines.Add('aaa=' + Socket.JSON.S['aaa']);
          // ��ѯ
//          Socket.Result.Action := 11;  // �°��Զ����� Action
          TBusiWorker(Sender).DataModule.WebSocketQuery(Socket.JSON, Socket.Result);
          Socket.SendResult;  // ��Ĭ���ַ������� UTF-8
        end;

        12: begin // �������ݱ�
//          Socket.Result.Action := 12;   // �°��Զ����� Action

          TBusiWorker(Sender).DataModule.WebSocketUpdates(Socket.JSON, Socket.Result);

          Socket.SendResult;
        end;

        20: begin // ��ѯ�ļ�
//          Socket.Result.Action := 20;  // �°��Զ����� Action

          // ��ѯ·����gAppPath + 'form\'
          InFileManager1.ListFiles(Socket, gAppPath + Socket.JSON.S['path']);

          Socket.SendResult;

          // ���԰��ļ�������������һ����:
        { for i := 0 to Count - 1 do
          begin
            Socket.Result.Attachment := TFileStream.Create('??' + , fmShareDenyWrite);
            Socket.Result.S['fileName'] := '??';
            Socket.SendResult;
          end;  }

        end;

        else begin
          // ������Ϣ
          Memo1.Lines.Add('aaa=' + Socket.JSON.S['aaa']);
          Memo1.Lines.Add('bbb=' + Socket.JSON.S['BBB']);
          Memo1.Lines.Add('����������=' + Socket.JSON.S['attach']);

          if Socket.JSON.HasAttachment then // ������ -> ���ļ������ո���������ʱ����
            Socket.JSON.Attachment := TFileStream.Create('temp\������յ�' + Socket.JSON.S['attach'], fmCreate);

          Socket.UserName := 'JSON';
    //     InWebSocketManager1.SendTo(Socket, 'ToUser');

    //      Socket.Result.S['return'] := 'test ������Ϣ';
    //      Socket.SendResult;  // ���ͽ�����ͻ���
        end;

      end;

    mtAttachment: begin
      // 2. InIOCP ��չ�� ������ ���ݣ���ʱ Socket.Complete = True��
      //    ��� Socket.JSON.Attachment δ�գ�������ִ�е���

      // ϵͳ���Զ��رո����� Socket.JSON.Attachment
      Memo1.Lines.Add('����������ϣ�ϵͳ���Զ��رո���������');

      // ������Ϣ
      Socket.Result.S['return'] := 'test ������Ϣ+������';

      // A. ���ظ�����
      Socket.Result.Attachment := TFileStream.Create('Doc\Form.7z', fmShareDenyWrite);
      Socket.Result.S['attach'] := 'Form.7z';
      Socket.SendResult;  // ��Ĭ���ַ������� UTF-8

      // ������������
      // B. ��ѯ���ݿ⣬���� Data ���ݣ�Ҳ�Ǹ�����
      //    ���� Data ��������ĸ����������߻��⡣

 {     TBusiWorker(Sender).DataModule.WebSocketQuery(Socket.JSON, Socket.Result);
      Socket.SendResult;  // ��Ĭ���ַ������� UTF-8  }

    end;

    else begin

      // 3. ��׼�� WebSocket ���ݣ���������������ģ�Socket.Complete δ��Ϊ True��
      
      if Socket.Complete then // ��Ϣ�������
      begin
        // ˫�ֽڵ� UTF8To ϵ�к����Ĵ�������� AnsiString Ϊ��
        // ���� S Ϊ AnsiString ���������
        SetString(S, Socket.Data, Socket.FrameRecvSize); // ����ϢתΪ String

        Socket.UserName := System.Utf8ToAnsi(S); // XE10 �������� UTF8ToString(S)
        Memo1.Lines.Add(Socket.UserName);
        
        // ����ȫ���ͻ��������б�
//        InWebSocketManager1.GetUserList(Socket);

        InWebSocketManager1.Broadcast(Socket);

        // ����ȫ���ͻ��ˣ�UserName ������
//        InWebSocketManager1.Broadcast('�����ҹ㲥��' + Socket.UserName + '������.');

{       // ���·�������������

        // 1. ������Ϣ���ͻ���
        Socket.SendData('������������' + Socket.UserName);

        // 2. �����������Ѿ��Ǽ��û�����ȫ���û���
        //    �����б���ͻ��ˣ�JSON��ʽ���ֶ�Ϊ NAME��Ĭ���ַ�����
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
        if (Socket.Role >= crAdmin) then  // ��Ȩ��
          InWebSocketManager1.Delete(Socket, '�û�A'); }

    //    Memo1.Lines.Add('�յ� WebSocket ��Ϣ��' + S);  // �󲢷���Ҫ��ʾ
      end;
    end;
  end;
end;

procedure TFormInIOCPWsJSON.InWebSocketManager1Upgrade(Sender: TObject;
  const Origin: string; var Accept: Boolean);
begin
  // Origin: �������� Socket ����Դ���磺www.aaa.com
  // �ڴ��ж��Ƿ���������Ϊ WebSocket��Ĭ�� Accept=True
end;

procedure TFormInIOCPWsJSON.InWSConnection1ReceiveData(Sender: TObject; const Msg: string);
begin
  // Sender: �� TInWSConnection
  //    Msg���յ���Ϣ�ı�

  // �����յ��Ĳ��� InIOCP-JSON ��Ϣ������δ��װ�����ݣ�
  // ���Է����������������һ����Ϣ���ڷ���˹㲥��

  Memo1.Lines.Add(Msg);
end;

procedure TFormInIOCPWsJSON.InWSConnection1ReceiveMsg(Sender: TObject; Msg: TJSONResult);
begin
  //  Sender: �� TInWSConnection
  //     Msg: JSON ��Ϣ��ϵͳ���Զ��ͷ�

  // �����յ����������ͻ����������� InIOCP-JSON ��Ϣ���������գ�
  // ���Է������� TJSONMessage ������Ϣ���ڷ���˹㲥��

  Memo1.Lines.Add('�յ�������Ϣ���������գ���' + Msg.S['push']);
end;

procedure TFormInIOCPWsJSON.InWSConnection1ReturnResult(Sender: TObject; Result: TJSONResult);
begin
  // Sender: �� TInWSConnection
  // Result: JSON ��Ϣ��ϵͳ���Զ��ͷ�
  
  // Result.MsgType: ��Ϣ����
  //   1. mtJSON��Result �� JSON ��Ϣ
  //   2. mtAttachment��Result �Ǹ�������ϵͳ�Զ��ͷţ���Ҫ Result.Attachment.Free��

  // Result.AttachType: �������ͣ����֣�
  //   1. ��������2. ���ݼ�

  // ���Է�����������յ���Ϣ������ Socket.Result���� Socket.SendResult ���ͻ�����

  Memo1.Lines.Add('====== �ͻ��� ======');

  if Result.MsgType = mtJSON then
  begin
    if Result.HasAttachment then  // �и����������գ����Բ����գ�
      Result.Attachment := TFileStream.Create('temp\�ͻ����յ�' + Result.S['attach'], fmCreate);
    Memo1.Lines.Add('����˷��ظ��Լ��� JSON ��Ϣ: ' + Result.S['return']);
  end else  // �Ǹ�����
  if Assigned(Result.Attachment) then  // �յ��ļ���
  begin
    if Result.HasAttachment then
      Memo1.Lines.Add('�����ļ���ϣ�ϵͳ���Զ��رո�������')
    else
      Memo1.Lines.Add('�������ݼ���ϣ�JSON��ʽ��')
  end else
    Memo1.Lines.Add('û�н����ļ�');
end;

end.
