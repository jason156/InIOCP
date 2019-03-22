(*
 * icop ���ֺ��������̵�Ԫ
 *)
unit iocp_utils;

interface

{$I in_iocp.inc}

uses
  Windows, Classes, SysUtils, Registry, ActiveX, PsAPI, Variants, DB,
  // ADODB �ĸ߰汾�� Data.Win.ADODB
  {$IF CompilerVersion >= 32} Data.Win.ADODB, {$ELSE} ADODB, {$IFEND}
  iocp_Winsock2, iocp_zlib, iocp_base,
  iocp_lists, http_base, http_utils;

function CreateSocket: TSocket;
function ConnectSocket(Socket: TSocket; const Server: string; Port: Word): Boolean;
function GetCPUCount: Integer;

function GetSysErrorMessage(ErrorCode: DWORD = 0): String;
function GetWSAErrorMessage(ErrorCode: DWORD = 0): String;

function AddBackslash(const Path: String): String;
function DropBackSlash(const Path: String): String;
function MyCreateDir(const Path: string): Boolean;

function FileTimeToDateTime(AFileTime: TFileTime): TDateTime;
function CreateNewFileName(const FileName: String): String;
function GetCompressionLevel(const FileName: String): TZipLevel;

function InternalOpenFile(const FileName: String; ReadOnly: Boolean = True): THandle; overload;
function InternalOpenMsgFile(const FileName: String; AutoCreate: Boolean = False): THandle;

// ����ת�ڴ���
function VariantToStream(Data: Variant; ZipCompress: Boolean = False; const FileName: String = ''): TStream;

// ��ת����
function StreamToVariant(Stream: TStream; ZipDecompress: Boolean = False): Variant;

// ȡ�ļ���С
function GetFileSize64(Handle: THandle): Int64;

// �򵥵ļ��ܡ�����
function EncryptString(const S: AnsiString): AnsiString;
function DecryptString(const S: AnsiString): AnsiString;

// ����׽��ֵ���������
function MatchSocketType(InBuf: PAnsiChar; const SocketFlag: AnsiString): Boolean;

// ���ݼ�תΪ json
function DataSetToJSON(DataSet: TDataSet; CharSet: THttpCharSet = hcsDefault): AnsiString;
procedure LargeDataSetToJSON(DataSet: TDataSet; Headers: TObject; CharSet: THttpCharSet);

// ȡ UTC/TFileTime ʱ��
function GetUTCTickCount: Int64; 
function GetUTCTickCountEh(Seed: Pointer = nil): UInt64;

// ȡ������Զ������ IP
function GetLocalIp(): AnsiString;
function ResolveHostIP(const Host: AnsiString): AnsiString;

// ת��ʱ��
function GetTimeLength(TimeLength: Cardinal): String;
function GetTimeLengthEx(TimeLength: Cardinal): String;

// ת�����������ı�
function GetTransmitSpeed(const Value: LongInt; MaxValue: LongInt = 0): String;

// ȡ�ڴ�ʹ�����
function GetProcMemoryUsed: Cardinal;

// ȡϵͳ����·��
function GetWindowsDir: String;
function GetSystemDir: String;
function GetProgramFileDir: String;
function GetProgramDataDir: String;
function GetSystemTempDir: String;

// ��ʽ������
// procedure FormatNowToBuf(const Buf: PAnsiChar);
function FormatDataTimeNow: AnsiString;  // δ��

// ����ʱ�� ��ʽ
procedure IniDateTimeFormat;

// ע�ᡢ���� Access ODBC DataSource���������Ӳ��ԣ�
procedure RegMSAccessDSN(const DataSourceName, AccessFileName: String; const Description: String = '');
procedure SetMSAccessDSN(ADO: TADOConnection; DataSourceOrFileName: String; DSNFile: String = '');

// ȡ�ļ���Ϣ
procedure GetLocalFileInf(const FileName: string; var FileSize: TFileSize;
                          var CreationTime, AccessTime, LastWriteTime: TFileTime);

// �����ڴ�
procedure ClearSysMemory;

implementation

uses
  iocp_log, iocp_msgPacks, http_objects, iocp_senders;

var
  WSAResult: Integer = 9;
  WSACount:  Integer = 0;

function CreateSocket: TSocket;
begin
  // �½�һ�� Socket(δ���ֹ� INVALID_SOCKET��
  Result := iocp_Winsock2.WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP,
                                    nil, 0, WSA_FLAG_OVERLAPPED);
end;

function ConnectSocket(Socket: TSocket; const Server: string; Port: Word): Boolean;
var
  Addr: TSockAddrIn;
