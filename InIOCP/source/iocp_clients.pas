(*
 * iocp c/s ����ͻ��˶�����
 *)
unit iocp_clients;

interface

{$I in_iocp.inc}

uses
  Windows, Classes, SysUtils,
  ExtCtrls, Variants, DB, DSIntf, DBClient,
  iocp_Winsock2, iocp_base, iocp_utils,
  iocp_lists, iocp_senders, iocp_receivers,
  iocp_baseObjs, iocp_msgPacks, MidasLib;    // ʹ��ʱ��ӵ�Ԫ���� MidasLib��

type

  // =================== IOCP �ͻ��� �� ===================

  TSendThread   = class;
  TRecvThread   = class;
  TPostThread   = class;

  TClientParams = class;
  TResultParams = class;

  // ============ �ͻ������ ���� ============
  // ����ֱ��ʹ��

  // ���������¼�
  TPassvieEvent = procedure(Sender: TObject; Msg: TResultParams) of object;

  // ��������¼�
  TReturnEvent  = procedure(Sender: TObject; Result: TResultParams) of object;

  TBaseClientObject = class(TComponent)
  protected
    FOnReceiveMsg: TPassvieEvent;   // ����������Ϣ�¼�
    FOnReturnResult: TReturnEvent;  // ������ֵ�¼�
    procedure HandlePushedMsg(Msg: TResultParams); virtual;
    procedure HandleFeedback(Result: TResultParams); virtual;
  published
    property OnReturnResult: TReturnEvent read FOnReturnResult write FOnReturnResult;
  end;

  // ============ �ͻ������� ============

  // ���������¼�
  TAddWorkEvent    = procedure(Sender: TObject; Msg: TClientParams) of object;

  // ��Ϣ�շ��¼�
  TRecvSendEvent   = procedure(Sender: TObject; MsgId: TIOCPMsgId; MsgSize, CurrentSize: TFileSize) of object;

  // �쳣�¼�
  TConnectionError = procedure(Sender: TObject; const Msg: String) of object;
  
  TInConnection = class(TBaseClientObject)
  private
    FSocket: TSocket;          // �׽���
    FTimer: TTimer;            // ��ʱ��

    FSendThread: TSendThread;  // �����߳�
    FRecvThread: TRecvThread;  // �����߳�
    FPostThread: TPostThread;  // Ͷ���߳�
//    FCurrentThread: TThread;

    FRecvCount: Cardinal;      // ���յ�
    FSendCount: Cardinal;      // ������

    FLocalPath: String;        // �����ļ��ı��ش��·��
    FUserName: String;         // ��¼�û���������ã�
    FServerAddr: String;       // ��������ַ
    FServerPort: Word;         // ����˿�

    FActive: Boolean;          // ����/����״̬
    FActResult: TActionResult; // �������������
    FAutoConnect: Boolean;     // �Ƿ��Զ�����
    FCancelCount: Integer;     // ȡ��������
    FMaxChunkSize: Integer;    // ������ÿ������䳤��

    FErrorcode: Integer;       // �쳣����
    FErrMsg: String;           // �쳣��Ϣ

    FReuseSessionId: Boolean;  // ƾ֤���ã�������ʱ,�´����¼��
    FRole: TClientRole;        // Ȩ��
    FSessionId: Cardinal;      // ƾ֤/�Ի��� ID
  private
    FAfterConnect: TNotifyEvent;     // ���Ӻ�
    FAfterDisconnect: TNotifyEvent;  // �Ͽ���
    FBeforeConnect: TNotifyEvent;    // ����ǰ
    FBeforeDisconnect: TNotifyEvent; // �Ͽ�ǰ
    FOnAddWork: TAddWorkEvent;       // ���������¼�
    FOnDataReceive: TRecvSendEvent;  // ��Ϣ�����¼�
    FOnDataSend: TRecvSendEvent;     // ��Ϣ�����¼�
    FOnError: TConnectionError;      // �쳣�¼�
  private
    function GetActive: Boolean;  
    procedure CreateTimer;
    procedure DoServerError(Result: TResultParams);
    procedure DoThreadFatalError;
    procedure InternalOpen;
    procedure InternalClose;
    procedure ReceiveProgress;
    procedure SendProgress;
    procedure SetActive(Value: Boolean);
    procedure SetMaxChunkSize(Value: Integer);
    procedure TimerEvent(Sender: TObject);
    procedure TryDisconnect;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CancelAllWorks;                 // ȡ��ȫ������
    procedure CancelWork(MsgId: TIOCPMsgId);  // ȡ��ָ����Ϣ��ŵ�����
    procedure PauseWork(MsgId: TIOCPMsgId);   // ��ָͣ����Ϣ��ŵ�����
  public
    property ActResult: TActionResult read FActResult;
    property CancelCount: Integer read FCancelCount;
    property Errorcode: Integer read FErrorcode;
    property RecvCount: Cardinal read FRecvCount;
    property SendCount: Cardinal read FSendCount;
    property SessionId: Cardinal read FSessionId;
    property Socket: TSocket read FSocket;
    property UserName: String read FUserName;
  published
    property Active: Boolean read GetActive write SetActive default False;
    property AutoConnect: Boolean read FAutoConnect write FAutoConnect default False;
    property LocalPath: String read FLocalPath write FLocalPath;
    property MaxChunkSize: Integer read FMaxChunkSize write SetMaxChunkSize default MAX_CHUNK_SIZE;
    property ReuseSessionId: Boolean read FReuseSessionId write FReuseSessionId default False;
    property ServerAddr: String read FServerAddr write FServerAddr;
    property ServerPort: Word read FServerPort write FServerPort default DEFAULT_SVC_PORT;
  published
    property AfterConnect: TNotifyEvent read FAfterConnect write FAfterConnect;
    property AfterDisconnect: TNotifyEvent read FAfterDisconnect write FAfterDisconnect;
    property BeforeConnect: TNotifyEvent read FBeforeConnect write FBeforeConnect;
    property BeforeDisconnect: TNotifyEvent read FBeforeDisconnect write FBeforeDisconnect;

    property OnAddWork: TAddWorkEvent read FOnAddWork write FOnAddWork;
    
    // ���ձ�����Ϣ/������Ϣ�¼�
    property OnReceiveMsg: TPassvieEvent read FOnReceiveMsg write FOnReceiveMsg;

    property OnDataReceive: TRecvSendEvent read FOnDataReceive write FOnDataReceive;
    property OnDataSend: TRecvSendEvent read FOnDataSend write FOnDataSend;
    property OnError: TConnectionError read FOnError write FOnError;
  end;

  // ============ �ͻ����յ������ݰ�/������ ============

  TResultParams = class(TReceivePack)
  protected
    procedure CreateAttachment(const LocalPath: String); override;
  end;

  // ============ TInBaseClient ���õ���Ϣ�� ============

  TClientParams = class(TBaseMessage)
  private
    FConnection: TInConnection;  // ����
    FCancel: Boolean;            // ��ȡ��
  protected
    function ReadDownloadInf(AResult: TResultParams): Boolean;
    function ReadUploadInf(AResult: TResultParams): Boolean;
    procedure CreateStreams(ClearList: Boolean = True); override;
    procedure ModifyMessageId;
    procedure InterSetAction(AAction: TActionType);
    procedure InternalSend(AThread: TSendThread; ASender: TClientTaskSender);
    procedure OpenLocalFile; override;
  public
    // Э��ͷ����
    property Action: TActionType read FAction;
    property ActResult: TActionResult read FActResult;
    property AttachSize: TFileSize read FAttachSize;
    property CheckType: TDataCheckType read FCheckType write FCheckType;  // ��д
    property DataSize: Cardinal read FDataSize;
    property MsgId: TIOCPMsgId read FMsgId write FMsgId;  // �û������޸�
    property Owner: TMessageOwner read FOwner;
    property SessionId: Cardinal read FSessionId;
    property Target: TActionTarget read FTarget;
    property VarCount: Cardinal read FVarCount;
    property ZipLevel: TZipLevel read FZipLevel write FZipLevel;
  public
    // �����������ԣ���д��
    property Connection: Integer read GetConnection write SetConnection;
    property Directory: String read GetDirectory write SetDirectory;
    property FileName: String read GetFileName write SetFileName;
    property FunctionGroup: string read GetFunctionGroup write SetFunctionGroup;
    property FunctionIndex: Integer read GetFunctionIndex write SetFunctionIndex;
    property HasParams: Boolean read GetHasParams write SetHasParams;
    property NewFileName: String read GetNewFileName write SetNewFileName;
    property Password: String read GetPassword write SetPassword;
    property ReuseSessionId: Boolean read GetReuseSessionId write SetReuseSessionId;
    property StoredProcName: String read GetStoredProcName write SetStoredProcName;
    property SQL: String read GetSQL write SetSQL;
    property SQLName: String read GetSQLName write SetSQLName;
  end;

  // ============ �û����ɶ��巢�͵���Ϣ�� ============
  // ���� Get��Post ����
    
  TMessagePack = class(TClientParams)
  private
    FThread: TSendThread;        // �����߳�
    procedure InternalPost(AAction: TActionType);
  public
    constructor Create(AOwner: TBaseClientObject);
    procedure Post(AAction: TActionType);
  end;

  // ============ �ͻ������ ���� ============

  // �о��ļ��¼�
  TListFileEvent = procedure(Sender: TObject; ActResult: TActionResult;
                             No: Integer; Result: TCustomPack) of object;

  TInBaseClient = class(TBaseClientObject)
  private
    FParams: TClientParams;       // ��������Ϣ������Ҫֱ��ʹ�ã�
    FFileList: TStrings;          // ��ѯ�ļ����б�
    function CheckState(CheckLogIn: Boolean = True): Boolean;
    function GetParams: TClientParams;
    procedure InternalPost(Action: TActionType = atUnknown);
    procedure ListReturnFiles(Result: TResultParams);
    procedure SetConnection(const Value: TInConnection);
  protected
    FConnection: TInConnection;   // �ͻ�������
    FOnListFiles: TListFileEvent; // ��������Ϣ�ļ�
  protected
    property Connection: TInConnection read FConnection write SetConnection;
    property Params: TClientParams read GetParams;
  public
    destructor Destroy; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  end;

  // ============ ��Ӧ����ͻ��� ============

  TInEchoClient = class(TInBaseClient)
  public
    procedure Post;
  published
    property Connection;
  end;

  // ============ ��֤����ͻ��� ============

  // ��֤����¼�
  TCertifyEvent     = procedure(Sender: TObject; Action: TActionType;
                                ActResult: Boolean) of object;

  // �оٿͻ����¼�
  TListClientsEvent = procedure(Sender: TObject; Count, No: Cardinal;
                                const Client: PClientInfo) of object;

  TInCertifyClient = class(TInBaseClient)
  private
    FGroup: String;       // ���飨δ�ã�
    FUserName: String;    // ����
    FPassword: String;    // ����
    FLogined: Boolean;    // ��¼״̬
  private
    FOnCertify: TCertifyEvent;  // ��֤����¼/�ǳ����¼�
    FOnListClients: TListClientsEvent;  // ��ʾ�ͻ�����Ϣ
    function GetLogined: Boolean;
    procedure InterListClients(Result: TResultParams);
    procedure SetPassword(const Value: String);
    procedure SetUserName(const Value: String);
  protected
    procedure HandleMsgHead(Result: TResultParams);
    procedure HandleFeedback(Result: TResultParams); override;
  public
    procedure Register(const AUserName, APassword: String; Role: TClientRole = crClient);
    procedure GetUserState(const AUserName: String);
    procedure Modify(const AUserName, ANewPassword: String; Role: TClientRole = crClient);
    procedure Delete(const AUserName: String);
    procedure QueryClients;
    procedure Login;
    procedure Logout;
  public
    property Logined: Boolean read GetLogined;
  published
    property Connection;
    property Group: String read FGroup write FGroup;
    property UserName: String read FUserName write SetUserName;
    property Password: String read FPassword write SetPassword;
  published
    property OnCertify: TCertifyEvent read FOnCertify write FOnCertify;
    property OnListClients: TListClientsEvent read FOnListClients write FOnListClients;
  end;

  // ============ ��Ϣ����ͻ��� ============

  TInMessageClient = class(TInBaseClient)
  protected
    procedure HandleFeedback(Result: TResultParams); override;
  public
    procedure Broadcast(const Msg: String);
    procedure Get;
    procedure GetMsgFiles(FileList: TStrings = nil);
    procedure SendMsg(const Msg: String; const ToUserName: String = '');
  published
    property Connection;
    property OnListFiles: TListFileEvent read FOnListFiles write FOnListFiles;
  end;

  // ============ �ļ�����ͻ��� ============
  // 2.0 δʵ���ļ����ʹ���

  TInFileClient = class(TInBaseClient)
  private
    procedure InternalDownload(const AFileName: String; ATarget: TActionTarget);
  protected
    procedure HandleFeedback(Result: TResultParams); override;
  public
    procedure SetDir(const Directory: String);
    procedure ListFiles(FileList: TStrings = nil);
    procedure Delete(const AFileName: String);
    procedure Download(const AFileName: String);
    procedure Rename(const AFileName, ANewFileName: String);
    procedure Upload(const AFileName: String); overload;
    procedure Share(const AFileName: String; Groups: TStrings);
  published
    property Connection;
    property OnListFiles: TListFileEvent read FOnListFiles write FOnListFiles;
  end;

  // ============ ���ݿ����ӿͻ��� ============

  TInDBConnection = class(TInBaseClient)
  private
    FConnectionIndex: Integer;   // ���ӱ��
  public
    procedure GetConnections;
    procedure Connect(ANo: Cardinal);
  published
    property Connection;
    property ConnectionIndex: Integer read FConnectionIndex write FConnectionIndex;
  end;

  // ============ ���ݿ�ͻ��� ���� ============

  TDBBaseClientObject = class(TInBaseClient)
  private
    FDBConnection: TInDBConnection;  // ���ݿ�����
    procedure SetDBConnection(const Value: TInDBConnection);
  public
    procedure ExecStoredProc(const ProcName: String);
  public
    property Params;
  published
    property DBConnection: TInDBConnection read FDBConnection write SetDBConnection;
  end;

  // ============ SQL ����ͻ��� ============

  TInDBSQLClient = class(TDBBaseClientObject)
  public
    procedure ExecSQL;
  end;

  // ============ ���ݲ�ѯ�ͻ��� �� ============
 
  TInDBQueryClient = class(TDBBaseClientObject)
  private
    FClientDataSet: TClientDataSet;  // �������ݼ�
    FSubClientDataSets: TList;  // �����ӱ�
    FTableNames: TStrings; // Ҫ���µ�Զ�̱���
    FReadOnly: Boolean;    // �Ƿ�ֻ��
  protected
    procedure HandleFeedback(Result: TResultParams); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddClientDataSets(AClientDataSet: TClientDataSet);
    procedure ApplyUpdates;
    procedure ClearClientDataSets;
    procedure ExecQuery;
  public
    property ReadOnly: Boolean read FReadOnly;
  published
    property ClientDataSet: TClientDataSet read FClientDataSet write FClientDataSet;
  end;

  // ============ �Զ�����Ϣ�ͻ��� ============

  TInCustomClient = class(TInBaseClient)
  public
    procedure Post;
  public
    property Params;
  published
    property Connection;    
  end;

  // ============ Զ�̺����ͻ��� ============

  TInFunctionClient = class(TInBaseClient)
  public
    procedure Call(const GroupName: String; FunctionNo: Integer);
  public
    property Params;
  published
    property Connection;    
  end;

  // =================== �����߳� �� ===================

  TMsgIdArray = array of TIOCPMsgId;

  TSendThread = class(TCycleThread)
  private
    FConnection: TInConnection; // ����
    FLock: TThreadLock;         // �߳���
    FSender: TClientTaskSender; // ��Ϣ������

    FCancelIds: TMsgIdArray;    // ��ȡ������Ϣ�������
    FMsgList: TInList;          // ������Ϣ���б�
    FMsgPack: TClientParams;    // ��ǰ������Ϣ��

    FTotalSize: TFileSize;      // ��Ϣ�ܳ���
    FCurrentSize: TFileSize;    // ��ǰ������
    FBlockSemaphore: THandle;   // ����ģʽ�ĵȴ��źŵ�

    FGetFeedback: Integer;      // �յ�����������
    FWaitState: Integer;        // �ȴ�����״̬
    FWaitSemaphore: THandle;    // �ȴ��������������źŵ�

    function GetCount: Integer;
    function GetWork: Boolean;
    function GetWorkState: Boolean;
    function InCancelArray(MsgId: TIOCPMsgId): Boolean;

    procedure AddCancelMsgId(MsgId: TIOCPMsgId);
    procedure AfterSend(FirstPack: Boolean; OutSize: Integer);
    procedure ClearCancelMsgId(MsgId: TIOCPMsgId);    
    procedure ClearMsgList;
    procedure KeepWaiting;
    procedure IniWaitState;
    procedure OnSendError(Sender: TObject);
    procedure ServerReturn(ACancel: Boolean = False);
    procedure WaitForFeedback;
  protected
    procedure AfterWork; override;
    procedure DoMethod; override;
  public
    constructor Create(AConnection: TInConnection);
    procedure AddWork(Msg: TClientParams);
    function CancelWork(MsgId: TIOCPMsgId): Boolean;
    procedure ClearAllWorks(var ACount: Integer);
  public
    property Count: Integer read GetCount;
  end;

  // =================== ���ͽ�����߳� �� ===================
  // ������յ�����Ϣ���б���һ����Ӧ�ò�

  TPostThread = class(TCycleThread)
  private
    FConnection: TInConnection; // ����
    FLock: TThreadLock;         // �߳���

    FResults: TInList;          // �յ�����Ϣ�б�
    FResult: TResultParams;     // �յ��ĵ�ǰ��Ϣ
    FResultEx: TResultParams;   // �ȴ��������ͽ������Ϣ

    FMsgPack: TClientParams;    // ��ǰ������Ϣ
    FOwner: TBaseClientObject;  // ��ǰ������Ϣ������
    
    procedure ExecInMainThread;
    procedure HandleMessage(Result: TReceivePack);
  protected
    procedure AfterWork; override;
    procedure DoMethod; override;
  public
    constructor Create(AConnection: TInConnection);
    procedure Add(Result: TReceivePack);
    procedure SetMsgPack(MsgPack: TClientParams);
  end;

  // =================== �����߳� �� ===================

  TRecvThread = class(TThread)
  private
    FConnection: TInConnection; // ����
    FRecvBuf: TWsaBuf;          // ���ջ���
    FOverlapped: TOverlapped;   // �ص��ṹ

    FReceiver: TClientReceiver; // ���ݽ�����
    FRecvMsg: TReceivePack;     // ��ǰ��Ϣ

    FTotalSize: TFileSize;      // ��ǰ��Ϣ����
    FCurrentSize: TFileSize;    // ��ǰ��Ϣ�յ��ĳ���

    procedure HandleDataPacket; // �����յ������ݰ�
    procedure OnCheckCodeError(Result: TReceivePack);
    procedure OnReceive(Result: TReceivePack; RecvSize: Cardinal; Complete, Main: Boolean);
  protected
    procedure Execute; override;
  public
    constructor Create(AConnection: TInConnection);
    procedure Stop;
  end;

implementation

uses
  http_base, iocp_api, iocp_wsExt;

// var
//  ExtrMsg: TStrings;
//  FDebug: TStrings;
//  FStream: TMemoryStream;

{ TBaseClientObject }

procedure TBaseClientObject.HandleFeedback(Result: TResultParams);
begin
  // ������������ص���Ϣ
  if Assigned(FOnReturnResult) then
    FOnReturnResult(Self, Result);
end;

procedure TBaseClientObject.HandlePushedMsg(Msg: TResultParams);
begin
  // �ӵ�������Ϣ�������յ������ͻ�����Ϣ�� 
  if Assigned(FOnReceiveMsg) then
    FOnReceiveMsg(Self, Msg);
end;

{ TInConnection }

procedure TInConnection.CancelAllWorks;
begin
  // ȡ��ȫ������
  if Assigned(FSendThread) then
  begin
    FSendThread.ClearAllWorks(FCancelCount);
    FSendThread.Activate;
    if Assigned(FOnError) then
      FOnError(Self, 'ȡ�� ' + IntToStr(FCancelCount) + ' ������.');
  end;
end;

