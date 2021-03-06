(*
 * iocp 服务器、工作线程池、关闭线程等
 *)
unit iocp_server;

interface

{$I in_iocp.inc}        // 模式设置

uses
  Windows, Classes, SysUtils, ActiveX,
  iocp_Winsock2, iocp_log, iocp_base,
  iocp_baseObjs, iocp_objPools, iocp_threads,
  iocp_sockets, iocp_managers, iocp_wsExt, 
  iocp_lists, iocp_api, http_objects;

type

  TIOCPEngine     = class;    // IOCP 引擎
  TInIOCPServer   = class;    // IOCP 服务器
  TAcceptManager  = class;    // AcceptEx 模式管理

  TWorkThread     = class;    // 工作线程
  TWorkThreadPool = class;    // 工作线程池
  TTimeoutThread  = class;    // 超时检查线程

  // ================== IOCP 引擎 ==================

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

  // ================== TInIOCPServer 启动参数属性组 类 ======================

  TServerParams = class(TPersistent)
  private
    FOwner: TInIOCPServer;    // 宿主
    function GetBusyRefuseService: Boolean;  // 繁忙拒绝服务
    function GetClientPoolSize: Integer;     // 预设客户端数量
    function GetMaxPushCount: Integer;       // 运行每秒最大推送数
    function GetMaxQueueCount: Integer;      // 允许的最大队列任务数
    function GetMaxIOTraffic: Integer;         // 最大流量
    function GetPreventAttack: Boolean;      // 防攻击
    function GetTimeOut: Cardinal;           // 设置超时间隔
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

  // ================== TInIOCPServer 服务线程属性组 类 ======================

  TThreadOptions = class(TPersistent)
  private
    FOwner: TInIOCPServer;
    function GetBusiThreadCount: Integer;   // 取业务线程数
    function GetPushThreadCount: Integer;   // 取推送线程数
    function GetWorkThreadCount: Integer;   // 取工作线程数
    procedure SetBusiThreadCount(const Value: Integer);
    procedure SetPushThreadCount(const Value: Integer);
    procedure SetWorkThreadCount(const Value: Integer);    // 宿主
  public
    constructor Create(AOwner: TInIOCPServer);
  published
    property BusinessThreadCount: Integer read GetBusiThreadCount write SetBusiThreadCount;
    property PushThreadCount: Integer read GetPushThreadCount write SetPushThreadCount;    
    property WorkThreadCount: Integer read GetWorkThreadCount write SetWorkThreadCount;    
  end;

  // ================== TInIOCPServer 管理器属性组 类 ======================

  TIOCPManagers = class(TPersistent)
  private
    FOwner: TInIOCPServer;   // 宿主
    function GetClientMgr: TInClientManager;       // 客户端管理
    function GetCustomMgr: TInCustomManager;       // 自定义消息
    function GetDatabaseMgr: TInDatabaseManager;   // 数据库管理
    function GetFileMgr: TInFileManager;           // 文件管理
    function GetMessageMgr: TInMessageManager;     // 消息管理
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
  
  // ================== TInIOCPServer 服务器 类 ==================

  TOnConnectEvnet   = procedure(Sender: TObject; Socket: TBaseSocket) of object;
  TOnStreamInEvent  = procedure(Sender: TBaseSocket; const Data: PAnsiChar; Size: Cardinal) of object;
  TOnStreamOutEvent = procedure(Sender: TBaseSocket; Size: Cardinal) of object;
  TOnErrorEvent     = procedure(Sender: TObject; const Error: Exception) of object;

  TInIOCPServer = class(TComponent)
  private
    FIODataPool: TIODataPool;            // 内存管理
    FSocketPool: TIOCPSocketPool;        // C/S 客户端管理
    FHttpSocketPool: TIOCPSocketPool;    // http 客户端管理
    FWebSocketPool: TIOCPSocketPool;     // WebSocket 客户池

    FAcceptManager: TAcceptManager;      // AcceptEx 管理
    FBusiWorkMgr: TBusiWorkManager;      // 业务管理
    FPushManager: TPushMsgManager;       // 消息推送管理

    FCheckThread: TTimeoutThread;        // 检查死连接线程
    FCloseThread: TCloseSocketThread;    // 关闭 Socket 的专用线程

    FListenSocket: TListenSocket;        // 监听套接字
    FIOCPEngine: TIOCPEngine;            // IOCP 驱动
    FWorkThreadPool: TWorkThreadPool;    // 工作线程池

    FActive: Boolean;                    // 启动状态
    FBusyRefuseService: Boolean;         // 繁忙拒绝服务
    FClientPoolSize: Integer;            // 预设客户端数量
    FGlobalLock: TThreadLock;            // 全局锁
    FIOCPManagers: TIOCPManagers;        // 管理器属性组
    FMaxQueueCount: Integer;             // 允许的最大队列任务数
    FMaxPushCount: Integer;              // 允许每秒最大推送消息数
    FMaxIOTraffic: Integer;              // 允许每秒最大流量

    FPeerIPList: TPreventAttack;         // 接入的 IP 列表
    FPreventAttack: Boolean;             // 防攻击

    FServerAddr: String;                 // 服务器地址
    FServerPort: Word;                   // 端口

    FSessionMgr: THttpSessionManager;    // Http 的会话管理（引用）
    FStartParams: TServerParams;         // 启动参数属性组
    FState: Integer;                     // 状态
    FStreamMode: Boolean;                // 当作流服务模式
    FTimeOut: Cardinal;                  // 超时间隔（0时不检查）
    FTimeoutChecking: Boolean;           // 关闭线程工作状态
    
    FThreadOptions: TThreadOptions;      // 线程设置
    FBusiThreadCount: Integer;           // 业务线程数
    FPushThreadCount: Integer;           // 推送线程数
    FWorkThreadCount: Integer;           // 工作线程数

    // =========== 管理器组件 ===========

    FIOCPBroker: TInIOCPBroker;          // 代理器
    FClientMgr: TInClientManager;        // 客户端管理
    FCustomMgr: TInCustomManager;        // 自定义消息
    FDatabaseMgr: TInDatabaseManager;    // 数据库管理
    FFileMgr: TInFileManager;            // 文件管理
    FMessageMgr: TInMessageManager;      // 消息管理
    FHttpDataProvider: TInHttpDataProvider; // Http 服务

    // =========== 事件 ===========

    FBeforeOpen: TNotifyEvent;           // 启动前事件
    FAfterOpen: TNotifyEvent;            // 启动后事件
    FBeforeClose: TNotifyEvent;          // 停止前事件
    FAfterClose: TNotifyEvent;           // 停止后事件

    FOnConnect: TOnConnectEvnet;         // 接入事件
    FOnDataReceive: TOnStreamInEvent;    // 收到数据
    FOnDataSend: TOnStreamOutEvent;      // 发出数据
    FOnDisconnect: TOnConnectEvnet;      // 断开事件    
    FOnError: TOnErrorEvent;             // 异常事件
    
    // 客户端接入
    procedure AcceptClient(Socket: TSocket; AddrIn: PSockAddrIn);
    procedure AcceptExClient(IOData: PPerIOData; ErrorCode: Integer);

    procedure ClearIPList;               // 清除 IP 表
    procedure ClosePoolSockets;          // 关闭池内套接字    
    procedure Prepare;                   // 准备监听 Socket
    procedure OpenDetails;               // 启动细节

    procedure InternalOpen;              // 启动
    procedure InternalClose;             // 停止
    procedure InvalidSessions;           // 删除过期的SessionId

    procedure InitExtraResources;        // 设置额外资源
    procedure FreeExtraResources;        // 释放额外资源

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
                            HttpSocketUsedCount, PushQueueCount,
                            WorkerUsedCount: Integer);
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
    // 管理器
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
    // 事件
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

  // ================== AcceptEx 管理 ==================

  TAcceptManager = class(TObject)
  private
    FAcceptors: array of TAcceptSocket;  // 套接字投放数组
    FAcceptorCount: Integer;             // 套接字投放数
    FSuccededCount: Integer;             // 套接字投放成功数
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

  // ================== 工作线程 ==================

  TWorkThread = class(TBaseThread)
  private
    FServer: TInIOCPServer;         // 服务器
    FThreadIdx: Integer;            // 数字编号
    FSummary: PWorkThreadSummary;   // 统计概况
    FDetail: TWorkThreadDetail;     // 统计明细

    FByteCount: Cardinal;           // 收到字节数
    FErrorCode: Integer;            // 异常代码
    FPerIOData: PPerIOData;         // 重叠结果
    FBaseSocket: TBaseSocket;       // 当前客户端对象
    FState: Integer;                // 客户端对象状态

    procedure HandleIOData;
  private
    procedure CalcIOSize; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure ExecIOEvent; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure WriteCloseLog(const PeerIPPort: string); {$IFDEF USE_INLINE} inline; {$ENDIF}
  protected
    procedure ExecuteWork; override;
  public
    constructor Create(const AServer: TInIOCPServer); reintroduce;
  end;

  // ================== 工作线程池 ==================

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

  // ===================== 超时检查线程 =====================

  TTimeoutThread = class(TBaseThread)
  private
    FServer: TInIOCPServer;   // 服务器
    FSemapHore: THandle;      // 信号灯
    FSockets: TInDataList;    // 超时客户端的列表
    FWorktime: TDateTime;     // 检查时间
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
  // PerIOData 内包含了 Owner 信息，忽略 CompletionKey
  if iocp_api.CreateIoCompletionPort(Socket, FHandle, 0, 0) = 0 then
  begin
    Result := False;
    iocp_log.WriteLog('TIOCPEngine.BindIoCompletionPort->' + GetWSAErrorMessage);
  end else
    Result := True;
