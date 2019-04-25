(*
 * iocp ����˸����׽��ַ�װ
 *)
unit iocp_sockets;

interface

{$I in_iocp.inc}        // ģʽ����

uses
  windows, Classes, SysUtils, Provider, Variants, DateUtils,
  iocp_base, iocp_zlib, iocp_api,
  iocp_Winsock2, iocp_wsExt, iocp_utils,
  iocp_baseObjs, iocp_objPools, iocp_senders,
  iocp_receivers, iocp_msgPacks, iocp_log,
  http_objects, iocp_WsJSON;

type

  // ================== �����׽��� �� ======================

  TRawSocket = class(TObject)
  private
    FConnected: Boolean;       // �Ƿ�����
    FErrorCode: Integer;       // �쳣����
    FPeerIP: String;           // IP
    FPeerIPPort: string;       // IP+Port
    FPeerPort: Integer;        // Port
    FSocket: TSocket;          // �׽���
    procedure InternalClose;    
  protected
    procedure IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer = nil); virtual;
    procedure SetPeerAddr(const Addr: PSockAddrIn);
  public
    constructor Create(AddSocket: Boolean);
    destructor Destroy; override;
    procedure Close; virtual;    
  public
    property Connected: Boolean read FConnected;
    property ErrorCode: Integer read FErrorCode;
    property PeerIP: String read FPeerIP;
    property PeerPort: Integer read FPeerPort;
    property PeerIPPort: String read FPeerIPPort;
    property Socket: TSocket read FSocket;
  public
    class function GetPeerIP(const Addr: PSockAddrIn): String;
  end;

  // ================== �����׽��� �� ======================

  TListenSocket = class(TRawSocket)
  public
    function Bind(Port: Integer; const Addr: String = ''): Boolean;
    function StartListen: Boolean;
  end;

  // ================== AcceptEx Ͷ���׽��� ======================

  TAcceptSocket = class(TRawSocket)
  private
    FListenSocket: TSocket;    // �����׽���
    FIOData: TPerIOData;       // �ڴ��
    FByteCount: Cardinal;      // Ͷ����
  public
    constructor Create(ListenSocket: TSocket);
    destructor Destroy; override;
    function AcceptEx: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure NewSocket; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function SetOption: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
  end;

  // ================== ҵ��ִ��ģ����� ======================

  TIOCPSocket = class;
  THttpSocket = class;
  TWebSocket  = class;

  TBaseWorker = class(TObject)
  protected
    FServer: TObject;           // TInIOCPServer ������
    FGlobalLock: TThreadLock;   // ȫ����
    FThreadIdx: Integer;        // ���
  protected
    procedure Execute(const ASocket: TIOCPSocket); virtual; abstract;
    procedure HttpExecute(const ASocket: THttpSocket); virtual; abstract;
    procedure WSExecute(const ASocket: TWebSocket); virtual; abstract;
  public
    property GlobalLock: TThreadLock read FGlobalLock; // ������ҵ���ʱ��
    property ThreadIdx: Integer read FThreadIdx;
  end;

  // ================== Socket ���� ======================
  // FState ״̬��
  // 1. ���� = 0���ر� = 9
  // 2. ռ�� = 1��TransmitFile ʱ +1���κ��쳣�� +1
  //    ������ֵ=1,2������ֵ��Ϊ�쳣��
  // 3. ���Թرգ�����=0��TransmitFile=2������Ŀ��У�������ֱ�ӹر�
  // 4. ����������=0 -> �ɹ�

  TBaseSocket = class(TRawSocket)
  private
    FLinkNode: PLinkRec;       // ��Ӧ�ͻ��˳ص� PLinkRec���������

    FRecvBuf: PPerIOData;      // �����õ����ݰ�
    FSender: TBaseTaskSender;  // ���ݷ����������ã�

    FObjPool: TIOCPSocketPool; // �����
    FServer: TObject;          // TInIOCPServer ������
    FWorker: TBaseWorker;      // ҵ��ִ���ߣ����ã�

    FByteCount: Cardinal;      // �����ֽ���
    FComplete: Boolean;        // �������/����ҵ��
    FRefCount: Integer;        // ������
    FState: Integer;           // ״̬��ԭ�Ӳ���������
    FTickCount: Cardinal;      // �ͻ��˷��ʺ�����
    FUseTransObj: Boolean;     // ʹ�� TTransmitObject ����

    FData: Pointer;            // ��������ݣ����û���չ

    function CheckDelayed(ATickCount: Cardinal): Boolean;
    function GetActive: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetBufferPool: TIODataPool; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetReference: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetSocketState: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}

    procedure InternalRecv(Complete: Boolean);
    procedure OnSendError(Sender: TObject);
  protected
    {$IFDEF TRANSMIT_FILE}      // TransmitFile ����ģʽ
    FTask: TTransmitObject;     // ��������������
    FTaskExists: Boolean;       // ��������
    procedure InterTransmit;    // ��������
    procedure InterFreeRes; virtual; abstract; // �ͷŷ�����Դ
    {$ENDIF}
    procedure ClearResources; virtual; abstract;
    procedure Clone(Source: TBaseSocket);  // ��¡��ת����Դ��
    procedure DoWork(AWorker: TBaseWorker; ASender: TBaseTaskSender);  // ҵ���̵߳������
    procedure ExecuteWork; virtual; abstract;  // �������
    procedure IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer = nil); override;
    procedure InterCloseSocket(Sender: TObject); virtual;
    procedure InternalPush(AData: PPerIOData); // �������
    procedure MarkIODataBuf(AData: PPerIOData); virtual;
    procedure SocketError(IOKind: TIODataType); virtual;
  public
    constructor Create(AObjPool: TIOCPSocketPool; ALinkNode: PLinkRec); virtual;
    destructor Destroy; override;

    // ��ʱ���
    function CheckTimeOut(ANowTickCount: Cardinal): Boolean;

    // �ر�
    procedure Close; override;  

    {$IFDEF TRANSMIT_FILE}
    procedure FreeTransmitRes;  // �ͷ� TransmitFile ����Դ
    {$ENDIF}

    // ����ǰ����
    function Lock(PushMode: Boolean): Integer; 

    // Ͷ�ݽ���
    procedure PostRecv; virtual;

    // Ͷ���¼�����ɾ�����ܾ����񡢳�ʱ
    procedure PostEvent(IOKind: TIODataType); virtual; abstract;

    // ���Թر�
    procedure TryClose;
  public
    property Active: Boolean read GetActive;
    property BufferPool: TIODataPool read GetBufferPool;
    property Complete: Boolean read FComplete;
    property LinkNode: PLinkRec read FLinkNode;
    property ObjPool: TIOCPSocketPool read FObjPool;
    property RecvBuf: PPerIOData read FRecvBuf;
    property Reference: Boolean read GetReference;
    property Sender: TBaseTaskSender read FSender;
    property SocketState: Boolean read GetSocketState;
    property Worker: TBaseWorker read FWorker;
  public
    // ���� Data���û�������չ
    property Data: Pointer read FData write FData;
  end;

  TBaseSocketClass = class of TBaseSocket;

  // ================== ԭʼ������ Socket ==================

  TStreamSocket = class(TBaseSocket)
  protected
    {$IFDEF TRANSMIT_FILE}
    procedure InterFreeRes; override;
    {$ENDIF}
    procedure ClearResources; override;
    procedure ExecuteWork; override;
  public
    procedure PostEvent(IOKind: TIODataType); override;
    procedure SendData(const Data: PAnsiChar; Size: Cardinal); overload; virtual;
    procedure SendData(const Msg: String); overload; virtual;
    procedure SendData(Handle: THandle); overload; virtual;
    procedure SendData(Stream: TStream); overload; virtual;
    procedure SendDataVar(Data: Variant); virtual; 
  end;

  // ================== C/S ģʽҵ���� ==================

  // 1. ����˽��յ�������

  TReceiveParams = class(TReceivePack)
  private
    FMsgHead: PMsgHead;      // Э��ͷλ��
    FSocket: TIOCPSocket;    // ����
  public
    constructor Create(AOwner: TIOCPSocket);
    function ToJSON: AnsiString; override;
    procedure CreateAttachment(const LocalPath: string); override;
  public
    property Socket: TIOCPSocket read FSocket;
    property AttachPath: string read GetAttachPath;
  end;

  // 2. �������ͻ��˵�����

  TReturnResult = class(TBaseMessage)
  private
    FSocket: TIOCPSocket;     // ����
    FSender: TBaseTaskSender; // ��������
    procedure ReturnHead(AActResult: TActionResult = arOK);
    procedure ReturnResult;
  public
    constructor Create(AOwner: TIOCPSocket); reintroduce;
    procedure LoadFromFile(const AFileName: String; OpenAtOnce: Boolean = False); override;
    procedure LoadFromVariant(const AProviders: array of TDataSetProvider;
                              const ATableNames: array of String); overload; override;
  public
    property ErrMsg: String read GetErrMsg write SetErrMsg;
    property Socket: TIOCPSocket read FSocket;
  public
    // ����Э��ͷ����
    property Action: TActionType read FAction;
    property ActResult: TActionResult read FActResult write FActResult;
    property AttachSize: TFileSize read FAttachSize;    
    property CheckType: TDataCheckType read FCheckType;
    property DataSize: Cardinal read FDataSize;
    property MsgId: TIOCPMsgId read FMsgId;
    property Offset: TFileSize read FOffset;
    property OffsetEnd: TFileSize read FOffsetEnd;
    property Owner: TMessageOwner read FOwner;
    property SessionId: Cardinal read FSessionId;
    property Target: TActionTarget read FTarget;
    property VarCount: Cardinal read FVarCount;
    property ZipLevel: TZipLevel read FZipLevel;
  end;

  TIOCPSocket = class(TBaseSocket)
  private
    FReceiver: TServerReceiver;// ���ݽ�����
    FParams: TReceiveParams;   // ���յ�����Ϣ����������
    FResult: TReturnResult;    // ���ص�����
    FEnvir: PEnvironmentVar;   // ����������Ϣ
    FAction: TActionType;      // �ڲ��¼�
    FSessionId: Cardinal;      // �Ի�ƾ֤ id
    function CreateSession: Cardinal;
    function SessionValid(ASession: Cardinal): Boolean;
    procedure SetLogoutState;
  protected
    {$IFDEF TRANSMIT_FILE}
    procedure InterFreeRes; override;
    {$ENDIF}  
    function CheckMsgHead(InBuf: PAnsiChar): Boolean;
    procedure ClearResources; override;
    procedure CreateResources; 
    procedure ExecuteWork; override;  // �������
    procedure HandleDataPack; 
    procedure IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer = nil); override;
    procedure ReturnMessage(ActResult: TActionResult; const ErrMsg: String = '');
    procedure SocketError(IOKind: TIODataType); override;
  public
    destructor Destroy; override;
  public
    // ҵ��ģ�����
    procedure Push(Target: TIOCPSocket = nil);
    procedure PostEvent(IOKind: TIODataType); override;
    procedure SetLogState(AEnvir: PEnvironmentVar);
    procedure SetUniqueMsgId;
  public
    property Action: TActionType read FAction;
    property Envir: PEnvironmentVar read FEnvir;
    property Params: TReceiveParams read FParams;
    property Result: TReturnResult read FResult;
    property SessionId: Cardinal read FSessionId;
  end;

  // ================== Http Э�� Socket ==================

  TRequestObject = class(THttpRequest);

  TResponeObject = class(THttpRespone);

  THttpSocket = class(TBaseSocket)
  private
    FRequest: THttpRequest;    // http ����
    FRespone: THttpRespone;    // http Ӧ��
    FStream: TFileStream;      // �����ļ�����
    FKeepAlive: Boolean;       // ��������
    FSessionId: AnsiString;    // Session Id
    procedure UpgradeSocket(SocketPool: TIOCPSocketPool);
    procedure DecodeHttpRequest;
  protected
    {$IFDEF TRANSMIT_FILE}
    procedure InterFreeRes; override;
    {$ENDIF}
    procedure ClearResources; override;
    procedure ExecuteWork; override;
    procedure SocketError(IOKind: TIODataType); override;
  public
    destructor Destroy; override;
    // �����¼�
    procedure PostEvent(IOKind: TIODataType); override;
    // �ļ�������
    procedure CreateStream(const FileName: String);
    procedure WriteStream(Data: PAnsiChar; DataLength: Integer);
    procedure CloseStream;
  public
    property Request: THttpRequest read FRequest;
    property Respone: THttpRespone read FRespone;
    property SessionId: AnsiString read FSessionId;
  end;

  // ================== WebSocket �� ==================

  // . �����ص� JSON ��Ϣ
  
  TResultJSON = class(TSendJSON)
  public
    property DataSet;
  end;
  
  TWebSocket = class(TStreamSocket)
  private
    FReceiver: TWSServerReceiver;  // ���ݽ�����
    FJSON: TBaseJSON;          // �յ��� JSON ����
    FResult: TResultJSON;      // Ҫ���ص� JSON ����
    FMsgType: TWSMsgType;      // ��������
    FOpCode: TWSOpCode;        // WebSocket ��������
    FRole: TClientRole;        // �ͻ�Ȩ�ޣ�Ԥ�裩
    FUserName: TNameString;    // �û����ƣ�Ԥ�裩
    procedure ClearMsgOwner(Buf: PAnsiChar; Len: Integer);
    procedure InternalPing;
  protected
    FData: PAnsiChar;          // �����յ�����������λ��
    FMsgSize: UInt64;          // ��ǰ��Ϣ�յ����ۼƳ���
    FFrameSize: UInt64;        // ��ǰ֡����
    FFrameRecvSize: UInt64;    // �����յ������ݳ���
    procedure InterPush(Target: TWebSocket = nil);
    procedure SetProps(AOpCode: TWSOpCode; AMsgType: TWSMsgType;
                       AData: Pointer; AFrameSize: Int64; ARecvSize: Cardinal);
  protected
    procedure ClearResources; override;
    procedure ExecuteWork; override;
  public
    constructor Create(AObjPool: TIOCPSocketPool; ALinkNode: PLinkRec); override;
    destructor Destroy; override;

    procedure PostEvent(IOKind: TIODataType); override;
    procedure SendData(const Data: PAnsiChar; Size: Cardinal); overload; override;
    procedure SendData(const Msg: String); overload; override;
    procedure SendData(Handle: THandle); overload; override;
    procedure SendData(Stream: TStream); overload; override;
    procedure SendDataVar(Data: Variant); override;

    procedure SendResult(UTF8CharSet: Boolean = False);
  public
    property Data: PAnsiChar read FData;  // raw
    property FrameRecvSize: UInt64 read FFrameRecvSize; // raw
    property FrameSize: UInt64 read FFrameSize; // raw
    property MsgSize: UInt64 read FMsgSize; // raw

    property JSON: TBaseJSON read FJSON; // JSON
    property Result: TResultJSON read FResult; // JSON
  public
    property MsgType: TWSMsgType read FMsgType; // ��������
    property OpCode: TWSOpCode read FOpCode;  // WebSocket ����
  public
    property Role: TClientRole read FRole write FRole;
    property UserName: TNameString read FUserName write FUserName;
  end;

  // ================== TSocketBroker �����׽��� ==================

  TSocketBroker = class;

  TAcceptBroker = procedure(Sender: TSocketBroker; const Host: AnsiString;
                            Port: Integer; var Accept: Boolean) of object;

  TBindIPEvent  = procedure(Sender: TSocketBroker; const Data: PAnsiChar;
                            DataSize: Cardinal) of object;

  TOuterPingEvent = TBindIPEvent;

  TSocketBroker = class(TBaseSocket)
  private
    FAction: Integer;          // ��ʼ��
    FBroker: TObject;          // �������
    FCmdConnect: Boolean;      // HTTP ����ģʽ

    FDualBuf: PPerIOData;      // �����׽��ֵĽ����ڴ��
    FDualConnected: Boolean;   // �����׽�������״̬
    FDualSocket: TSocket;      // �������׽���

    FRecvState: Integer;       // ����״̬
    FSocketType: TSocketBrokerType;  // ����
    FTargetHost: AnsiString;   // ������������ַ
    FTargetPort: Integer;      // �����ķ������˿�

    FOnBind: TBindIPEvent;     // ���¼�

    // �µ�Ͷ�ŷ��� 
    procedure BrokerPostRecv(ASocket: TSocket; AData: PPerIOData; ACheckState: Boolean = True);
    // HTTP Э��İ�
    procedure HttpBindOuter(Connection: TSocketBroker; const Data: PAnsiChar; DataSize: Cardinal);
  protected
    FBrokerId: AnsiString;     // �����ķ������ Id
    procedure ClearResources; override;
    procedure ExecuteWork; override;
    procedure IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer = nil); override;
    procedure InterCloseSocket(Sender: TObject); override;
    procedure MarkIODataBuf(AData: PPerIOData); override;
  protected
    procedure AssociateInner(InnerBroker: TSocketBroker);
    procedure SendInnerFlag;
    procedure SetConnection(AServer: TObject; Connection: TSocket);
  public
    procedure CreateBroker(const AServer: AnsiString; APort: Integer);  // �������м�
    procedure PostEvent(IOKind: TIODataType); override;
  end;

