(*
 * iocp WebSocket �ͻ��˵�Ԫ
 *
 * ˵����C/S ģʽ�� WebSocket Э��������֮������ǰ�߼���ҵ��
 *       һ���ӱȽ����������ߵĴ��룬�ִ� C/S ģʽ�Ŀͻ��˷�������ִ��룬
 *       �����ϴ��������ˣ������࣬�ɶ���Ҳǿ��������⡣
 *
 *)
unit iocp_wsClients;

interface

{$I in_iocp.inc}

uses
  Windows, Classes, SysUtils, ExtCtrls, Variants, DBClient, DSIntf,
  iocp_Winsock2, iocp_base, iocp_lists, iocp_senders,
  iocp_receivers, iocp_baseObjs, iocp_utils,
  iocp_msgPacks, iocp_WsJSON;

type

  // =================== WebSocket �ͻ��� �� ===================

  TSendThread = class;
  TRecvThread = class;
  TPostThread = class;

  TJSONMessage = class;
  TJSONResult  = class;

  // ============ �ͻ������� ============

  // �յ���׼ WebSocket �����¼�������Ϣ��װ��
  TOnReceiveData   = procedure(Sender: TObject; const Msg: String) of object;

  // �������յ� JSON
  TPassvieMsgEvent = procedure(Sender: TObject; Msg: TJSONResult) of object;

  // ��������¼�
  TReturnMsgEvent  = procedure(Sender: TObject; Result: TJSONResult) of object;

  // ��Ϣ�շ��¼�
  TOnDataTransmit  = procedure(Sender: TObject; MsgId: Int64; MsgSize, CurrentSize: TFileSize) of object;

  // �쳣�¼�
  TConnectionError = procedure(Sender: TObject; const Msg: String) of object;
  
  TInWSConnection = class(TComponent)
  private
    FSocket: TSocket;          // �׽���
    FTimer: TTimer;            // ��ʱ��
    
    FSendThread: TSendThread;  // �����߳�
    FRecvThread: TRecvThread;  // �����߳�
    FPostThread: TPostThread;  // Ͷ���߳�

    FRecvCount: Cardinal;      // ���յ�
    FSendCount: Cardinal;      // ������

    FActive: Boolean;          // ����/����״̬
    FAutoConnect: Boolean;     // �Ƿ��Զ�����

    FServerAddr: String;       // ��������ַ
    FServerPort: Word;         // ����˿�
    
    FLocalPath: String;        // �����ļ��ı��ش��·��
    FMasking: Boolean;         // ʹ������
    FJSON: TJSONMessage;       // ���� JSON ��Ϣ
    FUTF8CharSet: Boolean;     // �� UTF8 �ַ���

    FErrorcode: Integer;       // �쳣����
    FErrMsg: String;           // �쳣��Ϣ
  private
    FAfterConnect: TNotifyEvent;      // ���Ӻ�
    FAfterDisconnect: TNotifyEvent;   // �Ͽ���
    FBeforeConnect: TNotifyEvent;     // ����ǰ
    FBeforeDisconnect: TNotifyEvent;  // �Ͽ�ǰ
    FOnDataReceive: TOnDataTransmit;  // ��Ϣ�����¼�
    FOnDataSend: TOnDataTransmit;     // ��Ϣ�����¼�
    FOnReceiveData: TOnReceiveData;   // �յ��޷�װ������
    FOnReceiveMsg: TPassvieMsgEvent;  // ����������Ϣ�¼�
    FOnReturnResult: TReturnMsgEvent; // ������ֵ�¼�
    FOnError: TConnectionError;       // �쳣�¼�
  private
    function GetActive: Boolean;
    function GetJSON: TJSONMessage;

    procedure CreateTimer;
    procedure DoThreadFatalError;

    procedure HandlePushedData(Stream: TMemoryStream);
    procedure HandlePushedMsg(Result: TJSONResult);
    procedure HandleReturnMsg(Result: TJSONResult);
    procedure ReceiveAttachment;  

    procedure InternalOpen;
    procedure InternalClose;

    procedure ShowRecvProgress;
    procedure ShowSendProgress;

    procedure SetActive(Value: Boolean);
    procedure TimerEvent(Sender: TObject);
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    property Errorcode: Integer read FErrorcode;
    property RecvCount: Cardinal read FRecvCount;
    property SendCount: Cardinal read FSendCount;
    property Socket: TSocket read FSocket;
    property JSON: TJSONMessage read GetJSON;
  published
    property Active: Boolean read GetActive write SetActive default False;
    property AutoConnect: Boolean read FAutoConnect write FAutoConnect default False;
    property LocalPath: String read FLocalPath write FLocalPath;
    property Masking: Boolean read FMasking write FMasking default False;
    property ServerAddr: String read FServerAddr write FServerAddr;
    property ServerPort: Word read FServerPort write FServerPort default DEFAULT_SVC_PORT;
    property UTF8CharSet: Boolean read FUTF8CharSet write FUTF8CharSet default True;
  published
    property AfterConnect: TNotifyEvent read FAfterConnect write FAfterConnect;
    property AfterDisconnect: TNotifyEvent read FAfterDisconnect write FAfterDisconnect;
    property BeforeConnect: TNotifyEvent read FBeforeConnect write FBeforeConnect;
    property BeforeDisconnect: TNotifyEvent read FBeforeDisconnect write FBeforeDisconnect;

    // ���ձ�����Ϣ/������Ϣ�¼�
    property OnReceiveData: TOnReceiveData read FOnReceiveData write FOnReceiveData;
    property OnReceiveMsg: TPassvieMsgEvent read FOnReceiveMsg write FOnReceiveMsg;
    property OnReturnResult: TReturnMsgEvent read FOnReturnResult write FOnReturnResult;
    
    property OnDataReceive: TOnDataTransmit read FOnDataReceive write FOnDataReceive;
    property OnDataSend: TOnDataTransmit read FOnDataSend write FOnDataSend;
    property OnError: TConnectionError read FOnError write FOnError;
  end;

  TWSConnection = TInWSConnection;

  // ============ �û����͵� JSON ��Ϣ�� ============

  TJSONMessage = class(TSendJSON)
  public
    constructor Create(AOwner: TWSConnection);
    procedure Post;
    procedure SetRemoteTable(DataSet: TClientDataSet; const TableName: String);
  end;

  // ============ �ͻ����յ��� JSON ��Ϣ�� ============

  TJSONResult = class(TBaseJSON)
  protected
    FOpCode: TWSOpCode;         // �������ͣ��رգ�
    FMsgType: TWSMsgType;       // ��������
    FStream: TMemoryStream;     // �� InIOCP-JSON ��ԭʼ������
  public
    property MsgType: TWSMsgType read FMsgType;
  end;

  // =================== �����߳� �� ===================

  TSendThread = class(TCycleThread)
  private
    FLock: TThreadLock;         // �߳���
    FConnection: TWSConnection; // ����
    FSender: TClientTaskSender; // ��Ϣ������

    FMsgList: TInList;          // ������Ϣ���б�
    FMsgPack: TJSONMessage;     // ��ǰ������Ϣ��
    FCurrentSize: TFileSize;    // ��ǰ������

    function GetCount: Integer;
    function GetWork: Boolean;
    function GetWorkState: Boolean;

    procedure ClearMsgList;
    procedure AfterSend(First: Boolean; OutSize: Integer);
    procedure OnSendError(Sender: TObject);
  protected
    procedure AfterWork; override;
    procedure DoMethod; override;
  public
    constructor Create(AConnection: TWSConnection);
    procedure AddWork(Msg: TJSONMessage);
  public
    property Count: Integer read GetCount;
  end;

  // =================== ���ͽ�����߳� �� ===================
  // ������յ�����Ϣ���б���һ����Ӧ�ò�

  TPostThread = class(TCycleThread)
  private
    FLock: TThreadLock;         // �߳���
    FConnection: TWSConnection; // ����
    FResults: TInList;          // �յ�����Ϣ�б�
    FResult: TJSONResult;       // ��ǰ��Ϣ
    procedure ExecInMainThread;
  protected
    procedure AfterWork; override;
    procedure DoMethod; override;
  public
    constructor Create(AConnection: TWSConnection);
    procedure Add(AResult: TBaseJSON; AOpCode: TWSOpCode;
                  AMsgType: TWSMsgType; AStream: TMemoryStream);
  end;

  // =================== �����߳� �� ===================

  TRecvThread = class(TThread)
  private
    FConnection: TWSConnection; // ����
    FRecvBuf: TWsaBuf;          // ���ջ���
    FOverlapped: TOverlapped;   // �ص��ṹ

    FReceiver: TWSClientReceiver; // ���ݽ�����
    FResult: TJSONResult;       // ��ǰ��Ϣ

    FMsgId: Int64;              // ��ǰ��Ϣ Id
    FFrameSize: TFileSize;      // ��ǰ��Ϣ����
    FCurrentSize: TFileSize;    // ��ǰ��Ϣ�յ��ĳ���
    
    procedure HandleDataPacket; // �����յ������ݰ�
    procedure CheckUpgradeState(Buf: PAnsiChar; Len: Integer); 
    procedure OnAttachment(Result: TBaseJSON);
    procedure OnReceive(Result: TBaseJSON; FrameSize, RecvSize: Int64);
  protected
    procedure Execute; override;
  public
    constructor Create(AConnection: TWSConnection);
    procedure Stop;
  end;

