(*
 * iocp c/s ������Ϣ��װ��Ԫ
 *)
unit iocp_msgPacks;

interface

{$I in_iocp.inc}

uses
  Windows, Classes, SysUtils, Variants,
  iocp_winSock2, iocp_md5, iocp_mmHash,
  iocp_zlib, iocp_base, iocp_lists,
  iocp_baseObjs;

type

  { TMemBuffer: �Զ����ڴ�� }

  TMemBuffer = Pointer;

  // ================ ��չ���ڴ��� ================
  // ���Դ��ⲿ�����ڴ�飬����д��

  TInMemStream = class(TMemoryStream)
  private
    FSetMode: Boolean;   // �����ڴ�ģʽ
    FNewSize: Longint;   // �ڴ泤��
  protected
    function Realloc(var NewCapacity: Longint): Pointer; override;
  public
    procedure Clear;
    procedure Initialize(ASize: Cardinal; AddTag: Boolean);
    procedure SetMemory(ABuffer: Pointer; ASize: Longint);
  end;

  // ================== �ļ�����չ �� ======================
  //  ���ļ������� TFileStream �Ĳ�ͬ
  //  �Զ�ɾ����ʱ�ļ����ο� THandleStream

  TReceivePack = class;

  TIOCPDocument = class(THandleStream)
  private
    FFileName: String;         // �ļ���
    FUserName: String;         // ������
    FTempFile: Boolean;        // ��ʱ�ļ�
    FOriginSize: TFileSize;    // �ļ����ȣ��رպ��ã�
    FCreationTime: TFileTime;  // ����ʱ��
    FAccessTime: TFileTime;    // ����ʱ��
    FLastWriteTime: TFileTime; // �޸�ʱ��
    procedure InternalCreate(const AFileName: String; CreateNew: Boolean);
  public
    constructor Create(const AFileName: String = ''; CreateNew: Boolean = False);
    constructor CreateEx(const AFileName: String);
    destructor Destroy; override;
    procedure Close(DelFile: Boolean = False);
    procedure RenameFileName(AFileName: String);
    procedure SetFileInf(Params: TReceivePack);
  public
    property FileName: String read FFileName;
    property OriginSize: TFileSize read FOriginSize;
    property UserName: String read FUserName;
  end;

  // ================== �ֶζ��� �� ======================

  // ����/�ֶζ���(�ַ����� AnsiSting)

  TBasePack = class;

  TVarField = class(TObject)
  private
    FName: AnsiString;     // ����
    FData: TListVariable;  // ���ݴ����Ϣ
    function FieldSpace: Integer; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetDataRef: Pointer; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetIsNull: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetSize: Integer; // {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure InterClear;
    procedure InterSetBuffer(AEleType: TElementType; ABuffer: PAnsiChar; ASize: Integer);
    procedure InterSetStream(AEleType: TElementType; ABuffer: PAnsiChar; ASize: Integer);    
  protected
    // ������ =======================
    function GetAsBoolean: Boolean;
    function GetAsInteger: Integer;
    function GetAsCardinal: Cardinal;
    function GetAsInt64: Int64;
    function GetAsFloat: Double;
    function GetAsDateTime: TDateTime;
    function GetAsString: AnsiString;
    // Buffer��Record��Stream ����ʱ������
    function GetAsBuffer: TMemBuffer;
    function GetAsRecord: TBasePack;
    function GetAsStream: TStream;
  protected
    // д���� =======================
    procedure SetAsBoolean(const Value: Boolean);
    procedure SetAsInteger(const Value: Integer);
    procedure SetAsCardinal(const Value: Cardinal);
    procedure SetAsInt64(const Value: Int64);
    procedure SetAsFloat(const Value: Double);
    procedure SetAsDateTime(const Value: TDateTime);
    procedure SetAsString(const Value: AnsiString);
    // ���� Buffer��Record��Stream
    procedure SetAsBuffer(const Value: TMemBuffer);
    procedure SetAsRecord(const Value: TBasePack);
    procedure SetAsStream(const Value: TStream);
  public
    constructor Create(AName: AnsiString);
    destructor Destroy; override;
    property DataRef: Pointer read GetDataRef;
    property Name: AnsiString read FName;
    property IsNull: Boolean read GetIsNull;
    property VarType: TElementType read FData.EleType;
    property Size: Integer read GetSize;
  public
    property AsBoolean: Boolean read GetAsBoolean;
    property AsBuffer: TMemBuffer read GetAsBuffer;
    property AsCardinal: Cardinal read GetAsCardinal;
    property AsDateTime: TDateTime read GetAsDateTime;
    property AsFloat: Double read GetAsFloat;
    property AsInteger: Integer read GetAsInteger;
    property AsInt64: Int64 read GetAsInt64;
    property AsRecord: TBasePack read GetAsRecord;
    property AsStream: TStream read GetAsStream;
    property AsString: AnsiString read GetAsString;
  end;

  // ================== ������Ϣ�� �� ======================
  // �� <-> ���� ������δ�������ԣ�����ֱ��ʹ��

  TBasePack = class(TObject)
  private
    FError: Boolean;     // ��������
  protected
    FList: TInList;      // �����б�
    FSize: Cardinal;     // ȫ�����������ݳ���
  private
    function GetCount: Integer;
    function GetFields(Index: Integer): TVarField;
    function GetSize: Cardinal; virtual;
    
    // ���ұ���/�ֶ�
    function FindField(VarName: AnsiString; var Field: TVarField): Boolean;
  protected
    // ���ñ���ֵ
    procedure SetField(EleType: TElementType; const VarName: AnsiString;
                       const Value: PListVariable; const SValue: AnsiString = '');

    // ������ƵĺϷ���
    procedure CheckFieldName(const Value: AnsiString); virtual;

    // ������ݵĺϷ���
    procedure CheckStringValue(const Value: AnsiString); virtual;

    // ����������ڴ���
    procedure SaveToMemStream(Stream: TMemoryStream); virtual;

    // ɨ���ڴ�飬��������
    procedure ScanBuffers(ABuffer: PAnsiChar; ASize: Cardinal); virtual;

    // �ֶ�תΪ JSON
    procedure VarToJSON(var Buf: PAnsiChar; const VarName, VarValue: AnsiString;
                        Digital: Boolean; FirstPos: Boolean = False; EndPos: Boolean = False);
  protected
    // ������ =======================
    function GetAsBoolean(const Index: String): Boolean;
    function GetAsInteger(const Index: String): Integer;
    function GetAsCardinal(const Index: String): Cardinal;
    function GetAsInt64(const Index: String): Int64;
    function GetAsFloat(const Index: String): Double;
    function GetAsDateTime(const Index: String): TDateTime;

    function GetAsDocument(const Index: String): String;
    function GetAsString(const Index: String): String;

    // Buffer��Record��Stream ����ʱ������
    function GetAsBuffer(const Index: String): TMemBuffer;
    function GetAsRecord(const Index: String): TBasePack;
    function GetAsStream(const Index: String): TStream;
    function GetAsVariant(const Index: String): Variant;
  protected
    // д���� =======================
    procedure SetAsBoolean(const Index: String; const Value: Boolean);
    procedure SetAsInteger(const Index: String; const Value: Integer);
    procedure SetAsCardinal(const Index: String; const Value: Cardinal);
    procedure SetAsInt64(const Index: String; const Value: Int64);
    procedure SetAsFloat(const Index: String; const Value: Double);
    procedure SetAsDateTime(const Index: String; const Value: TDateTime);

    procedure SetAsDocument(const Index: String; const Value: String);
    procedure SetAsString(const Index: String; const Value: String);

    // ���� Buffer��Record��Stream
    procedure SetAsBuffer(const Index: String; const Value: TMemBuffer);
    procedure SetAsRecord(const Index: String; const Value: TBasePack);
    procedure SetAsStream(const Index: String; const Value: TStream);
    procedure SetAsVariant(const Index: String; const Value: Variant);
  protected
    property AsBoolean[const Index: String]: Boolean read GetAsBoolean write SetAsBoolean;
    property AsBuffer[const Index: String]: TMemBuffer read GetAsBuffer write SetAsBuffer;
    property AsCardinal[const Index: String]: Cardinal read GetAsCardinal write SetAsCardinal;
    property AsDateTime[const Index: String]: TDateTime read GetAsDateTime write SetAsDateTime;
    property AsDocument[const Index: String]: String read GetAsDocument write SetAsDocument;
    property AsFloat[const Index: String]: Double read GetAsFloat write SetAsFloat;
    property AsInteger[const Index: String]: Integer read GetAsInteger write SetAsInteger;
    property AsInt64[const Index: String]: Int64 read GetAsInt64 write SetAsInt64;
    property AsRecord[const Index: String]: TBasePack read GetAsRecord write SetAsRecord;
    property AsStream[const Index: String]: TStream read GetAsStream write SetAsStream;
    property AsString[const Index: String]: String read GetAsString write SetAsString;
    property AsVariant[const Index: String]: Variant read GetAsVariant write SetAsVariant;
  public
    constructor Create;
    destructor Destroy; override;
  public  
    procedure Clear; virtual;
    procedure Initialize(Stream: TStream; ClearIt: Boolean = True); overload;
    procedure Initialize(const AFileName: String); overload;
    procedure SaveToFile(const AFileName: String);
    procedure SaveToStream(Stream: TStream; DelParams: Boolean = True);
  public
    property Count: Integer read GetCount;
    property Document[const index: String]: TStream read GetAsStream;
    property Fields[index: Integer]: TVarField read GetFields;
    property Error: Boolean read FError write FError;
    property Size: Cardinal read GetSize;
  end;

  // ================== �û���Ϣ�� �� ======================
  // TBasePack ��ʹ����ʽ����������

  TCustomPack = class(TBasePack)
  public
    property AsBoolean;
    property AsBuffer;
    property AsCardinal;
    property AsDateTime;
    property AsDocument;
    property AsFloat;
    property AsInteger;
    property AsInt64;
    property AsRecord;
    property AsString;
    property AsStream;
  end;

  // ================== Э����Ϣ�� ���� ======================
  // ��Э��ͷ�����ա�����������
  // Ԥ�賣�ñ���/���ԵĶ�д������������Ҫ����

  THeaderPack = class(TBasePack)
  protected
    // ======== ����Ԫ���� TMsgHead ���ֶ�һ�� ==========
    FOwner: TMessageOwner;      // �����ߣ������
    FSessionId: Cardinal;       // ��֤/��¼ ID
    FMsgId: TIOCPMsgId;         // ��Ϣ ID
    FDataSize: Cardinal;        // ��������Ϣ��ԭʼ���ȣ����壩
    FAttachSize: TFileSize;     // �ļ��������ȣ�������
    FOffset: TFileSize;         // �ϵ��������ļ�λ��
    FOffsetEnd: TFileSize;      // �ϵ����������ݽ���λ��
    FCheckType: TDataCheckType; // У������
    FVarCount: Cardinal;        // ��������Ϣ�ı���/Ԫ�ظ���
    FZipLevel: TZipLevel;       // �����ѹ����
    FTarget: TActionTarget;     // Ŀ�Ķ�������
    FAction: TActionType;       // ��������
    FActResult: TActionResult;  // �������
    // ==================================================
  protected
    FMain: TInMemStream;        // ����������
    function GetData: Variant; virtual;
    function ToJSON: AnsiString; virtual;    
    procedure ToRecord(var ABuffer: PAnsiChar; var ASize: Cardinal);
  protected
    function GetAttachPath: String;       // �����ļ��ķ����·�������ܣ�
    function GetConnection: Integer;      // �������ӱ��
    function GetDateTime: TDateTime;      // ȡ����ʱ��
    function GetDirectory: String;        // ����·��
    function GetErrMsg: String;           // �쳣��Ϣ
    function GetFileName: String;         // ������ļ���
    function GetFileSize: TFileSize;      // �ļ���С
    function GetFunctionGroup: string;    // Զ�̺�����
    function GetFunctionIndex: Integer;   // Զ�̺������
    function GetHasParams: Boolean;       // SQL �Ƿ������
    function GetLocalFileName: string;    // ȡ����ʵ���ļ���
    function GetMsg: String;              // ��Ϣ����
    function GetNewCreatedFile: Boolean;  // �Ƿ�Ϊ�½��ļ�
    function GetNewFileName: String;      // �µ��ļ���
    function GetPassword: String;         // ����/����
    function GetReuseSessionId: Boolean;  // �Ƿ�����ƾ֤
    function GetRole: TClientRole;        // ��ɫ/Ȩ��
    function GetSize: Cardinal; override; // ȫ�������Ŀռ��С
    function GetSQL: String;              // SQL �ı�����
    function GetSQLName: String;          // SQL ���ƣ������Ԥ�裩
    function GetStoredProcName: String;   // �洢��������
    function GetToUser: String;           // Ŀ���û���
    function GetURL: String;              // ������������ URL
    function GetUserName: String;         // �û�������Դ
  protected
    procedure SetAttachPath(const Value: String);
    procedure SetConnection(const Value: Integer);
    procedure SetDateTime(const Value: TDateTime);
    procedure SetDirectory(const Value: String);
    procedure SetErrMsg(const Value: String);
    procedure SetFileName(const Value: String);
    procedure SetFileSize(const Value: TFileSize);
    procedure SetFunctionGroup(const Value: String);
    procedure SetFunctionIndex(const Value: Integer);
    procedure SetHasParams(const Value: Boolean);
    procedure SetLocalFileName(const Value: String);    
    procedure SetMsg(const Value: String);
    procedure SetNewCreatedFile(const Value: Boolean);
    procedure SetNewFileName(const Value: String);
    procedure SetPassword(const Value: String);
    procedure SetReuseSessionId(const Value: Boolean);
    procedure SetRole(const Value: TClientRole);
    procedure SetSQL(const Value: String);
    procedure SetSQLName(const Value: String);
    procedure SetStoredProcName(const Value: String);
    procedure SetToUser(const Value: String);
    procedure SetURL(const Value: String);
    procedure SetUserName(const Value: String);
  public
    function  GetMsgSize(RecvMode: Boolean): TFileSize;
    procedure GetHeadMsg(Msg: PMsgHead);
    procedure SetHeadMsg(Msg: PMsgHead; ForReturn: Boolean = False);
  public
    // ��������
    property AsBoolean;
    property AsBuffer;
    property AsCardinal;
    property AsDateTime;
    property AsDocument;
    property AsFloat;
    property AsInteger;
    property AsInt64;
    property AsRecord;
    property AsString;
    property AsStream;
  end;

  // ================== �յ�����Ϣ�� �� ======================
  // ����ˡ��ͻ����յ�����Ϣ��ֻ����
   
  TReceivePack = class(THeaderPack)
  private
    FAttachment: TIOCPDocument; // ����������
  protected
    procedure CreateAttachment(const LocalPath: String); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Cancel;
    procedure Clear; override;
  public
    // ��������������
    property Main: TInMemStream read FMain;
    property Attachment: TIOCPDocument read FAttachment write FAttachment;
  public
    // Э��ͷ����
    property Action: TActionType read FAction;
    property ActResult: TActionResult read FActResult;
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
  public
    // ���ñ���/����
    property Connection: Integer read GetConnection;
    property DateTime: TDateTime read GetDateTime;
    property Directory: String read GetDirectory;
    property ErrMsg: String read GetErrMsg;
    property FileName: String read GetFileName;
    property FromUser: String read GetUserName;
    property FunctionGroup: String read GetFunctionGroup;
    property FunctionIndex: Integer read GetFunctionIndex;
    property HasParams: Boolean read GetHasParams;
    property Msg: String read GetMsg;
    property NewFileName: String read GetNewFileName;
    property Password: String read GetPassword;
    property ReuseSessionId: Boolean read GetReuseSessionId;
    property Role: TClientRole read GetRole;
    property StoredProcName: String read GetStoredProcName;
    property SQL: String read GetSQL;
    property SQLName: String read GetSQLName;
    property TargetUser: String read GetToUser;
    property ToUser: String read GetToUser;
    property URL: String read GetURL;
    property UserName: String read GetUserName;
  end;

  // ������Ϣ����
  TReceivePackClass = class of TReceivePack;

  // ================== ������Ϣ�� �� ======================
  // ����ˡ��ͻ��˷��������ã���д��

  // ��Ϣ���ࣺ
  // 1. ���壺1.1 As... ϵ�еı��������ݣ�FVarCount > 0��
  //          1.2 Variant ���ݼ��������ݣ�FVarCount = 0��
  // 2. �����������ļ����������������ݼ������������߻���

  // ���ͷ�����
  // 1. �ȷ����壬�󷢸���
  // 2. �ͻ��˷��͸������������󣬵ȴ�����˷��������ٷ���
  // 3. ����˷��͸�����������ֱ�ӷ���

  // ���ݸ�ʽ��
  //   �װ���IOCP_HEAD_FLAG + TMsgHead + [У���� + У����] + [����ԭʼ����]
  // ��������[����򸽼���ԭʼ����]

  TBaseMessage = class(THeaderPack)
  protected
    FAttachFileName: String; // �������ļ���
    FAttachment: TStream;    // ����������
    FAttachZiped: Boolean;   // �����Ƿ���ѹ��
  private
    procedure GetFileInfo(const AFileName: String);
    procedure GetCheckCode(AStream: TStream; ToBuf: PAnsiChar;
                           ASize: TFileSize; var Offset: Cardinal);
    procedure InterSetAttachment(AStream: TStream);
  protected
    procedure AdjustTransmitRange(ChunkSize: Integer);
    procedure CreateStreams(ClearList: Boolean = True); virtual;
    procedure LoadFromVariant(AData: Variant); virtual;  // �ͻ��˲�����
    procedure LoadHead(Data: PWsaBuf);
    procedure NilStreams(CloseAttachment: Boolean);
    procedure OpenLocalFile; virtual;
    class procedure CreateHead(ABuf: PAnsiChar; AResult: TActionResult);
  public
    constructor Create(AOwner: TObject);
    destructor Destroy; override;
    procedure Clear; override;
    procedure LoadFromFile(const AFileName: String; OpenAtOnce: Boolean = False); virtual;
    procedure LoadFromStream(AStream: TStream; AZipCompressIt: Boolean = False);
  public
    // ��������������
    property Main: TInMemStream read FMain;
    property Attachment: TStream read FAttachment;
  public
    // ����ˡ��ͻ��˳������ԣ���д��
    property AttachFilename: String read FAttachFileName;
    property DateTime: TDateTime read GetDateTime write SetDateTime;
    property FromUser: String read GetUserName write SetUserName;
    property Msg: String read GetMsg write SetMsg;
    property Role: TClientRole read GetRole write SetRole;
    property TargetUser: String read GetToUser write SetToUser;
    property ToUser: String read GetToUser write SetToUser;
    property UserName: String read GetUserName write SetUserName;
  end;

  // ================== �������Ϣ���� �� ======================

  TMessageWriter = class(TObject)
  private
    FLock: TThreadLock;    // ��Ϣ��
    FSurportHttp: Boolean; // ���ɸ����� URL
  public
    constructor Create(SurportHttp: Boolean);
    destructor Destroy; override;
  public
    procedure LoadMsg(const UserName: String; Msg: TBaseMessage);
    procedure SaveMsg(Data: PPerIOData; const ToUser: String); overload;
    procedure SaveMsg(Msg: THeaderPack); overload;
  end;

  // ================== �ͻ���������Ϣ�Ķ� �� ======================

  TMessageReader = class(TObject)
  private
    FHandle: THandle;  // �ļ����
    FCount: Integer;   // ��Ϣ����
  public
    destructor Destroy; override;
    procedure Close;
    function Extract(Msg: TReceivePack; LastMsgId: TIOCPMsgId = 0): Boolean;
    procedure Open(const FileName: String);
  public
    property Count: Integer read FCount;
  end;
    
