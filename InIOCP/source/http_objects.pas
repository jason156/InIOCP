(*
 * http ������ֶ�����
 *)
unit http_objects;

interface

{$I in_iocp.inc}

uses
  Windows, Classes, SysUtils, StrUtils, DB, 
  iocp_Winsock2, iocp_base, iocp_senders, iocp_lists,
  iocp_objPools, iocp_msgPacks, http_base, http_utils,
  iocp_SHA1;

type

  // ================ Http Session �� ================

  // Set-Cookie: InIOCP_SID=Value

  THttpSession = class(Tobject)
  private
    FName: AnsiString;       // ����
    FValue: AnsiString;      // ֵ
    FExpires: Int64;         // ���� UTC ʱ�䣨��ȡ�ٶȿ죩
    FTimeOut: Integer;       // ��ʱʱ�䣨�룩
    FCount: Integer;         // �ۼ��������
    function CheckAttack: Boolean;
    function CreateSessionId: AnsiString;
    function ValidSession: Boolean;
    procedure UpdateExpires;
  public
    constructor Create(const AName: AnsiString; const AValue: AnsiString = '');
    class function Extract(const Info: AnsiString; var Name, Value: AnsiString): Boolean;
  public
    property Name: AnsiString read FName;   // ֻ��
    property Value: AnsiString read FValue; // ֻ��
    property TimeOut: Integer read FTimeOut;
  end;

  // ================ Http Session ���� �� ================

  THttpSessionManager = class(TStringHash)
  private
    procedure CheckSessionEvent(var Data: Pointer);
  protected
    procedure FreeItemData(Item: PHashItem); override;
  public
    function CheckAttack(const SessionId: AnsiString): Boolean;
    procedure DecRef(const SessionId: AnsiString);
    procedure InvalidateSessions;
  end;

  // ================== Http �����ṩ ����� ======================

  THttpBase         = class;         // ����
  THttpRequest      = class;         // ����
  THttpRespone      = class;         // ��Ӧ

  TOnAcceptEvent    = procedure(Sender: TObject; Request: THttpRequest;
                                var Accept: Boolean) of object;
  TOnInvalidSession = procedure(Sender: TObject; Request: THttpRequest;
                                Respone: THttpRespone) of object;
  TOnReceiveFile    = procedure(Sender: TObject; Request: THttpRequest;
                                const FileName: String; Data: PAnsiChar;
                                DataLength: Integer; State: THttpPostState) of object;

  // �����¼���Sender �� Worker��
  THttpRequestEvent = procedure(Sender: TObject;
                                Request: THttpRequest;
                                Respone: THttpRespone) of object;

  // ����Ϊ WebSocket ���¼�
  TOnUpgradeEvent = procedure(Sender: TObject; const Origin: String;
                              var Accept: Boolean) of object;
                                                              
  THttpDataProvider = class(TComponent)
  private
    FSessionMgr: THttpSessionManager;     // ȫ�� Session ����
    FMaxContentLength: Integer;           // ����ʵ�����󳤶�
    FKeepAlive: Boolean;                  // ��������
    FPeerIPList: TPreventAttack;          // �ͻ��� IP �б�
    FPreventAttack: Boolean;              // IP�б���������
    function CheckSessionState(Request: THttpRequest; Respone: THttpRespone;
                               const PeerInfo: AnsiString): Boolean;
    procedure SetMaxContentLength(const Value: Integer);
    procedure SetPreventAttack(const Value: Boolean);
  protected
    FServer: TObject;                     // TInIOCPServer ������
    FOnAccept: TOnAcceptEvent;            // �Ƿ��������
    FOnDelete: THttpRequestEvent;         // ����Delete
    FOnGet: THttpRequestEvent;            // ����Get
    FOnInvalidSession: TOnInvalidSession; // Session ��Ч�¼�
    FOnPost: THttpRequestEvent;           // ����Post
    FOnPut: THttpRequestEvent;            // ����Put
    FOnOptions: THttpRequestEvent;        // ����Options
    FOnReceiveFile: TOnReceiveFile;       // �����ļ��¼�
    FOnTrace: THttpRequestEvent;          // ����Trace
    FOnUpgrade: TOnUpgradeEvent;          // ����Ϊ WebSocket �¼�
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ClearIPList;
  public
    property SessionMgr: THttpSessionManager read FSessionMgr;
  published
    property KeepAlive: Boolean read FKeepAlive write FKeepAlive default True;
    property MaxContentLength: Integer read FMaxContentLength write SetMaxContentLength default MAX_CONTENT_LENGTH;
    property PreventAttack: Boolean read FPreventAttack write SetPreventAttack default False;
  published
    property OnAccept: TOnAcceptEvent read FOnAccept write FOnAccept;
    property OnDelete: THttpRequestEvent read FOnDelete write FOnDelete;
    property OnGet: THttpRequestEvent read FOnGet write FOnGet;
    property OnInvalidSession: TOnInvalidSession read FOnInvalidSession write FOnInvalidSession;
    property OnPost: THttpRequestEvent read FOnPost write FOnPost;
    property OnPut: THttpRequestEvent read FOnPut write FOnPut;
    property OnOptions: THttpRequestEvent read FOnOptions write FOnOptions;
    property OnReceiveFile: TOnReceiveFile read FOnReceiveFile write FOnReceiveFile;
    property OnTrace: THttpRequestEvent read FOnTrace write FOnTrace;
  end;

  // ================ �ͻ��˱��ֶ�/���� �� ================

  THttpFormParams = class(TBasePack)
  public  // �����������ԣ�ֻ����
    property AsBoolean[const Index: String]: Boolean read GetAsBoolean;
    property AsDateTime[const Index: String]: TDateTime read GetAsDateTime;
    property AsFloat[const Index: String]: Double read GetAsFloat;
    property AsInteger[const Index: String]: Integer read GetAsInteger;
    property AsString[const Index: String]: String read GetAsString;
  end;

  // ================ ����ͷ�Ķ�����Ϣ/���� �� ================

  THttpHeaderParams = class(THttpFormParams)
  private
    FOwner: THttpBase;
    function GetBoundary: AnsiString;
    function GetContentLength: Integer;
    function GetContentType: THttpContentType;
    function GetEncodeType: THttpEncodeType;
    function GetKeepAlive: Boolean;
    function GetMultiPart: Boolean;
    function GetRange: AnsiString;
    function GetIfMath: AnsiString;
    function GetLastModified: AnsiString;
  public
    constructor Create(AOwner: THttpBase);
  public
    // ���ԣ���ͷ����
    property Boundary: AnsiString read GetBoundary;    // Content-Type: multipart/form-data; Boundary=
    property ContentLength: Integer read GetContentLength; // Content-Length ��ֵ
    property ContentType: THttpContentType read GetContentType; // Content-Type ��ֵ
    property EncodeType: THttpEncodeType read GetEncodeType;  // UTF-8...
    property IfMath: AnsiString read GetIfMath;  // if-math...
    property LastModified: AnsiString read GetLastModified;  // Last-Modified  
    property KeepAlive: Boolean read GetKeepAlive;  // Keep-Alive...
    property MultiPart: Boolean read GetMultiPart; // Content-Type��multipart/form-data
    property Range: AnsiString read GetRange; // range
  end;

  // ================ Http ���� ================

  THttpBase = class(TObject)
  private
    FDataProvider: THttpDataProvider;  // HTTP ֧��
    FOwner: TObject;             // THttpSocket ����
    FContentSize: Integer;       // ʵ�峤��
    FFileName: AnsiString;       // �յ������͵����ļ���
    FKeepAlive: Boolean;         // ��������
    FSessionId: AnsiString;      // �Ի��� ID
    function GetSocketState: Boolean;
    function GetHasSession: Boolean;
  protected
    FExtParams: THttpHeaderParams;  // ���� Headers �Ķ������/������
    FStatusCode: Integer;        // ״̬����
  public
    constructor Create(ADataProvider: THttpDataProvider; AOwner: TObject);
    procedure Clear; virtual;
  public
    property HasSession: Boolean read GetHasSession;
    property KeepAlive: Boolean read FKeepAlive;    
    property SessionId: AnsiString read FSessionId;
    property SocketState: Boolean read GetSocketState;
    property Owner: TObject read FOwner;
  end;

  // ================ Http ���� ================

  // ��ͷ����
  PHeadersArray = ^THeadersArray;
  THeadersArray = array[TRequestHeaderType] of AnsiString;

  THttpRequest = class(THttpBase)
  private
    FAccepted: Boolean;          // ��������
    FAttacked: Boolean;          // ������
    FByteCount: Integer;         // ���ݰ�����

    FHeadersAry: THeadersArray;  // ��ͷ���飨ԭʼ���ݣ�
    FParams: THttpFormParams;    // �ͻ��˱����ֶ�/����/������
    FStream: TInMemStream;       // ����/����ԭʼ��

    FContentType: THttpContentType;  // ʵ������
    FContentLength: Integer;     // ʵ�峤��
    FMethod: THttpMethod;        // ��������
    FRequestURI: AnsiString;     // ������Դ
    FUpgradeState: Integer;      // ����Ϊ WebSocket ��״̬
    FVersion: AnsiString;        // �汾 http/1.1

    function GetComplete: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetHeaderIndex(const Header: AnsiString): TRequestHeaderType; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetHeaders(Index: TRequestHeaderType): AnsiString;

    procedure ExtractElements(Data: PAnsiChar; Len: Integer; RecvFileEvent: TOnReceiveFile);
    procedure ExtractHeaders(Data: PAnsiChar; DataLength: Integer);
    procedure ExtractMethod(var Data: PAnsiChar);
    procedure ExtractParams(Data: PAnsiChar; Len: Integer);
    procedure URLDecodeRequestURI;
    procedure WriteHeader(Index: TRequestHeaderType; const Content: AnsiString);
  protected
    procedure Decode(Sender: TBaseTaskSender; Respone: THttpRespone; Data: PPerIOData);
  public
    constructor Create(ADataProvider: THttpDataProvider; AOwner: TObject);
    destructor Destroy; override;
    procedure Clear; override;
  public
    property Accepted: Boolean read FAccepted;
    property Attacked: Boolean read FAttacked;
    property Complete: Boolean read GetComplete;
    property Entity: TInMemStream read FStream;
    property Headers[Index: TRequestHeaderType]: AnsiString read GetHeaders;
    property Method: THttpMethod read FMethod;
    property Params: THttpFormParams read FParams;
    property URI: AnsiString read FRequestURI;
    property UpgradeState: Integer read FUpgradeState;
    property StatusCode: Integer read FStatusCode;
  end;

  // ================ ��Ӧ��ͷ �� ================
  // һ����˵����Ӧ��ͷ���ݲ���ܴ�С�� IO_BUFFER_SIZE����
  // Ϊ�ӿ��ٶȣ���Ӧ��ͷ���ڴ�ֱ�����÷������� TPerIOData.Data��
  // �� Add �������뱨ͷ���� Append ��������Сҳ���ʵ�壨�ܳ� <= IO_BUFFER_SIZE��

  THeaderArray = array[TResponeHeaderType] of Boolean;

  THttpResponeHeaders = class(TObject)
  private
    FHeaders: THeaderArray;     // �Ѽ���ı�ͷ
    FData: PWsaBuf;             // ���÷���������
    FBuffer: PAnsiChar;         // ���ͻ��浱ǰλ��
    FOwner: TServerTaskSender;  // ���ݷ�����
    function GetSize: Integer;
    procedure InterAdd(const Content: AnsiString; SetCRLF: Boolean = True);
    procedure SetOwner(const Value: TServerTaskSender);
  public
    procedure Clear;

    procedure Add(Code: TResponeHeaderType; const Content: AnsiString = '');
    procedure Append(Content: AnsiString; SetCRLF: Boolean = True); overload;
    procedure Append(var AHandle: THandle; ASize: Cardinal); overload;
    procedure Append(var AStream: TStream; ASize: Cardinal); overload;
    procedure Append(AList: TInStringList; ASize: Cardinal); overload;
    procedure AddCRLF;

    procedure ChunkDone;
    procedure ChunkSize(ASize: Cardinal);
    procedure SetStatus(Code: Integer);
  public
    property Size: Integer read GetSize;
    property Owner: TServerTaskSender read FOwner write SetOwner; 
  end;

  // ================ Http ��Ӧ ================

  THttpRespone = class(THttpBase)
  private
    FRequest: THttpRequest;    // ��������
    FHeaders: THttpResponeHeaders; // ������״̬����ͷ
    FContent: TInStringList;   // �б�ʽʵ������

    FHandle: THandle;          // Ҫ���͵��ļ�
    FStream: TStream;          // Ҫ���͵�������
    FSender: TBaseTaskSender;  // ��������

    FContentType: AnsiString;  // ��������
    FGZipStream: Boolean;      // �Ƿ�ѹ����
    FLastWriteTime: Int64;     // �ļ�����޸�ʱ��
    FWorkDone: Boolean;        // ���ͽ�����
    
    function GetFileETag: AnsiString; 
    function GZipCompress(Stream: TStream): TStream;

    procedure AddHeaderList(SendNow: Boolean);  
    procedure AddDataPackets;
    procedure FreeResources;
    
    procedure SendChunkHeaders(const ACharSet: AnsiString = '');
  protected
    // ��ʽ��������
    procedure SendWork;
    procedure Upgrade;    
  public
    constructor Create(ADataProvider: THttpDataProvider; AOwner: TObject);
    destructor Destroy; override;

    // �����Դ
    procedure Clear; override;

    // Session���½�����ΪʧЧ
    procedure CreateSession;
    procedure InvalidSession;

    // ����״̬����ͷ
    procedure SetStatus(Code: Integer);
    procedure AddHeader(Code: TResponeHeaderType; const Content: AnsiString = '');

    // ����ʵ��
    procedure SetContent(const Content: AnsiString);
    procedure AddContent(const Content: AnsiString);

    // ���̷ֿ鷢�ͣ��Ż����Զ����ͽ�����־��
    procedure SendChunk(Stream: TStream);

    // ���÷���Դ�����������ļ�
    procedure SendStream(Stream: TStream; Compress: Boolean = False);
    procedure TransmitFile(const FileName: String; AutoView: Boolean = True);

    // ���� JSON
    procedure SendJSON(DataSet: TDataSet; CharSet: THttpCharSet = hcsDefault); overload;
    procedure SendJSON(JSON: AnsiString); overload;

    // ���� Head ��Ϣ
    procedure SetHead;

    // �ض�λ
    procedure Redirect(const URL: AnsiString);
  public
    property ContentType: AnsiString read FContentType;
    property StatusCode: Integer read FStatusCode write FStatusCode;
  end;

