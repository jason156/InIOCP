(*
 * iocp ����˸����׽��ַ�װ
 *)
unit iocp_sockets;

interface

{$I in_iocp.inc}        // ģʽ����

uses
  windows, Classes, SysUtils, Variants, DateUtils,
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
    procedure SetSocket(const Value: TSocket); virtual;  
  public
    constructor Create(AddSocket: Boolean);
    destructor Destroy; override;
    procedure Close; virtual;
    procedure SetPeerAddr(const Addr: PSockAddrIn);
  public
    property Connected: Boolean read FConnected;
    property ErrorCode: Integer read FErrorCode;
    property PeerIP: String read FPeerIP;
    property PeerPort: Integer read FPeerPort;
    property PeerIPPort: String read FPeerIPPort;
    property Socket: TSocket read FSocket write SetSocket;
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

  // ================== ����˽��յ������� ======================

  TReceiveParams = class(TReceivePack)
  private
    FMsgHead: PMsgHead;      // Э��ͷλ�� 
    FSocket: TIOCPSocket;    // ����
  public
    constructor Create(AOwner: TIOCPSocket);
    function GetData: Variant; override;
    function ToJSON: AnsiString; override;
    procedure CreateAttachment(const LocalPath: string); override;
  public
    property Socket: TIOCPSocket read FSocket;
    property AttachPath: string read GetAttachPath;
  end;

  // ================== �������ͻ��˵����� ======================

  TReturnResult = class(TBaseMessage)
  private
    FSocket: TIOCPSocket;     // ����
    FSender: TBaseTaskSender; // ��������
    procedure ReturnHead(AActResult: TActionResult = arOK);
    procedure ReturnResult;
  public
    constructor Create(AOwner: TIOCPSocket); reintroduce;
    procedure LoadFromFile(const AFileName: String; OpenAtOnce: Boolean = False); override;
    procedure LoadFromVariant(AData: Variant); override;
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
    FPool: TIOCPSocketPool;    // �����أ�������TLinkRec��

    FRecvBuf: PPerIOData;      // �����õ����ݰ�
    FSender: TBaseTaskSender;  // ���ݷ����������ã�
    FWorker: TBaseWorker;      // ҵ��ִ���ߣ����ã�

    FByteCount: Cardinal;      // �����ֽ���
    FComplete: Boolean;        // �������/����ҵ��

    FRefCount: Integer;        // ������
    FState: Integer;           // ״̬��ԭ�Ӳ���������
    FTickCount: Cardinal;      // �ͻ��˷��ʺ�����
    FUseTransObj: Boolean;     // ʹ�� TTransmitObject ����
    
    function CheckDelayed(ATickCount: Cardinal): Boolean;
    function GetActive: Boolean;
    function GetReference: Boolean;
    function GetSocketState: Boolean;

    procedure InterCloseSocket(Sender: TObject); 
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
    procedure ExecuteWork; virtual; abstract;  // �������
    procedure InternalPush(AData: PPerIOData); // �������
    procedure SetSocket(const Value: TSocket); override;
    procedure SocketError(IOKind: TIODataType); virtual;
  public
    constructor Create(APool: TIOCPSocketPool; ALinkNode: PLinkRec); virtual;
    destructor Destroy; override;

    // ��ʱ���
    function CheckTimeOut(ANowTickCount: Cardinal): Boolean;

    // ��¡��ת����Դ��
    procedure Clone(Source: TBaseSocket);

    // �ر�
    procedure Close; override;

    // ҵ���̵߳������
    procedure DoWork(AWorker: TBaseWorker; ASender: TBaseTaskSender);

    {$IFDEF TRANSMIT_FILE}
    procedure FreeTransmitRes;  // �ͷ� TransmitFile ����Դ
    {$ENDIF}
    
    // ����ǰ����
    function Lock(PushMode: Boolean): Integer; virtual;

    // Ͷ�ݽ���
    procedure PostRecv; virtual;

    // Ͷ���¼�����ɾ�����ܾ����񡢳�ʱ
    procedure PostEvent(IOKind: TIODataType); virtual; abstract;

    // ���Թر�
    procedure TryClose;

    // ���õ�Ԫ����
    class procedure SetUnitVariables(Server: TObject);
  public
    property Active: Boolean read GetActive;
    property Complete: Boolean read FComplete;
    property LinkNode: PLinkRec read FLinkNode;
    property Pool: TIOCPSocketPool read FPool;
    property RecvBuf: PPerIOData read FRecvBuf;
    property Reference: Boolean read GetReference;
    property Sender: TBaseTaskSender read FSender;
    property SocketState: Boolean read GetSocketState;
    property Worker: TBaseWorker read FWorker;
  end;

  TBaseSocketClass = class of TBaseSocket;

  // ================== TStreamSocket ԭʼ������ ==================

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

  // ================== ����� WebSocket �� ==================

  TResultJSON = class(TSendJSON)
  public
    property DataSet;
  end;
  
  TWebSocket = class(TStreamSocket)
  protected
    FReceiver: TWSServerReceiver;  // ���ݽ�����
    FJSON: TBaseJSON;          // �յ��� JSON ����
    FResult: TResultJSON;      // Ҫ���ص� JSON ����
        
    FData: PAnsiChar;          // �����յ�����������λ��
    FMsgSize: UInt64;          // ��ǰ��Ϣ�յ����ۼƳ���
    FFrameSize: UInt64;        // ��ǰ֡����
    FFrameRecvSize: UInt64;    // �����յ������ݳ���

    FMsgType: TWSMsgType;      // ��������
    FOpCode: TWSOpCode;        // WebSocket ��������
    FRole: TClientRole;        // �ͻ�Ȩ�ޣ�Ԥ�裩
    FUserName: TNameString;    // �û����ƣ�Ԥ�裩

    procedure ClearMsgOwner(Buf: PAnsiChar; Len: Integer);
    procedure InternalPing;    
  protected
    procedure ClearResources; override;
    procedure ExecuteWork; override;
    procedure InterPush(Target: TWebSocket = nil);
    procedure SetProps(AOpCode: TWSOpCode; AMsgType: TWSMsgType;
                       AData: Pointer; AFrameSize: Int64; ARecvSize: Cardinal);
  public
    constructor Create(APool: TIOCPSocketPool; ALinkNode: PLinkRec); override;
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

  // ================== C/S ģʽҵ���� ==================

  TIOCPSocket = class(TBaseSocket)
  private
    FReceiver: TServerReceiver;// ���ݽ�����
    FParams: TReceiveParams;   // ���յ�����Ϣ����������
    FResult: TReturnResult;    // ���ص�����
    FData: PEnvironmentVar;    // ����������Ϣ
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
    procedure ReturnMessage(ActResult: TActionResult; const ErrMsg: String = ''); 
    procedure SetSocket(const Value: TSocket); override;
    procedure SocketError(IOKind: TIODataType); override;
  public
    destructor Destroy; override;
  public
    // ҵ��ģ�����
    procedure Push(Target: TIOCPSocket = nil);
    procedure PostEvent(IOKind: TIODataType); override;
    procedure SetLogState(AData: PEnvironmentVar);
    procedure SetUniqueMsgId;
  public
    property Action: TActionType read FAction;
    property Data: PEnvironmentVar read FData;
    property Params: TReceiveParams read FParams;
    property Result: TReturnResult read FResult;
    property SessionId: Cardinal read FSessionId;
  end;

  // ================== Socket Http ���� ==================

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

  // ================== TSocketBroker �����׽��� ==================

  TSocketBroker = class;

  TBindIPEvent  = procedure(Sender: TSocketBroker; const Data: PAnsiChar;
                            DataSize: Cardinal) of object;
  TOuterPingEvent  = TBindIPEvent;

  TSocketBroker = class(TBaseSocket)
  private
    FDual: TSocketBroker;      // �������м�
    FAction: Integer;          // ��ʼ��

    FContentLength: Integer;   // Http ʵ���ܳ�
    FReceiveSize: Integer;     // Http �յ���ʵ�峤��
    FSocketType: TSocketBrokerType;  // ����

    FTargetHost: AnsiString;   // ������������ַ
    FTargetPort: Integer;      // �����ķ������˿�
    FToSocket: TSocket;        // ������Ŀ���׽���

    FOnBind: TBindIPEvent;     // ���¼�

    function CheckInnerSocket: Boolean;
    function ChangeConnection(const ABrokerId, AServer: AnsiString; APort: Integer): Boolean;

    procedure ExecSocketAction;
    procedure ForwardData;

    // HTTP Э��
    procedure HttpBindOuter(Connection: TSocketBroker; const Data: PAnsiChar; DataSize: Cardinal);
    procedure HttpConnectHost(const AServer: AnsiString; APort: Integer);  // ���ӵ� HTTP �� Host
    procedure HttpRequestDecode;  // Http ����ļ򵥽���
  protected
    FBrokerId: AnsiString;     // �����ķ������ Id
    procedure ClearResources; override;
    procedure ExecuteWork; override;
  protected
    procedure AssociateInner(InnerBroker: TSocketBroker);
    procedure SendInnerFlag;
    procedure SetConnection(Connection: TSocket);
    procedure SetSocket(const Value: TSocket); override;
  public
    function  Lock(PushMode: Boolean): Integer; override;
    procedure CreateBroker(const AServer: AnsiString; APort: Integer);  // �������м�
    procedure PostEvent(IOKind: TIODataType); override;
  end;

