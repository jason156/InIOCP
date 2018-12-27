(*
 * ���� MurmurHash64���������� ��10 �Ĵ����޸ģ�֧�ִ��ļ���
 *
 * https://blog.csdn.net/baiyunpeng42/article/details/45339937
 * https://blog.csdn.net/chenxing888/article/details/5912183
 *)
unit iocp_mmHash;

interface

{$I in_iocp.inc}

uses
  Windows, SysUtils, iocp_utils;

type
  {$IF CompilerVersion < 18.5}
  FILE_SIZE = Cardinal;
  {$ELSE}
  FILE_SIZE = Int64;
  {$IFEND}

function MurmurHash64(const Key: Pointer; Size: Cardinal): UInt64; overload;
function MurmurHash64(const FileName: string): UInt64; overload;
function MurmurHash64(Handle: THandle): UInt64; overload;
function MurmurHashPart64(Handle: THandle; Offset: FILE_SIZE; PartSize: Cardinal): UInt64;

implementation

type

  PMurmurHashInf = ^TMurmurHashInf;
  TMurmurHashInf = record
    h1, h2: Cardinal;
    Data: PInteger;
    K1, K2: Integer;    // ���룬��Ƶ������
    Tail: array[0..3] of Byte;
    Result: UInt64;     // ���
  end;

const
  m: Cardinal = $5bd1e995;
  r: Integer = 24;

procedure MurmurHash64Init(Inf: PMurmurHashInf; Size: Int64);
var
  KeySize: ULARGE_INTEGER;
begin
  // Դ�� Size Ϊ Cardinal��xor һ��
  KeySize.QuadPart := Size;
  Inf^.h1 := ($EE6B27EB xor KeySize.HighPart) xor KeySize.LowPart;  // ����
  Inf^.h2 := 0;
  Inf^.Data := nil;
end;

procedure MurmurHash64Update(Inf: PMurmurHashInf; const Key: Pointer; var Size: Cardinal);
begin
  // Size Ӧ�� 8 �ı���
  Inf^.Data := PInteger(Key);
  while (Size >= 8) do
  begin
    Inf^.K1 := Inf^.Data^;
    Inc(Inf^.Data);
    Inf^.K1 := Inf^.K1 * m;
    Inf^.K1 := Inf^.K1 xor (Inf^.K1 shr r);
    Inf^.k1 := Inf^.k1 * m;
    Inf^.h1 := Inf^.h1 * m;
    Inf^.h1 := Inf^.h1 xor Inf^.k1;
    Dec(Size, 4);
    //\\
    Inf^.k2 := Inf^.Data^;
    Inc(Inf^.Data);
    Inf^.k2 := Inf^.k2 * m;
    Inf^.k2 := Inf^.k2 xor (Inf^.k2 shr r);
    Inf^.K2 := Inf^.K2 * m;
    Inf^.h2 := Inf^.h2 * m;
    Inf^.h2 := Inf^.h2 xor Inf^.k2;
    Dec(Size, 4);
  end;
end;

procedure MurmurHash64Final(Inf: PMurmurHashInf; const Key: Pointer; var Size: Cardinal);
begin
  // ������ 8 �ֽڵ�����
  if (Size >=4) then
  begin
    Inf^.k1 := Inf^.Data^;
    Inc(Inf^.Data);

    Inf^.k1 := Inf^.k1 * m;
    Inf^.K1 := Inf^.k1 xor (Inf^.k1 shr r);
    Inf^.k1 := Inf^.k1 * m;

    Inf^.h1 := Inf^.h1 * m;
    Inf^.h1 := Inf^.h1 xor Inf^.k1;
    Dec(Size, 4);
  end;

  case Size of
     3: begin
       Integer(Inf^.Tail) := Inf^.Data^;
       Inf^.Tail[3] := 0;
       Inf^.h2 := Inf^.h2 xor Integer(Inf^.Tail);
       Inf^.h2 := Inf^.h2 * m;
     end;
     2: begin
       Inf^.h2 := Inf^.h2 xor PWord(Inf^.Data)^;
       Inf^.h2 := Inf^.h2 * m;
     end;
     1: begin
       Inf^.h2 := Inf^.h2 xor PByte(Inf^.Data)^;
       Inf^.h2 := Inf^.h2 * m;
     end;
  end;

  Inf^.h1 := Inf^.h1 xor (Inf^.h2 shr 18);
  Inf^.h1 := Inf^.h1 * m;

  Inf^.h2 := Inf^.h2 xor (Inf^.h1 shr 22);
  Inf^.h2 := Inf^.h2 * m;

  Inf^.h1 := Inf^.h1 xor (Inf^.h2 shr 17);
  Inf^.h1 := Inf^.h1 * m;

  Inf^.h2 := Inf^.h2 xor (Inf^.h1 shr 19);
  Inf^.h2 := Inf^.h2 * m;

  Inf^.Result := Inf^.h1;
  Inf^.Result := (Inf^.Result shl 32) or Inf^.h2;
