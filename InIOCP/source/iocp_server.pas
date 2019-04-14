(*
 * iocp �������������̳߳ء��ر��̵߳�
 *)
unit iocp_server;

interface

{$I in_iocp.inc}        // ģʽ����

uses
  Windows, Classes, SysUtils, ActiveX,
  iocp_Winsock2, iocp_log, iocp_base,
  iocp_baseObjs, iocp_objPools, iocp_threads,
  iocp_sockets, iocp_managers, iocp_wsExt, 
  iocp_lists, iocp_api, http_objects;

type

  TIOCPEngine     = class;    // IOCP ����
  TInIOCPServer   = class;    // IOCP ������
  TAcceptManager  = class;    // AcceptEx ģʽ����

  TWorkThread     = class;    // �����߳�
  TWorkThreadPool = class;    // �����̳߳�
  TTimeoutThread  = class;    // ��ʱ����߳�

  // ================== IOCP ���� ==================

  TIOCPEngine = class(TObject)
  private
    FHandle: THandle;
  public
    constructor Create;
    destructor Destroy; override;
  public
    function BindIoCompletionPort(Socket: TSocket): Boolean;
                                  {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetIoCompletionStatus(var ByteCount: Cardinal;
                                   var PerIOData: PPerIOData): Boolean;
                                   {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure StopIoCompletionPort;
  end;

  // ================== TInIOCPServer �������������� �� ======================

  TServerParams = class(TPersistent)
  private
    FOwner: TInIOCPServer;    // ����
    function GetBusyRefuseService: Boolean;  // ��æ�ܾ�����
    function GetClientPoolSize: Integer;     // Ԥ��ͻ�������
    function GetMaxPushCount: Integer;       // ����ÿ�����������
    function GetMaxQueueCount: Integer;      // �����������������
    function GetMaxIOTraffic: Integer;         // �������
    function GetPreventAttack: Boolean;      // ������
    function GetTimeOut: Cardinal;           // ���ó�ʱ���
    procedure SetBusyRefuseService(const Value: Boolean);
    procedure SetClientPoolSize(const Value: Integer);
    procedure SetMaxPushCount(const Value: Integer);
    procedure SetMaxQueueCount(const Value: Integer);
    procedure SetMaxIOTraffic(const Value: Integer);
    procedure SetPreventAttack(const Value: Boolean);
    procedure SetTimeOut(const Value: Cardinal);
  public
    constructor Create(AOwner: TInIOCPServer);
  published
    property BusyRefuseService: Boolean read GetBusyRefuseService write SetBusyRefuseService default False;
    property ClientPoolSize: Integer read GetClientPoolSize write SetClientPoolSize default 0;
    property MaxPushCount: Integer read GetMaxPushCount write SetMaxPushCount default 10000;
    property MaxQueueCount: Integer read GetMaxQueueCount write SetMaxQueueCount default 0;
    property MaxIOTraffic: Integer read GetMaxIOTraffic write SetMaxIOTraffic default 0;
    property PreventAttack: Boolean read GetPreventAttack write SetPreventAttack default False;
    property TimeOut: Cardinal read GetTimeOut write SetTimeOut default TIME_OUT_INTERVAL;
  end;

  // ================== TInIOCPServer �����߳������� �� ======================

  TThreadOptions = class(TPersistent)
  private
    FOwner: TInIOCPServer;
    function GetBusiThreadCount: Integer;   // ȡҵ���߳���
    function GetPushThreadCount: Integer;   // ȡ�����߳���
    function GetWorkThreadCount: Integer;   // ȡ�����߳���
    procedure SetBusiThreadCount(const Value: Integer);
    procedure SetPushThreadCount(const Value: Integer);
    procedure SetWorkThreadCount(const Value: Integer);    // ����
  public
    constructor Create(AOwner: TInIOCPServer);
  published
    property BusinessThreadCount: Integer read GetBusiThreadCount write SetBusiThreadCount;
    property PushThreadCount: Integer read GetPushThreadCount write SetPushThreadCount;    
    property WorkThreadCount: Integer read GetWorkThreadCount write SetWorkThreadCount;    
  end;

  // ================== TInIOCPServer ������������ �� ======================

  TIOCPManagers = class(TPersistent)
  private
    FOwner: TInIOCPServer;   // ����
    function GetClientMgr: TInClientManager;       // �ͻ��˹���
    function GetCustomMgr: TInCustomManager;       // �Զ�����Ϣ
    function GetDatabaseMgr: TInDatabaseManager;   // ���ݿ����
    function GetFileMgr: TInFileManager;           // �ļ�����
    function GetMessageMgr: TInMessageManager;     // ��Ϣ����
  private
    procedure SetClientMgr(const Value: TInClientManager);
    procedure SetCustomMgr(const Value: TInCustomManager);
    procedure SetDatabaseMgr(const Value: TInDatabaseManager);
    procedure SetFileMgr(const Value: TInFileManager);
    procedure SetMessageMgr(const Value: TInMessageManager);
  public
    constructor Create(AOwner: TInIOCPServer);
  published
    property ClientManager: TInClientManager read GetClientMgr write SetClientMgr;
    property CustomManager: TInCustomManager read GetCustomMgr write SetCustomMgr;
    property DatabaseManager: TInDatabaseManager read GetDatabaseMgr write SetDatabaseMgr;
    property FileManager: TInFileManager read GetFileMgr write SetFileMgr;
    property MessageManager: TInMessageManager read GetMessageMgr write SetMessageMgr;
  end;
  
  // ================== TInIOCPServer ������ �� ==================

  TOnConnectEvnet   = procedure(Sender: TObject; Socket: TBaseSocket) of object;
  TOnStreamInEvent  = procedure(Sender: TBaseSocket; const Data: PAnsiChar; Size: Cardinal) of object;
  TOnStreamOutEvent = procedure(Sender: TBaseSocket; Size: Cardinal) of object;
  TOnErrorEvent     = procedure(Sender: TObject; const Error: Exception) of object;

  TInIOCPServer = class(TComponent)
  private
    FIODataPool: TIODataPool;            // �ڴ����
    FSocketPool: TIOCPSocketPool;        // C/S �ͻ��˹���
    FHttpSocketPool: TIOCPSocketPool;    // http �ͻ��˹���
    FWebSocketPool: TIOCPSocketPool;     // WebSocket �ͻ���

    FAcceptManager: TAcceptManager;      // AcceptEx ����
    FBusiWorkMgr: TBusiWorkManager;      // ҵ�����
    FPushManager: TPushMsgManager;       // ��Ϣ���͹���

    FCheckThread: TTimeoutThread;        // ����������߳�
    FCloseThread: TCloseSocketThread;    // �ر� Socket ��ר���߳�

    FListenSocket: TListenSocket;        // �����׽���
    FIOCPEngine: TIOCPEngine;            // IOCP ����
    FWorkThreadPool: TWorkThreadPool;    // �����̳߳�

    FActive: Boolean;                    // ����״̬
    FBusyRefuseService: Boolean;         // ��æ�ܾ�����
    FClientPoolSize: Integer;            // Ԥ��ͻ�������
    FGlobalLock: TThreadLock;            // ȫ����
    FIOCPManagers: TIOCPManagers;        // ������������
    FMaxQueueCount: Integer;             // �����������������
    FMaxPushCount: Integer;              // ����ÿ�����������Ϣ��
    FMaxIOTraffic: Integer;              // ����ÿ���������

    FPeerIPList: TPreventAttack;         // ����� IP �б�
    FPreventAttack: Boolean;             // ������

    FServerAddr: String;                 // ��������ַ
    FServerPort: Word;                   // �˿�

    FSessionMgr: THttpSessionManager;    // Http �ĻỰ�������ã�
    FStartParams: TServerParams;         // ��������������
    FState: Integer;                     // ״̬
    FStreamMode: Boolean;                // ����������ģʽ
    FTimeOut: Cardinal;                  // ��ʱ�����0ʱ����飩
    FTimeoutChecking: Boolean;           // �ر��̹߳���״̬
    
    FThreadOptions: TThreadOptions;      // �߳�����
    FBusiThreadCount: Integer;           // ҵ���߳���
    FPushThreadCount: Integer;           // �����߳���
    FWorkThreadCount: Integer;           // �����߳���

    // =========== ��������� ===========

    FIOCPBroker: TInIOCPBroker;          // ������
    FClientMgr: TInClientManager;        // �ͻ��˹���
    FCustomMgr: TInCustomManager;        // �Զ�����Ϣ
    FDatabaseMgr: TInDatabaseManager;    // ���ݿ����
    FFileMgr: TInFileManager;            // �ļ�����
    FMessageMgr: TInMessageManager;      // ��Ϣ����
    FHttpDataProvider: TInHttpDataProvider; // Http ����

    // =========== �¼� ===========

    FBeforeOpen: TNotifyEvent;           // ����ǰ�¼�
    FAfterOpen: TNotifyEvent;            // �������¼�
    FBeforeClose: TNotifyEvent;          // ֹͣǰ�¼�
    FAfterClose: TNotifyEvent;           // ֹͣ���¼�

    FOnConnect: TOnConnectEvnet;         // �����¼�
    FOnDataReceive: TOnStreamInEvent;    // �յ�����
    FOnDataSend: TOnStreamOutEvent;      // ��������
    FOnDisconnect: TOnConnectEvnet;      // �Ͽ��¼�    
    FOnError: TOnErrorEvent;             // �쳣�¼�

    // �ͻ��˽���
    procedure AcceptClient(Socket: TSocket; AddrIn: PSockAddrIn);
    procedure AcceptExClient(IOData: PPerIOData; ErrorCode: Integer);

    procedure ClearIPList;               // ��� IP ��
    procedure Prepare;                   // ׼������ Socket
    procedure OpenDetails;               // ����ϸ��

    procedure InternalOpen;              // ����
    procedure InternalClose;             // ֹͣ
    procedure InvalidSessions;           // ɾ�����ڵ�SessionId

    procedure InitExtraResources;        // ���ö�����Դ
    procedure FreeExtraResources;        // �ͷŶ�����Դ

    procedure SetActive(const Value: Boolean);
    procedure SetHttpDataProvider(const Value: TInHttpDataProvider);
    procedure SetIOCPBroker(const Value: TInIOCPBroker);
  protected
    procedure Loaded; override;  
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    procedure CloseSocket(ASocket: TBaseSocket);
    procedure GetAcceptExCount(var AAcceptExCount: Integer);
    procedure GetClientInfo(var CSSocketCount, CSSocketUsedCount,
                            HttpSocketCount, HttpSocketUsedCount,
                            ActiveCount: Integer; var WorkTotalCount: IOCP_LARGE_INTEGER);
    procedure GetIODataInfo(var IODataCount, CSSocketUsedCount,
                            HttpSocketUsedCount, PushActiveCount: Integer);
    procedure GetThreadInfo(const ThreadInfo: PWorkThreadSummary;
                            var BusiThreadCount, BusiActiveCount,
                            PushThreadCount, PushActiveCount: Integer;
                            var CheckTimeOut: TDateTime);
  public
    property BusyRefuseService: Boolean read FBusyRefuseService;
    property BusinessThreadCount: Integer read FBusiThreadCount;
    property BusiWorkMgr: TBusiWorkManager read FBusiWorkMgr;
    property GlobalLock: TThreadLock read FGlobalLock;
    property IOCPEngine: TIOCPEngine read FIOCPEngine;
    property MaxIOTraffic: Integer read FMaxIOTraffic;    
    property PushManager: TPushMsgManager read FPushManager;
    property PushThreadCount: Integer read FPushThreadCount;
    property StreamMode: Boolean read FStreamMode;
    property TimeOut: Cardinal read FTimeOut;
    property WorkThreadCount: Integer read FWorkThreadCount;
  public
    property HttpSocketPool: TIOCPSocketPool read FHttpSocketPool;
    property IOCPSocketPool: TIOCPSocketPool read FSocketPool;
    property IODataPool: TIODataPool read FIODataPool;
    property WebSocketPool: TIOCPSocketPool read FWebSocketPool;
  public
    // ������
    property ClientManager: TInClientManager read FClientMgr;
    property CustomManager: TInCustomManager read FCustomMgr;
    property DatabaseManager: TInDatabaseManager read FDatabaseMgr;
    property FileManager: TInFileManager read FFileMgr;
    property MessageManager: TInMessageManager read FMessageMgr;
  published
    property Active: Boolean read FActive write SetActive default False;
    property HttpDataProvider: TInHttpDataProvider read FHttpDataProvider write SetHttpDataProvider;
    property IOCPBroker: TInIOCPBroker read FIOCPBroker write SetIOCPBroker;
    property IOCPManagers: TIOCPManagers read FIOCPManagers write FIOCPManagers;
    property ServerAddr: String read FServerAddr write FServerAddr;
    property ServerPort: Word read FServerPort write FServerPort default DEFAULT_SVC_PORT;
    property StartParams: TServerParams read FStartParams write FStartParams;
    property ThreadOptions: TThreadOptions read FThreadOptions write FThreadOptions;
  published
    // �¼�
    property OnConnect: TOnConnectEvnet read FOnConnect write FOnConnect;
    property OnDataReceive: TOnStreamInEvent read FOnDataReceive write FOnDataReceive;
    property OnDataSend: TOnStreamOutEvent read FOnDataSend write FOnDataSend;
    property OnDisconnect: TOnConnectEvnet read FOnDisconnect write FOnDisconnect;
    property OnError: TOnErrorEvent read FOnError write FOnError;
  published
    property BeforeOpen: TNotifyEvent read FBeforeClose write FBeforeClose;
    property AfterOpen: TNotifyEvent read FAfterOpen write FAfterOpen;
    property BeforeClose: TNotifyEvent read FBeforeClose write FBeforeClose;
    property AfterClose: TNotifyEvent read FAfterClose write FAfterClose;
  end;

  // ================== AcceptEx ���� ==================

  TAcceptManager = class(TObject)
  private
    FAcceptors: array of TAcceptSocket;  // �׽���Ͷ������
    FAcceptorCount: Integer;             // �׽���Ͷ����
    FSuccededCount: Integer;             // �׽���Ͷ�ųɹ���
  public
    constructor Create(ListenSocket: TSocket; WorkThreadCount: Integer);
    destructor Destroy; override;
    procedure AcceptEx(var Result: Boolean);
    procedure CreateSocket(ASocket: TAcceptSocket); 
    procedure DecAcceptExCount; {$IFDEF USE_INLINE} inline; {$ENDIF}
  public
    property AcceptorCount: Integer read FAcceptorCount;
    property SuccededCount: Integer read FSuccededCount;
  end;

  // ================== �����߳� ==================

  TWorkThread = class(TBaseThread)
  private
    FServer: TInIOCPServer;         // ������
    FThreadIdx: Integer;            // ���ֱ��
    FSummary: PWorkThreadSummary;   // ͳ�Ƹſ�
    FDetail: TWorkThreadDetail;     // ͳ����ϸ

    FByteCount: Cardinal;           // �յ��ֽ���
    FErrorCode: Integer;            // �쳣����
    FPerIOData: PPerIOData;         // �ص����
    FSocket: TBaseSocket;           // ��ǰ�ͻ��˶���
    FState: Integer;                // �ͻ��˶���״̬

    procedure CalcIOSize; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure ExecIOEvent; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure HandleIOData; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure WriteCloseLog(const PeerIPPort: string); {$IFDEF USE_INLINE} inline; {$ENDIF}
  protected
    procedure ExecuteWork; override;
  public
    constructor Create(const AServer: TInIOCPServer); reintroduce;
  end;

  // ================== �����̳߳� ==================

  TWorkThreadPool = class(TObject)
  private
    FServer: TInIOCPServer;
    FThreadAarry: array of TWorkThread;
    FSummary: TWorkThreadSummary;
  public
    constructor Create(const AServer: TInIOCPServer);
    destructor Destroy; override;
  public
    procedure CalcTaskOut(PackCount, ByteCount: Integer);
    procedure GetThreadSummary(const Summary: PWorkThreadSummary);
    procedure GetThreadDetail(Index: Integer; const Detail: PWorkThreadDetail);
    procedure StopThreads;
  end;

  // ===================== ��ʱ����߳� =====================

  TTimeoutThread = class(TBaseThread)
  private
    FServer: TInIOCPServer;   // ������
    FSemapHore: THandle;      // �źŵ�
    FSockets: TInDataList;    // ��ʱ�ͻ��˵��б�
    FWorktime: TDateTime;     // ���ʱ��
    procedure CreateQueue(SocketPool: TIOCPSocketPool);
    procedure OptimizePool(ObjectPool: TObjectPool; Delta: Integer = 0);
  protected
    procedure ExecuteWork; override;
  public
    constructor Create(const AServer: TInIOCPServer); reintroduce;
    procedure Stop;
  end;

var
  _ResetMMProc: procedure = nil;

implementation

uses                          
  iocp_utils;

type
  TBaseSocketRef = class(TBaseSocket);
  TBaseManagerRef = class(TBaseManager);
  THttpDataProviderRef = class(TInHttpDataProvider);

procedure __ResetMMProc(Lock: TThreadLock);
begin
  if Assigned(_ResetMMProc) then
  begin
    if Assigned(Lock) then
      Lock.Acquire;
    try
      _ResetMMProc;
    finally
      if Assigned(Lock) then
        Lock.Release;
    end;
  end;
  ClearSysMemory;
end;

{ TIOCPEngine }

function TIOCPEngine.BindIoCompletionPort(Socket: TSocket): Boolean;
begin
  // PerIOData �ڰ����� Owner ��Ϣ������ CompletionKey
  if iocp_api.CreateIoCompletionPort(Socket, FHandle, 0, 0) = 0 then
  begin
    Result := False;
    iocp_log.WriteLog('TIOCPEngine.BindIoCompletionPort->' + GetWSAErrorMessage);
  end else
    Result := True;
end;

constructor TIOCPEngine.Create;
begin
  // �� IOCP ��ɶ˿�
  FHandle := iocp_api.CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, 0);
  if FHandle = 0 then
    iocp_log.WriteLog('TIOCPEngine.Create->' + GetSysErrorMessage);
end;

destructor TIOCPEngine.Destroy;
begin
  CloseHandle(FHandle);
  FHandle := 0;
end;

function TIOCPEngine.GetIoCompletionStatus(var ByteCount: Cardinal;
  var PerIOData: PPerIOData): Boolean;
var
  CompletionKey: ULONG_PTR;
begin
  // PerIOData �ڰ����� Owner ��Ϣ������ CompletionKey
  Result := iocp_api.GetQueuedCompletionStatus(FHandle, ByteCount,
                     CompletionKey, POverlapped(PerIOData), INFINITE);
end;

procedure TIOCPEngine.StopIoCompletionPort;
begin
  // ֪ͨ IOCP ֹͣ����
  iocp_api.PostQueuedCompletionStatus(FHandle, 0, 0, nil);
end;

{ TServerParams }

constructor TServerParams.Create(AOwner: TInIOCPServer);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TServerParams.GetBusyRefuseService: Boolean;
begin
  Result := FOwner.FBusyRefuseService;
end;

function TServerParams.GetClientPoolSize: Integer;
begin
  Result := FOwner.FClientPoolSize;
end;

function TServerParams.GetMaxPushCount: Integer;
begin
  Result := FOwner.FMaxPushCount;
end;

function TServerParams.GetMaxQueueCount: Integer;
begin
  Result := FOwner.FMaxQueueCount;
end;

function TServerParams.GetMaxIOTraffic: Integer;
begin
  Result := FOwner.FMaxIOTraffic;
end;

function TServerParams.GetPreventAttack: Boolean;
begin
  Result := FOwner.FPreventAttack;
end;

function TServerParams.GetTimeOut: Cardinal;
begin
  Result := FOwner.FTimeOut;
end;

procedure TServerParams.SetBusyRefuseService(const Value: Boolean);
begin
  FOwner.FBusyRefuseService := Value;
  if (csDesigning in FOwner.ComponentState) then
    if Value and (FOwner.FClientPoolSize = 0) then
      FOwner.FClientPoolSize := MAX_CLIENT_COUNT;
end;

procedure TServerParams.SetClientPoolSize(const Value: Integer);
begin
  FOwner.FClientPoolSize := Value;
  if (csDesigning in FOwner.ComponentState) and (Value = 0) then
    FOwner.FBusyRefuseService := False;
end;

procedure TServerParams.SetMaxPushCount(const Value: Integer);
begin
  FOwner.FMaxPushCount := Value;
end;

procedure TServerParams.SetMaxQueueCount(const Value: Integer);
begin
  FOwner.FMaxQueueCount := Value;
end;

procedure TServerParams.SetMaxIOTraffic(const Value: Integer);
begin
  FOwner.FMaxIOTraffic := Value;
end;

procedure TServerParams.SetPreventAttack(const Value: Boolean);
begin
  FOwner.FPreventAttack := Value;
end;

procedure TServerParams.SetTimeOut(const Value: Cardinal);
begin
  FOwner.FTimeOut := Value;
end;

{ TThreadOptions }

constructor TThreadOptions.Create(AOwner: TInIOCPServer);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TThreadOptions.GetBusiThreadCount: Integer;
begin
  Result := FOwner.FBusiThreadCount;
end;

function TThreadOptions.GetPushThreadCount: Integer;
begin
  Result := FOwner.FPushThreadCount;
end;

function TThreadOptions.GetWorkThreadCount: Integer;
begin
  Result := FOwner.FWorkThreadCount;
end;

procedure TThreadOptions.SetBusiThreadCount(const Value: Integer);
begin
  if (Value >= FOwner.FWorkThreadCount) then // ���ܱȹ����߳���
    FOwner.FBusiThreadCount := Value;
end;

procedure TThreadOptions.SetPushThreadCount(const Value: Integer);
begin
  if (Value >= FOwner.FWorkThreadCount) then // ���ܱȹ����߳���
    FOwner.FPushThreadCount := Value;
end;

procedure TThreadOptions.SetWorkThreadCount(const Value: Integer);
begin
  if (Value > 0) then
    FOwner.FWorkThreadCount := Value;
end;

{ TIOCPManagers }

constructor TIOCPManagers.Create(AOwner: TInIOCPServer);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TIOCPManagers.GetClientMgr: TInClientManager;
begin
  Result := FOwner.FClientMgr;
end;

function TIOCPManagers.GetCustomMgr: TInCustomManager;
begin
  Result := FOwner.FCustomMgr;
end;

function TIOCPManagers.GetDatabaseMgr: TInDatabaseManager;
begin
  Result := FOwner.FDatabaseMgr;
end;

function TIOCPManagers.GetFileMgr: TInFileManager;
begin
  Result := FOwner.FFileMgr;
end;

function TIOCPManagers.GetMessageMgr: TInMessageManager;
begin
  Result := FOwner.FMessageMgr;
end;

procedure TIOCPManagers.SetClientMgr(const Value: TInClientManager);
begin
  if Assigned(FOwner.FClientMgr) then
    FOwner.FClientMgr.RemoveFreeNotification(FOwner);  // ȡ��֪ͨ��Ϣ
  FOwner.FClientMgr := Value;
  if Assigned(FOwner.FClientMgr) then
  begin
    FOwner.FClientMgr.FreeNotification(FOwner);  // ���ʱ֪ͨ��Ϣ
    TBaseManagerRef(FOwner.FClientMgr).FServer := FOwner;
    FOwner.IOCPBroker := nil;
  end;
end;

procedure TIOCPManagers.SetCustomMgr(const Value: TInCustomManager);
begin
  if Assigned(FOwner.FCustomMgr) then
    FOwner.FCustomMgr.RemoveFreeNotification(FOwner);
  FOwner.FCustomMgr := Value;
  if Assigned(FOwner.FCustomMgr) then
  begin
    FOwner.FCustomMgr.FreeNotification(FOwner);
    TBaseManagerRef(FOwner.FCustomMgr).FServer := FOwner;
    FOwner.IOCPBroker := nil;
  end;
end;

procedure TIOCPManagers.SetDatabaseMgr(const Value: TInDatabaseManager);
begin
  if Assigned(FOwner.FDatabaseMgr) then
    FOwner.FDatabaseMgr.RemoveFreeNotification(FOwner);
  FOwner.FDatabaseMgr := Value;
  if Assigned(FOwner.FDatabaseMgr) then
  begin
    FOwner.FDatabaseMgr.FreeNotification(FOwner);
    TBaseManagerRef(FOwner.FDatabaseMgr).FServer := FOwner;
    FOwner.IOCPBroker := nil;
  end;
end;

procedure TIOCPManagers.SetFileMgr(const Value: TInFileManager);
begin
  if Assigned(FOwner.FFileMgr) then
    FOwner.FFileMgr.RemoveFreeNotification(FOwner);
  FOwner.FFileMgr := Value;
  if Assigned(FOwner.FFileMgr) then
  begin
    FOwner.FFileMgr.FreeNotification(FOwner);
    TBaseManagerRef(FOwner.FFileMgr).FServer := FOwner;
    FOwner.IOCPBroker := nil;
  end;
end;

procedure TIOCPManagers.SetMessageMgr(const Value: TInMessageManager);
begin
  if Assigned(FOwner.FMessageMgr) then
    FOwner.FMessageMgr.RemoveFreeNotification(FOwner);
  FOwner.FMessageMgr := Value;
  if Assigned(FOwner.FMessageMgr) then
  begin
    FOwner.FMessageMgr.FreeNotification(FOwner);
    TBaseManagerRef(FOwner.FMessageMgr).FServer := FOwner;
    FOwner.IOCPBroker := nil;
  end;
end;

{ TInIOCPServer }

procedure TInIOCPServer.AcceptClient(Socket: TSocket; AddrIn: PSockAddrIn);
var
  PeerIP: String;
  ASocket: TBaseSocketRef;
  SocketPool: TIOCPSocketPool;
begin
  // �ͻ��˽��룬��������

  if Assigned(FPeerIPList) then  // ����Ƿ����� IP
  begin
    PeerIP := TRawSocket.GetPeerIP(AddrIn);
    if FPeerIPList.CheckAttack(PeerIP, 10000, 10) then  // 10 ���ڳ��� 10 ���ͻ�������
    begin
      iocp_Winsock2.CloseSocket(Socket);
      iocp_log.WriteLog('TInIOCPServer.AcceptClient->�رչ����׽��֣�' + PeerIP);
      Exit;
    end;
  end;

  // ׼�������� Socket��Ĭ��Ϊ THttpSocket��
  if FStreamMode then  // ���������������
    SocketPool := FSocketPool
  else
    SocketPool := FHttpSocketPool;

  ASocket := TBaseSocketRef(SocketPool.Pop^.Data);
  if (Assigned(ASocket) = False) then  // �����ڴ�ľ�
  begin
    iocp_log.WriteLog('TInIOCPServer.AcceptClient->�����ڴ治��.');
    Exit;
  end;

  ASocket.IniSocket(Self, Socket);  // �� Server��Socket
  ASocket.SetPeerAddr(AddrIn);  // ���õ�ַ

  // ע����Ϊ�ڴ˰� IOCP
  FIOCPEngine.BindIoCompletionPort(Socket);

  if (FBusyRefuseService and SocketPool.Full) or  // ���ӳ���
     (FMaxQueueCount > 0) and
     (FBusiWorkMgr.ActiveCount + FPushManager.PushMsgCount > FMaxQueueCount) // �����б����
  //   (FBusiWorkMgr.ActiveCount = MaxInt)  // �ڹ�����ģ������TBusiWorkManager.GetActiveCount
  then
    ASocket.PostEvent(ioRefuse) // �ܾ�����
  else begin
    // ���ó�ʱ��飬������
    if (FTimeOut = 0) then
      iocp_wsExt.SetKeepAlive(Socket);

    // ���ÿͻ��˽����¼������Ҫ��ֹ���룬���� Close
    if Assigned(FOnConnect) then
      FOnConnect(Self, ASocket);

    if ASocket.Connected then  // �������
    begin
      ASocket.PostRecv;        // Ͷ�Ž����ڴ��
      {$IFDEF DEBUG_MODE}
      iocp_log.WriteLog('TInIOCPServer.AcceptClient->�ͻ��˽��룺' + ASocket.PeerIPPort);
      {$ENDIF}
    end else
    begin
      CloseSocket(ASocket);    // ����Socket
      {$IFDEF DEBUG_MODE}
      iocp_log.WriteLog('TInIOCPServer.AcceptClient->��ֹ�ͻ��˽��룺' + ASocket.PeerIPPort);
      {$ENDIF}
    end;
  end;

end;

procedure TInIOCPServer.AcceptExClient(IOData: PPerIOData; ErrorCode: Integer);
var
  LocalAddr: PSockAddr;
  RemoteAddr: PSockAddr;
  LocalAddrSize: Integer;
  RemoteAddrSize: Integer;
  NewSocket: TAcceptSocket;
begin
  // AcceptEx ģʽ������������
  // ����Ŀͻ��˱����ӵ� AcceptEx ��Ӧ�� Socket��
  //   Ҫ�����µ� Socket ���� AcceptEx

  NewSocket := TAcceptSocket(IOData^.Owner);
  FAcceptManager.DecAcceptExCount;     // Ͷ����-

  try
    try
      if (ErrorCode > 0) or // �쳣
         (NewSocket.SetOption = False) // ��������ʧ��
      then
        NewSocket.Close  // �ر�
      else begin
        // ��ȡ����� Socket ��ַ
        LocalAddrSize := ADDRESS_SIZE_16;
        RemoteAddrSize := ADDRESS_SIZE_16;
        gGetAcceptExSockAddrs(IOData^.Data.buf, 0, ADDRESS_SIZE_16,
                              ADDRESS_SIZE_16, LocalAddr, LocalAddrSize,
                              RemoteAddr, RemoteAddrSize);
        // �� Socket ����ͻ���
        AcceptClient(NewSocket.Socket, PSockAddrIn(RemoteAddr));
      end;
    finally
      if FActive then  // ������ Socket���� IOCP, Ͷ�ţ��ȴ�����
        FAcceptManager.CreateSocket(NewSocket);
    end;
  except  
    iocp_log.WriteLog('TInIOCPServer.AcceptExClient->' + GetSysErrorMessage);
  end;
end;

procedure TInIOCPServer.ClearIPList;
var
  UsedCount: Integer;
begin
  // ��� IP �б�����
  UsedCount := FSocketPool.UsedCount;
  if Assigned(FHttpSocketPool) then
    Inc(UsedCount, FHttpSocketPool.UsedCount);
  if Assigned(FWebSocketPool) then
    Inc(UsedCount, FWebSocketPool.UsedCount);
  if (UsedCount = 0) then // û�пͻ�������
  begin
    FGlobalLock.Acquire;
    try
      if Assigned(FPeerIPList) then
        FPeerIPList.Clear;  // ����� IP �б�
      if Assigned(FHttpDataProvider) then  // ��� FHttpDataProvider �� IP
        FHttpDataProvider.ClearIPList;
    finally
      FGlobalLock.Release;
    end;
  end;
end;

procedure TInIOCPServer.CloseSocket(ASocket: TBaseSocket);
begin
  // ���� IP/Session ���ã��ر� Socket
  // ���ǹرշ���� Socket ��Ψһ���
  if FActive then
  begin
    if Assigned(FPeerIPList) then
      FPeerIPList.DecRef(ASocket.PeerIP);
    if Assigned(FSessionMgr) and (ASocket is THttpSocket) then
      FSessionMgr.DecRef(THttpSocket(ASocket).SessionId);
    if Assigned(FOnDisconnect) then  // �ͻ��˶Ͽ��¼�
      FOnDisconnect(Self, ASocket);      
    FCloseThread.AddSocket(ASocket);
  end;
end;

constructor TInIOCPServer.Create(AOwner: TComponent);
begin
  inherited;
  // ����Ĭ��ֵ
  FActive := False;
  FBusyRefuseService := False;
  FClientPoolSize := 0;
  FMaxPushCount := 10000;
  FMaxQueueCount := 0;
  FPreventAttack := False;
  FServerPort := DEFAULT_SVC_PORT;
  FTimeOut := 0; // ���ó�ʱ��� TIME_OUT_INTERVAL;

  // �����߳���
  // �����̺߳�ҵ���̷߳��룬�����̺߳����ɣ�
  // �����ý�������GetCPUCount * 2 + 2��
  FWorkThreadCount := GetCPUCount;
  if (FWorkThreadCount > 4) then
    FWorkThreadCount := 4;

  FBusiThreadCount := FWorkThreadCount * 2;
  FPushThreadCount := FWorkThreadCount;

  // ���������
  FIOCPManagers := TIOCPManagers.Create(Self);

  FStartParams := TServerParams.Create(Self);

  FThreadOptions := TThreadOptions.Create(Self);

end;

destructor TInIOCPServer.Destroy;
begin
  FIOCPManagers.Free;
  FStartParams.Free;
  FThreadOptions.Free;
  SetActive(False);
  inherited;
end;

procedure TInIOCPServer.FreeExtraResources;
begin
  // �����¼����ģ�� Http �� Cookie ��Ϣ
  if Assigned(FClientMgr) then
    FClientMgr.Clear;
  if Assigned(FDatabaseMgr) then
    FDatabaseMgr.Clear;
  if Assigned(FHttpDataProvider) then
    FHttpDataProvider.SessionMgr.Clear;
end;

procedure TInIOCPServer.GetAcceptExCount(var AAcceptExCount: Integer);
begin
  // ȡ AcceptEx Ͷ�ųɹ��� Socket ��
  if Assigned(FAcceptManager) then
    AAcceptExCount := FAcceptManager.FSuccededCount
  else
    AAcceptExCount := 0;
end;

procedure TInIOCPServer.GetClientInfo(var CSSocketCount, CSSocketUsedCount,
  HttpSocketCount, HttpSocketUsedCount, ActiveCount: Integer;
  var WorkTotalCount: IOCP_LARGE_INTEGER);
begin
  // ȡ Socket ͳ����
  CSSocketCount := FSocketPool.NodeCount; // �����
  CSSocketUsedCount := FSocketPool.UsedCount; // ������

  if Assigned(FWebSocketPool) then
  begin
    Inc(CSSocketCount, FWebSocketPool.NodeCount);
    Inc(CSSocketUsedCount, FWebSocketPool.UsedCount);
  end;

  if Assigned(FHttpSocketPool) then
  begin
    HttpSocketCount := FHttpSocketPool.NodeCount;
    HttpSocketUsedCount := FHttpSocketPool.UsedCount;
  end else
  begin
    HttpSocketCount := 0;
    HttpSocketUsedCount := 0;
  end;

  // ������������ҵ��+���͹��㣩
  ActiveCount := FBusiWorkMgr.ActiveCount;
  if Assigned(FPushManager) then
    Inc(ActiveCount, FPushManager.PushMsgCount); // FPushManager.ActiveCount;

  // ��ִ�е���������
  WorkTotalCount := FBusiWorkMgr.WorkTotalCount;
end;

procedure TInIOCPServer.GetIODataInfo(var IODataCount,
  CSSocketUsedCount, HttpSocketUsedCount, PushActiveCount: Integer);
begin
  // ͳ���ڴ���ʹ��
  IODataCount := FIODataPool.NodeCount;  // ����
  CSSocketUsedCount := FSocketPool.NodeCount;  // C/S ռ����
  if Assigned(FWebSocketPool) then   // ���� TWebSocket
    Inc(CSSocketUsedCount, FWebSocketPool.NodeCount);

  if Assigned(FHttpSocketPool) then  // ���� THttpSocket
    HttpSocketUsedCount := FHttpSocketPool.NodeCount
  else
    HttpSocketUsedCount := 0;

  if Assigned(FPushManager) then  // ���� FPushManager
    PushActiveCount := FPushManager.ActiveCount
  else
    PushActiveCount := 0;
end;

procedure TInIOCPServer.GetThreadInfo(const ThreadInfo: PWorkThreadSummary;
  var BusiThreadCount, BusiActiveCount, PushThreadCount,
  PushActiveCount: Integer; var CheckTimeOut: TDateTime);
begin
  // ȡ�߳���Ϣ
  FWorkThreadPool.GetThreadSummary(ThreadInfo); // �̳߳���Ϣ
  
  BusiThreadCount := FBusiThreadCount;  // ҵ���߳���
  BusiActiveCount := FBusiWorkMgr.ActiveThreadCount; // ���ҵ���߳���

  if Assigned(FPushManager) then
  begin
    PushThreadCount := FPushThreadCount;  // �����߳���
    PushActiveCount := FPushManager.ActiveThreadCount; // ��������߳���
  end else
  begin
    PushThreadCount := 0;
    PushActiveCount := 0;
  end;

  CheckTimeOut := FCheckThread.FWorktime;       // ��ʱ���ʱ��
end;

procedure TInIOCPServer.InitExtraResources;
begin
  // ��������������
  if Assigned(FIOCPBroker) then
    FStreamMode := True  // ������������
  else
    FStreamMode := not (Assigned(FClientMgr)   or Assigned(FCustomMgr) or
                        Assigned(FDatabaseMgr) or Assigned(FFileMgr)   or
                        Assigned(FMessageMgr)  or Assigned(FHttpDataProvider));
  // ����Ϣ��д��
  if Assigned(FMessageMgr) then
    FMessageMgr.CreateMsgWriter(Assigned(FHttpDataProvider));
end;

procedure TInIOCPServer.InternalClose;
begin
  if Assigned(FBeforeClose) then
    FBeforeClose(Self);

  FActive := False;         // ����ֹͣ
  FState := SERVER_IGNORED; // ���ԣ������߳̿�ѭ��
    
  // ֹͣ���ͷų�ʱ����߳�
  if Assigned(FCheckThread) then
  begin
    FCheckThread.Stop;
    FCheckThread := Nil;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FCheckThread����ʱ����̣߳�ֹͣ�ɹ���');
    {$ENDIF}
  end;

  // �ͷż��� Socket�����������ӣ�
  if Assigned(FListenSocket) then
  begin
    FListenSocket.Close;
    FreeAndNil(FListenSocket);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FListenSocket�������׽��֣��ͷųɹ���');
    {$ENDIF}
  end;

  if Assigned(FPushManager) then  // �ȴ������߳�ִ�����
    FPushManager.WaitFor;

  if Assigned(FBusiWorkMgr) then  // �ȴ�ҵ���߳�ִ�����
    FBusiWorkMgr.WaitFor;

  if Assigned(FCloseThread) then  // �ȴ� Socket �ر����
    FCloseThread.WaitFor;

  FState := SERVER_STOPED;        // ��ʽֹͣ�������߳̽�����

  // �ͷŶ�����Դ
  FreeExtraResources;

  // �ͷŹ����߳� FWorkThreadPool

  if Assigned(FWorkThreadPool) then      
  begin
    FWorkThreadPool.StopThreads;
    FreeAndNil(FWorkThreadPool);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FWorkThreadPool�������̳߳أ�ֹͣ�ɹ���');
    {$ENDIF}
  end;

  if Assigned(FIOCPBroker) and FIOCPBroker.ReverseMode then
  begin
    FIOCPBroker.Stop;  // ֹͣ
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIOCPBroker����������ͷ� Ping �׽��֡�');
    {$ENDIF}
  end;
  
  // �ͷ���Ͷ�ŵ� Socket
  if Assigned(FAcceptManager) then
  begin
    FreeAndNil(FAcceptManager);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FAcceptManager���ͻ��˽�������ͷųɹ���');
    {$ENDIF}
  end;

  // �ͷ�ҵ���߳�
  if Assigned(FBusiWorkMgr) then
  begin
    FBusiWorkMgr.StopThreads;
    FreeAndNil(FBusiWorkMgr);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FBusiThreadMgr��ҵ���̹߳����ͷųɹ���');
    {$ENDIF}
  end;

  // �ͷ���Ϣ�����߳�
  if Assigned(FPushManager) then
  begin
    FPushManager.StopThreads;
    FreeAndNil(FPushManager);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FPushManager�������̹߳����ͷųɹ���');
    {$ENDIF}
  end;

  if Assigned(FIOCPEngine) then
  begin
    FreeAndNil(FIOCPEngine);     // ���ͷŹ����̺߳�
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FIOCPEngine��IOCP���棩�ͷųɹ���');
    {$ENDIF}
  end;

  if Assigned(FSocketPool) then
  begin
    FreeAndNil(FSocketPool);     // ��ǰ��Ҫ�ͷ� IO_DATA
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FSocketPool���ͻ��أ��ͷųɹ���');
    {$ENDIF}
  end;

  if Assigned(FHttpSocketPool) then
  begin
    FreeAndNil(FHttpSocketPool); // ��ǰ��Ҫ�ͷ� IO_DATA
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FHttpSocketPool���ͻ��أ��ͷųɹ���');
    {$ENDIF}
  end;

  if Assigned(FWebSocketPool) then
  begin
    FreeAndNil(FWebSocketPool); // ��ǰ��Ҫ�ͷ� IO_DATA
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FWebSocketPool��WebSocket�أ��ͷųɹ���');
    {$ENDIF}
  end;

  if Assigned(FIODataPool) then
  begin
    FreeAndNil(FIODataPool);   // ����ͷ��շ��ڴ�
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FIODataPool���ڴ�أ��ͷųɹ���');
    {$ENDIF}
  end;

  if Assigned(FPeerIPList) then
  begin
    FreeAndNil(FPeerIPList);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FPeerIPList�������������ͷųɹ���');
    {$ENDIF}
  end;

  // ����ͷ� FGlobalLock���� ClearBalanceServers ��
  if Assigned(FGlobalLock) then  // TSystemGlobalLock
  begin
    TSystemGlobalLock.FreeGlobalLock;
    FGlobalLock := nil;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FGlobalLock��ȫ�������ͷųɹ���');
    {$ENDIF}
  end;

  // ֹͣ���ͷŹرտͻ��˵��߳�
  if Assigned(FCloseThread) then
  begin
    FCloseThread.Stop;
    FCloseThread := Nil;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FCloseThread���ر��׽����̣߳�ֹͣ�ɹ���');
    {$ENDIF}
  end;
    
  CoUninitialize;

  iocp_log.WriteLog('TInIOCPServer.InternalClose->IOCP ����ֹͣ�ɹ���');

  if Assigned(FAfterClose) and not (csDestroying in ComponentState) then
    FAfterClose(Self);

  __ResetMMProc(nil);   // �ͷ�ռ�õ��ڴ�
    
end;

procedure TInIOCPServer.InternalOpen;
begin
  try
    Prepare;
    OpenDetails;
  except
    InternalClose;
    raise;
  end;
end;

procedure TInIOCPServer.InvalidSessions;
begin
  // ɾ������ SessionId
  if Assigned(FHttpDataProvider) then
  begin
    FGlobalLock.Acquire;
    try
      FHttpDataProvider.SessionMgr.InvalidateSessions;
    finally
      FGlobalLock.Release;
    end;
  end;
end;

procedure TInIOCPServer.OpenDetails;
begin
  if Assigned(FBeforeOpen) then
    FBeforeOpen(Self);

  // ����ʱ����Ϊ True, ���� False
  FActive := False;
  FState := SERVER_IGNORED;

  // ��ʼ���������������� InitMoreResource �л����
  FStreamMode := True;  

  // ������æ�ܾ����ͻ��˳أ����������ӳأ�
  if FBusyRefuseService and (FClientPoolSize = 0) then
    FClientPoolSize := MAX_CLIENT_COUNT
  else
  if (FClientPoolSize = 0) then
    FBusyRefuseService := False;

  // ȫ����,���� InitMoreResource ֮ǰ��
  FGlobalLock := TSystemGlobalLock.CreateGlobalLock;  // TThreadLock.Create;

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FGlobalLock��ȫ�����������ɹ���');
  {$ENDIF}

  // ���ö�����Դ
  InitExtraResources;

  // ����������
  if FPreventAttack then
  begin
    FPeerIPList := TPreventAttack.Create;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FPeerIPList�����������������ɹ���');
    {$ENDIF}
  end;

  // ׼���շ��ڴ�أ���ǰ
  FIODataPool := TIODataPool.Create(FClientPoolSize);
  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIODataPool���ڴ�أ������ɹ���');
  {$ENDIF}

  // ׼���ͻ��˳�
  if Assigned(FIOCPBroker) then  // ����ģʽ�����������
    FSocketPool := TIOCPSocketPool.Create(otBroker, FClientPoolSize)
  else
  if FStreamMode then  // �� TStreamSocket
    FSocketPool := TIOCPSocketPool.Create(otStreamSocket, FClientPoolSize)
  else begin  // �� TIOCPSocket + THttpSocket
    FSocketPool := TIOCPSocketPool.Create(otSocket, FClientPoolSize);
    FHttpSocketPool := TIOCPSocketPool.Create(otHttpSocket, FClientPoolSize);
    if Assigned(FHttpDataProvider) and Assigned(FHttpDataProvider.WebSocketManager) then
      FWebSocketPool := TIOCPSocketPool.Create(otWebSocket, 0);
  end;

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FSocketPool���ͻ��أ������ɹ���');
  if Assigned(FHttpSocketPool) then
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FHttpSocketPool���ͻ��أ������ɹ���');
  if Assigned(FWebSocketPool) then
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FWebSocketPool��WebSocket�أ������ɹ���');
  {$ENDIF}

  // IOCP ����
  //  ע�����¶����½����Զ����빤��״̬
  FIOCPEngine := TIOCPEngine.Create;

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIOCPEngine��IOCP���棩�����ɹ���');
  {$ENDIF}

  // �����̳߳�
  FWorkThreadPool := TWorkThreadPool.Create(Self);

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FWorkThreadPool�������̳߳أ������ɹ���');
  {$ENDIF}

  // ҵ���̵߳��ȹ���
  FBusiWorkMgr := TBusiWorkManager.Create(Self, FBusiThreadCount);

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FBusiThreadMgr��ҵ���̹߳��������ɹ���');
  {$ENDIF}

  // �������̵߳��ȣ��� FBusiWorkMgr ��
  if (FStreamMode = False) then
  begin
    FPushManager := TPushMsgManager.Create(FBusiWorkMgr, FPushThreadCount, FMaxPushCount);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FPushManager�������̹߳��������ɹ���');
    {$ENDIF}
  end;

  // �ر� Socket ���߳�
  FCloseThread := TCloseSocketThread.Create;
  FCloseThread.Resume;

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FCloseThread���ر��׽����̣߳������ɹ���');
  {$ENDIF}

  // �����������ӡ�����̣߳���ʱ��飩
  FCheckThread := TTimeoutThread.Create(Self);
  FCheckThread.Resume;  // ��ʽ����

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FCheckThread����ʱ����̣߳������ɹ���');
  {$ENDIF}

  // AcceptEx ģʽʱ FListenSocket.Socket ����� IOCP��
  // Accept ģʽ���

  FIOCPEngine.BindIoCompletionPort(FListenSocket.Socket);

  if Assigned(FIOCPBroker) and FIOCPBroker.ReverseMode then
  begin
    FIOCPBroker.Prepare;  // ��ģʽ���������
    FActive := True;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIOCPBroker���������׼����ϡ�');
    {$ENDIF}
  end else
  begin
    if Assigned(FIOCPBroker) then
    begin
      FIOCPBroker.Prepare; // �ⲿģʽ
      {$IFDEF DEBUG_MODE}
      if (FIOCPBroker.ProxyType = ptDefault) then
        iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIOCPBroker����ͨ����׼����ϡ�')
      else
        iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIOCPBroker���ⲿ����׼����ϡ�');
      {$ENDIF}
    end;

    // Ԥ�������õ� Socket
    FAcceptManager := TAcceptManager.Create(FListenSocket.Socket, FWorkThreadCount);

    // ��ʼ������
    if not FListenSocket.StartListen then
    begin
      FListenSocket.Close;
      FreeAndNil(FListenSocket);
      raise Exception.Create('�׽��ּ����쳣��' + FServerAddr + ':' + IntToStr(FServerPort));
    end;

    // Ͷ�ţ�Ҫ�����ɹ�����
    FAcceptManager.AcceptEx(FActive);

    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FAcceptManager���ͻ��˽�����������ɹ���');
    {$ENDIF}
  end;

  if FActive then
  begin
    FState := SERVER_RUNNING;    // ��ʽ����
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->IOCP ���������ɹ���');
  end else
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->IOCP ��������ʧ�ܡ�');

  if Assigned(FAfterOpen) then
    FAfterOpen(Self);
end;

procedure TInIOCPServer.Loaded;
begin
  inherited;
  // װ�غ�FActive -> ��
  if FActive and not (csDesigning in ComponentState) then
    InternalOpen;
end;

procedure TInIOCPServer.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) then  // ���ʱ�յ�ɾ�������Ϣ
  begin
    if (AComponent = FClientMgr) then
      FClientMgr := nil;
    if (AComponent = FCustomMgr) then
      FCustomMgr := nil;
    if (AComponent = FDatabaseMgr) then
      FDatabaseMgr := nil;
    if (AComponent = FFileMgr) then
      FFileMgr := nil;
    if (AComponent = FMessageMgr) then
      FMessageMgr := nil;
    if (AComponent = FHttpDataProvider) then
      FHttpDataProvider := nil;
    if (AComponent = FIOCPBroker) then
      FIOCPBroker := nil;
  end;