implementation

uses
  iocp_server, http_base, http_utils, iocp_threads, iocp_managers;

type
  THeadMessage   = class(TBaseMessage);
  TInIOCPBrokerX = class(TInIOCPBroker);

var
      FServer: TInIOCPServer = nil;   // ��Ԫ����������
  FGlobalLock: TThreadLock = nil;     // ȫ����
 FPushManager: TPushMsgManager = nil; // ��Ϣ���͹���
  FIOCPBroker: TInIOCPBroker = nil;   // �������
 FServerMsgId: TIOCPMsgId = 0;        // Ψһ������Ϣ��

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
    SetSocket(iocp_utils.CreateSocket);
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

procedure TRawSocket.SetSocket(const Value: TSocket);
begin
  // ���� Socket
  FSocket := Value;
  FConnected := FSocket <> INVALID_SOCKET;
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

function TReceiveParams.GetData: Variant;
begin
  Result := inherited GetData;
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

procedure TReturnResult.LoadFromVariant(AData: Variant);
begin
  inherited;  // ֱ�ӵ���
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
    FVarCount := FServer.IOCPSocketPool.UsedCount // �ͻ���Ҫ�ж�
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

{ TBaseSocket }

constructor TBaseSocket.Create(APool: TIOCPSocketPool; ALinkNode: PLinkRec);
begin
  inherited Create(False);
  // FSocket �ɿͻ��˽���ʱ����
  //   ����TInIOCPServer.AcceptClient
  //       TIOCPSocketPool.CreateObjData
  FPool := APool;
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
      Result := ANowTickCount - FTickCount >= FServer.TimeOut
    else
      Result := High(Cardinal) - FTickCount + ANowTickCount >= FServer.TimeOut;
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
  SetSocket(Source.FSocket);

  FPeerIP := Source.FPeerIP;
  FPeerPort := Source.FPeerPort;
  FPeerIPPort := Source.FPeerIPPort;

  // ��ע Source ����Դ��Ч
  Source.FSocket := INVALID_SOCKET;
  Source.FConnected := False;

  // δ�� FTask  
