(*
 * ��־�̵߳�Ԫ���ص㣺
 *   1�����١��ȶ�
 *   2�����ء�д���ڴ������
 *   3��������
 *
 * ʹ�÷�����
 *   1��������־�̣߳�TLogThread.InitLog(��־���·��);
 *   2��д����־��iocp_log.WriteLog('��־����')��
 *   3��ֹͣ��־�̣߳�TLogThread.StopLog;
 *
 * ʹ�þ��飺
 *    1. �� 2 �򲢷����Ա�������ʵ��Ӧ�û����£��������־���治�� 2 �飬
 * ˵��Ԥ�� 1-2M ����־�����ʺϾ��������СӦ�á�
 *    2. ��ѭ���ķ���дǧ��Σ��������־����Ｘʮ�ף���ʵ��Ӧ�ò���
 * ������������
 *
 *)
unit iocp_log;

interface

uses
  Windows, Classes, SyncObjs, SysUtils;

type

  // ����ṹ

  PBufferNode = ^TBufferNode;
  TBufferNode = record
    buf: PAnsiChar;         // ����
    len: Integer;           // ʣ��ռ䳤��
    next: PBufferNode;      // �����ڵ�
  end;

  // ��־�������

  TLogBuffers = class(TObject)
  private
    FHead: PBufferNode;     // ͷ�ڵ�
    FTail: PBufferNode;     // β�ڵ�
    FCurrent: PBufferNode;  // ��ǰ�ڵ�
    FBuffers: PAnsiChar;    // д���ַ
    FBufferSize: Integer;   // ���泤��
    FSize: Integer;         // д����ܳ���
    procedure InterAdd;
  public
    constructor Create(ABufferSize: Integer);
    destructor Destroy; override;
  public
    procedure Clear;
    procedure Reset;
    procedure Write(const Msg: PAnsiChar; MsgSize: Integer); overload;
    procedure Write(Handle: THandle); overload;
  end;

  // ��־�߳�

  TLogThread = class(TThread)
  private
    FSection: TRTLCriticalSection;  // �ٽ���
    FLogPath: String;        // ��־���·��
    FMaster: TLogBuffers;    // ���б�
    FSlave: TLogBuffers;     // ���б�
    FCurrent: TLogBuffers;   // ��ǰ�б����ã�
    FWorking: Boolean;       // ����״̬
    procedure InterClear;
  protected
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    procedure Write(const Msg: AnsiString);
    procedure Stop;
  public
    class procedure Clear;
    class procedure InitLog(const LogPath: String = 'log');
    class procedure StopLog;
  end;

// д��־���� 
procedure WriteLog(const Msg: AnsiString);

implementation

var
  LogThread: TLogThread = nil;

type
  // ˫�ֽ�����

  PDblChars = ^TDblChars;
  TDblChars = array[0..1] of AnsiChar;

  // ����ʱ���Ӧ�Ľṹ��

  PDateTimeFormat = ^TDateTimeFormat;
  TDateTimeFormat = packed record
      Year: TDblChars; Year2: TDblChars; S: AnsiChar;
     Month: TDblChars;    S2: AnsiChar;
       Day: TDblChars;    S3: AnsiChar;
      Hour: TDblChars;    S4: AnsiChar;
    Minute: TDblChars;    S5: AnsiChar;
    Second: TDblChars;    S6: AnsiChar;
      MSec: TDblChars; MSec2: AnsiChar
  end;

procedure FormatNowToBuf(const dTime: PDateTimeFormat);
const
  DBL_NUMBERS: array[0..99] of TDblChars = (
     '00', '01', '02', '03', '04', '05', '06', '07', '08', '09',
     '10', '11', '12', '13', '14', '15', '16', '17', '18', '19',
     '20', '21', '22', '23', '24', '25', '26', '27', '28', '29',
     '30', '31', '32', '33', '34', '35', '36', '37', '38', '39',
     '40', '41', '42', '43', '44', '45', '46', '47', '48', '49',
     '50', '51', '52', '53', '54', '55', '56', '57', '58', '59',
     '60', '61', '62', '63', '64', '65', '66', '67', '68', '69',
     '70', '71', '72', '73', '74', '75', '76', '77', '78', '79',
     '80', '81', '82', '83', '84', '85', '86', '87', '88', '89',
     '90', '91', '92', '93', '94', '95', '96', '97', '98', '99');
var
  SysTime: TSystemTime;
  i: Integer;