procedure TInConnection.CancelWork(MsgId: TIOCPMsgId);
var
  CancelOK: Boolean;
begin
  // ȡ��ָ����Ϣ�ŵ�����
  if Assigned(FSendThread) and (MsgId > 0) then
  begin
    CancelOK := FSendThread.CancelWork(MsgId);  // �ҷ����߳�
    if Assigned(FOnError) then
      if CancelOK then
        FOnError(Self, 'ȡ�����񣬱��: ' + IntToStr(MsgId))
      else
        FOnError(Self, '����δ��ȡ�������: ' + IntToStr(MsgId));
  end;
end;

constructor TInConnection.Create(AOwner: TComponent);
begin
  inherited;
  IniDateTimeFormat;

  FAutoConnect := False;  // ���Զ�����
  FMaxChunkSize := MAX_CHUNK_SIZE;
  FReuseSessionId := False;

  FSessionId := INI_SESSION_ID;  // ��ʼƾ֤
  FServerPort := DEFAULT_SVC_PORT;
  FSocket := INVALID_SOCKET;  // ��Ч Socket
end;

procedure TInConnection.CreateTimer;
begin
  // ����ʱ��
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 80;
  FTimer.OnTimer := TimerEvent;
end;

destructor TInConnection.Destroy;
begin
  SetActive(False);
  inherited;
end;

procedure TInConnection.DoServerError(Result: TResultParams);
begin
  // �յ��쳣���ݣ������쳣
  //  �������̵߳���ִ�У���ʱͨѶ�������ģ�
  try
    FActResult := Result.ActResult;
    if Assigned(FOnError) then
      case FActResult of
        arOutDate:
          FOnError(Self, '��������ƾ֤/��֤����.');
        arDeleted:
          FOnError(Self, '����������ǰ�û�������Աɾ�����Ͽ�����.');
        arRefuse:
          FOnError(Self, '���������ܾ����񣬶Ͽ�����.');
        arTimeOut:
          FOnError(Self, '����������ʱ�˳����Ͽ�����.');
        arErrAnalyse:
          FOnError(Self, '�����������������쳣.');
        arErrBusy:
          FOnError(Self, '��������ϵͳ��æ����������.');        
        arErrHash:
          FOnError(Self, '��������У���쳣.');
        arErrHashEx:
          FOnError(Self, '�ͻ��ˣ�У���쳣.');
        arErrInit:  // �յ��쳣����
          FOnError(Self, '�ͻ��ˣ����ճ�ʼ���쳣���Ͽ�����.');
        arErrPush:
          FOnError(Self, '��������������Ϣ�쳣.');
        arErrUser:  // ������ SessionId �ķ���
          FOnError(Self, '���������û�δ��¼��Ƿ�.');
        arErrWork:  // �����ִ�������쳣
          FOnError(Self, '��������' + Result.ErrMsg);
      end;
  finally
    if (FActResult in [arDeleted, arRefuse, arTimeOut, arErrInit]) then
      FTimer.Enabled := True;  // �Զ��Ͽ�
  end;
end;

procedure TInConnection.DoThreadFatalError;
begin
  // �շ�ʱ���������쳣/ֹͣ
  try
    if Assigned(FOnError) then
      if (FActResult = arErrNoAnswer) then
        FOnError(Self, '�ͻ��ˣ���������Ӧ��.')
      else
      if (FErrorCode > 0) then
        FOnError(Self, '�ͻ��ˣ�' + GetWSAErrorMessage(FErrorCode))
      else
      if (FErrorCode = -1) then
        FOnError(Self, '�ͻ��ˣ������쳣.')
      else
      if (FErrorCode = -2) then  // �������
        FOnError(Self, '�ͻ��ˣ��û�ȡ������.')
      else
        FOnError(Self, '�ͻ��ˣ�' + FErrMsg);
  finally
    if not FSendThread.FSender.Stoped then
      FTimer.Enabled := True;  // �Զ��Ͽ�
  end;
end;

function TInConnection.GetActive: Boolean;
begin
  if (csDesigning in ComponentState) or (csLoading in ComponentState) then
    Result := FActive
  else
    Result := (FSocket <> INVALID_SOCKET) and FActive;
end;

procedure TInConnection.InternalClose;
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

      // �����ӣ�����ƾ֤���´����¼
      if not FReuseSessionId then
        FSessionId := INI_SESSION_ID;

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
        FSendThread.Stop;
        FSendThread.FSender.Stoped := True;
        FSendThread.ServerReturn(True);
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

procedure TInConnection.InternalOpen;
begin
  // ���� WSASocket�����ӵ�������
  if Assigned(FBeforeConnect) then
    FBeforeConnect(Self);

  if (FSocket = INVALID_SOCKET) then
  begin
    // �½� Socket
    FSocket := WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, nil, 0, WSA_FLAG_OVERLAPPED);

    // ��������
    FActive := iocp_utils.ConnectSocket(FSocket, FServerAddr, FServerPort);

    if FActive then  // ���ӳɹ�
    begin
      // ��ʱ��
      CreateTimer;

      // ����
      iocp_wsExt.SetKeepAlive(FSocket);

      // ���̷��� IOCP_SOCKET_FLAG�������תΪ TIOCPSocet
      iocp_Winsock2.Send(FSocket, IOCP_SOCKET_FLAG[1], IOCP_SOCKET_FLEN, 0);

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

procedure TInConnection.Loaded;
begin
  inherited;
  // װ�غ�FActive -> ��  
  if FActive and not (csDesigning in ComponentState) then
    InternalOpen;
end;

procedure TInConnection.PauseWork(MsgId: TIOCPMsgId);
begin
  // ��ָͣ����Ϣ��ŵ�����
  // û��ʵ���Ե���ͣ������ᱻȡ��
  CancelWork(MsgId);
end;

procedure TInConnection.ReceiveProgress;
begin
  // ��ʾ���ս���
  if Assigned(FOnDataReceive) then
    FOnDataReceive(Self,
                   FRecvThread.FRecvMsg.MsgId,
                   FRecvThread.FTotalSize,
                   FRecvThread.FCurrentSize);
end;

procedure TInConnection.SendProgress;
begin
  // ��ʾ���ͽ��̣����塢������һ�� 100%��
  if Assigned(FOnDataSend) then  // �� FMsgSize
    FOnDataSend(Self,
                FSendThread.FMsgPack.FMsgId,
                FSendThread.FTotalSize,
                FSendThread.FCurrentSize);
end;

procedure TInConnection.SetActive(Value: Boolean);
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

procedure TInConnection.SetMaxChunkSize(Value: Integer);
begin
  if (Value > 65536) then
    FMaxChunkSize := Value
  else
    FMaxChunkSize := MAX_CHUNK_SIZE div 2;
end;

procedure TInConnection.TimerEvent(Sender: TObject);
begin
  // ��ɾ������ʱ���ܾ�����ȴ���
  FTimer.Enabled := False;
  InternalClose;  // �Ͽ�����
end;

procedure TInConnection.TryDisconnect;
begin
  // �������ر�ʱ�����Թرտͻ��� 
  if Assigned(FTimer) then
  begin
    FTimer.OnTimer := TimerEvent;
    FTimer.Enabled := True;
  end;
end;

{ TResultParams }

procedure TResultParams.CreateAttachment(const LocalPath: String);
var
  Msg: TCustomPack;
  MsgFileName: String;
begin
  // �ȼ�鱾�������ļ�(�汾��ͬ��ɾ��)
  
  if (FAction = atFileDownChunk) then
  begin
    // ����Ϣ�ļ�
    MsgFileName := LocalPath + FileName + '.download';

    Msg := TCustomPack.Create;
    Msg.Initialize(MsgFileName);

    try
      if (Msg.AsInt64['_FileSize'] > 0) and (
         (Msg.AsInt64['_FileSize'] <> GetFileSize) or
         (Msg.AsCardinal['_modifyLow'] <> AsCardinal['_modifyLow']) or
         (Msg.AsCardinal['_modifyHigh'] <> AsCardinal['_modifyHigh'])) then
      begin
        // �жϵ���Ϣ���������ļ��ĳ��ȡ��޸�ʱ��ı䣬ɾ��
        FOffset := 0;  // �´δ� 0 ��ʼ����
        FOffsetEnd := 0;
        DeleteFile(LocalPath + Msg.AsString['_AttachFileName']);
      end;

      Msg.AsInt64['_Offset'] := FOffset;
      Msg.AsInt64['_OffsetEnd'] := FOffsetEnd;

      Msg.AsInt64['_FileSize'] := GetFileSize;
      Msg.AsCardinal['_modifyLow'] := AsCardinal['_modifyLow'];
      Msg.AsCardinal['_modifyHigh'] := AsCardinal['_modifyHigh'];
      Msg.AsString['_AttachPath'] := GetAttachPath;
      
      // �ļ�����
      SetLocalFileName(Msg.AsString['_AttachFileName']);

      Msg.SaveToFile(MsgFileName);  // �����ļ�
    finally
      Msg.Free;
    end;
  end;

  inherited;
end;

{ TClientParams }

procedure TClientParams.InternalSend(AThread: TSendThread; ASender: TClientTaskSender);
  procedure SendMsgHeader;
  begin
    // ׼���ȴ�
    AThread.IniWaitState;

    // ������Ϣ�ܳ���
    AThread.FTotalSize := GetMsgSize(False);

    // ����Э��ͷ+У����+�ļ�����
    LoadHead(ASender.Data);
    ASender.SendBuffers;
  end;
  procedure SendAttachmentStream;
  begin
    // ���͸�������(���ر���Դ)
    AThread.IniWaitState;  // ׼���ȴ�
    if (FAction = atFileUpChunk) then  // �ϵ�����
      ASender.Send(FAttachment, FAttachSize, FOffset, FOffsetEnd, False)
    else
      ASender.Send(FAttachment, FAttachSize, False);
  end;