end;

procedure TBaseSocket.Close;
begin
  ClearResources;  // ֻ�����Դ�����ͷţ��´β����½�
  inherited;
end;

destructor TBaseSocket.Destroy;
begin
  // �ͷ�ʱ�Ż��գ�����TryClose��
  {$IFDEF TRANSMIT_FILE}
  if Assigned(FTask) then
    FTask.Free;
  {$ENDIF}
  if Assigned(FServer) then
    if FServer.Active and Assigned(FRecvBuf) then
    begin
      FServer.IODataPool.Push(FRecvBuf^.Node);
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
  if (Complete = False) and (FServer.TimeOut > 0) then
    Dec(FTickCount, 10000);

  // ���ص��ṹ
  FillChar(FRecvBuf^.Overlapped, SizeOf(TOverlapped), 0);

  FRecvBuf^.Owner := Self;  // ����
  FRecvBuf^.IOType := ioReceive;  // iocp_server ���ж���
  FRecvBuf^.Data.len := IO_BUFFER_SIZE; // �ָ�
  FRecvBuf^.RefCount := 0;  // �����ã����Ը�Ϊ FRefCount

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
        Result := SOCKET_LOCK_OK;  // ��������
      end;
      if (Result = SOCKET_LOCK_FAIL) then // ҵ��δ��ɣ�������
        if (windows.InterlockedDecrement(FState) <> 0) then
          InterCloseSocket(Self);
    end;

    SOCKET_STATE_BUSY,
    SOCKET_STATE_TRANS:
      Result := SOCKET_LOCK_FAIL;  // ����

    else
      Result := SOCKET_LOCK_CLOSE; // �ѹرջ������쳣
  end;