end;

constructor TIOCPEngine.Create;
begin
  // 建 IOCP 完成端口
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
  // PerIOData 内包含了 Owner 信息，忽略 CompletionKey
  Result := iocp_api.GetQueuedCompletionStatus(FHandle, ByteCount,
                     CompletionKey, POverlapped(PerIOData), INFINITE);
end;

procedure TIOCPEngine.StopIoCompletionPort;
begin
  // 投放 nil，通知 IOCP 停止工作
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
  if (Value >= FOwner.FWorkThreadCount) then // 不能比工作线程少
    FOwner.FBusiThreadCount := Value;
end;

procedure TThreadOptions.SetPushThreadCount(const Value: Integer);
begin
  if (Value >= FOwner.FWorkThreadCount) then // 不能比工作线程少
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
    FOwner.FClientMgr.RemoveFreeNotification(FOwner);  // 取消通知消息
  FOwner.FClientMgr := Value;
  if Assigned(FOwner.FClientMgr) then
  begin
    FOwner.FClientMgr.FreeNotification(FOwner);  // 设计时通知消息
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
  // 客户端接入，接受请求

  if Assigned(FPeerIPList) then  // 检查是否恶意的 IP
  begin
    PeerIP := TRawSocket.GetPeerIP(AddrIn);
    if FPeerIPList.CheckAttack(PeerIP, 10000, 10) then  // 10 秒内出现 10 个客户端连接
    begin
      iocp_Winsock2.CloseSocket(Socket);
      iocp_log.WriteLog('TInIOCPServer.AcceptClient->关闭攻击套接字，' + PeerIP);
      Exit;
    end;
  end;

  // 准备、设置 Socket（默认为 THttpSocket）
  if FStreamMode then  // 纯粹的数据流服务
    SocketPool := FSocketPool
  else
    SocketPool := FHttpSocketPool;

  ASocket := TBaseSocketRef(SocketPool.Pop^.Data);
  if (Assigned(ASocket) = False) then  // 除非内存耗尽
  begin
    iocp_log.WriteLog('TInIOCPServer.AcceptClient->可能内存不足.');
    Exit;
  end;

  ASocket.IniSocket(Self, Socket);  // 绑定 Server、Socket
  ASocket.SetPeerAddr(AddrIn);  // 设置地址

  // 注：改为在此绑定 IOCP
  FIOCPEngine.BindIoCompletionPort(Socket);

  if (FBusyRefuseService and SocketPool.Full) or  // 连接池满
     (FMaxQueueCount > 0) and
     (FBusiWorkMgr.ActiveCount + FPushManager.PushMsgCount > FMaxQueueCount) // 任务列表堵塞
  //   (FBusiWorkMgr.ActiveCount = MaxInt)  // 在管理数模，见：TBusiWorkManager.GetActiveCount
  then
    ASocket.PostEvent(ioRefuse) // 拒绝服务
  else begin
    // 不用超时检查，加心跳
    if (FTimeOut = 0) then
      iocp_wsExt.SetKeepAlive(Socket);

    // 调用客户端接入事件，如果要禁止接入，可以 Close
    if Assigned(FOnConnect) then
      FOnConnect(Self, ASocket);

    if ASocket.Connected then  // 允许接入
    begin
      ASocket.PostRecv;        // 投放接收内存块
      {$IFDEF DEBUG_MODE}
      iocp_log.WriteLog('TInIOCPServer.AcceptClient->客户端接入：' + ASocket.PeerIPPort);
      {$ENDIF}
    end else
    begin
      CloseSocket(ASocket);    // 回收Socket
      {$IFDEF DEBUG_MODE}
      iocp_log.WriteLog('TInIOCPServer.AcceptClient->禁止客户端接入：' + ASocket.PeerIPPort);
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
  // AcceptEx 模式接受连接请求
  // 接入的客户端被连接到 AcceptEx 对应的 Socket，
  //   要申请新的 Socket 继续 AcceptEx

  NewSocket := TAcceptSocket(IOData^.Owner);
  FAcceptManager.DecAcceptExCount;     // 投放数-

  try
    try
      if (ErrorCode > 0) or // 异常
         (NewSocket.SetOption = False) // 复制属性失败
      then
        NewSocket.Close  // 关闭
      else begin
        // 提取接入的 Socket 地址
        LocalAddrSize := ADDRESS_SIZE_16;
        RemoteAddrSize := ADDRESS_SIZE_16;
        gGetAcceptExSockAddrs(IOData^.Data.buf, 0, ADDRESS_SIZE_16,
                              ADDRESS_SIZE_16, LocalAddr, LocalAddrSize,
                              RemoteAddr, RemoteAddrSize);
        // 把 Socket 加入客户池
        AcceptClient(NewSocket.Socket, PSockAddrIn(RemoteAddr));
      end;
    finally
      if FActive then  // 继续建 Socket，绑定 IOCP, 投放，等待接入
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
  // 清除 IP 列表内容
  UsedCount := FSocketPool.UsedCount;
  if Assigned(FHttpSocketPool) then
    Inc(UsedCount, FHttpSocketPool.UsedCount);
  if Assigned(FWebSocketPool) then
    Inc(UsedCount, FWebSocketPool.UsedCount);
  if (UsedCount = 0) then // 没有客户端连接
  begin
    FGlobalLock.Acquire;
    try
      if Assigned(FPeerIPList) then
        FPeerIPList.Clear;  // 接入的 IP 列表
      if Assigned(FHttpDataProvider) then  // 清除 FHttpDataProvider 的 IP
        FHttpDataProvider.ClearIPList;
    finally
      FGlobalLock.Release;
    end;
  end;