end;

procedure TInIOCPServer.Prepare;
begin
  // ׼������ Socket
  CoInitializeEx(nil, 0);

  FListenSocket := TListenSocket.Create(True);

  if not FListenSocket.Bind(FServerPort, FServerAddr) then
  begin
    FListenSocket.Close;
    FreeAndNil(FListenSocket);
    raise Exception.Create('�׽��ְ��쳣��' + FServerAddr + ':' + IntToStr(FServerPort));
  end else

  // װ�� WinSocket 2 ����
  GetWSExtFuncs(FListenSocket.Socket);

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.Prepare->FListenSocket�������׽��֣������ɹ���');
  {$ENDIF}
end;

procedure TInIOCPServer.SetActive(const Value: Boolean);
begin
  // ����/�رշ���
  if Value <> FActive then
    if (csDesigning in ComponentState) or (csLoading in ComponentState) then
      FActive := Value
    else begin
      if Value and not FActive then
        InternalOpen
      else
      if not Value and FActive then
        InternalClose;
    end;             
end;                             

procedure TInIOCPServer.SetHttpDataProvider(const Value: TInHttpDataProvider);
begin
  // ���� FHttpDataProvider �����ʱ�¼�
  if Assigned(FHttpDataProvider) then
    FHttpDataProvider.RemoveFreeNotification(Self);
  FHttpDataProvider := Value;
  if Assigned(FHttpDataProvider) then
  begin
    FHttpDataProvider.FreeNotification(Self);
    THttpDataProviderRef(FHttpDataProvider).FServer := Self;
    FSessionMgr := FHttpDataProvider.SessionMgr;
    IOCPBroker := nil;
  end else
    FSessionMgr := Nil;