end;

function MurmurHash64(const Key: Pointer; Size: Cardinal): UInt64;
var
  MurmurHash: TMurmurHashInf;
begin
  // �����ڴ�� MurmurHash
  MurmurHash64Init(@MurmurHash, Size);
  MurmurHash64Update(@MurmurHash, Key, Size);
  MurmurHash64Final(@MurmurHash, Key, Size);
  Result := MurmurHash.Result;
end;

function MurmurHash64(const FileName: string): UInt64;
var
  Handle: THandle;
begin
  // �����ļ��� MurmurHash��֧�ִ��ļ���

  Handle := CreateFile(PChar(FileName), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE,
                       nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, 0);
  if (Handle = INVALID_HANDLE_VALUE) then
    Result := 0
  else
    try
      Result := MurmurHash64(Handle);
    finally
      CloseHandle(Handle);
    end;
end;

function MurmurHash64(Handle: THandle): UInt64;
var
  Inf: SYSTEM_INFO;
  MapHandle: THandle;
  FileSize, Offset: FILE_SIZE;
  Granularity, PartSize: Cardinal;
  MapOffset: LARGE_INTEGER;
  ViewPointer: Pointer;
  MurmurHash: TMurmurHashInf;
begin
  // �����ļ������ MurmurHash��֧�ִ��ļ���

  if (Handle = 0) or (Handle = INVALID_HANDLE_VALUE) then
  begin
    Result := 0;
    Exit;
  end;

  FileSize := GetFileSize64(Handle);
  MurmurHash64Init(@MurmurHash, FileSize);

  MapHandle := CreateFileMapping(Handle, nil, PAGE_READONLY, 0, 0, nil);
  if (MapHandle <> 0) then
    try
      {$IFDEF DELPHI_7}
      GetSystemInfo(Inf);  // ȡ�ڴ���侫��
      {$ELSE}
      GetSystemInfo(&Inf);  // ȡ�ڴ���侫��
      {$ENDIF}

      Granularity := Inf.dwAllocationGranularity * 80; // 8 �ı���
      Offset := 0;

      while (FileSize > 0) do
      begin
        if (FileSize > Granularity) then
          PartSize := Granularity
        else
          PartSize := FileSize;

        // ӳ��: λ��=Offset, ����=PartSize��8�ı�����
        MapOffset.QuadPart := Offset;
        ViewPointer := MapViewOfFile(MapHandle, FILE_MAP_READ,
                                     MapOffset.HighPart, MapOffset.LowPart,
                                     PartSize);

        Inc(Offset, PartSize);
        Dec(FileSize, PartSize);

        if (ViewPointer <> nil) then
          try
            if (PartSize >= 8) then
              MurmurHash64Update(@MurmurHash, ViewPointer, PartSize);
            if (FileSize = 0) then
              MurmurHash64Final(@MurmurHash, ViewPointer, PartSize);
          finally
            UnmapViewOfFile(ViewPointer);
          end;
      end;
    finally
      CloseHandle(MapHandle);
    end;

  Result := MurmurHash.Result;

end;

function MurmurHashPart64(Handle: THandle; Offset: FILE_SIZE; PartSize: Cardinal): UInt64;
var
  MapHandle: THandle;
  MapOffset: LARGE_INTEGER;
  ViewPointer: Pointer;
  MurmurHash: TMurmurHashInf;
begin
  // �����ļ���Χ�� MurmurHash��֧�ִ��ļ���

  if (Handle = 0) or (Handle = INVALID_HANDLE_VALUE) or (PartSize = 0) then
  begin
    Result := 0;
    Exit;
  end;

  MurmurHash64Init(@MurmurHash, PartSize);

  MapHandle := CreateFileMapping(Handle, nil, PAGE_READONLY, 0, 0, nil);
  if (MapHandle <> 0) then
    try
      // ӳ�䷶Χ: λ��=Offset, ����=PartSize
      MapOffset.QuadPart := Offset;
      ViewPointer := MapViewOfFile(MapHandle, FILE_MAP_READ,
                                   MapOffset.HighPart, MapOffset.LowPart,
                                   PartSize);
      if (ViewPointer <> nil) then
        try
          MurmurHash64Update(@MurmurHash, ViewPointer, PartSize);
          MurmurHash64Final(@MurmurHash, ViewPointer, PartSize);
        finally
          UnmapViewOfFile(ViewPointer);
        end;

    finally
      CloseHandle(MapHandle);
    end;

  Result := MurmurHash.Result;

end;

end.