implementation

uses
  http_base;

{ var
  FDebug: TStringList;
  FStream: TMemoryStream;  } 

{ TInWSConnection }

constructor TInWSConnection.Create(AOwner: TComponent);
begin
  inherited;
  IniDateTimeFormat;
  FAutoConnect := False; // ���Զ�����
  FUTF8CharSet := True;  // �ַ��� UTF-8
  FServerPort := DEFAULT_SVC_PORT;
  FSocket := INVALID_SOCKET;  // ��Ч Socket
end;

procedure TInWSConnection.CreateTimer;
begin
  // ����ʱ��(�ر��ã�
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 80;
  FTimer.OnTimer := TimerEvent;
end;

destructor TInWSConnection.Destroy;
begin
  SetActive(False);
  inherited;
end;

procedure TInWSConnection.DoThreadFatalError;
begin
  // �շ�ʱ�����쳣
  if Assigned(FOnError) then
    FOnError(Self, IntToStr(FErrorcode) + ',' + FErrMsg);
end;

function TInWSConnection.GetActive: Boolean;
begin
  if (csDesigning in ComponentState) or (csLoading in ComponentState) then
    Result := FActive
  else
    Result := (FSocket <> INVALID_SOCKET) and FActive;
end;

function TInWSConnection.GetJSON: TJSONMessage;
begin
  if (FJSON = nil) then
    FJSON := TJSONMessage.Create(Self);
  Result := FJSON;
