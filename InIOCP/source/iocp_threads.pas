(*
 * iocp �ر��̡߳�ҵ���̡߳������̵߳�
 *)
unit iocp_threads;

interface

{$I in_iocp.inc}        // ģʽ����

uses
  Windows, Classes, SysUtils, ActiveX, 
  iocp_base, iocp_lists, iocp_objPools,
  iocp_winSock2, iocp_baseObjs, iocp_sockets,
  iocp_managers, iocp_msgPacks, iocp_senders;

type

  // ===================== ר�Źر� Socket ���߳� =====================

  TCloseSocketThread = class(TCycleThread)
  private
    FLock: TThreadLock;   // ��
    FSockets: TInList;    // ����ɾ�׽ڵ���б�
  protected
    procedure AfterWork; override;
    procedure DoMethod; override;
  public
    constructor Create;
    procedure AddSocket(const Socket: TObject);
    procedure WaitFor;    // ����
  end;

  // ===================== ִ��ҵ����߳� =====================

  TBusiWorkManager = class;

  TBusiThread = class(TCycleThread)
  private
    FManager: TBusiWorkManager; // ������
    FSender: TServerTaskSender; // �������������ã�
    FSocket: TBaseSocket;       // ��ǰ�׽��ֶ���
    FWorker: TBusiWorker;       // ����ִ���ߣ����ã�
  protected
    procedure AfterWork; override;
    procedure DoMethod; override;
  public
    constructor Create(AManager: TBusiWorkManager);
  end;

  // ===================== ҵ���̵߳��ȹ��� =====================

  TBusiWorkManager = class(TObject)
  private
    FSemaphore: THandle;         // �̹߳�����źŵ�

    // �߳�����
    FThreads: Array of TBusiThread;

    FThreadCount: Integer;       // �߳���
    FLock: TThreadLock;          // ��������

    FSockets: TInList;           // ����ɾ�׽ڵ�����б����ܴܺ�
    FBackSockets: TInList;       // �����б����ܴܺ���ɾ��ģʱ�ã�
    FCurrentList: TInList;       // ���� FSockets/FBackSockets

    FActiveCount: Integer;       // ���������
    FActiveThreadCount: Integer; // ��߳���

    function CreateWorker(Index: Integer): TBusiWorker;
    function GetDataModuleState(Index: Integer): Boolean;
    function GetWork(var Socket: TObject): Boolean;
    function GetWorkTotalCount: IOCP_LARGE_INTEGER;

    procedure InternalAddRemove(Index: Integer; AddMode: Boolean);
    procedure InternalStop;
  public
    constructor Create(AServer: TObject; AThreadCount: Integer);
    destructor Destroy; override;
    procedure AddWork(Socket: TObject; Activate: Boolean = True);
    procedure AddDataModule(Index: Integer);
    procedure RemoveDataModule(Index: Integer);
    procedure StopThreads;
    procedure WaitFor;
  public
    property ActiveCount: Integer read FActiveCount;
    property ActiveThreadCount: Integer read FActiveThreadCount;
    property DataModuleState[Index: Integer]: Boolean read GetDataModuleState;
    property WorkTotalCount: IOCP_LARGE_INTEGER read GetWorkTotalCount;
  end;

  // ===================== ���Ͷ���/���� =====================

  TPushMessage = class(TInList)
  private
    FPool: TIOCPSocketPool;     // �����
    FPushBuf: PPerIOData;       // ��������Ϣ
    FBroadcast: Boolean;        // �㲥ģʽ
    FClientCount: Integer;      // ���ƹ㲥Ŀ����
    FTickCount: Cardinal;       // ����ʱ�����
  public
    constructor Create(AOwner: TObject; IOKind: TIODataType; MsgSize: Cardinal); overload;
    constructor Create(Msg: PPerIOData; Broadcast: Boolean = False); overload;
    constructor Create(APool: TIOCPSocketPool; IOKind: TIODataType); overload;
    destructor Destroy; override;
  public
    property PushBuf: PPerIOData read FPushBuf;
  end;

  // ===================== ��Ϣ�����߳� =====================

  TPushMsgManager = class;

  TPushThread = class(TCycleThread)
  private
    FManager: TPushMsgManager;  // ������
    FMsg: TPushMessage;         // ��ǰ��������Ϣ
    FSocket: TBaseSocket;       // ��ǰ�׽��ֶ���
    procedure PushMesssage;
  protected
    procedure AfterWork; override;
    procedure DoMethod; override;
  public
    constructor Create(AManager: TPushMsgManager);
  end;

  // ===================== ������Ϣ����� =====================
  // 1. ����ʱ��ҵ���̣߳�Socket ��Դ��ռ�ã����ֱ��Ͷ��ʱ
  //    �����������߳�����������Դ�����������ù���
  // 2. �Ȱ���ϢͶ�ŵ�����أ�ÿ��һ��ʱ��������Ͷ��С�
  
  TMsgPushPool = class(TBaseThread)
  private
    FLock: TThreadLock;          // ��Ϣ��
    FManager: TPushMsgManager;   // ������
    FMsgList: TInList;           // ������Ϣ��
    procedure InterAdd(Msg: TPushMessage);
  protected
    procedure ExecuteWork; override;
  public
    constructor Create(AManager: TPushMsgManager);
    destructor Destroy; override;
  end;

  // ===================== ��Ϣ�����̹߳��� =====================

  TPushMsgManager = class(TObject)
  private
    FSemaphore: THandle;         // �߳��źŵ�
    FWaitSemaphore: THandle;     // �̵߳ȴ��źŵ�

    // �߳�����
    FThreads: array of TPushThread;
    FThreadCount: Integer;       // �߳���
    FLock: TThreadLock;          // ��������

    FPushPool: TMsgPushPool;     // ������Ϣ��
    FMsgList: TInList;           // ������Ϣ�б�

    FActiveCount: Integer;       // �����б�������
    FActiveThreadCount: Integer; // ��������߳���
    FPushMsgCount: Integer;      // ��Ϣ���������㣩

    // �ٶȿ���
    FMaxPushCount: Integer;      // ����ÿ�����������Ϣ��
    FNowTickCount: Cardinal;     // ��ǰ����ʱ��
    FTickCount: Cardinal;        // �ɵĺ���ʱ��
    FPushCountPS: Integer;       // ÿ��������Ϣ��

    function GetWork(var Msg: TPushMessage): Boolean;
    procedure ActivateThreads;
    procedure InterAdd(Msg: TPushMessage);
  public
    constructor Create(AThreadCount, AMaxPushCount: Integer);
    destructor Destroy; override;
    function AddWork(Msg: TPushMessage): Boolean;
    procedure StopThreads;
    procedure WaitFor;
  public
    property ActiveCount: Integer read FActiveCount;
    property ActiveThreadCount: Integer read FActiveThreadCount;
    property PushMsgCount: Integer read FPushMsgCount;
  end;