end;

procedure TInIOCPServer.SetIOCPBroker(const Value: TInIOCPBroker);
begin
  // ���� FIOCPBroker �����ʱ�¼�
  if Assigned(FIOCPBroker) then
    FIOCPBroker.RemoveFreeNotification(Self);
  FIOCPBroker := Value;
  if Assigned(FIOCPBroker) then
  begin
    FIOCPBroker.FreeNotification(Self);
    TBaseManagerRef(FIOCPBroker).FServer := Self;
    FIOCPManagers.ClientManager := nil;
    FIOCPManagers.CustomManager := nil;
    FIOCPManagers.DatabaseManager := nil;
    FIOCPManagers.FileManager := nil;
    FIOCPManagers.MessageManager := nil;
    HttpDataProvider := nil;
  end;
end;

{ TAcceptManager }

procedure TAcceptManager.AcceptEx(var Result: Boolean);
var
  i: Integer;
begin
  // ��һͶ�Ž����õ��׽���
  FSuccededCount := 0;
  for i := 0 to High(FAcceptors) do
    if FAcceptors[i].AcceptEx then
      Inc(FSuccededCount)
    else  // ���ɹ����ر� Socket�������ͷŶ���
      FAcceptors[i].Close;
  Result := FSuccededCount > 0;
end;