end;

procedure TInIOCPServer.ClosePoolSockets;
var
  i: Integer;
  Sockets: TInList;
begin
  Sockets := TInList.Create;
  try
    if Assigned(FSocketPool) then
      FSocketPool.GetSockets(Sockets);

    if Assigned(FHttpSocketPool) then
      FHttpSocketPool.GetSockets(Sockets);

    if Assigned(FWebSocketPool) then
      FWebSocketPool.GetSockets(Sockets);

    // 关闭
    for i := 0 to Sockets.Count - 1 do
      CloseSocket(Sockets.PopFirst);

    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.ClosePoolSockets->关闭客户池套接字成功。');
    {$ENDIF}         
  finally
    Sockets.Free;
  end;
end;

procedure TInIOCPServer.CloseSocket(ASocket: TBaseSocket);
begin
  // 减少 IP/Session 引用，关闭 Socket
  // 这是关闭服务端 Socket 的唯一入口
  if FActive then
  begin
    if Assigned(FPeerIPList) then
      FPeerIPList.DecRef(ASocket.PeerIP);
    if Assigned(FSessionMgr) and (ASocket is THttpSocket) then
      FSessionMgr.DecRef(THttpSocket(ASocket).SessionId);
    if Assigned(FOnDisconnect) and ASocket.Connected then  // 客户端断开事件
      FOnDisconnect(Self, ASocket);      
    FCloseThread.AddSocket(ASocket);
  end;
end;

constructor TInIOCPServer.Create(AOwner: TComponent);
begin
  inherited;
  // 设置默认值
  FActive := False;
  FBusyRefuseService := False;
  FClientPoolSize := 0;
  FMaxPushCount := 10000;
  FMaxQueueCount := 0;
  FPreventAttack := False;
  FServerPort := DEFAULT_SVC_PORT;
  FTimeOut := 0; // 不用超时检查 TIME_OUT_INTERVAL;

  // 工作线程数
  // 因工作线程和业务线程分离，工作线程很轻松，
  // 不采用建议数（GetCPUCount * 2 + 2）
  FWorkThreadCount := GetCPUCount;
  if (FWorkThreadCount > 4) then
    FWorkThreadCount := 4;

  FBusiThreadCount := FWorkThreadCount * 2;
  FPushThreadCount := FWorkThreadCount;

  // 属性组控制
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
  // 清除登录、数模和 Http 的 Cookie 信息
  if Assigned(FClientMgr) then
    FClientMgr.Clear;
  if Assigned(FDatabaseMgr) then
    FDatabaseMgr.Clear;
  if Assigned(FHttpDataProvider) then
    FHttpDataProvider.SessionMgr.Clear;
end;

procedure TInIOCPServer.GetAcceptExCount(var AAcceptExCount: Integer);
begin
  // 取 AcceptEx 投放成功的 Socket 数
  if Assigned(FAcceptManager) then
    AAcceptExCount := FAcceptManager.FSuccededCount
  else
    AAcceptExCount := 0;
end;