begin
  // ת��ʱ���ʽΪ�ַ������õ��ֽ�
  // ��ʽ��2018-06-09 10:30:28 678������ = 23

  Windows.GetLocalTime(SysTime);

  // ��
  i := SysTime.wYear div 100;
  dTime^.Year := DBL_NUMBERS[i];
  dTime^.Year2 := DBL_NUMBERS[SysTime.wYear - i * 100];

  // �¡���
  dTime^.Month := DBL_NUMBERS[SysTime.wMonth];
  dTime^.Day := DBL_NUMBERS[SysTime.wDay];

  // ʱ���֡���
  dTime^.Hour := DBL_NUMBERS[SysTime.wHour];
  dTime^.Minute := DBL_NUMBERS[SysTime.wMinute];
  dTime^.Second := DBL_NUMBERS[SysTime.wSecond];

  // ����
  i := SysTime.wMilliseconds div 10;
  dTime^.MSec := DBL_NUMBERS[i];
  dTime^.MSec2 := DBL_NUMBERS[SysTime.wMilliseconds - i * 10][1];

  // �����
  dTime^.S  := AnsiChar('-');
  dTime^.S2 := AnsiChar('-');
  dTime^.S3 := AnsiChar(#32);
  dTime^.S4 := AnsiChar(':');
  dTime^.S5 := AnsiChar(':');
  dTime^.S6 := AnsiChar(#32);

end;

procedure WriteLog(const Msg: AnsiString);
begin
  // д��־
  if Assigned(LogThread) and (LogThread.Terminated = False) then
    LogThread.Write(Msg);
end;

{ TLogBuffers }

procedure TLogBuffers.Clear;
var
  Node: PBufferNode;
begin
  // �ͷ�ȫ���ڵ㡢����
  while Assigned(FHead) do
  begin
    FreeMem(FHead^.buf);
    Node := FHead^.next;
    FreeMem(FHead);
    FHead := Node;
  end;
  FTail := nil;
end;

constructor TLogBuffers.Create(ABufferSize: Integer);
begin
  inherited Create;
  FBufferSize := ABufferSize;  // ÿ�鳤��
  InterAdd;  // Ԥ��һ�黺��
end;

destructor TLogBuffers.Destroy;
begin
  Clear;
  inherited;
end;

procedure TLogBuffers.InterAdd;
begin
  // ����һ�黺��
  GetMem(FCurrent, SizeOf(TBufferNode));  // ����ڵ�
  GetMem(FBuffers, FBufferSize);  // ����д�뻺��

  FCurrent^.buf := FBuffers;
  FCurrent^.len := FBufferSize;   // ���ÿռ䳤��
  FCurrent^.next := nil;  // �޺�̽ڵ�

  if (FHead = nil) then
    FHead := FCurrent
  else
    FTail^.next := FCurrent;  // �ӵ�ĩβ

  FTail := FCurrent;  // �ú�
end;

procedure TLogBuffers.Reset;
begin
  // ���ã�ʹ���׻����
  FCurrent := FHead;
  FCurrent^.len := FBufferSize;
  FBuffers := FCurrent^.buf;
  FSize := 0;
end;

procedure TLogBuffers.Write(Handle: THandle);
var
  Node: PBufferNode;
  NoUsed: Cardinal;
begin
  // �������������д����־�ļ�
  Node := FHead;
  while Assigned(Node) do
  begin
    Windows.WriteFile(Handle, Node^.buf^, FBufferSize - Node^.len, NoUsed, nil);
    Node := Node^.next;
  end;
end;

procedure TLogBuffers.Write(const Msg: PAnsiChar; MsgSize: Integer);
begin
  // д��־������ռ�
  // ���˿��ܷ����µĻ���飬û�з��������ڴ�
  
  if (FCurrent^.len < MsgSize) then  // ������ʱ�䡢�س����еĳ���
    if Assigned(FCurrent^.next) then // �ú��������
    begin
      FCurrent := FCurrent^.next;
      FCurrent^.len := FBufferSize;
      FBuffers := FCurrent^.buf;
    end else
      InterAdd;  // �����µĻ����

  // ��־ʱ��
  FormatNowToBuf(PDateTimeFormat(FBuffers));
  Inc(FBuffers, 23);

  // ʱ���ļ���������ֽڣ�
  PDblChars(FBuffers)^ := AnsiString(':'#32);
  Inc(FBuffers, 2);

  // ��־����
  System.Move(Msg^, FBuffers^, MsgSize - 27);
  Inc(FBuffers, MsgSize - 27);

  // �س�����
  PDblChars(FBuffers)^ := AnsiString(#13#10);
  Inc(FBuffers, 2);

  // ���ÿռ�-���ܴ�С+
  Dec(FCurrent^.len, MsgSize);
  Inc(FSize, MsgSize);
end;

{ TLogThread }

constructor TLogThread.Create;
begin
  inherited Create(True);
  FreeOnTerminate := True;
  InitializeCriticalSection(FSection); // �ٽ���
  FMaster := TLogBuffers.Create(1024 * 1024);  // ������
  FSlave := TLogBuffers.Create(1024 * 1024);   // �ӻ���
  FCurrent := FMaster;  // ���û���
end;

destructor TLogThread.Destroy;
begin
  FMaster.Free;
  FSlave.Free;
  DeleteCriticalSection(FSection);
  inherited;
end;

procedure TLogThread.Execute;
  function CreateLogFile(var FileIndex: Integer): THandle;
  begin
    // �����Ϊ FileIndex ����־�ļ�
    Result := windows.CreateFile(PChar(FLogPath + IntToStr(FileIndex) + '.log'),
                      GENERIC_READ or GENERIC_WRITE, 0, nil, CREATE_ALWAYS,
                      FILE_ATTRIBUTE_NORMAL, 0);
    Inc(FileIndex);
  end;
var
  FileIndex: Integer;
  FileHandle: THandle;
  TotalSize: Integer;
  SaveBuffers: TLogBuffers;
begin
  inherited;

  // ��ʼ����
  FWorking := True;

  // ����־�ļ�
  FileIndex := 0;   // �ļ����
  FileHandle := CreateLogFile(FileIndex);

  TotalSize := 0;   // ��־�ļ���С

  while (Terminated = False) do
  begin
    Sleep(28);  // ԽС����־�ļ�Խ�࣬���ڴ��ʹ�ø���
    
    EnterCriticalSection(FSection);
    try
      SaveBuffers := FCurrent;
      if (FCurrent = FMaster) then
        FCurrent := FSlave   // ���б� -> ��ǰ�б�
      else
        FCurrent := FMaster; // ���б� -> ��ǰ�б�
    finally
      LeaveCriticalSection(FSection);
    end;

    if (SaveBuffers.FSize > 0) then
    begin
      Inc(TotalSize, SaveBuffers.FSize);  // �ۼ�д���ֽ�������ţ�
      SaveBuffers.Write(FileHandle);  // д�ļ�
      SaveBuffers.Reset;   // ����

      // ���� 5M�����µ���־�ļ�
      if (TotalSize >= 5242880) then
      begin
        Windows.CloseHandle(FileHandle);  // �ر��ļ�
        FileHandle := CreateLogFile(FileIndex); // �����ļ�
        TotalSize := 0; // ����
      end;
    end;
  end;

  // ������дʣ������
  if (FCurrent.FSize > 0) then
    FCurrent.Write(FileHandle);
  Windows.CloseHandle(FileHandle);

  // ֹͣ����
  FWorking := False;
  
end;

procedure TLogThread.InterClear;
begin
  // �ͷ���־����
  EnterCriticalSection(FSection);
  try
    FMaster.Clear;
    FSlave.Clear;
    FMaster.InterAdd;  // ��һ�黺��
    FSlave.InterAdd;
  finally
    LeaveCriticalSection(FSection);
  end;
end;

procedure TLogThread.Stop;
begin
  Terminate;  // ֹͣ
  while FWorking do
    Sleep(10);
end;

procedure TLogThread.Write(const Msg: AnsiString);
begin
  // д��־����ǰ�б�Msg <> ''��
  EnterCriticalSection(FSection);
  try
    // ��ʽ��ʱ�� + ����� + Msg + �س����У������ 27 �ֽ�
    FCurrent.Write(PAnsiChar(Msg), Length(Msg) + 27);
  finally
    LeaveCriticalSection(FSection);
  end;
end;

class procedure TLogThread.Clear;
begin
  // �����־����
  if Assigned(LogThread) and (LogThread.Terminated = False) then
    LogThread.InterClear;
end;

class procedure TLogThread.InitLog(const LogPath: String);
begin
  // ������־
  if (LogPath = '') then
    raise Exception.Create('��־·������Ϊ��.');
  if not DirectoryExists(LogPath) then
    raise Exception.Create('��־·��������: ' + LogPath);
  if not Assigned(LogThread) then
  begin
    LogThread := TLogThread.Create;
    if (LogPath[Length(LogPath)] <> '\') then
      LogThread.FLogPath := LogPath + '\'
    else
      LogThread.FLogPath := LogPath;
    LogThread.FLogPath := LogThread.FLogPath +
                          FormatDateTime('yyyy-mm-dd-hh-mm-ss-', now);
    LogThread.Resume;
  end;
end;

class procedure TLogThread.StopLog;
begin
  // ֹͣ��־
  if Assigned(LogThread) then
  begin
    LogThread.Stop;
    LogThread := nil;
  end;
end;

end.