// �Զ�����ڴ��, �ṹ��Size + Content
function GetBuffer(const Value: Integer): TMemBuffer;
function FreeBuffer(P: TMemBuffer): Integer;
function BufferSize(P: TMemBuffer): Integer;

implementation

uses
  iocp_log, iocp_varis, iocp_utils, http_utils;

function GetBuffer(const Value: Integer): TMemBuffer;
begin
  if (Value > 0) then
  begin
    GetMem(Result, Value + SizeOf(Integer));
    PInteger(Result)^ := Value;  // ��һ�� Integer Ϊ����
    Inc(PAnsiChar(Result), SizeOf(Integer));  // ���صڶ�Ԫ�ص�ַ
  end else
    Result := Nil;
end;

function FreeBuffer(P: TMemBuffer): Integer;
begin
  Dec(PAnsiChar(P), SizeOf(Integer));  // ����һ�� Integer λ��
  Result := PInteger(P)^;
  FreeMem(P);
end;

function BufferSize(P: TMemBuffer): Integer;
begin
  Dec(PAnsiChar(P), SizeOf(Integer));  // ����һ�� Integer λ��
  Result := PInteger(P)^;
end;

{ TInMemStream }

procedure TInMemStream.Clear;
begin
  if Assigned(Memory) then
    inherited Clear;
end;

procedure TInMemStream.Initialize(ASize: Cardinal; AddTag: Boolean);
begin
  // ���������ܳ���
  if AddTag then
  begin
    // �� 1 ���ֽڣ���� Http �����б�ָ�����&��,
    Size := ASize + 1;
    PAnsiChar(LongWord(Memory) + ASize)^ := AnsiChar('&'); 
  end else
    Size := ASize;
  Position := 0;
end;

function TInMemStream.Realloc(var NewCapacity: Integer): Pointer;
begin
  if FSetMode then
  begin
    Result := Memory;
    NewCapacity := FNewSize;
  end else
    Result := inherited Realloc(NewCapacity);
end;

procedure TInMemStream.SetMemory(ABuffer: Pointer; ASize: Integer);
begin
  // ���ⲿ�ڴ� ABuffers ��Ϊ�����ڴ�
  if Assigned(Memory) then
    inherited Clear;
  FSetMode := True;
  FNewSize := ASize;
  SetPointer(ABuffer, ASize);  // �����ڴ�
  Capacity := ASize;  // ���룬���� Free ʱ���ͷ��ڴ�
  FSetMode := False;
  Position := 0;
end;

{ TIOCPDocument }

constructor TIOCPDocument.Create(const AFileName: String; CreateNew: Boolean);
begin
  inherited Create(0);
  if (AFileName = '') then  // ��ʱ�ļ����ر�ʱɾ��
  begin
    FTempFile := True;
    InternalCreate(iocp_varis.gTempPath + '_' +
                   IntToStr(NativeUInt(Self)) + '.tmp', True);
  end else
  begin  // ���»���ļ�
    FTempFile := False;
    InternalCreate(AFileName, CreateNew);
  end;
end;

constructor TIOCPDocument.CreateEx(const AFileName: String);
begin
  inherited Create(0);
  // ֻ���ļ�������������
  FHandle := InternalOpenFile(AFileName, True);  // ֻ��
  if (FHandle > 0) then
  begin
    FFileName := AFileName;
    FOriginSize := GetFileSize64(FHandle);  // ԭʼ����
    GetFileTime(FHandle, @FCreationTime, @FAccessTime, @FLastWriteTime);
  end else
  begin
    iocp_log.WriteLog('TIOCPDocument.CreateEx->���ļ��쳣��' + AFileName);
    Raise Exception.Create('���ļ��쳣.');
  end;
end;

destructor TIOCPDocument.Destroy;
begin
  Self.Close(FTempFile);
  inherited;
end;