procedure TInIOCPServer.GetClientInfo(var CSSocketCount, CSSocketUsedCount,
  HttpSocketCount, HttpSocketUsedCount, ActiveCount: Integer;
  var WorkTotalCount: IOCP_LARGE_INTEGER);
begin
  // 取 Socket 统计数
  CSSocketCount := FSocketPool.NodeCount; // 结点数
  CSSocketUsedCount := FSocketPool.UsedCount; // 连接数

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

  // 在列任务数（业务+推送估算）
  ActiveCount := FBusiWorkMgr.ActiveCount;
  if Assigned(FPushManager) then
    Inc(ActiveCount, FPushManager.PushMsgCount); // FPushManager.ActiveCount;

  // 已执行的任务总数
  WorkTotalCount := FBusiWorkMgr.WorkTotalCount;
end;

procedure TInIOCPServer.GetIODataInfo(var IODataCount,
  CSSocketUsedCount, HttpSocketUsedCount, PushQueueCount,
  WorkerUsedCount: Integer);
begin
  // 统计内存块的使用

  IODataCount := FIODataPool.NodeCount; // 总占用数  
  CSSocketUsedCount := IODataCount - FBusiThreadCount;  // C/S 占用数
  WorkerUsedCount := FBusiThreadCount;  // 发送器/工作线程占用
  
  if FStreamMode then // 流模式、代理模式
  begin
    HttpSocketUsedCount := 0;
    PushQueueCount := 0;
  end else
  begin
    if Assigned(FHttpSocketPool) then  // 建了 THttpSocket
    begin
      HttpSocketUsedCount := FHttpSocketPool.NodeCount;
      Dec(CSSocketUsedCount, HttpSocketUsedCount);  // 总数减少
    end else
      HttpSocketUsedCount := 0;

    if Assigned(FPushManager) then  // 建了 FPushManager
    begin
      PushQueueCount := FPushManager.ActiveCount;
      Dec(CSSocketUsedCount, PushQueueCount);  // 总数减少
    end else
      PushQueueCount := 0;
  end;
end;

procedure TInIOCPServer.GetThreadInfo(const ThreadInfo: PWorkThreadSummary;
  var BusiThreadCount, BusiActiveCount, PushThreadCount,
  PushActiveCount: Integer; var CheckTimeOut: TDateTime);
begin
  // 取线程信息
  FWorkThreadPool.GetThreadSummary(ThreadInfo); // 线程池信息
  
  BusiThreadCount := FBusiThreadCount;  // 业务线程数
  BusiActiveCount := FBusiWorkMgr.ActiveThreadCount; // 活动的业务线程数

  if Assigned(FPushManager) then
  begin
    PushThreadCount := FPushThreadCount;  // 推送线程数
    PushActiveCount := FPushManager.ActiveThreadCount; // 活动的推送线程数
  end else
  begin
    PushThreadCount := 0;
    PushActiveCount := 0;
  end;

  CheckTimeOut := FCheckThread.FWorktime;       // 超时检查时间
end;

procedure TInIOCPServer.InitExtraResources;
begin
  // 检查调整服务类型
  if Assigned(FIOCPBroker) then
    FStreamMode := True  // 当作是流服务
  else
    FStreamMode := not (Assigned(FClientMgr)   or Assigned(FCustomMgr) or
                        Assigned(FDatabaseMgr) or Assigned(FFileMgr)   or
                        Assigned(FMessageMgr)  or Assigned(FHttpDataProvider));
  // 建消息书写器
  if Assigned(FMessageMgr) then
    FMessageMgr.CreateMsgWriter(Assigned(FHttpDataProvider));
end;