end;

procedure TInWSConnection.HandlePushedData(Stream: TMemoryStream);
var
  Msg: AnsiString;
begin
  // ���������յ�δ��װ������
  if Assigned(FOnReceiveData) then
  begin
    SetString(Msg, PAnsiChar(Stream.Memory), Stream.Size);
    Msg := System.Utf8ToAnsi(Msg);
    FOnReceiveData(Self, Msg);
  end;
end;

procedure TInWSConnection.HandlePushedMsg(Result: TJSONResult);
begin
  // ���������յ� JSON ��Ϣ
  if Assigned(FOnReceiveMsg) then
    FOnReceiveMsg(Self, Result);
end;

procedure TInWSConnection.HandleReturnMsg(Result: TJSONResult);
begin
  // �������˷����� JSON ��Ϣ
  if Assigned(FOnReturnResult) then
    FOnReturnResult(Self, Result);
end;

procedure TInWSConnection.InternalClose;
begin
  // �Ͽ�����
  if Assigned(FBeforeDisConnect) then
    FBeforeDisConnect(Self);

  if (FSocket <> INVALID_SOCKET) then
  begin
    // �ر� Socket
    ShutDown(FSocket, SD_BOTH);
    CloseSocket(FSocket);

    FSocket := INVALID_SOCKET;

    if FActive then
    begin
      FActive := False;

      // �ͷŽ����߳�
      if Assigned(FRecvThread) then
      begin
        FRecvThread.Terminate;  // 100 ������˳�
        FRecvThread := nil;
      end;

      // Ͷ���߳�
      if Assigned(FPostThread) then
      begin
        FPostThread.Stop;
        FPostThread := nil;
      end;

      // �ͷŷ����߳�
      if Assigned(FSendThread) then
      begin
        FSendThread.FSender.Stoped := True;
        FSendThread.Stop;
        FSendThread := nil;
      end;

      // �ͷŶ�ʱ��
      if Assigned(FTimer) then
      begin
        FTimer.Free;
        FTimer := nil;
      end;      
    end;
  end;

  if not (csDestroying in ComponentState) then
    if Assigned(FAfterDisconnect) then
      FAfterDisconnect(Self);
end;