begin
  // ִ�з�������, �����˷�������
  //   ����TReturnResult.ReturnResult��TDataReceiver.Prepare

  // ASender.Socket �Ѿ�����
  ASender.Owner := Self;  // ����
  FSessionId := FConnection.FSessionId; // ��¼ƾ֤

  try
    // 1. ׼��������
    CreateStreams(False);  // ���������

    if not Error then
    begin
      // 2. ��Э��ͷ
      SendMsgHeader;

      // 3. �������ݣ��ڴ�����
      if (FDataSize > 0) then 
        ASender.Send(FMain, FDataSize, False);  // ���ر���Դ

      // 4. �ȴ�����
      if AThread.GetWorkState then
        AThread.WaitForFeedback;

      // 5. ���͸�������
      if (FAttachSize > 0) then
        if (FActResult = arAccept) then
        begin
          SendAttachmentStream;  // 5.1 ����
          if AThread.GetWorkState then
            AThread.WaitForFeedback;  // 5.2 �ȴ�����
        end;
    end;
  finally
    NilStreams(True);  // 6. ��գ��ͷŸ�����
  end;
end;

procedure TClientParams.InterSetAction(AAction: TActionType);
begin
  // ������Ϣʱ����Ŀ�� FTarget ֵ
  FAction := AAction;
  case FAction  of
    atTextPush,
    atFileRequest,
    atFileSendTo:
      FTarget := SINGLE_CLIENT;
    atTextBroadcast: 
      FTarget := ALL_CLIENT_SOCKET;
  end;
end;

function TClientParams.ReadDownloadInf(AResult: TResultParams): Boolean;
var
  Msg: TCustomPack;
  MsgFileName: String;
begin
  // ��/�½��ϵ�������Ϣ��ÿ������һ�飩

  // ��Ϣ�ļ���·�� FConnection.FLocalPath
  MsgFileName := FConnection.FLocalPath + FileName + '.download';
  Result := True;

  Msg := TCustomPack.Create;
  Msg.Initialize(MsgFileName);

  try
    if (Msg.Count = 0) then
    begin
      // ��һ������
      FOffset := 0;
      FOffsetEnd := FConnection.FMaxChunkSize;

      Msg.AsInt64['_MsgId'] := FMsgId;
      Msg.AsInt64['_Offset'] := 0;
      Msg.AsInt64['_OffsetEnd'] := FOffsetEnd;
      Msg.AsString['_AttachFileName'] := FileName + '_����ʹ��' +
                                         IntToStr(GetTickCount) + '.chunk';
    end else
    begin
      if (FActResult = arOK) then  // �ƽ�λ�ƣ��������س��� = FOffsetEnd
        FOffset := Msg.AsInt64['_OffsetEnd'] + 1
      else  // �쳣����������
        FOffset := Msg.AsInt64['_Offset'];  
      FOffsetEnd := FConnection.FMaxChunkSize;
      SetAttachPath(Msg.AsString['_AttachPath']);
      if (FOffset >= Msg.AsInt64['_fileSize']) then
        Result := False;  // �������
    end;
    
    // ���洫����Ϣ
    if Result then
      Msg.SaveToFile(MsgFileName)
    else
      DeleteFile(MsgFileName);
  finally
    Msg.Free;
  end;

end;

function TClientParams.ReadUploadInf(AResult: TResultParams): Boolean;
var
  Msg: TCustomPack;
  MsgFileName, ServerFileName: String;
begin
  // ��/�½��ϵ��ϴ���Ϣ��ÿ���ϴ�һ�飩

  // ��֧��������������
  if (FAttachFileName = '') then
  begin
    Clear;
    FAction := atUnknown;
    Result := False;
    Exit;
  end;

  MsgFileName := FAttachFileName + '.upload';

  Msg := TCustomPack.Create;
  Msg.Initialize(MsgFileName);

  try
    if (Msg.Count = 0) or
       (Msg.AsInt64['_FileSize'] <> AsInt64['_FileSize']) or
       (Msg.AsCardinal['_modifyLow'] <> AsCardinal['_modifyLow']) or
       (Msg.AsCardinal['_modifyHigh'] <> AsCardinal['_modifyHigh']) then
    begin
      // ��һ�η��ͻ��߱����ļ� FAttachFileName �ĳ��ȡ��޸�ʱ��ı�
      // ָ������˵Ķ�Ӧ�ļ�
      FOffset := 0;
      Msg.AsInt64['_MsgId'] := FMsgId;
      ServerFileName := FileName + '_����ʹ��' + IntToStr(GetTickCount) + '.chunk';
      Msg.AsString['_AttachFileName'] := ServerFileName;
      SetLocalFileName(ServerFileName);
    end else
    begin
      // ȡ����λ��
      if (FActResult <> arOK) then  // �쳣�Ͽ�����У�����쳣 -> ��Χ����
        FOffset := Msg.AsInt64['_Offset']
      else
      if AResult.GetNewCreatedFile then  // �������������½��ļ�
        FOffset := 0
      else  // ���������� arOK
        FOffset := Msg.AsInt64['_OffsetEnd'] + 1;
      FMsgId := Msg.AsInt64['_MsgId'];
      SetLocalFileName(Msg.AsString['_AttachFileName']);
    end;

    // �����ϴ���Χ��FOffset ... FOffset + x
    if (FOffset >= FAttachSize) then  // �������
    begin
      Result := False;
      DeleteFile(MsgFileName);  // ɾ����Դ�ļ�
    end else
    begin
      // �������䷶Χ
      AdjustTransmitRange(FConnection.FMaxChunkSize);

      Msg.AsInt64['_Offset'] := FOffset;
      Msg.AsInt64['_OffsetEnd'] := FOffsetEnd;

      // �ļ���Ϣ
      Msg.AsInt64['_FileSize'] := AsInt64['_FileSize'];
      Msg.AsCardinal['_modifyLow'] := AsCardinal['_modifyLow'];
      Msg.AsCardinal['_modifyHigh'] := AsCardinal['_modifyHigh'];

      if Assigned(AResult) then
      begin
        SetAttachPath(AResult.GetAttachPath);  // ����˴��·�����Ѽ���
        Msg.AsString['_AttachPath'] := AResult.GetAttachPath;
      end else // ��һ��Ϊ��
        SetAttachPath(Msg.AsString['_AttachPath']);

      Msg.SaveToFile(MsgFileName);  // ���洫����Ϣ
      Result := True;
    end;

  finally
    Msg.Free;
  end;
  
end;

procedure TClientParams.CreateStreams(ClearList: Boolean);
begin
  // ��顢�����ϵ����ط�Χ
  if (FileName <> '') and
     (FAction = atFileDownChunk) and (FActResult = arUnknown) then
    ReadDownloadInf(nil);
  inherited;
end;

procedure TClientParams.ModifyMessageId;
var
  Msg: TCustomPack;
  MsgFileName: String;
begin
  // ʹ��������Ϣ�ļ��� MsgId
  if (FAction = atFileDownChunk) then
    MsgFileName := FileName + '.download'
  else
    MsgFileName := FAttachFileName + '.upload';

  if FileExists(MsgFileName) then
  begin
    Msg := TCustomPack.Create;
    try
      Msg.Initialize(MsgFileName);
      FMsgId := Msg.AsInt64['_msgId'];
    finally
      Msg.Free;
    end;
  end;
end;

procedure TClientParams.OpenLocalFile;
begin
  inherited;
  if Assigned(FAttachment) and
    (FAction = atFileUpChunk) and (FActResult = arUnknown) then
    ReadUploadInf(nil);
end;

{ TMessagePack }

constructor TMessagePack.Create(AOwner: TBaseClientObject);
begin
  if (AOwner = nil) then  // ����Ϊ nil
    raise Exception.Create('��Ϣ Owner ����Ϊ��.');
  inherited Create(AOwner);
  if (AOwner is TInConnection) then
    FConnection := TInConnection(AOwner)
  else
  if (AOwner is TInBaseClient) then
    FConnection := TInBaseClient(AOwner).FConnection;
  if Assigned(FConnection) then
  begin
    UserName := FConnection.FUserName;  // Ĭ�ϼ����û���
    FThread := FConnection.FSendThread;
  end;
end;

procedure TMessagePack.InternalPost(AAction: TActionType);
var
  sErrMsg: String;
begin
  if Assigned(FThread) then
  begin
    InterSetAction(AAction); // ����
    if (FTarget > 0) and (Size > BROADCAST_MAX_SIZE) then
      sErrMsg := '���͵���Ϣ̫��.'
    else
    if Error then
      sErrMsg := '���ñ����쳣.'
    else
      FThread.AddWork(Self); // �ύ��Ϣ
  end else
    sErrMsg := 'δ���ӵ�������.';

  if (sErrMsg <> '') then
    try
      if Assigned(FConnection.FOnError) then
        FConnection.FOnError(Self, sErrMsg)
      else
        raise Exception.Create(sErrMsg);
    finally
      Free;
    end;
end;

procedure TMessagePack.Post(AAction: TActionType);
begin
  InternalPost(AAction);  // �ύ��Ϣ
end;

{ TInBaseClient }

function TInBaseClient.CheckState(CheckLogIn: Boolean): Boolean;
var
  Error: String;
begin
  // ������״̬
  if Assigned(FParams) and FParams.Error then  // �쳣
    Error := '�������ñ����쳣.'
  else
  if not Assigned(FConnection) then
    Error := '����δָ���ͻ�������.'
  else
  if not FConnection.Active then
  begin
    if FConnection.FAutoConnect then
      FConnection.InternalOpen
    else
      Error := '����δ���ӷ�����.';
  end else
  if CheckLogIn and (FConnection.FSessionId = 0) then
    Error := '���󣺿ͻ���δ��¼.';

  if (Error = '') then
    Result := not CheckLogIn or (FConnection.FSessionId > 0)
  else begin
    Result := False;
    if Assigned(FParams) then
      FreeAndNil(FParams);
    if Assigned(FConnection.FOnError) then
      FConnection.FOnError(Self, Error)
    else
      raise Exception.Create(Error);
  end;

end;

destructor TInBaseClient.Destroy;
begin
  if Assigned(FParams) then
    FParams.Free;
  inherited;
end;

function TInBaseClient.GetParams: TClientParams;
begin
  // ��̬��һ����Ϣ�������ͺ��� FParams = nil
  //    ��һ�ε���ʱҪ���� Params ��ʵ������Ҫ�� FParams��
  if not Assigned(FParams) then   
    FParams := TClientParams.Create(Self);
  if Assigned(FConnection) then
  begin
    FParams.FConnection := FConnection;
    FParams.FSessionId := FConnection.FSessionId;
    FParams.UserName := FConnection.FUserName;  // Ĭ�ϼ����û���
  end;
  Result := FParams;
end;

