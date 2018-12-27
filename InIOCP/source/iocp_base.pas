(*
 * iocp c/s ����������ͳ�����
 *)
unit iocp_base;

//
// ȫ�� record ��Ҫ�� packed ���ͣ���д�ٶȸ��졣
//

interface

{$I in_iocp.inc}               

uses
  Windows, Classes, 
  iocp_Winsock2, iocp_wsExt, iocp_zlib;

type

  // �շ��ڴ�����;
  TIODataType = (
    ioAccept,                 // ����
    ioReceive,                // ����
    ioSend,                   // ����
    {$IFDEF TRANSMIT_FILE}
    ioTransmit,               // TransmitFile ����
    {$ENDIF}
    ioPush,                   // ����
    ioDelete,                 // ������ɾ��
    ioTimeOut,                // ��ʱ
    ioRefuse                  // �ܾ�����
  );

  // TLinkRec.data ��ŵ���������
  TObjectType = (
    otEnvData,                // �ͻ��˹��������ռ�
    otTaskInf,                // ��������������Ϣ              
    otIOData,                 // IO �ṹ����
    
    otSocket,                 // TIOCPSocket ����
    otHttpSocket,             // THttpSocket ����
    otStreamSocket,           // TStreamSocket ����
    otWebSocket,              // TWebSocket ���󣨱�����
    otBroker                  // �������
  );

  // ˫������ �ṹ
  PLinkRec = ^TLinkRec;
  TLinkRec = record
    {$IFDEF DEBUG_MODE}
    No: Integer;              // �ڵ���
    {$ENDIF}
    Data: Pointer;            // ����κ���������
    Prev, Next: PLinkRec;     // ǰ��һ�ڵ�
    Auto: Boolean;            // �Ƿ��� SetLength �Զ�����
    InUsed: Boolean;          // �Ƿ�ռ��
  end;

  // �� IO ���ݽṹ������_WSABUF��

  PPerIOData = ^TPerIOData;
  TPerIOData = record
    Overlapped: TOverlapped;  // ������ڵ�һλ��
    Data: TWsaBuf;            // �����С����ַ
    IOType: TIODataType;      // ��;����
    RefCount: Integer;        // ���ã�����
    Owner: TObject;           // ������TBaseSocket
    Node: PLinkRec;           // �����Ӧ�� PLinkRec���������
  end;

  // ��������
  //   v2.0 ȡ��Э�� TServiceType�����ݲ�������ȷ��Э�飬
  // ��չ��������ʱҪע�ⷶΧ������
  //   TBusiWorker.Execute��TRecvThread.HandleInMainThread

  TActionType = (
    // stEcho����Ӧ����
    atUnknown,                //0 δ֪

    // stCertify����֤����
    atUserLogin,              // ��¼
    atUserLogout,             // �Ͽ����ǳ�
    atUserRegister,           // ע���û�
    atUserModify,             // �޸�����
    atUserDelete,             // ɾ���û�
    atUserQuery,              // ��ѯ���߿ͻ���
    atUserState,              // ��ѯ�û�״̬

    // stMessage���ı���Ϣ����
    atTextSend,               // �ı���Ϣ ++
    atTextPush,               // ����Ϣ�������ͻ���
    atTextBroadcast,          // �㲥
    atTextGet,                // ȡ������Ϣ
    atTextGetFiles,           // ȡ������Ϣ�ļ��б�

    // stFile���ļ�����
    atFileList,               // �г�Ŀ¼���ļ�
    atFileSetDir,             // ���õ�ǰĿ¼
    atFileRename,             // �������ļ�
    atFileRenameDir,          // ������Ŀ¼

    atFileDelete,             // ɾ���ļ�
    atFileDeleteDir,          // ɾ��Ŀ¼
    atFileMakeDir,            // �½�Ŀ¼

    atFileDownload,           // �����ļ�
    atFileUpload,             // �ϴ��ļ�
    atFileDownChunk,          // ����һ���ļ����ϵ����أ�
    atFileUpChunk,            // �ϴ�һ���ļ����ϵ��ϴ���

    atFileRequest,            // ����Է������ļ�
    atFileSendTo,             // �ϴ�����ʱ·��������
    atFileShare,              // ���������ļ�

    // stDatabase�����ݿ����
    atDBGetConns,             // ��ѯ���ݿ�����
    atDBConnect,              // ���ݿ�����
    atDBExecSQL,              // ִ�� SQL
    atDBExecQuery,            // ���ݿ��ѯ
    atDBExecStoredProc,       // ִ�д洢����
    atDBApplyUpdates,         // Delta �������ݿ�

    // stCustom���Զ���
    atCallFunction,           // ����Զ�̺���
    atCustomAction,           // �Զ��壨TCustomClient ������

    // �������
    atNilCancel,              // �ͻ���ȡ������

    // ������ڲ�����
    atAfterReceive,           // ���ո������
    atAfterSend,              // ���͸������
    atServerEvent             // �������¼�
  );

  // �������/״̬

  TActionResult = (
    // ===== �ͻ��˲������ =====
    arUnknown,                // δ��

    arOK,                     // �ɹ�/����
    arFail,                   // ʧ��
    arCancel,                 // ȡ��/�ܾ�
    
    // ����״̬
    arEmpty,                  // ����Ϊ��
    arExists,                 // �Ѵ���
    arMissing,                // ������/��ʧ
    arOccupied,               // ��ռ��
    arOutDate,                // �ļ�/ƾ֤����

    // ���ݴ���״̬
    arRequest,                // ����
    arAnswer,                 // Ӧ��
    arAccept,                 // ����
    arAsTempFile,             // �����ļ�����ʱ·��

    // �û�״̬/����
    arLogout,                 // �ǳ� 
    arOnline,                 // ����
    arOffline,                // ���ߣ�δ��¼��

    arDeleted,                // ��ɾ��
    arRefuse,                 // �ܾ�����
    arTimeOut,                // ��ʱ�ر�

    // ===== �쳣������� =====

    arErrAnalyse,             // ���������쳣
    arErrBusy,                // ϵͳ��æ
    arErrHash,                // �����У�������
    arErrHashEx,              // �ͻ���У�������
    arErrInit,                // ��ʼ���쳣
    arErrNoAnswer,            // ��Ӧ��
    arErrPush,                // �����쳣
    arErrUser,                // �Ƿ��û�
    arErrWork                 // ִ�������쳣
  );

  // C/S ����У������
  TDataCheckType  = (
    ctNone,                   // ��У��
    ctMD5,                    // MD 5
    ctMurmurHash              // MurmurHash
  );

  {$IFDEF WIN_64}
  IOCP_LARGE_INTEGER = Int64;   // 64 bits
  {$ELSE}
  IOCP_LARGE_INTEGER = Integer; // 32 bits
  {$ENDIF}

  {$IFDEF DELPHI_7}
  TServerSocket = Int64;
  TMessageOwner = Int64;
  TMurmurHash   = Int64;
  {$ELSE}
  TServerSocket = UInt64;
  TMessageOwner = UInt64;     // ���� 64+32 λϵͳ
  TMurmurHash   = UInt64;
  {$ENDIF}

  PMurmurHash   = ^TMurmurHash;
  
  TFileSize     = Int64;      // ֧�ִ��ļ�
  TIOCPMsgId    = Int64;      // 64 λ

  TActionTarget = Cardinal;   // ����Ŀ�Ķ���
  TZipLevel     = TZCompressionLevel;

  // ����Ϣ����Э��ͷ
  //   �޸�ʱ����ͬʱ�޸� THeaderPack �Ķ�Ӧ�ֶ�

  PMsgHead = ^TMsgHead;
  TMsgHead = record
    Owner: TMessageOwner;      // �����ߣ������
    SessionId: Cardinal;       // ��֤/��¼ ID
    MsgId: TIOCPMsgId;         // ��Ϣ ID

    DataSize: Cardinal;        // ��������Ϣ��ԭʼ���ȣ����壩
    AttachSize: TFileSize;     // �ļ��������ȣ�������
    Offset: TFileSize;         // �ϵ��������ļ�λ��
    OffsetEnd: TFileSize;      // �ϵ����������ݽ���λ��

    CheckType: TDataCheckType; // У������
    VarCount: Cardinal;        // ��������Ϣ�ı���/Ԫ�ظ���
    ZipLevel: TZipLevel;       // �����ѹ����

    Target: TActionTarget;     // Ŀ�Ķ�������
    Action: TActionType;       // ��������
    ActResult: TActionResult;  // �������
  end;

  // =============== WebSocket ��� ===============

  // ��������
  TWSOpCode = (
    ocContinuation = 0,
    ocText         = 1,
    ocBiary        = 2,
    ocClose        = 8,
    ocPing         = 9,
    ocPong         = 10
  );

  // ��Ϣ����
  TWSMsgType = (
    mtDefault,      // ��׼�� WebSocket Э��
    mtJSON,         // ��չ�� JSON ��Ϣ
    mtAttachment    // ��չ�ĸ�����
  );

  // ����
  PWSMask = ^TWSMask;
  TWSMask = array[0..3] of Byte;

  // ���ȣ�WebSocket ֡�ṹͷ
  PWebSocketFrame = ^TWebSocketFrame;
  TWebSocketFrame = array[0..9] of AnsiChar; // 2+8

  PByteAry = ^TByteAry;
  TByteAry = array of Byte;

  // ��ű�־�ֶεĿռ�
  PInIOCPJSONField = ^TInIOCPJSONField;
  TInIOCPJSONField = array[0..18] of AnsiChar;

  // ˫�ֽڡ����ֽ�����
  PDblChars = ^TDblChars;
  TDblChars = array[0..1] of AnsiChar;

  PThrChars = ^TThrChars;
  TThrChars = array[0..2] of AnsiChar;

  // =============== ������� ===============

  // ����ģʽ

  TProxyType = (
    ptDefault,
    ptOuter
  );

  // ����Э��

  TTransportProtocol = (
    tpNone,
    tpHTTP
  );

  TSocketBrokerType = (
    stDefault,
    stOuterSocket,
    stWebSocket
  );

  // �ڲ����ӱ�־����ӦInIOCP_INNER_SOCKET��
  PInIOCPInnerSocket = ^TInIOCPInnerSocket;
  TInIOCPInnerSocket = array[0..18] of AnsiChar;

  // =============== Ԫ��/����/�ֶ�/���� ===============
  // ������ת����������Ϣ

  // Ԫ��/����/�ֶ�/�������ͣ���Ҫ��λ�ã�

  TElementType = (             // *11
    etNull,                    // ��ֵ
    etBoolean,                 // �߼�
    etCardinal,                // �޷�������
    etFloat,                   // ������
    etInteger,                 // ����
    etInt64,                   // 64 λ����
    // ����ת JSON ʱ���ַ���
    etDateTime,                // ʱ������ 8 �ֽ�
    etBuffer,                  // �ڴ�����
    etString,                  // �ַ���
    etRecord,                  // ��¼����
    etStream                   // ������
  );
  
  // ���б�洢ʱ����Ϣ
  PListVariable = ^TListVariable;
  TListVariable = record
    EleType: TElementType;
    NameSize: SmallInt;
    case Integer of
      0: (BooleanValue: Boolean);
      1: (IntegerValue: Integer);
      2: (CardinalValue: Cardinal);
      3: (Int64Value: Int64);
      4: (FloatValue: Double);
      5: (DateTimeValue: TDateTime);
      6: (DataSize: Integer; Data: Pointer);  // �����ı������ȱ䳤��������
  end;

  // �ڴ������е�������Ϣ
  PStreamVariable = ^TStreamVariable;
  TStreamVariable = record
    EleType: TElementType;
    NameSize: SmallInt;
    // �����ţ�Name + DataSize + DataContent
  end;

  // =============== ������ ��Ϣ ===============

  // ������������Ϣ
  // ǰ���ֶβ��ܸ�λ�ã��� TTransmitFileBuffers ��һ��

  PTransmitTask = ^TTransmitTask;
  TTransmitTask = record
    Head: Pointer;            // �ȷ��͵�����
    HeadLength: DWORD;
    Tail: Pointer;            // ����͵�����
    TailLength: DWORD;
  
    // ����Դ���ͷ��ã�
    Handle: THandle;          // �ļ����
    RefStr: AnsiString;       // �ַ���
    Stream: TStream;          // �����󣬶�Ӧ Head
    Stream2: TStream;         // ������ 2����Ӧ Tail

    // ���ȣ�λ��
    Size: TFileSize;          // ��С
    Offset: TFileSize;        // ��ʼλ��
    OffsetEnd: TFileSize;     // ����λ��

    ObjType: TClass;          // ������
    AutoFree: Boolean;        // �Զ��ͷ���
  end;

  // =============== �ͻ���/ҵ�񻷾� ��Ϣ ===============

  // ��ɫ/Ȩ��
  TClientRole = (
    crUnknown,                 // δ��¼�û�
    crClient,                  // ��ͨ
    crAdmin,                   // ����Ա
    crSuper                    // ��������Ա
  );

  // �û�������Ϣ
  // ˫�ֽڻ��� String[n] Ҳ�ǵ��ֽ�

  TNameString = string[30];

  PClientInfo = ^TClientInfo;
  TClientInfo = record
    Socket: TServerSocket;     // TIOCPSocket������ 64+32 λϵͳ
    Role: TClientRole;         // ��ɫ��Ȩ��
    Name: TNameString;         // ����
    LoginTime: TDateTime;      // ��¼ʱ��
    LogoutTime: TDateTime;     // �ǳ�ʱ��
    PeerIPPort: TNameString;   // IP:Port
    Tag: TNameString;          // ������Ϣ
  end;

  // �û���������
  PEnvironmentVar = ^TEnvironmentVar;
  TEnvironmentVar = record
    BaseInf: TClientInfo;      // ������Ϣ
    WorkDir: string[128];      // ����·��
    IniDirLen: Integer;        // ��ʼ·�����ȣ��������ã�
    DBConnection: Integer;     // ��ģ���ӱ��
    ReuseSession: Boolean;     // ������֤�����ͷţ�
  end;

  // ��������¼
  PAttackInfo = ^TAttackInfo;
  TAttackInfo = record
    PeerIP: String[20];        // �ͻ��� IP
    TickCount: Int64;          // ���µ� UTC/_FILETIME ʱ��
    Count: Integer;            // �������
  end;

  // ==================== ƾ֤/��ȫ ====================

  PCertifyNumber = ^TCertifyNumber;
  TCertifyNumber = record
    case Integer of
      0: (Session: Cardinal);
      1: (DayCount: SmallInt; Timeout: SmallInt);      
  end;

  // ==================== �̡߳�����ͳ�� ==================== 

  // ȫ�� �����߳� �ĸſ��ṹ
  PWorkThreadSummary = ^TWorkThreadSummary;
  TWorkThreadSummary = record
    ThreadCount: LongInt;      // ����
    WorkingCount: LongInt;     // ������
    ActiveCount: LongInt;      // ���

    PackCount: LongInt;        // �������ݰ���
    PackInCount: LongInt;      // �յ����ݰ���
    PackOutCount: LongInt;     // �������ݰ���

    ByteCount: LongInt;        // ��λʱ���շ��ֽ���
    ByteInCount: LongInt;      // ��λʱ������ֽ���
    ByteOutCount: LongInt;     // ��λʱ�䷢���ֽ���
  end;

  TWorkThreadMaxInf = record
    MaxPackIn: LongInt;        // �յ�������ݰ���
    MaxPackOut: LongInt;       // ������������ݰ���
    MaxByteIn: LongInt;        // ÿ����յ�����ֽ���
    MaxByteOut: LongInt;       // ÿ�뷢��������ֽ���
  end;

  // ��һ �����߳� ����ϸ�ṹ
  PWorkThreadDetail = ^TWorkThreadDetail;
  TWorkThreadDetail = record
    Working: Boolean;          // ����״̬
    Index: Integer;            // ���

    PackCount: LongInt;        // �������ݰ�
    PackInCount: LongInt;      // �յ����ݰ�
    PackOutCount: LongInt;     // �������ݰ�

    ByteCount: LongInt;        // ��λʱ���շ��ֽ���
    ByteInCount: LongInt;      // ��λʱ������ֽ���
    ByteOutCount: LongInt;     // ��λʱ�䷢���ֽ���
  end;