implementation

uses
  iocp_log, iocp_varis, iocp_utils,
  iocp_server, iocp_managers, iocp_sockets, iocp_zlib;

type
  TBaseSocketRef = class(TBaseSocket);

{ THttpSession }

function THttpSession.CheckAttack: Boolean;
var
  TickCount: Int64;
begin
  // 10 ���ڳ��� 10 �����󣬵�������, 15 �����ڽ�ֹ����
  //    �� httptest.exe ���Գɹ���
  TickCount := GetUTCTickCount;
  if (FExpires > TickCount) then   // ��������δ���
    Result := True
  else begin
    Result := (FCount >= 10) and (TickCount - FExpires <= 10000);
    if Result then                // �ǹ���
    begin
      FExpires := TickCount + 900000;  // 900 ��
//      {$IFDEF DEBUG_MODE}
      iocp_log.WriteLog('THttpSession.CheckAttack->�ܾ����񣬹����Ի��ڣ�' + FValue);
//      {$ENDIF}
    end else
      FExpires := TickCount;
    Inc(FCount);
  end;
end;

constructor THttpSession.Create(const AName, AValue: AnsiString);
begin
  inherited Create;
  // FName �Ժ��ܸģ�������Ψһ��ֵ
  // FValue = CreateSessionId���Ժ��ܸ�
  FName := UpperCase(AName);
  if (AValue = '') then
    FValue := CreateSessionId
  else
    FValue := AValue;
  FExpires := GetUTCTickCount;  // ��ǰʱ��
  FTimeOut := 300;              // 300 �볬ʱ
end;

function THttpSession.CreateSessionId: AnsiString;
const
  // BASE_CHARS �� 62
  BASE_CHARS = AnsiString('0123456789aAbBcCdDeEfFgGhHiIjJ' +
                          'kKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ');
var
  i: Integer;
begin
  Randomize;
  Result := Copy(BASE_CHARS, 1, HTTP_SESSION_ID_LEN);  // 32 �ֽ�
  for i := 1 to HTTP_SESSION_ID_LEN do                 // �ܳ� 32
    Result[i] := BASE_CHARS[Random(62) + 1];           // 1 <= Random < 62
end;

class function THttpSession.Extract(const Info: AnsiString; var Name, Value: AnsiString): Boolean;
var
  pa, p2: PAnsiChar;
begin
  // ��ȡ Session �����ơ�ֵ
  pa := PAnsiChar(Info);
  p2 := pa;
  if SearchInBuffer(p2, Length(Info), HTTP_SESSION_ID) then
  begin
    Inc(p2);
    Name := HTTP_SESSION_ID;
    Value := Copy(Info, Integer(p2 - pa) + 1, HTTP_SESSION_ID_LEN);
    Result := Pos(HTTP_INVALID_SESSION, Value) = 0;
  end else
  begin
    Name := '';
    Value := '';
    Result := False;
  end;
end;

procedure THttpSession.UpdateExpires;
begin
  // �ӳ�������
  FExpires := GetUTCTickCount;  // ��ǰʱ��
end;

function THttpSession.ValidSession: Boolean;
begin
  // ����Ƿ���Ч
  Result := (GetUTCTickCount - FExpires) <= FTimeOut * 1000;
end;

{ THttpSessionManager }

procedure THttpSessionManager.CheckSessionEvent(var Data: Pointer);
var
  Session: THttpSession;
begin
  // �ص������ Session �Ƿ���Ч
  Session := THttpSession(Data);
  if (Session.ValidSession = False) then
    try
      Session.Free;
    finally
      Data := Nil;
    end;
end;

procedure THttpSessionManager.DecRef(const SessionId: AnsiString);
var
  Session: THttpSession;
begin
  // ���� IP ����
  if (SessionId = '') or (SessionId = HTTP_INVALID_SESSION) then
    Exit;
  Lock;
  try
    Session := ValueOf2(SessionId);
    if Assigned(Session) and (Session.FCount > 0) then
      Dec(Session.FCount);
  finally
    UnLock;
  end;
end;

function THttpSessionManager.CheckAttack(const SessionId: AnsiString): Boolean;
var
  Session: THttpSession;
begin
  // ����Ƿ�Ϊ SessionId ��������ʱ�����ʹ�ã�
  Lock;
  try
    Session := ValueOf2(SessionId);
    Result := Assigned(Session) and Session.CheckAttack;
  finally
    UnLock;
  end;
end;

procedure THttpSessionManager.FreeItemData(Item: PHashItem);
begin
  // �ͷ� Session ����
  try
    THttpSession(Item^.Value).Free;
  finally
    Item^.Value := Nil;
  end;
end;

procedure THttpSessionManager.InvalidateSessions;
begin
  // ���ȫ�� Session ��״̬
  //   ɾ�����ڵ� Session
  Lock;
  try
    Scan(CheckSessionEvent);
  finally
    Unlock;
  end;