procedure TInBaseClient.InternalPost(Action: TActionType);
begin
  // ����Ϣ�������߳�
  if Assigned(FParams) then
    try
      if (Action <> atUnknown) then // ���ò���
        FParams.InterSetAction(Action);
      FConnection.FSendThread.AddWork(FParams);
    finally
      FParams := Nil;  // ���
    end;
end;

procedure TInBaseClient.ListReturnFiles(Result: TResultParams);
 var
  i: Integer;
  RecValues: TBasePack;
begin
  // �г��ļ�����
  case Result.ActResult of
    arFail:        // Ŀ¼������
      if Assigned(FOnListFiles) then
        FOnListFiles(Self, arFail, 0, Nil);
    arEmpty:       // Ŀ¼Ϊ��
      if Assigned(FOnListFiles) then
        FOnListFiles(Self, arEmpty, 0, Nil);
    else
      try          // �г��ļ���һ���ļ�һ����¼
        try
          for i := 1 to Result.Count do
          begin
            RecValues := Result.AsRecord[IntToStr(i)];
            if Assigned(RecValues) then
              try
                if Assigned(FFileList) then // ���浽�б�
                  FFileList.Add(TCustomPack(RecValues).AsString['name'])
                else
                if Assigned(FOnListFiles) then
                  FOnListFiles(Self, arExists, i, TCustomPack(RecValues));
              finally
                RecValues.Free;
              end;
          end;
        finally
          if Assigned(FFileList) then
            FFileList := nil; 
        end;
      except
        if Assigned(FConnection.FOnError) then
          FConnection.FOnError(Self, 'TInBaseClient.ListReturnFiles�����쳣.');
      end;
  end;
end;

procedure TInBaseClient.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (AComponent = FConnection) and (operation = opRemove) then
    FConnection := nil;  // ������ TInConnection �����ɾ��
end;

procedure TInBaseClient.SetConnection(const Value: TInConnection);
begin
  // �����������
  if Assigned(FConnection) then
    FConnection.RemoveFreeNotification(Self);
  FConnection := Value; // ��ֵ
  if Assigned(FConnection) then
    FConnection.FreeNotification(Self);
end;

{ TInEchoClient }

procedure TInEchoClient.Post;
begin
  if CheckState(False) then  // ���õ�¼
    if Assigned(Params) then // Ĭ��Ϊ��Ӧ
      InternalPost;
end;

{ TInCertifyClient }

procedure TInCertifyClient.Delete(const AUserName: String);
begin
  // ɾ���û�
  if CheckState() then
  begin
    Params.ToUser := AUserName;  // ��ɾ���û�
    InternalPost(atUserDelete);  // ɾ���û�
  end;
end;

function TInCertifyClient.GetLogined: Boolean;
begin
  // ȡ��¼״̬
  if Assigned(FConnection) and (FConnection.FSessionId > 0) then
    Result := FLogined
  else
    Result := False;
end;

procedure TInCertifyClient.GetUserState(const AUserName: String);
begin
  // ��ѯ�û�״̬
  if CheckState() then
  begin
    Params.ToUser := AUserName; // 2.0 ��
    InternalPost(atUserState);
  end;
end;

procedure TInCertifyClient.HandleMsgHead(Result: TResultParams);
begin
  // �����¼���ǳ����
  case Result.Action of
    atUserLogin: begin  // SessionId > 0 ���ɹ�
      FConnection.FSessionId := Result.SessionId;
      FConnection.FRole := Result.Role;
      FLogined := (FConnection.FSessionId > INI_SESSION_ID);
      if FLogined then  // �Ǽǵ�����
      begin
        if (FUserName = '') then
          FUserName := Result.UserName;
        FConnection.FUserName := FUserName;
      end;
      if Assigned(FOnCertify) then
        FOnCertify(Self, atUserLogin, FLogined);
    end;
    atUserLogout: begin
      // �����ӣ�����ƾ֤ʱ -> ���� FSessionId
      if not FConnection.FReuseSessionId then
      begin
        FConnection.FSessionId := INI_SESSION_ID;
        FConnection.FRole := crUnknown;
      end;
      FLogined := False;
      FConnection.FUserName := '';
      if Assigned(FOnCertify) then
        FOnCertify(Self, atUserLogout, True);
    end;
  end;         
end;

procedure TInCertifyClient.InterListClients(Result: TResultParams);
var
  i, k, iCount: Integer;
  Buf, Buf2: TMemBuffer;
begin
  // �г��ͻ�����Ϣ 
  try
    // TMemoryStream(Stream).SaveToFile('clients.txt');
    for i := 1 to Result.AsInteger['group'] do
    begin
      // ������ TMemBuffer
      Buf := Result.AsBuffer['list_' + IntToStr(i)];
      iCount := Result.AsInteger['count_' + IntToStr(i)];
      if Assigned(Buf) then
        try
          Buf2 := Buf;
          for k := 1 to iCount do  // �����ڴ��
          begin
            FOnListClients(Self, iCount, k, PClientInfo(Buf2));
            Inc(PAnsiChar(Buf2), CLIENT_DATA_SIZE);
          end;
        finally
          FreeBuffer(Buf);  // Ҫ��ʽ�ͷ�
        end;
    end;
  except
    on E: Exception do
    begin
      if Assigned(FConnection.FOnError) then
        FConnection.FOnError(Self, 'TInCertifyClient.InterListClients, ' + E.Message);
    end;
  end;
end;

procedure TInCertifyClient.HandleFeedback(Result: TResultParams);
begin
  try
    case Result.Action of
      atUserLogin, atUserLogout:  // 1. �����¼���ǳ�
        HandleMsgHead(Result);
      atUserQuery:  // 2. ��ʾ���߿ͻ��ĵĲ�ѯ���
        if Assigned(FOnListClients) then
          InterListClients(Result);
    end;
  finally
    inherited HandleFeedback(Result);
  end;
end;

procedure TInCertifyClient.Login;
begin
  // ��¼
  if CheckState(False) then  // ���ü���¼״̬
  begin
    Params.UserName := FUserName;  
    FParams.Password := FPassword;
    FParams.ReuseSessionId := FConnection.ReuseSessionId;
    InternalPost(atUserLogin);;
  end;
end;

procedure TInCertifyClient.Logout;
begin
  // �ǳ�
  if CheckState() and Assigned(Params) then
  begin
    FConnection.FSendThread.ClearAllWorks(FConnection.FCancelCount); // ���������
    InternalPost(atUserLogout);
  end;
end;

procedure TInCertifyClient.Modify(const AUserName, ANewPassword: String; Role: TClientRole);
begin
  // �޸��û����롢��ɫ
  if CheckState() and (FConnection.FRole >= Role) then
  begin
    Params.ToUser := AUserName;  // ���޸ĵ��û�
    FParams.Password := ANewPassword;
    FParams.Role := Role;
    InternalPost(atUserModify);
  end;
end;

procedure TInCertifyClient.QueryClients;
begin
  // ��ѯȫ�����߿ͻ���
  if CheckState() and Assigned(Params) then
    InternalPost(atUserQuery);
end;

procedure TInCertifyClient.Register(const AUserName, APassword: String; Role: TClientRole);
begin
  // ע���û�������Ա��
  if CheckState() and
    (FConnection.FRole >= crAdmin) and (FConnection.FRole >= Role) then
  begin
    Params.ToUser := AUserName;  // 2.0 �� ToUser
    FParams.Password := APassword;
    FParams.Role := Role;
    InternalPost(atUserRegister);
  end;
end;

procedure TInCertifyClient.SetPassword(const Value: String);
begin
  if not Logined and (Value <> FPassword) then
    FPassword := Value;
end;

procedure TInCertifyClient.SetUserName(const Value: String);
begin
  if not Logined and (Value <> FPassword) then
    FUserName := Value;
end;

{ TInMessageClient }

procedure TInMessageClient.Broadcast(const Msg: String);
begin
  // ����Ա�㲥��������Ϣ��ȫ�����߿ͻ��ˣ�
  if CheckState() and (FConnection.FRole >= crAdmin) then
  begin
    Params.Msg := Msg;
    FParams.Role := FConnection.FRole;
    if (FParams.Size <= BROADCAST_MAX_SIZE) then
      InternalPost(atTextBroadcast)
    else begin
      FParams.Clear;
      raise Exception.Create('���͵���Ϣ̫��.');
    end;
  end;
end;

procedure TInMessageClient.Get;
begin
  // ȡ������Ϣ
  if CheckState() and Assigned(Params) then
    InternalPost(atTextGet);
end;

procedure TInMessageClient.GetMsgFiles(FileList: TStrings);
begin
  // ��ѯ����˵�������Ϣ�ļ�
  if CheckState() and Assigned(Params) then
  begin
    if Assigned(FileList) then
      FFileList := FileList;
    InternalPost(atTextGetFiles);
  end;
end;

procedure TInMessageClient.HandleFeedback(Result: TResultParams);
begin
  // ����������Ϣ�ļ�
  try
    if (Result.Action = atTextGetFiles) then  // �г��ļ�����
      ListReturnFiles(Result);
  finally
    inherited HandleFeedback(Result);
  end;
end;

procedure TInMessageClient.SendMsg(const Msg, ToUserName: String);
begin
  // �����ı�
  if CheckState() then
    if (ToUserName = '') then   // ���͵�������
    begin
      Params.Msg := Msg;
      InternalPost(atTextSend); // �򵥷���
    end else
    begin
      Params.Msg := Msg;
      FParams.ToUser := ToUserName; // ���͸�ĳ�û�
      if (FParams.Size <= BROADCAST_MAX_SIZE) then
        InternalPost(atTextPush)
      else begin
        FParams.Clear;
        raise Exception.Create('���͵���Ϣ̫��.');
      end;
    end;
end;

{ TInFileClient }

procedure TInFileClient.Delete(const AFileName: String);
begin
  // ɾ��������û���ǰ·�����ļ���Ӧ���ⲿ��ȷ�ϣ�
  if CheckState() then
  begin
    Params.FileName := AFileName;
    InternalPost(atFileDelete);
  end;
end;

procedure TInFileClient.Download(const AFileName: String);
begin
  // ���ط�����û���ǰ·�����ļ�
  InternalDownload(AFileName, 0);
end;