implementation

uses
  iocp_api, iocp_Server,
  iocp_log, iocp_utils, http_objects;

type
  TPushMsgSocket = class(TBaseSocket);

var
  FServer: TInIOCPServer = nil;  // ������
  FWorkTotalCount: IOCP_LARGE_INTEGER = 0;  // ��ִ�е���������

{ TCloseSocketThread }

procedure TCloseSocketThread.AddSocket(const Socket: TObject);
begin
  // ����ǰ�Ѿ���ȫ����
  FLock.Acquire;
  try
    FSockets.Add(Socket);
  finally
    FLock.Release;
  end;
  Activate;  // ����
end;

procedure TCloseSocketThread.AfterWork;
begin
  FLock.Free;
  FSockets.Free;  // �ͷŽڵ�ռ伴��, �����ɳ��ͷ�
end;

constructor TCloseSocketThread.Create;
begin
  inherited Create;
  FLock := TThreadLock.Create;
  FSockets := TInList.Create;
end;

procedure TCloseSocketThread.DoMethod;
var
  Socket: TBaseSocket;
begin
  while (Terminated = False) do
  begin
    FLock.Acquire;
    try
      Socket := FSockets.PopFirst;  // ȡ��һ����ɾ��
      if (Socket = nil) then
        Exit;
    finally
      FLock.Release;
    end;
    try
      Socket.Close;
    finally
      Socket.Pool.Push(Socket.LinkNode);
    end;
  end;
end;

