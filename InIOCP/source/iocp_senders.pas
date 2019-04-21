// =================================================================
//
//            �������ݵ�ר�õ�Ԫ
//
//   ע��1. �����ÿ��ҵ���߳�һ�����ݷ�������
//          �� iocp_threads.TBusiThread��
//       2. �ͻ���ÿ�������߳�һ�����ݷ�������
//       3. TransmitFile ģʽ����ʱ��ÿ TBaseSocket ����һ��
//          TTransmitObject ������
//
// =================================================================
unit iocp_senders;

interface

{$I in_iocp.inc}

uses
  Windows, Classes, Variants, Sysutils,
  iocp_Winsock2, iocp_base, iocp_objPools, iocp_wsExt;

type

  // ================= ����������Ϣ ���� =================
  // ����ˡ��ͻ��˾��� TPerIOData�����ͻ����� Send ���ͣ�
  // �������������������ݵ���Ч�ԣ�Ҫ�ڵ���ǰ��顣

  TBaseTaskObject = class(TObject)
  private
    FOwner: TObject;             // ����
    FSocket: TSocket;            // �ͻ��˶�Ӧ���׽���
    FTask: TTransmitTask;        // ��������������
    FErrorCode: Integer;         // �쳣����
    FOnError: TNotifyEvent;      // �쳣�¼�
    function GetIOType: TIODataType;
    procedure SetOwner(const Value: TObject);
  protected
    FSendBuf: PPerIOData;        // �ص��ṹ
    procedure InterSetTask(const Data: PAnsiChar; Size: Cardinal; AutoFree: Boolean); overload;
    procedure InterSetTask(const Data: AnsiString; AutoFree: Boolean); overload;
    procedure InterSetTask(Handle: THandle; Size, Offset, OffsetEnd: TFileSize; AutoFree: Boolean); overload;
    procedure InterSetTaskVar(const Data: Variant);
  public
    procedure FreeResources(FreeRes: Boolean = True); virtual; abstract;
  public
    property ErrorCode: Integer read FErrorCode;
    property IOType: TIODataType read GetIOType;
    property Owner: TObject read FOwner write SetOwner; // r/w
    property Socket: TSocket read FSocket write FSocket; // r/w
  public
    property OnError: TNotifyEvent read FOnError write FOnError; // r/w
  end;

  // ================= �׽��ֶ������ݷ����� �� =================
  // ������� TransmitFile ģʽ���͵���������
  // ����������� TBaseSocket������������ TRANSMIT_FILE ��Ч
  
  {$IFDEF TRANSMIT_FILE}

  TTransmitObject = class(TBaseTaskObject)
  private
    FExists: Integer;       // �Ƿ�������
    function GetExists: Boolean;
  public
    constructor Create(AOwner: TObject);
    destructor Destroy; override;
    procedure FreeResources(FreeRes: Boolean = True); override;

    procedure SetTask(const Data: PAnsiChar; Size: Cardinal); overload;
    procedure SetTask(const Data: AnsiString); overload;
    procedure SetTask(Handle: THandle; Size: TFileSize); overload;

    procedure SetTask(Stream: TMemoryStream; Size: Cardinal); overload;
    procedure SetTask(Stream: TStream; Size: TFileSize;
                      Offset: TFileSize = 0; OffsetEnd: TFileSize = 0); overload;

    procedure SetTaskVar(const Data: Variant);

    procedure TransmitFile;
  public
    property Exists: Boolean read GetExists;
  end;

  {$ENDIF}

  // ================= �߳����ݷ����� ���� =================

  TBaseTaskSender = class(TBaseTaskObject)
  private
    FBufferSize: Cardinal;  // ���ͻ��泤��
    FChunked: Boolean;      // HTTP ����˷ֿ鷢������

    FMasking: Boolean;      // WebSocket ʹ������
    FOpCode: TWSOpCode;     // WebSocket ����
    FWebSocket: Boolean;    // WebSocket ����
    FWSCount: UInt64;       // WebSocket �������ݼ���
    FWSMask: TWSMask;       // WebSocket ����

    function GetData: PWsaBuf;
    procedure ChunkDone;
    procedure MakeFrameInf(Payload: UInt64);
    procedure InitHeadTail(DataLength: Cardinal; Fulled: Boolean);
    procedure InterSendBuffer(Data: PAnsiChar; ByteCount, Offset, OffsetEnd: Cardinal);
    procedure InterSendFile;
    procedure InternalSend;

    procedure SetChunked(const Value: Boolean);
    procedure SetOpCode(Value: TWSOpCode);
  protected
    procedure DirectSend(OutBuf: PAnsiChar; OutSize, FrameSize: Integer); virtual; abstract;
    procedure ReadSendBuffers(InBuf: PAnsiChar; ReadCount, FrameSize: Integer); virtual; abstract;
  public
    procedure FreeResources(FreeRes: Boolean = True); override;

    procedure Send(const Data: PAnsiChar; Size: Cardinal; AutoFree: Boolean = True); overload;
    procedure Send(const Data: AnsiString); overload;

    procedure Send(Handle: THandle; Size: TFileSize;
                   Offset: TFileSize = 0; OffsetEnd: TFileSize = 0;
                   AutoFree: Boolean = True); overload;

    procedure Send(Stream: TStream; Size: TFileSize; Offset: TFileSize = 0;
                   OffsetEnd: TFileSize = 0; AutoFree: Boolean = True); overload;

    procedure Send(Stream: TStream; Size: TFileSize; AutoFree: Boolean = True); overload;
    procedure SendVar(const Data: Variant);
    
    procedure SendBuffers;
  protected
    property Chunked: Boolean read FChunked write SetChunked;
  public
    property Data: PWsaBuf read GetData;
    property Masking: Boolean read FMasking write FMasking;
    property OpCode: TWSOpCode read FOpCode write SetOpCode; // r/w
  end;

  // ================= ҵ�����ݷ����� �� =================
  // �� WSASend ���� TPerIOData.Data.Buf
  // �����������ҵ���߳� TBusiThread

  TServerTaskSender = class(TBaseTaskSender)
  private
    FDualBuf: PPerIOData;   // �ֻ����ڴ��
    FTempBuf: PPerIOData;   // ��ʱ����
  protected
    procedure DirectSend(OutBuf: PAnsiChar; OutSize, FrameSize: Integer); override;
    procedure ReadSendBuffers(InBuf: PAnsiChar; ReadCount, FrameSize: Integer); override;
  public
    constructor Create(BufferPool: TIODataPool; DoubleBuf: Boolean);
    procedure CopySend(ARecvBuf: PPerIOData);
    procedure FreeBuffers(BufferPool: TIODataPool);
  public
    property Chunked;
  end;

  // ================= �ͻ������ݷ����� �� =================
  // �� Send ���� TPerIOData.Data.Buf

  TAfterSendEvent = procedure(First: Boolean; OutSize: Integer) of object;

  TClientTaskSender = class(TBaseTaskSender)
  private
    FFirst: Boolean;        // �װ�����
    FStoped: Integer;       // ����״̬(0=������1=ֹͣ)
    FAfterSend: TAfterSendEvent; // �����¼�
    function GetStoped: Boolean;
    procedure SetStoped(const Value: Boolean);
  protected
    procedure DirectSend(OutBuf: PAnsiChar; OutSize, FrameSize: Integer); override;
    procedure ReadSendBuffers(InBuf: PAnsiChar; ReadCount, FrameSize: Integer); override;
  public
    constructor Create;
    destructor Destroy; override;
  public
    property Stoped: Boolean read GetStoped write SetStoped;
  public
    property AfterSend: TAfterSendEvent read FAfterSend write FAfterSend;  
  end;