procedure TAcceptManager.CreateSocket(ASocket: TAcceptSocket);
begin
  // �½� Socket���� IOCP������Ͷ�ţ�
  ASocket.NewSocket;
  if ASocket.AcceptEx then
    Windows.InterlockedIncrement(FSuccededCount)  // Ͷ���� +
  else  // ���ɹ����ر� Socket�������ͷŶ���
    ASocket.Close;
end;

constructor TAcceptManager.Create(ListenSocket: TSocket; WorkThreadCount: Integer);
var
  i: Integer;
begin
  // Ԥ��һЩ Socket��Ͷ�š��ȴ�����
  //   ���Խ����TAcceptSocket ʵ������Խ��Խ��

  case WorkThreadCount of  // �ʵ��� Socket Ͷ������СӦ�� 100 ���ڼ���
    1..2:
      FAcceptorCount := 50;
    3..6:
      FAcceptorCount := 100;
    else
      FAcceptorCount := 200;
  end;
    
  SetLength(FAcceptors, FAcceptorCount);
  for i := 0 to FAcceptorCount - 1 do
    FAcceptors[i] := TAcceptSocket.Create(ListenSocket); // ���׽��֣�����ʱ��

end;

procedure TAcceptManager.DecAcceptExCount;
begin
  // Socket Ͷ�ųɹ���-
  Windows.InterlockedDecrement(FSuccededCount);