procedure TCloseSocketThread.WaitFor;
begin
  // �ȴ�ȫ�� Socket �ر����
  while (FSockets.Count > 0) do
    Sleep(20);
end;

{ TBusiThread }

procedure TBusiThread.AfterWork;
begin
  // �����߳��� -1
  Windows.InterlockedDecrement(FManager.FThreadCount);
  FServer.IODataPool.Push(FSender.SendBuf^.Node);  // �ͷŷ��ͻ���
  FSender.Free;
end;

constructor TBusiThread.Create(AManager: TBusiWorkManager);
begin
  inherited Create(False);
  FManager := AManager;
  FSemaphore := FManager.FSemaphore;  // ����
  FSender := TServerTaskSender.Create;  // �� Socket ����
  FSender.SendBuf := FServer.IODataPool.Pop^.Data;
end;

procedure TBusiThread.DoMethod;
begin
  // ȡ�б��һ�� Socket��ִ��
  while (Terminated = False) and
         FManager.GetWork(TObject(FSocket)) do
    case FSocket.Lock(False) of  // ������������ģʽ

      SOCKET_LOCK_OK: begin  // �����ɹ�
        Windows.InterlockedIncrement(FManager.FActiveThreadCount);  // �ҵ���߳�+
        try
          FSocket.DoWork(FWorker, FSender)  // ���� FWorker, FSender
        finally
          Windows.InterlockedDecrement(FManager.FActiveThreadCount); // �ҵ���߳�-
          {$IFDEF WIN_64}
          System.AtomicIncrement(FWorkTotalCount);  // ִ������+
          {$ELSE}
          Windows.InterlockedIncrement(FWorkTotalCount);  // ִ������+
          {$ENDIF}
        end;
      end;

      SOCKET_LOCK_FAIL:  // �������ɹ������¼����б����´Σ�
        FManager.AddWork(FSocket, False);  // ������

      else
        { �Ѿ��ر�, ��������ڵ�� Socket } ;
    end;
end;

{ TBusiWorkManager }

procedure TBusiWorkManager.AddDataModule(Index: Integer);
begin
  // �½����Ϊ Index ����ģ��Ҫ��ע����ģ��
  InternalAddRemove(Index, True);
end;

procedure TBusiWorkManager.AddWork(Socket: TObject; Activate: Boolean);
begin
  // �����̵߳��ã�

  // 1. ����һ������
  FLock.Acquire;
  try
    FCurrentList.Add(Socket);
    if (FCurrentList = FSockets) then  // δ�ı��б�
      FActiveCount := FCurrentList.Count;
  finally
    FLock.Release;
  end;

  // 2. ����ҵ���̣߳�����ȡ����
  if Activate and (FCurrentList = FSockets) then  // �����б�
    ReleaseSemapHore(FSemaphore, 8, Nil);
end;

constructor TBusiWorkManager.Create(AServer: TObject; AThreadCount: Integer);
var
  i: Integer;
  Thread: TBusiThread;
begin
  inherited Create;

  // ÿ�������̶߳�Ӧһ������ҵ���̣߳�1:n��

  // 1. �����źŵƣ����ֵ = MaxInt
  FSemaphore := CreateSemapHore(Nil, 0, MaxInt, Nil);

  // 2. ��������ҵ���߳���
  FServer := TInIOCPServer(AServer);
  FThreadCount := AThreadCount;

  SetLength(FThreads, FThreadCount);

  // 3. ����Socket �б�
  FLock := TThreadLock.Create;

  FSockets := TInList.Create;        // ���б�
  FBackSockets := TInList.Create;    // �����б�
  FCurrentList := FSockets;          // �������б�

  // 4. ��ҵ���̡߳�����ִ����
  for i := 0 to FThreadCount - 1 do
  begin
    Thread := TBusiThread.Create(Self);
    Thread.FWorker := CreateWorker(i);
    FThreads[i] := Thread;
    Thread.Resume;
  end;

  // 5. ���� iocp_managers, iocp_sockets��http_base �ĵ�Ԫ����
  TBusiWorker.SetUnitVariables(Self);
  TBaseSocket.SetUnitVariables(AServer);
  THttpDataProvider.SetDataProvider(FServer.HttpDataProvider);

end;