procedure TIOCPDocument.InternalCreate(const AFileName: String; CreateNew: Boolean);
begin
  // InternalOpenFile �� INVALID_HANDLE_VALUE תΪ 0
  if CreateNew then  // �½��ļ�
    FHandle := FileCreate(AFileName, fmCreate or fmOpenWrite or fmShareDenyWrite)
  else begin  // ���ļ�
    FHandle := InternalOpenFile(AFileName, False); // ����д
    FOriginSize := GetFileSize64(FHandle);  // ԭʼ����
    GetFileTime(FHandle, @FCreationTime, @FAccessTime, @FLastWriteTime);
  end;
  if (FHandle > 0) then
    FFileName := AFileName
  else begin
    iocp_log.WriteLog('TIOCPDocument.InternalCreate->�½�/���ļ��쳣��' + AFileName);
    Raise Exception.Create('�½�/���ļ��쳣.');
  end;
end;

procedure TIOCPDocument.Close(DelFile: Boolean);
begin
  if (FHandle > 0) then
  begin
    try
      CloseHandle(FHandle);
    finally
      FHandle := 0;
    end;
    if DelFile or FTempFile then  // ɾ����ʱ�ļ�
      SysUtils.DeleteFile(FileName);
  end;
end;

procedure TIOCPDocument.SetFileInf(Params: TReceivePack);
begin
  // �ѽ��ļ����������ļ�����
  //   ����TBaseMessage.GetFileInfo
  FOriginSize := Params.GetFileSize; // �ϵ�����ʱ AttachSize �ǿ鳤��
  Size := FOriginSize; 
  Position := 0; // ����
  if (FTempFile = False) then    // ������ʱ�ļ�
  begin
    FUserName := Params.ToUser;  // �����ļ�Ŀ��
    FCreationTime.dwLowDateTime := Params.AsCardinal['_creationLow'];
    FCreationTime.dwHighDateTime := Params.AsCardinal['_creationHigh'];
    FAccessTime.dwLowDateTime := Params.AsCardinal['_accessLow'];
    FAccessTime.dwHighDateTime := Params.AsCardinal['_accessHigh'];
    FLastWriteTime.dwLowDateTime := Params.AsCardinal['_modifyLow'];
    FLastWriteTime.dwHighDateTime := Params.AsCardinal['_modifyHigh'];
    Windows.SetFileTime(FHandle, @FCreationTime, @FAccessTime, @FLastWriteTime);
  end;
end;

procedure TIOCPDocument.RenameFileName(AFileName: String);
var
  i: Integer;
begin
  Close;
  if RenameFile(FFileName, AFileName) then
    FFileName := AFileName
  else begin
    i := Pos('.chunk', FFileName);
    if (i > 0) then  // �����ļ�
    begin
      if RenameFile(FFileName, Copy(FFileName, 1, i - 1)) then
        Delete(FFileName, i, 6);
    end;
  end;
end;

{ TVarField }

constructor TVarField.Create(AName: AnsiString);
begin
  inherited Create;
  FName := AName;
  FData.EleType := etNull;
end;

destructor TVarField.Destroy;
begin
  InterClear;
  inherited;
end;

function TVarField.FieldSpace: Integer;
begin
  // ȡ�洢�ռ��С����������
  Result := GetSize;
  Inc(Result, STREAM_VAR_SIZE + Length(FName));
  if (FData.EleType in [etStream, etBuffer, etString, etRecord]) then
    Inc(Result, SizeOf(Integer));
end;

function TVarField.GetAsBoolean: Boolean;
  function CompareStr(const S: AnsiString): Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
  begin
    // True -> 1, ����SetAsBoolean
    Result := (S = '1') or (S = 'True') or (S = 'Yes');
  end;
begin
  case FData.EleType of
    etBoolean:
      Result := FData.BooleanValue;
    etString:
      Result := CompareStr(AsString);
    etCardinal:
      Result := FData.CardinalValue > 0;
    etFloat:
      Result := FData.FloatValue > 0;
    etInt64:
      Result := FData.Int64Value > 0;
    etInteger:
      Result := FData.IntegerValue > 0;
    else
      Result := False;
  end;
end;

function TVarField.GetAsBuffer: TMemBuffer;
begin
  // ����ʱ�����ã�����һ�ݣ��ⲿҪ�ͷ� Result
  if (FData.EleType = etBuffer) then
  begin
    Result := GetBuffer(FData.DataSize);
    System.Move(FData.Data^, Result^, FData.DataSize);
  end else
    Result := nil;
end;

function TVarField.GetAsCardinal: Cardinal;
begin
  if (FData.EleType = etString) then
    Result := StrToInt(AsString)
  else
    Result := FData.CardinalValue;
end;

function TVarField.GetAsDateTime: TDateTime;
begin
  if (FData.EleType = etString) then
    Result := StrToDateTime(AsString)
  else
    Result := FData.DateTimeValue;
end;

function TVarField.GetAsFloat: Double;
begin
  if (FData.EleType = etString) then
    Result := StrToFloat(AsString)
  else
    Result := FData.FloatValue;
end;

function TVarField.GetAsInt64: Int64;
begin
  case FData.EleType of
    etInt64:
      Result := FData.Int64Value;
    etCardinal:
      Result := FData.CardinalValue;
    etInteger:
      Result := FData.IntegerValue;
    etString:
      Result := StrToInt64(AsString);
    else
      Result := 0;
  end;
end;

function TVarField.GetAsInteger: Integer;
begin
  if (FData.EleType = etString) then
    Result := StrToInt(AsString)
  else
    Result := FData.IntegerValue;
end;

function TVarField.GetAsRecord: TBasePack;
begin
  // ����һ�ݣ��ⲿҪ�ͷ� Result������ʱΪ TMemoryStream �����ã�
  if (FData.EleType = etRecord) then
  begin
    Result := TCustomPack.Create;  // �� TCustomPack���ⲿ��ʹ������
    Result.ScanBuffers(TMemoryStream(FData.Data).Memory, FData.DataSize); // ��������
  end else
    Result := nil;
end;

function TVarField.GetAsStream: TStream;
begin
  // ����һ�ݣ��ⲿҪ�ͷ� Result������ʱΪ TStream �����ã�
  case FData.EleType of
    etRecord,
    etStream: begin // ����ʱ�����ã�����
      Result := TMemoryStream.Create;
      TStream(FData.Data).Position := 0;  // ����
      Result.CopyFrom(TStream(FData.Data), FData.DataSize);
      Result.Position := 0;
    end;
    etBuffer,
    etString: begin // תΪ��
      Result := TMemoryStream.Create;
      Result.Size := FData.DataSize;
      Result.Write(FData.Data^, FData.DataSize);
    end;
    else
      Result := Nil;
  end;
end;

function TVarField.GetAsString: AnsiString;
const
  BOOLEAN_STRS: array[Boolean] of AnsiString = ('0', '1');
begin
  // ���� String ������ת��
  case FData.EleType of
    etBuffer,
    etString:
      SetString(Result, PAnsiChar(FData.Data), FData.DataSize);
    etRecord,
    etStream:
      if (TStream(FData.Data) is TMemoryStream) then
        SetString(Result, PAnsiChar(TMemoryStream(FData.Data).Memory), FData.DataSize)
      else begin
        SetLength(Result, FData.DataSize);
        TStream(FData.Data).Read(Result[1], FData.DataSize);
      end;
    etBoolean:
      Result := BOOLEAN_STRS[FData.BooleanValue];
    etCardinal:
      Result := IntToStr(FData.CardinalValue);
    etDateTime:
      Result := DateTimeToStr(FData.DateTimeValue);
    etFloat:
      Result := FloatToStr(FData.FloatValue);
    etInt64:
      Result := IntToStr(FData.Int64Value);
    etInteger:
      Result := IntToStr(FData.IntegerValue);
    else
      Result := '';
  end;
end;

function TVarField.GetDataRef: Pointer;
begin
  Result := FData.Data;  // �䳤�������õ�ַ
end;

function TVarField.GetIsNull: Boolean;
begin
  Result := (FData.EleType = etNull);
end;

function TVarField.GetSize: Integer;
begin
  case FData.EleType of
    etBoolean:
      Result := SizeOf(Boolean);
    etDateTime:
      Result := SizeOf(TDateTime);
    etCardinal:
      Result := SizeOf(Cardinal);
    etFloat:
      Result := SizeOf(Double);
    etInt64:
      Result := SizeOf(Int64);
    etInteger:
      Result := SizeOf(Integer);
    etBuffer, etString,
    etRecord, etStream:
      Result := FData.DataSize;
    else  // etNull
      Result := 0;
  end;
end;

procedure TVarField.InterClear;
begin
  // ����ռ���ͷŶ���Ҳ�����ظ���ֵ��
  case FData.EleType of
    etBuffer:
      if Assigned(FData.Data) then
      begin
        FreeBuffer(FData.Data);
        FData.Data := nil;
      end;
    etString:
      if Assigned(FData.Data) then
      begin
        FreeMem(FData.Data);
        FData.Data := nil;
      end;
    etRecord, etStream:
      if Assigned(FData.Data) then
      begin
        TStream(FData.Data).Free;
        FData.Data := nil;
      end;
  end;
end;

procedure TVarField.InterSetBuffer(AEleType: TElementType; ABuffer: PAnsiChar; ASize: Integer);
begin
  // ��������ʱ���ڴ�ȡ���������ֶ�
  if (ASize > 0) then
  begin
    FData.EleType := AEleType;
    FData.DataSize := ASize;
    if (AEleType = etBuffer) then
      FData.Data := GetBuffer(ASize)
    else
      GetMem(FData.Data, ASize);
    System.Move(ABuffer^, FData.Data^, ASize);
  end else
  begin
    FData.EleType := etNull;
    FData.DataSize := 0;
    FData.Data := nil;    
  end;
end;

procedure TVarField.InterSetStream(AEleType: TElementType; ABuffer: PAnsiChar; ASize: Integer);
begin
  // ��������ʱ���ڴ�ȡ���������ڴ���
  if (ASize > 0) then
  begin
    FData.EleType := AEleType;
    FData.DataSize := ASize;
    FData.Data := TMemoryStream.Create;
    TMemoryStream(FData.Data).Size := ASize;
    System.Move(ABuffer^, TMemoryStream(FData.Data).Memory^, ASize);
  end else
  begin
    FData.EleType := etNull;
    FData.DataSize := 0;
    FData.Data := nil;    
  end;
end;

procedure TVarField.SetAsBoolean(const Value: Boolean);
begin
  FData.EleType := etBoolean;
  FData.BooleanValue := Value;
end;

procedure TVarField.SetAsBuffer(const Value: TMemBuffer);
begin
  // ���� TMemBuffer �����ã���߲����ͷ� Value
  if Assigned(Value) then
  begin
    FData.EleType := etBuffer;
    FData.DataSize := BufferSize(Value);
    FData.Data := Value;
  end else
  begin
    FData.EleType := etNull;  // ��ֵ
    FData.DataSize := 0;
    FData.Data := nil;
  end;
end;

procedure TVarField.SetAsCardinal(const Value: Cardinal);
begin
  FData.EleType := etCardinal;
  FData.CardinalValue := Value;
end;

procedure TVarField.SetAsDateTime(const Value: TDateTime);
begin
  FData.EleType := etDateTime;
  FData.DateTimeValue := Value;
end;

procedure TVarField.SetAsFloat(const Value: Double);
begin
  FData.EleType := etFloat;
  FData.FloatValue := Value;
end;

procedure TVarField.SetAsInt64(const Value: Int64);
begin
  FData.EleType := etInt64;
  FData.Int64Value := Value;
end;

procedure TVarField.SetAsInteger(const Value: Integer);
begin
  FData.EleType := etInteger;
  FData.IntegerValue := Value;
end;

procedure TVarField.SetAsRecord(const Value: TBasePack);
var
  Stream: TMemoryStream;
begin
  // �����¼��, �ⲿҪ�ͷ� Value
  if Assigned(Value) then
  begin
    Stream := TMemoryStream.Create;
    Value.SaveToStream(Stream, False);
    FData.EleType := etRecord;
    FData.DataSize := Stream.Size;  // 2018-09-09
    FData.Data := Stream;
  end else
  begin
    FData.EleType := etNull;
    FData.DataSize := 0;
    FData.Data := nil;
  end;
end;