implementation

uses
  iocp_server, http_base, http_utils, iocp_threads, iocp_managers;

type
  THeadMessage = class(TBaseMessage);
  TIOCPBrokerRef = class(TInIOCPBroker);

{ TRawSocket }

procedure TRawSocket.Close;
begin
  if FConnected then
    InternalClose;  // �ر�
end;

constructor TRawSocket.Create(AddSocket: Boolean);
begin
  inherited Create;
  if AddSocket then  // ��һ�� Socket
    IniSocket(nil, iocp_utils.CreateSocket);
end;

destructor TRawSocket.Destroy;
begin
  if FConnected then
    InternalClose; // �ر�
  inherited;
end;

class function TRawSocket.GetPeerIP(const Addr: PSockAddrIn): String;
begin
  // ȡIP
  Result := iocp_Winsock2.inet_ntoa(Addr^.sin_addr);
end;

procedure TRawSocket.IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer);
begin
  // ���� Socket
  FSocket := ASocket;
  FConnected := FSocket <> INVALID_SOCKET;
end;

procedure TRawSocket.InternalClose;
begin
  // �ر� Socket
  try
    iocp_Winsock2.Shutdown(FSocket, SD_BOTH);
    iocp_Winsock2.CloseSocket(FSocket);
    FSocket := INVALID_SOCKET;
  finally
    FConnected := False;
  end;
end;

procedure TRawSocket.SetPeerAddr(const Addr: PSockAddrIn);
begin
  // �ӵ�ַ��Ϣȡ IP��Port
  FPeerIP := iocp_Winsock2.inet_ntoa(Addr^.sin_addr);
  FPeerPort := Addr^.sin_port;
  FPeerIPPort := FPeerIP + ':' + IntToStr(FPeerPort);
end;

{ TListenSocket }

function TListenSocket.Bind(Port: Integer; const Addr: String): Boolean;
var
  SockAddr: TSockAddrIn;
begin
  // �󶨵�ַ
  // htonl(INADDR_ANY); ���κε�ַ������������ϼ���
  FillChar(SockAddr, SizeOf(TSockAddr), 0);

  SockAddr.sin_family := AF_INET;
  SockAddr.sin_port := htons(Port);
  SockAddr.sin_addr.S_addr := inet_addr(PAnsiChar(ResolveHostIP(Addr)));

  if (iocp_Winsock2.bind(FSocket, TSockAddr(SockAddr), SizeOf(TSockAddr)) <> 0) then
  begin
    Result := False;
    FErrorCode := WSAGetLastError;
    iocp_log.WriteLog('TListenSocket.Bind->Error:' + IntToStr(FErrorCode));
  end else
  begin
    Result := True;
    FErrorCode := 0;
  end;
end;

function TListenSocket.StartListen: Boolean;
begin
  // ����
  if (iocp_Winsock2.listen(FSocket, MaxInt) <> 0) then
  begin
    Result := False;
    FErrorCode := WSAGetLastError;
    iocp_log.WriteLog('TListenSocket.StartListen->Error:' + IntToStr(FErrorCode));
  end else
  begin
    Result := True;
    FErrorCode := 0;
  end;
end;

{ TAcceptSocket }

function TAcceptSocket.AcceptEx: Boolean;
begin
  // Ͷ�� AcceptEx ����
  FillChar(FIOData.Overlapped, SizeOf(TOverlapped), 0);

  FIOData.Owner := Self;       // ����
  FIOData.IOType := ioAccept;  // ������
  FByteCount := 0;

  Result := gAcceptEx(FListenSocket, FSocket,
                      Pointer(FIOData.Data.buf), 0,   // �� 0�����ȴ���һ������
                      ADDRESS_SIZE_16, ADDRESS_SIZE_16,
                      FByteCount, @FIOData.Overlapped);

  if Result then
    FErrorCode := 0
  else begin
    FErrorCode := WSAGetLastError;
    Result := FErrorCode = WSA_IO_PENDING;
    if (Result = False) then
      iocp_log.WriteLog('TAcceptSocket.AcceptEx->Error:' + IntToStr(FErrorCode));
  end;
end;

constructor TAcceptSocket.Create(ListenSocket: TSocket);
begin
  inherited Create(True);
  // �½� AcceptEx �õ� Socket
  FListenSocket := ListenSocket;
  GetMem(FIOData.Data.buf, ADDRESS_SIZE_16 * 2);  // ����һ���ڴ�
  FIOData.Data.len := ADDRESS_SIZE_16 * 2;
  FIOData.Node := nil;  // ��
end;

destructor TAcceptSocket.Destroy;
begin
  FreeMem(FIOData.Data.buf);  // �ͷ��ڴ��
  inherited;
end;

procedure TAcceptSocket.NewSocket;
begin
  // �½� Socket
  FSocket := iocp_utils.CreateSocket;
end;

function TAcceptSocket.SetOption: Boolean;
begin
  // ���� FListenSocket �����Ե� FSocket
  Result := iocp_Winsock2.setsockopt(FSocket, SOL_SOCKET,
                 SO_UPDATE_ACCEPT_CONTEXT, PAnsiChar(@FListenSocket),
                 SizeOf(TSocket)) <> SOCKET_ERROR;
end;

{ TBaseSocket }

constructor TBaseSocket.Create(AObjPool: TIOCPSocketPool; ALinkNode: PLinkRec);
begin
  inherited Create(False);
  // FSocket �ɿͻ��˽���ʱ����
  //   ����TInIOCPServer.AcceptClient
  //       TIOCPSocketPool.CreateObjData
  FObjPool := AObjPool; 
  FLinkNode := ALinkNode;
  FUseTransObj := True;  
end;

function TBaseSocket.CheckDelayed(ATickCount: Cardinal): Boolean;
begin
  // ȡ������ʱ��Ĳ�
  if (ATickCount >= FTickCount) then
    Result := ATickCount - FTickCount <= 3000
  else
    Result := High(Cardinal) - ATickCount + FTickCount <= 3000;
  {$IFDEF TRANSMIT_FILE}
  if Assigned(FTask) then  // TransmitFile û������
    Result := Result and (FTask.Exists = False);
  {$ENDIF}