function TBusiWorkManager.CreateWorker(Index: Integer): TBusiWorker;
begin
  // Ϊ�����߳̽�һ��ҵ������
  //   ��ģ�� DatabaseManager ������ TBusiThread.FWorker �ͷ�
  Result := TBusiWorker.Create(FServer, Index);
  Result.CreateDataModules;  // ��ʵ��
end;

destructor TBusiWorkManager.Destroy;
begin
  InternalStop;  // Ҫ�ȵȴ�ִ�����
  inherited;
end;

function TBusiWorkManager.GetDataModuleState(Index: Integer): Boolean;
begin
  // ������ģ�Ƿ���ʵ��
  Result := TBusiWorker(FThreads[0].FWorker).DataModules[Index] <> nil;
end;

function TBusiWorkManager.GetWork(var Socket: TObject): Boolean;
begin
  // �������������һ������
  FLock.Acquire;
  try
    Socket := FSockets.PopFirst;
    FActiveCount := FSockets.Count;
    Result := (Socket <> nil);
  finally
    FLock.Release;
  end;
end;

function TBusiWorkManager.GetWorkTotalCount: IOCP_LARGE_INTEGER;
begin
  // ȡ��ִ����
  Result := FWorkTotalCount;
end;

procedure TBusiWorkManager.InternalAddRemove(Index: Integer; AddMode: Boolean);
  procedure StartBackSocketList;
  begin
    // ���ñ��������б�洢����
    //  ��AddWork ������ҵ���̣߳�
    FLock.Acquire;
    try
      if (FCurrentList = FSockets) then
        FCurrentList := FBackSockets
      else
        FCurrentList := FSockets;
    finally
      FLock.Release;
    end;
  end;
  procedure SetMainSocketList;
  begin
    // �������������б���
    //  ��AddWork ����ҵ���̣߳�GetWork ���µ� FSockets ȡ����
    FLock.Acquire;
    try
      FCurrentList := FBackSockets;  // ��ǰ���ñ���
      FBackSockets := FSockets;      // �� -> ����
      FSockets := FCurrentList;      // ���� -> ��
    finally
      FLock.Release;
    end;
  end;
var
  i: Integer;
begin
  // ɾ�����½����Ϊ Index ����ģʵ��
  StartBackSocketList;
  try
    while (FActiveThreadCount > 0) do  // �Ȼ�߳�ִ�����
      Sleep(20);
    for i := 0 to FThreadCount - 1 do  // ��/ɾÿִ���ߵĶ�Ӧ��ģʵ��
      if AddMode then
        TBusiWorker(FThreads[i].FWorker).AddDataModule(Index)
      else
        TBusiWorker(FThreads[i].FWorker).RemoveDataModule(Index);
  finally
    SetMainSocketList;
  end;
end;

procedure TBusiWorkManager.InternalStop;
var
  i: Integer;
begin
  if Assigned(FLock) then
  begin
    for i := 0 to FThreadCount - 1 do // ֹͣ�߳�
    begin
      FThreads[i].FWorker.Free;  // FWorker �Զ��ͷ���ģ
      FThreads[i].Stop;
    end;

    while (FThreadCount > 0) do  // �ȴ�ȫ���߳��˳�
    begin
      ReleaseSemapHore(FSemaphore, 1, Nil);
      Sleep(20);
    end;

    SetLength(FThreads, 0);
    CloseHandle(FSemaphore);  // �ر�
    
    FLock.Free;
    FSockets.Free;
    FBackSockets.Free;

    FLock := Nil;
    FSockets := nil;
    FBackSockets := nil;

    // �嵥Ԫ����
    TBusiWorker.SetUnitVariables(nil);
    TBaseSocket.SetUnitVariables(nil);
    THttpDataProvider.SetDataProvider(nil);    
  end;
end;

procedure TBusiWorkManager.RemoveDataModule(Index: Integer);
begin
  // ɾ�����Ϊ Index ����ģʵ�������ı����� FThreads ���ȣ�
  InternalAddRemove(Index, False);
end;

procedure TBusiWorkManager.StopThreads;
begin
  InternalStop;
end;

procedure TBusiWorkManager.WaitFor;
begin
  // �ȴ���߳̽���
  while (FActiveThreadCount > 0) do
    Sleep(20);
end;

{ TPushMessage }