procedure TVarField.SetAsStream(const Value: TStream);
begin
  // ����������, �ⲿ�����ͷ� Value
  if Assigned(Value) then
  begin
    FData.EleType := etStream;
    FData.DataSize := Value.Size;
    FData.Data := Value;
  end else
  begin
    FData.EleType := etNull;
    FData.DataSize := 0;
    FData.Data := nil;
  end;
end;

procedure TVarField.SetAsString(const Value: AnsiString);
begin
  // �����ַ�������������
  InterSetBuffer(etString, @Value[1], Length(Value));
end;

{ TBasePack }

procedure TBasePack.CheckFieldName(const Value: AnsiString);
begin
  if not (Length(Value) in [1..128]) then
    raise Exception.Create('�������Ʋ���Ϊ�ջ�̫��.');
end;

procedure TBasePack.CheckStringValue(const Value: AnsiString);
begin
  // JSON �ż��
end;

procedure TBasePack.Clear;
var
  i: Integer;
begin
  FSize := 0;
  for i := 0 to FList.Count - 1 do
    TVarField(FList.PopFirst).Free;
end;

constructor TBasePack.Create;
begin
  inherited;
  FList := TInList.Create;
end;

destructor TBasePack.Destroy;
begin
  Clear;
  FList.Free;
  inherited;
end;

function TBasePack.FindField(VarName: AnsiString; var Field: TVarField): Boolean;
var
  i: Integer;
begin
  // ���ұ���/�ֶ�
  //  VarName �� AnsiString����д
  VarName := UpperCase(VarName);
  for i := 0 to FList.Count - 1 do
  begin
    Field := TVarField(FList.Items[i]);
    if (Field.FName = VarName) then  // ͬΪ AnsiString
    begin
      Result := True;
      Exit;
    end;
  end;
  Field := nil;
  Result := False;
end;

function TBasePack.GetAsBoolean(const Index: String): Boolean;
var
  Field: TVarField;
begin
  if FindField(Index, Field) then
    Result := Field.AsBoolean
  else
    Result := False;
end;

function TBasePack.GetAsBuffer(const Index: String): TMemBuffer;
var
  Field: TVarField;
begin
  // ����һ�ݣ��ⲿҪ�ͷ� Result������ʱ�����ã�
  if FindField(Index, Field) then
    Result := Field.AsBuffer
  else
    Result := nil;
end;

function TBasePack.GetAsCardinal(const Index: String): Cardinal;
var
  Field: TVarField;
begin
  if FindField(Index, Field) then
    Result := Field.AsCardinal
  else
    Result := 0;
end;

function TBasePack.GetAsDateTime(const Index: String): TDateTime;
var
  Field: TVarField;
begin
  if FindField(Index, Field) then
    Result := Field.AsDateTime
  else
    Result := 0.0;
end;

function TBasePack.GetAsDocument(const Index: String): String;
begin
  Raise Exception.Create('�� Document[] ������ȡ�ļ�����');
end;

function TBasePack.GetAsFloat(const Index: String): Double;
var
  Field: TVarField;
begin
  if FindField(Index, Field) then
    Result := Field.AsFloat
  else
    Result := 0.0;
end;

function TBasePack.GetAsInt64(const Index: String): Int64;
var
  Field: TVarField;
begin
  if FindField(Index, Field) then
    Result := Field.AsInt64
  else
    Result := 0;
end;

function TBasePack.GetAsInteger(const Index: String): Integer;
var
  Field: TVarField;
begin
  if FindField(Index, Field) then
    Result := Field.AsInteger
  else
    Result := 0;
end;

function TBasePack.GetAsRecord(const Index: String): TBasePack;
var
  Field: TVarField;
begin
  if FindField(Index, Field) then
    Result := Field.AsRecord
  else
    Result := nil;
end;            

function TBasePack.GetAsStream(const Index: String): TStream;
var
  Field: TVarField;
begin
  if FindField(Index, Field) then
    Result := Field.AsStream
  else
    Result := nil;
end;

function TBasePack.GetAsString(const Index: String): String;
var
  Field: TVarField;
begin
  if FindField(Index, Field) then
    Result := Field.AsString
  else
    Result := '';
end;

function TBasePack.GetAsVariant(const Index: String): Variant;
var
  Field: TVarField;
begin
  if (FindField(Index, Field) = False) then
    Result := Null
  else  // ����ת��Ϊ varByte Variant ���ͣ�ѹ�������ݼ��� Delta��
  if (Field.VarType in [etRecord, etStream]) then
    Result := iocp_utils.StreamToVariant(TMemoryStream(Field.FData.Data), True)
  else
    Result := iocp_utils.StreamToVariant(Field.GetAsStream as TMemoryStream, True);
end;

function TBasePack.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TBasePack.GetFields(Index: Integer): TVarField;
begin
  // ȡ�ֶ�
  Result := TVarField(FList.Items[Index]);
end;

function TBasePack.GetSize: Cardinal;
begin
  // ȡ�����ܳ���
  Result := FSize;
end;

procedure TBasePack.SaveToFile(const AFileName: String);
var
  Stream: TFileStream;
begin
  // ����������ļ�
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    if (Stream.Handle > 0) then
      SaveToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TBasePack.SaveToMemStream(Stream: TMemoryStream);
var
  i: Integer;
  p: PAnsiChar;
  Field: TVarField;
  Target: PListVariable;
begin
  // ת������/����������ʽ���ڴ���
  //   ����ʽ��ElementCount + Variable, Variable2...
  // ������ʽ��EleType + NameSize + Name + Value | (BufferSize + Buffer)

  // Ԥ�賤��
  if (Stream.Size <> FSize) then
    Stream.Size := FSize;

  // Ԫ�ظ���
  p := PAnsiChar(Stream.Memory);

  PInteger(p)^ := FList.Count;  // ��������
  Inc(p, SizeOf(Integer));

  for i := 0 to FList.Count - 1 do
  begin
    // �ֶ�
    Field := TVarField(FList.Items[i]);
    Target := PListVariable(p);

    // ���͡����Ƴ��ȣ�EleType + NameSize
    Target^.EleType := Field.FData.EleType;
    Target^.NameSize := Length(Field.FName);
    Inc(p, STREAM_VAR_SIZE);

    // �������ƣ�Name: AnsiString
    System.Move(Field.FName[1], p^, Target^.NameSize);
    Inc(p, Target^.NameSize);

    // ��ֵ�����ݳ��ȣ� Value | BufferSize
    case Field.FData.EleType of
      etNull:            // ��ֵ
        { Empty } ;
      etBoolean: begin   // �߼�
        PBoolean(p)^ := Field.FData.BooleanValue;
        Inc(p, SizeOf(Boolean));
      end;
      etInteger: begin   // ����
        PInteger(p)^ := Field.FData.IntegerValue;
        Inc(p, SizeOf(Integer));
      end;
      etCardinal: begin  // �޷�������
        PCardinal(p)^ := Field.FData.CardinalValue;
        Inc(p, SizeOf(Cardinal));
      end;
      etFloat: begin     // ������
        PDouble(p)^ := Field.FData.FloatValue;
        Inc(p, SizeOf(Double));
      end;
      etInt64: begin     // 64 λ����
        PInt64(p)^ := Field.FData.Int64Value;
        Inc(p, SizeOf(Int64));
      end;
      etDateTime: begin  // ����ʱ��
        PDateTime(p)^ := Field.FData.DateTimeValue;
        Inc(p, SizeOf(TDateTime));
      end;

      // �䳤����: BufferSize + Buffer

      etBuffer,         // �Զ����ڴ��
      etString: begin   // �ַ���
        PInteger(p)^ := Field.FData.DataSize;
        Inc(p, SizeOf(Integer));
        if (Field.FData.DataSize > 0) then
        begin
          System.Move(Field.FData.Data^, p^, Field.FData.DataSize);
          Inc(p, Field.FData.DataSize);
        end;
      end;

      etStream,         // ��
      etRecord: begin   // ��¼��
        PInteger(p)^ := Field.FData.DataSize;
        Inc(p, SizeOf(Integer));
        if (Field.FData.DataSize > 0) then
        begin
          TStream(Field.FData.Data).Position := 0;  // ��ʼλ��
          TStream(Field.FData.Data).Read(p^, Field.FData.DataSize);
          Inc(p, Field.FData.DataSize);
        end;
      end;
    end;
  end;

end;

procedure TBasePack.SaveToStream(Stream: TStream; DelParams: Boolean);
var
  mStream: TMemoryStream;
begin
  // ת������/��������������ʽ������
  if Assigned(Stream) and (FSize > 0) then
    try
      if (Stream is TMemoryStream) then  // �ڴ���
        SaveToMemStream(TMemoryStream(Stream))
      else begin
        // ��ת�����ڴ���
        Stream.Position := 0;
        mStream := TMemoryStream.Create;
        try
          SaveToMemStream(mStream);
          Stream.Write(mStream.Memory^, mStream.Size);
        finally
          mStream.Free;
        end;
      end;
    finally
      Stream.Position := 0;
      if DelParams then  // ���������
        Clear;
    end;
end;

procedure TBasePack.ScanBuffers(ABuffer: PAnsiChar; ASize: Cardinal);
var
  i, iCount: Integer;
  Field: TVarField;
  VarName: AnsiString;
  Source: PListVariable;
begin                              
  // �����ڴ������������б�
  //   ����ʽ��ElementCount + Variable, Variable2...
  // Variable ��ʽ��EleType + NameSize + Name + Value | BufferSize + Buffer

  // �ܳ���
  FSize := ASize;

  // ��������
  iCount := PInteger(ABuffer)^;
  Inc(ABuffer, SizeOf(Integer));

  for i := 0 to iCount - 1 do
  begin
    // ���ܴ����쳣�� NameSize ̫�� -> �ڴ治��
    Source := PListVariable(ABuffer);
    if (Source^.NameSize > 128) then
    begin
      FError := True;
      Break;
    end;

    // ȡ��������: VarName
    Inc(ABuffer, STREAM_VAR_SIZE);

    SetLength(VarName, Source^.NameSize);
    System.Move(ABuffer^, VarName[1], Source^.NameSize);

    // ���ӱ�����Ĭ��Ϊ etNull
    Field := TVarField.Create(VarName);
    FList.Add(Field); // inherited Add(Field);

    // ��������ֵ����λ��
    Inc(ABuffer, Source^.NameSize);
    
    // ����ֵ�򳤶�: Value | BufferSize
    case Source^.EleType of
      etBoolean: begin   // �߼�
        Field.SetAsBoolean(PBoolean(ABuffer)^);
        Inc(ABuffer, SizeOf(Boolean));
      end;
      etInteger: begin   // ����
        Field.SetAsInteger(PInteger(ABuffer)^);
        Inc(ABuffer, SizeOf(Integer));
      end;
      etCardinal: begin  // �޷�������
        Field.SetAsCardinal(PCardinal(ABuffer)^);
        Inc(ABuffer, SizeOf(Cardinal));
      end;
      etFloat: begin     // ������
        Field.SetAsFloat(PDouble(ABuffer)^);
        Inc(ABuffer, SizeOf(Double));
      end;
      etInt64: begin     // 64 λ����
        Field.SetAsInt64(PInt64(ABuffer)^);
        Inc(ABuffer, SizeOf(Int64));
      end;
      etDateTime: begin  // ʱ������
        Field.SetAsDateTime(PDateTime(ABuffer)^);
        Inc(ABuffer, SizeOf(TDateTime));
      end;

      etBuffer,          // �Զ����ڴ��
      etString: begin    // �ַ���
        Field.InterSetBuffer(Source^.EleType, ABuffer + SizeOf(Integer),
                             PInteger(ABuffer)^);
        Inc(ABuffer, SizeOf(Integer) + PInteger(ABuffer)^);
      end;

      etRecord,          // ��¼
      etStream: begin    // ��
        Field.InterSetStream(Source^.EleType, ABuffer + SizeOf(Integer),
                             PInteger(ABuffer)^);
        Inc(ABuffer, SizeOf(Integer) + PInteger(ABuffer)^);      
      end;
    end;
  end;