begin
  // Socket ���ӵ�������
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(Port);
  Addr.sin_addr.s_addr := inet_addr(PAnsiChar(ResolveHostIP(Server)));

  Result := iocp_Winsock2.WSAConnect(Socket, TSockAddr(Addr), SizeOf(TSockAddr),
                                     nil, nil, nil, nil) = 0;
end;

function GetCPUCount: Integer;
var
  SysInfo: TSystemInfo;
begin
  // ȡ CPU ��
  FillChar(SysInfo, SizeOf(SysInfo), 0);
  GetSystemInfo(SysInfo);
  Result := SysInfo.dwNumberOfProcessors;
end;

function GetErrMessage(ErrorCode: DWORD): String;
var
  Buffer: array[0..255] of Char;
var
  Len: Integer;
begin
  Len := FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS or
                       FORMAT_MESSAGE_ARGUMENT_ARRAY, nil, ErrorCode, 0, Buffer,
                       SizeOf(Buffer), nil);
  while (Len > 0) and {$IFDEF USE_UNICODE}
    CharInSet(Buffer[Len - 1], [#0..#32, '.']) {$ELSE}
   (Buffer[Len - 1] in [#0..#32, '.']) {$ENDIF} do
    Dec(Len);

  SetString(Result, Buffer, Len);
end;

function GetSysErrorMessage(ErrorCode: DWORD): String;
begin
  if ErrorCode = 0 then
    Result := GetErrMessage(GetLastError)
  else
    Result := GetErrMessage(ErrorCode);
end;

function GetWSAErrorMessage(ErrorCode: DWORD): String;
begin
  if ErrorCode = 0 then
    Result := GetErrMessage(WSAGetLastError)
  else
    Result := GetErrMessage(ErrorCode);
end;

function AddBackslash(const Path: String): String;
begin
  if (Path <> '') and (Path[Length(Path)] <> '\') then
    Result := Path + '\'
  else
    Result := Path;
end;

function DropBackslash(const Path: String): String;
begin
  if (Path <> '') and (Path[Length(Path)] = '\') then
    Result := Copy(Path, 1, Length(Path) - 1)
  else
    Result := Path;
end;

function GetTimeLength(TimeLength: Cardinal): String;
var
  DivVal: Cardinal;
begin
  // ����ʱ��
  if TimeLength >= 31536000 then       // ��
  begin
    DivVal := TimeLength div 31536000;
    if DivVal > 0 then
    begin
      TimeLength := TimeLength - DivVal * 31536000;
      Result := IntToStr(DivVal) + '��';
    end;
  end;

  if TimeLength >= 86400 then         // ��
  begin
    DivVal := TimeLength div 86400;
    if DivVal > 0 then
    begin
      TimeLength := TimeLength - DivVal * 86400;
      Result := Result + IntToStr(DivVal) + '��';
    end;
  end;

  if TimeLength >= 3600 then          // ʱ
  begin
    DivVal := TimeLength div 3600;
    if DivVal > 0 then
    begin
      TimeLength := TimeLength - DivVal * 3600;
      Result := Result + IntToStr(DivVal) + 'ʱ';
    end;
  end;

  if TimeLength >= 60 then            // ��
  begin
    DivVal := TimeLength div 60;
    if DivVal > 0 then
    begin
      TimeLength := TimeLength - DivVal * 60;
      Result := Result + IntToStr(DivVal) + '��';
    end;
  end;

  if TimeLength >= 1 then            // ��
    Result := Result + IntToStr(TimeLength) + '��';

end;

function GetTimeLengthEx(TimeLength: Cardinal): String;
type
  TTimeRang = record
    Index: Cardinal;
    Name: string[2];
  end;
const
  TIME_RANGES: array[0..4] of TTimeRang = (
    (Index: 31536000; Name: '��'),
    (Index: 86400; Name: '��'), (Index: 3600; Name: 'ʱ'),
    (Index: 60; Name: '��'), (Index: 1; Name: '��')
  );
var
  i: Integer;
  DivVal: Cardinal;
begin
  // ����ʱ����2��
  Result := '';
  for i := 0 to 4 do
    if TimeLength >= TIME_RANGES[i].Index then
      if i <= 3 then
      begin
        DivVal := TimeLength div TIME_RANGES[i].Index;
        if DivVal > 0 then
        begin
          TimeLength := TimeLength - DivVal * TIME_RANGES[i].Index;
          Result := Result + IntToStr(DivVal) + TIME_RANGES[i].Name;
        end;
      end else          // ��
        Result := Result + IntToStr(TimeLength) + TIME_RANGES[i].Name;
end;

function GetTransmitSpeed(const Value: LongInt; MaxValue: LongInt): String;
var
  gCount: Double;
  function CalculateValue(const InValue: LongInt): String;
  begin
    // ���㴫����
    case InValue of
      0:
        Result := '0';
      1..1023:
        Result := IntToStr(InValue);
      1024..1024575:         // 1024*1024=1024576
        Result := FloatToStrF(InValue / 1024, ffFixed, 15, 2);
      1024576..1073741823:   // 1024*1024*1024=1073741824
        Result := FloatToStrF(InValue / 1024576, ffFixed, 15, 2);
      else begin
        gCount := InValue / 1073741824;
        if gCount < 1024 then
          Result := FloatToStrF(gCount, ffFixed, 15, 2)
        else
          Result := FloatToStrF(gCount / 1024, ffFixed, 15, 2);
      end;
    end;
  end;
  function CalculateValue2(const InValue: LongInt): String;
  begin
    case InValue of
      0:
        Result := '0';
      1..1023:
        Result := IntToStr(InValue) + 'b';
      1024..1024575:         // 1024*1024=1024576
        Result := FloatToStrF(InValue / 1024, ffFixed, 15, 2) + 'kb';
      1024576..1073741823:   // 1024*1024*1024=1073741824
        Result := FloatToStrF(InValue / 1024576, ffFixed, 15, 2) + 'mb';
      else begin
        gCount := InValue / 1073741824;
        if gCount < 1024 then
          Result := FloatToStrF(gCount, ffFixed, 15, 2) + 'gb'
        else
          Result := FloatToStrF(gCount / 1024, ffFixed, 15, 2) + 'tb';
      end;
    end;
  end;
begin
  // ���㴫����
  if (MaxValue = 0) then
    Result := CalculateValue2(Value)
  else
    Result := CalculateValue(Value) + '/' + CalculateValue2(MaxValue);
end;          

function GetProcMemoryUsed: Cardinal;
var
  Info: PPROCESS_MEMORY_COUNTERS;
  ProcHandle: HWND;
begin
  // ��ѯ��ǰ���̵��ڴ�ʹ�ô�С
  Result := 0;
  ProcHandle := 0;
  Info := New(PPROCESS_MEMORY_COUNTERS);
  Info^.cb := SizeOf(_PROCESS_MEMORY_COUNTERS);
  try
    //�� CurrentProcessId ȡ�ý��̶���ľ��
    ProcHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ,
                              False, GetCurrentProcessId);
    if GetProcessMemoryInfo(ProcHandle, Info, Info^.cb) then
      Result := Info^.WorkingSetSize;
  finally
    if (ProcHandle <> 0) then
      CloseHandle(ProcHandle);
    Dispose(Info);
  end;
end;

function GetLocalIP: AnsiString;
var
  Ent: PHostEnt;
  Host: array of AnsiChar;
begin
  // ȡ������һ�� IP
  SetLength(Host, 128);
  try
    iocp_Winsock2.GetHostName(PAnsiChar(Host), 128);
    Ent := iocp_Winsock2.GetHostByName(PAnsiChar(Host));
    Result := IntToStr(Byte(Ent^.h_addr^[0])) + '.' +
              IntToStr(Byte(Ent^.h_addr^[1])) + '.' +
              IntToStr(Byte(Ent^.h_addr^[2])) + '.' +
              IntToStr(Byte(Ent^.h_addr^[3]));
  finally
    SetLength(Host, 0);
  end;
end;

function ResolveHostIP(const Host: AnsiString): AnsiString;
  function CheckIP(const S: AnsiString): Boolean;
  var
    i: Integer;
  begin
    for i := 1 to Length(S) do
      if not (S[i] in ['0'..'9', '.']) then
      begin
        Result := False;
        Exit;
      end;
    Result := True;
  end;
var
  Ent: PHostEnt;
begin
  // ȡ���� IP: AnsiString
  Result := '0.0.0.0';
  if (Host <> '') then
    if CheckIP(Host) then
    begin
      if inet_addr(PAnsiChar(Host)) <> INADDR_NONE then
        Result := Host;
    end else
    begin
      Ent := iocp_Winsock2.GetHostByName(PAnsiChar(Host));
      if (Ent <> nil) then  // ȡ��һ��
        Result := IntToStr(Byte(Ent^.h_addr^[0])) + '.' +
                  IntToStr(Byte(Ent^.h_addr^[1])) + '.' +
                  IntToStr(Byte(Ent^.h_addr^[2])) + '.' +
                  IntToStr(Byte(Ent^.h_addr^[3]));
    end;
end;

type
  TSystemPath = (
    spWindows,
    spSystem,
    spProgramFile,
    spProgramData,
    spSystemTemp
  );

procedure InternalGetPath(PathType: TSystemPath; var Path: String);
begin
  SetLength(Path, 256);
  case PathType of
    spWindows:
      GetWindowsDirectory(PChar(Path), 256);    // ���治�� '\'
    spSystem:
      GetSystemDirectory(PChar(Path), 256);     // ���治�� '\'
    spProgramFile:
      with TRegistry.Create do begin
        RootKey := HKEY_LOCAL_MACHINE;
        if OpenKey('software\microsoft\windows\currentversion', False) then
          Path := ReadString('ProgramFilesDir');
        Free;
      end;
    spProgramData:
      with TRegistry.Create do begin
        RootKey := HKEY_LOCAL_MACHINE;
        if OpenKey('Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders', False) then
          Path := ReadString('Common AppData'); 
        Free;
      end;
    spSystemTemp:
      GetTempPath(256, PChar(Path));           // ����� '\'
  end;
  SetLength(Path, StrLen(PChar(Path)));
  if Copy(Path, Length(Path), 1) <> '\' then
    Path := Path + '\';
end;

function GetWindowsDir: String;
begin
  InternalGetPath(spWindows, Result);
end;

function GetSystemDir: String;
begin
  InternalGetPath(spSystem, Result);
end;

function GetProgramFileDir: String;
begin
  InternalGetPath(spProgramFile, Result);
end;

function GetProgramDataDir: String;
begin
  InternalGetPath(spProgramData, Result);
end;

function GetSystemTempDir: String;
begin
  InternalGetPath(spSystemTemp, Result);
end;

function MyCreateDir(const Path: String): Boolean;
begin
  // ��Ŀ¼
  if DirectoryExists(Path) then
    Result := True
  else
    Result := ForceDirectories(Path);
end;

function FileTimeToDateTime(AFileTime: TFileTime): TDateTime;
var
 SysTime: TSystemTime;
 Temp: TFileTime;
begin
  // ת���ļ���ʱ�䵽 delphi ��ʽ
  FileTimeToLocalFileTime(AFileTime, Temp);
  FileTimeToSystemTime(Temp, SysTime);
  Result := SystemTimeToDateTime(SysTime);
end;

function CreateNewFileName(const FileName: String): String;
var
  i: Integer;
begin
  // �������ļ��������ϵ�������
  for i := Length(FileName) downto 1 do
    if (FileName[i] = '.') then
    begin
      Result := Copy(FileName, 1, i - 1) + '_' + IntToStr(GetTickCount) +
                Copy(FileName, i, 99);
      Exit;
    end;
  Result := FileName;
end;

function GetCompressionLevel(const FileName: String): TZipLevel;
var
  Ext: String;
begin
  // ����ѹ���ʣ���ѹ�����ļ�����ѹ�����䡢�������ļ���ѹ���ʵͣ�
  Ext := UpperCase(ExtractFileExt(FileName));
  if (Ext = '.RAR')  or (Ext = '.ZIP')  or (Ext = '.7Z')   or
     (Ext = '.JPG')  or (Ext = '.DOCX') or (Ext = '.XLSX') or
     (Ext = '.PPTX') or (Ext = '.TAR')  or (Ext = '.CAB')  or
     (Ext = '.GZIP') or (Ext = '.BZ2')  or (Ext = '.JAR')  or
     (Ext = '.ISO')  or (Ext = '.GHO')  or (Ext = '.UUE')  or
     (Ext = '.ACE')  or (Ext = '.LZH')  or (Ext = '.ARJ')  or
     (Ext = '.EXE')  or (Ext = '.AVI')  or (Ext = '.VDI')  or 
     (Ext = '.Z')
//     (Ext = '.SYS') or (Ext = '.DLL') or (Ext = '.OCX')
  then
    Result := zcNone
  else
    Result := zcDefault;
end;

function InternalOpenFile(const FileName: String; ReadOnly: Boolean): THandle;
begin
  // ���ļ�
  //   ����ʹ�ã�OPEN_EXISTING or CREATE_ALWAYS
  //   ������ FILE_FLAG_OVERLAPPED ʱ��ReadFile Ҫ Overlapped�������쳣��
  if ReadOnly then
    Result := Windows.CreateFile(PChar(FileName), GENERIC_READ,
                      FILE_SHARE_READ, nil, OPEN_EXISTING,
                      FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, 0)
  else
    Result := Windows.CreateFile(PChar(FileName), GENERIC_READ or GENERIC_WRITE,
                      FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING,
                      FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, 0);
  if (Result = INVALID_HANDLE_VALUE) then
    Result := INVALID_FILE_HANDLE;
end;

function InternalOpenMsgFile(const FileName: String; AutoCreate: Boolean): THandle;
var
  iFlag, iValue: Cardinal;
begin
  // �򿪡��½�������Ϣ�ļ����½�ʱд���ļ���־ OFFLINE_MS_FLAG
  //   ��Ϣ�ļ����� 2m ���ļ���
  Result := Windows.CreateFile(PChar(FileName), GENERIC_READ or GENERIC_WRITE,  // ����д
                    0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if (Result = INVALID_HANDLE_VALUE) then  // �½��ļ�
  begin
    if AutoCreate then
    begin
      iFlag := OFFLINE_MSG_FLAG;
      Result := Windows.CreateFile(PChar(FileName), GENERIC_READ or GENERIC_WRITE,
                      0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
      Windows.WriteFile(Result, iFlag, SizeOf(Integer), iValue, nil);
    end;
  end else
  begin
    iFlag := 0;
    Windows.ReadFile(Result, iFlag, SizeOf(Integer), iValue, nil);
    if (iFlag <> OFFLINE_MSG_FLAG) then  // ��־����
    begin
      Windows.CloseHandle(Result);
      Result := INVALID_HANDLE_VALUE;
    end else
    if (Windows.GetFileSize(Result, nil) > 2014000) then
    begin
      // �ļ�̫�󣬸������½���Ϣ�ļ�
      Windows.CloseHandle(Result);
      SysUtils.RenameFile(FileName, FileName + '@' + IntToStr(GetUTCTickCount));
      Result := InternalOpenMsgFile(FileName, AutoCreate);
    end;
  end;
  if (Result = INVALID_HANDLE_VALUE) then
    Result := INVALID_FILE_HANDLE;  
end;

function GetFileSize64(Handle: THandle): Int64;
begin
  // ȡ�ļ���С
  Result := 0;
  Int64Rec(Result).Lo := SetFilePointer(Handle, Int64Rec(Result).Lo,
                                        @Int64Rec(Result).Hi, FILE_END);
  SetFilePointer(Handle, 0, nil, FILE_BEGIN);
  if (Int64Rec(Result).Lo = $FFFFFFFF) and (GetLastError <> 0) then
    Int64Rec(Result).Hi := $FFFFFFFF;
end;

function VariantToStream(Data: Variant; ZipCompress: Boolean; const FileName: String): TStream;
var
  p: Pointer;
  iSize, ZipSize: Integer;
  OutBuffer: Pointer;
begin
  // �ѱ䳤��������תΪ��������֧��ѹ��������Ϊ�ļ���
  //   Data ��Ҫ���� String ��������������!

  if VarIsNull(Data) then
  begin
    Result := nil;
    Exit;
  end;

  if (FileName = '') then  // ��In�ڴ���
    Result := TInMemStream.Create
  else  // ���ļ���
    Result := TFileStream.Create(FileName, fmCreate);

  iSize := VarArrayHighBound(Data, 1) - VarArrayLowBound(Data, 1) + 1;
  p := VarArrayLock(Data);

  try
    if ZipCompress then  // ֱ��ѹ�����ݣ���ѹ�����ڴ�ҵ� Result ��
    begin
      iocp_zlib.ZCompress(p, iSize, OutBuffer, ZipSize, zcDefault);
      TInMemStream(Result).SetMemory(OutBuffer, ZipSize);
    end else
      Result.Write(p^, iSize);
//    TInMemStream(Result).SaveToFile('q.dat');
  finally
    VarArrayUnlock(Data);
  end;
  
end;

function StreamToVariant(Stream: TStream; ZipDecompress: Boolean): Variant;
var
  Source: TStream;
  iSize: Integer;
  p: Pointer;
begin
  // ��������ת��Ϊ varByte Variant ���ͣ����ݼ��� Delta��
  if Assigned(Stream) then
  begin
    iSize := Stream.Size;
    if (iSize > 0) then
    begin
      if ZipDecompress then  // �Ƚ�ѹ
      begin
        Stream.Position := 0;
        Source := TMemoryStream.Create;
        iocp_zlib.ZDecompressStream(Stream, Source);
        iSize := Source.Size;
      end else
        Source := Stream;

      Result := VarArrayCreate([0, iSize - 1], varByte);
      p := VarArrayLock(Result);

      try
        Source.Position := 0;
        Source.Read(p^, iSize);
      finally
        if ZipDecompress then
          Source.Free;
        VarArrayUnlock(Result);
      end;
      
    end else
      Result := NULL;
  end else
    Result := NULL;
end;

function EncryptString(const S: AnsiString): AnsiString;
var
  i: Integer;
  p: PByte;
begin
  Result := S;
  p := PByte(Result);
  for i := 1 to Length(S) do
  begin
    case i of
      1, 3, 5, 7, 9:
        p^ := p^ xor Byte(19);
      2, 4, 6, 8, 10:
        p^ := p^ xor Byte(37);
      else
        p^ := p^ xor Byte(51);
    end;
    Inc(p);
  end;
end;

function DecryptString(const S: AnsiString): AnsiString;
begin
  Result := EncryptString(S);
end;

function MatchSocketType(InBuf: PAnsiChar; const SocketFlag: AnsiString): Boolean;
var
  i: Integer;
begin
  // ���Э��ͷ��־��IOCP_SOCKET_FLAG
  for i := 1 to Length(SocketFlag) do
  begin
    if (InBuf^ <> SocketFlag[i]) then
    begin
      Result := False;
      Exit;
    end;
    Inc(InBuf);
  end;
  Result := True;
end;

procedure InterDataSetToJSON(DataSet: TDataSet; Headers: THttpResponeHeaders;
                             List: TInStringList; CharSet: THttpCharSet);
  function CharSetText(const S: AnsiString): AnsiString;
  begin
    // �����ַ���ת���ַ���
    case CharSet of
      hcsUTF8:
        Result := System.UTF8Encode(S); // ������� JSON Object δ��������ʾ��Ҫת��
      hcsURLEncode:
        Result := http_utils.URLEncode(S); // ����� AJAX Ҫת������
      else
        Result := S;
    end;
  end;
var
  BufLength: Integer;
  i, k, n, m, Idx: integer;
  p: PAnsiChar;
  Desc, JSON: AnsiString;
  Names: TStringAry;
  Field: TField;
begin
  // ���ٰ����ݼ�תΪ JSON��Blob�ֶ�����δ���룩
  //  1. Headers <> nil, �ֿ鷢��
  //  2. List <> nil, ���浽�б�

  // ע�⣺ÿ�ֶγ��Ȳ��ܳ��� IO_BUFFER_SIZE

  if not DataSet.Active or DataSet.IsEmpty then
    Exit;
    
  Dataset.DisableControls;
  Dataset.First;

  try
    // 1. �ȱ����ֶ����������飨�ֶ������ִ�Сд��

    n := 5;  // ������¼�� JSON ���ȣ���ʼΪ Length('["},]')
    k := Dataset.FieldCount;

    SetLength(Names, k);
    for i := 0 to k - 1 do
    begin
      Field := Dataset.Fields[i];
      if (i = 0) then
      begin
        Desc := '{"' + CharSetText(LowerCase(Field.FieldName)) + '":"';  // ��Сд
      end else
        Desc := '","' + CharSetText(LowerCase(Field.FieldName)) + '":"';
      Names[i] := Desc;
      Inc(n, Length(Desc) + Field.Size);
    end;

    // 2. ÿ����¼תΪ JSON��������ʱ���� �� �����б�

    if Assigned(Headers) then
    begin
      BufLength := IO_BUFFER_SIZE - 8;
      Headers.ChunkSize(0);  // ��ʼ��
      Headers.Append('[', False);
    end else
    begin
      BufLength := 0;
      if Assigned(List) and (List.Size > 0) then
        List.Clear;
    end;

    while not Dataset.Eof do
    begin
      SetLength(JSON, n);    // Ԥ���¼�ռ�
      p := PAnsiChar(JSON);
      Idx := 0;              // ���ݵ�ʵ�ʳ���

      for i := 0 to k - 1 do
      begin
        Field := Dataset.Fields[i];
        if (i = k - 1) then  // [{"Id":"1","Name":"��"},{"Id":"2","Name":"��"}]
          Desc := Names[i] + CharSetText(Field.Text) + '"}'
        else
          Desc := Names[i] + CharSetText(Field.Text);
        m := Length(Desc);
        System.Move(Desc[1], p^, m);
        Inc(p, m);
        Inc(Idx, m);
      end;

      Dataset.Next;   // ��һ��
      
      if Assigned(List) then
      begin
        Delete(JSON, Idx + 1, n - Idx);   // ɾ����������
        List.Add(JSON); // �����б�
      end else
      begin
        Inc(Idx);  // Ҫ���Ӽ�¼��������� , �� ]
        Delete(JSON, Idx + 1, n - Idx);   // ɾ����������

        if (Headers.Size + Idx > BufLength) then  // �����ֿ���󳤶ȣ��ȷ���
        begin
          Headers.ChunkSize(Headers.Size);  // ���÷ֿ鳤��
          Headers.Owner.SendBuffers;  // ����
          Headers.ChunkSize(0);  // ��λ
        end;

        // ���룬�´���ʱ����
        if Dataset.Eof then
        begin
          JSON[Idx] := ']';  // ������
          Headers.Append(JSON, False);
        end else
        begin
          JSON[Idx] := ',';  // δ����
          Headers.Append(JSON, False);
        end;
      end;

    end;

    if Assigned(Headers) then
    begin
      if (Headers.Size > 0) then
      begin
        Headers.ChunkSize(Headers.Size);  // ���÷ֿ鳤��
        Headers.Owner.SendBuffers;  // ����
        Headers.Clear;  // ���
      end;
      Headers.ChunkDone;
      Headers.Owner.SendBuffers;  // ����
      Headers.Clear;
    end;

  finally
    Dataset.EnableControls;
  end;

end;

function DataSetToJSON(DataSet: TDataSet; CharSet: THttpCharSet): AnsiString;
var
  List: TInStringList;
begin
  // ���ٰ����ݼ�ȫ����¼ת��Ϊ JSON
  List := TInStringList.Create;
  try
    InterDataSetToJSON(DataSet, nil, List, CharSet);
    Result := List.JSON;  // �ϲ� JSON ��¼
  finally
    List.Free;
  end;
end;

procedure LargeDataSetToJSON(DataSet: TDataSet; Headers: TObject; CharSet: THttpCharSet);
begin
  // �÷ֿ鷽�����ʹ����ݼ� JSON
  InterDataSetToJSON(DataSet, THttpResponeHeaders(Headers), nil, CharSet);
end;

function GetUTCTickCount: Int64;
var
  UtcFt: _FILETIME;
begin
  // ��ȷ��ǧ���֮һ��
  //   ������ GetTickCount һ���ĺ���
  GetSystemTimeAsFileTime(UtcFt);
  Result := (Int64(UtcFt) shr 4);
end;

function GetUTCTickCountEh(Seed: Pointer): UInt64;
var
  UtcFt: _FILETIME;
begin
  // ��ȷ��ǧ���֮һ�룬�� Seed �������Ψһֵ
  GetSystemTimeAsFileTime(UtcFt);
  if (Seed <> nil) then
    {$IFDEF WIN_64}
    UInt64(UtcFt) := UInt64(UtcFt) xor UInt64(Seed);
    {$ELSE}
    UtcFt.dwLowDateTime := UtcFt.dwLowDateTime xor LongWord(Seed);
    {$ENDIF}
  Result := UInt64(UtcFt);
end;

procedure FormatNowToBuf(const Buf: PAnsiChar);
type
  TDblChar = array[0..1] of AnsiChar;

  PDateTimeFormat = ^TDateTimeFormat;
  TDateTimeFormat = packed record
      Year: TDblChar; Year2: TDblChar; S: AnsiChar;
     Month: TDblChar;    S2: AnsiChar;
       Day: TDblChar;    S3: AnsiChar;
      Hour: TDblChar;    S4: AnsiChar;
    Minute: TDblChar;    S5: AnsiChar;
    Second: TDblChar;    S6: AnsiChar;
      MSec: TDblChar; MSec2: AnsiChar
  end;

const
  DBL_NUMBERS: array[0..99] of TDblChar = (
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
  Data: PDateTimeFormat;
  i: Integer;
begin
  // ת��ʱ���ʽΪ�ַ�����֧��˫�ֽڣ������ⲿ���ã�
  //   S: String = '2017-11-05 11:12:52 321'; ���� PChar(@S[1])

  Windows.GetLocalTime(SysTime);

  Data := PDateTimeFormat(Buf);

  // ��
  i := SysTime.wYear div 100;
  Data^.Year := DBL_NUMBERS[i];
  Data^.Year2 := DBL_NUMBERS[SysTime.wYear - i * 100];

  // �¡���
  Data^.Month := DBL_NUMBERS[SysTime.wMonth];
  Data^.Day := DBL_NUMBERS[SysTime.wDay];

  // ʱ���֡���
  Data^.Hour := DBL_NUMBERS[SysTime.wHour];
  Data^.Minute := DBL_NUMBERS[SysTime.wMinute];
  Data^.Second := DBL_NUMBERS[SysTime.wSecond];

  // ����
  i := SysTime.wMilliseconds div 10;
  Data^.MSec := DBL_NUMBERS[i];
  Data^.MSec2 := DBL_NUMBERS[SysTime.wMilliseconds - i * 10][1];

end;  

function FormatDataTimeNow: AnsiString;
begin
  Result := '2017-11-05 11:12:52 321';
  FormatNowToBuf(PAnsiChar(@Result[1]));
end;

procedure IniDateTimeFormat;
begin
  {$IFDEF DELPHI_XE}     // xe �����
  FormatSettings.DateSeparator := '-';
  FormatSettings.TimeSeparator := ':';
  FormatSettings.ShortDateFormat := 'yyyy-mm-dd';
  {$ELSE}
  DateSeparator := '-';
  TimeSeparator := ':';
  ShortDateFormat := 'yyyy-mm-dd';
  {$ENDIF}
end;

procedure GetLocalFileInf(const FileName: String; var FileSize: TFileSize;
                          var CreationTime, AccessTime, LastWriteTime: TFileTime);
var
  Data: TWin32FindData;
  Handle: THandle;
begin
  // ȡ�ļ���С����32λ����������ļ����䣩��ʱ��
  Handle := Windows.FindFirstFile(PChar(FileName), Data);
  if Handle <> INVALID_HANDLE_VALUE then
  begin
    if (Data.nFileSizeHigh = 0) then
      FileSize := Data.nFileSizeLow
    else  // MAXDWORD = DWORD($FFFFFFFF);
      FileSize := Int64($FFFFFFFF) + Data.nFileSizeLow + 1;
    CreationTime := Data.ftCreationTime;
    AccessTime := Data.ftLastAccessTime;
    LastWriteTime := Data.ftLastWriteTime;
    Windows.FindClose(Handle);
  end;
end;

procedure RegMSAccessDSN(const DataSourceName, AccessFileName, Description: String);
const
  DRIVER_KEY_32 = 'Microsoft Access Driver (*.mdb)';
  DRIVER_KEY_64 = 'Microsoft Access Driver (*.mdb, *.accdb)';
var
  Reg: TRegistry;
  Driver, DriverKey: String;
begin
  // ���� Access ODBC
  // �����ļ�λ�ã�32 λ��Microsoft Access Driver (*.mdb)
  //               64 λ��Microsoft Access Driver (*.mdb, *.accdb)
  Reg := TRegistry.Create;
  Reg.RootKey := HKEY_LOCAL_MACHINE; // �� HKEY_LOCAL_MACHINE

  try
    // ȡ�����ļ�������
    if Reg.OpenKey('Software\ODBC\ODBCINST.INI\' + DRIVER_KEY_64, False) then
    begin
      Driver := Reg.ReadString('Driver');
      DriverKey := DRIVER_KEY_64;
    end else
    if Reg.OpenKey('Software\ODBC\ODBCINST.INI\' + DRIVER_KEY_32, False) then
    begin
      Driver := Reg.ReadString('Driver');
      DriverKey := DRIVER_KEY_32;
    end;

    Reg.CloseKey;
    if Reg.OpenKey('Software\ODBC\ODBC.INI\' + DataSourceName, True) then
    begin
      Reg.WriteString('DBQ', AccessFileName);  // ���ݿ��ļ�
      Reg.WriteString('Description', Description); // ����
      Reg.WriteString('Driver', Driver);  // ����
      Reg.WriteInteger('DriverId', 25);   // ������ʶ
      Reg.WriteString('FIL', 'Ms Access;');    // Filter ����
      Reg.WriteInteger('SafeTransaction', 0);  // ���������
      Reg.WriteString('UID', '');  // �û�����

      Reg.CloseKey;
      if Reg.OpenKey('Software\ODBC\ODBC.INI\' + DataSourceName + '\Engines\Jet', True) then
      begin
        Reg.WriteString('ImplicitCommitSync', 'Yes');
        Reg.WriteInteger('MaxBufferSize', 512); // ��������С
        Reg.WriteInteger('PageTimeout', 10); // ҳ��ʱ
        Reg.WriteInteger('Threads', 3);  // ֧�ֵ��߳���
        Reg.WriteString('UserCommitSync', 'Yes');

        Reg.CloseKey;
        if Reg.OpenKey('Software\ODBC\ODBC.INI\ODBC Data Sources', True) then
          Reg.WriteString(DataSourceName, DriverKey);
      end;
    end;
  finally
    Reg.CloseKey;
    Reg.Free;
  end;
end;

procedure SetMSAccessDSN(ADO: TADOConnection; DataSourceOrFileName, DSNFile: String);
const
  CONNECTION_STR = 'Provider=MSDASQL.1;Persist Security Info=False;Extended Properties="DBQ=%s;DefaultDir=%s;Driver={Microsoft Access Driver (*.mdb)};';
  CONNECTION_STR2 = 'DriverId=25;FIL=MS Access;FILEDSN=%s;MaxBufferSize=2048;MaxScanRows=8;PageTimeout=5;SafeTransactions=0;Threads=3;UID=admin;UserCommitSync=Yes;"';
  CONNECTION_STR3 = 'Provider=MSDASQL.1;Persist Security Info=False;Data Source=';
begin
  // ���� Access ADO ����
  if ADO.Connected then
    ADO.Connected := False;
  if (DSNFile = '') then // �� ODBC
    ADO.ConnectionString := CONNECTION_STR3 + DataSourceOrFileName
  else   // �� DatabaseFile + DSN FileName
    ADO.ConnectionString := Format(CONNECTION_STR + CONNECTION_STR2,
        [DataSourceOrFileName, ExtractFilePath(DataSourceOrFileName), DSNFile]);
end;

procedure ClearSysMemory;
begin
  // �����ڴ棬�����ڴ�ռ�������������棩
  if Win32Platform = VER_PLATFORM_WIN32_NT then
    SetProcessWorkingSetSize(GetCurrentProcess, $FFFFFFFF, $FFFFFFFF);
end;

end.