constructor TPushMessage.Create(Msg: PPerIOData; Broadcast: Boolean);
begin
  inherited Create;
  // ������Ϣ���б�Ŀͻ��ˣ���㲥
  FBroadcast := Broadcast;  // ��
  FTickCount := GetTickCount;  // ��ǰʱ��
  FPool := TBaseSocket(Msg^.Owner).Pool;

  FPushBuf := FServer.IODataPool.Pop^.Data;
  FPushBuf^.IOType := ioPush; // ����
  FPushBuf^.Data.len := Msg^.Overlapped.InternalHigh; // ��Ϣ��С
  
  // ���� Msg
  System.Move(Msg^.Data.buf^, FPushBuf^.Data.buf^, FPushBuf^.Data.len);
end;

constructor TPushMessage.Create(AOwner: TObject; IOKind: TIODataType; MsgSize: Cardinal);
begin
  inherited Create;
  // ��һ���� AOwner �� IOKind ������Ϣ���Ա��ⲿ������Ϣ����
  FBroadcast := False;
  FTickCount := GetTickCount;  // ��ǰʱ��
  FPool := TBaseSocket(AOwner).Pool;
  
  FPushBuf := FServer.IODataPool.Pop^.Data;

  FPushBuf^.IOType := IOKind; // ����
  FPushBuf^.Data.len := MsgSize;  // ���ݳ���

  inherited Add(AOwner); // ֻ��һ���ڵ�
end;

constructor TPushMessage.Create(APool: TIOCPSocketPool; IOKind: TIODataType);
begin
  inherited Create;
  // ��һ���㲥��Ϣ���ⲿ��������
  FBroadcast := True;
  FTickCount := GetTickCount;  // ��ǰʱ��
  FPool := APool;

  FPushBuf := FServer.IODataPool.Pop^.Data;

  FPushBuf^.IOType := IOKind; // ����
  FPushBuf^.Data.len := 0;  // ���ݳ���
end;

destructor TPushMessage.Destroy;
begin
  FServer.IODataPool.Push(FPushBuf^.Node);
  inherited;
end;

{ TPushThread }

procedure TPushThread.AfterWork;
begin
  // �����߳��� -1
  Windows.InterlockedDecrement(FManager.FThreadCount);
end;

constructor TPushThread.Create(AManager: TPushMsgManager);
begin
  inherited Create(False);
  FManager := AManager;
  FSemaphore := FManager.FSemaphore;  // ����
end;

procedure TPushThread.DoMethod;
var
  i: Integer;
  Trigger: Boolean;
begin
  // ���� TPushMessage.FPushBuf �� TPushMessage ���б��û�
  //   ֻҪû�ر� Socket��һ��Ҫ����һ��

  // ��������ҵ���߳��� Socket ��Դ����һ��
  WaitForSingleObject(FManager.FWaitSemaphore, 8);

  Trigger := False;
  while (Terminated = False) and FManager.GetWork(FMsg) do
  begin
    // 1. �㲥�������߿ͻ����б�
    if FMsg.FBroadcast then
    begin
      FMsg.FBroadcast := False;  // �´β��ü�
      FMsg.FPool.GetSockets(FMsg);
    end;

    // 2. ��һ����
    for i := 1 to FMsg.Count do
    begin
      FSocket := FMsg.PopFirst;  // ����Ŀ��
      FMsg.FPushBuf^.Owner := FSocket;
      if FSocket.Active then
        PushMesssage;
    end;

    // ��һ��
    WaitForSingleObject(FManager.FWaitSemaphore, 8);

    // 3. ������
    if (FMsg.Count > 0) then // δȫ������
    begin
      Trigger := True;
      FManager.InterAdd(FMsg);  // �ټ���
      Break;  // �´μ���
    end else
    begin
      Trigger := False;
      FMsg.Free;  // ȫ���������ͷ�
    end;
  end;

  if Trigger then
    FManager.ActivateThreads;
    
end;