end;

procedure TBasePack.SetAsBoolean(const Index: String; const Value: Boolean);
var
  Variable: TListVariable;
begin
  Variable.BooleanValue := Value;
  SetField(etBoolean, Index, @Variable);
end;

procedure TBasePack.SetAsBuffer(const Index: String; const Value: TMemBuffer);
var
  Variable: TListVariable;
begin
  Variable.Data := Value;
  SetField(etBuffer, Index, @Variable);
end;

procedure TBasePack.SetAsCardinal(const Index: String; const Value: Cardinal);
var
  Variable: TListVariable;
begin
  Variable.CardinalValue := Value;
  SetField(etCardinal, Index, @Variable);
end;

procedure TBasePack.SetAsDateTime(const Index: String; const Value: TDateTime);
var
  Variable: TListVariable;
begin
  Variable.DateTimeValue := Value;
  SetField(etDateTime, Index, @Variable);
end;

procedure TBasePack.SetAsDocument(const Index, Value: String);
var
  Stream: TFileStream;
  Variable: TListVariable;
begin
  // �򿪡�����һ���ļ������ļ�����̫�󣩣��� Document[] ��ȡ�ļ�
  FError := True;
  if FileExists(Value) then
  begin
    // TFileStream.Handle �߰汾Ϊ THandle 
    Stream := TFileStream.Create(Value, fmOpenRead or fmShareDenyWrite);
    if (Stream.Handle = 0) or (Stream.Handle = INVALID_HANDLE_VALUE) or (Stream.Size = 0) then
    begin
      Stream.Free;
      FError := False;
      Variable.Data := nil;
      SetField(etStream, Index, @Variable);
    end else
    begin
      FError := False;
      Variable.Data := Stream;
      SetField(etStream, Index, @Variable);
    end;
  end;
end;

procedure TBasePack.SetAsFloat(const Index: String; const Value: Double);
var
  Variable: TListVariable;
begin
  Variable.FloatValue := Value;
  SetField(etFloat, Index, @Variable);
end;

procedure TBasePack.SetAsInt64(const Index: String; const Value: Int64);
var
  Variable: TListVariable;
begin
  Variable.Int64Value := Value;
  SetField(etInt64, Index, @Variable);
end;

procedure TBasePack.SetAsInteger(const Index: String; const Value: Integer);
var
  Variable: TListVariable;
begin
  Variable.IntegerValue := Value;
  SetField(etInteger, Index, @Variable);
end;

procedure TBasePack.SetAsRecord(const Index: String; const Value: TBasePack);
var
  Variable: TListVariable;
begin
  Variable.Data := Value;
  SetField(etRecord, Index, @Variable);
end;

procedure TBasePack.SetAsStream(const Index: String; const Value: TStream);
var
  Variable: TListVariable;
begin
  Variable.Data := Value;
  SetField(etStream, Index, @Variable);
end;

procedure TBasePack.SetAsString(const Index, Value: String);
begin
  SetField(etString, Index, nil, Value);
end;

procedure TBasePack.SetAsVariant(const Index: String; const Value: Variant);
begin
  // ���ñ��ͱ�����Value ���ʺϴ����ݣ�
  SetAsStream(Index, iocp_utils.VariantToStream(Value, True));
end;

procedure TBasePack.SetField(EleType: TElementType; const VarName: AnsiString;
                             const Value: PListVariable; const SValue: AnsiString = '');
var
  Field: TVarField;
begin
  // �������

  // etBuffer��etStream��etRecord ���ֱ䳤���ͣ�
  // ֻ�������ã�SaveToMemStream ʱ���룬Clear ʱ�ͷš�

  // �������ƺϷ���
  CheckFieldName(VarName);

  if (EleType = etString) then  // JSON �����ݺϷ���
    CheckStringValue(SValue);

  // �������Ƿ����
  if FindField(VarName, Field) then
  begin
    Dec(FSize, Field.FieldSpace); // ��-��+
    Field.InterClear;  // ���ܸı����ͣ��ͷſռ�
  end else begin  // ����һ��
    Field := TVarField.Create(UpperCase(VarName));
    FList.Add(Field);
  end;

  case EleType of
    etBoolean:  // �߼�
      Field.SetAsBoolean(Value^.BooleanValue);
    etCardinal: // �޷�������
      Field.SetAsCardinal(Value^.CardinalValue);
    etDateTime: // ʱ������ 8 �ֽ�
      Field.SetAsDateTime(Value^.DateTimeValue);
    etFloat:    // ������
      Field.SetAsFloat(Value^.FloatValue);
    etInt64:    // 64 λ����
      Field.SetAsInt64(Value^.Int64Value);
    etInteger:  // ����
      Field.SetAsInteger(Value^.IntegerValue);
    etBuffer:   // �ڴ�����
      Field.SetAsBuffer(Value^.Data);
    etString:   // �ַ���
      Field.SetAsString(SValue);  // �� AnsiString
    etRecord:   // ��¼����
      Field.SetAsRecord(Value^.Data);
    etStream:   // ������
      Field.SetAsStream(Value^.Data);
  end;

  // ת���������ܳ��� = FSize
  //     ��ʽ��ElementCount + Variable, Variable2...
  // ������ʽ��EleType + NameSize + Name + Value | (BufferSize + Buffer)
  //   ����TBasePack.SaveToMemStream

  // ���������ռ�
  if (FSize = 0) then
    Inc(FSize, SizeOf(Integer));

  // EleType + NameSize + ���Ƴ���
  Inc(FSize, STREAM_VAR_SIZE + Length(VarName));

  // ���ݳ���
  Inc(FSize, Field.Size);

  // �䳤���͵ĳ�������
  if (EleType in [etStream, etBuffer, etString, etRecord]) then
    Inc(FSize, SizeOf(Integer));

end;

procedure TBasePack.VarToJSON(var Buf: PAnsiChar; const VarName,
  VarValue: AnsiString; Digital: Boolean; FirstPos, EndPos: Boolean);
begin
  // ���ֶα���Ϊ JSON
  if FirstPos then  // ��ʼ
  begin
    PDblChars(Buf)^ := AnsiString('{"');
    Inc(Buf, 2);
  end else
  begin
    PAnsiChar(Buf)^ := AnsiChar('"');
    Inc(Buf);
  end;

  // ����
  System.Move(VarName[1], Buf^, Length(VarName));
  Inc(Buf, Length(VarName));

  // ð��
  if Digital then  // ��������
  begin
    PDblChars(Buf)^ := AnsiString('":');
    Inc(Buf, 2)
  end else
  begin
    PThrChars(Buf)^ := AnsiString('":"');
    Inc(Buf, 3);
  end;

  // ֵ
  if (Length(VarValue) > 0) then
  begin
    System.Move(VarValue[1], Buf^, Length(VarValue));
    Inc(Buf, Length(VarValue));
  end;

  if EndPos then  // ĩβ
  begin
    if Digital then  // ֻ�� }
    begin
      PAnsiChar(Buf)^ := AnsiChar('}');
      Inc(Buf);
    end else
    begin
      PDblChars(Buf)^ := AnsiString('"}');
      Inc(Buf, 2);
    end;
  end else
  begin
    if Digital then  // ��������
    begin
      PAnsiChar(Buf)^ := AnsiChar(',');
      Inc(Buf);
    end else
    begin
      PDblChars(Buf)^ := AnsiString('",');
      Inc(Buf, 2);
    end;
  end;
end;

procedure TBasePack.Initialize(Stream: TStream; ClearIt: Boolean);
var
  mStream: TMemoryStream;
begin
  // �������롢������������Ϣ��Ҫ���ⲿ�ͷ�����
  if Assigned(Stream) then
    try
      if (FSize > 0) then
        Clear;
      FError := False;
      if (Stream is TMemoryStream) then  // �ڴ���
        with TMemoryStream(Stream) do
          try
            ScanBuffers(Memory, Size);
          finally
            if ClearIt then
              Clear;  // �����������
          end
      else begin
        Stream.Position := 0;
        mStream := TMemoryStream.Create; // ����ʱ��
        mStream.LoadFromStream(Stream);
        try
          ScanBuffers(mStream.Memory, mStream.Size);
        finally
          mStream.Free;
        end;
      end;
    except
      on E: Exception do
      begin
        FError := True;  // �쳣
        iocp_log.WriteLog('TBasePack.Initialize->' + E.Message);
      end;
    end;
end;

procedure TBasePack.Initialize(const AFileName: String);
var
  Handle: THandle;
  FileSize, NoUsed: Cardinal;
  Stream: TMemoryStream;
begin
  // ���ļ����롢������������Ϣ���ļ�����̫��
  if FileExists(AFileName) then
  begin
    if (FSize > 0) then
      Clear;

    FError := False;
    Handle := InternalOpenFile(AFileName);
    FileSize := Windows.GetFileSize(Handle, nil); // ��֧�ִ��ļ�

    Stream := TMemoryStream.Create;
    Stream.Size := FileSize;

    try
      try
        // ���뵽�ڴ���
        Windows.ReadFile(Handle, Stream.Memory^, FileSize, NoUsed, nil);

        ScanBuffers(Stream.Memory, FileSize);
      finally
        windows.CloseHandle(Handle);
        Stream.Free;
      end;
    except
      on E: Exception do
      begin
        FError := True;  // �쳣
        iocp_log.WriteLog('TBasePack.Initialize->' + E.Message);
      end;
    end;
  end;
end;

{ THeaderPack }

function THeaderPack.GetAttachPath: String;
begin
  // �����ڷ���˵�·�������ܣ�
  Result := AsString['_AttachPath'];
end;

function THeaderPack.GetConnection: Integer;
begin
  // �������ӱ��
  Result := AsInteger['_Connection'];
end;

function THeaderPack.GetData: Variant;
begin
  // �ͻ��˲������˺���
  Result := iocp_utils.StreamToVariant(FMain); // ��ת��Ϊ varByte Variant
end;

function THeaderPack.GetDateTime: TDateTime;
begin
  // ��Ϣ����ʱ��
  Result := AsDateTime['_DateTime'];
end;

function THeaderPack.GetDirectory: String;
begin
  // ����·��
  Result := AsString['_Directory'];
end;

function THeaderPack.GetErrMsg: String;
begin
  // �쳣��Ϣ
  Result := AsString['_ErrMsg'];
end;

function THeaderPack.GetFileName: String;
begin
  // ������ļ�����
  Result := AsString['_FileName'];
end;

function THeaderPack.GetFileSize: TFileSize;
begin
  // ȡ�ļ���С
  Result := AsInt64['_FileSize'];
end;

function THeaderPack.GetFunctionGroup: string;
begin
  // Զ�̺�����
  Result := AsString['_FunctionGroup'];
end;

function THeaderPack.GetFunctionIndex: Integer;
begin
  // Զ�̺������
  Result := AsInteger['_FunctionIndex'];
end;

function THeaderPack.GetHasParams: Boolean;
begin
  // SQL �Ƿ������
  Result := AsBoolean['_HasParams'];
end;

procedure THeaderPack.GetHeadMsg(Msg: PMsgHead);
begin
  // ����ʱ��������Ϣͷ���ݵ� Msg
  Msg^.Owner := FOwner;
  Msg^.SessionId := FSessionId;

  Msg^.MsgId := FMsgId;
  Msg^.DataSize := FDataSize;  // FSize
  Msg^.AttachSize := FAttachSize;
  Msg^.Offset := FOffset;
  Msg^.OffsetEnd := FOffsetEnd;

  Msg^.CheckType := FCheckType;
  Msg^.VarCount := FVarCount;
  Msg^.ZipLevel := FZipLevel;

  Msg^.Target := FTarget;
  Msg^.Action := FAction;
  Msg^.ActResult := FActResult;
end;

function THeaderPack.GetLocalFileName: string;
begin
  // ����ʵ���ļ���
  Result := AsString['_AttachFileName'];
end;

function THeaderPack.GetMsg: String;
begin
  // ��Ϣ����
  Result := AsString['_Msg'];
end;