procedure TInWSConnection.InternalOpen;
const
  // WebSocket ��������
  WS_UPGRADE_REQUEST = AnsiString(
                       'GET / HTTP/1.1'#13#10 +
                       'Connection: Upgrade'#13#10 +
                       'Upgrade: WebSocket'#13#10 +
                       'Sec-WebSocket-Key: w4v7O6xFTi36lq3RNcgctw=='#13#10 +
                       'Sec-WebSocket-Version: 13'#13#10 +
                       'Origin: InIOCP-WebSocket'#13#10#13#10);
var
  Addr: TSockAddrIn;
begin
  // ���� WSASocket�����ӵ�������
  if Assigned(FBeforeConnect) then
    FBeforeConnect(Self);

  if (FSocket = INVALID_SOCKET) then
  begin
    // �½� Socket
    FSocket := WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, nil, 0, WSA_FLAG_OVERLAPPED);

    // �������ӵ�ַ���˿ڣ�����
    Addr.sin_family := AF_INET;
    Addr.sin_port := htons(FServerPort);
    Addr.sin_addr.s_addr := inet_addr(PAnsiChar(ResolveHostIP(FServerAddr)));

    // ˢ�� FActive
    FActive := iocp_Winsock2.WSAConnect(FSocket, TSockAddr(Addr),
                             SizeOf(TSockAddr), nil, nil, nil, nil) = 0;

    if FActive then    // ���ӳɹ�
    begin
      // ��ʱ��
      CreateTimer;

      // ���̷��� WS_UPGRADE_REQUEST�����������Ϊ WebSocket
      iocp_Winsock2.Send(FSocket, WS_UPGRADE_REQUEST[1], Length(WS_UPGRADE_REQUEST), 0);

      // �շ���
      FRecvCount := 0;
      FSendCount := 0;

      // Ͷ���߳�
      FPostThread := TPostThread.Create(Self);

      // �շ��߳�
      FSendThread := TSendThread.Create(Self);
      FRecvThread := TRecvThread.Create(Self);

      FPostThread.Resume;
      FSendThread.Resume;
      FRecvThread.Resume;
    end else
    begin
      ShutDown(FSocket, SD_BOTH);
      CloseSocket(FSocket);
      FSocket := INVALID_SOCKET;
    end;
  end;

  if FActive and Assigned(FAfterConnect) then
    FAfterConnect(Self)
  else
  if not FActive and Assigned(FOnError) then
    FOnError(Self, '�޷����ӵ�������.');
    
end;

procedure TInWSConnection.Loaded;
begin
  inherited;
  // װ�غ�FActive -> ��  
  if FActive and not (csDesigning in ComponentState) then
    InternalOpen;
end;

procedure TInWSConnection.SetActive(Value: Boolean);
begin
  if Value <> FActive then
  begin
    if (csDesigning in ComponentState) or (csLoading in ComponentState) then
      FActive := Value
    else
    if Value and not FActive then
      InternalOpen
    else
    if not Value and FActive then
      InternalClose;
  end;
end;

procedure TInWSConnection.ReceiveAttachment;
begin
  // �и�������׼������
  if Assigned(FOnReturnResult) then
    FOnReturnResult(Self, FRecvThread.FResult);
end;

procedure TInWSConnection.ShowRecvProgress;
begin
  // ��ʾ���ս���
  if Assigned(FOnDataReceive) then
    FOnDataReceive(Self,
                   FRecvThread.FMsgId,
                   FRecvThread.FFrameSize,
                   FRecvThread.FCurrentSize);
end;

procedure TInWSConnection.ShowSendProgress;
begin
  // ��ʾ���ͽ���
  if Assigned(FOnDataSend) then 
    FOnDataSend(Self,
                FSendThread.FMsgPack.FMsgId,
                FSendThread.FMsgPack.FFrameSize,
                FSendThread.FCurrentSize);
end;

procedure TInWSConnection.TimerEvent(Sender: TObject);
begin
  FTimer.Enabled := False;
  InternalClose;  // �Ͽ�����
end;

{ TJSONMessage }

constructor TJSONMessage.Create(AOwner: TWSConnection);
var
  ErrMsg: String;
begin
  if (AOwner = nil) then  // ����Ϊ nil
    ErrMsg := '��Ϣ Owner ����Ϊ��.'
  else
  if not AOwner.Active then
    ErrMsg := '���� AOwner ������.';
  if (ErrMsg <> '') then
    raise Exception.Create(ErrMsg)
  else
    inherited Create(AOwner);  