procedure TInFileClient.HandleFeedback(Result: TResultParams);
begin
  // �����ļ���ѯ���
  try
    if (Result.Action = atFileList) then  // �г��ļ�����
      ListReturnFiles(Result);
  finally
    inherited HandleFeedback(Result);
  end;
end;

procedure TInFileClient.InternalDownload(const AFileName: String; ATarget: TActionTarget);
begin
  // �����ļ�
  if CheckState() then
  begin
    Params.FileName := AFileName;
    FParams.FTarget := ATarget;
    InternalPost(atFileDownload);
  end;
end;

procedure TInFileClient.ListFiles(FileList: TStrings);
begin
  // ��ѯ��������ǰĿ¼���ļ�
  if CheckState() and Assigned(Params) then
  begin
    if Assigned(FileList) then
      FFileList := FileList;
    InternalPost(atFileList);
  end;
end;

procedure TInFileClient.Rename(const AFileName, ANewFileName: String);
begin
  // ������ļ�����
  if CheckState() then
  begin
    Params.FileName := AFileName;
    FParams.NewFileName := ANewFileName;
    InternalPost(atFileRename);
  end;
end;

procedure TInFileClient.SetDir(const Directory: String);
begin
  // ���ÿͻ����ڷ������Ĺ���Ŀ¼
  if CheckState() and (Directory <> '') then
  begin
    Params.Directory := Directory;
    InternalPost(atFileSetDir);
  end;
end;

procedure TInFileClient.Share(const AFileName: String; Groups: TStrings);
begin
  // �����ĵ���δ�ã�
  if CheckState() then
  begin
    Params.FileName := AFileName;
    FParams.AsString['groups'] := Groups.DelimitedText;
    InternalPost(atFileShare);
  end;
end;

procedure TInFileClient.Upload(const AFileName: String);
begin
  // �ϴ������ļ� AFileName ��������
  if CheckState() and FileExists(AFileName) then
  begin
    Params.LoadFromFile(AFileName);
    InternalPost(atFileUpload);
  end;
end;

{ TInDBConnection }

procedure TInDBConnection.Connect(ANo: Cardinal);
begin
  // ���ӵ����Ϊ ANo �����ݿ�
  if CheckState() then
  begin
    Params.FTarget := ANo;
    FConnectionIndex := ANo;  // ����
    InternalPost(atDBConnect);
  end;
end;

procedure TInDBConnection.GetConnections;
begin
  // ��ѯ������������������/��ģʵ����
  if CheckState() and Assigned(Params) then
    InternalPost(atDBGetConns);
end;

{ TDBBaseClientObject }

procedure TDBBaseClientObject.ExecStoredProc(const ProcName: String);
begin
  // ִ�д洢����
  //   TInDBQueryClient �����ص����ݼ���TInDBSQLClient ������
  if CheckState() then
  begin
    Params.StoredProcName := ProcName;
    FParams.FTarget := FDBConnection.FConnectionIndex;  // ��Ӧ����ģ���
    InternalPost(atDBExecStoredProc);
  end;
end;

procedure TDBBaseClientObject.SetDBConnection(const Value: TInDBConnection);
begin
  if (FDBConnection <> Value) then
  begin
    FDBConnection := Value;
    FConnection := FDBConnection.FConnection;
  end;
end;

{ TInDBSQLClient }

procedure TInDBSQLClient.ExecSQL;
begin
  // ִ�� SQL
  if CheckState() and Assigned(Params) then
  begin
    FParams.FTarget := FDBConnection.FConnectionIndex;  // ��Ӧ����ģ���
    InternalPost(atDBExecSQL);
  end;
end;

{ TInDBQueryClient }

procedure TInDBQueryClient.AddClientDataSets(AClientDataSet: TClientDataSet);
begin
  // �����ӱ� TClientDataSet
  if FSubClientDataSets.IndexOf(AClientDataSet) = -1 then
    FSubClientDataSets.Add(AClientDataSet);
end;

procedure TInDBQueryClient.ApplyUpdates;
var
  i: Integer;
  oDataSet: TClientDataSet;
begin
  // ����ȫ�����ݱ��������ӱ�
  if CheckState() and (FReadOnly = False) then
  begin
    for i := 0 to FTableNames.Count - 1 do
    begin
      if (i = 0) then
        oDataSet := FClientDataSet
      else
        oDataSet := TClientDataSet(FSubClientDataSets[i - 1]);

      // ���� Delta
      if (oDataSet.Changecount > 0) then
      begin
        oDataSet.SetOptionalParam(szTABLE_NAME, FTableNames[i], True);
        Params.AsVariant[FTableNames[i]] := oDataSet.Delta;
      end else  // ���� NULL �ֶ�
        Params.AsVariant[FTableNames[i]] := Null;
    end;
    if (Params.Size > 0) then  // δ���� VarCount
      InternalPost(atDBApplyUpdates);
  end;
end;

procedure TInDBQueryClient.ClearClientDataSets;
begin
  // ��������ݱ�
  FSubClientDataSets.Clear;
end;

constructor TInDBQueryClient.Create(AOwner: TComponent);
begin
  inherited;
  FSubClientDataSets := TList.Create;
  FTableNames := TStringList.Create;
end;

destructor TInDBQueryClient.Destroy;
begin
  FSubClientDataSets.Free;
  FTableNames.Free;
  inherited;
end;

procedure TInDBQueryClient.ExecQuery;
begin
  // SQL ��ֵʱ�Ѿ��ж� Action ���ͣ�����THeaderPack.SetSQL
  if CheckState() and Assigned(FParams) then
  begin
    FParams.FTarget := FDBConnection.FConnectionIndex;  // ��Ӧ����ģ���
    if (FParams.SQLName <> '') then  // ������ SQLName
      InternalPost(atDBExecQuery)
    else
      InternalPost(FParams.Action);
  end;
end;

procedure TInDBQueryClient.HandleFeedback(Result: TResultParams);
  procedure LoadResultDataSets;
  var
    i: Integer;
    XDataSet: TClientDataSet;
    DataField: TVarField;
  begin
    // װ�ز�ѯ���
    
    // �Ƿ�ֻ��
    FReadOnly := Result.Action = atDBExecStoredProc;

    // Result ���ܰ���������ݼ����ֶΣ�1,2,3

    FTableNames.Clear;
    for i := 0 to Result.VarCount - 1 do
    begin
      if (i = 0) then  // �����ݱ�
        XDataSet := FClientDataSet
      else
        XDataSet := FSubClientDataSets[i - 1];
        
      XDataSet.DisableControls;
      try
        DataField := Result.Fields[i];  // ȡ�ֶ� 1,2,3
        FTableNames.Add(DataField.Name);  // �������ݱ�����

        XDataSet.Data := DataField.AsVariant;  // ���ݸ�ֵ
        XDataSet.ReadOnly := FReadOnly;
      finally
        XDataSet.EnableControls;
      end;
    end;
  end;
  procedure MergeChangeDataSets;
  var
    i: Integer;
  begin
    // �ϲ����صĸ�������
    if (FClientDataSet.ChangeCount > 0) then
      FClientDataSet.MergeChangeLog;
    for i := 0 to FSubClientDataSets.Count - 1 do
      with TClientDataSet(FSubClientDataSets[i]) do
        if (ChangeCount > 0) then
          MergeChangeLog;
  end;
begin
  try
    if (Result.ActResult = arOK) then
      case Result.Action of
        atDBExecQuery,       // 1. ��ѯ����
        atDBExecStoredProc:  // 2. �洢���̷��ؽ��
          if Assigned(FClientDataSet) and (Result.VarCount > 0) and
            (Integer(Result.VarCount) = FSubClientDataSets.Count + 1) then
            LoadResultDataSets;
        atDBApplyUpdates:    // 3. ����
          MergeChangeDataSets;  // �ϲ����صĸ�������
      end;
  finally
    inherited HandleFeedback(Result);
  end;
end;

{ TInCustomClient }

procedure TInCustomClient.Post;
begin
  // �����Զ�����Ϣ
  if CheckState() and Assigned(FParams) then
    InternalPost(atCustomAction);
end;

{ TInFunctionClient }

procedure TInFunctionClient.Call(const GroupName: String; FunctionNo: Integer);
begin
  // ����Զ�̺����� GroupName �ĵ� FunctionNo ������
  //   ����TInCustomManager.Execute
  if CheckState() then
  begin
    Params.FunctionGroup := GroupName;
    FParams.FunctionIndex := FunctionNo;
    InternalPost(atCallFunction);
  end;
end;

// ================== �����߳� ==================

{ TSendThread }

procedure TSendThread.AddCancelMsgId(MsgId: TIOCPMsgId);
var
  i: Integer;
  Exists: Boolean;
begin
  // �����ȡ������Ϣ��� MsgId
  Exists := False;
  if (FCancelIds <> nil) then
    for i := 0 to High(FCancelIds) do
      if (FCancelIds[i] = MsgId) then
      begin
        Exists := True;
        Break;
      end;
  if (Exists = False) then
  begin
    SetLength(FCancelIds, Length(FCancelIds) + 1);
    FCancelIds[High(FCancelIds)] := MsgId;
  end;
end;

procedure TSendThread.AddWork(Msg: TClientParams);
begin
  // ����Ϣ�������б�
  //   Msg �Ƕ�̬���ɣ������ظ�Ͷ��
  if (Msg.FAction in FILE_CHUNK_ACTIONS) then
    Msg.ModifyMessageId;  // �������޸� MsgId

  if Assigned(FConnection.FOnAddWork) then
    FConnection.FOnAddWork(Self, Msg);

  FLock.Acquire;
  try
//    FConnection.FCurrentThread := TThread.CurrentThread;
    ClearCancelMsgId(Msg.FMsgId);  // ��������ڵ� MsgId
    FMsgList.Add(Msg);
  finally
    FLock.Release;
  end;

  Activate;  // �����߳�

end;

procedure TSendThread.AfterSend(FirstPack: Boolean; OutSize: Integer);
begin
  // ���ݳɹ���������ʾ����
  if FirstPack then  // ����Э������
  begin
    // FTotalSize �ڽ���ǰ������
    if (FMsgPack.Action in FILE_CHUNK_ACTIONS) then
      FCurrentSize := FMsgPack.FOffset
    else
      FCurrentSize := 0;
  end;
  Inc(FCurrentSize, OutSize);
  Synchronize(FConnection.SendProgress);
end;