procedure TPushThread.PushMesssage;
begin
  // ���� FMsg.FPushBuf �� FSocket
  case FSocket.Lock(True) of

    SOCKET_LOCK_OK: begin  // �����ɹ�
      // ������ͳ�Ƶ� FTotalCount
      Windows.InterlockedIncrement(FManager.FActiveThreadCount); // ������߳�+
      try
        TPushMsgSocket(FSocket).InternalPush(FMsg.FPushBuf); // ����
      finally
        Windows.InterlockedDecrement(FManager.FActiveThreadCount); // �ҵ���߳�-
        {$IFDEF WIN_64}
        System.AtomicIncrement(FWorkTotalCount);  // ִ������+
        {$ELSE}
        Windows.InterlockedIncrement(FWorkTotalCount);  // ִ������+
       {$ENDIF}
      end;
    end;

    SOCKET_LOCK_FAIL:  // ���ɹ�
      // ���� Socket ���ر����ٴδӳ�ȡ������ʱ����ԭ���Ŀͻ����ˣ�
      // ��������Ҳ��һ����㲥�Ŀͻ��ˣ����Խ��չ㲥��Ϣ��
      FMsg.Add(FSocket);  // ���¼��룬���´Σ�

    else
      { �Ѿ��ر�, ��������ڵ�� Socket } ;

  end;
end;

{ TMsgPushPool }

constructor TMsgPushPool.Create(AManager: TPushMsgManager);
begin
  inherited Create(True);
  FManager := AManager;
  FreeOnTerminate := True;  
  FLock := TThreadLock.Create;
  FMsgList := TInList.Create;
  Resume;
end;

destructor TMsgPushPool.Destroy;
var
  i: Integer;
begin
  for i := 0 to FMsgList.Count - 1 do
    TPushMessage(FMsgList.PopFirst).Free;
  FMsgList.Free;
  FLock.Free;
  // FManager ���߳�������-
  windows.InterlockedDecrement(FManager.FThreadCount);
  inherited;  
end;

procedure TMsgPushPool.ExecuteWork;
const
  MILLSECONDS_80 = 80;  // ������
var
  i: Integer;
  Trigger: Boolean;
  NowTickCount: Cardinal;
  Msg: TPushMessage;
  function GetTickCountDiff: Boolean;
  begin
    if (NowTickCount >= Msg.FTickCount) then
      Result := NowTickCount - Msg.FTickCount >= MILLSECONDS_80  // n ����
    else
      Result := High(Cardinal) - Msg.FTickCount + NowTickCount >= MILLSECONDS_80;
  end;
begin
  // ÿ n ����ѭ��һ�Σ�
  // �����е���Ϣ�Ƿ�ҪͶ�ŵ����Ͷ��С�
  while (Terminated = False) do
  begin
    Sleep(MILLSECONDS_80);  // �� n ����
    FLock.Acquire;
    try
      Trigger := False;
      NowTickCount := GetTickCount;
      for i := 1 to FMsgList.Count do
      begin
        Msg := FMsgList.PopFirst;
        if GetTickCountDiff then  // ʱ��� n ����
        begin
          FManager.InterAdd(Msg); // ��ʽ�������Ͷ���
          Trigger := True;
        end else
          FMsgList.Add(Msg);  // ���¼���
      end;
      if Trigger then  // ����
        FManager.ActivateThreads;
    finally
      FLock.Release;
    end;
  end;
end;

procedure TMsgPushPool.InterAdd(Msg: TPushMessage);
begin
  // ����Ϣ�ӵ������б�
  FLock.Acquire;
  try
    FMsgList.Add(Msg);
  finally
    FLock.Release;
  end;
end;

{ TPushMsgManager }

procedure TPushMsgManager.ActivateThreads;
var
  Trigger: Boolean;
begin
  // ���������߳�
  FLock.Acquire;
  try
    Trigger := (FMsgList.Count > 0); // ����Ϣ
  finally
    FLock.Release;
  end;
  if Trigger then
    ReleaseSemapHore(FSemaphore, 8, Nil);
end;

function TPushMsgManager.AddWork(Msg: TPushMessage): Boolean;
  function GetTickCountDiff: Boolean;
  begin
    if (FNowTickCount >= FTickCount) then
      Result := FNowTickCount - FTickCount >= 1000  // һ��
    else
      Result := High(Cardinal) - FTickCount + FNowTickCount >= 1000;
  end;