end;

procedure TJSONMessage.Post;
begin
  if Assigned(FOwner) then
    with TWSConnection(FOwner) do
    begin
      if (Self = FJSON) then  // �� Connection.FJSON
        FJSON := nil;         // �� nil
      if Assigned(FSendThread) then
        FSendThread.AddWork(Self); // �ύ��Ϣ
    end;
end;

procedure TJSONMessage.SetRemoteTable(DataSet: TClientDataSet; const TableName: String);
begin
  DataSet.SetOptionalParam(szTABLE_NAME, TableName, True); // �������ݱ�
end;

// ================== �����߳� ==================

{ TSendThread }

procedure TSendThread.AddWork(Msg: TJSONMessage);
begin
  // ����Ϣ�������б�
  //   Msg �Ƕ�̬���ɣ������ظ�Ͷ��
  FLock.Acquire;
  try
    FMsgList.Add(Msg);
  finally
    FLock.Release;
  end;
  Activate;  // �����߳�
end;

procedure TSendThread.AfterSend(First: Boolean; OutSize: Integer);
begin
  // ���ݳɹ���������ʾ����
  Inc(FCurrentSize, OutSize);
  Synchronize(FConnection.ShowSendProgress);
end;

procedure TSendThread.AfterWork;
begin
  // ֹͣ�̣߳��ͷ���Դ
  ClearMsgList;
  FMsgList.Free;
  FLock.Free;
  FSender.Free;
end;

constructor TSendThread.Create(AConnection: TWSConnection);
begin
  inherited Create;
  FConnection := AConnection;

  FLock := TThreadLock.Create; // ��
  FMsgList := TInList.Create;  // ���������

  FSender := TClientTaskSender.Create;   // ��������
  FSender.Owner := Self;       // ����
  FSender.Socket := FConnection.Socket;  // �����׽���
      
  FSender.AfterSend := AfterSend;  // �����¼�
  FSender.OnError := OnSendError;  // �����쳣�¼�
end;

procedure TSendThread.ClearMsgList;
var
  i: Integer;
begin
  // �ͷ��б��ȫ����Ϣ
  for i := 0 to FMsgList.Count - 1 do
    TJSONMessage(FMsgList.PopFirst).Free;
  if Assigned(FMsgPack) then
    FMsgPack.Free;
end;

procedure TSendThread.DoMethod;
  procedure FreeMsgPack;
  begin
    FLock.Acquire;
    try
      FMsgPack.Free;  // �ͷţ�
      FMsgPack := nil;
    finally
      FLock.Release;
    end;
  end;
begin
  // ѭ��������Ϣ
  while (Terminated = False) and FConnection.FActive and GetWork do
    try
      try
        FMsgPack.FUTF8CharSet := FConnection.FUTF8CharSet;
        FMsgPack.InternalSend(FSender, FConnection.FMasking);
      finally
        FreeMsgPack;  // �ͷ�
      end;
    except
      on E: Exception do
      begin
        FConnection.FErrMsg := E.Message;
        FConnection.FErrorcode := GetLastError;
        Synchronize(FConnection.DoThreadFatalError);
      end;
    end;
end;

function TSendThread.GetCount: Integer;
begin
  // ȡ������
  FLock.Acquire;
  try
    Result := FMsgList.Count;
  finally
    FLock.Release;
  end;
end;

function TSendThread.GetWork: Boolean;
begin
  // ���б���ȡһ����Ϣ
  FLock.Acquire;
  try
    if Terminated or (FMsgList.Count = 0) or Assigned(FMsgPack) then
      Result := False
    else begin
      FMsgPack := TJSONMessage(FMsgList.PopFirst);  // ȡ����
      Result := True;
    end;
  finally
    FLock.Release;
  end;
end;

function TSendThread.GetWorkState: Boolean;
begin
  // ȡ����״̬���̡߳�������δֹͣ
  FLock.Acquire;
  try
    Result := (Terminated = False) and (FSender.Stoped = False);
  finally
    FLock.Release;
  end;
end;

procedure TSendThread.OnSendError(Sender: TObject);
begin
  // �������쳣
  if (GetWorkState = False) then  // ȡ������
    FConnection.FRecvThread.FReceiver.Reset;
  FConnection.FErrorcode := TClientTaskSender(Sender).ErrorCode;
  Synchronize(FConnection.DoThreadFatalError); // �߳�ͬ��
end;

{ TPostThread }

procedure TPostThread.Add(AResult: TBaseJSON; AOpCode: TWSOpCode;
                          AMsgType: TWSMsgType; AStream: TMemoryStream);
begin
  // ��һ����Ϣ���б������߳�
  with TJSONResult(AResult) do
  begin
    FOpCode := AOpCode;
    FMsgType := AMsgType;
    FStream := AStream;
  end;
  FLock.Acquire;
  try
    FResults.Add(AResult);
  finally
    FLock.Release;
  end;
  Activate;  // ����
end;

procedure TPostThread.AfterWork;
var
  i: Integer;
begin
  // �����Ϣ
  for i := 0 to FResults.Count - 1 do
    TJSONResult(FResults.PopFirst).Free;
  FLock.Free;
  FResults.Free;
  inherited;
end;

constructor TPostThread.Create(AConnection: TWSConnection);
begin
  inherited Create;
  FreeOnTerminate := True;
  FConnection := AConnection;
  FLock := TThreadLock.Create; // ��
  FResults := TInList.Create;  // �յ�����Ϣ�б�
end;

procedure TPostThread.DoMethod;
begin
  // ѭ�������յ�����Ϣ
  while (Terminated = False) do
  begin
    FLock.Acquire;
    try
      FResult := FResults.PopFirst;  // ȡ����һ��
    finally
      FLock.Release;
    end;
    if Assigned(FResult) then
      Synchronize(ExecInMainThread) // ����Ӧ�ò�
    else
      Break;
  end;
end;

procedure TPostThread.ExecInMainThread;
begin
  // �������̣߳�����Ϣ�ύ������
  try
    try
      if (FResult.FOpCode = ocClose) then
        FConnection.FTimer.Enabled := True
      else
      if Assigned(FResult.FStream) then  // δ��װ������
        FConnection.HandlePushedData(FResult.FStream)
      else
      if (FResult.FOwner <> FConnection) then  // ����������Ϣ
        FConnection.HandlePushedMsg(FResult)
      else
        FConnection.HandleReturnMsg(FResult);  // ����˷������Լ�����Ϣ
    finally
      if Assigned(FResult.FStream) then  // �ͷţ�
        FResult.FStream.Free;      
      FResult.Free;
    end;
  except
    on E: Exception do
    begin
      FConnection.FErrMsg := E.Message;
      FConnection.FErrorcode := GetLastError;
      FConnection.DoThreadFatalError;  // �����̣߳�ֱ�ӵ���
    end;
  end;

end;

// ================== �����߳� ==================

// ʹ�� WSARecv �ص�������Ч�ʸ�
procedure WorkerRoutine(const dwError, cbTransferred: DWORD;
                        const lpOverlapped: POverlapped;
                        const dwFlags: DWORD); stdcall;
var
  Thread: TRecvThread;
  Connection: TWSConnection;
  ByteCount, Flags: DWORD;
  ErrorCode: Cardinal;
begin
  // �������߳� ��
  // ����� lpOverlapped^.hEvent = TInRecvThread

  Thread := TRecvThread(lpOverlapped^.hEvent);
  Connection := Thread.FConnection;

  if (dwError <> 0) or (cbTransferred = 0) then // �Ͽ����쳣
  begin
    Connection.FTimer.Enabled := True;
    Exit;
  end;

  try
    // ����һ�����ݰ�
    Thread.HandleDataPacket;
  finally
    // ����ִ�� WSARecv���ȴ�����
    FillChar(lpOverlapped^, SizeOf(TOverlapped), 0);
    lpOverlapped^.hEvent := DWORD(Thread);  // �����Լ�

    ByteCount := 0;
    Flags := 0;

    // �յ�����ʱִ�� WorkerRoutine
    if (iocp_Winsock2.WSARecv(Connection.FSocket, @Thread.FRecvBuf, 1,
                              ByteCount, Flags, LPWSAOVERLAPPED(lpOverlapped),
                              @WorkerRoutine) = SOCKET_ERROR) then
    begin
      ErrorCode := WSAGetLastError;
      if (ErrorCode <> WSA_IO_PENDING) then  
      begin
        Connection.FErrorcode := ErrorCode;
        Thread.Synchronize(Connection.DoThreadFatalError); // �߳�ͬ��
      end;
    end;
  end;
end;

{ TRecvThread }