function THeaderPack.GetMsgSize(RecvMode: Boolean): TFileSize;
  function GetEntitySize: TFileSize;
  begin
    if RecvMode then  // ����ģʽ
      Result := IOCP_SOCKET_SIZE + FDataSize
    else
      Result := IOCP_SOCKET_SIZE + FSize;
  end;
begin
  // ȡ��Ϣ���ݵĳ�
  if (FAction in FILE_CHUNK_ACTIONS) then
    Result := GetEntitySize + GetFileSize
  else
    Result := GetEntitySize + FAttachSize;
  case FCheckType of
    ctMurmurHash: begin
      if (FDataSize > 0) then
        Inc(Result, HASH_CODE_SIZE);
      if (FAttachSize > 0) then
        Inc(Result, HASH_CODE_SIZE);
    end;
    ctMD5: begin
      if (FDataSize > 0) then
        Inc(Result, HASH_CODE_SIZE * 2);
      if (FAttachSize > 0) then
        Inc(Result, HASH_CODE_SIZE * 2);
    end;
  end;
end;

function THeaderPack.GetNewCreatedFile: Boolean;
begin
  // �½����ļ�
  Result := AsBoolean['_NewCreatedFile'];
end;

function THeaderPack.GetNewFileName: String;
begin
  // �µ��ļ���
  Result := AsString['_NewFileName'];
end;

function THeaderPack.GetPassword: String;
begin
  // ����/����
  Result := AsString['_Password'];
end;

function THeaderPack.GetReuseSessionId: Boolean;
begin
  // �Ƿ�����ƾ֤
  Result := AsBoolean['_ReuseSessionId'];
end;

function THeaderPack.GetRole: TClientRole;
begin
  // ��ɫ/Ȩ��
  Result := TClientRole(AsInteger['_Role']);
end;

function THeaderPack.GetSize: Cardinal;
begin
  // ȫ�������Ŀռ��С�����ǻ��ࣩ
  if (FList.Count > 0) then
    Result := FSize
  else
    Result := FDataSize;
end;

function THeaderPack.GetSQL: String;
begin
  // SQL �ı�����
  Result := AsString['_SQLText'];
end;

function THeaderPack.GetSQLName: String;
begin
  // SQL ���ƣ������Ԥ�裬�� iocp_sqlMgr.TInSQLManager��
  Result := AsString['_SQLName'];
end;

function THeaderPack.GetStoredProcName: String;
begin
  // �洢��������
  Result := AsString['_StoredProcName'];
end;

function THeaderPack.GetToUser: String;
begin
  // Ŀ���û���
  Result := AsString['_ToUser'];
end;

function THeaderPack.GetURL: String;
begin
  // ������������ URL
  Result := AsString['_URL'];
end;

function THeaderPack.GetUserName: String;
begin
  // �û�������Դ
  Result := AsString['_UserName'];
end;

procedure THeaderPack.SetAttachPath(const Value: String);
begin
  // Ԥ�裺�����ڷ���˵�·�������ܣ�
  AsString['_AttachPath'] := Value;
end;

procedure THeaderPack.SetConnection(const Value: Integer);
begin
  // Ԥ�裺���ݿ����ӱ��
  AsInteger['_Connection'] := Value;
end;

procedure THeaderPack.SetDateTime(const Value: TDateTime);
begin
  // Ԥ�裺����ʱ��
  AsDateTime['_DateTime'] := Value;
end;

procedure THeaderPack.SetDirectory(const Value: String);
begin
  // Ԥ�裺����·��
  AsString['_Directory'] := Value;
end;

procedure THeaderPack.SetErrMsg(const Value: String);
begin
  // Ԥ�裺�쳣��Ϣ
  AsString['_ErrMsg'] := Value;
end;

procedure THeaderPack.SetFileName(const Value: String);
begin
  // Ԥ�裺������ļ�����
  AsString['_FileName'] := Value;
end;

procedure THeaderPack.SetFileSize(const Value: TFileSize);
begin
  // Ԥ�裺�ļ���С
  AsInt64['_FileSize'] := Value;
end;

procedure THeaderPack.SetFunctionGroup(const Value: String);
begin
  // Ԥ�裺Զ�̺�����
  AsString['_FunctionGroup'] := Value;
end;

procedure THeaderPack.SetFunctionIndex(const Value: Integer);
begin
  // Ԥ�裺Զ�̺������Ŀ��
  AsInteger['_FunctionIndex'] := Value;
end;

procedure THeaderPack.SetHasParams(const Value: Boolean);
begin
  // Ԥ�裺SQL �Ƿ������
  AsBoolean['_HasParams'] := Value;
end;

procedure THeaderPack.SetHeadMsg(Msg: PMsgHead; ForReturn: Boolean);
begin
  // ����ʱ������ Msg ���ݵ�Э��ͷ
  FError := False;   // !!!
  FOwner := Msg^.Owner;
  FSessionId := Msg^.SessionId;
  FMsgId := Msg^.MsgId;

  if ForReturn then  // ����˷�������
  begin
    FDataSize := 0;
    FAttachSize := 0;
    FVarCount := 0;
  end else
  begin
    FDataSize := Msg^.DataSize;
    FAttachSize := Msg^.AttachSize;
    FVarCount := Msg^.VarCount;
  end;

  FOffset := Msg^.Offset;
  FOffsetEnd := Msg^.OffsetEnd;

  FCheckType := Msg^.CheckType;
  FZipLevel := Msg^.ZipLevel;

  FTarget := Msg^.Target;
  FAction := Msg^.Action;
  FActResult := Msg^.ActResult;

  // �Ƿ��Ĳ���
  if (FAction in ECHO_SVC_ACTIONS) then
    FAction := atUnknown;
end;

procedure THeaderPack.SetLocalFileName(const Value: String);
begin
  // Ԥ�裺����ʵ���ļ���
  AsString['_AttachFileName'] := Value;
end;

procedure THeaderPack.SetMsg(const Value: String);
begin
  // Ԥ�裺��Ϣ����
  AsString['_Msg'] := Value;
end;

procedure THeaderPack.SetNewCreatedFile(const Value: Boolean);
begin
  // Ԥ�裺�½����ļ�
  AsBoolean['_NewCreatedFile'] := Value;
end;

procedure THeaderPack.SetNewFileName(const Value: String);
begin
  // Ԥ�裺�µ��ļ���
  AsString['_NewFileName'] := Value;
end;

procedure THeaderPack.SetPassword(const Value: String);
begin
  // Ԥ�裺����/����
  AsString['_Password'] := Value;
end;

procedure THeaderPack.SetReuseSessionId(const Value: Boolean);
begin
  // Ԥ�裺�Ƿ�����ƾ֤
  AsBoolean['_ReuseSessionId'] := Value;
end;

procedure THeaderPack.SetRole(const Value: TClientRole);
begin
  // Ԥ�裺��ɫ/Ȩ��
  AsInteger['_Role'] := Integer(Value);
end;

procedure THeaderPack.SetSQL(const Value: String);
begin
  // Ԥ�裺SQL �ı�����
  AsString['_SQLText'] := Value;
  if (UpperCase(TrimLeft(Copy(Value, 1, 7))) = 'SELECT ') then
    FAction := atDBExecQuery
  else
    FAction := atDBExecSQL;
end;

procedure THeaderPack.SetSQLName(const Value: String);
begin
  // Ԥ�裺SQL ���ƣ������Ԥ�裬�� iocp_sqlMgr.TInSQLManager��
  AsString['_SQLName'] := Value;
end;

procedure THeaderPack.SetStoredProcName(const Value: String);
begin
  // Ԥ�裺�洢��������
  AsString['_StoredProcName'] := Value;
end;

procedure THeaderPack.SetToUser(const Value: String);
begin
  // Ԥ�裺Ŀ���û��� = TargetUser
  AsString['_ToUser'] := Value;
end;

procedure THeaderPack.SetURL(const Value: String);
begin
  // Ԥ�裺������������ URL
  AsString['_URL'] := Value;
end;

procedure THeaderPack.SetUserName(const Value: String);
begin
  // Ԥ�裺�û�������Դ
  AsString['_UserName'] := Value;
end;

function THeaderPack.ToJSON: AnsiString;
const
  HEADER_SIZE = 150;  // Э��ͷ���� 150 �ֽ�����
  BOOL_VALUES: array[Boolean] of string = ('False', 'True');
var
  p: PAnsiChar;
  k, i: Integer;
begin
  // ����Ϣת��Ϊ JSON������Э��ͷ��

  k := FList.Count;
  if (k = 0) then
    SetLength(Result, HEADER_SIZE)
  else begin
    if (FDataSize = 0) then
      SetLength(Result, HEADER_SIZE + Size + Size div 2)
    else
      SetLength(Result, HEADER_SIZE + FDataSize + FDataSize div 2);
  end;

  // ��ʼλ��
  p := PAnsiChar(Result);

  // ��Ϣ��ʽ�ı䣬Э��ͷ���⼸���ֶ�û�����ˣ�
  // FDataSize��FAttachSize��FCheckType��FZipLevel

  VarToJSON(p, 'Owner', IntToStr(FOwner), True, True);  // UInt64
  VarToJSON(p, 'SessionId', IntToStr(FSessionId), True);
  VarToJSON(p, 'MsgId', IntToStr(FMsgId), True);   // UInt64
  VarToJSON(p, 'VarCount', IntToStr(k + 7), True); // Count + Э��ͷ�ֶ���
  VarToJSON(p, 'Target', IntToStr(FTarget), True);
  VarToJSON(p, 'Action', IntToStr(Integer(FAction)), True);
  VarToJSON(p, 'ActResult', IntToStr(Integer(FActResult)), True, False, k = 0);

  if (k > 0) then
    for i := 0 to k - 1 do
      with Fields[i] do
        case VarType of
          etNull:
            VarToJSON(p, Name, 'Null', True, False, i = k - 1);
          etBoolean:
            VarToJSON(p, Name, BOOL_VALUES[AsBoolean], True, False, i = k - 1);          
          etCardinal..etInteger:
            VarToJSON(p, Name, AsString, True, False, i = k - 1);
          else
            VarToJSON(p, Name, AsString, False, False, i = k - 1);          
        end;
        
  Delete(Result, p - PAnsiChar(Result) + 1, Length(Result));

end;

procedure THeaderPack.ToRecord(var ABuffer: PAnsiChar; var ASize: Cardinal);
var
  Dest: PAnsiChar;
  Rec: PStreamVariable;
  ClearMem: Boolean;
begin
  // �ѱ�����ת��Ϊ TElementType.etRecord ��¼
  //   ��ʽ��EleType + NameSize + TMsgHead + [Buffer]
  //   TMsgHead �ں�����

  // �����ڴ�
  ASize := STREAM_VAR_SIZE + MSG_HEAD_SIZE + FSize;
  GetMem(ABuffer, ASize);

  // ��������¼�����Ƴ���=0�����ݳ���=FSize
  Rec := PStreamVariable(ABuffer);
  Rec^.NameSize := 0;

  // ����Э��ͷ
  Dest := ABuffer;
  Inc(Dest, STREAM_VAR_SIZE);

  GetHeadMsg(PMsgHead(Dest));

  if (FList.Count = 0) or (FSize = 0) then  // ��ֵ
    Rec^.EleType := etNull
  else begin  // ������
    Rec^.EleType := etRecord;
    ClearMem := Assigned(FMain.Memory) = False;

    if ClearMem then
      SaveToMemStream(FMain);  // ת���ڴ���

    // ������ Memory �� ABuffer ĩβ
    Inc(Dest, MSG_HEAD_SIZE);
    System.Move(FMain.Memory^, Dest^, FSize);

    if ClearMem then  // ��ԭ״̬
      FMain.Clear;
  end;
end;

{ TReceivePack }

procedure TReceivePack.Cancel;
begin
  if Assigned(FAttachment) then  // �ͷŸ���
    FAttachment.Close(not (FAction in FILE_CHUNK_ACTIONS));
  Clear;
end;