procedure TInIOCPServer.InternalClose;
begin
  if Assigned(FBeforeClose) then
    FBeforeClose(Self);

  FActive := False;         // 工作停止
  FState := SERVER_IGNORED; // 忽略，工作线程空循环
    
  // 停止、释放超时检查线程
  if Assigned(FCheckThread) then
  begin
    FCheckThread.Stop;
    FCheckThread := Nil;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FCheckThread（超时检查线程）停止成功。');
    {$ENDIF}
  end;

  // 释放监听 Socket（不受理连接）
  if Assigned(FListenSocket) then
  begin
    FListenSocket.Close;
    FreeAndNil(FListenSocket);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FListenSocket（监听套接字）释放成功。');
    {$ENDIF}
  end;

  // 关闭池内套接字
  ClosePoolSockets;
    
  if Assigned(FPushManager) then  // 等待推送线程执行完毕
    FPushManager.WaitFor;

  if Assigned(FBusiWorkMgr) then  // 等待业务线程执行完毕
    FBusiWorkMgr.WaitFor;

  if Assigned(FCloseThread) then  // 等待 Socket 关闭完毕
    FCloseThread.WaitFor;

  // 正式停止，工作线程将结束
  FState := SERVER_STOPED;        

  // 释放额外资源
  FreeExtraResources;

  // 释放工作线程 FWorkThreadPool

  if Assigned(FWorkThreadPool) then      
  begin
    FWorkThreadPool.StopThreads;
    FreeAndNil(FWorkThreadPool);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FWorkThreadPool（工作线程池）停止成功。');
    {$ENDIF}
  end;

  if Assigned(FIOCPBroker) and FIOCPBroker.ReverseMode then
  begin
    FIOCPBroker.Stop;  // 停止
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIOCPBroker（反向代理）释放 Ping 套接字。');
    {$ENDIF}
  end;
  
  // 释放已投放的 Socket
  if Assigned(FAcceptManager) then
  begin
    FreeAndNil(FAcceptManager);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FAcceptManager（客户端接入管理）释放成功。');
    {$ENDIF}
  end;

  // 释放业务线程
  if Assigned(FBusiWorkMgr) then
  begin
    FBusiWorkMgr.StopThreads;
    FreeAndNil(FBusiWorkMgr);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FBusiThreadMgr（业务线程管理）释放成功。');
    {$ENDIF}
  end;

  // 释放消息推送线程
  if Assigned(FPushManager) then
  begin
    FPushManager.StopThreads;
    FreeAndNil(FPushManager);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FPushManager（推送线程管理）释放成功。');
    {$ENDIF}
  end;

  if Assigned(FIOCPEngine) then
  begin
    FreeAndNil(FIOCPEngine);     // 在释放工作线程后
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FIOCPEngine（IOCP引擎）释放成功。');
    {$ENDIF}
  end;

  if Assigned(FSocketPool) then
  begin
    FreeAndNil(FSocketPool);     // 在前，要释放 IO_DATA
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FSocketPool（客户池）释放成功。');
    {$ENDIF}
  end;

  if Assigned(FHttpSocketPool) then
  begin
    FreeAndNil(FHttpSocketPool); // 在前，要释放 IO_DATA
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FHttpSocketPool（客户池）释放成功。');
    {$ENDIF}
  end;

  if Assigned(FWebSocketPool) then
  begin
    FreeAndNil(FWebSocketPool); // 在前，要释放 IO_DATA
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FWebSocketPool（WebSocket池）释放成功。');
    {$ENDIF}
  end;

  if Assigned(FIODataPool) then
  begin
    FreeAndNil(FIODataPool);   // 最后释放收发内存
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FIODataPool（内存池）释放成功。');
    {$ENDIF}
  end;

  if Assigned(FPeerIPList) then
  begin
    FreeAndNil(FPeerIPList);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FPeerIPList（防攻击管理）释放成功。');
    {$ENDIF}
  end;

  // 最后释放 FGlobalLock（在 ClearBalanceServers 后）
  if Assigned(FGlobalLock) then  // TSystemGlobalLock
  begin
    TSystemGlobalLock.FreeGlobalLock;
    FGlobalLock := nil;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FGlobalLock（全局锁）释放成功。');
    {$ENDIF}
  end;

  // 停止、释放关闭客户端的线程
  if Assigned(FCloseThread) then
  begin
    FCloseThread.Stop;
    FCloseThread := Nil;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.InternalClose->FCloseThread（关闭套接字线程）停止成功。');
    {$ENDIF}
  end;
    
  CoUninitialize;

  iocp_log.WriteLog('TInIOCPServer.InternalClose->IOCP 服务停止成功。');

  if Assigned(FAfterClose) and not (csDestroying in ComponentState) then
    FAfterClose(Self);

  __ResetMMProc(nil);   // 释放占用的内存
    
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
  // 删除过期 SessionId
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

  // 设置时可能为 True, 重设 False
  FActive := False;
  FState := SERVER_IGNORED;

  // 开始当作流服务器，在 InitMoreResource 中会调整
  FStreamMode := True;  

  // 调整繁忙拒绝、客户端池（允许不开连接池）
  if FBusyRefuseService and (FClientPoolSize = 0) then
    FClientPoolSize := MAX_CLIENT_COUNT
  else
  if (FClientPoolSize = 0) then
    FBusyRefuseService := False;

  // 全局锁,（在 InitMoreResource 之前）
  FGlobalLock := TSystemGlobalLock.CreateGlobalLock;  // TThreadLock.Create;

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FGlobalLock（全局锁）创建成功。');
  {$ENDIF}

  // 设置额外资源
  InitExtraResources;

  // 防攻击管理
  if FPreventAttack then
  begin
    FPeerIPList := TPreventAttack.Create;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FPeerIPList（防攻击管理）创建成功。');
    {$ENDIF}
  end;

  // 准备收发内存池，在前
  FIODataPool := TIODataPool.Create(FClientPoolSize);
  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIODataPool（内存池）创建成功。');
  {$ENDIF}

  // 准备客户端池
  if Assigned(FIOCPBroker) then  // 代理模式（特殊的流）
    FSocketPool := TIOCPSocketPool.Create(otBroker, FClientPoolSize)
  else
  if FStreamMode then  // 用 TStreamSocket
    FSocketPool := TIOCPSocketPool.Create(otStreamSocket, FClientPoolSize)
  else begin  // 用 TIOCPSocket + THttpSocket
    FSocketPool := TIOCPSocketPool.Create(otSocket, FClientPoolSize);
    FHttpSocketPool := TIOCPSocketPool.Create(otHttpSocket, FClientPoolSize);
    if Assigned(FHttpDataProvider) and Assigned(FHttpDataProvider.WebSocketManager) then
      FWebSocketPool := TIOCPSocketPool.Create(otWebSocket, 0);
  end;

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FSocketPool（客户池）创建成功。');
  if Assigned(FHttpSocketPool) then
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FHttpSocketPool（客户池）创建成功。');
  if Assigned(FWebSocketPool) then
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FWebSocketPool（WebSocket池）创建成功。');
  {$ENDIF}

  // IOCP 引擎
  //  注：以下对象新建后自动进入工作状态
  FIOCPEngine := TIOCPEngine.Create;

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIOCPEngine（IOCP引擎）创建成功。');
  {$ENDIF}

  // 工作线程池
  FWorkThreadPool := TWorkThreadPool.Create(Self);

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FWorkThreadPool（工作线程池）创建成功。');
  {$ENDIF}

  // 业务线程调度管理
  FBusiWorkMgr := TBusiWorkManager.Create(Self, FBusiThreadCount);

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FBusiThreadMgr（业务线程管理）创建成功。');
  {$ENDIF}

  // 在推送线程调度（在 FBusiWorkMgr 后）
  if (FStreamMode = False) then
  begin
    FPushManager := TPushMsgManager.Create(FBusiWorkMgr, FPushThreadCount, FMaxPushCount);
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FPushManager（推送线程管理）创建成功。');
    {$ENDIF}
  end;

  // 关闭 Socket 的线程
  FCloseThread := TCloseSocketThread.Create;
  FCloseThread.Resume;

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FCloseThread（关闭套接字线程）创建成功。');
  {$ENDIF}

  // 开启“死连接”检查线程（定时检查）
  FCheckThread := TTimeoutThread.Create(Self);
  FCheckThread.Resume;  // 正式开启

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.OpenDetails->FCheckThread（超时检查线程）创建成功。');
  {$ENDIF}

  // AcceptEx 模式时 FListenSocket.Socket 必须绑定 IOCP，
  // Accept 模式则否。

  FIOCPEngine.BindIoCompletionPort(FListenSocket.Socket);

  if Assigned(FIOCPBroker) and FIOCPBroker.ReverseMode then
  begin
    FIOCPBroker.Prepare;  // 桥模式，无须监听
    FActive := True;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIOCPBroker（反向代理）准备完毕。');
    {$ENDIF}
  end else
  begin
    if Assigned(FIOCPBroker) then
    begin
      FIOCPBroker.Prepare; // 外部模式
      {$IFDEF DEBUG_MODE}
      if (FIOCPBroker.ProxyType = ptDefault) then
        iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIOCPBroker（普通代理）准备完毕。')
      else
        iocp_log.WriteLog('TInIOCPServer.OpenDetails->FIOCPBroker（外部代理）准备完毕。');
      {$ENDIF}
    end;

    // 预建接入用的 Socket
    FAcceptManager := TAcceptManager.Create(FListenSocket.Socket, FWorkThreadCount);

    // 开始监听！
    if not FListenSocket.StartListen then
    begin
      FListenSocket.Close;
      FreeAndNil(FListenSocket);
      raise Exception.Create('套接字监听异常：' + FServerAddr + ':' + IntToStr(FServerPort));
    end;

    // 投放（要监听成功）！
    FAcceptManager.AcceptEx(FActive);

    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->FAcceptManager（客户端接入管理）创建成功。');
    {$ENDIF}
  end;

  if FActive then
  begin
    FState := SERVER_RUNNING;    // 正式工作
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->IOCP 服务启动成功。');
  end else
    iocp_log.WriteLog('TInIOCPServer.OpenDetails->IOCP 服务启动失败。');

  if Assigned(FAfterOpen) then
    FAfterOpen(Self);