end;

destructor TAcceptManager.Destroy;
var
  i: Integer;
begin
  // �ͷ�ȫ���ѽ��Ľ������
  for i := 0 to High(FAcceptors) do
    if Assigned(FAcceptors[i]) then
      FAcceptors[i].Free;
  SetLength(FAcceptors, 0);
end;

{ TWorkThread }

procedure TWorkThread.CalcIOSize;
begin
  // �����շ����ݰ����ֽ���
  if (FPerIOData^.IOType in [ioAccept, ioReceive]) then
  begin
    // �յ�����
    windows.InterlockedIncrement(FDetail.PackInCount);
    windows.InterlockedIncrement(FSummary^.PackInCount);
    windows.InterlockedExchangeAdd(FDetail.ByteInCount, FByteCount);
    windows.InterlockedExchangeAdd(FSummary^.ByteInCount, FByteCount);
  end else
  begin
    // ��������
    windows.InterlockedIncrement(FDetail.PackOutCount);
    windows.InterlockedIncrement(FSummary^.PackOutCount);
    windows.InterlockedExchangeAdd(FDetail.ByteOutCount, FByteCount);
    windows.InterlockedExchangeAdd(FSummary^.ByteOutCount, FByteCount);
  end;

  // ���ݰ����� + 1
  windows.InterlockedIncrement(FDetail.PackCount);
  windows.InterlockedIncrement(FSummary^.PackCount);

  // �ֽ�����
  windows.InterlockedExchangeAdd(FDetail.ByteCount, FByteCount);
  windows.InterlockedExchangeAdd(FSummary^.ByteCount, FByteCount);