procedure TSendThread.AfterWork;
begin
  // ֹͣ�̣߳��ͷ���Դ
  SetLength(FCancelIds, 0);
  CloseHandle(FBlockSemaphore);
  CloseHandle(FWaitSemaphore);
  ClearMsgList;
  FMsgList.Free;
  FLock.Free;
  FSender.Free;
end;

constructor TSendThread.Create(AConnection: TInConnection);
begin
  inherited Create;
  FConnection := AConnection;
  
  FLock := TThreadLock.Create; // ��
  FMsgList := TInList.Create;  // ���������

  FBlockSemaphore := CreateSemaphore(Nil, 0, 1, Nil); // �źŵ�
  FWaitSemaphore := CreateSemaphore(Nil, 0, 1, Nil);  // �źŵ�

  FSender := TClientTaskSender.Create;   // ��������
  FSender.Socket := FConnection.Socket;  // �����׽���

  FSender.AfterSend := AfterSend;  // �����¼�
  FSender.OnError := OnSendError;  // �����쳣�¼�
end;

function TSendThread.CancelWork(MsgId: TIOCPMsgId): Boolean;
var
  i: Integer;
  Msg: TClientParams;
begin
  // ȡ�����ͱ��Ϊ MsgId ����Ϣ
  Result := False;
  FLock.Acquire;
  try
    // 1. �� MsgId �������飨�����ڴ���Ч��
    AddCancelMsgId(MsgId);

    // 2. ���ڷ��͵���Ϣ���Դ��ļ������壬�����������������ȶ���
    if Assigned(FMsgPack) and (FMsgPack.FMsgId = MsgId) and
       not (FMsgPack.Action in FILE_CHUNK_ACTIONS) then
    begin
      FSender.Stoped := True;
      ServerReturn(True);  // ���Եȴ�
      Result := True;
      Exit;
    end;
    
    // 3. �����б����Ϣ
    for i := 0 to FMsgList.Count - 1 do
    begin
      Msg := FMsgList.Items[i];
      if (Msg.FMsgId = MsgId) then
      begin
        Msg.FCancel := True;
        Result := True;
        Exit;
      end;
    end;

  finally
    FLock.Release;
  end;

end;

procedure TSendThread.ClearAllWorks(var ACount: Integer);
begin
  // ����մ�����Ϣ����Ӱ��������ݣ�
  FLock.Acquire;
  try
    ACount := FMsgList.Count;  // ȡ����
    if Assigned(FMsgPack) then
    begin
      Inc(ACount);
      FSender.Stoped := True;  // ֹͣ
      ServerReturn(True);  // ���Եȴ�
    end;
    ClearMsgList;
  finally
    FLock.Release;
  end;
end;

procedure TSendThread.ClearCancelMsgId(MsgId: TIOCPMsgId);
var
  i: Integer;
begin
  // ���ȡ�����������ڵ���Ϣ��� MsgId
  if (FCancelIds <> nil) then
    for i := 0 to High(FCancelIds) do
      if (FCancelIds[i] = MsgId) then
      begin
        FCancelIds[i] := 0;
        Break;
      end;
end;

procedure TSendThread.ClearMsgList;
var
  i: Integer;
begin
  // �ͷ��б��ȫ����Ϣ
  for i := 0 to FMsgList.Count - 1 do
    TClientParams(FMsgList.PopFirst).Free;
  if Assigned(FMsgPack) then
    FMsgPack.Free;
end;

procedure TSendThread.DoMethod;
begin
  // ѭ��ִ������

  // �����з���
  Windows.InterlockedExchange(FGetFeedback, 1);

  // δֹͣ��ȡ����ɹ� -> ����
  while (Terminated = False) and FConnection.FActive and GetWork do
    try
      try
        FMsgPack.InternalSend(Self, FSender);  // ����
      finally
        FLock.Acquire;
        try
          FreeAndNil(FMsgPack);  // �ͷţ�
        finally
          FLock.Release;
        end;
      end;
    except
      on E: Exception do
      begin
        FConnection.FErrMsg := E.Message;
        FConnection.FErrorcode := GetLastError;
        Synchronize(FConnection.DoThreadFatalError);
      end;
    end;

  // ����Ƿ��з�����FGetFeedback > 0
  if (Windows.InterlockedDecrement(FGetFeedback) < 0) then
  begin
    // �������Ӧ�𣬵��� Synchronize����ͬ�̣߳�
    FConnection.FActResult := arErrNoAnswer;
    Synchronize(FConnection.DoThreadFatalError);
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
var
  i: Integer;
begin
  // ���б���ȡһ����Ϣ
  FLock.Acquire;
  try
    if Terminated or (FMsgList.Count = 0) or Assigned(FMsgPack) then
      Result := False
    else begin
      // ȡδֹͣ������
      for i := 0 to FMsgList.Count - 1 do
      begin
        FMsgPack := TClientParams(FMsgList.PopFirst);  // ����
        if FMsgPack.FCancel or InCancelArray(FMsgPack.FMsgId) then
        begin
          FMsgPack.Free;
          FMsgPack := nil;
        end else
          Break;
      end;
      if Assigned(FMsgPack) then
      begin
        FConnection.FPostThread.SetMsgPack(FMsgPack);  // ��ǰ��Ϣ
        FSender.Stoped := False;  // �ָ�
        Result := True;
      end else
      begin
        FConnection.FPostThread.SetMsgPack(nil); 
        Result := False;
      end;
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

function TSendThread.InCancelArray(MsgId: TIOCPMsgId): Boolean;
var
  i: Integer;
begin
  // ����Ƿ�Ҫֹͣ
  Result := False;
  if (FCancelIds <> nil) then
    for i := 0 to High(FCancelIds) do
      if (FCancelIds[i] = MsgId) then
      begin
        Result := True;
        Break;
      end;
end;

procedure TSendThread.IniWaitState;
begin
  // ��ʼ���ȴ�����
  Windows.InterlockedExchange(FGetFeedback, 0); // δ�յ�����
  Windows.InterlockedExchange(FWaitState, 0); // ״̬=0
end;

procedure TSendThread.KeepWaiting;
begin
  // �����ȴ�: FWaitState = 1 -> +1
  Windows.InterlockedIncrement(FGetFeedback); // �յ�����  
  if (iocp_api.InterlockedCompareExchange(FWaitState, 2, 1) = 1) then  // ״̬+
    ReleaseSemaphore(FWaitSemaphore, 1, Nil);  // ����
end;

procedure TSendThread.OnSendError(Sender: TObject);
begin
  // �������쳣
  if (GetWorkState = False) then  // ȡ������
  begin
    ServerReturn;  // ���Եȴ�
    FConnection.FRecvThread.FReceiver.Reset;
  end;
  FConnection.FErrorcode := TClientTaskSender(Sender).ErrorCode;
  Synchronize(FConnection.DoThreadFatalError); // �߳�ͬ��
end;

procedure TSendThread.ServerReturn(ACancel: Boolean);
begin
  // ���������� �� ���Եȴ�
  //  1. ȡ��������յ�����
  //  2. �յ���������δ�ȴ������������ȵȴ��磩
  Windows.InterlockedIncrement(FGetFeedback); // �յ�����
  if (Windows.InterlockedDecrement(FWaitState) = 0) then  // 1->0
    ReleaseSemaphore(FWaitSemaphore, 1, Nil);  // �ź���+1
end;

procedure TSendThread.WaitForFeedback;
begin
  // �ȷ������������� WAIT_MILLISECONDS ����
  if (Windows.InterlockedIncrement(FWaitState) = 1) then
    repeat
      WaitForSingleObject(FWaitSemaphore, WAIT_MILLISECONDS);
    until (Windows.InterlockedDecrement(FWaitState) <= 0);
end;

{ TPostThread }

procedure TPostThread.Add(Result: TReceivePack);
begin
  // ��һ����Ϣ���б������߳�

{  if (Result.DataSize > 0) then
    ExtrMsg.Add(Result.Msg);
  Success := True;
  Exit;     }

  // 1. ��鸽���������
  if (Result.ActResult = arAccept) then   // ��������������
  begin
//    FDebug.Add('arAccept:' + IntToStr(FMsgPack.FMsgId));
    FMsgPack.FActResult := arAccept;      // FMsgPack �ڵȴ�
    FResultEx := TResultParams(Result);   // �ȱ��淴�����
    FConnection.FSendThread.ServerReturn; // ����
  end else
  begin
    // 2. Ͷ�����̶߳���
    // ������ʱ�����������յ��㲥��Ϣ��
    // ��ʱ FMsgPack=nil��δ��¼��һ��Ͷ��
    FLock.Acquire;
    try
      if Assigned(FResultEx) and
        (FResultEx.FMsgId = Result.MsgId) then // ���͸�����ķ���
      begin
        Result.Free;         // �ڶ��η�������ִ�н���������ݣ�
        Result := FResultEx; // ʹ�������ķ�����Ϣ�������ݣ�
        FResultEx.FActResult := arOK;  // �޸Ľ�� -> �ɹ�
        FResultEx := nil;    // ������
//        FDebug.Add('Recv MsgId:' + IntToStr(Result.MsgId));
//        FDebug.SaveToFile('msid.txt');
      end;
      FResults.Add(Result);
    finally
      FLock.Release;
    end;
    // ����
    Activate;
  end;
end;

procedure TPostThread.AfterWork;
var
  i: Integer;
begin
  // �����Ϣ
  for i := 0 to FResults.Count - 1 do
    TResultParams(FResults.PopFirst).Free;
  FLock.Free;
  FResults.Free;
  inherited;
end;

constructor TPostThread.Create(AConnection: TInConnection);
begin
  inherited Create;
  FreeOnTerminate := True;
  FConnection := AConnection;
  FLock := TThreadLock.Create; // ��
  FResults := TInList.Create;  // �յ�����Ϣ�б�
end;

procedure TPostThread.DoMethod;
var
  Result: TResultParams;
begin
  // ѭ��ȡ���������յ�����Ϣ
  while (Terminated = False) do
  begin
    FLock.Acquire;
    try
      Result := FResults.PopFirst;  // ȡ����һ��
    finally
      FLock.Release;
    end;
    if Assigned(Result) then
      HandleMessage(Result) // ������Ϣ
    else
      Break;
  end;
end;