end;

procedure TBaseSocket.InterCloseSocket(Sender: TObject);
begin
  // �ڲ��ر�
  windows.InterlockedExchange(Integer(FByteCount), 0); // ������������
  windows.InterlockedExchange(FState, 9);  // ��Ч״̬
  FServer.CloseSocket(Self);  // �ùر��̣߳������ظ��رգ�
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

class procedure TBaseSocket.SetUnitVariables(Server: TObject);
begin
  // ���õ�Ԫ����������
  FServer := TInIOCPServer(Server);
  if Assigned(Server) then
  begin
    FIOCPBroker := FServer.IOCPBroker;
    FGlobalLock := FServer.GlobalLock;
    FPushManager := FServer.PushManager;
  end else
  begin
    FIOCPBroker := nil;
    FGlobalLock := nil;
    FPushManager := nil;
  end;
end;

procedure TBaseSocket.SetSocket(const Value: TSocket);
begin
  inherited;
  // ��������ڴ�飨�ر�ʱ�����գ��� TryClose��
  if (FRecvBuf = nil) then
  begin
    FRecvBuf := FServer.IODataPool.Pop^.Data;
    FRecvBuf^.IOType := ioReceive;  // ����
    FRecvBuf^.Owner := Self;  // ����
  end;

  FByteCount := 0;   // �������ݳ���
  FComplete := True; // �ȴ�����
  FErrorCode := 0;   // ���쳣
  FState := 9;       // ��Ч״̬��Ͷ�� Recv ������ʽʹ��

  // ���ֵ����ֹ�����Ϊ��ʱ��
  //   ����TTimeoutThread.ExecuteWork
  FTickCount := NEW_TICKCOUNT;

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
    if Assigned(FServer.OnDataReceive) then
      FServer.OnDataReceive(Self, FRecvBuf^.Data.buf, FByteCount);
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

constructor TWebSocket.Create(APool: TIOCPSocketPool; ALinkNode: PLinkRec);
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
  // �������ݣ��� TReceiveSocket ���ƣ�

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
      FWorker.WSExecute(Self);
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
  if FServer.PushManager.AddWork(Msg) then
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

{ TIOCPSocket }

function TIOCPSocket.CheckMsgHead(InBuf: PAnsiChar): Boolean;
  function CheckLogState: TActionResult;
  begin
    // ����¼״̬
    if (FParams.Action = atUserLogin) then
      Result := arOK       // ͨ��
    else
    if (FParams.SessionId = 0) then
      Result := arErrUser  // �ͻ��˲����� SessionId, ���Ƿ��û�(
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
      if Assigned(FServer.ClientManager) then
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
begin
  // ����һ����¼ƾ֤����Ч��Ϊ SESSION_TIMEOUT ����
  //   �ṹ��(�������� + ��Ч����) xor ��
  NowTime := Now();
  Certify.DayCount := Trunc(NowTime - 42500);  // ��������
  Certify.Timeout := HourOf(NowTime) * 60 + MinuteOf(NowTime) + SESSION_TIMEOUT;
  Result := Certify.Session xor (Cardinal($A0250000) + YearOf(NowTime));
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
  FPushManager.AddWork(Msg);
end;

procedure TIOCPSocket.Push(Target: TIOCPSocket);
var
  Msg: TPushMessage;
begin
  // ���յ�����Ϣ�� Target ��㲥
  //   �ύ�������̣߳���֪����ʱ�������Ƿ�ɹ���

  SetUniqueMsgId;  // ��Ψһ�� MsgID

  if Assigned(Target) then  // ���� Target
  begin
    Msg := TPushMessage.Create(FRecvBuf, False);
    Msg.Add(Target);  // ���� Target
  end else  // �㲥
    Msg := TPushMessage.Create(FRecvBuf, True);

  // ���������߳�
  if FServer.PushManager.AddWork(Msg) then
    Result.ActResult := arOK
  else
    Result.ActResult := arErrBusy; // ��æ��������Msg �ѱ��ͷ�
    