end;

constructor TWorkThread.Create(const AServer: TInIOCPServer);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FServer := AServer;  
end;

procedure TWorkThread.ExecIOEvent;
begin
  // ִ���ա����¼�
  if (FPerIOData^.IOType in [ioAccept, ioReceive]) then
  begin
    // ���ڴ˴����յ�ԭʼ������������TStreamSocket.ExecuteWork
    if (FServer.FStreamMode = False) and Assigned(FServer.FOnDataReceive) then
      FServer.FOnDataReceive(FSocket, FPerIOData^.Data.buf, FByteCount);
  end else
  if Assigned(FServer.FOnDataSend) then  // ���������¼�
    FServer.FOnDataSend(FSocket, FByteCount);
end;

procedure TWorkThread.ExecuteWork;
var
  RetValue: Boolean;
begin
  // ���������߳�

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TWorkThread.ExecuteWork->׼�������߳�: ' + IntToStr(FThreadIdx));
  {$ENDIF}

  FillChar(FDetail, SizeOf(TWorkThreadDetail), 0);
  FDetail.Index := FThreadIdx;

  while (Terminated = False) do
    try
      FByteCount := 0;
      FPerIOData := nil;

      // ��� IOCP ״̬
      RetValue := FServer.FIOCPEngine.GetIoCompletionStatus(FByteCount, FPerIOData);

      // ������״̬
      case FServer.FState of
        SERVER_STOPED:   // ֹͣ��
          Break;
        SERVER_IGNORED:  // ���ԣ���ѭ��
          Continue;
      end;

      if Assigned(FPerIOData) then  // ����ֹͣʱ PerIOData = Nil
      begin
        if RetValue then
          FErrorCode := 0
        else  // �쳣
          FErrorCode := WSAGetLastError;

        if (FDetail.Working = False) then  // ���õ��߳��� + 1
        begin
          FDetail.Working := True;
          windows.InterlockedIncrement(FSummary^.WorkingCount);
        end;

        // ��߳��� + 1
        windows.InterlockedIncrement(FSummary^.ActiveCount);

        try
          if (FPerIOData^.IOType = ioAccept) then // 1. AcceptEx ģʽ����
            FServer.AcceptExClient(FPerIOData, FErrorCode)
          else
          if Assigned(FPerIOData^.Owner) then     // 2. �����ӵĿͻ���
            HandleIOData;
        finally
          // ��߳��� - 1
          windows.InterlockedDecrement(FSummary^.ActiveCount);
        end;
      end;
    except
      on E: Exception do
      begin
        if Assigned(FServer.FOnError) then
          FServer.FOnError(FServer, E);
      end;
    end;

  // �������߳��� -1
  windows.InterlockedDecrement(FSummary^.ThreadCount);

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TWorkThread.ExecuteWork->ֹͣ�����߳�: ' + IntToStr(FThreadIdx));
  {$ENDIF}