end;

procedure TInIOCPServer.Loaded;
begin
  inherited;
  // 装载后，FActive -> 打开
  if FActive and not (csDesigning in ComponentState) then
    InternalOpen;
end;

procedure TInIOCPServer.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) then  // 设计时收到删除组件消息
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
  // 准备监听 Socket
  CoInitializeEx(nil, 0);

  FListenSocket := TListenSocket.Create(True);

  if not FListenSocket.Bind(FServerPort, FServerAddr) then
  begin
    FListenSocket.Close;
    FreeAndNil(FListenSocket);
    raise Exception.Create('套接字绑定异常：' + FServerAddr + ':' + IntToStr(FServerPort));
  end else

  // 装载 WinSocket 2 函数
  GetWSExtFuncs(FListenSocket.Socket);

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TInIOCPServer.Prepare->FListenSocket（监听套接字）创建成功。');
  {$ENDIF}
end;

procedure TInIOCPServer.SetActive(const Value: Boolean);
begin
  // 开启/关闭服务
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
  // 设置 FHttpDataProvider 和设计时事件
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
  // 设置 FIOCPBroker 和设计时事件
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
  // 逐一投放接入用的套接字
  FSuccededCount := 0;
  for i := 0 to High(FAcceptors) do
    if FAcceptors[i].AcceptEx then
      Inc(FSuccededCount)
    else  // 不成功，关闭 Socket，但不释放对象
      FAcceptors[i].Close;
  Result := FSuccededCount > 0;
end;

procedure TAcceptManager.CreateSocket(ASocket: TAcceptSocket);
begin
  // 新建 Socket，绑定 IOCP（继续投放）
  ASocket.NewSocket;
  if ASocket.AcceptEx then
    Windows.InterlockedIncrement(FSuccededCount)  // 投放数 +
  else  // 不成功，关闭 Socket，但不释放对象
    ASocket.Close;
end;

constructor TAcceptManager.Create(ListenSocket: TSocket; WorkThreadCount: Integer);
var
  i: Integer;
begin
  // 预设一些 Socket，投放、等待接入
  //   测试结果：TAcceptSocket 实例不是越多越好

  case WorkThreadCount of  // 适当设 Socket 投放数，小应用 100 以内即可
    1..2:
      FAcceptorCount := 50;
    3..6:
      FAcceptorCount := 100;
    else
      FAcceptorCount := 200;
  end;
    
  SetLength(FAcceptors, FAcceptorCount);
  for i := 0 to FAcceptorCount - 1 do
    FAcceptors[i] := TAcceptSocket.Create(ListenSocket); // 建套接字，接入时绑定

end;

procedure TAcceptManager.DecAcceptExCount;
begin
  // Socket 投放成功数-
  Windows.InterlockedDecrement(FSuccededCount);
end;

destructor TAcceptManager.Destroy;
var
  i: Integer;
begin
  // 释放全部已建的接入对象
  for i := 0 to High(FAcceptors) do
    if Assigned(FAcceptors[i]) then
      FAcceptors[i].Free;
  SetLength(FAcceptors, 0);
end;

{ TWorkThread }

procedure TWorkThread.CalcIOSize;
begin
  // 计算收发数据包、字节数
  if (FPerIOData^.IOType in [ioAccept, ioReceive]) then
  begin
    // 收到数据
    windows.InterlockedIncrement(FDetail.PackInCount);
    windows.InterlockedIncrement(FSummary^.PackInCount);
    windows.InterlockedExchangeAdd(FDetail.ByteInCount, FByteCount);
    windows.InterlockedExchangeAdd(FSummary^.ByteInCount, FByteCount);
  end else
  begin
    // 发出数据
    windows.InterlockedIncrement(FDetail.PackOutCount);
    windows.InterlockedIncrement(FSummary^.PackOutCount);
    windows.InterlockedExchangeAdd(FDetail.ByteOutCount, FByteCount);
    windows.InterlockedExchangeAdd(FSummary^.ByteOutCount, FByteCount);
  end;

  // 数据包总数 + 1
  windows.InterlockedIncrement(FDetail.PackCount);
  windows.InterlockedIncrement(FSummary^.PackCount);

  // 字节总数
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
  // 执行收、发事件
  if (FPerIOData^.IOType in [ioAccept, ioReceive]) then
  begin
    // 不在此处理收到原始数据流，见：TStreamSocket.ExecuteWork
    if (FServer.FStreamMode = False) and Assigned(FServer.FOnDataReceive) then
      FServer.FOnDataReceive(FBaseSocket, FPerIOData^.Data.buf, FByteCount);
  end else
  if Assigned(FServer.FOnDataSend) then  // 发出数据事件
    FServer.FOnDataSend(FBaseSocket, FByteCount);