end;

function TBaseSocket.CheckTimeOut(ANowTickCount: Cardinal): Boolean;
  function GetTickCountDiff: Boolean;
  begin
    if (ANowTickCount >= FTickCount) then
      Result := ANowTickCount - FTickCount >= TInIOCPServer(FServer).TimeOut
    else
      Result := High(Cardinal) - FTickCount + ANowTickCount >= TInIOCPServer(FServer).TimeOut;
  end;
begin
  // ��ʱ���
  if (FTickCount = NEW_TICKCOUNT) then  // Ͷ�ż��Ͽ�������TBaseSocket.SetSocket
  begin
    Inc(FByteCount);  // ByteCount +
    Result := (FByteCount >= 5);  // ��������
  end else
    Result := GetTickCountDiff;
end;

procedure TBaseSocket.Clone(Source: TBaseSocket);
begin
  // ����任���� Source ���׽��ֵ���Դת�Ƶ��¶���
  // �� TIOCPSocketPool �������ã���ֹ�����Ϊ��ʱ

  // ת�� Source ���׽��֡���ַ
  IniSocket(Source.FServer, Source.FSocket, Source.FData);

  FPeerIP := Source.FPeerIP;
  FPeerPort := Source.FPeerPort;
  FPeerIPPort := Source.FPeerIPPort;

  // ��� Source ����Դֵ
  // Source.FServer ���䣬�ͷ�ʱҪ��飺TBaseSocket.Destroy
  Source.FData := nil;
  
  Source.FPeerIP := '';
  Source.FPeerPort := 0;
  Source.FPeerIPPort := '';

  Source.FConnected := False;
  Source.FSocket := INVALID_SOCKET;
   
  // δ�� FTask  
end;

procedure TBaseSocket.Close;
begin
  ClearResources;  // ֻ�����Դ�����ͷţ��´β����½�
  inherited;
end;

destructor TBaseSocket.Destroy;
begin
  {$IFDEF TRANSMIT_FILE}
  if Assigned(FTask) then
    FTask.Free;
  {$ENDIF}
  if TInIOCPServer(FServer).Active and Assigned(FRecvBuf) then
  begin
    BufferPool.Push(FRecvBuf^.Node);  // �����ڴ��
    FRecvBuf := Nil;
  end;
  inherited;
end;

procedure TBaseSocket.DoWork(AWorker: TBaseWorker; ASender: TBaseTaskSender);
begin
  // ��ʼ��
  // ����������� FWorker��FSender Ϊ Nil

  {$IFDEF TRANSMIT_FILE}
  if FUseTransObj then
  begin
    if (Assigned(FTask) = False) then
    begin
      FTask := TTransmitObject.Create(Self); // TransmitFile ����
      FTask.OnError := OnSendError;
    end;
    FTask.Socket := FSocket;
    FTaskExists := False; // ����
  end;
  {$ENDIF}
  
  FErrorCode := 0;      // ���쳣
  FByteCount := FRecvBuf^.Overlapped.InternalHigh;  // �յ��ֽ���

  FWorker := AWorker;   // ִ����
  FSender := ASender;   // ������

  FSender.Owner := Self;
  FSender.Socket := FSocket;
  FSender.OnError := OnSendError;

  // ִ������
  ExecuteWork;
    
end;

{$IFDEF TRANSMIT_FILE}
procedure TBaseSocket.FreeTransmitRes;
begin
  // �����̵߳��ã�TransmitFile �������
  if (windows.InterlockedDecrement(FState) = 1) then  // FState=2 -> �����������쳣
    InterFreeRes // ������ʵ�֣���ʽ�ͷŷ�����Դ���ж��Ƿ����Ͷ�� WSARecv��
  else
    InterCloseSocket(Self);
end;
{$ENDIF}

function TBaseSocket.GetActive: Boolean;
begin
  // ����ǰȡ��ʼ��״̬�����չ����ݣ�
  Result := (iocp_api.InterlockedCompareExchange(Integer(FByteCount), 0, 0) > 0);
end;

function TBaseSocket.GetBufferPool: TIODataPool;
begin
  // ȡ�ڴ��
  Result := TInIOCPServer(FServer).IODataPool;
end;

function TBaseSocket.GetReference: Boolean;
begin
  // ����ʱ���ã�ҵ������ FRecvBuf^.RefCount��
  Result := windows.InterlockedIncrement(FRefCount) = 1;
end;

function TBaseSocket.GetSocketState: Boolean;
begin
  // ȡ״̬, FState = 1 ˵������
  Result := iocp_api.InterlockedCompareExchange(FState, 1, 1) = 1;
end;

procedure TBaseSocket.InternalPush(AData: PPerIOData);
var
  ByteCount, Flags: Cardinal;
begin
  // ������Ϣ�������̵߳��ã�
  //  AData��TPushMessage.FPushBuf

  // ���ص��ṹ
  FillChar(AData^.Overlapped, SizeOf(TOverlapped), 0);

  FErrorCode := 0;
  FRefCount := 0;  // AData:Socket = 1:n
  FTickCount := GetTickCount;  // +

  ByteCount := 0;
  Flags := 0;

  if (Windows.InterlockedDecrement(FState) <> 0) then
    InterCloseSocket(Self)
  else
    if (iocp_Winsock2.WSASend(FSocket, @(AData^.Data), 1, ByteCount,
        Flags, LPWSAOVERLAPPED(@AData^.Overlapped), nil) = SOCKET_ERROR) then
    begin
      FErrorCode := WSAGetLastError;
      if (FErrorCode <> ERROR_IO_PENDING) then  // �쳣
      begin
        SocketError(AData^.IOType);
        InterCloseSocket(Self);  // �ر�
      end else
        FErrorCode := 0;
    end;

end;

procedure TBaseSocket.InternalRecv(Complete: Boolean);
var
  ByteCount, Flags: DWORD;
begin
  // �������������ύһ����������

  // δ������ɣ����̳�ʱʱ�䣨�����⹥����
  if (Complete = False) and (TInIOCPServer(FServer).TimeOut > 0) then
    Dec(FTickCount, 10000);

  // ���ص��ṹ
  FillChar(FRecvBuf^.Overlapped, SizeOf(TOverlapped), 0);

  FRecvBuf^.Owner := Self;  // ����
  FRecvBuf^.IOType := ioReceive;  // iocp_server ���ж���
  FRecvBuf^.Data.len := IO_BUFFER_SIZE; // �ָ�

  ByteCount := 0;
  Flags := 0;

  // ����ʱ FState=1�������κ�ֵ��˵���������쳣��
  // FState-��FState <> 0 -> �쳣�ı���״̬���رգ�

  if (Windows.InterlockedDecrement(FState) <> 0) then
    InterCloseSocket(Self)
  else  // FRecvBuf^.Overlapped �� TPerIOData ͬ��ַ
    if (iocp_Winsock2.WSARecv(FSocket, @(FRecvBuf^.Data), 1, ByteCount,
        Flags, LPWSAOVERLAPPED(@FRecvBuf^.Overlapped), nil) = SOCKET_ERROR) then
    begin
      FErrorCode := WSAGetLastError;
      if (FErrorCode <> ERROR_IO_PENDING) then  // �쳣
      begin
        SocketError(ioReceive);
        InterCloseSocket(Self);  // �ر�
      end else
        FErrorCode := 0;
    end;

  // Ͷ����ɣ��� FByteCount > 0, ���Խ���������Ϣ��, ͬʱע�ⳬʱ���
  //   ����CheckTimeOut��TPushThread.DoMethod��TIOCPSocketPool.GetSockets
  if (FByteCount = 0) then
    FByteCount := 1;  // ����̫�󣬷���ʱ

  // �������  
  if (FComplete <> Complete) then
    FComplete := Complete;
    
end;

function TBaseSocket.Lock(PushMode: Boolean): Integer;
const
  SOCKET_STATE_IDLE  = 0;  // ����
  SOCKET_STATE_BUSY  = 1;  // ����
  SOCKET_STATE_TRANS = 2;  // TransmitFile ���� 
begin
  // ����ǰ����
  //  ״̬ FState = 0 -> 1, ���ϴ�������� -> �ɹ���
  //  �Ժ��� Socket �ڲ����κ��쳣�� FState+
  case iocp_api.InterlockedCompareExchange(FState, 1, 0) of  // ����ԭֵ

    SOCKET_STATE_IDLE: begin
      if PushMode then   // ����ģʽ
      begin
        if FComplete then
          Result := SOCKET_LOCK_OK
        else
          Result := SOCKET_LOCK_FAIL;
      end else
      begin
        // ҵ���߳�ģʽ������TWorkThread.HandleIOData
        Result := SOCKET_LOCK_OK;     // ��������
      end;
      if (Result = SOCKET_LOCK_FAIL) then // ҵ��δ��ɣ�������
        if (windows.InterlockedDecrement(FState) <> 0) then
          InterCloseSocket(Self);
    end;

    SOCKET_STATE_BUSY:
      Result := SOCKET_LOCK_FAIL;     // ����

    SOCKET_STATE_TRANS:
      if FUseTransObj then
        Result := SOCKET_LOCK_FAIL    // ����
      else
        Result := SOCKET_LOCK_CLOSE;  // �쳣

    else
      Result := SOCKET_LOCK_CLOSE;    // �ѹرջ������쳣
  end;
end;

procedure TBaseSocket.MarkIODataBuf(AData: PPerIOData);
begin
  // ��
end;

procedure TBaseSocket.IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer);
begin
  inherited;

  FServer := AServer;// ����������ǰ��
  FData := AData;    // ��չ����

  // ��������ڴ�飨�ͷ�ʱ���գ�
  if (FRecvBuf = nil) then
  Begin
    FRecvBuf := BufferPool.Pop^.Data; // �� FServer ��ֵ��
    FRecvBuf^.IOType := ioReceive;  // ����
    FRecvBuf^.Owner := Self;  // ����
  End;

  FByteCount := 0;   // �������ݳ���
  FComplete := True; // �ȴ�����
  FErrorCode := 0;   // ���쳣
  FState := 9;       // ��Ч״̬��Ͷ�� Recv ������ʽʹ��

  // ���ֵ����ֹ�����Ϊ��ʱ��
  //   ����TTimeoutThread.ExecuteWork
  FTickCount := NEW_TICKCOUNT;
end;

procedure TBaseSocket.InterCloseSocket(Sender: TObject);
begin
  // �ڲ��ر�
  windows.InterlockedExchange(Integer(FByteCount), 0); // ������������
  windows.InterlockedExchange(FState, 9);  // ��Ч״̬
  TInIOCPServer(FServer).CloseSocket(Self);  // �ùر��̣߳������ظ��رգ�
end;

{$IFDEF TRANSMIT_FILE}
procedure TBaseSocket.InterTransmit;
begin
  if FTask.Exists then
  begin
    FTaskExists := True;
    windows.InterlockedIncrement(FState);  // FState+������ʱ=2
    FTask.TransmitFile;
  end;
end;
{$ENDIF}

procedure TBaseSocket.OnSendError(Sender: TObject);
begin
  // �������쳣�Ļص�����
  //   ����TBaseSocket.DoWork��TBaseTaskObject.Send...
  FErrorCode := TBaseTaskObject(Sender).ErrorCode;
  Windows.InterlockedIncrement(FState);  // FState+
  SocketError(TBaseTaskObject(Sender).IOType);
end;