procedure TPostThread.ExecInMainThread;
const
  SERVER_PUSH_EVENTS = [arDeleted, arRefuse { ��Ӧ�ô��� },
                        arTimeOut];
  SELF_ERROR_RESULTS = [arOutDate, arRefuse { c/s ģʽ���� },
                        arErrBusy, arErrHash, arErrHashEx,
                        arErrAnalyse, arErrPush, arErrUser,
                        arErrWork];
begin
  // �������̣߳�����Ϣ�ύ������

  try

    if (FOwner = nil) or (FMsgPack = nil) or
       (FResult.Owner <> LongWord(FOwner)) then

      {$IFNDEF DELPHI_7}
      {$REGION '. ����������Ϣ'}
      {$ENDIF}

      try
        if (FResult.ActResult in SERVER_PUSH_EVENTS) then
        begin
          // 3.4 ���������͵���Ϣ
          FConnection.DoServerError(FResult);
        end else
        begin
          // 3.5 �����ͻ������͵���Ϣ
          FConnection.HandlePushedMsg(FResult);
        end;
      finally
        FResult.Free;
      end

      {$IFNDEF DELPHI_7}
      {$ENDREGION}
      {$ENDIF}

    else  // ====================================

      {$IFNDEF DELPHI_7}
      {$REGION '. �Լ������ķ�����Ϣ'}
      {$ENDIF}

      try
        // ������¼�����±��ص�ƾ֤
        if (FConnection.FSessionId <> FResult.FSessionId) then
          FConnection.FSessionId := FResult.FSessionId;
        if (FResult.ActResult in SELF_ERROR_RESULTS) then
        begin
          // 3.1 ����ִ���쳣
          FConnection.DoServerError(FResult);  // ��������
        end else
        if (FMsgPack.MsgId = FResult.MsgId) then
        begin
          // 3.2 �����������
          FOwner.HandleFeedback(FResult); // �����ͻ���
        end else
        begin
          // 3.3 MsgId ��������޸ģ��Լ����͵���Ϣ
          FConnection.HandlePushedMsg(FResult)
        end;
      finally
        if (FMsgPack.MsgId = FResult.MsgId) then
          FConnection.FSendThread.ServerReturn;  // ����
        FResult.Free;
      end;

      {$IFNDEF DELPHI_7}
      {$ENDREGION}
      {$ENDIF}

  except
    on E: Exception do
    begin
      FConnection.FErrMsg := E.Message;
      FConnection.FErrorcode := GetLastError;
      FConnection.DoThreadFatalError;  // �����̣߳�ֱ�ӵ���
    end;
  end;

end;

procedure TPostThread.HandleMessage(Result: TReceivePack);
var
  Msg: TMessagePack;
  DoSynch: Boolean;
begin
  // Ԥ������Ϣ
  // ���Ҫ�ύ�����߳�ִ�У�Ҫ���ϵ�����
  DoSynch := True;
  FResult := TResultParams(Result);
  try
    if (FResult.FAction in FILE_CHUNK_ACTIONS) and
       (FConnection.FSendThread.InCancelArray(FResult.FMsgId) = False) then
    begin
      Msg := TMessagePack.Create(TBaseClientObject(FResult.Owner));

      Msg.FActResult := FResult.FActResult; // ���͸�����ķ������
      Msg.FCheckType := FResult.FCheckType;
      Msg.FZipLevel := FResult.FZipLevel;

      if (FResult.FAction = atFileUpChunk) then
      begin
        // �ϵ��ϴ������̴򿪱����ļ���
        //   ����TBaseMessage.LoadFromFile��TReceiveParams.CreateAttachment
        Msg.LoadFromFile(FResult.Directory + FResult.FileName, True);
         if Msg.ReadUploadInf(FResult) then
          Msg.Post(atFileUpChunk)
        else
          Msg.Free;
      end else
      begin
        if (Msg.FActResult in [arOK, arErrHashEx]) then
        begin
          // �ϵ����أ����������ļ�������
          //   ����TReturnResult.LoadFromFile��TResultParams.CreateAttachment
          Msg.FileName := FResult.FileName;
          if Msg.ReadDownloadInf(FResult) then
          begin
            DoSynch := False;  // ֻ����Ӧ�ò�һ��
            Msg.Post(atFileDownChunk);
          end else
            Msg.Free;
        end else
          Msg.Free;
      end;
    end;
  finally
    if DoSynch then  // FConnection.FCurrentThread,
      Synchronize(ExecInMainThread) // ����Ӧ�ò�
    else
      FConnection.FSendThread.ServerReturn; // ����
  end;
end;

procedure TPostThread.SetMsgPack(MsgPack: TClientParams);
begin
  FLock.Acquire;
  try
    FResultEx := nil;
    FMsgPack := MsgPack; // ��ǰ������Ϣ��
    if Assigned(FMsgPack) then
      FOwner := TBaseClientObject(FMsgPack.Owner)  // ��ǰ��Ϣ������
    else
      FOwner := nil;
  finally
    FLock.Release;
  end;
end;

// ================== �����߳� ==================

// ʹ�� WSARecv �ص�������Ч�ʸ�
procedure WorkerRoutine(const dwError, cbTransferred: DWORD;
                        const lpOverlapped: POverlapped;
                        const dwFlags: DWORD); stdcall;
var
  Thread: TRecvThread;
  Connection: TInConnection;
  ByteCount, Flags: DWORD;
  ErrorCode: Cardinal;
begin
  // �������߳� ��
  // ����� lpOverlapped^.hEvent = TInRecvThread

  Thread := TRecvThread(lpOverlapped^.hEvent);
  Connection := Thread.FConnection;

  if (dwError <> 0) or (cbTransferred = 0) then // �Ͽ����쳣
  begin
    // ����˹ر�ʱ cbTransferred = 0, Ҫ�Ͽ����ӣ�2019-02-28
    if (cbTransferred = 0) then
      Thread.Synchronize(Connection.TryDisconnect); // ͬ��
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

constructor TRecvThread.Create(AConnection: TInConnection);
{ var
  i: Integer; }    
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FConnection := AConnection;

  // ������ջ���
  GetMem(FRecvBuf.buf, IO_BUFFER_SIZE_2);
  FRecvBuf.len := IO_BUFFER_SIZE_2;

  // ��Ϣ�������������� TResultParams
  FReceiver := TClientReceiver.Create(TResultParams);

  // ����·��
  FReceiver.LocalPath := AddBackslash(FConnection.FLocalPath);

  FReceiver.OnCheckError := OnCheckCodeError; // У���쳣�¼�
  FReceiver.OnPost := FConnection.FPostThread.Add; // Ͷ�ŷ���
  FReceiver.OnReceive := OnReceive; // ���ս���

{  FDebug.LoadFromFile('recv\pn2.txt');
  FStream.LoadFromFile('recv\recv2.dat');

  for i := 0 to FDebug.Count - 1 do
  begin
    FOverlapped.InternalHigh := StrToInt(FDebug[i]);
    if FOverlapped.InternalHigh = 93 then
      FStream.Read(FRecvBuf.buf^, FOverlapped.InternalHigh)
    else
      FStream.Read(FRecvBuf.buf^, FOverlapped.InternalHigh);
    HandleDataPacket;
  end;

  ExtrMsg.SaveToFile('msg.txt');    }

end;

procedure TRecvThread.Execute;
VAR
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

//  FDebug.Add(IntToStr(FOverlapped.InternalHigh));
//  FStream.Write(FRecvBuf.buf^, FOverlapped.InternalHigh);

  if FReceiver.Complete then  // 1. �װ�����
  begin
    // 1.1 ������ͬʱ���� HTTP ����ʱ�����ܷ����ܾ�������Ϣ��HTTPЭ�飩
    if MatchSocketType(FRecvBuf.buf, HTTP_VER) then
    begin
      TResultParams(FReceiver.Owner).FActResult := arRefuse;
      FConnection.DoServerError(TResultParams(FReceiver.Owner));
      Exit;
    end;

    // 1.2 C/S ģʽ����
    if (FOverlapped.InternalHigh < IOCP_SOCKET_SIZE) or  // ����̫��
       (MatchSocketType(FRecvBuf.buf, IOCP_SOCKET_FLAG) = False) then // C/S ��־����
    begin
      TResultParams(FReceiver.Owner).FActResult := arErrInit;  // ��ʼ���쳣
      FConnection.DoServerError(TResultParams(FReceiver.Owner));
      Exit;
    end;

    if (FReceiver.Owner.ActResult <> arAccept) then
      FReceiver.Prepare(FRecvBuf.buf, FOverlapped.InternalHigh)  // ׼������
    else begin
      // �ϴ�������ո������ٴ��յ�������������ϵķ���
      TResultParams(FReceiver.Owner).FActResult := arOK; // Ͷ��ʱ��Ϊ arAccept, �޸�
      FReceiver.PostMessage;  // ��ʽͶ��
    end;

  end else
  begin
    // 2. ��������
    FReceiver.Receive(FRecvBuf.buf, FOverlapped.InternalHigh);
  end;

end;

procedure TRecvThread.OnCheckCodeError(Result: TReceivePack);
begin
  // У���쳣
  TResultParams(Result).FActResult := arErrHashEx;
end;

procedure TRecvThread.OnReceive(Result: TReceivePack;
                      RecvSize: Cardinal; Complete, Main: Boolean);
begin
  // ��ʾ���ս���
  if Main then  // �����һ��
  begin
    FRecvMsg := Result;
    FTotalSize := FRecvMsg.GetMsgSize(True);
    if (FRecvMsg.Action in FILE_CHUNK_ACTIONS) then
      FCurrentSize := FRecvMsg.Offset  // ��ϸ΢���
    else
      FCurrentSize := IOCP_SOCKET_SIZE;
  end else
  if (Complete = False) then  // û�������
    FConnection.FSendThread.KeepWaiting;  // �����ȴ�

  Inc(FCurrentSize, RecvSize);
  Synchronize(FConnection.ReceiveProgress);  // �л������߳�
end;

procedure TRecvThread.Stop;
begin
  inherited;
  Sleep(20);
end;
 

initialization
//  ExtrMsg := TStringList.Create;
//  FDebug := TStringList.Create;
//  FStream := TMemoryStream.Create;

finalization
//  FDebug.SaveToFile('msid.txt');
//  FStream.SaveToFile('recv2.dat');

// ExtrMsg.Free;
//  FStream.Free;
//  FDebug.Free;

end.