procedure MakeFrameHeader(const Data: PWsaBuf; OpCode: TWSOpCode; Payload: UInt64 = 0);

implementation

uses
  iocp_api, iocp_sockets, http_base;

procedure MakeFrameHeader(const Data: PWsaBuf; OpCode: TWSOpCode; Payload: UInt64);
var
  i: Integer;
  p: PByte;
begin
  // ����ˣ��������Ϣ�� WebSocket ֡��Ϣ
  //   ���� RSV1/RSV2/RSV3

  p := PByte(Data^.buf);

  p^ := Byte($80) + Byte(OpCode);
  Inc(p);

  case Payload of
    0..125: begin
      if (OpCode >= ocClose) then
        p^ := 0
      else
        p^ := Payload;
      Inc(p);
    end;
    126..$FFFF: begin
      p^ := 126;
      Inc(p);
      TByteAry(p)[0] := TByteAry(@Payload)[1];
      TByteAry(p)[1] := TByteAry(@Payload)[0];
      Inc(p, 2);
    end;
    else begin
      p^ := 127;
      Inc(p);
      for i := 0 to 7 do
        TByteAry(p)[i] := TByteAry(@Payload)[7 - i];
      Inc(p, 8);
    end;
  end;

  Data^.len := PAnsiChar(p) - Data^.buf;

end;

{ TBaseTaskObject }

procedure TBaseTaskObject.InterSetTask(const Data: AnsiString; AutoFree: Boolean);
begin
  // ���� AnsiString������˫�ֽڵ� String��
  FTask.RefStr := Data;
  FTask.Head := PAnsiChar(Data);
  FTask.HeadLength := Length(Data);
  FTask.AutoFree := AutoFree;
end;

procedure TBaseTaskObject.InterSetTask(const Data: PAnsiChar; Size: Cardinal;
                          AutoFree: Boolean);
begin
  // ����һ���ڴ� Buffer
  FTask.Head := Data;
  FTask.HeadLength := Size;
  FTask.AutoFree := AutoFree;
end;