end;

procedure TIOCPSocket.SetLogoutState;
begin
  // ���õǳ�״̬
  FSessionId := INI_SESSION_ID;
  if Assigned(FData) then
    if FData^.ReuseSession then  // �����ӶϿ������� FData ��Ҫ��Ϣ
    begin
      FData^.BaseInf.Socket := 0;
      FData^.BaseInf.LogoutTime := Now();
    end else
      try  // �ͷŵ�¼��Ϣ
        FServer.ClientManager.ClientList.Remove(FData^.BaseInf.Name);
      finally
        FData := Nil;
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

procedure TIOCPSocket.SetLogState(AData: PEnvironmentVar);
begin
  // ���õ�¼/�ǳ���Ϣ
  if (AData = nil) then  // �ǳ�
  begin
    SetLogoutState;
    FResult.FSessionId := FSessionId;
    FResult.ActResult := arLogout;  // ���� arOffline
    if Assigned(FData) then  // �������� Socket
      FData := nil;
  end else
  begin
    FSessionId := CreateSession;  // �ؽ��Ի���
    FResult.FSessionId := FSessionId;
    FResult.ActResult := arOK;
    FData := AData;
  end;
end;

procedure TIOCPSocket.SetUniqueMsgId;
begin
  // ����������Ϣ�� MsgId
  //   ������Ϣ���÷�������Ψһ MsgId
  
  {$IFDEF WIN64}
  FParams.FMsgId := System.AtomicIncrement(FServerMsgId);
  {$ELSE}
  FGlobalLock.Acquire;
  try
    Inc(FServerMsgId);
    FParams.FMsgId := FServerMsgId;
  finally
    FGlobalLock.Release;
  end;
  {$ENDIF}

  // �޸Ļ���� MsgId
  // ��Ҫ�� FResult.FMsgId������ͻ��˰ѷ��ͷ�������������Ϣ����
  FParams.FMsgHead^.MsgId := FParams.FMsgId;

end;

procedure TIOCPSocket.SetSocket(const Value: TSocket);
begin
  inherited;
  FSessionId := INI_SESSION_ID; // ��ʼƾ֤
end;

function TIOCPSocket.SessionValid(ASession: Cardinal): Boolean;
var
  NowTime: TDateTime;
  Certify: TCertifyNumber;
begin
  // ���ƾ֤�Ƿ���ȷ��û��ʱ
  //   �ṹ��(�������� + ��Ч����) xor ��
  NowTime := Now();
  Certify.Session := ASession xor (Cardinal($A0250000) + YearOf(NowTime));

  Result := (Certify.DayCount = Trunc(NowTime - 42500)) and
            (Certify.Timeout > HourOf(NowTime) * 60 + MinuteOf(NowTime));

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
    FRequest := THttpRequest.Create(Self); // http ����
    FRespone := THttpRespone.Create(Self); // http Ӧ��
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
      UpgradeSocket(FServer.IOCPSocketPool);
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
        UpgradeSocket(FServer.WebSocketPool);
      end else  // �������������ر�
        InterCloseSocket(Self);
      Exit;
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
  FPushManager.AddWork(Msg);
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

{ TSocketBroker }

procedure TSocketBroker.AssociateInner(InnerBroker: TSocketBroker);
begin
  // ���ڲ����ӹ����������Ѿ�Ͷ�� WSARecv��
  if (InnerBroker.ErrorCode = 0) then
  begin
    FDual := InnerBroker;
    FToSocket := InnerBroker.FSocket;

    InnerBroker.FDual := Self;
    InnerBroker.FToSocket := FSocket;
    InnerBroker.FState := 1;  // ����
    
    InnerBroker.FBrokerId := FBrokerId;
    InnerBroker.FTargetHost := FTargetHost;
    InnerBroker.FTargetPort := FTargetPort;

    FDual.FOnBind := nil;  // ɾ��
  end;
  if (FSocketType = stWebSocket) or (FIOCPBroker.Protocol = tpNone) then
    FOnBind := nil;  // ɾ�����¼����Ժ��ٰ󶨣�
end;