procedure TBaseSocket.PostRecv;
begin
  // ����ʱͶ�Ž��ջ���
  //   ����TInIOCPServer.AcceptClient��THttpSocket.ExecuteWork
  FState := 1;  // �跱æ
  InternalRecv(True); // Ͷ��ʱ FState-
end;

procedure TBaseSocket.SocketError(IOKind: TIODataType);
const
  PROCEDURE_NAMES: array[ioReceive..ioTimeOut] of string = (
                   'Post WSARecv->', 'Post WSASend->',
                   {$IFDEF TRANSMIT_FILE} 'TransmitFile->', {$ENDIF}
                   'InternalPush->', 'InternalPush->',
                   'InternalPush->');
begin
  // д�쳣��־
  if Assigned(FWorker) then  // �����ʹ���Ͷ�ţ�û�� FWorker
    iocp_log.WriteLog(PROCEDURE_NAMES[IOKind] + PeerIPPort +
                      ',Error:' + IntToStr(FErrorCode) +
                      ',BusiThread:' + IntToStr(FWorker.ThreadIdx));
end;

procedure TBaseSocket.TryClose;
begin
  // ���Թر�
  // FState+, ԭֵ: 0,2,3... <> 1 -> �ر�
  if (windows.InterlockedIncrement(FState) in [1, 3]) then // <> 2
    InterCloseSocket(Self);
end;

{ TStreamSocket }

procedure TStreamSocket.ClearResources;
begin
  {$IFDEF TRANSMIT_FILE}
  if Assigned(FTask) then
    FTask.FreeResources(True);
  {$ENDIF}
end;

procedure TStreamSocket.ExecuteWork;
begin
  // ֱ�ӵ��� Server �� OnDataReceive �¼���δ�ؽ�����ϣ�
  try
    FTickCount := GetTickCount;
    if Assigned(TInIOCPServer(FServer).OnDataReceive) then
      TInIOCPServer(FServer).OnDataReceive(Self, FRecvBuf^.Data.buf, FByteCount);
  finally
    {$IFDEF TRANSMIT_FILE}
    if (FTaskExists = False) then {$ENDIF}
      InternalRecv(True);  // ��������
  end;
end;

procedure TStreamSocket.PostEvent(IOKind: TIODataType);
begin
  // Empty
end;

{$IFDEF TRANSMIT_FILE}
procedure TStreamSocket.InterFreeRes;
begin
  // �ͷ� TransmitFile �ķ�����Դ������Ͷ�Ž��գ�
  try
    ClearResources;
  finally
    InternalRecv(True);
  end;
end;
{$ENDIF}

procedure TStreamSocket.SendData(const Data: PAnsiChar; Size: Cardinal);
var
  Buf: PAnsiChar;
begin
  // �����ڴ�����ݣ����� Data��
  if Assigned(Data) and (Size > 0) then
  begin
    GetMem(Buf, Size);
    System.Move(Data^, Buf^, Size);
    {$IFDEF TRANSMIT_FILE}
    FTask.SetTask(Buf, Size);
    InterTransmit;
    {$ELSE}
    FSender.Send(Buf, Size);
    {$ENDIF}
  end;
end;

procedure TStreamSocket.SendData(const Msg: String);
begin
  // �����ı�
  if (Msg <> '') then
  begin
    {$IFDEF TRANSMIT_FILE}
    FTask.SetTask(Msg);
    InterTransmit;
    {$ELSE}
    FSender.Send(Msg);
    {$ENDIF}
  end;
end;

procedure TStreamSocket.SendData(Handle: THandle);
begin
  // �����ļ� handle���Զ��رգ�
  if (Handle > 0) and (Handle <> INVALID_HANDLE_VALUE) then
  begin
    {$IFDEF TRANSMIT_FILE}
    FTask.SetTask(Handle, GetFileSize64(Handle));
    InterTransmit;
    {$ELSE}
    FSender.Send(Handle, GetFileSize64(Handle));
    {$ENDIF}
  end;
end;

procedure TStreamSocket.SendData(Stream: TStream);
begin
  // ���������ݣ��Զ��ͷţ�
  if Assigned(Stream) then
  begin
    {$IFDEF TRANSMIT_FILE}
    FTask.SetTask(Stream, Stream.Size);
    InterTransmit;
    {$ELSE}
    FSender.Send(Stream, Stream.Size, True);
    {$ENDIF}
  end;
end;

procedure TStreamSocket.SendDataVar(Data: Variant);
begin
  // ���Ϳɱ���������
  if (VarIsNull(Data) = False) then
  begin
    {$IFDEF TRANSMIT_FILE}
    FTask.SetTaskVar(Data);
    InterTransmit;
    {$ELSE}
    FSender.SendVar(Data);
    {$ENDIF}
  end;
end;

{ TReceiveParams }

constructor TReceiveParams.Create(AOwner: TIOCPSocket);
begin
  inherited Create;
  FSocket := AOwner;
end;

procedure TReceiveParams.CreateAttachment(const LocalPath: string);
begin
  inherited;      
  // ���������ո���
  if Error then  // ���ִ���
    FSocket.FResult.ActResult := arFail
  else begin
    FSocket.FAction := atAfterReceive; // ����ʱִ���¼�
    FSocket.FResult.FActResult := arAccept;  // �����ϴ�

    // ����
    if (FAction in FILE_CHUNK_ACTIONS) then
    begin
      // ����·�������ظ��ͻ���
      FSocket.FResult.SetAttachPath(iocp_utils.EncryptString(LocalPath));

      // ԭ�����ؿͻ��˵� ·��+�ļ���...
      FSocket.FResult.SetFileSize(GetFileSize);
      FSocket.FResult.SetDirectory(Directory);
      FSocket.FResult.SetFileName(FileName);
      FSocket.FResult.SetNewCreatedFile(GetNewCreatedFile);
    end;

    FSocket.FReceiver.Complete := False;  // �ָ������ո���
  end;
end;

function TReceiveParams.ToJSON: AnsiString;
begin
  Result := inherited ToJSON;
end;

{ TReturnResult }

constructor TReturnResult.Create(AOwner: TIOCPSocket);
begin
  inherited Create(nil);  // �ý��յ� Owner
  FSocket := AOwner;
end;

procedure TReturnResult.LoadFromFile(const AFileName: String; OpenAtOnce: Boolean);
begin
  // ���̴��ļ����ȴ�����
  if (FileExists(AFileName) = False) then
  begin
    FActResult := arMissing;
    FOffset := 0;
    FOffsetEnd := 0;
  end else
  begin
    inherited;
    if (FAction = atFileDownChunk) then  // �ϵ�����
    begin
      // FParams.FOffsetEnd ת��, ����������, == �ͻ��� FMaxChunkSize
      FOffset := FSocket.FParams.FOffset;  // ����λ��
      AdjustTransmitRange(FSocket.FParams.FOffsetEnd);
      // ���ؿͻ����ļ���������·�������ܣ����ͻ���
      SetFileName(FSocket.FParams.FileName);
      SetAttachPath(iocp_utils.EncryptString(ExtractFilePath(AFileName)));
    end;
    if Error then
      FActResult := arFail
    else
      FActResult := arOK;
  end;
end;

procedure TReturnResult.LoadFromVariant(const AProviders: array of TDataSetProvider;
  const ATableNames: array of String);
begin
  inherited; // ֱ�ӵ���
end;

procedure TReturnResult.ReturnHead(AActResult: TActionResult);
begin
  // ����Э��ͷ���ͻ��ˣ���Ӧ��������Ϣ��
  //   ��ʽ��IOCP_HEAD_FLAG + TMsgHead

  // ����Э��ͷ��Ϣ
  FDataSize := 0;
  FAttachSize := 0;
  FActResult := AActResult;

  if (FAction = atUnknown) then  // ��Ӧ
    FVarCount := FSocket.ObjPool.UsedCount // �ͻ���Ҫ�ж�
  else
    FVarCount := 0;

  // ֱ��д�� FSender �ķ��ͻ���
  LoadHead(FSender.Data);

  // ���ͣ����� = ByteCount��
  FSender.SendBuffers;
end;

procedure TReturnResult.ReturnResult;
  procedure SendMsgHeader;
  begin
    // ����Э��ͷ��������
    LoadHead(FSender.Data);
    FSender.SendBuffers;
  end;
  procedure SendMainStream;
  begin
    // ��������������
    {$IFDEF TRANSMIT_FILE}
    // ��������������
    FSocket.FTask.SetTask(FMain, FDataSize);
    {$ELSE}
    FSender.Send(FMain, FDataSize, False);  // ���ر���Դ
    {$ENDIF}
  end;
  procedure SendAttachmentStream;
  begin
    // ���͸�������
    {$IFDEF TRANSMIT_FILE}
    // ���ø���������
    if (FAction = atFileDownChunk) then
      FSocket.FTask.SetTask(FAttachment, FAttachSize, FOffset, FOffsetEnd)
    else
      FSocket.FTask.SetTask(FAttachment, FAttachSize);
    {$ELSE}
    // ���ر���Դ
    if (FAction = atFileDownChunk) then
      FSender.Send(FAttachment, FAttachSize, FOffset, FOffsetEnd, False)
    else
      FSender.Send(FAttachment, FAttachSize, False);
    {$ENDIF}
  end;
begin
  // ���ͽ�����ͻ��ˣ���������ֱ�ӷ���
  //  �������� TIOCPDocument����Ҫ�ã������ͷ�
  //   ����TIOCPSocket.HandleDataPack; TClientParams.InternalSend

  // FSender.Socket��Owner �Ѿ�����

  try
    // 1. ׼��������
    CreateStreams;

    if (Error = False) then
    begin
      // 2. ��Э��ͷ
      SendMsgHeader;

      // 3. �������ݣ��ڴ�����
      if (FDataSize > 0) then
        SendMainStream;

      // 4. ���͸�������
      if (FAttachSize > 0) then
        SendAttachmentStream;
    end;
  finally
    {$IFDEF TRANSMIT_FILE}
    FSocket.InterTransmit;
    {$ELSE}
    NilStreams(False);  // 5. ��գ��ݲ��ͷŸ�����
    {$ENDIF}
  end;

end;

{ TIOCPSocket }

function TIOCPSocket.CheckMsgHead(InBuf: PAnsiChar): Boolean;
  function CheckLogState: TActionResult;
  begin
    // ����¼״̬
    if (FParams.Action = atUserLogin) then
      Result := arOK       // ͨ��
    else
    if (FParams.SessionId = 0) then
      Result := arErrUser  // �ͻ���ȱ�� SessionId, ���Ƿ��û�
    else
    if (FParams.SessionId = INI_SESSION_ID) or
       (FParams.SessionId = FSessionId) then
      Result := arOK       // ͨ��
    else
    if SessionValid(FParams.SessionId) then
      Result := arOK       // ͨ��
    else
      Result := arOutDate; // ƾ֤����
  end;
begin
  // ����һ�������ݰ�����Ч�ԡ��û���¼״̬�������� http Э�飩

  if (FByteCount < IOCP_SOCKET_SIZE) or  // ����̫��
     (MatchSocketType(InBuf, IOCP_SOCKET_FLAG) = False) then // C/S ��־����
  begin
    // �رշ���
    InterCloseSocket(Self);
    Result := False;
  end else
  begin
    // ������
    Result := True;
    FAction := atUnknown;  // �ڲ��¼������ڸ������䣩
    FResult.FSender := FSender;

    // �ȸ���Э��ͷ
    FParams.FMsgHead := PMsgHead(InBuf + IOCP_SOCKET_FLEN); // ����ʱ��
    FParams.SetHeadMsg(FParams.FMsgHead);
    FResult.SetHeadMsg(FParams.FMsgHead, True);

    if (FParams.Action = atUnknown) then  // 1. ��Ӧ����
      FReceiver.Complete := True
    else begin
      // 2. ����¼״̬
      if Assigned(TInIOCPServer(FServer).ClientManager) then
        FResult.ActResult := CheckLogState
      else begin // ���¼
        FResult.ActResult := arOK;
        if (FParams.FSessionId = INI_SESSION_ID) then
          FResult.FSessionId := CreateSession;
      end;
      if (FResult.ActResult in [arOffline, arOutDate]) then
        FReceiver.Complete := True  // 3. �������
      else // 4. ׼������
        FReceiver.Prepare(InBuf, FByteCount);
    end;
  end;