function TBaseTaskObject.GetIOType: TIODataType;
begin
  // ȡ FSendBuf^.IOType���ͻ��������壩
  Result := FSendBuf^.IOType;
end;

procedure TBaseTaskObject.InterSetTask(Handle: THandle; Size, Offset, 
                          OffsetEnd: TFileSize; AutoFree: Boolean);
begin
  // �����ļ���� Handle
  //  Handle > 0 Ϊ��Ч������� iocp_utils.InternalOpenFile
  FTask.Handle := Handle;
  FTask.Size := Size;
  FTask.Offset := Offset;
  FTask.OffsetEnd := OffsetEnd;
  FTask.AutoFree := AutoFree;
end;

procedure TBaseTaskObject.InterSetTaskVar(const Data: Variant);
var
  p, Buf: Pointer;
  BufLength: Integer;
begin
  // ���Ϳɱ��������ݣ����ݼ���
  if VarIsNull(Data) then
    Exit;

  BufLength := VarArrayHighBound(Data, 1) - VarArrayLowBound(Data, 1) + 1;
  GetMem(Buf, BufLength);

  p := VarArrayLock(Data);
  try
    System.Move(p^, Buf^, BufLength);
  finally
    VarArrayUnlock(Data);
  end;

  // �����ڴ�����
  FTask.Head := Buf;
  FTask.HeadLength := BufLength;
  FTask.AutoFree := True;
end;

procedure TBaseTaskObject.SetOwner(const Value: TObject);
begin
  FOwner := Value;
  FTask.ObjType := Value.ClassType;
end;

{ TTransmitObject }

{$IFDEF TRANSMIT_FILE}

constructor TTransmitObject.Create(AOwner: TObject);
begin
  inherited Create;
  FOwner := AOwner;
  FTask.ObjType := AOwner.ClassType;
  GetMem(FSendBuf, SizeOf(TPerIOData));  // ֱ�ӷ���
  FSendBuf^.Data.len := 0;
  FSendBuf^.Node := nil;  // ���ǳ�����Ľڵ�
end;

destructor TTransmitObject.Destroy;
begin
  // �ͷ���Դ
  FreeResources;
  FreeMem(FSendBuf);
  inherited;
end;

procedure TTransmitObject.FreeResources(FreeRes: Boolean);
begin
  // �ͷ� TransmitFile ģʽ��������Դ
  //   �����ⲿ�ͷ�ʱ������ FreeRes=False
  try
    try
      if (windows.InterlockedDecrement(FExists) = 0) and FreeRes then
        if (FTask.ObjType = TIOCPSocket) then
        begin
          // 1. ֻ�� Stream��Stream2 ����Դ
          if Assigned(FTask.Stream) then  // ������
            FTask.Stream.Free;
          if Assigned(FTask.Stream2) then // ������
            FTask.Stream2.Free;
        end else
        if (FTask.ObjType = THttpSocket) then
        begin
          // 2. ֻ�� AnsiString��Handle��Stream ����Դ��
          //    ���໥�ų⣬����THttpRespone.SendWork;
          if Assigned(FTask.Stream) then  // �ڴ������ļ���
            FTask.Stream.Free
          else
          if (FTask.Handle > 0) then  // ������ļ����
            CloseHandle(FTask.Handle)
          else
          if (FTask.RefStr <> '') then
            FTask.RefStr := '';
        end else
        begin
          // 3. TStreamSocket ����������ĸ��ַ�����Դ���໥�ų�
          if Assigned(FTask.Stream) then  // �ڴ������ļ���
            FTask.Stream.Free
          else
          if (FTask.Handle > 0) then  // ������ļ����
            CloseHandle(FTask.Handle)
          else
          if (FTask.RefStr <> '') then
            FTask.RefStr := ''
          else begin
            if Assigned(FTask.Head) then
              FreeMem(FTask.Head);
            if Assigned(FTask.Tail) then
              FreeMem(FTask.Tail);
          end;
        end;
    finally
      FillChar(FTask, TASK_SPACE_SIZE, 0);  // ����
      FTask.ObjType := FOwner.ClassType;    // �ᱻ��
    end;
  except
    // ������Ӧ����
  end;
end;

function TTransmitObject.GetExists: Boolean;
begin
  // �Ƿ��з�������
  Result := (iocp_api.InterlockedCompareExchange(FExists, 0, 0) > 0);
end;

procedure TTransmitObject.SetTask(const Data: AnsiString);
begin
  // �����ַ���
  InterSetTask(Data, False);
  FExists := 1;
end;

procedure TTransmitObject.SetTask(const Data: PAnsiChar; Size: Cardinal);
begin
  // �����ڴ��
  InterSetTask(Data, Size, False);
  FExists := 1;
end;

procedure TTransmitObject.SetTask(Handle: THandle; Size: TFileSize);
begin
  // �����ļ�����������ļ���
  InterSetTask(Handle, Size, 0, 0, False);
  FExists := 1;
