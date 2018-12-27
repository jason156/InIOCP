(*
 * �����б�Ԫ
 *)
unit iocp_lists;

interface

{$I in_iocp.inc}

uses
  Windows, Classes, SysUtils, iocp_base;

type

  // ===================== �Զ����б� �� =====================

  // ֻ��ɾ���׽ڵ���б�
  //    ÿ�μ���ʱ��ֻ����һ���ڵ�ռ䣬ֻ��ɾ���׽ڵ�

  //    ���б��ܳ��������Ƭ�ڴ�飬������Ƶ�����䡢�ͷţ�
  //    �ظ������ͷŵĽڵ�ռ���Ա��ⲻ�㡣

  // Delphi 2007 �� XE 10 �� PPointerList ���岻ͬ

  PItemArray = ^TItemArray;
  TItemArray = array[0..MaxInt div 16 - 1] of Pointer;

  TInList = class(TObject)
  private
    FHead: PItemArray;      // ͷ�ڵ�
    FTail: PItemArray;      // β�ڵ�
    FCount: Integer;        // ������
    function GetItems(Index: Integer): Pointer;
  public
    constructor Create;
    destructor Destroy; override;
  public
    procedure Add(Item: Pointer); {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure Clear; virtual;
    function Exists(Item: Pointer): Boolean;
    function PopFirst: Pointer; {$IFDEF USE_INLINE} inline; {$ENDIF}
  public
    property Count: Integer read FCount;
    property Items[Index: Integer]: Pointer read GetItems;
  end;

  // TInDataList �� TList Ч�ʸ�

  TInDataList = class(TObject)
  private
    FItems: PItemArray;     // �����
    FLength: Integer;       // FItems ����
    FCount: Integer;        // ��������
    function GetItems(Index: Integer): Pointer;
    procedure ClearItems; {$IFDEF USE_INLINE} inline; {$ENDIF} // �������
    procedure SetItems(Index: Integer; const Value: Pointer); virtual;
    procedure SetCount(Value: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(Item: Pointer); {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure Delete(Index: Integer); virtual;
    procedure Clear; virtual;
    function PopFirst: Pointer; {$IFDEF USE_INLINE} inline; {$ENDIF} // δ��
  public
    property Count: Integer read FCount write SetCount;
    property Items[Index: Integer]: Pointer read GetItems write SetItems;
  end;

  // TInStringList �ַ����б��� TStringList Ч�ʸ�
  // ��Ҫ������ַ�����
  
  PStringItem = ^TStringItem;
  TStringItem = record
    FString: AnsiString;  // �õ��ֽ�
    FObject: TObject;
  end;

  // JSON �ֿ�λ��
  TJSONChunkPosition = (
    cpAll,            // ȫ��
    cpFirst,          // ��һ��
    cpMiddle,         // �м��
    cpLast            // ����
  );

  TInStringList = class(TInDataList)
  private
    FSize: Integer;
    function UnionStrings(Buf: PAnsiChar; InterChr: AnsiChar): PAnsiChar;
    function GetDelimitedText: AnsiString;
    function GetHttpString(Headers: Boolean): AnsiString;
    function GetJSON: AnsiString;
    function GetJSONChunk(Position: TJSONChunkPosition): AnsiString;
    function GetObjects(Index: Integer): Pointer;
    function GetStrings(Index: Integer): AnsiString;
    function GetText: AnsiString;
    procedure SetItems(Index: Integer; const Value: Pointer); override;
  public
    function IndexOf(const Key: AnsiString): Integer; overload; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function IndexOf(const Key: AnsiString; var Item: Pointer): Boolean; overload; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function IndexOf(Item: Pointer): Integer; overload; {$IFDEF USE_INLINE} inline; {$ENDIF}

    procedure Add(const Key: AnsiString; Item: Pointer); overload; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure Add(const S: AnsiString); overload; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure AddStrings(Strings: TInStringList); {$IFDEF USE_INLINE} inline; {$ENDIF}

    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure DeleteItem(Item: Pointer);
    procedure SaveToFile(const FileName: String);
    procedure WriteLog(Handle: THandle);    
  public
    property DelimitedText: AnsiString read GetDelimitedText;
    property HttpString[Headers: Boolean]: AnsiString read GetHttpString;
    property JSON: AnsiString read GetJSON;
    property JSONChunk[Position: TJSONChunkPosition]: AnsiString read GetJSONChunk;
    property Objects[Index: Integer]: Pointer read GetObjects;
    property Size: Integer read FSize;
    property Strings[Index: Integer]: AnsiString read GetStrings;
    property Text: AnsiString read GetText;
  end;

  // ==================== JSON ��� ====================

  // �ַ�������
  TStringAry = array of AnsiString;
  PStringAry = ^TStringAry;

  // List �Ļص��¼���Source��TTaskList��
  TCallbackEvent = procedure(List: TInStringList; Position: TJSONChunkPosition) of object;

implementation

uses
  iocp_msgPacks, http_base;

const
  ALLOCATE_COUNT = 100;   // TInDataList ÿ������ռ���

{ TInList }

procedure TInList.Add(Item: Pointer);
var
  NewBlock: PItemArray;
begin
  GetMem(NewBlock, 2 * POINTER_SIZE);

  if (FCount = 0) then
  begin
    FHead := NewBlock;
    FTail := NewBlock;
  end else
  begin
    FTail^[1] := NewBlock;  // ������
    FTail := NewBlock;
  end;

  FTail^[0] := Item;        // Item ռ��
  FTail^[1] := Nil;

  Inc(FCount);
end;

procedure TInList.Clear;
var
  NextBlock: PItemArray;
begin
  if Assigned(FHead) then
  begin
    repeat
      NextBlock := FHead^[1];
      FreeMem(FHead);
      FHead := NextBlock;
    until FHead = Nil;
    FTail := nil;
    FCount := 0;
  end;
end;

constructor TInList.Create;
begin
  inherited;
  FHead := Nil;
  FCount := 0;
end;

destructor TInList.Destroy;
begin
  if Assigned(FHead) then
    Clear;
  inherited;
end;

function TInList.PopFirst: Pointer;
var
  Block: PItemArray;
begin
  // �����׽ڵ�
  if (FCount > 0) then
  begin
    Result := FHead^[0];
    Block := FHead^[1];
    FreeMem(FHead);      // ͬʱɾ���洢�ռ�
    FHead := Block;
    Dec(FCount);
    if (FCount = 0) then
      FHead := Nil;
  end else
    Result := Nil;
end;

function TInList.GetItems(Index: Integer): Pointer;
var
  i: Integer;
  Block: PItemArray;
begin
  if (Index < 0) or (Index >= FCount) then
    Result := nil
  else begin
    i := 0;
    Block := FHead;
    Result := Block[0];
    while Assigned(Block) and (i < Index) do
    begin
      Block := PItemArray(Block)^[1];
      Result := Block[0];
      Inc(i);
    end;
  end;
end;

function TInList.Exists(Item: Pointer): Boolean;
var
  Block: PItemArray;
begin
  Result := False;
  if (FCount > 0) then
  begin
    Block := FHead;
    while Assigned(Block) do
    begin
      if (Block^[0] = Item) then
      begin
        Result := True;
        Break;
      end;
      Block := Block^[1];
    end;
  end;
end;

{ TInDataList }

procedure TInDataList.Add(Item: Pointer);
begin
  if (FCount * POINTER_SIZE >= FLength) then
  begin
    Inc(FLength, POINTER_SIZE * ALLOCATE_COUNT);  // Ԥ�� n ��
    ReallocMem(FItems, FLength);
  end;
  FItems^[FCount] := Item;             // ռ��
  Inc(FCount);              
end;

procedure TInDataList.Clear;
begin
  ClearItems;
end;

procedure TInDataList.ClearItems;
begin
  FreeMem(FItems);
  FItems := nil;
  FCount := 0;
  FLength := 0;
end;

constructor TInDataList.Create;
begin
  inherited;
  FCount := 0;
  FLength := 0;
  FItems := nil;
end;

procedure TInDataList.SetCount(Value: Integer);
begin
  if (Value = 0) then
    Clear
  else begin
    FCount := Value;
    FLength := FCount * POINTER_SIZE;
    ReallocMem(FItems, FLength);
  end;
end;

procedure TInDataList.Delete(Index: Integer);
begin
  if (Index >= 0) and (Index < FCount) then
  begin
    Dec(FCount);    // ��ǰ
    if (FCount = 0) then
      ClearItems             
    else begin
      System.Move(FItems^[Index + 1], FItems^[Index],
                 (FCount - Index) * POINTER_SIZE);
      if (FLength > POINTER_SIZE * (FCount + ALLOCATE_COUNT)) then   // ����ռ�̫��
      begin
        FLength := POINTER_SIZE * (FCount + ALLOCATE_COUNT);
        ReallocMem(FItems, FLength);
      end;
    end;
  end;
end;

destructor TInDataList.Destroy;
begin
  if (FLength > 0) then
    Clear;
  inherited;
end;

function TInDataList.GetItems(Index: Integer): Pointer;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := FItems^[Index]
  else
    Result := Nil;
end;

procedure TInDataList.SetItems(Index: Integer; const Value: Pointer);
begin
  if (Index >= 0) and (Index < FCount) then
    FItems^[Index] := Value;
end;

function TInDataList.PopFirst: Pointer;
begin
  // ȡ��һ����ɾ��
  Result := GetItems(0);
  if (Result <> nil) then
    Delete(0);
end;

{ TInStringList }

procedure TInStringList.Add(const Key: AnsiString; Item: Pointer);
var
  pItem: PStringItem;
begin
  pItem := New(PStringItem);
  pItem^.FString := Key;  // ���ֽ�
  pItem^.FObject := Item;
  Inc(FSize, Length(pItem^.FString));
  inherited Add(pItem);
end;

procedure TInStringList.Add(const S: AnsiString);
var
  pItem: PStringItem;
begin
  pItem := New(PStringItem);
  pItem^.FString := S;   // ���ֽ�
  pItem^.FObject := nil;
  Inc(FSize, Length(pItem^.FString));
  inherited Add(pItem);
end;

procedure TInStringList.AddStrings(Strings: TInStringList);
var
  i: Integer;
  pItem: PStringItem;
begin
  // ����ʵ�֣�
  //   �� Strings �� TStringItem �ڵ��Ƶ���ǰ�б�
  //   �ٰ� Strings ������ռ������
  for i := 0 to Strings.FCount - 1 do
  begin
    pItem := Strings.GetItems(i);
    Inc(FSize, Length(pItem^.FString));
    inherited Add(pItem);
  end;
  TInDataList(Strings).ClearItems;
  Strings.FCount := 0;
end;

procedure TInStringList.Clear;
var
  i: Integer;
  pItem: PStringItem;
begin
  FSize := 0;
  for i := 0 to FCount - 1 do
  begin
    pItem := GetItems(i);
    if Assigned(pItem) then  // ���ܱ���Ϊ nil
      Dispose(pItem);
  end;
  inherited;
end;

procedure TInStringList.DeleteItem(Item: Pointer);
var
  i: Integer;
  pItem: PStringItem;
begin
  for i := 0 to FCount - 1 do
  begin
    pItem := GetItems(i);
    if (pItem^.FObject = Item) then
    begin
      Dec(FSize, Length(pItem^.FString));
      Dispose(pItem);
      inherited Delete(i);
      Break;
    end;
  end;
end;

procedure TInStringList.Delete(Index: Integer);
var
  pItem: PStringItem;
begin
  pItem := GetItems(Index);
  if Assigned(pItem) then
  begin
    Dec(FSize, Length(pItem^.FString));
    Dispose(pItem);
    inherited Delete(Index);
  end;
end;

function TInStringList.GetHttpString(Headers: Boolean): AnsiString;
var
  i, m: Integer;
  p: PAnsiChar;        // ��ָ�����
  pItem: PStringItem;
begin
  // �ϲ��б���ַ���
  //    Headers: True, ����س����з�

  // �����˫�ֽڣ��� Move ���Ʋ�����

  if Headers then     // ÿ�к�Ҫ�ӻس�����
    SetLength(Result, FSize + FCount * 2 + 2)
  else
    SetLength(Result, FSize);

  p := PAnsiChar(Result);
  
  for i := 0 to FCount - 1 do
  begin
    pItem := GetItems(i);

    m := Length(pItem^.FString);
    System.Move(pItem^.FString[1], p^, m);

    Inc(p, m);
    if Headers then  // �ӻس�������
    begin
      p^ := AnsiChar(CHAR_CR);
      (p + 1)^ := AnsiChar(CHAR_LF);
      Inc(p, 2);
    end;
  end;

  if Headers then
  begin
    p^ := AnsiChar(CHAR_CR);
    (p + 1)^ := AnsiChar(CHAR_LF);
  end;
end;

function TInStringList.GetJSON: AnsiString;
begin
  // ���б���ַ���תΪ JSON
  if (FSize > 0) then
    Result := GetJSONChunk(cpAll)
  else
    Result := '';
end;

function TInStringList.GetJSONChunk(Position: TJSONChunkPosition): AnsiString;
var
  p: PAnsiChar;
begin
  // ת���б� JSON �ֿ�

  if (FSize = 0) then
  begin
    Result := '';
    Exit;
  end;

  if (Position in [cpMiddle, cpLast]) then
  begin
    // ����ĩβ�� , �� ] 
    SetLength(Result, FSize + FCount);
    p := PAnsiChar(Result);
  end else
  begin
    // ������ʼ�� [ ��ĩβ�� ] �� ,
    SetLength(Result, FSize + FCount + 1);
    p := PAnsiChar(Result);
    p^ := '[';
    Inc(p);
  end;

  // �ϲ����ݣ��ָ���Ϊ ,
  p := UnionStrings(p, ',');

  if (Position in [cpAll, cpLast]) then
    p^ := AnsiChar(']')       // ĩ���ݿ飬�ӽ�����
  else
    p^ := AnsiChar(',');      // ��ǰ���м����ݿ飬�ӷָ���

end;

function TInStringList.GetDelimitedText: AnsiString;
begin
  if (FSize > 0) then
  begin
    SetLength(Result, FSize + FCount - 1);  // Ԥ��ռ�
    UnionStrings(@Result[1], ',');          // �� , �ָ�
  end;
end;

function TInStringList.GetObjects(Index: Integer): Pointer;
var
  pItem: PStringItem;
begin
  pItem := GetItems(Index);
  if Assigned(pItem) then
    Result := pItem^.FObject
  else
    Result := nil;
end;

function TInStringList.GetStrings(Index: Integer): AnsiString;
var
  pItem: PStringItem;
begin
  pItem := GetItems(Index);
  if Assigned(pItem) then
    Result := pItem^.FString;
end;

function TInStringList.GetText: AnsiString;
begin
  if (FSize > 0) then
  begin
    SetLength(Result, FSize + FCount - 1);  // Ԥ��ռ�
    UnionStrings(@Result[1], #32);          // �ÿո�ָ���SQL���
  end;
end;

function TInStringList.IndexOf(const Key: AnsiString; var Item: Pointer): Boolean;
var
  i: Integer;
  pItem: PStringItem;
begin
  for i := 0 to FCount - 1 do
  begin
    pItem := GetItems(i);
    if (pItem^.FString = Key) then
    begin
      Item := pItem^.FObject;
      Result := True;
      Exit;
    end;
  end;
  Item := Nil;
  Result := False;
end;

function TInStringList.IndexOf(const Key: AnsiString): Integer;
var
  i: Integer;
  pItem: PStringItem;
begin
  for i := 0 to FCount - 1 do
  begin
    pItem := GetItems(i);
    if (pItem^.FString = Key) then
    begin
      Result := i;
      Exit;
    end;
  end;
  Result := -1;
end;

function TInStringList.IndexOf(Item: Pointer): Integer;
var
  i: Integer;
  pItem: PStringItem;
begin
  for i := 0 to FCount - 1 do
  begin
    pItem := GetItems(i);
    if (pItem^.FObject = Item) then
    begin
      Result := i;
      Exit;
    end;
  end;
  Result := -1;
end;

procedure TInStringList.SaveToFile(const FileName: String);
var
  i: Integer;
  pItem: PStringItem;
  Stream: TStream;
begin
  // ·��������ʱ�쳣
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    for i := 0 to FCount - 1 do
    begin
      pItem := GetItems(i);
      Stream.Write(pItem^.FString[1], Length(pItem^.FString));
      Stream.Write(AnsiString(STR_CRLF)[1], 2);  // ��β�ӻس�����
    end;
  finally
    Stream.Free;
  end;
end;

procedure TInStringList.SetItems(Index: Integer; const Value: Pointer);
var
  pItem: PStringItem;
begin
  // ������Ϊ Nil�������ı�洢�ռ�
  pItem := GetItems(Index);
  if Assigned(pItem) then
  begin
    Dec(FSize, Length(pItem^.FString));
    Dispose(pItem);
    inherited;
  end;
end;

function TInStringList.UnionStrings(Buf: PAnsiChar; InterChr: AnsiChar): PAnsiChar;
var
  i, k: Integer;
  pItem: PStringItem;
begin
  // �ϲ��ַ�������Ԥ��ռ䣩
  // ��ʼ��ַ Buf���� InterChr �ָ�
  for i := 0 to FCount - 1 do
  begin
    pItem := GetItems(i);
    k := Length(pItem^.FString);

    // �����˫�ֽڣ��� Move ���Ʋ�����
    System.Move(pItem^.FString[1], Buf^, k);
    Inc(Buf, k);

    if (i < FCount - 1) then
    begin
      Buf^ := InterChr;     // �ӷָ���
      Inc(Buf);
    end;
  end;
  Result := Buf;
end;

procedure TInStringList.WriteLog(Handle: THandle);
var
  i: Integer;
  NoUsed: Cardinal;
  pItem: PStringItem;
begin
  // ���б�д����־�ļ�����β���س����У�
  //  Ϊ�����ڴ���䣬ֱ��д���̡�
  for i := 0 to FCount - 1 do
  begin
    pItem := GetItems(i);
    Windows.WriteFile(Handle, pItem^.FString[1], Length(pItem^.FString), NoUsed, nil);
    Windows.WriteFile(Handle, STR_CRLF[1], 2, NoUsed, nil); // �س�����
  end;
end;

end.