function TSocketBroker.ChangeConnection(const ABrokerId, AServer: AnsiString; APort: Integer): Boolean;
begin
  // �������Ƿ��Ѿ��ı�
  if (FIOCPBroker.ProxyType = ptOuter) then
    Result := (ABrokerId <> FBrokerId)  // �������ı�
  else
    Result := not (((AServer = FTargetHost) or
                    (LowerCase(AServer) = 'localhost') and (FTargetHost = '127.0.0.1') or
                    (LowerCase(FTargetHost) = 'localhost') and (AServer = '127.0.0.1')) and (
                    (APort = FTargetPort) or (APort = FServer.ServerPort)));
end;

function TSocketBroker.CheckInnerSocket: Boolean;
begin
  // ++�ⲿ����ģʽ
  if (PInIOCPInnerSocket(FRecvBuf^.Data.buf)^ = InIOCP_INNER_SOCKET) then
  begin
    // �����ڲ��ķ���������ӣ����浽�б�
    SetString(FBrokerId, FRecvBuf^.Data.buf + Length(InIOCP_INNER_SOCKET) + 1,
                         Integer(FByteCount) - Length(InIOCP_INNER_SOCKET) - 1);
    TInIOCPBrokerX(FIOCPBroker).AddConnection(Self, FBrokerId);
    Result := True;
  end else
    Result := False;  // �����ⲿ�Ŀͻ�������
end;

procedure TSocketBroker.ClearResources;
begin
  // �������δ���������ӱ��Ͽ������ⲹ������
  if FIOCPBroker.ReverseMode and (FSocketType = stOuterSocket) then
    TInIOCPBrokerX(FIOCPBroker).ConnectOuter;
  if Assigned(FDual) then  // ���Թر�
    FDual.TryClose;
end;

procedure TSocketBroker.CreateBroker(const AServer: AnsiString; APort: Integer);
begin
  // �½�һ���ڲ������м��׽��֣�

  if Assigned(FDual) then  
  begin
    if (FDual.ChangeConnection(FBrokerId, AServer, APort) = False) then
      Exit;
    FDual.InternalClose;  // �ر�
  end else  // �½��ڲ�����
    FDual := TSocketBroker(FPool.Pop^.Data);

  // ���׽���
  FDual.SetSocket(iocp_utils.CreateSocket);

  if ConnectSocket(FDual.FSocket, AServer, APort) and  // ����
    FServer.IOCPEngine.BindIoCompletionPort(FDual.FSocket) then  // ��
  begin
    FTargetHost := AServer;
    FTargetPort := APort;
    FToSocket := FDual.FSocket;

    // ��������
    FDual.FDual := Self;
    FDual.FToSocket := FSocket;

    FDual.FBrokerId := FBrokerId;
    FDual.FTargetPort := APort;
    FDual.FTargetHost := AServer;
    FDual.FOnBind := nil;  // ɾ��

    // Ͷ��
    FDual.PostRecv;
    FDual.FState := 1;  // ����    
    FErrorCode := FDual.ErrorCode;
  end else
    FErrorCode := GetLastError;

  if (FErrorCode > 0) then  // �رմ���
  begin
    FDual.FDual := nil;
    FDual.InternalClose;
    FDual.InterCloseSocket(FDual);
    FDual := nil;
  end;

  // ����������ⲹ������
  if FIOCPBroker.ReverseMode then
  begin
    FSocketType := stDefault;  // �ı䣬�ر�ʱ����������
    TInIOCPBrokerX(FIOCPBroker).ConnectOuter;
  end;

  if (FSocketType = stWebSocket) or (FIOCPBroker.Protocol = tpNone) then
    FOnBind := nil;  // ɾ�����¼����Ժ��ٰ󶨣�

end;

procedure TSocketBroker.ExecuteWork;
begin
  // ִ�У�
  //   1���󶨡������������ⲿ���ݵ� FDual
  //   2���Ѿ�����ʱֱ�ӷ��͵� FDual
  
  if (FConnected = False) then
    Exit;

  // Ҫ�������� TInIOCPBroker.ProxyType 
  case FIOCPBroker.ProxyType of
    ptDefault:
      if (FAction > 0) then  // ����SendInnerFlag
      begin
        ExecSocketAction;    // ִ�в���������
        InternalRecv(True);
        Exit;
      end;
    ptOuter:  // �ⲿ����
      if not Assigned(FDual) and CheckInnerSocket then  // �����������
      begin
        InternalRecv(True);  // ��Ͷ��
        Exit;
      end;
  end;

  if Assigned(FOnBind) then
    try
      FOnBind(Self, FRecvBuf^.Data.buf, FByteCount)  // �󶨡�����
    finally
      if Assigned(FDual) then
        ForwardData  // ת������
      else
        InterCloseSocket(Self);
    end
  else
    if Assigned(FDual) then
      ForwardData;  // ת������

end;

procedure TSocketBroker.ExecSocketAction;
begin
  // �����ڲ����ӱ�־���ⲿ����
  try
    if (FIOCPBroker.BrokerId = '') then  // ��Ĭ�ϱ�־
      FSender.Send(InIOCP_INNER_SOCKET + ':DEFAULT')
    else  // ͬʱ���ʹ����־�������ⲿ��������
      FSender.Send(InIOCP_INNER_SOCKET + ':' + UpperCase(FIOCPBroker.BrokerId));
  finally
    FAction := 0;
  end;
end;

procedure TSocketBroker.ForwardData;
  procedure ResetDualState;
  begin
    if (windows.InterlockedDecrement(FDual.FState) <> 0) then
      FDual.InterCloseSocket(FDual);
  end;
begin
  // ���ơ�ת�����ݣ����ܼ򵥻������ݿ飬����󲢷�ʱ 995 �쳣��:
  try
    FSender.Socket := FToSocket;  // �ı䣨ԭ��Ϊ�Լ��ģ�
    TServerTaskSender(FSender).CopySend(FRecvBuf);
  finally
    if (FErrorCode = 0) then
    begin
      InternalRecv(FComplete);
      ResetDualState;
    end else
    begin
      ResetDualState;    
      InterCloseSocket(Self);
    end;
  end;
end;

procedure TSocketBroker.HttpConnectHost(const AServer: AnsiString; APort: Integer);
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

procedure TSocketBroker.HttpRequestDecode;
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
  procedure GetContentLength(var p: PAnsiChar);
  var
    S: AnsiString;
    pb: PAnsiChar;
  begin
    // ��ȡ���ݳ��ȣ�CONTENT-LENGTH: 1234
    pb := nil;
    Inc(p, 14);
    repeat
      case p^ of
        ':':
          pb := p + 1;
        #13: begin
          SetString(S, pb, p - pb);
          TryStrToInt(S, FContentLength);
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
        '@':
          k := i;
      end;

    if (k > 0) then  // ��������־
    begin
      if (FIOCPBroker.ProxyType = ptOuter) then  // �ⲿ����
        FBrokerId := Copy(FTargetHost, k + 1, 99);
      Delete(FTargetHost, k, 99);
    end;

    if (j > 0) then  // �ڲ�����
    begin
      TryStrToInt(Copy(FTargetHost, j + 1, 99), FTargetPort);
      Delete(FTargetHost, j, 99);
    end;
    
  end;

var
  iState: Integer;
  pE, pb, p: PAnsiChar;
begin
  // Http Э�飺��ȡ������Ϣ��Host��Content-Length��Upgrade

  FContentLength := 0;  // �ܳ�
  FReceiveSize := 0;    // �յ��ĳ���
  iState := 0;          // ��Ϣ״̬

  p := FRecvBuf^.Data.buf;  // ��ʼλ��
  pE := PAnsiChar(p + FByteCount);  // ����λ��
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
            if (p < pE) then  // ��������ݣ�POST
              FReceiveSize := pE - p;
            Break;
          end else
          if (p - pb >= 15) then
          begin
            if http_utils.CompareBuffer(pb, 'HOST', True) then
            begin
              iState := iState xor 1;
              GetHttpHost(pb);
              ExtractHostPort;
            end else
            if http_utils.CompareBuffer(pb, 'CONTENT-LENGTH', True) then
            begin
              iState := iState xor 2;
              GetContentLength(pb);
            end else
            if http_utils.CompareBuffer(pb, 'UPGRADE', True) then  // WebSocket
            begin
              iState := iState xor 2;
              GetUpgradeType(pb);
            end;
          end;
    end;

    Inc(p);
  until (p >= pE) or (iState = 3);

  // ��Ĭ������
  if (FIOCPBroker.ProxyType = ptDefault) then
  begin
    if (FTargetHost = '') then
      FTargetHost := FIOCPBroker.DefaultInnerAddr;
    if (FTargetPort = 0) then
      FTargetPort := FIOCPBroker.DefaultInnerPort;
  end;

  // �Ƿ������
  FComplete := FReceiveSize >= FContentLength;