end;

procedure TWorkThread.ExecuteWork;
var
  RetValue: Boolean;
begin
  // 开启工作线程

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TWorkThread.ExecuteWork->准备工作线程: ' + IntToStr(FThreadIdx));
  {$ENDIF}

  FillChar(FDetail, SizeOf(TWorkThreadDetail), 0);
  FDetail.Index := FThreadIdx;

  while (Terminated = False) do
    try
      FByteCount := 0;
      FPerIOData := nil;

      // 监测 IOCP 状态
      RetValue := FServer.FIOCPEngine.GetIoCompletionStatus(FByteCount, FPerIOData);

      // 检查服务状态
      case FServer.FState of
        SERVER_STOPED:   // 停止了
          Break;
        SERVER_IGNORED:  // 忽略，空循环
          Continue;
      end;

      if Assigned(FPerIOData) then  // 服务停止时 PerIOData = Nil
      begin
        if RetValue then
          FErrorCode := 0
        else  // 异常
          FErrorCode := WSAGetLastError;

        if (FDetail.Working = False) then  // 启用的线程数 + 1
        begin
          FDetail.Working := True;
          windows.InterlockedIncrement(FSummary^.WorkingCount);
        end;

        // 活动线程数 + 1
        windows.InterlockedIncrement(FSummary^.ActiveCount);

        try
          if (FPerIOData^.IOType = ioAccept) then // 1. AcceptEx 模式接入
            FServer.AcceptExClient(FPerIOData, FErrorCode)
          else
          if Assigned(FPerIOData^.Owner) then     // 2. 已连接的客户端
            HandleIOData;
        finally
          // 活动线程数 - 1
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

  // 开启的线程数 -1
  windows.InterlockedDecrement(FSummary^.ThreadCount);

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog('TWorkThread.ExecuteWork->停止工作线程: ' + IntToStr(FThreadIdx));
  {$ENDIF}

end;

procedure TWorkThread.HandleIOData;
const
  IODATA_STATE_RECV  = 10;  // 接收
  IODATA_STATE_SEND  = 20;  // 发送
  {$IFDEF TRANSMIT_FILE}       
  IODATA_STATE_TRANS = 30;  // 发送
  {$ENDIF}
  IODATA_STATE_ERROR = 40;  // 异常或关闭
begin
  // 处理一个收发事件
                                                      
  // IOData 与 TBaseSocket 关联:
  //   IOData = Socket.FRecvBuf
  //   IOData^.Owner:= Socket

  // ioReceive, ioSend, ioPush, ioTransmit, ioDelete, ioTimeOut, ioRefuse
                  
  if (FErrorCode > 0) or (FByteCount = 0) or
     (FPerIOData^.IOType in [ioDelete, ioTimeOut, ioRefuse]) then
    FState := IODATA_STATE_ERROR      // 异常或关闭
  else
    case FPerIOData^.IOType of
      ioReceive:
        FState := IODATA_STATE_RECV;  // 接收
      {$IFDEF TRANSMIT_FILE}
      ioTransmit:
        FState := IODATA_STATE_TRANS; // TransmitFile
      {$ENDIF}  
      else
        FState := IODATA_STATE_SEND;  // 发出
    end;

  // 取对应的 Socket
  FBaseSocket := TBaseSocket(FPerIOData^.Owner);

  // 计算流量
  CalcIOSize;

  // 触发事件
  ExecIOEvent;

  case FState of
    IODATA_STATE_ERROR: // 1. 尝试关闭
      begin
        {$IFDEF DEBUG_MODE}
        if (FPerIOData^.IOType <> ioPush) or FBaseSocket.Reference then
          WriteCloseLog(FBaseSocket.PeerIPPort);
        {$ENDIF}
        FBaseSocket.TryClose;
      end;
    IODATA_STATE_RECV:  // 2. 收到数据，加锁使用
      begin
        TBaseSocketRef(FBaseSocket).MarkIODataBuf(FPerIOData);
        FServer.FBusiWorkMgr.AddWork(FBaseSocket); // 加入业务线程列表
      end;
    {$IFDEF TRANSMIT_FILE}
    IODATA_STATE_TRANS: // 3. TransmitFile 发送完毕，释放数据源
      FBaseSocket.FreeTransmitRes;
    {$ENDIF}
  end;

end;

procedure TWorkThread.WriteCloseLog(const PeerIPPort: string);
begin
  if (FErrorCode > 0) then
  begin
    if (FPerIOData^.IOType = ioPush) then
      iocp_log.WriteLog('TWorkThread.HandleIOData->推送异常断开：' +
                        PeerIPPort + ',Error:' +
                        IntToStr(FErrorCode) + ',WorkThread:' +
                        IntToStr(FThreadIdx))
    else
      iocp_log.WriteLog('TWorkThread.HandleIOData->异常断开：' +
                        PeerIPPort + ',Error:' +
                        IntToStr(FErrorCode) + ',WorkThread:' +
                        IntToStr(FThreadIdx));
  end else
  if (FByteCount = 0) then
    iocp_log.WriteLog('TWorkThread.HandleIOData->客户端关闭：' +
                      PeerIPPort + ',WorkThread:' + IntToStr(FThreadIdx))
  else
    case FPerIOData^.IOType of
      ioDelete:
        iocp_log.WriteLog('TWorkThread.HandleIOData->被删除：' +
                          PeerIPPort + ',WorkThread:' + IntToStr(FThreadIdx));
      ioTimeOut:
        iocp_log.WriteLog('TWorkThread.HandleIOData->超时退出：' +
                          PeerIPPort + ',WorkThread:' + IntToStr(FThreadIdx));
      ioRefuse:
        iocp_log.WriteLog('TWorkThread.HandleIOData->拒绝服务：' +
                          PeerIPPort + ',WorkThread:' + IntToStr(FThreadIdx));
    end;
end;

{ TWorkThreadPool }