begin
  // ����һ��������Ϣ
  // �ٶȿ��ƣ�ÿ�������������� FMaxPushCount �Σ�������
  //           ������Ϣ�ѻ�ʱ��Ҳ������

  Result := True;
  FLock.Acquire;

  try
    if (FMaxPushCount > 0) then
    begin
      if (FPushMsgCount > FMaxPushCount div 5) then // ������Ϣ�ѻ��������豸���ܵ�����
        Result := False
      else begin
        FNowTickCount := GetTickCount;
        if GetTickCountDiff then  // ʱ�� 1 ��
        begin
          FTickCount := FNowTickCount;
          Result := (FPushCountPS <= FMaxPushCount); // û����
          FPushCountPS := 0;
        end;
      end;
    end;
    if Result then  // ͳ��
    begin
      // ���
      FActiveCount := FMsgList.Count;
      // ÿ��������Ϣ��
      Inc(FPushCountPS, Msg.FClientCount);
    end;
  finally
    FLock.Release;
  end;

  if Result then
    FPushPool.InterAdd(Msg)  // �ȼ����
  else // �ͷţ�������
    Msg.Free;

end;

constructor TPushMsgManager.Create(AThreadCount, AMaxPushCount: Integer);
var
  i: Integer;
begin
  inherited Create;

  // 1. �źŵƣ����ֵ = MaxInt
  FSemaphore := CreateSemapHore(Nil, 0, MaxInt, Nil);
  FWaitSemaphore := CreateSemapHore(Nil, 0, MaxInt, Nil);

  // 2. �����б�
  FLock := TThreadLock.Create;
  FPushPool := TMsgPushPool.Create(Self);  // ��Ϣ��
  FMsgList := TInList.Create;  // ������Ϣ�б�

  // 3. �����߳���������ÿ�����������
  FThreadCount := AThreadCount;
  FMaxPushCount := AMaxPushCount;

  SetLength(FThreads, FThreadCount);

  for i := 0 to High(FThreads) do
  begin
    FThreads[i] := TPushThread.Create(Self);
    FThreads[i].Resume;
  end;

  // 4. ���� FPushPool��ֹͣʱ���ͷ� FPushPool
  windows.InterlockedIncrement(FThreadCount);
end;

destructor TPushMsgManager.Destroy;
begin
  StopThreads;
  inherited;
end;

function TPushMsgManager.GetWork(var Msg: TPushMessage): Boolean;
begin
  // ȡһ��������Ϣ
  FLock.Acquire;
  try
    Msg := FMsgList.PopFirst;
    if (Msg = nil) then
    begin
      FActiveCount := 0;
      Result := False;
    end else
    begin
      FActiveCount := FMsgList.Count;
      Dec(FPushMsgCount, Msg.FClientCount);  // ��������-      
      Result := True;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TPushMsgManager.InterAdd(Msg: TPushMessage);
begin
  // ��ʽ����Ϣ�������Ͷ���
  FLock.Acquire;
  try
    // �����������
    if Msg.FBroadcast then
      Msg.FClientCount := Msg.FPool.UsedCount
    else
      Msg.FClientCount := 1;
    Inc(FPushMsgCount, Msg.FClientCount);
    FMsgList.Add(Msg);
  finally
    FLock.Release;
  end;
end;

procedure TPushMsgManager.StopThreads;
var
  i: Integer;
begin
  if Assigned(FLock) then
  begin
    // ���ͷ�
    FPushPool.Terminate;
    
    // ֹͣȫ�������߳�
    for i := 0 to High(FThreads) do
      FThreads[i].Stop;

    // �ȴ�ȫ���߳��˳�
    while (FThreadCount > 0) do
    begin
      ReleaseSemapHore(FSemaphore, 1, Nil);
      Sleep(20);
    end;

    SetLength(FThreads, 0);
    CloseHandle(FSemaphore);  // �ر�
    CloseHandle(FWaitSemaphore);  // �ر�

    // �ͷ�δ���͵���Ϣ�ռ�
    for i := 0 to FMsgList.Count - 1 do
      TPushMessage(FMsgList.PopFirst).Free;

    FMsgList.Free;
    FLock.Free;

    FPushPool := nil;
    FMsgList := nil;
    FLock := nil;
  end;
end;

procedure TPushMsgManager.WaitFor;
begin
  // �ȴ���߳̽���
  while (FActiveThreadCount > 0) do
    Sleep(20);
end;

end.