end;

procedure TTransmitObject.SetTask(Stream: TMemoryStream; Size: Cardinal);
begin
  // ���� C/S ������������ HTTP ʱʵ�壩
  FTask.Stream := Stream;  // ��Ӧ Stream
  FTask.Head := Stream.Memory;
  FTask.HeadLength := Size;
  FExists := 1;
end;

procedure TTransmitObject.SetTask(Stream: TStream; Size, Offset, OffsetEnd: TFileSize);
begin
  // ����һ��������Ϊ��
  //   1. C/S ģʽ�ĸ�����
  //   2. HTTP ��ʵ��������
  if (FTask.ObjType = THttpSocket) then  // THttpSocket
  begin
    FTask.Stream := Stream;
    if (Stream is TMemoryStream) then
    begin
      // �����ڴ���
      FTask.Head := TMemoryStream(Stream).Memory;
      FTask.HeadLength := Size;
    end else
    begin
      // �����ļ����ľ��
      FTask.Handle := THandleStream(Stream).Handle;
      FTask.Size := Size;
      FTask.Offset := Offset;
      FTask.OffsetEnd := OffsetEnd;
    end;
  end else
  begin
    FTask.Stream2 := Stream;  // TBaseSocket ��Ӧ Stream2
    if (Stream is TMemoryStream) then
    begin
      // ��Ϊβ
      FTask.Tail := TMemoryStream(Stream).Memory;
      FTask.TailLength := Size;
    end else
    begin
      // �����ļ����ľ��
      FTask.Handle := THandleStream(Stream).Handle;
      FTask.Size := Size;
      FTask.Offset := Offset;
      FTask.OffsetEnd := OffsetEnd;
    end;
  end;
  FExists := 1;
end;

procedure TTransmitObject.SetTaskVar(const Data: Variant);
begin
  // ���ñ䳤����
  InterSetTaskVar(Data);
  FExists := 1;
end;

procedure TTransmitObject.TransmitFile;
var
  XOffset: LARGE_INTEGER;
begin
  // �� TransmitFile ���� Task ������
  // �ύ�������ֽ����
  // 1. ʧ�ܣ��ڵ�ǰ�̴߳���
  // 2. �ύ�ɹ��������������
  //    A. ȫ��������ϣ��������̼߳�⵽��ֻһ�Σ���ִ�� TBaseSocket.FreeTransmitRes �ͷ���Դ
  //    B. ���ͳ����쳣��Ҳ�������̼߳�⵽��ִ�� TBaseSocket.TryClose ���Թر�

  // ���ص��ṹ
  FillChar(FSendBuf^.Overlapped, SizeOf(TOverlapped), 0);

  FSendBuf^.Owner := FOwner;  // ����
  FSendBuf^.IOType := ioTransmit;  // iocp_server ���ж���

  // ����λ�ƣ��� LARGE_INTEGER ȷ��λ�ƣ�
  if (FTask.Handle > 0) then
  begin
    XOffset.QuadPart := FTask.Offset;
    if (FTask.OffsetEnd > 0) then
    begin
      FSendBuf^.Overlapped.Offset := XOffset.LowPart;  // ����λ��
      FSendBuf^.Overlapped.OffsetHigh := XOffset.HighPart; // λ�Ƹ�λ
      FTask.Size := FTask.OffsetEnd - FTask.Offset + 1; // ���ͳ���
    end;
    Windows.SetFilePointer(FTask.Handle, XOffset.LowPart, @XOffset.HighPart, FILE_BEGIN);
  end;
  
  if (iocp_wsExt.gTransmitFile(
                 FSocket,            // �׽���
                 FTask.Handle,       // �ļ��������Ϊ 0
                 FTask.Size,         // ���ͳ��ȣ���Ϊ 0
                 IO_BUFFER_SIZE * 8, // ÿ�η��ͳ���
                 @FSendBuf^.Overlapped,     // �ص��ṹ
                 PTransmitBuffers(@FTask),  // ͷβ���ݿ�
                 TF_USE_KERNEL_APC   // ���ں��߳�
                 ) = False) then
  begin
    FErrorCode := WSAGetLastError;
    if (FErrorCode <> ERROR_IO_PENDING) then  // �쳣
      FOnError(Self)
    else
      FErrorCode := 0;
  end else
    FErrorCode := 0;

end;  

{$ENDIF}

{ TBaseTaskSender }

procedure TBaseTaskSender.ChunkDone;
begin
  // ���ͷֿ������־
  with FSendBuf^.Data do
  begin
    PAnsiChar(buf)^ := AnsiChar('0');  // 0
    PStrCRLF2(buf + 1)^ := STR_CRLF2;  // �س�����, ����
  end;
  DirectSend(nil, 5, 0);  // ���� 5 �ֽ�
end;