end;

procedure TIOCPSocket.ClearResources;
begin
  // �����Դ
  if Assigned(FResult) then
    FReceiver.Clear;
  if Assigned(FParams) then
    FParams.Clear;
  if Assigned(FResult) then
    FResult.Clear;
  SetLogoutState;     // �ǳ�
  {$IFDEF TRANSMIT_FILE}
  if Assigned(FTask) then  
    FTask.FreeResources(False);  // ���� FResult.Clear �ͷ�
  {$ENDIF}
end;

procedure TIOCPSocket.CreateResources;
begin
  // ����Դ�����ա��������/���������ݽ�����
  if (FReceiver = nil) then
  begin
    FParams := TReceiveParams.Create(Self);  // ��ǰ
    FResult := TReturnResult.Create(Self);
    FReceiver := TServerReceiver.Create(FParams); // �ں�
  end else
  if FReceiver.Complete then
  begin
    FParams.Clear;
    FResult.Clear;
  end;
end;

function TIOCPSocket.CreateSession: Cardinal;
var
  NowTime: TDateTime;
  Certify: TCertifyNumber;
  LHour, LMinute, LSecond, LMilliSecond: Word;
begin
  // ����һ����¼ƾ֤����Ч��Ϊ SESSION_TIMEOUT ����
  //   �ṹ��(�������� + ��Ч����) xor ��
  NowTime := Now();

  DecodeTime(NowTime, LHour, LMinute, LSecond, LMilliSecond);

  Certify.DayCount := Trunc(NowTime - 43000);  // ��������
  Certify.Timeout := LHour * 60 + LMinute + SESSION_TIMEOUT;

  if (Certify.Timeout >= 1440) then  // ����һ��ķ�����
  begin
    Inc(Certify.DayCount);  // ��һ��
    Dec(Certify.Timeout, 1440);
  end;

  Result := Certify.Session xor Cardinal($AB12);
end;

destructor TIOCPSocket.Destroy;
begin
  // �ͷ���Դ
  if Assigned(FReceiver) then
  begin
    FReceiver.Free;
    FReceiver := Nil;
  end;
  if Assigned(FParams) then
  begin
    FParams.Free;
    FParams := Nil;
  end;
  if Assigned(FResult) then
  begin
    FResult.Free;
    FResult := Nil;
  end;
  inherited;
end;

procedure TIOCPSocket.ExecuteWork;
const
  IO_FIRST_PACKET = True;  // �����ݰ�
  IO_SUBSEQUENCE  = False; // �������ݰ�
begin
  // �������� FRecvBuf

  // ����Դ
  CreateResources;   

  {$IFNDEF DELPHI_7}
  {$REGION '+ ��������'}
  {$ENDIF}
  
  // 1. ��������
  FTickCount := GetTickCount;
  
  case FReceiver.Complete of
    IO_FIRST_PACKET:  // 1.1 �����ݰ��������Ч�� �� �û���¼״̬
      if (CheckMsgHead(FRecvBuf^.Data.buf) = False) then
        Exit;
    IO_SUBSEQUENCE:   // 1.2 ���պ������ݰ�
      FReceiver.Receive(FRecvBuf^.Data.buf, FByteCount);
  end;

  // 1.3 ����򸽼�������Ͼ�����Ӧ�ò�
  FComplete := FReceiver.Complete and (FReceiver.Cancel = False);

  {$IFNDEF DELPHI_7}
  {$ENDREGION}

  {$REGION '+ ����Ӧ�ò�'}
  {$ENDIF}

  // 2. ����Ӧ�ò�
  try
    if FComplete then   // ������ϡ��ļ�Э��
      if FReceiver.CheckPassed then // У��ɹ�
        HandleDataPack  // 2.1 ����ҵ��
      else
        ReturnMessage(arErrHash);  // 2.2 У����󣬷�����
  finally
    // 2.3 ����Ͷ�� WSARecv���������ݣ�
    {$IFDEF TRANSMIT_FILE}
    // ���ܷ����ɹ�����������ǰ��
    if (FTaskExists = False) then {$ENDIF}
      InternalRecv(FComplete);
  end;

  {$IFNDEF DELPHI_7}
  {$ENDREGION}
  {$ENDIF}

end;

procedure TIOCPSocket.HandleDataPack;
begin
  // ִ�пͻ�������

  // 1. ��Ӧ -> ֱ�ӷ���Э��ͷ
  if (FParams.Action = atUnknown) then
    FResult.ReturnHead
  else

  // 2. δ��¼������˲��رգ����Ի����� -> ����Э��ͷ
  if (FResult.ActResult in [arErrUser, arOutDate]) then
    ReturnMessage(FResult.ActResult)
  else

  // 3. ���������쳣
  if FParams.Error then
    ReturnMessage(arErrAnalyse)
  else begin

    // 4. ����Ӧ�ò�ִ������
    try
      FWorker.Execute(Self);
    except
      on E: Exception do  // 4.1 �쳣 -> ����
      begin
        ReturnMessage(arErrWork, E.Message);
        Exit;  // 4.2 ����
      end;
    end;

    try
      // 5. ����+����������� -> ���
      FReceiver.OwnerClear;

      // 6. �Ƿ��û����������Ҫ�ر�
      if (FResult.ActResult = arErrUser) then
        windows.InterlockedIncrement(FState);  // FState+

      // 7. ���ͽ����
      FResult.ReturnResult;

      {$IFNDEF TRANSMIT_FILE}
      // 7.1 ��������¼�������δ�رգ�
      if Assigned(FResult.Attachment) then
      begin
        FAction := atAfterSend;
        FWorker.Execute(Self);
      end;
      {$ENDIF}
    finally
      {$IFNDEF TRANSMIT_FILE}
      if (FReceiver.Complete = False) then  // ����δ�������
        FAction := atAfterReceive;  // �ָ�
      if Assigned(FResult.Attachment) then
        FResult.Clear;
      {$ENDIF}
    end;

  end;

end;

procedure TIOCPSocket.IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer);
begin
  inherited;
  FSessionId := INI_SESSION_ID; // ��ʼƾ֤
end;

{$IFDEF TRANSMIT_FILE}
procedure TIOCPSocket.InterFreeRes;
begin
  // �ͷ� TransmitFile �ķ�����Դ
  try
    try
      if Assigned(FResult.Attachment) then  // �����������
      begin
        FAction := atAfterSend;
        FWorker.Execute(Self);
      end;
    finally
      if (FReceiver.Complete = False) then  // ����δ�������
        FAction := atAfterReceive;  // �ָ�
      FResult.NilStreams(True);     // �ͷŷ�����Դ
      FTask.FreeResources(False);   // False -> �������ͷ�
    end;
  finally  // ����Ͷ�� Recv
    InternalRecv(FComplete);
  end;
end;
{$ENDIF}

procedure TIOCPSocket.PostEvent(IOKind: TIODataType);
var
  Msg: TPushMessage;
begin
  // ���졢����һ��Э��ͷ��Ϣ�����Լ���
  //   C/S ���� IOKind ֻ�� ioDelete��ioRefuse��ioTimeOut��
  //  ������Ϣ�ã�Push(ATarget: TBaseSocket; UseUniqueMsgId: Boolean);
  //  ͬʱ���� HTTP ����ʱ������ THttpSocket ���� arRefuse��δת����Դ��

  // 3 ���ڻ����ȡ����ʱ
  if (IOKind = ioTimeOut) and CheckDelayed(GetTickCount) then
    Exit;

  Msg := TPushMessage.Create(Self, IOKind, IOCP_SOCKET_SIZE);

  case IOKind of
    ioDelete:
      THeadMessage.CreateHead(Msg.PushBuf^.Data.buf, arDeleted);
    ioRefuse: 
      THeadMessage.CreateHead(Msg.PushBuf^.Data.buf, arRefuse);
    ioTimeOut:
      THeadMessage.CreateHead(Msg.PushBuf^.Data.buf, arTimeOut);
  end;

  // ���������б����������߳�
  TInIOCPServer(FServer).PushManager.AddWork(Msg);
end;

procedure TIOCPSocket.Push(Target: TIOCPSocket);
var
  Msg: TPushMessage;
begin
  // ���յ�����Ϣ�� Target ��㲥
  //   �ύ�������̣߳���֪����ʱ�������Ƿ�ɹ���

  // ��Ψһ�� MsgID, �޸Ļ���� MsgId
  //   ��Ҫ�� FResult.FMsgId������ͻ��˰ѷ��ͷ�������������Ϣ����
  FParams.FMsgHead^.MsgId := TSystemGlobalLock.GetMsgId;

  if Assigned(Target) then  // ���� Target
  begin
    Msg := TPushMessage.Create(FRecvBuf, False);
    Msg.Add(Target);  // ���� Target
  end else  // �㲥
    Msg := TPushMessage.Create(FRecvBuf, True);

  // ���������߳�
  if TInIOCPServer(FServer).PushManager.AddWork(Msg) then
    Result.ActResult := arOK
  else
    Result.ActResult := arErrBusy; // ��æ��������Msg �ѱ��ͷ�
    
end;

procedure TIOCPSocket.SetLogoutState;
begin
  // ���õǳ�״̬
  FSessionId := INI_SESSION_ID;
  if Assigned(FEnvir) then
    if FEnvir^.ReuseSession then  // �����ӶϿ������� FData ��Ҫ��Ϣ
    begin
      FEnvir^.BaseInf.Socket := 0;
      FEnvir^.BaseInf.LogoutTime := Now();
    end else
      try  // �ͷŵ�¼��Ϣ
        TInIOCPServer(FServer).ClientManager.ClientList.Remove(FEnvir^.BaseInf.Name);
      finally
        FEnvir := Nil;
      end;
end;

procedure TIOCPSocket.ReturnMessage(ActResult: TActionResult; const ErrMsg: String);
begin
  // ����Э��ͷ���ͻ���

  FParams.Clear;
  FResult.Clear;
  
  if (ErrMsg <> '') then
  begin
    FResult.ErrMsg := ErrMsg;
    FResult.ActResult := ActResult;
    FResult.ReturnResult;
  end else
    FResult.ReturnHead(ActResult);

  case ActResult of
    arOffline:
      iocp_log.WriteLog(Self.ClassName + '->�ͻ���δ��¼.');
    arOutDate:
      iocp_log.WriteLog(Self.ClassName + '->ƾ֤/��֤����.');
    arErrAnalyse:
      iocp_log.WriteLog(Self.ClassName + '->���������쳣.');
    arErrHash:
      iocp_log.WriteLog(Self.ClassName + '->У���쳣��');
    arErrWork:
      iocp_log.WriteLog(Self.ClassName + '->ִ���쳣, ' + ErrMsg);
  end;

end;

procedure TIOCPSocket.SocketError(IOKind: TIODataType);
begin
  // �����շ��쳣
  if (IOKind in [ioDelete, ioPush, ioRefuse]) then  // ����
    FResult.ActResult := arErrPush;
  inherited;