procedure TReceivePack.Clear;
begin
  // ����TServerReceiver.OwnerClear
  FActResult := arUnknown; // ȡ��ʱ������
  if Assigned(FMain) then  // ��գ����ͷ�
    FMain.Clear;
  if Assigned(FAttachment) then  // �ͷŸ���
    FreeAndNil(FAttachment);
  inherited;
end;

constructor TReceivePack.Create;
begin
  inherited;
  FMain := TInMemStream.Create;  // ����������
end;

procedure TReceivePack.CreateAttachment(const LocalPath: String);
var
  LocalFileName: String;
begin
  // �����ո������ļ��������������ļ�������������ٸ������ѹ

  // ȡ�ϵ������ı����ļ�����
  if (FAction in FILE_CHUNK_ACTIONS) then
    LocalFileName := GetLocalFileName;

  if (LocalFileName <> '') then
    LocalFileName := LocalPath + LocalFileName 
  else
    LocalFileName := LocalPath + FileName + '_����ʹ��' + IntToStr(GetTickCount);

  if FileExists(LocalFileName) then
    FAttachment := TIOCPDocument.Create(LocalFileName, not (FAction in FILE_CHUNK_ACTIONS))
  else
    FAttachment := TIOCPDocument.Create(LocalFileName, True);

  // TIOCPDocument.Handle ��Чʱ = 0
  if (FAttachment.Handle > 0) then
  begin
    // 1. �����ļ�����
    if (FAttachment.Size = 0) then
    begin
      SetNewCreatedFile(True);  // �½��ļ�������ʱ�ͻ���Ҫ���¿�ʼ
      FAttachment.SetFileInf(Self);
    end else
      SetNewCreatedFile(False);

    // 2. �ϵ���������λ
    if (FAction in FILE_CHUNK_ACTIONS) then
      FAttachment.Position := FOffset;

    // 3. �����ļ��� URL
    SetURL(LocalFileName);

    FError := False;
  end else
  begin
    FError := True;
    FAttachment.Free;
    FAttachment := nil;
  end;

end;

destructor TReceivePack.Destroy;
begin
  if Assigned(FMain) then
  begin
    FMain.Free;
    FMain := nil;  // �� Clear �쳣
  end;
  inherited;
end;

{ TBaseMessage }

procedure TBaseMessage.CreateStreams(ClearList: Boolean);
var
  mStream: TStream;
begin
  // ׼��Ҫ���͵�������
  //   1. ���������ļ���ѹ��
  //   2. ���壺������������ -> ��

  FError := False;
  FVarCount := FList.Count;     // ��������

  // 1. �ȴ�������������Ҫ���������

  if (FAction = atUnknown) then  // ��Ӧ�����������
  begin
    FAttachFileName := '';
    InterSetAttachment(nil);
  end else
    if (FAttachFileName <> '') then  // ���ļ�
    begin
      if not Assigned(FAttachment) then // �ϵ�ʱ�Ѵ�
      begin
        OpenLocalFile;
        if FError and Assigned(FMain) then  // �쳣
          FMain.Size := 0;
      end;
    end else
    if Assigned(FAttachment) and not (FAction in FILE_CHUNK_ACTIONS) then
      if (FZipLevel <> zcNone) and (FAttachZiped = False) then  // ѹ����
      begin
        FAttachZiped := True;
        mStream := TIOCPDocument.Create;
        iocp_zlib.ZCompressStream(FAttachment, mStream);
        InterSetAttachment(mStream);  // �Զ��ͷ����е� FStream
      end;
        
  // 2. ����������
  //    Variant ��������ʱ FVarCount = 0

  if (FVarCount > 0) then // �б�����������
  begin
    FDataSize := FSize;   // �����ռ䳤��
    if (FZipLevel = zcNone) or (FAction in FILE_CHUNK_ACTIONS) then
      SaveToStream(FMain, False)  // ��������
    else begin  // ѹ��
      mStream := TMemoryStream.Create;
      try
        SaveToStream(mStream, False);  // ��������
        iocp_zlib.ZCompressStream(mStream, FMain);
        FDataSize := FMain.Size;  // �ı�
        FMain.Position := 0;
      finally
        mStream.Free;
      end;
    end;
    if ClearList then  // �������
      inherited Clear;
  end;

end;

procedure TBaseMessage.AdjustTransmitRange(ChunkSize: Integer);
begin
  // �������䷶Χ���ϵ㴫�䣩
  //   Ҫ���� FOffset��FAttachSize
  if (FOffset + ChunkSize <= FAttachSize) then
  begin
    FAttachSize := ChunkSize;  // ÿ������ϴ�����
    FOffsetEnd := FOffset + ChunkSize - 1;
  end else
  begin
    FOffsetEnd := FAttachSize - 1;
    Dec(FAttachSize, FOffset);
  end;
end;

procedure TBaseMessage.Clear;
begin
  //  �����Դ
  //    ����δ�ͷ� FAttachment������TReturnResult.ReturnResult
  FVarCount := 0;
  FDataSize := 0;
  FAttachSize := 0;
  FAttachFileName := '';
  if Assigned(FAttachment) then
    FreeAndNil(FAttachment);
  inherited;
end;

constructor TBaseMessage.Create(AOwner: TObject);
begin
  inherited Create;
  FMain := TInMemStream.Create; // ������
  FAction := atUnknown;    // δ֪����
  FZipLevel := zcNone;     // ѹ����
  if Assigned(AOwner) then // �ǿͻ���
  begin
    FOwner := TMessageOwner(AOwner);
    FMsgId := GetUTCTickCountEh(Self);
  end;
end;

class procedure TBaseMessage.CreateHead(ABuf: PAnsiChar; AResult: TActionResult);
begin
  // ����ˣ�����һ����Ϣ���ܾ����񡢳�ʱ����ɾ����
  System.Move(IOCP_SOCKET_FLAG[1], ABuf^, IOCP_SOCKET_FLEN); // C/S ��־
  with PMsgHead(ABuf + IOCP_SOCKET_FLEN)^ do
  begin
    Owner := 0;
    MsgId := 0;
    DataSize := 0;
    AttachSize := 0;
    VarCount := 0;
    Action := atServerEvent;
    ActResult := AResult;
    Target := SINGLE_CLIENT;
  end;
end;

destructor TBaseMessage.Destroy;
begin
  // �ͷ�������
  //   �� NilStreams �ͷ� FAttachment
  if Assigned(FMain) then
    FMain.Free;
  inherited;
end;

procedure TBaseMessage.GetCheckCode(AStream: TStream; ToBuf: PAnsiChar;
                                    ASize: TFileSize; var Offset: Cardinal);
begin
  // ��������͸�����У����
  //   ����TBaseReceiver.GetCheckCodes
  case FCheckType of
    ctMurmurHash: begin  // MurmurHash У��
      if (AStream is TMemoryStream) then  // ������
        PMurmurHash(ToBuf)^ := iocp_mmHash.MurmurHash64(TMemoryStream(AStream).Memory, ASize)
      else
      if (FAction in FILE_CHUNK_ACTIONS) then  // �������ļ���һ��
        PMurmurHash(ToBuf)^ := iocp_mmHash.MurmurHashPart64(TIOCPDocument(AStream).Handle,
                                                            FOffset, FAttachSize)
      else  // �����ļ�
        PMurmurHash(ToBuf)^ := iocp_mmHash.MurmurHash64(TIOCPDocument(AStream).Handle);
      Inc(Offset, HASH_CODE_SIZE);
    end;
    ctMD5: begin  // MD5 У��
      if (AStream is TMemoryStream) then  // ������
        PMD5Digest(ToBuf)^ := iocp_md5.MD5Buffer(TMemoryStream(AStream).Memory, ASize)
      else
      if (FAction in FILE_CHUNK_ACTIONS) then  // �������ļ���һ��
        PMD5Digest(ToBuf)^ := iocp_md5.MD5Part(TIOCPDocument(AStream).Handle,
                                               FOffset, FAttachSize)
      else  // �����ļ�
        PMD5Digest(ToBuf)^ := iocp_md5.MD5File(TIOCPDocument(AStream).Handle);
      Inc(Offset, HASH_CODE_SIZE * 2);
    end;
  end;
end;

procedure TBaseMessage.GetFileInfo(const AFileName: String);
var
  FileSize: TFileSize;
  CreationTime, AccessTime, LastWriteTime: TFileTime;
begin
  // ȡ�ļ�������Ϣ����32λ��С���ļ�����̫�󣩡�����ʱ��
  //   ����TIOCPDocument.SetFileInf
  GetLocalFileInf(AFileName, FileSize, CreationTime, AccessTime, LastWriteTime);
  SetFileSize(FileSize);
  AsCardinal['_creationLow'] := CreationTime.dwLowDateTime;
  AsCardinal['_creationHigh'] := CreationTime.dwHighDateTime;
  AsCardinal['_accessLow'] := AccessTime.dwLowDateTime;
  AsCardinal['_accessHigh'] := AccessTime.dwHighDateTime;
  AsCardinal['_modifyLow'] := LastWriteTime.dwLowDateTime;
  AsCardinal['_modifyHigh'] := LastWriteTime.dwHighDateTime;
end;

procedure TBaseMessage.InterSetAttachment(AStream: TStream);
begin
  // ���ø�����������
  if Assigned(FAttachment) then
    FAttachment.Free;
  FAttachment := AStream;
  if Assigned(FAttachment) then
  begin
    FAttachSize := FAttachment.Size;
    FAttachment.Position := 0;  // ����
    if (FAction <> atFileUpChunk) and  // ���ļ�У��ǳ���ʱ��ȡ����
       (FAttachSize > MAX_CHECKCODE_SIZE) and (FCheckType > ctNone) then
      FCheckType := ctNone;
  end else
    FAttachSize := 0;
end;

procedure TBaseMessage.LoadHead(Data: PWsaBuf);
var
  Msg: PMsgHead; 
begin
  // ������Э��ͷ����Ϣ��
  //   �װ���IOCP_HEAD_FLAG + TMsgHead + [У���� + У����] + [����ԭʼ����]

  Data^.len := IOCP_SOCKET_SIZE;  // ���ݳ���
  Msg := PMsgHead(Data^.buf + IOCP_SOCKET_FLEN);

  System.Move(IOCP_SOCKET_FLAG[1], Data^.buf^, IOCP_SOCKET_FLEN); // C/S ��־
  GetHeadMsg(Msg);  // ����Э��ͷ

  // ����У����
  if (FCheckType > ctNone) then
  begin
    if (FDataSize > 0) then
      GetCheckCode(FMain, Data^.buf + Data^.len, FDataSize,  Data^.len);
    if (FAttachSize > 0) then
      GetCheckCode(FAttachment, Data^.buf + Data^.len, FAttachSize, Data^.len);
  end;

  // �ӿ����ݷ��ͣ�FHeader ���ݲ���ʱ��һ���ͣ�
  //   ������շ�����ռ������ƣ����Ϊ IO_BUFFER_SIZE
  if (FDataSize > 0) and (IO_BUFFER_SIZE >= FDataSize + Data^.len) then
  begin
    System.Move(FMain.Memory^, (Data^.buf + Data^.len)^, FDataSize);
    Inc(Data^.len, FDataSize);
    FMain.Clear;     // ���
    FDataSize := 0;  // ����
  end;
  
end;

procedure TBaseMessage.LoadFromFile(const AFileName: String; OpenAtOnce: Boolean);
begin
  // ����Ҫ������ļ���
  if FileExists(AFileName) then
  begin
    FAttachFileName := AFileName;
    if (FZipLevel = zcNone) then
      FZipLevel := GetCompressionLevel(FAttachFileName);  // ѹ����
    GetFileInfo(FAttachFileName);  // �ļ�������Ϣ
    SetDirectory(ExtractFilePath(FAttachFileName)); // �ϵ㴫��ʱ����
    SetFileName(ExtractFileName(FAttachFileName));  // ����ʱ���ļ�������
    if OpenAtOnce then  // �������ˣ����̴򿪣���ֹ��ɾ��
      OpenLocalFile
    else
      InterSetAttachment(Nil);
  end else
    FError := True;