procedure TBaseTaskSender.FreeResources(FreeRes: Boolean);
begin
  // �ͷ� WSASend��Send ģʽ��������Դ
  try
    if Assigned(FTask.Stream) then
    begin
      if FTask.AutoFree then
        FTask.Stream.Free;
    end else
    if (FTask.Handle > 0) then
      CloseHandle(FTask.Handle)
    else
    if (FTask.RefStr <> '') then
    begin
      FTask.RefStr := '';
      FTask.Head := nil;
    end else
    if Assigned(FTask.Head) then  // δ�� FTask.Tail
    begin
      if FTask.AutoFree then
        FreeMem(FTask.Head);
    end;
  finally
    FillChar(FTask, TASK_SPACE_SIZE, 0);  // ����
    FTask.ObjType := FOwner.ClassType;    // �ᱻ��
  end;
end;

function TBaseTaskSender.GetData: PWsaBuf;
begin
  // ���ط��ͻ����ַ�����ⲿֱ��д���ݣ��� SendBuffers ��Ӧ
  Result := @FSendBuf^.Data;
end;

procedure TBaseTaskSender.InitHeadTail(DataLength: Cardinal; Fulled: Boolean);
begin
  // ��д�ֿ��ͷβ������������6�ֽڣ����س�����
  PChunkSize(FSendBuf^.Data.buf)^ := PChunkSize(AnsiString(IntToHex(DataLength, 4)) + STR_CRLF)^;
  PStrCRLF(FSendBuf^.Data.buf + DataLength + 6)^ := STR_CRLF;
end;

procedure TBaseTaskSender.MakeFrameInf(Payload: UInt64);
var
  i: Integer;
  iByte: Byte;
  p: PByte;
begin
  // ���� WebSocket ֡��Ϣ
  //   ���� RSV1/RSV2/RSV3

  p := PByte(FSendBuf^.Data.buf);

  p^ := Byte($80) + Byte(FOpCode);
  Inc(p);

  if FMasking then  // ������
    iByte := Byte($80)
  else
    iByte := 0;
    
  case Payload of
    0..125: begin
      if (OpCode >= ocClose) then
        p^ := iByte
      else
        p^ := iByte + Payload;
      Inc(p);
    end;
    126..$FFFF: begin
      p^ := iByte + 126;
      Inc(p);
      TByteAry(p)[0] := TByteAry(@Payload)[1];
      TByteAry(p)[1] := TByteAry(@Payload)[0];
      Inc(p, 2);
    end;
    else begin
      p^ := iByte + 127;
      Inc(p);
      for i := 0 to 7 do
        TByteAry(p)[i] := TByteAry(@Payload)[7 - i];
      Inc(p, 8);
    end;
  end;

  if FMasking then  // �ͻ��˵�����
  begin
    Cardinal(FWsMask) := GetTickCount;
    FWsMask[3] := FWsMask[1] xor $28;  // = 0 -> ����
    PCardinal(p)^ := Cardinal(FWsMask);
    Inc(p, 4);
  end;

  FSendBuf^.Data.len := PAnsiChar(p) - FSendBuf^.Data.buf;
  FWSCount := 0;
  
end;

procedure TBaseTaskSender.InternalSend;
begin
  // �������� FTask ���������ݣ��������ݲ����棩
  FErrorCode := 0;  // ���쳣
  try
    try
      if Assigned(FTask.Head) then  // 1. �����ڴ��
        InterSendBuffer(FTask.Head, FTask.HeadLength, FTask.Offset, FTask.OffsetEnd)
      else
      if (FTask.Handle > 0) then    // 2. �����ļ�
        InterSendFile
      else
      if Assigned(FTask.Tail) then  // 3. �����ڴ��
        InterSendBuffer(FTask.Tail, FTask.TailLength, FTask.Offset, FTask.OffsetEnd);
    finally
      FreeResources;  // 4. �ͷ���Դ
      if FChunked then
        FChunked := False;
    end;
  except
    FErrorCode := GetLastError;
  end;
end;

procedure TBaseTaskSender.InterSendBuffer(Data: PAnsiChar;
                          ByteCount, Offset, OffsetEnd: Cardinal);
var
  FrameSize: Cardinal;   // ������������
  BufLength: Cardinal;   // �ֿ�ģʽ�Ļ��泤��
  BytesToRead: Cardinal; // �������볤��
begin
  // ����һ���ڴ棨��Ӧ�ܳ���
  // ��Χ��Offset - OffsetEnd

  // Chunk ���͵ĸ�ʽ��
  // ����������6�ֽڣ� + �س����� + ���� + �س����У�2�ֽڣ�
  // ���ݴ��� IO_BUFFER_SIZE ʱ����Ԥ�� ����������ĩβ�Ļس�����
  
  if (OffsetEnd > Offset) then  // ���Ͳ������ݣ���λ
  begin
    Inc(Data, Offset);
    ByteCount := OffsetEnd - Offset + 1;
  end;

  if FWebSocket then  // ���� webSocket ����
  begin
    MakeFrameInf(ByteCount);
    FrameSize := FSendBuf^.Data.len; // ��������
    BufLength := FBufferSize - FrameSize;  // �����볤��
  end else
    if FChunked then  // Chunk ����
    begin
      FrameSize := 6; // ��������
      BufLength := FBufferSize - 8; // ��ͷβ���ȣ�6+2
      if (ByteCount >= BufLength) then  // Ԥ��ͷβ
        InitHeadTail(BufLength, True);
    end else
    begin
      FrameSize := 0;
      BufLength := FBufferSize;
    end;

  while (ByteCount > 0) do
  begin
    if (ByteCount >= BufLength) then  // ����
      BytesToRead := BufLength
    else begin
      BytesToRead := ByteCount;
      if FChunked then  // ����δ��
        InitHeadTail(BytesToRead, False); // ����ͷβ
    end;

    // �������ݣ�����
    ReadSendBuffers(Data, BytesToRead, FrameSize);

    if (FErrorCode <> 0) then  // �˳�
      Break;

    Inc(Data, BytesToRead);  // ��ַ��ǰ
    Dec(ByteCount, BytesToRead);  // ʣ���� -

    if FWebSocket and (FrameSize > 0) then  // �´β�������
    begin
      FrameSize := 0;
      BufLength := FBufferSize;  // �ָ���󳤶�
    end;
  end;

  if FChunked then  // ���ͷֿ������־
    ChunkDone;

end;

procedure TBaseTaskSender.InterSendFile;
var
  FrameSize: Cardinal;   // WebSocket֡�ṹ����
  BufLength: Cardinal;   // �ֿ�ģʽ�Ļ��泤��
  ByteCount: TFileSize;  // �ܳ���
  BytesToRead, BytesReaded: Cardinal;
  Offset: LARGE_INTEGER;
begin
  // ����һ���ļ�
  // ��Χ��Task^.Offset ... Task^.OffsetEnd
  try
    if (FTask.Offset = 0) and (FTask.OffsetEnd = 0) then
      ByteCount := FTask.Size
    else
      ByteCount := FTask.OffsetEnd - FTask.Offset + 1;

    // ��λ�����ܴ��� 2G���� LARGE_INTEGER ȷ��λ�ƣ�
    Offset.QuadPart := FTask.Offset;
    Windows.SetFilePointer(FTask.Handle, Offset.LowPart, @Offset.HighPart, FILE_BEGIN);

    if FWebSocket then  // ���� webSocket ����
    begin
      MakeFrameInf(ByteCount);
      FrameSize := FSendBuf^.Data.len;
      BufLength := FBufferSize - FrameSize;  // �����볤��
    end else
      if FChunked then  // Chunk ����
      begin
        FrameSize := 6; // ������
        BufLength := FBufferSize - 8; // ��ͷβ���ȣ�6+2
        if (ByteCount >= BufLength) then  // Ԥ��ͷβ
          InitHeadTail(BufLength, True);
      end else
      begin
        FrameSize := 0;
        BufLength := FBufferSize;
      end;

    while (ByteCount > 0) do
    begin
      if (ByteCount >= BufLength) then  // ����
        BytesToRead := BufLength
      else begin
        BytesToRead := ByteCount;
        if FChunked then  // ����δ��
          InitHeadTail(BytesToRead, False); // ����ͷβ
      end;

      // �ȶ���һ������
      if (FrameSize > 0) then  // ���뵽����������λ��
        Windows.ReadFile(FTask.Handle, (FSendBuf^.Data.buf + FrameSize)^,
                         BytesToRead, BytesReaded, nil)
      else
        Windows.ReadFile(FTask.Handle, FSendBuf^.Data.buf^,
                         BytesToRead, BytesReaded, nil);

      if (BytesToRead = BytesReaded) then  // ����ɹ�
      begin
        if FWebSocket then
          DirectSend(FSendBuf^.Data.buf, BytesToRead + FrameSize, FrameSize) // ���ͣ�����+FrameSize
        else
        if FChunked then
          DirectSend(FSendBuf^.Data.buf, BytesToRead + 8, 0)  // ���ͣ�����+6+2
        else
          DirectSend(FSendBuf^.Data.buf, BytesToRead, 0); // ���ͣ����Ȳ���

        if (FErrorCode <> 0) then  // �˳�
          Break;

        Dec(ByteCount, BytesToRead);  // ʣ���� -
        if FWebSocket and (FrameSize > 0) then  // �´β�������
        begin
          FrameSize := 0;
          BufLength := FBufferSize;
        end;
      end else
      begin
        FErrorCode := GetLastError;
        Break;
      end;
    end;

    if FChunked then  // ���ͷֿ������־
      ChunkDone;

  except
    FErrorCode := GetLastError;
  end;
end;

procedure TBaseTaskSender.Send(const Data: PAnsiChar; Size: Cardinal; AutoFree: Boolean);
begin
  // ���� Buffer
  InterSetTask(Data, Size, AutoFree);
  InternalSend;