end;

procedure TIOCPSocket.SetLogState(AEnvir: PEnvironmentVar);
begin
  // ���õ�¼/�ǳ���Ϣ
  if (AEnvir = nil) then  // �ǳ�
  begin
    SetLogoutState;
    FResult.FSessionId := FSessionId;
    FResult.ActResult := arLogout;  // ���� arOffline
    if Assigned(FEnvir) then  // �������� Socket
      FEnvir := nil;
  end else
  begin
    FSessionId := CreateSession;  // �ؽ��Ի���
    FResult.FSessionId := FSessionId;
    FResult.ActResult := arOK;
    FEnvir := AEnvir;
  end;
end;

procedure TIOCPSocket.SetUniqueMsgId;
begin
  // ����������Ϣ�� MsgId
  //   ������Ϣ���÷�������Ψһ MsgId
  //   �޸Ļ���� MsgId
  //   ��Ҫ�� FResult.FMsgId������ͻ��˰ѷ��ͷ�������������Ϣ����
  FParams.FMsgHead^.MsgId := TSystemGlobalLock.GetMsgId;
end;

function TIOCPSocket.SessionValid(ASession: Cardinal): Boolean;
var
  NowTime: TDateTime;
  Certify: TCertifyNumber;
  LHour, LMinute, LSecond, LMilliSecond: Word;  
begin
  // ���ƾ֤�Ƿ���ȷ��û��ʱ
  //   �ṹ��(�������� + ��Ч����) xor ��
  NowTime := Now();

  DecodeTime(NowTime, LHour, LMinute, LSecond, LMilliSecond);

  LMinute := LHour * 60 + LMinute;  // ��ʱ���
  LSecond :=  Trunc(NowTime - 43000);  // ��ʱ���
  Certify.Session := ASession xor Cardinal($AB12);

  Result := (Certify.DayCount = LSecond) and (Certify.Timeout > LMinute) or
            (Certify.DayCount = LSecond + 1) and (Certify.Timeout > (1440 - LMinute));

  if Result then
    FSessionId := Certify.Session;
end;

{ THttpSocket }

procedure THttpSocket.ClearResources;
begin
  // �����Դ
  CloseStream;
  if Assigned(FRequest) then
    FRequest.Clear;
  if Assigned(FRespone) then
    FRespone.Clear;
  {$IFDEF TRANSMIT_FILE}
  if Assigned(FTask) then  
    FTask.FreeResources(False);  // ���� FResult.Clear �ͷ�
  {$ENDIF}    
end;

procedure THttpSocket.CloseStream;
begin
  if Assigned(FStream) then
  begin
    FStream.Free;
    FStream := Nil;
  end;
end;

procedure THttpSocket.CreateStream(const FileName: String);
begin
  // ���ļ���
  FStream := TFileStream.Create(FileName, fmCreate or fmOpenWrite);
end;

procedure THttpSocket.DecodeHttpRequest;
begin
  // ����������루�����ݰ���
  //   ��ҵ���߳̽� FRequest��FRespone���ӿ�����ٶ�
  if (FRequest = nil) then
  begin
    FRequest := THttpRequest.Create(TInIOCPServer(FServer).HttpDataProvider, Self); // http ����
    FRespone := THttpRespone.Create(TInIOCPServer(FServer).HttpDataProvider, Self); // http Ӧ��
  end;
  // ����ʱ�䡢HTTP �������
  FTickCount := GetTickCount;
  TRequestObject(FRequest).Decode(FSender, FRespone, FRecvBuf);
end;

destructor THttpSocket.Destroy;
begin
  CloseStream;
  if Assigned(FRequest) then
  begin
    FRequest.Free;
    FRequest := Nil;
  end;
  if Assigned(FRespone) then
  begin
    FRespone.Free;
    FRespone := Nil;
  end;
  inherited;
end;

procedure THttpSocket.ExecuteWork;
begin
  // ִ�� Http ����
  try
    // 0. ʹ�� C/S Э��ʱ��Ҫת��Ϊ TIOCPSocket
    if (FTickCount = NEW_TICKCOUNT) and (FByteCount = IOCP_SOCKET_FLEN) and
      MatchSocketType(FRecvBuf^.Data.Buf, IOCP_SOCKET_FLAG) then
    begin
      UpgradeSocket(TInIOCPServer(FServer).IOCPSocketPool);
      Exit;  // ����
    end;

    // 1. �������
    DecodeHttpRequest;

    // 2. ������� WebSocket
    if (FRequest.UpgradeState > 0) then
    begin
      if FRequest.Accepted then  // ����Ϊ WebSocket�����ܷ��� THttpSocket ��
      begin
        TResponeObject(FRespone).Upgrade;
        UpgradeSocket(TInIOCPServer(FServer).WebSocketPool);
      end else  // �������������ر�
        InterCloseSocket(Self);
      Exit;     // ����
    end;

    // 3. ִ��ҵ��
    FComplete := FRequest.Complete;   // �Ƿ�������
    FSessionId := FRespone.SessionId; // SendWork ʱ�ᱻɾ��
    FRespone.StatusCode := FRequest.StatusCode;

    if FComplete and FRequest.Accepted and (FRequest.StatusCode < 400) then
      FWorker.HttpExecute(Self);

    // 4. ����Ƿ�Ҫ��������
    if FRequest.Attacked then // ������
      FKeepAlive := False
    else
      if FComplete or (FRespone.StatusCode >= 400) then  // ������ϻ��쳣
      begin
        // �Ƿ񱣴�����
        FKeepAlive := FRespone.KeepAlive;

        // 5. �������ݸ��ͻ���
        TResponeObject(FRespone).SendWork;

        if {$IFNDEF TRANSMIT_FILE} FKeepAlive {$ELSE}
           (FTaskExists = False) {$ENDIF} then // 6. ����Դ��׼���´�����
          ClearResources;
      end else
        FKeepAlive := True;   // δ��ɣ������ܹر�

    // 7. ����Ͷ�Ż�ر�
    if FKeepAlive and (FErrorCode = 0) then  // ����Ͷ��
    begin
      {$IFDEF TRANSMIT_FILE}
      if (FTaskExists = False) then {$ENDIF}
        InternalRecv(FComplete);
    end else
      InterCloseSocket(Self);  // �ر�ʱ����Դ
                 
  except
    // �󲢷�ʱ���ڴ���ϵ㣬�����Ƿ��쳣
    iocp_log.WriteLog('THttpSocket.ExecuteHttpWork->' + GetSysErrorMessage);
    InterCloseSocket(Self);  // ϵͳ�쳣
  end;

end;

{$IFDEF TRANSMIT_FILE}
procedure THttpSocket.InterFreeRes;
begin
  // ������ϣ��ͷ� TransmitFile �ķ�����Դ
  try
    ClearResources;
  finally
    if FKeepAlive and (FErrorCode = 0) then  // ����Ͷ��
      InternalRecv(True)
    else
      InterCloseSocket(Self);
  end;
end;
{$ENDIF}

procedure THttpSocket.PostEvent(IOKind: TIODataType);
const
  REQUEST_NOT_ACCEPTABLE = HTTP_VER + ' 406 Not Acceptable';
        REQUEST_TIME_OUT = HTTP_VER + ' 408 Request Time-out';
var
  Msg: TPushMessage;
  ResponeMsg: AnsiString;
begin
  // ���졢����һ����Ϣͷ�����Լ���
  //   HTTP ����ֻ�� arRefuse��arTimeOut

  // TransmitFile ������� 3 ���ڻ����ȡ����ʱ
  if (IOKind = ioTimeOut) and CheckDelayed(GetTickCount) then
    Exit;

  if (IOKind = ioRefuse) then
    ResponeMsg := REQUEST_NOT_ACCEPTABLE + STR_CRLF +
                  'Server: ' + HTTP_SERVER_NAME + STR_CRLF +
                  'Date: ' + GetHttpGMTDateTime + STR_CRLF +
                  'Content-Length: 0' + STR_CRLF +
                  'Connection: Close' + STR_CRLF2
  else
    ResponeMsg := REQUEST_TIME_OUT + STR_CRLF +
                  'Server: ' + HTTP_SERVER_NAME + STR_CRLF +
                  'Date: ' + GetHttpGMTDateTime + STR_CRLF +
                  'Content-Length: 0' + STR_CRLF +
                  'Connection: Close' + STR_CRLF2;

  Msg := TPushMessage.Create(Self, IOKind, Length(ResponeMsg));

  System.Move(ResponeMsg[1], Msg.PushBuf^.Data.buf^, Msg.PushBuf^.Data.len);

  // ���������б������߳�
  TInIOCPServer(FServer).PushManager.AddWork(Msg);

end;

procedure THttpSocket.SocketError(IOKind: TIODataType);
begin
  // �����շ��쳣
  if Assigned(FRespone) then      // ����ʱ = Nil
    FRespone.StatusCode := 500;   // 500: Internal Server Error
  inherited;
end;

procedure THttpSocket.UpgradeSocket(SocketPool: TIOCPSocketPool);
var
  oSocket: TBaseSocket;
begin
  // �� THttpSocket ת��Ϊ TIOCPSocket��TWebSocket��
  try
    oSocket := TBaseSocket(SocketPool.Clone(Self));  // δ�� FTask��
    oSocket.PostRecv;  // Ͷ��
  finally
    InterCloseSocket(Self);  // �ر�����
  end;
end;

procedure THttpSocket.WriteStream(Data: PAnsiChar; DataLength: Integer);
begin
  // �������ݵ��ļ���
  if Assigned(FStream) then
    FStream.Write(Data^, DataLength);
end;

{ TWebSocket }

procedure TWebSocket.ClearMsgOwner(Buf: PAnsiChar; Len: Integer);
begin
  // �޸���Ϣ������
  Inc(Buf, Length(INIOCP_JSON_FLAG));
  if SearchInBuffer(Buf, Len, '"__MSG_OWNER":') then // ���ִ�Сд
    while (Buf^ <> AnsiChar(',')) do
    begin
      Buf^ := AnsiChar('0');
      Inc(Buf);
    end;
end;

procedure TWebSocket.ClearResources;
begin
  if Assigned(FReceiver) then
    FReceiver.Clear;
end;

constructor TWebSocket.Create(AObjPool: TIOCPSocketPool; ALinkNode: PLinkRec);
begin
  inherited;
  FUseTransObj := False;  // ���� TransmitFile
  FJSON := TBaseJSON.Create(Self);
  FResult := TResultJSON.Create(Self);
  FResult.FServerMode := True;  // ������ģʽ
  FReceiver := TWSServerReceiver.Create(Self, FJSON);
end;

destructor TWebSocket.Destroy;
begin
  FJSON.Free;
  FResult.Free;
  FReceiver.Free;
  inherited;
end;