end;

procedure TWorkThread.HandleIOData;
const
  IODATA_STATE_RECV  = 10;  // ����
  IODATA_STATE_SEND  = 20;  // ����
  {$IFDEF TRANSMIT_FILE}       
  IODATA_STATE_TRANS = 30;  // ����
  {$ENDIF}
  IODATA_STATE_ERROR = 40;  // �쳣��ر�
begin
  // ����һ���շ��¼�
                                                      
  // IOData �� TBaseSocket ����:
  //   IOData = Socket.FRecvBuf
  //   IOData^.Owner:= Socket

  // ioReceive, ioSend, ioPush, ioTransmit, ioDelete, ioTimeOut, ioRefuse
                  
  if (FErrorCode > 0) or (FByteCount = 0) or
     (FPerIOData^.IOType in [ioDelete, ioTimeOut, ioRefuse]) then
    FState := IODATA_STATE_ERROR      // �쳣��ر�
  else
    case FPerIOData^.IOType of
      ioReceive:
        FState := IODATA_STATE_RECV;  // ����
      {$IFDEF TRANSMIT_FILE}
      ioTransmit:
        FState := IODATA_STATE_TRANS; // TransmitFile
      {$ENDIF}  
      else
        FState := IODATA_STATE_SEND;  // ����
    end;

  // ȡ��Ӧ�� Socket
  FSocket := TBaseSocket(FPerIOData^.Owner);

  // ��������
  CalcIOSize;

  // �����¼�
  ExecIOEvent;

  case FState of
    IODATA_STATE_ERROR: // 1. ���Թر�
      begin
        {$IFDEF DEBUG_MODE}
        if (FPerIOData^.IOType <> ioPush) or FSocket.Reference then
          if (FSocket.PeerIPPort = '') then  // �������� Socket
            WriteCloseLog('Broker Dual')
          else
            WriteCloseLog(FSocket.PeerIPPort);
        {$ENDIF}
        FSocket.TryClose;
      end;
    IODATA_STATE_RECV:  // 2. �յ����ݣ�����ʹ��
      FServer.FBusiWorkMgr.AddWork(FSocket); // ����ҵ���߳��б�
    {$IFDEF TRANSMIT_FILE}
    IODATA_STATE_TRANS: // 3. TransmitFile ������ϣ��ͷ�����Դ
      FSocket.FreeTransmitRes;
    {$ENDIF}
  end;

end;

procedure TWorkThread.WriteCloseLog(const PeerIPPort: string);
begin
  if (FErrorCode > 0) then
  begin
    if (FPerIOData^.IOType = ioPush) then
      iocp_log.WriteLog('TWorkThread.HandleIOData->�����쳣�Ͽ���' +
                        PeerIPPort + ',Error:' +
                        IntToStr(FErrorCode) + ',WorkThread:' +
                        IntToStr(FThreadIdx))
    else
      iocp_log.WriteLog('TWorkThread.HandleIOData->�쳣�Ͽ���' +
                        PeerIPPort + ',Error:' +
                        IntToStr(FErrorCode) + ',WorkThread:' +
                        IntToStr(FThreadIdx));
  end else
  if (FByteCount = 0) then
    iocp_log.WriteLog('TWorkThread.HandleIOData->�ͻ��˹رգ�' +
                      PeerIPPort + ',WorkThread:' + IntToStr(FThreadIdx))
  else
    case FPerIOData^.IOType of
      ioDelete:
        iocp_log.WriteLog('TWorkThread.HandleIOData->��ɾ����' +
                          PeerIPPort + ',WorkThread:' + IntToStr(FThreadIdx));
      ioTimeOut:
        iocp_log.WriteLog('TWorkThread.HandleIOData->��ʱ�˳���' +
                          PeerIPPort + ',WorkThread:' + IntToStr(FThreadIdx));
      ioRefuse:
        iocp_log.WriteLog('TWorkThread.HandleIOData->�ܾ�����' +
                          PeerIPPort + ',WorkThread:' + IntToStr(FThreadIdx));
    end;