end;

{ THttpDataProvider }

function THttpDataProvider.CheckSessionState(Request: THttpRequest;
                           Respone: THttpRespone; const PeerInfo: AnsiString): Boolean;
var
  State: Integer;
  Session: THttpSession;
begin
  // ���ͻ��� Session �ڷ���˵�״̬
  //  �� FSessionMgr �в��ҿͻ��� SessionId ��Ӧ�� THttpSession

  Session := FSessionMgr.ValueOf(Request.FSessionId);
  if Assigned(Session) = False then  // ������
    State := 1
  else
  if (Session.ValidSession = False) then // ��ʱ, ɾ��
  begin
    State := 2;
    FSessionMgr.Remove(Request.FSessionId);
  end else
  begin
    State := 0;
    Session.UpdateExpires;  // �������Ӻ�
    Respone.FSessionId := Request.FSessionId;  // ������������ж�
  end;

  if (State = 0) then
    Result := True
  else
    try
//      {$IFDEF DEBUG_MODE}
      iocp_log.WriteLog(PeerInfo + '->�Ի�����Ч, ' + HTTP_SESSION_ID  + '=' + Request.FSessionId);
//      {$ENDIF}
      if Assigned(FOnInvalidSession) then  // �����¼� FOnInvalidSession
        FOnInvalidSession(THttpSocket(Request.FOwner).Worker, Request, Respone);
    finally
      Request.FSessionId := '';
      Respone.InvalidSession;   // ����һ����Ч�� Session ���ͻ���
      Result := False; 
    end;

end;

procedure THttpDataProvider.ClearIPList;
begin
  // ��� IP �б�����
  if Assigned(FPeerIPList) then
    TPreventAttack(FPeerIPList).Clear;
end;

constructor THttpDataProvider.Create(AOwner: TComponent);
begin
  inherited;
  FKeepAlive := True; // Ĭ��ֵ
  FMaxContentLength := MAX_CONTENT_LENGTH;
  FPreventAttack := False;
  FSessionMgr := THttpSessionManager.Create(512);
end;

destructor THttpDataProvider.Destroy;
begin
  if Assigned(FPeerIPList) then
    FPeerIPList.Free;
  FSessionMgr.Free;
  inherited;
end;

procedure THttpDataProvider.SetMaxContentLength(const Value: Integer);
begin
  if (Value <= 0) then
    FMaxContentLength := MAX_CONTENT_LENGTH
  else
    FMaxContentLength := Value;
end;

procedure THttpDataProvider.SetPreventAttack(const Value: Boolean);
begin
  FPreventAttack := Value;
  if not (csDesigning in ComponentState) then
    if FPreventAttack then
      FPeerIPList := TPreventAttack.Create
    else
    if Assigned(FPeerIPList) then
      FPeerIPList.Free;
end;

{ THttpHeaderParams }

constructor THttpHeaderParams.Create(AOwner: THttpBase);
begin
  inherited Create;    
  FOwner := AOwner;
end;

function THttpHeaderParams.GetBoundary: AnsiString;
begin
  Result := inherited AsString['BOUNDARY'];
end;

function THttpHeaderParams.GetContentLength: Integer;
begin
  Result := inherited AsInteger['CONTENT-LENGTH'];
end;

function THttpHeaderParams.GetContentType: THttpContentType;
begin
  Result := THttpContentType(inherited AsInteger['CONTENT-TYPE']);
end;

function THttpHeaderParams.GetEncodeType: THttpEncodeType;
begin
  Result := THttpEncodeType(inherited AsInteger['ENCODE-TYPE']);
end;

function THttpHeaderParams.GetIfMath: AnsiString;
begin
  Result := inherited AsString['IF-MATH'];
end;

function THttpHeaderParams.GetKeepAlive: Boolean;
begin
  Result := inherited AsBoolean['KEEP-ALIVE'];
end;

function THttpHeaderParams.GetLastModified: AnsiString;
begin
  Result := inherited AsString['LAST-MODIFIED'];
end;

function THttpHeaderParams.GetMultiPart: Boolean;
begin
  Result := inherited AsBoolean['MULTIPART'];
end;

function THttpHeaderParams.GetRange: AnsiString;
begin
  Result := inherited AsString['RANGE'];
end;

{ THttpBase }

procedure THttpBase.Clear;
begin
  // �����Դ����������ֵ
  FContentSize := 0;            
  FFileName := '';
  FSessionId := '';
  FStatusCode := 200;      // Ĭ��       
end;

constructor THttpBase.Create(ADataProvider: THttpDataProvider; AOwner: TObject);
begin
  inherited Create;
  FDataProvider := ADataProvider;  // HTTP ֧��
  FOwner := AOwner;  // THttpSocket ����
end;

function THttpBase.GetSocketState: Boolean;
begin
  Result := THttpSocket(FOwner).SocketState;
end;

function THttpBase.GetHasSession: Boolean;
begin
  Result := (FSessionId <> '');
end;

{ THttpRequest }

procedure THttpRequest.Clear;
var
  i: TRequestHeaderType;
begin
  inherited;
  FAttacked := False;
  FContentLength := 0; // �´�Ҫ�Ƚ�
  FContentType := hctUnknown;
  
  for i := rqhHost to High(FHeadersAry) do
    Delete(FHeadersAry[i], 1, Length(FHeadersAry[i]));
  Delete(FRequestURI, 1, Length(FRequestURI)); // ��
  Delete(FVersion, 1, Length(FVersion));  // �汾

  FParams.Clear;
  FExtParams.Clear;
  FStream.Clear;
end;

constructor THttpRequest.Create(ADataProvider: THttpDataProvider; AOwner: TObject);
begin
  inherited;
  FExtParams := THttpHeaderParams.Create(Self);
  FParams := THttpFormParams.Create;
  FStream := TInMemStream.Create;
end;

procedure THttpRequest.Decode(Sender: TBaseTaskSender; Respone: THttpRespone; Data: PPerIOData);
var
  Buf: PAnsiChar;
begin
  // ���룺��������ȡ������Ϣ
  //  1. ������� -> ��ʼ������
  //  2. ����δ������ɣ���������     

  Respone.FRequest := Self;     // ����
  Respone.FExtParams := FExtParams; // ���ò�����
  Respone.FSender := Sender;    // �������ݷ�����

  // ���ñ�ͷ���棬�ѱ�ͷ����ͷ�������������
  Respone.FHeaders.Owner := TServerTaskSender(Sender);

  Buf := Data^.Data.buf;  // ��ʼ��ַ
  FByteCount := Data^.Overlapped.InternalHigh;  // ���ݰ�����

  if Complete then   // �µ�����
  begin
    // ��ȡ��������Ϣ�����ܴ�������
    ExtractMethod(Buf);

    if (FMethod > hmUnknown) and (FRequestURI <> '') and (FStatusCode = 200) then
    begin
      // ����������ͷ Headers�� Buf ���Ƶ��� 2 �е���λ�ã�
      ExtractHeaders(Buf, Integer(Data^.Overlapped.InternalHigh) -
                          Integer(Buf - Data^.Data.buf));

      // ���� FKeepAlive���ݲ��ó����ӣ�
      Respone.FKeepAlive := FKeepAlive;

      // URI ����, ���� GET ������
      if (FMethod = hmGet) then
        URLDecodeRequestURI;

      // �����Ƿ������¼�
      if Assigned(FDataProvider.FOnAccept) then
      begin
        FDataProvider.FOnAccept(THttpSocket(FOwner).Worker, Self, FAccepted);
        if (FAccepted = False) then
          FStatusCode := 403  // 403: Forbidden
        else
        if (FSessionId <> '') then // ��� FSessionId �Ƿ���Ч
          FAccepted := FDataProvider.CheckSessionState(Self, Respone,
                                     THttpSocket(FOwner).PeerIPPort);
      end;

      // ����Ƿ�Ҫ����Ϊ WebSocket, 15=8+4+2+1
      if FAccepted and (FUpgradeState = 15) and
         Assigned(FDataProvider.FOnUpgrade) then
      begin
        FDataProvider.FOnUpgrade(Self, FHeadersAry[rqhOrigin], FAccepted);
        {$IFDEF DEBUG_MODE}
        if (FAccepted = False) then  // ����Ϊ WebSocket
          iocp_log.WriteLog(THttpSocket(FOwner).PeerIPPort + '->�ܾ���������Ϊ WebSocket.');
        {$ENDIF}
        Exit;
      end;

      // ���
      FUpgradeState := 0;

      {$IFDEF DEBUG_MODE}
      if (FAccepted = False) then
        iocp_log.WriteLog(THttpSocket(FOwner).PeerIPPort +
                          '->�ܾ����� ' + METHOD_LIST[FMethod] + ' ' +
                          FRequestURI + ', ״̬=' + IntToStr(FStatusCode));
      {$ENDIF}
    end else
      FAccepted := False;
      
  end else
  if FAccepted then    // �ϴ����ݰ�������
  begin
    Inc(FContentSize, FByteCount);   // �������� +
    FStream.Write(Buf^, FByteCount); // д����
  end;

  if (FStatusCode > 200) then  
  begin
    FExtParams.Clear;  
    FStream.Clear;
  end else             // �����������
  if FAccepted and Complete and (FStream.Size > 0) then
    if (FMethod = hmPost) and (FContentType <> hctUnknown) then
      try
        if FExtParams.MultiPart then  // ��ȡ���ֶ�
          ExtractElements(FStream.Memory, FStream.Size, FDataProvider.FOnReceiveFile)
        else  // ��ȡ��ͨ����/����
          ExtractParams(FStream.Memory, FStream.Size);
      finally
        FStream.Clear;
      end;

end;

destructor THttpRequest.Destroy;
begin
  FParams.Free;
  FExtParams.Free;  
  FStream.Free;
  inherited;