end;

procedure TBaseTaskSender.Send(Handle: THandle; Size, Offset,
                               OffsetEnd: TFileSize; AutoFree: Boolean);
begin
  // �����ļ� Handle
  //  Handle > 0 Ϊ��Ч������� iocp_utils.InternalOpenFile
  InterSetTask(Handle, Size, Offset, OffsetEnd, AutoFree);
  InternalSend;
end;

procedure TBaseTaskSender.Send(const Data: AnsiString);
begin
  // ���� AnsiString������˫�ֽڵ� String��
  InterSetTask(Data, True);
  InternalSend;
end;

procedure TBaseTaskSender.Send(Stream: TStream; Size, Offset,
                          OffsetEnd: TFileSize; AutoFree: Boolean);
begin
  // ���� C/S ģʽ�ĸ�����, ���� AutoFree �ͷ�
  FTask.Stream := Stream; 
  FTask.AutoFree := AutoFree;
  if (Stream is TMemoryStream) then
  begin
    // �����ڴ���
    FTask.Head := TMemoryStream(Stream).Memory;
    FTask.HeadLength := Size;
  end else
  begin
    // �����ļ����ľ��
    FTask.Handle := THandleStream(Stream).Handle;
    FTask.Size := Size;
    FTask.Offset := Offset;
    FTask.OffsetEnd := OffsetEnd;
  end;
  InternalSend;
end;

procedure TBaseTaskSender.Send(Stream: TStream; Size: TFileSize; AutoFree: Boolean);
begin
  // �������������������� AutoFree �����Ƿ��ͷ�
  Send(Stream, Size, 0, 0, AutoFree);
end;

procedure TBaseTaskSender.SendBuffers;
begin
  // �����Ѿ���д�� Buf��ֱ�ӷ���
  //��FramSize = 0��WebSocket�ͻ��˲���ʹ�ã� 
  DirectSend(FSendBuf^.Data.Buf, FSendBuf^.Data.len, 0);
end;

procedure TBaseTaskSender.SendVar(const Data: Variant);
begin
  InterSetTaskVar(Data);
  InternalSend;
end;

procedure TBaseTaskSender.SetChunked(const Value: Boolean);
begin
  FChunked := Value;
  FOpCode := ocContinuation;
  FWebSocket := False;  // ���� WebSocket ����
end;

procedure TBaseTaskSender.SetOpCode(Value: TWSOpCode);
begin
  FOpCode := Value;
  FWebSocket := True;
  FChunked := False;  // ���Ƿֿ鷢����
end;

{ TServerTaskSender }

procedure TServerTaskSender.CopySend(ARecvBuf: PPerIOData);
begin
  // ���Ʒ��� TPerIOData������ʹ�÷����ڴ�飬�Է�����ռ�ó�ͻ��
  try
    FTempBuf := FDualBuf;
    FSendBuf^.Data.len := ARecvBuf^.Overlapped.InternalHigh;
    System.Move(ARecvBuf^.Data.buf^, FSendBuf^.Data.buf^, FSendBuf^.Data.len);
    DirectSend(nil, FSendBuf^.Data.len, 0);  // ֱ�ӷ���
  finally
    FDualBuf := FSendBuf;  // ��������
    FSendBuf := FTempBuf;
  end;
end;

constructor TServerTaskSender.Create(BufferPool: TIODataPool; DoubleBuf: Boolean);
begin
  inherited Create;
  FSendBuf := BufferPool.Pop^.Data;
  FSendBuf^.Data.len := IO_BUFFER_SIZE;
  if DoubleBuf then  // ����ģʽ��˫�����ڴ��
  begin
    FDualBuf := BufferPool.Pop^.Data;
    FDualBuf^.Data.len := IO_BUFFER_SIZE;
  end;
  FBufferSize := IO_BUFFER_SIZE;
  FWebSocket := False;
end;

procedure TServerTaskSender.DirectSend(OutBuf: PAnsiChar; OutSize, FrameSize: Integer);
var
  ByteCount, Flags: Cardinal;
begin
  // ֱ�ӷ��� FSendBuf �����ݣ����Բ��� OutBuf��FrameSize��

  // ���ص��ṹ
  FillChar(FSendBuf^.Overlapped, SizeOf(TOverlapped), 0);

  FSendBuf^.Owner := FOwner;  // ����
  FSendBuf^.IOType := ioSend;  // iocp_server ���ж���
  FSendBuf^.Data.len := OutSize;  // ����

  ByteCount := 0;
  Flags := 0;        

  // FSendBuf^.Overlapped �� TPerIOData ͬ��ַ
  if (iocp_Winsock2.WSASend(FSocket, @(FSendBuf^.Data), 1, ByteCount,
      Flags, LPWSAOVERLAPPED(@FSendBuf^.Overlapped), nil) = SOCKET_ERROR) then
  begin
    FErrorCode := WSAGetLastError;
    if (FErrorCode <> ERROR_IO_PENDING) then  // �쳣
      FOnError(Self)  // ִ�� TBaseSocket ����
    else begin
      // ����ʱ���յ���Ϣ��
      // �ϸ���˵Ҫ�ڹ����̴߳�����Ҫ����������
      WaitForSingleObject(FSocket, INFINITE);
      FErrorCode := 0;
    end;
  end else
    FErrorCode := 0;