end;

function TSocketBroker.Lock(PushMode: Boolean): Integer;
const
  SOCKET_STATE_IDLE  = 0;  // ����
  SOCKET_STATE_BUSY  = 1;  // ����
  SOCKET_STATE_TRANS = 2;  // TransmitFile ���� 
begin
  // ���ǻ��෽����û������ģʽ
  case iocp_api.InterlockedCompareExchange(FState, 1, 0) of  // ����ԭֵ

    SOCKET_STATE_IDLE: begin
      if not Assigned(FDual) or
        (iocp_api.InterlockedCompareExchange(FDual.FState, 1, 0) = SOCKET_STATE_IDLE) then
        Result := SOCKET_LOCK_OK
      else
        Result := SOCKET_LOCK_FAIL;
      if (Result = SOCKET_LOCK_FAIL) then // ������
        if (windows.InterlockedDecrement(FState) <> 0) then
          InterCloseSocket(Self);
    end;

    SOCKET_STATE_BUSY,
    SOCKET_STATE_TRANS:
      Result := SOCKET_LOCK_FAIL;  // ����

    else
      Result := SOCKET_LOCK_CLOSE; // �ѹرջ������쳣
  end;
end;

procedure TSocketBroker.HttpBindOuter(Connection: TSocketBroker; const Data: PAnsiChar; DataSize: Cardinal);
begin
  // Http Э�飺�ⲿ�ͻ��˴������ݣ������ڲ�����
  if FComplete then  // �µ�����
  begin
    HttpRequestDecode;  // ��ȡ��Ϣ
    if (FIOCPBroker.ProxyType = ptDefault) then  // �½����ӣ�����
      HttpConnectHost(FIOCPBroker.InnerServer.ServerAddr,
                      FIOCPBroker.InnerServer.ServerPort)
    else  // ���ڲ����ӳ�ѡȡ��������
    if not Assigned(FDual) or FDual.ChangeConnection(FBrokerId, FTargetHost, FTargetPort) then
      TInIOCPBrokerX(FIOCPBroker).BindBroker(Connection, Data, DataSize);
  end else
  begin  // �յ��ĵ�ǰ�����ʵ������+
    Inc(FReceiveSize, FByteCount);
    FComplete := FReceiveSize >= FContentLength;
  end;
end;

procedure TSocketBroker.PostEvent(IOKind: TIODataType);
begin
  InterCloseSocket(Self);  // ֱ�ӹرգ��� TInIOCPServer.AcceptClient
end;

procedure TSocketBroker.SendInnerFlag;
begin
  // ���ⲿ���������ӱ�־
  FAction := 1;  // �������
  FState := 0;
  FRecvBuf^.RefCount := 1;
  FServer.BusiWorkMgr.AddWork(Self);
end;

procedure TSocketBroker.SetConnection(Connection: TSocket);
begin
  // ��������������������ⲿ������
  SetSocket(Connection);
  FSocketType := stOuterSocket;  // ���ӵ��ⲿ��
  if (FIOCPBroker.Protocol = tpNone) then 
    FOnBind := FIOCPBroker.OnBind; // �󶨹����¼�
end;

procedure TSocketBroker.SetSocket(const Value: TSocket);
begin
  inherited;

  FDual := nil;
  FTargetHost := '';
  FTargetPort := 0;
  FToSocket := INVALID_SOCKET;
  FUseTransObj := False;  // ���� TransmitFile

  // Ĭ�ϵ� FBrokerId
  if (FIOCPBroker.ProxyType = ptOuter) then
    FBrokerId := 'DEFAULT';

  if (FIOCPBroker.Protocol = tpHTTP) then  // http Э�飬ֱ���ڲ��󶨡�����
    FOnBind := HttpBindOuter
  else
  if (FIOCPBroker.ProxyType = ptDefault) then
    FOnBind := FIOCPBroker.OnBind  // �󶨹����¼�
  else // �ⲿ�����Զ���
    FOnBind := TInIOCPBrokerX(FIOCPBroker).BindBroker;
end;

end.