const
  // ����״̬
  SERVER_STOPED       = $00;         // ֹͣ
  SERVER_RUNNING      = $10;         // ����
  SERVER_IGNORED      = $20;         // ���ԣ�������

  SOCKET_LOCK_FAIL    = 0;           // ����ʧ��
  SOCKET_LOCK_OK      = 1;           // �����ɹ�
  SOCKET_LOCK_CLOSE   = 2;           // �Ѿ��رա���������

  IO_BUFFER_SIZE      = 8192;        // ������շ����泤�ȣ��Ż��ֿ鷢�ͣ����ܴ���65535�������쳣��
  IO_BUFFER_SIZE_2    = 32768;       // �ͻ����շ����泤�� 4096 * 8

  DEFAULT_SVC_PORT    = 12302;       // Ĭ�϶˿�
  MAX_CLIENT_COUNT    = 300;         // Ԥ��ͻ���������

  INI_SESSION_ID      = 1;           // ���¼��ƾ֤
  MAX_FILE_VAR_SIZE   = 5120000;     // �ļ��ͱ�������󳤶� 5M

  SESSION_TIMEOUT     = 30;          // ������ƾ֤����Чʱ�䣬30 ����
  TIME_OUT_INTERVAL   = 180000;      // ��������ӵ�ʱ����, 180 ��
  WAIT_MILLISECONDS   = 15000;       // �ͻ��˷������ݺ�ȴ�������ʱ��

  INVALID_FILE_HANDLE = 0;           // ��Ч���ļ���������� INVALID_HANDLE_VALUE)

  // �ϵ㴫��ÿ������ͳ���
  //   ����ֵ�����ٶȿ죬������������Դ��
  MAX_CHUNK_SIZE     = 131072;      // 65536 * 2;

  MAX_CHECKCODE_SIZE = 204800000;   // �ļ����� 204M ʱ��ȡ��У�飨���ļ��ǳ���ʱ����
  OFFLINE_MSG_FLAG   = 2356795438;  // ������Ϣ���ļ�ͷ��־

  // ��Ϣ/�ļ����õ����⺬��
  ALL_CLIENT_SOCKET  = $FFFFFFFF;   // ȫ���ͻ���
  SINGLE_CLIENT      = 1;           // ĳһ�ͻ���

  HASH_CODE_SIZE     = SizeOf(TMurmurHash); // Hash ����
  MSG_HEAD_SIZE      = SizeOf(TMsgHead);    // ��Ϣͷ����

  POINTER_SIZE       = SizeOf(Pointer);     // ָ�볤��
  NEW_TICKCOUNT      = Cardinal(not 0);     // Socket δ���չ����ݵ�״̬

  STREAM_VAR_SIZE    = SizeOf(TStreamVariable);// �������ı�����������
  CLIENT_DATA_SIZE   = SizeOf(TClientInfo);    // �ͻ�����Ϣ����

  // ��������������С
  TASK_SPACE_SIZE    = SizeOf(TTransmitTask) - SizeOf(TClass) - SizeOf(Boolean);

  // Socket ��ַ��С
  ADDRESS_SIZE_16    = SizeOf(TSockAddr) + 16;

  // Echo ����
  ECHO_SVC_ACTIONS   = [atUnknown, atNilCancel, atAfterReceive,
                        atAfterSend, atServerEvent];

  // �ļ�Э����������Ͳ���
  REQUEST_ACTIONS    = [atFileUpload, atFileRequest, atFileSendTo];

  // �ϵ���������
  FILE_CHUNK_ACTIONS = [atFileDownChunk, atFileUpChunk];

  // C/S ģʽ��־
  IOCP_SOCKET_FLAG   = AnsiString('IOCP/2.5'#32);
  IOCP_SOCKET_FLEN   = Cardinal(Length(IOCP_SOCKET_FLAG));
  IOCP_SOCKET_SIZE   = IOCP_SOCKET_FLEN + MSG_HEAD_SIZE;
  MESSAGE_HEAD_SIZE  = IOCP_SOCKET_SIZE + HASH_CODE_SIZE * 4;

  // C/S ģʽȡ������
  IOCP_SOCKET_CANCEL = AnsiString('IOCP/2.5 CANCEL');
  IOCP_CANCEL_LENGTH = DWORD(Length(IOCP_SOCKET_CANCEL));

  // ��Ե㡢�㲥��Ϣ��󳤶ȣ�HASH_SIZE * 4 = 2 �� MD5 ����
  BROADCAST_MAX_SIZE = IO_BUFFER_SIZE - IOCP_SOCKET_SIZE -
                       MSG_HEAD_SIZE - HASH_CODE_SIZE * 4;

  // ================ webSocekt ====================

  // WebSocekt �� MAGIC-GUID�������޸ģ���
  WSOCKET_MAGIC_GUID = AnsiString('258EAFA5-E914-47DA-95CA-C5AB0DC85B11');

  // webSocekt �Ĳ�������
  WEBSOCKET_OPCODES  = [0, 1, 2, 8, 9, 10];

  // InIOCP ��չ WebSocket �� JSON ���ֶΣ�����=19����Ҫ�ģ�
  // ����TBaseJSON.SaveToStream
  INIOCP_JSON_FLAG     = AnsiString('{"_InIOCP_Ver":2.5,');
  INIOCP_JSON_FLAG_LEN = Length(INIOCP_JSON_FLAG);

  // InIOCP ��չ WebSocket �� JSON ���ֶΣ�����=19����Ҫ�ģ�
  // ����TBaseJSON.SaveToStream
  JSON_CHARSET_DEF   = AnsiString('"_UTF8_CHARSET":0,"');  // Ĭ���ַ���
  JSON_CHARSET_UTF8  = AnsiString('"_UTF8_CHARSET":1,"');  // UTF-8

  // ================ ������� ====================

  InIOCP_INNER_SOCKET = AnsiString('InIOCP_INNER_SOCKET');

implementation

var
  _WSAResult: Integer = 1;

procedure _WSAStartup;
var
  WSAData: TWSAData;
begin
  // ��ʼ�� Socket ����
  _WSAResult := iocp_Winsock2.WSAStartup(WINSOCK_VERSION, WSAData);
end;

procedure _WSACleanUp;
begin
  // ��� Socket ����
  if (_WSAResult = 0) then
    iocp_Winsock2.WSACleanUp;
end;

initialization
  _WSAStartup;

finalization
  _WSACleanUp;

end.