procedure TRecvThread.CheckUpgradeState(Buf: PAnsiChar; Len: Integer);
begin
  // �������������򻯣����ܳ��־ܾ�����ķ�����
  if not MatchSocketType(Buf, HTTP_VER + HTTP_STATES_100[1]) then
    FConnection.FTimer.Enabled := True;  // ����� Accept Key
end;

constructor TRecvThread.Create(AConnection: TWSConnection);
{ var
  i: Integer;    }
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FConnection := AConnection;

  // ������ջ���
  GetMem(FRecvBuf.buf, IO_BUFFER_SIZE_2);
  FRecvBuf.len := IO_BUFFER_SIZE_2;

  // ��Ϣ�������������� TResultParams
  FReceiver := TWSClientReceiver.Create(FConnection,
                                        TJSONResult.Create(FConnection));

  FReceiver.OnAttachment := OnAttachment;  // ���ո�������
  FReceiver.OnPost := FConnection.FPostThread.Add;  // Ͷ�ŷ���
  FReceiver.OnReceive := OnReceive;  // ���ս���

{  FDebug.LoadFromFile('ms.txt');
  FStream.LoadFromFile('recv2.dat');

  for i := 0 to FDebug.Count - 1 do
  begin
    FOverlapped.InternalHigh := StrToInt(FDebug[i]);
    FStream.Read(FRecvBuf.buf^, FOverlapped.InternalHigh);
    HandleDataPacket;
  end;    }

end;

procedure TRecvThread.Execute;
var
  ByteCount, Flags: DWORD;
begin
  // ִ�� WSARecv���ȴ�����

  try
    FillChar(FOverlapped, SizeOf(TOverlapped), 0);
    FOverlapped.hEvent := DWORD(Self);  // �����Լ�

    ByteCount := 0;
    Flags := 0;

    // �����ݴ���ʱ����ϵͳ�Զ�����ִ�� WorkerRoutine
    iocp_Winsock2.WSARecv(FConnection.FSocket, @FRecvBuf, 1,
                          ByteCount, Flags, @FOverlapped, @WorkerRoutine);

    while (Terminated = False) do  // ���ϵȴ�
      if (SleepEx(100, True) = WAIT_IO_COMPLETION) then  // �����������ȴ�ģʽ
      begin
        // Empty
      end;
  finally
    FreeMem(FRecvBuf.buf);
    FReceiver.Free;
  end;
  
end;

procedure TRecvThread.HandleDataPacket;
begin
  // ������յ������ݰ�

  // �����ֽ�����
  Inc(FConnection.FRecvCount, FOverlapped.InternalHigh);

  if FReceiver.Complete then  // 1. �װ�����
  begin
    if MatchSocketType(FRecvBuf.buf, HTTP_VER) then  // HTTP ��Ϣ
      CheckUpgradeState(FRecvBuf.buf, FOverlapped.InternalHigh)
    else begin
//      FDebug.Add(IntToStr(FOverlapped.InternalHigh));
//      FStream.Write(FRecvBuf.buf^, FOverlapped.InternalHigh);
      FReceiver.Prepare(FRecvBuf.buf, FOverlapped.InternalHigh);  // ����
    end;
  end else
  begin
    // 2. ��������
    FReceiver.Receive(FRecvBuf.buf, FOverlapped.InternalHigh);
  end;

end;

procedure TRecvThread.OnAttachment(Result: TBaseJSON);
begin
  // �и�������ͬ�����ÿͻ����ж��Ƿ����
  FResult := TJSONResult(Result);
  FResult.FMsgType := mtJSON;
  Synchronize(FConnection.ReceiveAttachment);
end;

procedure TRecvThread.OnReceive(Result: TBaseJSON; FrameSize, RecvSize: Int64);
begin
  // ��ʾ���ս���
  if (Result.MsgId = FMsgId) then
    Inc(FCurrentSize, RecvSize)
  else begin  // �µ� JSON
    FMsgId := Result.MsgId;
    FFrameSize := FrameSize;
    FCurrentSize := RecvSize;
  end;
  Synchronize(FConnection.ShowRecvProgress);  // �л������߳�
end;

procedure TRecvThread.Stop;
begin
  inherited;
  Sleep(20);
end; 

{ initialization
  FDebug := TStringList.Create;
  FStream := TMemoryStream.Create;

finalization
  FDebug.SaveToFile('ms.txt');
  FStream.SaveToFile('recv2.dat');

  FStream.Free;
  FDebug.Free;   }

end.