procedure TWebSocket.ExecuteWork;
begin
  // �������ݣ�ִ������

  // 1. ��������
  FTickCount := GetTickCount;

  if FReceiver.Complete then  // �����ݰ�
  begin
    // ��������������
    // ���ܸı� FMsgType���� FReceiver.UnMarkData
    FMsgType := mtDefault;
    FReceiver.Prepare(FRecvBuf^.Data.buf, FByteCount);
    case FReceiver.OpCode of
      ocClose: begin
        InterCloseSocket(Self);  // �رգ�����
        Exit;
      end;
      ocPing, ocPong: begin
        InternalRecv(True);  // Ͷ�ţ�����
        Exit;
      end;
    end;
  end else
  begin
    // ���պ������ݰ�
    FReceiver.Receive(FRecvBuf^.Data.buf, FByteCount);
  end;

  // �Ƿ�������
  FComplete := FReceiver.Complete;

  // 2. ����Ӧ�ò�
  // 2.1 ��׼������ÿ����һ�μ�����
  // 2.2 ��չ�Ĳ������� JSON ��Ϣ��������ϲŽ���

  try
    if (FMsgType = mtDefault) or FComplete then
    begin
      if (FMsgType <> mtDefault) then
        FResult.Action := FJSON.Action;  // ���� Action
      FWorker.WSExecute(Self);
    end;
  finally
    if FComplete then   // �������
    begin
      case FMsgType of
        mtJSON: begin   // ��չ�� JSON
          FJSON.Clear;  // ���� Attachment
          FResult.Clear;
          FReceiver.Clear;
        end;
        mtAttachment: begin  // ��չ�ĸ�����
          FJSON.Close;  // �رո�����
          FResult.Clear;
          FReceiver.Clear;
        end;
      end;
      // ping �ͻ���
      InternalPing;  
    end;
    // ��������
    InternalRecv(FComplete);
  end;

end;

procedure TWebSocket.InternalPing;
begin
  // Ping �ͻ��ˣ����µ���Ϣ����������
  MakeFrameHeader(FSender.Data, ocPing);
  FSender.SendBuffers;
end;

procedure TWebSocket.InterPush(Target: TWebSocket);
var
  Msg: TPushMessage;
begin
  // ���յ�����Ϣ���� Target ��㲥
  //   �ύ�������̣߳���֪����ʱ�������Ƿ�ɹ���

  if (FOpCode <> ocText) then
  begin
    SendData('ֻ�������ı���Ϣ.');
    Exit;
  end;
    
  if (FComplete = False) or (FMsgSize > IO_BUFFER_SIZE - 30) then
  begin
    SendData('��Ϣδ�������ջ�̫��, ����.');
    Exit;
  end;

  // �������
  FReceiver.ClearMark(FData, @FRecvBuf^.Overlapped);

  if (FMsgType = mtJSON) then  // ��� Owner, 0 ��ʾ�����
    ClearMsgOwner(FData, FRecvBuf^.Overlapped.InternalHigh);

  if Assigned(Target) then  // ���� Target
  begin
    Msg := TPushMessage.Create(FRecvBuf, False);
    Msg.Add(Target);  // ���� Target
  end else  // �㲥
    Msg := TPushMessage.Create(FRecvBuf, True);

  // ���������̣߳����뷢��һ����Ϣ���ͻ��ˣ�
  if TInIOCPServer(FServer).PushManager.AddWork(Msg) then
    InternalPing  // Ping �ͻ��ˣ���ʱ�����룩
  else
    SendData('ϵͳ��æ, ����.'); // ��æ��������Msg �ѱ��ͷ�

end;

procedure TWebSocket.PostEvent(IOKind: TIODataType);
begin
  // Empty
end;

procedure TWebSocket.SendData(const Msg: String);
begin
  // δ��װ�������ı�
  if (Msg <> '') then
  begin
    FSender.OpCode := ocText;
    FSender.Send(System.AnsiToUtf8(Msg));
  end;
end;

procedure TWebSocket.SendData(const Data: PAnsiChar; Size: Cardinal);
var
  Buf: PAnsiChar;
begin
  // δ��װ�������ڴ�����ݣ����� Data��
  if Assigned(Data) and (Size > 0) then
  begin
    GetMem(Buf, Size);
    System.Move(Data^, Buf^, Size);
    FSender.OpCode := ocBiary;
    FSender.Send(Buf, Size);
  end;
end;

procedure TWebSocket.SendData(Handle: THandle);
begin
  // δ��װ�������ļ� handle���Զ��رգ�
  if (Handle > 0) and (Handle <> INVALID_HANDLE_VALUE) then
  begin
    FSender.OpCode := ocBiary;
    FSender.Send(Handle, GetFileSize64(Handle));
  end;
end;

procedure TWebSocket.SendData(Stream: TStream);
begin
  // δ��װ�����������ݣ��Զ��ͷţ�
  if Assigned(Stream) then
  begin
    FSender.OpCode := ocBiary;
    FSender.Send(Stream, Stream.Size, True);
  end;
end;

procedure TWebSocket.SendDataVar(Data: Variant);
begin
  // δ��װ�����Ϳɱ���������
  if (VarIsNull(Data) = False) then
  begin
    FSender.OpCode := ocBiary;
    FSender.SendVar(Data);
  end;
end;

procedure TWebSocket.SendResult(UTF8CharSet: Boolean);
begin
  // ���� FResult ���ͻ��ˣ�InIOCP-JSON��
  FResult.FOwner := FJSON.Owner;
  FResult.FUTF8CharSet := UTF8CharSet;
  FResult.InternalSend(FSender, False);
end;

procedure TWebSocket.SetProps(AOpCode: TWSOpCode; AMsgType: TWSMsgType;
                     AData: Pointer; AFrameSize: Int64; ARecvSize: Cardinal);
begin
  // ���£�����TWSServerReceiver.InitResources
  FMsgType := AMsgType;  // ��������
  FOpCode := AOpCode;  // ����
  FMsgSize := 0;  // ��Ϣ����
  FData := AData; // ���õ�ַ
  FFrameSize := AFrameSize;  // ֡����
  FFrameRecvSize := ARecvSize;  // �յ�֡����
end;

{ TSocketBroker }

procedure TSocketBroker.AssociateInner(InnerBroker: TSocketBroker);
begin
  // �ⲿ�������ڲ� Socket �����������Ѿ�Ͷ�� WSARecv��
  try
    // ת����Դ
    FDualConnected := True;
    FDualSocket := InnerBroker.FSocket;
    FDualBuf := InnerBroker.FRecvBuf;
    FDualBuf^.Owner := Self;  // ������
    FPeerIPPort := 'Dual:' + FPeerIPPort;
 finally
    // ���ԭ��Դֵ
    InnerBroker.FConnected := False;
    InnerBroker.FSocket := INVALID_SOCKET;
    InnerBroker.FRecvBuf := nil;
    // ���� TBaseSocket
    InnerBroker.InterCloseSocket(InnerBroker);
  end;
  if (FSocketType = stWebSocket) or (TInIOCPBroker(FBroker).Protocol = tpNone) then
    FOnBind := nil;  // ɾ�����¼����Ժ��ٰ󶨣� }
end;

procedure TSocketBroker.BrokerPostRecv(ASocket: TSocket; AData: PPerIOData; ACheckState: Boolean);
var
  ByteCount, Flags: DWORD;
begin
  // Ͷ�� WSRecv: ASocket, AData

  // ����ʱ FState=1�������κ�ֵ��˵���������쳣��
  // FState = 1 -> ����������ı���״̬���رգ�

  if ACheckState and (Windows.InterlockedDecrement(FState) <> 0) then
  begin
    FErrorCode := 9;
    InterCloseSocket(Self);
  end else
  begin
    // ���ص��ṹ
    FillChar(AData^.Overlapped, SizeOf(TOverlapped), 0);

    AData^.Owner := Self;  // ����
    AData^.IOType := ioReceive;  // iocp_server ���ж���
    AData^.Data.len := IO_BUFFER_SIZE;  // ����

    ByteCount := 0;
    Flags := 0;

    if (iocp_Winsock2.WSARecv(ASocket, @(AData^.Data), 1, ByteCount,
        Flags, LPWSAOVERLAPPED(@AData^.Overlapped), nil) = SOCKET_ERROR) then
    begin
      FErrorCode := WSAGetLastError;
      if (FErrorCode <> ERROR_IO_PENDING) then  // �쳣
      begin
        SocketError(ioReceive);
        InterCloseSocket(Self);  // �ر�
      end else
        FErrorCode := 0;
    end;
  end;
end;

procedure TSocketBroker.ClearResources;
begin
  // �������δ���������ӱ��Ͽ������ⲹ������
  if TInIOCPBroker(FBroker).ReverseMode and (FSocketType = stOuterSocket) then
    TIOCPBrokerRef(FBroker).ConnectOuter;
  if FDualConnected then  // ���Թر�
    TryClose;
end;

procedure TSocketBroker.CreateBroker(const AServer: AnsiString; APort: Integer);
begin
  // �½�һ���ڲ������м��׽��֣������ܸı�����

  if (FDualSocket <> INVALID_SOCKET) then
    Exit;
    
  // ���׽���
  FDualSocket := iocp_utils.CreateSocket;

  if (ConnectSocket(FDualSocket, AServer, APort) = False) then  // ����
  begin
    FDualConnected := False;
    FErrorCode := GetLastError;
    iocp_log.WriteLog('TSocketBroker.CreateBroker:ConnectSocket->' + GetSysErrorMessage(FErrorCode));
    InterCloseSocket(Self);  // �رմ���
  end else
  if TInIOCPServer(FServer).IOCPEngine.BindIoCompletionPort(FDualSocket) then  // ��
  begin
    FDualConnected := True;
    FTargetHost := AServer;
    FTargetPort := APort;
    FPeerIPPort := 'Dual:' + FPeerIPPort;  // �����־

    // ��������ڴ��
    if (FDualBuf = nil) then
      FDualBuf := BufferPool.Pop^.Data;

    BrokerPostRecv(FDualSocket, FDualBuf, False);  // Ͷ�� FDualSocket

    if (FErrorCode > 0) then  // �쳣
      FDualConnected := False
    else
    if TInIOCPBroker(FBroker).ReverseMode then  // ����������ⲹ������
    begin
      FSocketType := stDefault;  // �ı䣨�ر�ʱ���������ӣ�
      TIOCPBrokerRef(FBroker).ConnectOuter;
    end;

    FOnBind := nil;  // ɾ�����¼����Ժ��ٰ󶨣�
  end else
  begin
    FDualConnected := False;
    FErrorCode := GetLastError;
    InterCloseSocket(Self);  // �رմ���
  end;

end;

procedure TSocketBroker.ExecuteWork;
  function CheckInnerSocket: Boolean;
  begin
    // ++�ⲿ����ģʽ���������ӣ�
    // 1���ⲿ�ͻ��ˣ����ݲ��� InIOCP_INNER_SOCKET
    // 2���ڲ��ķ������ͻ��ˣ����ݴ� InIOCP_INNER_SOCKET:InnerBrokerId
    if (PInIOCPInnerSocket(FRecvBuf^.Data.buf)^ = InIOCP_INNER_SOCKET) then
    begin
      // �����ڲ��ķ���������ӣ����浽�б��� TInIOCPBroker.BindBroker ���
      SetString(FBrokerId, FRecvBuf^.Data.buf + Length(InIOCP_INNER_SOCKET) + 1,
                           Integer(FByteCount) - Length(InIOCP_INNER_SOCKET) - 1);
      TIOCPBrokerRef(FBroker).AddConnection(Self, FBrokerId);
      Result := True;
    end else
      Result := False;  // �����ⲿ�Ŀͻ�������
  end;
  procedure ExecSocketAction;
  begin
    // �����ڲ����ӱ�־���ⲿ����
    try
      if (TInIOCPBroker(FBroker).BrokerId = '') then  // ��Ĭ�ϱ�־
        FSender.Send(InIOCP_INNER_SOCKET + ':DEFAULT')
      else  // ͬʱ���ʹ����־�������ⲿ��������
        FSender.Send(InIOCP_INNER_SOCKET + ':' + UpperCase(TInIOCPBroker(FBroker).BrokerId));
    finally
      FAction := 0;
    end;
  end;
  procedure ForwardDataEx(ASocket, AToSocket: TSocket; AData: PPerIOData; MaskInt: Integer);
  begin
    try
      // ���ܼ򵥻������ݿ飬����󲢷�ʱ AData ���ظ�Ͷ�� -> 995 �쳣
      FSender.Socket := AToSocket;  // ���� AToSocket
      FRecvState := FRecvState and MaskInt;  // ȥ��״̬
      TServerTaskSender(FSender).CopySend(AData);  // ��������
    finally
      if (FErrorCode = 0) then
        BrokerPostRecv(ASocket, AData)  // ����Ͷ�� WSRecv
      else
        InterCloseSocket(Self);
    end;
  end;
  procedure ForwardData;
  begin
    // ���ơ�ת������
    if FCmdConnect then  // Http����: Connect ������Ӧ
    begin
      FCmdConnect := False;
      FSender.Send(HTTP_PROXY_RESPONE);
      BrokerPostRecv(FSocket, FRecvBuf);
    end else
    if (FRecvState and $0001 = 1) then
      ForwardDataEx(FSocket, FDualSocket, FRecvBuf, 2)
    else
      ForwardDataEx(FDualSocket, FSocket, FDualBuf, 1);
  end;