end;

{ TWorkThreadPool }

procedure TWorkThreadPool.CalcTaskOut(PackCount, ByteCount: Integer);
begin
  // ͳ�� TransmitFile ģʽ�������
  windows.InterlockedIncrement(FSummary.PackOutCount);
  windows.InterlockedExchangeAdd(FSummary.ByteOutCount, ByteCount);

  // ���ݰ����� +
  windows.InterlockedIncrement(FSummary.PackCount);

  // �ֽ����� +
  windows.InterlockedExchangeAdd(FSummary.ByteCount, ByteCount);
end;

constructor TWorkThreadPool.Create(const AServer: TInIOCPServer);
var
  i, CPUCount: Integer;
  Thread: TWorkThread;
begin
  // �������߳�

  FServer := AServer;
  CPUCount := GetCPUCount;

  // ͳ�Ƹſ��������̵߳�ͳ����Ϣ
  FillChar(FSummary, SizeOf(TWorkThreadSummary), 0);
  FSummary.ThreadCount := FServer.FWorkThreadCount; // �����߳���

  SetLength(FThreadAarry, FSummary.ThreadCount);

  for i := 0 to FSummary.ThreadCount - 1 do
  begin
    Thread := TWorkThread.Create(FServer);
    FThreadAarry[i] := Thread;

    Thread.FThreadIdx := i + 1;
    Thread.FSummary := @Self.FSummary;

    // �� CPU
    windows.SetThreadIdealProcessor(Thread.Handle, i mod CPUCount);  // 0,1,2...
    Thread.Resume;
  end;

  {$IFNDEF DEBUG_MODE}
  iocp_log.WriteLog('TWorkThreadPool.Create->���������̳߳ɹ�, ����: ' + IntToStr(FSummary.ThreadCount));
  {$ENDIF}

end;

destructor TWorkThreadPool.Destroy;
begin
  // ֹͣ�����߳�
  if Length(FThreadAarry) > 0 then
    StopThreads;
  inherited;
end;

procedure TWorkThreadPool.GetThreadDetail(Index: Integer; const Detail: PWorkThreadDetail);
begin
  // ��������ͳ������δ����ſ���һ��
  if (Index >= 1) and (Index <= FSummary.ThreadCount) then  // > 0 �ı��
    System.Move(FThreadAarry[Index - 1].FDetail, Detail^, SizeOf(TWorkThreadDetail));
end;

procedure TWorkThreadPool.GetThreadSummary(const Summary: PWorkThreadSummary);
begin
  // ����ÿ����ٶȣ�1���Ӷ�һ�Σ�, �����ݺ����
  System.Move(FSummary, Summary^, SizeOf(LongInt) * 3); // ǰ�� 3 ��
  Summary^.PackCount := windows.InterlockedExchange(FSummary.PackCount, 0);
  Summary^.PackInCount := windows.InterlockedExchange(FSummary.PackInCount, 0);
  Summary^.PackOutCount := windows.InterlockedExchange(FSummary.PackOutCount, 0);
  Summary^.ByteCount := windows.InterlockedExchange(FSummary.ByteCount, 0);
  Summary^.ByteInCount := windows.InterlockedExchange(FSummary.ByteInCount, 0);
  Summary^.ByteOutCount := windows.InterlockedExchange(FSummary.ByteOutCount, 0);
end;

procedure TWorkThreadPool.StopThreads;
begin
  // �������Ѿ���Ϊ Active := False

  // ֹͣ�����߳�
  while (FSummary.ThreadCount > 0) do
  begin
    FServer.FIOCPEngine.StopIoCompletionPort;  // ����ֹͣ��Ϣ
    Sleep(20);
  end;

  {$IFNDEF DEBUG_MODE}
  iocp_log.WriteLog('TWorkThreadPool.StopThreads->ֹͣ�����̳߳ɹ�, ����: ' + IntToStr(Length(FThreadAarry)));
  {$ENDIF}

  // �ں�
  SetLength(FThreadAarry, 0);
end;

{ TTimeoutThread }

constructor TTimeoutThread.Create(const AServer: TInIOCPServer);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FServer := AServer;
end;

procedure TTimeoutThread.CreateQueue(SocketPool: TIOCPSocketPool);
var
  CurrNode: PLinkRec;
  TickCount: Cardinal;
  Socket: TBaseSocket;
begin
  // �������ӿͻ����б�
  //   �����ӣ���ʱ��������û���չ�����
  SocketPool.Lock;
  try
    CurrNode := SocketPool.FirstNode;  // ��һ�ڵ�
    TickCount := GetTickCount;  // ��ǰʱ��
    while (CurrNode <> Nil) do
    begin
      Socket := TBaseSocket(CurrNode^.Data);
      if Socket.CheckTimeOut(TickCount) then
        FSockets.Add(Socket);
      CurrNode := CurrNode^.Next;
    end;
  finally
    SocketPool.UnLock;
  end;
end;

procedure TTimeoutThread.ExecuteWork;
  procedure PostTimeOutEvent;
  var
    i: Integer;
  begin
    // 1. ����ʱ�˳���Ϣ���ͻ���
    for i := 0 to FSockets.Count - 1 do
      TBaseSocket(FSockets.Items[i]).PostEvent(ioTimeOut);
  end;
const
  MSECOND_COUNT = 30000;  // ���� 30 ��û���ݴ���ͳ��ԶϿ�
var
  i: Integer;
begin
  inherited;
  // ���ر������ӡ��Ż���Դʹ��

  FSemapHore := CreateSemapHore(Nil, 0, 1, Nil); // �źŵ�

  i := 1;
  FWorktime := 0;
  FServer.FTimeoutChecking := True;

  while (Terminated = False) do
    try
      // �ȴ� MSECOND_COUNT ����
      WaitForSingleObject(FSemapHore, MSECOND_COUNT);

//      Continue;       // ����
      if Terminated then
        Break;

      // ���������б��ͷ�������
      if (FServer.FTimeOut > 0) then
      begin
        FSockets := TInDataList.Create;
        try
          if Assigned(FServer.FSocketPool) then
            CreateQueue(FServer.FSocketPool);
          if Assigned(FServer.FHttpSocketPool) then
            CreateQueue(FServer.FHttpSocketPool);
          if Assigned(FServer.FWebSocketPool) then
            CreateQueue(FServer.FWebSocketPool);;
          if (FSockets.Count > 0) then
            PostTimeOutEvent;
        finally
          FSockets.Free;
        end;
      end;

      FWorktime := Now();
      if (Frac(FWorktime) > 0.00) and (Frac(FWorktime) < 0.08) then  // 0 - 2��
      begin
        case i of
          1..5: begin
            // �Ż���Դ�����������Դ�࣬ʹ���� -> �Ż���
            OptimizePool(FServer.FSocketPool);
            if Assigned(FServer.FHttpSocketPool) then
              OptimizePool(FServer.FHttpSocketPool);
            if Assigned(FServer.FWebSocketPool) then
              OptimizePool(FServer.FWebSocketPool);
            OptimizePool(FServer.FIODataPool, FServer.BusinessThreadCount);
          end;
          30:  // ����һ�� Cookie
            FServer.InvalidSessions;
          40:  // ��� IP ��¼
            FServer.ClearIPList;
          50: begin  // ռ���ڴ治������������һ��
            i := 0;
            __ResetMMProc(FServer.FGlobalLock);
          end;
        end;
        Inc(i); // ���� +
      end;
    except
      iocp_log.WriteLog('TTimeoutThread.ExecuteWork->' + GetSysErrorMessage);
    end;

  CloseHandle(FSemapHore);
  FServer.FTimeoutChecking := False;
  
end;

procedure TTimeoutThread.OptimizePool(ObjectPool: TObjectPool; Delta: Integer);
begin
  // �Ż���Դ��
  if (ObjectPool.NodeCount > ObjectPool.IniCount) and
     (ObjectPool.UsedCount - Delta <= ObjectPool.IniCount) then
  begin
    FServer.FGlobalLock.Acquire;
    try
      ObjectPool.Optimize;
    finally
      FServer.FGlobalLock.Release;
    end;
  end;
end;

procedure TTimeoutThread.Stop;
begin
  Terminate;
  ReleaseSemapHore(FSemapHore, 1, Nil);  // �ź���+1������ WaitForSingleObject
  while FServer.FTimeoutChecking do Sleep(10);
end;

end.