end;

procedure TBaseMessage.LoadFromStream(AStream: TStream; AZipCompressIt: Boolean);
var
  mStream: TStream;
begin
  // ����Ҫ�����������
  //   �������ڲ�ѹ������ͨ�� ZipLevel ������Ϊѹ��
  if Assigned(AStream) then
  begin
    if AZipCompressIt then
      FZipLevel := zcDefault;
    FAttachZiped := (FZipLevel <> zcNone);

    if (FZipLevel = zcNone) then
      InterSetAttachment(AStream)
    else
    if Assigned(AStream) then  // ѹ�����ļ���
    begin
      mStream := TIOCPDocument.Create;
      try
        iocp_zlib.ZCompressStream(AStream, mStream);
        InterSetAttachment(mStream);
      finally
        AStream.Free;  // �ͷ�
      end;
    end;

    // �����ļ���
    inherited SetFileName('_stream.strm');
  end;
end;

procedure TBaseMessage.LoadFromVariant(AData: Variant);
begin
  // ����Ҫ����� Variant �������ݣ����ݼ���
  //   ���ݼ����������壨FVarCount = 0�����Զ�ѹ�����Զ�����������ݣ�
  //   ��Ҫ���� String ��������������!
  
  if VarIsNull(AData) then
    Exit;

  // �����������
  if (FSize > 0) then
    inherited Clear;
  if Assigned(FMain) then
    FMain.Free;  // �ͷ�
  if Assigned(FAttachment) then
    FreeAndNil(FAttachment);

  FMain := iocp_utils.VariantToStream(AData, True) as TInMemStream;
  FDataSize := FMain.Size;

  FAttachZiped := True;
  FZipLevel := zcDefault;
  FVarCount := 0;  // ����
  
end;

procedure TBaseMessage.NilStreams(CloseAttachment: Boolean);
begin
  // ������ϣ�������Դ
  //   C/S ģʽ���ݷ��������Զ��ظ�������
  //   ����TClientParams.InternalSend��TReturnResult.ReturnResult;
  if (FSize > 0) then
    inherited Clear;
  FDataSize := 0;
  FVarCount := 0;
  FAttachSize := 0;
  FAttachFileName := '';
  if Assigned(FMain.Memory) then
    FMain.Clear;
  if Assigned(FAttachment) and CloseAttachment then
    FreeAndNil(FAttachment);
end;

procedure TBaseMessage.OpenLocalFile;
var
  mStream, mZStream: THandleStream;
begin
  // ��Ҫ������ļ�
  mStream := TIOCPDocument.CreateEx(FAttachFileName);
  if (mStream.Handle > 0) then
  begin
    if (mStream.Size > 1021*1024*32) then  // �ļ�̫�󣬲�ѹ��
      FZipLevel := zcNone;
    if (FZipLevel = zcNone) or (FAction in FILE_CHUNK_ACTIONS) then
      InterSetAttachment(mStream)
    else begin
      // ѹ������ʱ�ļ�!
      mZStream := TIOCPDocument.Create;
      try
        iocp_zlib.ZCompressStream(mStream, mZStream, zcDefault);
        InterSetAttachment(mZStream);  // ��ǰ
        SetFileSize(FAttachSize);  // �ں󣬵����ļ���С
      finally
        mStream.Free;  // �ͷ�ԭ�ļ�
      end;
    end;
  end else
  begin
    mStream.Free;
    InterSetAttachment(nil);
    FError := True;
  end;
end;

{ TMessageWriter }

constructor TMessageWriter.Create(SurportHttp: Boolean);
begin
  inherited Create;
  FSurportHttp := SurportHttp;
  FLock := TThreadLock.Create;
end;

destructor TMessageWriter.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TMessageWriter.LoadMsg(const UserName: String; Msg: TBaseMessage);
var
  FileName, NewFileName: String;
begin
  // ���û���Ϣ�ļ�
  //   �û�Ϊ Params.UserName������Ϣ�ļ���������װ��
  //   ��Ҫֱ���� Msg.LoadFromFile �ķ���

  // �ļ����û�����ϢĿ¼
  FileName := iocp_varis.gUserDataPath + UserName + '\msg\main.msg';
  NewFileName := FileName + '_' + IntToStr(GetUTCTickCount);

  FLock.Acquire;
  try
    if FileExists(FileName) then
      RenameFile(FileName, NewFileName)  // �ļ�����
    else
      Exit;
  finally
    FLock.Release;
  end;

  // ���̴��ļ� True
  Msg.LoadFromFile(NewFileName, True);

end;

procedure TMessageWriter.SaveMsg(Data: PPerIOData; const ToUser: String);
var
  Count: Integer;    // ��Ϣ��
  iValue: Cardinal;
  Handle: THandle;
  Rec: TStreamVariable;
begin
  // д��Ϣ�ļ�
  // ���յ������ݿ鱣�浽�ļ�����������������ת�����̣�
  // �ٶȸ��죬�����ܼ��븽���� URL ����
  // �ļ���ʽ��OFFLINE_MSG_FLAG + ElementCount + Record... ...

  Rec.EleType := etRecord; // ��һ����¼
  Rec.NameSize := 0; // û�м�¼����

  FLock.Acquire;

  // ��/�½���Ϣ�ļ����Զ�����ļ���־��
  // InternalOpenMsgFile �� INVALID_HANDLE_VALUE תΪ 0
  Handle := InternalOpenMsgFile(iocp_varis.gUserDataPath +
                                ToUser + '\msg\main.msg', True);

  try
    if (Handle > 0) then
    begin
      // ����Ϣ��
      Count := 0;
      Windows.ReadFile(Handle, Count, SizeOf(Integer), iValue, nil);

      // ��Ϣ�� + 1���� OFFLINE_MS_FLAG ��д��
      Inc(Count);  // +
      Windows.SetFilePointer(Handle, SizeOf(Integer), nil, FILE_BEGIN);
      Windows.WriteFile(Handle, Count, SizeOf(Integer), iValue, nil);

      // ���ļ�ĩλ�ã�д��Ϣ����
      Windows.SetFilePointer(Handle, 0, nil, FILE_END);
      Windows.WriteFile(Handle, Rec, STREAM_VAR_SIZE, iValue, nil);   // 1.д����
      Windows.WriteFile(Handle, (Data^.Data.buf + IOCP_SOCKET_FLEN)^, // 2.д Data
                        Data^.Overlapped.InternalHigh - IOCP_SOCKET_FLEN,
                        iValue, nil);
    end;
  finally
    if (Handle > 0) then
      Windows.CloseHandle(Handle);
    FLock.Release;
  end;
end;

procedure TMessageWriter.SaveMsg(Msg: THeaderPack);
var
  Count: Integer;    // ��Ϣ��
  iSize, iValue: Cardinal;
  Handle: THandle;
  Buffer: PAnsiChar;
begin
  // д��Ϣ�ļ�
  // �ļ���ʽ��OFFLINE_MSG_FLAG + ElementCount + Record... ...

  // �������ʱ·�� gTempDirectory�����շ� Params.ToUser
  // ��תΪ JSON��Msg Ϊ THeaderPack�����Ա��� TReceivePack��TSendMessage

  if FSurportHttp and (Msg is TReceivePack) then
    if Assigned(TReceivePack(Msg).Attachment) then
    begin
      // ���븽���� URL ����
      // <a href="/web_site/downloads/filename.doc">FileName.doc</a>
      Msg.SetURL('<a href="' + Msg.GetURL + '">' +
          ExtractFileName(TReceivePack(Msg).Attachment.FileName) + '</a>');
    end;

  // Msg ת��Ϊ��¼
  Msg.ToRecord(Buffer, iSize);

  // ����Ϣ�ļ���д��

  FLock.Acquire;

  // ��/�½���Ϣ�ļ����Զ�����ļ���־��
  // �����û�ʱ��Ϊÿ�û���һ��������ݵ���Ŀ¼
  // MyCreateDir(gTempDirectory + Msg.GetToUser);

  // InternalOpenMsgFile �� INVALID_HANDLE_VALUE תΪ 0
  Handle := InternalOpenMsgFile(iocp_varis.gUserDataPath +
                                Msg.GetToUser + '\msg\main.msg', True);

  try
    if (Handle > 0) then
    begin
      // ����Ϣ��
      Count := 0;
      Windows.ReadFile(Handle, Count, SizeOf(Integer), iValue, nil);

      // ��Ϣ�� + 1���� OFFLINE_MS_FLAG ��д��
      Inc(Count);  // +
      Windows.SetFilePointer(Handle, SizeOf(Integer), nil, FILE_BEGIN);
      Windows.WriteFile(Handle, Count, SizeOf(Integer), iValue, nil);

      // ���ļ�ĩλ�ã��� Buffer д���ļ�
      Windows.SetFilePointer(Handle, 0, nil, FILE_END);
      Windows.WriteFile(Handle, Buffer^, iSize, iValue, nil);
    end;
  finally
    FreeMem(Buffer);
    if (Handle > 0) then
      Windows.CloseHandle(Handle);
    FLock.Release;
  end;
end;

{ TMessageReader }

procedure TMessageReader.Close;
begin
  // ���ļ����
  FCount := 0;
  if (FHandle > 0) then
    Windows.CloseHandle(FHandle);
end;

destructor TMessageReader.Destroy;
begin
  Close;
  inherited;
end;

function TMessageReader.Extract(Msg: TReceivePack; LastMsgId: TIOCPMsgId): Boolean;
var
  Rec: TStreamVariable;
  MsgHead: TMsgHead;
  EleType, iCount: Cardinal;
  function LocateNewMessage: Boolean;
  begin
    // ����������Э��ͷ
    Windows.ReadFile(FHandle, Rec, STREAM_VAR_SIZE, EleType, nil);
    Windows.ReadFile(FHandle, MsgHead, MSG_HEAD_SIZE, iCount, nil);
    if (EleType <> STREAM_VAR_SIZE) or (iCount <> MSG_HEAD_SIZE) then
    begin
      Result := False;
      Rec.EleType := etNull;
    end else begin
      Result := (LastMsgId = 0) or (MsgHead.MsgId > LastMsgId);
      if (Result = False) then  // �ƽ�������һ��λ��
        Windows.SetFilePointer(FHandle, MsgHead.DataSize, nil, FILE_CURRENT);
    end;
  end;
var
  Buffer: PAnsiChar;
begin
  // ��ȡһ����Ϣ��¼
  // LastMsgId Ϊ�Ѷ��������Ϣ id������ id ���������Ϣ
  // LastMsgId = 0 -> ȫ������
  // �ļ���ʽ��OFFLINE_MSG_FLAG + ElementCount + Record... ...

  Msg.Clear;
  Msg.FAction := atUnknown;

  // ��������
  while (LocateNewMessage = False) and (Rec.EleType <> etNull) do
    { �ҵ�һ���¼�¼��MsgId > LastMsgId } ;

  // ��������Ϣ
  Result := (Rec.EleType <> etNull);
  
  if Result then
  begin
    Msg.SetHeadMsg(@MsgHead);  // Э��ͷ
    GetMem(Buffer, MsgHead.DataSize);
    try
      Windows.ReadFile(FHandle, Buffer^, MsgHead.DataSize, iCount, nil);
      if (MsgHead.DataSize = iCount) then
      begin
        Msg.ScanBuffers(Buffer, MsgHead.DataSize);
        Result := True;
      end;
    finally
      FreeMem(Buffer);
    end;
  end;
  
end;

procedure TMessageReader.Open(const FileName: String);
var
  iValue: Cardinal;
begin
  // ��������Ϣ�ļ�
  // InternalOpenMsgFile �� INVALID_HANDLE_VALUE תΪ 0
  FHandle := InternalOpenMsgFile(FileName);  // ���Զ�����ļ���־
  if (FHandle > 0) then  // ������Ϣ���������������Ϣ
    Windows.ReadFile(FHandle, FCount, SizeOf(Integer), iValue, nil)
  else
    FCount := 0;
end;

end.