begin
  // ִ�У�
  //   1���󶨡������������ⲿ���ݵ� FDualSocket
  //   2���Ѿ�����ʱֱ�ӷ��͵� FDualSocket

  // Ҫ�������� TInIOCPBroker.ProxyType

  FTickCount := GetTickCount;
  
  case TInIOCPBroker(FBroker).ProxyType of
    ptDefault: // Ĭ�ϴ���ģʽ
      if (FAction > 0) then  // ����SendInnerFlag
      begin
        ExecSocketAction;    // ִ�в���������
        BrokerPostRecv(FSocket, FRecvBuf);  // Ͷ��
        Exit;
      end;
    ptOuter:   // �ⲿ����ģʽ
      if (FDualConnected = False) and CheckInnerSocket then  // ���ڲ�������������
      begin
        BrokerPostRecv(FSocket, FRecvBuf); // ��Ͷ��
        Exit;
      end;
  end;

  if (Assigned(FOnBind) = False) then  // �ް󶨷���  
    ForwardData  // ת������
  else  // ��ʼʱ FOnBind <> nil
    try
      FOnBind(Self, FRecvBuf^.Data.buf, FByteCount)  // �󶨡�����
    finally
      if FDualConnected then  // ת������
        ForwardData;
    end;

end;

procedure TSocketBroker.HttpBindOuter(Connection: TSocketBroker; const Data: PAnsiChar; DataSize: Cardinal);
  function ChangeConnection(const ABrokerId, AServer: AnsiString; APort: Integer): Boolean;
  begin
    // ������Ŀ���Ƿ��Ѿ��ı�
    if (TInIOCPBroker(FBroker).ProxyType = ptOuter) then
      Result := (ABrokerId <> FBrokerId)  // �������ı�
    else
      Result := not (((AServer = FTargetHost) or
                      (LowerCase(AServer) = 'localhost') and (FTargetHost = '127.0.0.1') or
                      (LowerCase(FTargetHost) = 'localhost') and (AServer = '127.0.0.1')) and (
                      (APort = FTargetPort) or (APort = TInIOCPServer(FServer).ServerPort)));
  end;
  procedure GetConnectHost(var p: PAnsiChar);
  var
    pb: PAnsiChar;
    i: Integer;
  begin
    // ��ȡ������ַ��CONNECT xxx:443 HTTP/1.1
    Delete(FTargetHost, 1, Length(FTargetHost));

    pb := nil;
    Inc(p, 7);  // connect

    for i := 1 to FByteCount do
    begin
      if (p^ = #32) then
        if (pb = nil) then  // ��ַ��ʼ
          pb := p
        else begin  // ��ַ���������жϰ汾
          SetString(FTargetHost, pb, p - pb);
          FTargetHost := Trim(FTargetHost);
          Break;
        end;
      Inc(p);
    end;
  end;
  procedure GetHttpHost(var p: PAnsiChar);
  var
    pb: PAnsiChar;
  begin
    // ��ȡ������ַ��HOST:
    pb := nil;
    Inc(p, 4);
    repeat
      case p^ of
        ':':
          if (pb = nil) then
            pb := p + 1;
        #13: begin
          SetString(FTargetHost, pb, p - pb);
          FTargetHost := Trim(FTargetHost);
          Exit;
        end;
      end;
      Inc(p);
    until (p^ = #10);
  end;
  procedure GetUpgradeType(var p: PAnsiChar);
  var
    S: AnsiString;
    pb: PAnsiChar;
  begin
    // ��ȡ���ݳ��ȣ�UPGRADE: WebSocket
    pb := nil;
    Inc(p, 14);
    repeat
      case p^ of
        ':':
          pb := p + 1;
        #13: begin
          SetString(S, pb, p - pb);
          if (UpperCase(Trim(S)) = 'WEBSOCKET') then
            FSocketType := stWebSocket;
          Exit;
        end;
      end;
      Inc(p);
    until (p^ = #10);
  end;
  procedure ExtractHostPort;
  var
    i, j, k: Integer;
  begin
    // ���� Host��Port �� ��������־

    j := 0;
    k := 0;

    for i := 1 to Length(FTargetHost) do  // 127.0.0.1:800@DEFAULT
      case FTargetHost[i] of
        ':':
          j := i;
        '@':  // HTTP ���������չ������Ϊ������/�ֹ�˾��־
          k := i;
      end;

    if (k > 0) then  // ��������־
    begin
      if (TInIOCPBroker(FBroker).ProxyType = ptOuter) then  // �ⲿ�������
        FBrokerId := Copy(FTargetHost, k + 1, 99);
      Delete(FTargetHost, k, 99);
    end;

    if (j > 0) then  // �ڲ�����
    begin
      TryStrToInt(Copy(FTargetHost, j + 1, 99), FTargetPort);
      Delete(FTargetHost, j, 99);
    end;
    
  end;
  procedure HttpRequestDecode;
  var
    iState: Integer;
    pE, pb, p: PAnsiChar;
  begin
    // Http Э�飺��ȡ������Ϣ��Host��Upgrade
    p := FRecvBuf^.Data.buf;  // ��ʼλ��
    pE := PAnsiChar(p + FByteCount);  // ����λ��

    // 1��HTTP����Connect �������=443
    if http_utils.CompareBuffer(p, 'CONNECT', True) then
    begin
      FCmdConnect := True;
      GetConnectHost(p);  // p �ı�
      ExtractHostPort;
      Exit;
    end;

    // 2������ HTTP ����
    
    iState := 0;  // ��Ϣ״̬
    FCmdConnect := False;
    FTargetPort := 80;  // Ĭ�϶˿ڣ�����=443
    pb := nil;

    Inc(p, 12);

    repeat
      case p^ of
        #10:  // ���з�
          pb := p + 1;

        #13:  // �س���
          if (pb <> nil) then
            if (p = pb) then  // ���������Ļس����У���ͷ����
            begin
              Inc(p, 2);
              Break;
            end else
            if (p - pb >= 15) then
            begin
              if http_utils.CompareBuffer(pb, 'HOST', True) then
              begin
                Inc(iState);
                GetHttpHost(pb);
                ExtractHostPort;
              end else
              if http_utils.CompareBuffer(pb, 'UPGRADE', True) then  // WebSocket
              begin
                Inc(iState, 2);
                GetUpgradeType(pb);
              end;
            end;
      end;

      Inc(p);
    until (p >= pE) or (iState = 3);

  end;
  procedure HttpConnectHost(const AServer: AnsiString; APort: Integer);
  begin
    // Http Э�飺���ӵ���������� HOST��û��ʱ���ӵ�����ָ����
    if (FTargetHost <> '') and (FTargetPort > 0) then
      CreateBroker(FTargetHost, FTargetPort)
    else
    if (AServer <> '') and (APort > 0) then  // �ò���ָ����
      CreateBroker(AServer, APort)
    else
      InterCloseSocket(Self);  // �ر�
  end;
var
  Accept: Boolean;
begin
  // Http Э�飺��� Connect �������������� Host

  // ��ȡ Host ��Ϣ
  HttpRequestDecode;

  Accept := True;
  if Assigned(TInIOCPBroker(FBroker).OnAccept) then  // �Ƿ���������
    TInIOCPBroker(FBroker).OnAccept(Self, FTargetHost, FTargetPort, Accept);

  if Accept then
    if (TInIOCPBroker(FBroker).ProxyType = ptDefault) then  // Ĭ�ϴ����½����ӣ�����
      HttpConnectHost(TInIOCPBroker(FBroker).InnerServer.ServerAddr,
                      TInIOCPBroker(FBroker).InnerServer.ServerPort)
    else  // �ڲ��������ڲ����ӳ�ѡȡ��������
    if (FDualConnected = False) or
      ChangeConnection(FBrokerId, FTargetHost, FTargetPort) then
      TIOCPBrokerRef(FBroker).BindInnerBroker(Connection, Data, DataSize);

end;

procedure TSocketBroker.IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer);
begin
  inherited;
  FDualConnected := False;  // Dual δ����
  FDualSocket := INVALID_SOCKET;

  FRecvState := 0;
  FTargetHost := '';
  FTargetPort := 0;
  FUseTransObj := False;  // ���� TransmitFile

  // ���������
  FBroker := TInIOCPServer(FServer).IOCPBroker;

  if (TInIOCPBroker(FBroker).ProxyType = ptOuter) then  
    FBrokerId := 'DEFAULT';  // Ĭ�ϵ� FBrokerId

  if (TInIOCPBroker(FBroker).Protocol = tpHTTP) then
    FOnBind := HttpBindOuter  // http Э�飬ֱ���ڲ��󶨡�����
  else
  if (TInIOCPBroker(FBroker).ProxyType = ptDefault) then
    FOnBind := TInIOCPBroker(FBroker).OnBind  // ������¼�
  else  // �ⲿ�������������
    FOnBind := TIOCPBrokerRef(FBroker).BindInnerBroker;

end;

procedure TSocketBroker.InterCloseSocket(Sender: TObject);
begin
  // �ر� DualSocket
  if FDualConnected then
    try
      iocp_Winsock2.Shutdown(FDualSocket, SD_BOTH);
      iocp_Winsock2.CloseSocket(FDualSocket);
    finally
      FDualSocket := INVALID_SOCKET;
      FDualConnected := False;
    end;
  inherited;
end;

procedure TSocketBroker.MarkIODataBuf(AData: PPerIOData);
begin
  // AData �Ľ���״̬
  if (AData = FRecvBuf) then
    FRecvState := FRecvState or $0001  // Windows.InterlockedIncrement(FRecvState)
  else
    FRecvState := FRecvState or $0002; // Windows.InterlockedExchangeAdd(FRecvState, 2);
end;

procedure TSocketBroker.PostEvent(IOKind: TIODataType);
begin
  InterCloseSocket(Self);  // ֱ�ӹرգ��� TInIOCPServer.AcceptClient
end;

procedure TSocketBroker.SendInnerFlag;
begin
  // ����������ⲿ���������ӱ�־���� ExecSocketAction ִ��
  FAction := 1;  // �������
  FState := 0;   // ����
  TInIOCPServer(FServer).BusiWorkMgr.AddWork(Self);
end;

procedure TSocketBroker.SetConnection(AServer: TObject; Connection: TSocket);
begin
  // ��������������������ⲿ������
  IniSocket(AServer, Connection);
  FSocketType := stOuterSocket;  // ���ӵ��ⲿ��
  if (TInIOCPBroker(FBroker).Protocol = tpNone) then
    FOnBind := TInIOCPBroker(FBroker).OnBind; // �󶨹����¼�
end;

end.