end;

procedure TServerTaskSender.FreeBuffers(BufferPool: TIODataPool);
begin
  BufferPool.Push(FSendBuf^.Node);
  FSendBuf := nil;
  if Assigned(FDualBuf) then
  begin
    BufferPool.Push(FDualBuf^.Node);
    FDualBuf := nil;
  end;
end;

procedure TServerTaskSender.ReadSendBuffers(InBuf: PAnsiChar; ReadCount, FrameSize: Integer);
begin
  // �����ݵ����ͻ��棬����
  if FChunked or (FrameSize > 0) then
  begin
    // 1. ���� Chunk, WebSocket �״�����
    System.Move(InBuf^, (FSendBuf^.Data.buf + FrameSize)^, ReadCount);  // ����
    if FChunked then
      DirectSend(nil, ReadCount + 8, 0)  // ReadCount + �������� + ĩβ�Ļس�����
    else  // WebSocket ����
      DirectSend(nil, ReadCount + FrameSize, FrameSize);
  end else
  begin
    // 2. �����������ݣ�ֱ�Ӷ���
    System.Move(InBuf^, FSendBuf^.Data.buf^, ReadCount);
    DirectSend(nil, ReadCount, 0);
  end;
end;

{ TClientTaskSender }

constructor TClientTaskSender.Create;
begin
  inherited;
  // ֱ�ӷ��䷢���ڴ��  
  FSendBuf := New(PPerIOData);
  GetMem(FSendBuf^.Data.Buf, IO_BUFFER_SIZE_2);
  FSendBuf^.Data.len := IO_BUFFER_SIZE_2;
  FBufferSize := IO_BUFFER_SIZE_2;
  FWebSocket := False;
end;

destructor TClientTaskSender.Destroy;
begin
  // �ͷŷ����ڴ��
  FreeMem(FSendBuf^.Data.Buf);
  Dispose(FSendBuf);
  inherited;
end;

procedure TClientTaskSender.DirectSend(OutBuf: PAnsiChar; OutSize, FrameSize: Integer);
var
  i: Integer;
  TotalCount: UInt64; // �ܷ���
  p: PByte;
begin
  // �������ݿ�

  if FWebSocket and FMasking then  // �����������봦��
  begin
    p := PByte(FSendBuf^.Data.buf + FrameSize);
    TotalCount := FWSCount + OutSize - FrameSize;
    for i := FWSCount to TotalCount - 1 do
    begin
      p^ := p^ xor FWSMask[i mod 4];
      Inc(p);
    end;
    FWSCount := TotalCount;
  end;

  if (Stoped = False) then
    FErrorCode := iocp_Winsock2.Send(FSocket, OutBuf^, OutSize, 0)
  else begin
    if not FFirst then  // ����ȡ����־
      iocp_Winsock2.Send(FSocket, IOCP_SOCKET_CANCEL[1], IOCP_CANCEL_LENGTH, 0);
    FErrorCode := -2;   // ֹͣ���������
  end;

  if Stoped or (FErrorCode <= 0) then
  begin
    if Assigned(FOnError) then
      FOnError(FOwner);
  end else
  begin
    FErrorCode := 0;  // ���쳣
    try
      if Assigned(FAfterSend) then
        FAfterSend(FFirst, OutSize);
    finally
      FFirst := False;
    end;
  end;

end;

function TClientTaskSender.GetStoped: Boolean;
begin
  // FState=1��ֹͣ��
  Result := iocp_api.InterlockedCompareExchange(FStoped, 1, 1) = 1;
end;

procedure TClientTaskSender.ReadSendBuffers(InBuf: PAnsiChar; ReadCount, FrameSize: Integer);
begin
  // ���ͻ���
  if FWebSocket then  // �����ݵ�����
  begin
    System.Move(InBuf^, (FSendBuf^.Data.buf + FrameSize)^, ReadCount);
    DirectSend(FSendBuf^.Data.buf, ReadCount + FrameSize, FrameSize);
  end else
    DirectSend(InBuf, ReadCount, FrameSize);
end;

procedure TClientTaskSender.SetStoped(const Value: Boolean);
begin
  // ����״̬
  //   ������Value=False��FStoped=0
  //   ֹͣ��Value=True��FStoped=1
  windows.InterlockedExchange(FStoped, Ord(Value));
  if (Value = False) then  // ��ֹͣ
    FFirst := True;
end;
  
end.