procedure TWorkThreadPool.CalcTaskOut(PackCount, ByteCount: Integer);
begin
  // 统计 TransmitFile 模式输出流量
  windows.InterlockedIncrement(FSummary.PackOutCount);
  windows.InterlockedExchangeAdd(FSummary.ByteOutCount, ByteCount);

  // 数据包总数 +
  windows.InterlockedIncrement(FSummary.PackCount);

  // 字节总数 +
  windows.InterlockedExchangeAdd(FSummary.ByteCount, ByteCount);
end;

constructor TWorkThreadPool.Create(const AServer: TInIOCPServer);
var
  i, CPUCount: Integer;
  Thread: TWorkThread;
begin
  // 建工作线程

  FServer := AServer;
  CPUCount := GetCPUCount;

  // 统计概况、单个线程的统计信息
  FillChar(FSummary, SizeOf(TWorkThreadSummary), 0);
  FSummary.ThreadCount := FServer.FWorkThreadCount; // 工作线程数

  SetLength(FThreadAarry, FSummary.ThreadCount);

  for i := 0 to FSummary.ThreadCount - 1 do
  begin
    Thread := TWorkThread.Create(FServer);
    FThreadAarry[i] := Thread;

    Thread.FThreadIdx := i + 1;
    Thread.FSummary := @Self.FSummary;

    // 绑定 CPU
    windows.SetThreadIdealProcessor(Thread.Handle, i mod CPUCount);  // 0,1,2...
    Thread.Resume;
  end;

  {$IFNDEF DEBUG_MODE}
  iocp_log.WriteLog('TWorkThreadPool.Create->创建工作线程成功, 总数: ' + IntToStr(FSummary.ThreadCount));
  {$ENDIF}

end;

destructor TWorkThreadPool.Destroy;
begin
  // 停止工作线程
  if Length(FThreadAarry) > 0 then
    StopThreads;
  inherited;
end;

procedure TWorkThreadPool.GetThreadDetail(Index: Integer; const Detail: PWorkThreadDetail);
begin
  // 不加锁，统计数据未必与概况的一致
  if (Index >= 1) and (Index <= FSummary.ThreadCount) then  // > 0 的编号
    System.Move(FThreadAarry[Index - 1].FDetail, Detail^, SizeOf(TWorkThreadDetail));
end;

procedure TWorkThreadPool.GetThreadSummary(const Summary: PWorkThreadSummary);
begin
  // 计算每秒的速度（1秒钟读一次）, 读数据后清空
  System.Move(FSummary, Summary^, SizeOf(LongInt) * 3); // 前面 3 个
  Summary^.PackCount := windows.InterlockedExchange(FSummary.PackCount, 0);
  Summary^.PackInCount := windows.InterlockedExchange(FSummary.PackInCount, 0);
  Summary^.PackOutCount := windows.InterlockedExchange(FSummary.PackOutCount, 0);
  Summary^.ByteCount := windows.InterlockedExchange(FSummary.ByteCount, 0);
  Summary^.ByteInCount := windows.InterlockedExchange(FSummary.ByteInCount, 0);
  Summary^.ByteOutCount := windows.InterlockedExchange(FSummary.ByteOutCount, 0);
end;

procedure TWorkThreadPool.StopThreads;
begin
  // 服务器已经设为 Active := False

  // 停止工作线程
  while (FSummary.ThreadCount > 0) do
  begin
    FServer.FIOCPEngine.StopIoCompletionPort;  // 发送停止消息
    Sleep(20);
  end;

  {$IFNDEF DEBUG_MODE}
  iocp_log.WriteLog('TWorkThreadPool.StopThreads->停止工作线程成功, 总数: ' + IntToStr(Length(FThreadAarry)));
  {$ENDIF}

  // 在后
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
  // 建死连接客户端列表
  //   死连接：超时或接入后长期没接收过数据
  SocketPool.Lock;
  try
    CurrNode := SocketPool.FirstNode;  // 第一节点
    TickCount := GetTickCount;  // 当前时间
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
    // 1. 发超时退出消息给客户端
    for i := 0 to FSockets.Count - 1 do
      TBaseSocket(FSockets.Items[i]).PostEvent(ioTimeOut);
  end;
const
  MSECOND_COUNT = 30000;  // 接入 30 秒没数据传输就尝试断开
var
  i: Integer;
begin
  inherited;
  // 检查关闭死连接、优化资源使用

  FSemapHore := CreateSemapHore(Nil, 0, 1, Nil); // 信号灯

  i := 1;
  FWorktime := 0;
  FServer.FTimeoutChecking := True;

  while (Terminated = False) do
    try
      // 等待 MSECOND_COUNT 毫秒
      WaitForSingleObject(FSemapHore, MSECOND_COUNT);

//      Continue;       // 调试
      if Terminated then
        Break;

      // 建死连接列表，释放死连接
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
      if (Frac(FWorktime) > 0.00) and (Frac(FWorktime) < 0.08) then  // 0 - 2点
      begin
        case i of
          1..5: begin
            // 优化资源（连续多次资源多，使用少 -> 优化）
            OptimizePool(FServer.FSocketPool);
            if Assigned(FServer.FHttpSocketPool) then
              OptimizePool(FServer.FHttpSocketPool);
            if Assigned(FServer.FWebSocketPool) then
              OptimizePool(FServer.FWebSocketPool);
            OptimizePool(FServer.FIODataPool, FServer.BusinessThreadCount);
          end;
          30:  // 清理一次 Cookie
            FServer.InvalidSessions;
          40:  // 清除 IP 记录
            FServer.ClearIPList;
          50: begin  // 占用内存不断增长，整理一下
            i := 0;
            __ResetMMProc(FServer.FGlobalLock);
          end;
        end;
        Inc(i); // 次数 +
      end;
    except
      iocp_log.WriteLog('TTimeoutThread.ExecuteWork->' + GetSysErrorMessage);
    end;

  CloseHandle(FSemapHore);
  FServer.FTimeoutChecking := False;
  
end;

procedure TTimeoutThread.OptimizePool(ObjectPool: TObjectPool; Delta: Integer);
begin
  // 优化资源池
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
  ReleaseSemapHore(FSemapHore, 1, Nil);  // 信号量+1，触发 WaitForSingleObject
  while FServer.FTimeoutChecking do Sleep(10);
end;
  
end.