end;

procedure THttpRequest.ExtractElements(Data: PAnsiChar; Len: Integer;
                                       RecvFileEvent: TOnReceiveFile);
var
  IgnoreSearch: Boolean;
  EleBuf, EleBuf2, TailBuf: PAnsiChar;
  FldType, FldType2: TFormElementType;
  Boundary, EleValue, EleValue2: AnsiString;
begin
  // ��ȡʵ������Ϊ multipart/form-data ���ֶ�/���������� FParams

  // ---------------------Boundary
  // Content-Disposition: form-data; name="textline2"; filename="����.txt"
  // <Empty Line>
  // Value Text
  // ---------------------Boundary--

  //  multipart/form-data���� Form:
  //    �����ַ����롣��ʹ�ð����ļ��ϴ��ؼ��ı�ʱ������ʹ�ø����͡�
  // �ֶ�������1����ͨ���ݣ��� Content-Type
  //           2���ļ����ݣ�Content-Type: text/plain

  try
    EleBuf := Nil;   // �ֶ����ݿ�ʼ
    TailBuf := PAnsiChar(Data + Len);

    // ����ʵ������ʱҪ��ǰ��� '--'�� ȫ���ֶ����ݽ���ʱ����ĩβ�� '--'
    Boundary := '--' + FExtParams.Boundary;

    FldType := fdtUnknown;
    FldType2 := fdtUnknown;
    IgnoreSearch := False;

    while IgnoreSearch or
          SearchInBuffer(Data, TailBuf - Data, Boundary) do
      if (Data^ in [#13, '-']) then  // �ָ���־��ĩβ
      begin
        if (EleBuf = Nil) then   // �ֶο�ʼ��������������λ����λ��
        begin
          // �����س�����
          Inc(Data, 2);

          // �´�Ҫ��ѯ Boundary
          IgnoreSearch := False;

          // �ؼ�������ȱ��ʱ����ѭ��
          if (SearchInBuffer2(Data, 40, 'FORM-DATA') = False) then
          begin
            FStatusCode := 417;   // ����Ԥ�ڣ�Expectation Failed
            Break;
          end;

          // ��λ����λ�ã�����֮���һ���������ֵ������У�STR_CRLF2��
          EleBuf2 := Data;
          if SearchInBuffer(Data, TailBuf - Data, STR_CRLF2) then
          begin
            EleBuf := Data;
            Data := EleBuf2;
          end else
          begin
            FStatusCode := 417;   // ����Ԥ�ڣ�Expectation Failed
            Break;
          end;
                      
          // �Ѿ���λ�� FORM-DATA ��һ�ֽڣ�ȷ���ֶ������Ƿ�Ϊ�ļ�
          FldType := ExtractFieldInf(Data, Integer(EleBuf - Data), EleValue);     // name="xxx"��xxx ����̫��
          FldType2 := ExtractFieldInf(Data, Integer(EleBuf - Data), EleValue2);
          Data := EleBuf;       // ������λ��
          
          if (FldType = fdtUnknown) and (FldType2 = fdtUnknown) then
          begin
            FStatusCode := 417;  // ����Ԥ�ڣ�Expectation Failed
            Break;
          end;

          if (FldType2 = fdtFileName) then   // �ļ�
          begin
            FFileName := EleValue2;
            FldType := fdtName;
          end else
          if (FldType = fdtFileName) then    // �ļ�������ֵ����
          begin
            FFileName := EleValue;
            EleValue := EleValue2;
            FldType2 := fdtFileName;         // �޸�!
          end;

        end else
        begin
          // ��ǰ�ֶ����ݽ��������ֶ����ݿ�ʼ�����˵�ǰ�ֶεĽ���λ��
          EleBuf2 := PAnsiChar(Data - Length(Boundary));

          if (FldType2 = fdtFileName) then
          begin
            // �ļ������ֶΣ�������Ʋ�Ϊ�գ���������Ϊ�գ���������ⲿ�¼�
            try
              FParams.SetAsString(EleValue, FFileName);
              if (FFileName <> '') then
                if Assigned(RecvFileEvent) then
                begin
                  // ִ��һ������
                  RecvFileEvent(THttpSocket(FOwner).Worker, THttpRequest(Self),
                                FFileName, Nil, 0, hpsRequest);
                  RecvFileEvent(THttpSocket(FOwner).Worker, THttpRequest(Self),
                                FFileName, EleBuf, LongWord(EleBuf2 - EleBuf) - 2,
                                hpsRecvData);
                end;
              finally
                Delete(FFileName, 1, Length(FFileName));
              end;
          end else

          if (FldType = fdtName) then
          begin
            // ��ֵ�����ֶΣ����������
            if (EleBuf^ in [#13, #10]) then  // ��ֵ
              FParams.SetAsString(EleValue, '')
            else begin
              // �����������ݣ�û���룬����2�ֽڣ�
              SetString(EleValue2, EleBuf, Longword(EleBuf2 - EleBuf) - 2);
              FParams.SetAsString(EleValue, EleValue2);
            end;
          end else
          begin
            FStatusCode := 417;  // �쳣
            Break;
          end;

          // ����������־��Boundary--
          if ((Data^ = '-') and ((Data + 1)^ = '-')) then
            Break;

          // ׼����һ�ֶ�
          EleBuf := nil;
          IgnoreSearch := True;
        end;
      end;
  except
    on E: Exception do
    begin
      FStatusCode := 500;
      iocp_log.WriteLog('THttpBase.ExtractElements->' + E.Message);
    end;
  end;

end;

procedure THttpRequest.ExtractHeaders(Data: PAnsiChar; DataLength: Integer);
var
  i, k, iPos: Integer;
  p: PAnsiChar;
  Header, HeaderValue: AnsiString;
begin
  // ��ʽ��
  //   Accept: image/gif.image/jpeg,*/*
  //   Accept-Language: zh-cn
  //   Referer: <a href="http://www.google.cn/">http://www.google.cn/</a>
  //   Connection: Keep-Alive
  //   Host: localhost
  //   User-Agent: Mozila/4.0(compatible;MSIE5.01;Window NT5.0)
  //   Accept-Encoding: gzip,deflate
  //   Content-Type: text/plain
  //                 application/x-www-form-urlencoded
  //                 multipart/form-data; boundary=---------------------------7e119f8908f8
  //   Content-Length: 21698
  //   Cookie: ...
  //
  //   Body...

  // 1��application/x-www-form-urlencoded:
  //    �ڷ���ǰ���������ַ���Ĭ�ϣ����ո�ת��Ϊ "+" �Ӻţ��������ת��Ϊ ASCII HEX ֵ��
  // ���ģ�
  //    textline=&textline2=%D2%BB%B8%F6%CE%C4%B1%BE%A1%A3++a&onefile=&morefiles='

  // 2��text/plain: ÿ�ֶ�һ�У����������ַ����롣
  // ���ģ�IE��Chrome����
  //    textline=#13#10textline2=һ���ı���  a#13#10onefile=#13#10morefiles=#13#10

  FAttacked := False;   // �ǹ���
  FAccepted := True;    // Ĭ�Ͻ�������
  FContentLength := 0;  // ʵ�峤��
  FContentType := hctUnknown;  // ʵ������
  FKeepAlive := False;  // Ĭ�ϲ���������
  FUpgradeState := 0;   // ������Ϊ WebSocket

  i := 0;       // ��ʼλ��
  k := 0;       // ����λ��
  iPos := 0;    // �ֺ�λ��
  p := Data;    // ָ��λ��

  while i < DataLength do
  begin
    case p^ of
      CHAR_SC:
        if (iPos = 0) then // ��һ���ֺ� :
          iPos := i;

      CHAR_CR,
      CHAR_LF:             // �н���
        if (iPos > 0) then
        begin
          // ȡ������ֵ
          SetString(Header, Data + k, iPos - k);
          SetString(HeaderValue, Data + iPos + 1, i - iPos - 1);

          // ���� Header �����飺AnsiString -> String
          WriteHeader(GetHeaderIndex(UpperCase(Header)), Trim(HeaderValue));

          // �����쳣
          if (FStatusCode > 200) then
            Exit;
            
          k := i + 1;      // ������λ��
          iPos := 0;

          if ((p + 1)^ = CHAR_LF) then   // ǰ�� 1 �ֽڣ�����β
          begin
            Inc(k);        // ������λ��
            Inc(i);
            Inc(p);
            if ((p + 1)^ = CHAR_CR) then // ����ʵ�� Body
            begin
              Dec(DataLength, i + 3);    // �� 3
              if (DataLength > 0) then   // ��ʵ������
              begin
                if (FContentLength > 0) then  // hctUnknown ʱĩβ���� &
                  FStream.Initialize(FContentLength, FContentType <> hctUnknown);
                if (DataLength <= FContentLength) then
                  FContentSize := DataLength
                else
                  FContentSize := FContentLength;
                FStream.Write((p + 3)^, FContentSize);
              end;
              Break;
            end;
          end;
        end;
    end;
    Inc(i);
    Inc(p);
  end;

  // δ�յ�ʵ�����ݣ�Ԥ��ռ�
  if (FContentLength > 0) and (FStream.Size = 0) then  // Ԥ��ռ�
    FStream.Initialize(FContentLength, FContentType <> hctUnknown);

end;

procedure THttpRequest.ExtractMethod(var Data: PAnsiChar);
  function CheckMethod(const S: AnsiString): THttpMethod;
  var
    i: THttpMethod;
  begin
    // ��������Ƿ�Ϸ�
    for i := hmGet to High(METHOD_LIST) do
      if (S = METHOD_LIST[i]) then
      begin
        Result := i;
        Exit;
      end;
    Result := hmUnknown;
  end;
var
  i, iPos: Integer;
  Method: AnsiString;
  p: PAnsiChar;
begin
  // �������󷽷���URI�Ͱ汾��
  // ��ʽ��GET /sn/index.php?user=aaa&password=ppp HTTP/1.1

  FMethod := hmUnknown; // δ֪
  FRequestURI := '';    // ��
  FStatusCode := 200;   // ״̬

  iPos := 0;  // �ո����ݿ�ʼ��λ��
  p := Data;  // ָ��λ��

  for i := 0 to FByteCount - 1 do  // ��������
  begin
    case p^ of
      CHAR_CR, CHAR_LF: begin  // �س����У����н���
        SetString(FVersion, Data + iPos + 1, i - iPos - 1);
        Break;  // ��һ�з������
      end;
      CHAR_SP, CHAR_TAB:    // �ո�TAB
        if (iPos = 0) then  // �������������ȡ���� GET, POST...
        begin
          if (i < 8) then   // = Length('CONNECT') + 1
          begin
            SetString(Method, Data, i);
            FMethod := CheckMethod(UpperCase(Method));
          end;
          if (FMethod = hmUnknown) then
          begin
            FStatusCode := 400;  // ���������
            Break;
          end else
            iPos := i; // ��һ���ݵĿ�ʼλ��
        end else
        if (FRequestURI = '') then // URI ������ȡ URI
        begin
          SetString(FRequestURI, Data + iPos + 1, i - iPos - 1);
          iPos := i;   // ��һ���ݵĿ�ʼλ��
        end;
    end;
    Inc(p); // ��һ�ַ�
  end;

  // ֧�ְ汾: 1.0, 1.1
  if (FVersion <> HTTP_VER1) and (FVersion <> HTTP_VER) then
    FStatusCode := 505
  else begin
    if (p^ = CHAR_CR) then  // ǰ��������һ����
      Inc(p, 2);
    Data := p;  // Data ָ��������
  end;

end;

procedure THttpRequest.ExtractParams(Data: PAnsiChar; Len: Integer);
var
  i: Integer;
  Buf: PAnsiChar;
  Param, Value: AnsiString;
begin
  // ������������ֶΣ�Ҫ֪�����룩
  // �����룺1��user=aaa&password=ppp&No=123
  //         2��textline=#13#10textline2=һ���ı���  a#13#10onefile=#13#10morefiles=#13#10
  // Ĭ�ϱ��룺textline=&textline2=%D2%BB%B8%F6%CE%C4%B1%BE%A1%A3++a&onefile=&morefiles='
  Buf := Data;
  for i := 1 to Len do   // ĩβ�Ѿ�Ԥ��Ϊ"&"
  begin
    case Data^ of
      '=': begin   // ��������
        SetString(Param, Buf, Data - Buf);
        Buf := Data + 1; // ����һ�ֽ�
      end;
      
      '&', #13:    // ����ֵ���������
        if (Param <> '') then
        begin
          if (Buf = Data) then  // ֵΪ��
            FParams.SetAsString(Param, '')
          else begin
            // �ǿ�ֵ��hctMultiPart ����ʱ���ڴ˴���
            SetString(Value, Buf, Data - Buf);
            if (FContentType <> hctTextPlain) then
            begin
              Value := DecodeHexText(Value);
              if (FExtParams.EncodeType = etUTF8) then
                Value := Trim(System.UTF8Decode(Value));
            end;
            FParams.SetAsString(Param, Value); 
          end;

          // �ƽ�
          if (Data^ = #13) then // �س�
          begin
            Buf := Data + 2;
            Inc(Data, 2);
          end else
          begin
            Buf := Data + 1;
            Inc(Data);
          end;

          // �� Param
          Delete(Param, 1, Length(Param));
        end;
    end;

     // �ƽ�
    Inc(Data);
  end;
end;

function THttpRequest.GetComplete: Boolean;
begin
  // �ж��Ƿ�������
  Result := (FContentLength = 0) or (FContentSize >= FContentLength);
end;

function THttpRequest.GetHeaderIndex(const Header: AnsiString): TRequestHeaderType;
var
  i: TRequestHeaderType;
begin
  // ���� Header ������ REQUEST_HEADERS ��λ��
  for i := rqhHost to High(TRequestHeaderType) do
    if (REQUEST_HEADERS[i] = Header) then
    begin
      Result := i;
      Exit;
    end;
  Result := rqhUnknown;
end;

function THttpRequest.GetHeaders(Index: TRequestHeaderType): AnsiString;
begin
  Result := FHeadersAry[Index];
end;

procedure THttpRequest.URLDecodeRequestURI;
var
  i: Integer;
  ParamList: AnsiString;
begin
  // URI ���룬��ȡ����
  // ����� GET ����Ĳ�����/aaa/ddd.jsp?code=111&name=WWW
  for i := 1 to Length(FRequestURI) do
    if (FRequestURI[i] = AnsiChar('?')) then
    begin
      SetLength(ParamList, Length(FRequestURI) - i + 1); // ��һ���ֽ�
      ParamList[Length(ParamList)] := AnsiChar('&'); // ĩβ��Ϊ &

      System.Move(FRequestURI[i + 1], ParamList[1], Length(ParamList) - 1);
      ExtractParams(@ParamList[1], Length(ParamList)); // ��ȡ������

      Delete(FRequestURI, i, Length(FRequestURI));
      Exit;
    end;
  if (Pos('%', FRequestURI) > 0) then  // ����Ϊ˫�ֽ��ļ�
    FRequestURI := http_utils.URLDecode(FRequestURI);
end;

procedure THttpRequest.WriteHeader(Index: TRequestHeaderType; const Content: AnsiString);
var
  i: Int64;
  StrName, StrValue: AnsiString;
begin
  // ���� Content ����ͷ����

  FHeadersAry[Index] := Content;

  // ����������Ӷ���ı���/����
  
  case Index of
    rqhAcceptCharset: begin  // TNetHttpClient
      if (Pos('UTF-8', UpperCase(Content)) > 0) then
        FExtParams.SetAsInteger('ENCODE-TYPE', Integer(etUTF8))
      else
        FExtParams.SetAsInteger('ENCODE-TYPE', Integer(etNone));
    end;

    rqhContentLength:
      // Content-Length: ���賤�ȱ���, �ļ�̫��ʱ��IE < 0, Chrome ����
      if (TryStrToInt64(Content, i) = False) then
        FStatusCode := 417    // 417 Expectation Failed
      else
        if (i < 0) or (i > FDataProvider.FMaxContentLength) then
        begin
          FStatusCode := 413;     // ����̫����413 Request Entity Too Large
          FExtParams.SetAsInteger('CONTENT-LENGTH', 0);
        end else
        begin
          // 10 ����ͬһ IP ���� 3 �� >= 10M �����󣬵�������
          if (i >= 10240000) and Assigned(FDataProvider.FPeerIPList) then
            FAttacked := FDataProvider.FPeerIPList.CheckAttack(THttpSocket(FOwner).PeerIP, 10000, 3)
          else
            FAttacked := False;

          if FAttacked then       // �����
            FStatusCode := 403    // 403 Forbidden
          else begin
            FContentLength := i;   // ���س��� i
            FExtParams.SetAsInteger('CONTENT-LENGTH', i);
          end;
        end;

    rqhConnection:  // Connection: Upgrade��Keep-Alive
      if (UpperCase(Content) = 'UPGRADE') then  // ֧�� WebSocket
      begin
        FUpgradeState := FUpgradeState xor 1;
        FKeepAlive := True;
      end else
      if (UpperCase(Content) = 'KEEP-ALIVE') then
      begin
        FKeepAlive := FDataProvider.FKeepAlive;
        FExtParams.SetAsBoolean('KEEP-ALIVE', FKeepAlive);
      end else
        FExtParams.SetAsBoolean('KEEP-ALIVE', False);

    rqhContentType: begin
      // Content-Type: text/plain
      //               application/x-www-form-urlencoded
      //               multipart/form-data; boundary=...
      // ��������������CONTENT-TYPE��MULTIPART��BOUNDARY
      StrValue := LowerCase(Content);
      if (FMethod = hmGet) then
      begin
        if (Pos('%', FRequestURI) > 0) then
        begin
          FContentType := hctUrlEncoded;
          FExtParams.SetAsInteger('CONTENT-TYPE', Integer(hctUrlEncoded));
        end;
        if (Pos('utf-8', StrValue) > 1) then
          FExtParams.SetAsInteger('ENCODE-TYPE', Integer(etUTF8));
      end else
        if (StrValue = 'text/plain') then
        begin
          FContentType := hctTextPlain;
          FExtParams.SetAsString('BOUNDARY', '');
          FExtParams.SetAsInteger('CONTENT-TYPE', Integer(hctTextPlain));
          FExtParams.SetAsBoolean('MULTIPART', False);
        end else
        if (Pos('application/x-www-form-urlencoded', StrValue) = 1) then
        begin
          FContentType := hctUrlEncoded;
          FExtParams.SetAsString('BOUNDARY', '');
          FExtParams.SetAsInteger('CONTENT-TYPE', Integer(hctUrlEncoded));
          FExtParams.SetAsBoolean('MULTIPART', False);
        end else
        if (Pos('multipart/form-data', StrValue) = 1) then
        begin
          FStatusCode := 417; // ����Ԥ��
          i := PosEx('=', Content, 28);
          if (i >= 29) then   // multipart/form-data; boundary=...
          begin
            StrValue := Copy(Content, i + 1, 999);
            if (StrValue <> '') then
            begin
              FContentType := hctMultiPart;
              FExtParams.SetAsString('BOUNDARY', StrValue);
              FExtParams.SetAsInteger('CONTENT-TYPE', Integer(hctMultiPart));
              FExtParams.SetAsBoolean('MULTIPART', True);
              FStatusCode := 200;
            end;
          end;
        end else
        begin
          // ������ͨ���������޲���
          FContentType := hctUnknown;
          FExtParams.SetAsInteger('CONTENT-TYPE', Integer(hctUnknown));
        end;
    end;

    rqhCookie:  // �½�һ�� Session�����ü��� Hash ��
      if THttpSession.Extract(Content, StrName, StrValue) then
      begin
        FAttacked := FDataProvider.FSessionMgr.CheckAttack(StrValue);
        if FAttacked then  // ���� SessionId ����
          FAccepted := False
        else               // ������Ч SessionId
        if (StrValue <> HTTP_INVALID_SESSION) then
          FSessionId := StrValue;
      end;

    rqhIfMatch,
    rqhIfNoneMatch:
      FExtParams.SetAsString('IF_MATCH', Copy(Content, 2, Length(Content) - 2));

    rqhIfRange: begin  // �ϵ�����
      StrValue := Copy(Content, 2, Length(Content) - 2);
      FExtParams.SetAsString('IF_MATCH', StrValue);
      FExtParams.SetAsString('IF_RANGE', StrValue);
    end;

    rqhRange:  // �ϵ�����
      FExtParams.SetAsString('RANGE', Content);

    rqhIfModifiedSince,
    rqhIfUnmodifiedSince:
      FExtParams.SetAsString('LAST_MODIFIED', Content);

    rqhUserAgent:  // 'Mozilla/4.0 (compatible; MSIE 8.0; ...
      if Pos('MSIE ', Content) > 0 then
        FExtParams.SetAsBoolean('MSIE', True);

    // ֧�� WebSocket
    //  Connection: Upgrade
    //  Upgrade: websocket    
    //  Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==
    //  Sec-WebSocket-Protocol: chat, superchat
    //  Sec-WebSocket-Version: 13
    //  Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits
    //  Origin: http://example.com

    rqhUpgrade:  // ������ WebSocket
      if (UpperCase(Content) = 'WEBSOCKET') then
        FUpgradeState := FUpgradeState xor 2;

    rqhWebSocketKey:
      if (Length(Content) > 0) then
        FUpgradeState := FUpgradeState xor 4;

    rqhWebSocketVersion:
      if (Content = '13') then
        FUpgradeState := FUpgradeState xor 8;
  end;

end;

{ THttpResponeHeaders }

procedure THttpResponeHeaders.Add(Code: TResponeHeaderType; const Content: AnsiString);
begin
  // ���ӱ�ͷ��Ϣ
  if (Code = rshUnknown) then  // �Զ���
  begin
    if (Content <> '') then  // ��ʱ����
      InterAdd(Content);
  end else
  if (FHeaders[Code] = False) then
  begin
    FHeaders[Code] := True;
    case Code of
      rshDate:
        InterAdd(RESPONE_HEADERS[Code] + CHAR_SC2 + GetHttpGMTDateTime);
      rshServer:
        InterAdd(RESPONE_HEADERS[Code] + CHAR_SC2 + HTTP_SERVER_NAME);
      else
        InterAdd(RESPONE_HEADERS[Code] + CHAR_SC2 + Content);
    end;
  end;
end;

procedure THttpResponeHeaders.AddCRLF;
begin
  // �ӻس�����
  PStrCRLF(FBuffer)^ := STR_CRLF;
  Inc(FBuffer, 2);
  Inc(FData^.len, 2);
end;

procedure THttpResponeHeaders.Append(var AHandle: THandle; ASize: Cardinal);
begin
  // ׷���ļ����ݣ�ʵ�壩
  try
    Windows.ReadFile(AHandle, FBuffer^, ASize, ASize, Nil);
    Inc(FBuffer, ASize);
    Inc(FData^.len, ASize);
  finally
    CloseHandle(AHandle);
    AHandle := 0;  // ���룬��������Դʱ�쳣 
  end;
end;

procedure THttpResponeHeaders.Append(var AStream: TStream; ASize: Cardinal);
begin
  // ׷����������ʵ�壩
  try
    AStream.Read(FBuffer^, ASize);
    Inc(FBuffer, ASize);
    Inc(FData^.len, ASize);
  finally
    AStream.Free;
    AStream := nil;  // ���룬��������Դʱ�쳣 
  end;
end;

procedure THttpResponeHeaders.Append(AList: TInStringList; ASize: Cardinal);
var
  i: Integer;
  S: AnsiString;
begin
  // ׷���б����ݣ�ʵ�壩
  try
    for i := 0 to AList.Count - 1 do
    begin
      S := AList.Strings[i];
      System.Move(S[1], FBuffer^, Length(S));
      Inc(FBuffer, Length(S));
    end;
    Inc(FData^.len, ASize);
  finally
    AList.Clear;
  end;
end;

procedure THttpResponeHeaders.Append(Content: AnsiString; SetCRLF: Boolean);
begin
  // �����ַ�����һ�����ݣ�
  InterAdd(Content, SetCRLF);
end;

procedure THttpResponeHeaders.ChunkDone;
begin
  PAnsiChar(FData^.buf)^ := AnsiChar('0');  // 0
  PStrCRLF2(FData^.buf + 1)^ := STR_CRLF2;  // �س�����, ����
  FData^.len := 5;
end;

procedure THttpResponeHeaders.ChunkSize(ASize: Cardinal);
begin
  if (ASize > 0) then
  begin
    // �޸� Chunk ���ȣ��ڵ�ǰλ�ü� STR_CRLF��������䳤��
    PChunkSize(FData.buf)^ := PChunkSize(AnsiString(IntToHex(ASize, 4)) + STR_CRLF)^;
    PStrCRLF(FBuffer)^ := STR_CRLF;
    Inc(FData^.len, 8);
  end else
  begin  // ��գ�ǰ�� 6 �ֽ�
    FBuffer := FData^.buf;
    FData^.len := 0;
    Inc(FBuffer, 6);  // ֻ�������������ռ�
  end;
end;

procedure THttpResponeHeaders.Clear;
begin
  // д���ַ�ָ�����ʼλ��
  FillChar(FHeaders, SizeOf(THeaderArray), 0);
  if Assigned(FBuffer) and (FData^.len > 0) then
  begin
    FBuffer := FData^.buf;
    FData^.len := 0;
  end;
end;

function THttpResponeHeaders.GetSize: Integer;
begin
  // ȡ�������ݳ���
  Result := FData^.len;
end;

procedure THttpResponeHeaders.InterAdd(const Content: AnsiString; SetCRLF: Boolean);
begin
  // ���ӱ�ͷ��Ŀ
  // �磺Server: InIOCP/2.0

  // ��������
  System.Move(Content[1], FBuffer^, Length(Content));
  Inc(FData^.len, Length(Content));
  Inc(FBuffer, Length(Content));

  // �ӻس�����
  if SetCRLF then
  begin
    PStrCRLF(FBuffer)^ := STR_CRLF;
    Inc(FData^.len, 2);    
    Inc(FBuffer, 2);
  end;
end;

procedure THttpResponeHeaders.SetOwner(const Value: TServerTaskSender);
begin
  // ��ʼ��
  FOwner := Value;
  FData := FOwner.Data;
  FData^.len := 0;
  FBuffer := FData^.buf;
end;

procedure THttpResponeHeaders.SetStatus(Code: Integer);
begin
  // ������Ӧ״̬
  Clear;
  case Code div 100 of
    1:
      InterAdd(HTTP_VER + HTTP_STATES_100[Code - 100]);
    2:
      InterAdd(HTTP_VER + HTTP_STATES_200[Code - 200]);
    3:
      InterAdd(HTTP_VER + HTTP_STATES_300[Code - 300]);
    4:
      InterAdd(HTTP_VER + HTTP_STATES_400[Code - 400]);
    else
      InterAdd(HTTP_VER + HTTP_STATES_500[Code - 500]);
  end;
end;

{ THttpRespone }

procedure THttpRespone.AddContent(const Content: AnsiString);
begin
  // ����ʵ������
  FContent.Add(Content);
  FContentSize := FContent.Size;  // ��
end;

procedure THttpRespone.AddDataPackets;
var
  ETag, LastModified: AnsiString;

  procedure AddPacket(Range: AnsiString);
  var
    StartPos, EndPos: Integer;
  begin

    // ������Χ
    EndPos := 0;
    if (Range[1] = '-') then    // -235
    begin
      StartPos := StrToInt(Copy(Range, 2, 99));
      if (FContentSize >= StartPos) then
      begin
        StartPos := FContentSize - StartPos;
        EndPos := FContentSize - 1;
      end else
        FStatusCode := 416;     //  416 Requested range not satisfiable
    end else
    if (Range[Length(Range)] = '-') then    // 235-
    begin
      Delete(Range, Length(Range), 1);
      StartPos := StrToInt(Range);
      if (FContentSize >= StartPos) then
        EndPos := FContentSize - 1
      else
        FStatusCode := 416;     //  416 Requested range not satisfiable
    end else                    // 235-2289
    begin
      EndPos := Pos('-', Range);
      StartPos := StrToInt(Copy(Range, 1, EndPos - 1));
      EndPos := StrToInt(Copy(Range, EndPos + 1, 99));
      if (StartPos > EndPos) or (EndPos >= FContentSize) then
        FStatusCode := 416;     //  416 Requested range not satisfiable
    end;

    if (FStatusCode <> 416) then
    begin
      SetStatus(206);
      FHeaders.Add(rshServer);
      FHeaders.Add(rshDate);

      FHeaders.Add(rshAcceptRanges, 'bytes');
      FHeaders.Add(rshContentType, FContentType);

      if (FSessionId <> '') then
        FHeaders.Add(rshSetCookie, HTTP_SESSION_ID + '=' + FSessionId);

      // ���ݿ鳤��
      FHeaders.Add(rshContentLength, IntToStr(EndPos - StartPos + 1));

      // ��Χ����ʼ-��ֹ/�ܳ�
      FHeaders.Add(rshContentRange, 'bytes ' + IntToStr(StartPos) + '-' +
                   IntToStr(EndPos) + '/' + IntToStr(FContentSize));

      FHeaders.Add(rshETag, ETag);
      FHeaders.Add(rshLastModified, LastModified);

      if FKeepAlive then
        FHeaders.Add(rshConnection, 'keep-alive')
      else
        FHeaders.Add(rshConnection, 'close');

      // �ȷ��ͱ�ͷ
      FHeaders.AddCRLF;
      FSender.SendBuffers;

      // �����ļ�ʵ��
      if (FSender.ErrorCode = 0) then
        FSender.Send(FHandle, FContentSize, StartPos, EndPos);
    end;
  end;
var
  i: Integer;
  RangeList: AnsiString;
begin
  // �ϵ�����
  //  ����Ҫ���͵����ݿ鷶Χ
  //  ����ͬʱ��������Χ����֧�� TransmitFile ����

  ETag := '"' + GetFileETag + '"';
  LastModified := GetHttpGMTDateTime(TFileTime(FLastWriteTime));
  RangeList := FExtParams.Range + ','; //  'bytes=123-145,1-1,-23,900-,';

  i := Pos('=', RangeList);
  Delete(RangeList, 1, i);

  i := Pos(',', RangeList);
  repeat
    AddPacket(Copy(RangeList, 1, i - 1));  // ����һ�����ݿ鷢������
    // ����Χ���󡢷����쳣 -> �˳�
    if (FStatusCode = 416) or (FSender.ErrorCode <> 0) then
      Break
    else begin
      Delete(RangeList, 1, i);
      i := Pos(',', RangeList);
    end;
  until i = 0;

end;

procedure THttpRespone.AddHeader(Code: TResponeHeaderType; const Content: AnsiString);
begin
  // ���ӱ�ͷ��Ϣ
  if (FStatusCode = 0) then
    FStatusCode := 200;
  if (FHeaders.Size = 0) then
  begin
    SetStatus(FStatusCode);
    FHeaders.Add(rshServer);
    FHeaders.Add(rshDate);
  end;
  FHeaders.Add(Code, Content);
end;

procedure THttpRespone.AddHeaderList(SendNow: Boolean);
begin
  // ׼��״̬����ͷ
  if (FStatusCode = 0) then
    FStatusCode := 200;
  if (FHeaders.Size = 0) then
  begin
    SetStatus(FStatusCode);
    FHeaders.Add(rshServer);
    FHeaders.Add(rshDate);
  end;

  if (FStatusCode < 400) and (FStatusCode <> 204) then
  begin
    // ͳһʹ�� gb2312
    // �� text/html: IE 8 ��������, Chrome ����
    if (FContentType <> '') then
      FHeaders.Add(rshContentType, FContentType + '; CharSet=gb2312')
    else
    if (FContent.Count > 0) or (FContentSize = 0) then
      FHeaders.Add(rshContentType, 'text/html; CharSet=gb2312')
    else
      FHeaders.Add(rshContentType, 'text/plain; CharSet=gb2312');

    // ����Դ
    if (FContent.Count > 0) then
    begin
      // html �ű�
      FHeaders.Add(rshContentLength, IntToStr(FContentSize));
    end else
    if Assigned(FStream) then
    begin
      // �ڴ�/�ļ���
      if FGZipStream then
        FHeaders.Add(rshContentEncoding, 'gzip');
      FHeaders.Add(rshContentLength, IntToStr(FContentSize));
    end else
    if (FContentSize > 0) and (FLastWriteTime > 0) then
    begin
      // �ļ�����������ļ���Ǻ��ļ��� UTC �޸�ʱ�䣨64λ����ȷ��ǧ���֮һ�룩
      FHeaders.Add(rshContentLength, IntToStr(FContentSize));
      FHeaders.Add(rshAcceptRanges, 'bytes');
      FHeaders.Add(rshETag, '"' + GetFileETag + '"');
      FHeaders.Add(rshLastModified, GetHttpGMTDateTime(TFileTime(FLastWriteTime)));
      // Content-Disposition������������أ�����ֱ�Ӵ򿪡�
      if (FFileName <> '') then
        FHeaders.Add(rshUnknown, 'Content-Disposition: attachment; filename=' + FFileName);
    end;

    FHeaders.Add(rshCacheControl, 'No-Cache');

    if FKeepAlive then
      FHeaders.Add(rshConnection, 'keep-alive')
    else
      FHeaders.Add(rshConnection, 'close');
  end else
  begin
    // �쳣������ FContent ������
    FHeaders.Add(rshContentLength, IntToStr(FContent.Size));
    if (FContent.Size > 0) then
    begin
      FHeaders.AddCRLF;
      FHeaders.Append(FContent, FContent.Size);
    end;
  end;

  // ���� SessionId
  if (FSessionId <> '') then
    FHeaders.Add(rshSetCookie, HTTP_SESSION_ID + '=' + FSessionId);

  // ��ͷ����������
  FHeaders.AddCRLF;
  if SendNow then
    FSender.SendBuffers;
  
end;

procedure THttpRespone.Clear;
begin
  inherited;
  FreeResources;
  FContentType := '';
  FGZipStream := False;
  FLastWriteTime := 0;
  FWorkDone := False;
end;

constructor THttpRespone.Create(ADataProvider: THttpDataProvider; AOwner: TObject);
begin
  inherited;
  FContent := TInStringList.Create;   // ��Ϣ����
  FHeaders := THttpResponeHeaders.Create; // ������״̬����ͷ
end;

procedure THttpRespone.CreateSession;
var
  Session: THttpSession;
begin
  // �½� SessionId
  Session := THttpSession.Create(HTTP_SESSION_ID);
  FSessionId := Session.FValue;
  FDataProvider.FSessionMgr.Add(Session.FValue, Session);  // ���� Hash ��
end;

destructor THttpRespone.Destroy;
begin
  FreeResources;
  FHeaders.Free;
  FContent.Free;
  inherited;
end;

procedure THttpRespone.FreeResources;
begin
  if Assigned(FStream) then
  begin
    FStream.Free;
    FStream := nil;
  end;
  if (FHandle > 0) then
  begin
    CloseHandle(FHandle);
    FHandle := 0;
  end;
  if (FContent.Count > 0) then
    FContent.Clear;
end;

function THttpRespone.GetFileETag: AnsiString;
begin
  // ȡ�ļ���ʶ��ԭ������Ψһ�ģ�
  Result := IntToHex(FLastWriteTime, 2) + '-' + IntToHex(FContentSize, 4);
end;

function THttpRespone.GZipCompress(Stream: TStream): TStream;
begin
  // GZip ѹ�����������ļ���
  Result := TFileStream.Create(iocp_varis.gTempPath + '_' +
                        IntToStr(NativeUInt(Self)) + '.tmp', fmCreate);
  try
    Stream.Position := 0;    // ����
    iocp_zlib.GZCompressStream(Stream, Result, '');
  finally
    Stream.Free;
  end;
end;

procedure THttpRespone.InvalidSession;
begin
  // ������Ч�� SessionId���������ͻ���
  if (FSessionId <> '') then
    FDataProvider.FSessionMgr.Remove(FSessionId);
  FSessionId := HTTP_INVALID_SESSION;
  SetContent(HTTP_INVALID_SESSION);
end;

procedure THttpRespone.Redirect(const URL: AnsiString);
begin
  // ��λ��ָ���� URL
  SetStatus(302);  // 302 Found, 303 See Other
  FHeaders.Add(rshServer);
  FHeaders.Add(rshLocation, URL);
  FHeaders.AddCRLF;       
end;

procedure THttpRespone.SendWork;
  procedure AppendEntityData;
  begin
    // ��Сʵ�����ݼ��뵽 FHeaders ֮��
    if (FHandle > 0) then        // ������ Handle ��
      FHeaders.Append(FHandle, FContentSize)
    else
    if (Assigned(FStream)) then  // ������
      FHeaders.Append(FStream, FContentSize)
    else
    if (FContent.Count > 0) then // ����ʵ���б�
      FHeaders.Append(FContent, FContentSize);
  end;
  procedure SendEntityData;
  begin
    // ����ʵ������
    {$IFDEF TRANSMIT_FILE}
    // 1. �� TransmitFile ����
    //    ������ɻ��쳣���� THttpSocket.ClearResources ��
    //    �ͷ���Դ FHandle �� FStream
    with TBaseSocketRef(FOwner) do
      if (FHandle > 0) then  // �ļ���� Handle
        FTask.SetTask(FHandle, FContentSize)
      else
      if Assigned(FStream) then  // ��
        FTask.SetTask(FStream, FContentSize)
      else
      if (FContent.Count > 0) then  // ����ʵ���б�
      begin
        FTask.SetTask(FContent.HttpString[False]);
        FContent.Clear;
      end;
    {$ELSE}
    // 2. �� WSASend ����, �Զ��ͷ� FHandle��FStream
    if (FHandle > 0) then  // �ļ���� Handle
      FSender.Send(FHandle, FContentSize)
    else
    if Assigned(FStream) then  // ��
      FSender.Send(FStream, FContentSize, True)
    else
    if (FContent.Count > 0) then // ����ʵ���б�
    begin
      FSender.Send(FContent.HttpString[False]);
      FContent.Clear;
    end;
    {$ENDIF}
  end;
begin
  // ��ʽ��������

  if (FStatusCode = 206) then   // 1. �ϵ�����
  begin
    AddDataPackets;
    if (FStatusCode = 416) then // ����Χ����
    begin
      Clear;  // �ͷ���Դ
      AddHeaderList(True);
    end;
  end else

  if (FWorkDone = False) then   // 2. ��ͨ����
    if (FStatusCode >= 400) or (FSender.ErrorCode > 0) then   // 2.1 �쳣
      AddHeaderList(True)       // ��������
    else begin
      AddHeaderList(False);     // �Ȳ�����
      if (FContentSize + FHeaders.Size <= IO_BUFFER_SIZE) then
      begin
        // 2.2 ���ͻ��滹װ����ʵ��
        if (FContentSize > 0) then
          AppendEntityData;       // ����ʵ������
        FSender.SendBuffers;  // ��ʽ����
      end else
      begin
        // 2.3 ʵ��̫��, �ȷ���ͷ����ʵ��
        FSender.SendBuffers;  // ��ʽ����
        SendEntityData;  // ��ʵ��
      end;         
    end;

  {$IFDEF DEBUG_MODE}
  iocp_log.WriteLog(TBaseSocket(FOwner).PeerIPPort +
                    '->ִ������ ' + METHOD_LIST[FRequest.FMethod] + ' ' +
                    FRequest.FRequestURI + ', ״̬=' + IntToStr(FStatusCode));
  {$ENDIF}

  {$IFDEF TRANSMIT_FILE}
  TBaseSocketRef(FOwner).InterTransmit;
  {$ELSE}
  FHandle := 0;    // �Ѿ�����
  FStream := nil;  // �Ѿ�����
  {$ENDIF}

end;

procedure THttpRespone.SendChunk(Stream: TStream);
begin
  // �����ֿ鷢�ͣ����ⲿ�ͷ� Stream��
  //   HTTP Э�鲻�ܶԵ������ѹ�������崫��ʱ���ԣ�
  //   ��֧�� TransmitFile ģʽ�������ݣ�
  FreeResources;
  if (Assigned(Stream) = False) then
    FStatusCode := 204
  else
    try
      // ���͵����ݽṹ��
      // 1. ��ͷ��
      // 2. ���� + �س����� + ���� + �س����У�
      // 3. "0" + �س����� + �س�����

      // 1. ���ͱ�ͷ
      SendChunkHeaders;

      // 2. ���͵��Ƶ�ʵ��
      TServerTaskSender(FSender).Chunked := True; // �ֿ鷢�ͣ�
      FSender.Send(Stream, Stream.Size, False); // ���ͷ���!
    finally
      FWorkDone := True;
      if (Stream is TMemoryStream) then
        Stream.Size := 0;
    end;
end;

procedure THttpRespone.SendChunkHeaders(const ACharSet: AnsiString);
begin
  // ���ͷֿ�����
  SetStatus(200);

  FHeaders.Add(rshServer);
  FHeaders.Add(rshDate);
  FHeaders.Add(rshContentType, CONTENT_TYPES[0].ContentType + ACharSet);

  if (FSessionId <> '') then
    FHeaders.Add(rshSetCookie, HTTP_SESSION_ID + '=' + FSessionId);

  FHeaders.Add(rshTransferEncoding, 'chunked');
  FHeaders.Add(rshCacheControl, 'no-cache, no-store');
  FHeaders.Add(rshPragma, 'no-cache');
  FHeaders.Add(rshExpires, '-1');

  // ��ͷ����������
  FHeaders.AddCRLF;
  FSender.SendBuffers;

end;

procedure THttpRespone.SendJSON(DataSet: TDataSet; CharSet: THttpCharSet);
begin
  // �Ѵ����ݼ�תΪ JSON �ֿ鷢�ͣ��������ͣ�
  // CharSet���Ѽ�¼ת��Ϊ��Ӧ���ַ���
  SendChunkHeaders(HTTP_CHAR_SETS[CharSet]);  // ���ͱ�ͷ
  try
    LargeDataSetToJSON(DataSet, FHeaders, CharSet);  // �� JSON������
  finally
    FWorkDone := True; // �Ľ����ڷ������Զ����ͽ�����־
  end;
end;

procedure THttpRespone.SendJSON(JSON: AnsiString);
begin
  // ����Ҫ���͵� JSON�����������ͣ�
  SetContent(JSON);
end;

procedure THttpRespone.SendStream(Stream: TStream; Compress: Boolean);
begin
  // ׼��Ҫ���͵�������

  FreeResources;
  if Assigned(Stream) then
  begin
    FContentSize := Stream.Size;
    if (FContentSize > MAX_TRANSMIT_LENGTH) then  // ̫��
    begin
      FContentSize := 0;
      FStatusCode := 413;
    end else
    begin
      if Compress then  // ѹ��
      begin
        FStream := GZipCompress(Stream);  // ѹ�����ļ������ͷ� Stream
        FContentSize := FStream.Size; // �ı�
      end else
        FStream := Stream;  // ��ѹ��
      FGZipStream := Compress;
      FContentType := CONTENT_TYPES[0].ContentType;
    end;
  end else
    FStatusCode := 204;
    
end;

procedure THttpRespone.SetContent(const Content: AnsiString);
begin
  // ��һ�μ���ʵ������
  if (FContent.Count > 0) then
    FContent.Clear;
  FContent.Add(Content);
  FContentSize := FContent.Size;  // ��
end;

procedure THttpRespone.SetHead;
begin
  // ���� Head �������Ϣ
  SetStatus(200);

  FHeaders.Add(rshServer);
  FHeaders.Add(rshDate);
  FHeaders.Add(rshAllow, 'GET, POST, HEAD');  // CONNECT, DELETE, PUT, OPTIONS, TRACE');
  FHeaders.Add(rshContentType, 'text/html; CharSet=gb2312');
  FHeaders.Add(rshContentLang, 'zh-cn,zh;q=0.8,en-us;q=0.5,en;q=0.3');
  FHeaders.Add(rshContentEncoding, 'gzip, deflate');
  FHeaders.Add(rshContentLength, IntToStr(FDataProvider.FMaxContentLength));
  FHeaders.Add(rshCacheControl, 'no-cache');
  FHeaders.Add(rshTransferEncoding, 'chunked');

  if FKeepAlive then
    FHeaders.Add(rshConnection, 'keep-alive')
  else
    FHeaders.Add(rshConnection, 'close');

  // ��ͷ����
  FHeaders.AddCRLF;
  
end;

procedure THttpRespone.SetStatus(Code: Integer);
begin
  // ������Ӧ״̬
  FStatusCode := Code;
  FHeaders.SetStatus(Code);
end;

procedure THttpRespone.TransmitFile(const FileName: String; AutoView: Boolean);
var
  ETag: AnsiString;
  TempFileName: String;
  lpCreationTime, lpLastAccessTime: _FILETIME;
begin
  // ���ļ���Դ
  // http://blog.csdn.net/xiaofei0859/article/details/52883500

  FreeResources;

  TempFileName := AdjustFileName(FileName);
  if (FileExists(TempFileName) = False) then
  begin
    FStatusCode := 404;
    SetContent('<html><body>InIOCP/2.0: ҳ�治���ڣ�</body></html>');
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('THttpRespone.TransmitFile->�ļ������ڣ�' + FileName);
    {$ENDIF}
    Exit;
  end;

  // InternalOpenFile �� INVALID_HANDLE_VALUE תΪ 0
  FHandle := InternalOpenFile(TempFileName);

  if (FHandle > 0) then
  begin
    // �� �ļ���С + �޸�ʱ�� ���� ETag
    FContentSize := GetFileSize64(FHandle);

    if (FContentSize > MAX_TRANSMIT_LENGTH) then     // �ļ�̫��
    begin
      FContentSize := 0;
      FStatusCode := 413;
      CloseHandle(FHandle);
      FHandle := 0;
      Exit;
    end;

    // ���� FFileName��chrome ������Ժ�ϵ�����
    if not AutoView or (FContentSize > 4096000) then
      FFileName := ExtractFileName(FileName);

    GetFileTime(FHandle, @lpCreationTime, @lpLastAccessTime, @FLastWriteTime);

    ETag := GetFileETag;
    if (ETag = FExtParams.IfMath) and
       (GetHttpGMTDateTime(TFileTime(FLastWriteTime)) = FExtParams.LastModified) then
    begin
      if (FExtParams.Range <> '') then  // ����ϵ�����
      begin
        FStatusCode := 206;     // �������������ݿ飬��Сδ��
        FContentType := CONTENT_TYPES[0].ContentType;
      end else
      begin
        FStatusCode := 304;     // 304 Not Modified���ļ�û�޸Ĺ�
        FContentSize := 0;
        FLastWriteTime := 0;
        CloseHandle(FHandle);
        FHandle := 0;
      end;
    end else
    begin
      if (FExtParams.Range <> '') then  // ����ϵ�����
      begin
        FStatusCode := 206;     // �������������ݿ飬��Сδ��
        FContentType := CONTENT_TYPES[0].ContentType;
      end else
        FContentType := GetContentType(FileName);
    end;
  end else
  begin
    FStatusCode := 500;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('THttpRespone.TransmitFile->���ļ��쳣��' + FileName);
    {$ENDIF}
  end;

end;

procedure THttpRespone.Upgrade;
begin
  // ����Ϊ WebSocket������
  FHeaders.SetStatus(101);

  FHeaders.Add(rshServer); // ��ѡ
  FHeaders.Add(rshDate);   // ��ѡ
    
  FHeaders.Add(rshConnection, 'Upgrade');
  FHeaders.Add(rshUpgrade, 'WebSocket');
  FHeaders.Add(rshWebSocketAccept, iocp_SHA1.EncodeBase64(
           iocp_SHA1.SHA1StringA(FRequest.GetHeaders(rqhWebSocketKey) +
                                 WSOCKET_MAGIC_GUID)));

  FHeaders.Add(rshContentType, 'text/html; charSet=utf-8'); // ��ѡ
  FHeaders.Add(rshContentLength, '0'); // ��ѡ
  FHeaders.AddCRLF;
  
  FSender.SendBuffers;
end;

end.
