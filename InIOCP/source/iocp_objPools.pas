(*
 * icop ����ء���ϣ���
 *)
unit iocp_objPools;

interface

{$I in_iocp.inc}

uses
  Windows, Classes, SysUtils,
  iocp_api, iocp_base, iocp_lists, iocp_utils,
  iocp_baseObjs;

type

  // ===================== �������� �� =====================

  // ��������صĻص�����
  TScanListEvent = procedure(ObjType: TObjectType; var FromObject: Pointer;
                             const Data: TObject; var CancelScan: Boolean) of object;

  TObjectPool = class(TObject)
  private
    FLock: TThreadLock;         // ��
    FObjectType: TObjectType;   // ��������

    FBuffer: Array of TLinkRec; // �Զ�������ڴ�� FBuffer
    FAutoAllocate: Boolean;     // �Զ����� FBuffer

    FFirstNode: PLinkRec;       // ��ǰ ���� ����
    FFreeNode: PLinkRec;        // ��ǰ ���� ����

    // ͳ������
    FIniCount: Integer;         // ��ʼ��С
    FNodeCount: Integer;        // ȫ���ڵ�������������
    FUsedCount: Integer;        // ���ýڵ�������������

    function AddNode: PLinkRec;
    function GetFull: Boolean;

    procedure CreateObjLink(ASize: Integer);
    procedure DeleteObjLink(var FirstNode: PLinkRec; FreeObject: Boolean);
    procedure DefaultFreeResources;
    procedure FreeNodeObject(ANode: PLinkRec);
  protected
    procedure CreateObjData(const ALinkNode: PLinkRec); virtual;
    procedure FreeListObjects(List: TInDataList);
    procedure OptimizeDetail(List: TInDataList);
  public
    constructor Create(AObjectType: TObjectType; ASize: Integer);
    destructor Destroy; override;
  public
    procedure Clear;
    function Pop: PLinkRec; overload; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure Push(const ANode: PLinkRec); {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure Lock; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure UnLock; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure Optimize; virtual;
    procedure Scan(var FromObject: Pointer; Callback: TScanListEvent);
  public
    property FirstNode: PLinkRec read FFirstNode;
    property Full: Boolean read GetFull;
    property IniCount: Integer read FIniCount;
    property NodeCount: Integer read FNodeCount;
    property ObjectType: TObjectType read FObjectType;
    property UsedCount: Integer read FUsedCount;
  end;

  // ====================== ���б�ĳ� �� ======================

  TDataListPool = class(TObjectPool)
  private
    FNodeList: TInDataList;   // ��Դ�ڵ��б�
  protected
    procedure CreateObjData(const ALinkNode: PLinkRec); override;
  public
    constructor Create(AObjectType: TObjectType; ASize: Integer);
    destructor Destroy; override;
  public
    procedure Optimize; override;
  end;

  // ====================== ����� Socket ���� �� ======================

  TIOCPSocketPool = class(TDataListPool)
  private
    FSocketClass: TClass;      // TBaseSocket ��
  protected
    procedure CreateObjData(const ALinkNode: PLinkRec); override;
  public
    constructor Create(AObjectType: TObjectType; ASize: Integer);
  public
    function Clone(Source: TObject): TObject;
    procedure GetSockets(List: TInList);
  end;

  // ===================== �ա����ڴ���� �� =====================

  TIODataPool = class(TDataListPool)
  protected
    procedure CreateObjData(const ALinkNode: PLinkRec); override;
  public
    constructor Create(ASize: Integer);
    destructor Destroy; override;
  end;

  // ====================== TStringHash �� ======================

  // �� Delphi 2007 �� TStringHash �޸�

  PHashItem  = ^THashItem;
  PPHashItem = ^PHashItem;
  
  THashItem = record
    Key: AnsiString;       // �õ��ֽ�
    Value: Pointer;        // �ģ����ָ��
    Next: PHashItem;
  end;

  TScanHashEvent = procedure(var Data: Pointer) of object;
  
  TStringHash = class(TObject)
  private
    FLock: TThreadLock;    // ������
    FCount: Integer;
    FBuckets: array of PHashItem;
    function Find(const Key: AnsiString): PPHashItem;
  protected
    function HashOf(const Key: AnsiString): Cardinal; virtual;
    procedure FreeItemData(Item: PHashItem); virtual;
  public
    constructor Create(Size: Cardinal = 256);
    destructor Destroy; override;

    function Modify(const Key: AnsiString; Value: Pointer): Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function ValueOf(const Key: AnsiString): Pointer; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function ValueOf2(const Key: AnsiString): Pointer; {$IFDEF USE_INLINE} inline; {$ENDIF}

    procedure Add(const Key: AnsiString; Value: Pointer); {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure Clear;
    procedure Lock; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure UnLock; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure Remove(const Key: AnsiString); {$IFDEF USE_INLINE} inline; {$ENDIF}

    procedure Scan(var Dest: Pointer; CallEvent: TScanListEvent); overload;
    procedure Scan(CallEvent: TScanHashEvent); overload;
  public
    property Count: Integer read FCount;
  end;

  // ================== ������ ���� ==================

  TPreventAttack = class(TStringHash)
  protected
    procedure FreeItemData(Item: PHashItem); override;
  public
    function CheckAttack(const PeerIP: String; MSecond, InterCount: Integer): Boolean;
    procedure DecRef(const PeerIP: String);
  end;
  
implementation

uses
  iocp_sockets;

type
  TBaseSocketRef = class(TBaseSocket);
  
{ TObjectPool }

function TObjectPool.AddNode: PLinkRec;
begin
  // �����½ڵ�, �ӵ���������
  Inc(FNodeCount);

  Result := New(PLinkRec);
  Result^.Auto := False;
  
  {$IFDEF DEBUG_MODE}
  Result^.No := FNodeCount;
  {$ENDIF}

  CreateObjData(Result);    // ����������

  Result^.Prev := Nil;
  Result^.Next := FFreeNode;
  if (FFreeNode <> Nil) then
    FFreeNode^.Prev := Result;

  FFreeNode := Result;
end;

procedure TObjectPool.Clear;
begin
  FLock.Acquire;
  try
    DefaultFreeResources;
  finally
    FLock.Release;
  end;
end;

constructor TObjectPool.Create(AObjectType: TObjectType; ASize: Integer);
begin
  inherited Create;
  FIniCount := ASize;
  FObjectType := AObjectType;
  FLock := TThreadLock.Create;
  CreateObjLink(ASize);
end;

procedure TObjectPool.CreateObjLink(ASize: Integer);
var
  i: Integer;
  PNode: PLinkRec;
begin
  // ������
  
  FFreeNode := nil;
  FFirstNode := Nil;
  
  FUsedCount := 0;
  FNodeCount := ASize;
  FAutoAllocate := ASize > 0;     // > 0 �Զ�����ڵ�ռ�

  if FAutoAllocate then
  begin
    // ����ڵ�ռ�
    SetLength(FBuffer, ASize);

    FFreeNode := @FBuffer[0];
    for i := 0 to ASize - 1 do    // ��˫����
    begin
      PNode := @FBuffer[i];       // 0...

      PNode^.Auto := True;        // �Զ�����
      PNode^.InUsed := False;

      {$IFDEF DEBUG_MODE}
      PNode^.No := i + 1;
      {$ENDIF}

      if (i = 0) then             // ��
        PNode^.Prev := Nil
      else
        PNode^.Prev := @FBuffer[i - 1];

      if (i < ASize - 1) then     // β
        PNode^.Next := @FBuffer[i + 1]
      else
        PNode^.Next := Nil;

      CreateObjData(PNode);      // ����������
    end;
  end;
end;

procedure TObjectPool.CreateObjData(const ALinkNode: PLinkRec);
begin
  // Empty
end;

procedure TObjectPool.DefaultFreeResources;
begin
  // Ĭ���ͷŷ��������������ͷŽڵ㼰��������
  if Assigned(FFirstNode) then
    DeleteObjLink(FFirstNode, True);

  if Assigned(FFreeNode) then
    DeleteObjLink(FFreeNode, True);

  if FAutoAllocate then
  begin
    SetLength(FBuffer, 0);
    FAutoAllocate := False;
  end;

  FNodeCount := 0;
  FUsedCount := 0;

end;

procedure TObjectPool.DeleteObjLink(var FirstNode: PLinkRec; FreeObject: Boolean);
var
  PToFree, PNode: PLinkRec;
begin
  // ɾ�� TopNode ������ռ估��������
  FLock.Acquire;
  try
    PNode := FirstNode;
    while (PNode <> Nil) do   // ��������
    begin
      if Assigned(PNode^.Data) then
        FreeNodeObject(PNode);
      PToFree := PNode;
      PNode := PNode^.Next;
      if (PToFree^.Auto = False) then    // �� AddNode() �����Ľڵ�
        Dispose(PToFree);
    end;
    FirstNode := nil;
  finally
    FLock.Release;
  end;
end;

destructor TObjectPool.Destroy;
begin
  DefaultFreeResources;
  FLock.Free;
  inherited;
end;

procedure TObjectPool.FreeListObjects(List: TInDataList);
var
  i: Integer;
  Node: PLinkRec;
begin
  // ������ͷŷ����������б��ͷŽڵ㼰��������
  for i := 0 to List.Count - 1 do
  begin
    Node := List.Items[i];
    if Assigned(Node) then
    begin
      if Assigned(Node^.Data) then
        FreeNodeObject(Node);
      if (Node^.Auto = False) then   // �� AddNode() �����Ľڵ�
        Dispose(Node);
    end;
  end;

  FFirstNode := nil;  // ��ֹ DefaultFreeResources �ظ��ͷ�����
  FFreeNode := nil;

  DefaultFreeResources;
end;

procedure TObjectPool.FreeNodeObject(ANode: PLinkRec);
begin
  // �ͷŽڵ� ANode �����Ķ���/�ڴ�ռ�
  case FObjectType of
    otEnvData:         // �ͻ��˹��������ռ�
      { ���ڴ��ͷ� } ;
    otTaskInf:         // ������������
      FreeMem(ANode^.Data);    
    otIOData: begin    // �շ��ڴ��
      FreeMem(PPerIOData(ANode^.Data)^.Data.buf);
      FreeMem(ANode^.Data);
    end;
    else  // ���� TBaseSocket
      TBaseSocket(ANode^.Data).Free;
  end;
  ANode^.Data := Nil;
end;

function TObjectPool.GetFull: Boolean;
begin
  // ��������Ƿ�����
  FLock.Acquire;
  try
    Result := FUsedCount >= FInICount;
  finally
    FLock.Release;
  end;
end;

procedure TObjectPool.Lock;
begin
  FLock.Acquire;
end;

function TObjectPool.Pop: PLinkRec;
begin
  // ���� ���� ����Ķ������뵽��������
  FLock.Acquire;
  try
    if (FFreeNode = nil) then
      Result := AddNode
    else
      Result := FFreeNode;

    // ��һ���нڵ�Ϊ��
    FFreeNode := FFreeNode^.Next;  // ��һ�ڵ�����
    if (FFreeNode <> Nil) then     // ��Ϊ�գ�ָ���
      FFreeNode^.Prev := Nil;

    // �� Result �� ���� ����
    Result^.Prev := nil;
    Result^.Next := FFirstNode;
    Result^.InUsed := True;

    if (FFirstNode <> Nil) then
      FFirstNode^.Prev := Result;
    FFirstNode := Result;  // Ϊ��

    Inc(FUsedCount);
  finally
    FLock.Release;
  end;
end;

procedure TObjectPool.Push(const ANode: PLinkRec);
begin
  // �� ����/���� ����� ANode ���뵽��������
  FLock.Acquire;
  try
    if ANode^.InUsed and (FUsedCount > 0) then
    begin
      // �� ���� �����жϿ� ANode
      if (ANode^.Prev = Nil) then  // �Ƕ�
      begin
        FFirstNode := ANode^.Next; // ��һ�ڵ�����
        if (FFirstNode <> Nil) then
          FFirstNode^.Prev := nil;
      end else
      begin  // �Ͻڵ����½ڵ�
        ANode^.Prev^.Next := ANode^.Next;
        if (ANode^.Next <> Nil) then  // ���ǵ�
          ANode^.Next^.Prev := ANode^.Prev;
      end;

      // ���뵽 ���� ����Ķ�
      ANode^.Prev := Nil;
      ANode^.Next := FFreeNode;
      ANode^.InUsed := False;

      if (FFreeNode <> Nil) then
        FFreeNode^.Prev := ANode;
      FFreeNode := ANode;  // �䶥

      Dec(FUsedCount);    // ֻ�ڴ˴� -
    end;
  finally
    FLock.Release;
  end;
end;

procedure TObjectPool.OptimizeDetail(List: TInDataList);
var
  i: Integer;
  PNode, PTail: PLinkRec;
  PFreeLink: PLinkRec;
  UsedNodes: TInDataList;
begin
  // �Ż���Դ���ָ�����ʼ��ʱ��״̬��
  // ���ͷŷ��Զ����ӵĽڵ� Auto = False��

  // �����������������Զ����ڵ������ -> �ͷ�

  FLock.Acquire;
  UsedNodes := TInDataList.Create;
  
  try
    PTail := nil;            // β
    PFreeLink := Nil;        // ������

    PNode := FFreeNode;      // ��ǰ�ڵ�
    while (PNode <> nil) do  // ������������
    begin
      if (PNode^.Auto = False) then
      begin
        // �ӿ��б����ѿ��ڵ� PNode
        if (PNode^.Prev = Nil) then  // �Ƕ�
        begin
          FFreeNode := PNode^.Next;  // ��һ�ڵ�����
          if (FFreeNode <> Nil) then
            FFreeNode^.Prev := nil;
        end else                     // �Ͻڵ����½ڵ�
        begin
          PNode^.Prev^.Next := PNode^.Next;
          if (PNode^.Next <> Nil) then // ���ǵ�
            PNode^.Next^.Prev := PNode^.Prev;
        end;

        // ������
        if (PFreeLink = nil) then
          PFreeLink := PNode
        else
          PTail^.Next := PNode;

        // ����β
        PTail := PNode;
        PTail^.InUsed := False;

        // ȡ��һ�ڵ�
        PNode := PNode^.Next;

        // �ں�
        PTail^.Next := nil;

        Dec(FNodeCount);
      end else
        PNode := PNode^.Next;
    end;

    if Assigned(List) then
    begin
      // �Ż������б�
      // ��������ʹ���еĽڵ��Ƶ� FIniCount λ��֮ǰ
      for i := FIniCount to List.Count - 1 do
      begin
        PNode := List.Items[i];
        if Assigned(PNode) and PNode^.InUsed then
          UsedNodes.Add(PNode);
      end;

      // UsedNodes �Ľڵ�ǰ��
      for i := 0 to UsedNodes.Count - 1 do
        List.Items[FIniCount + i] := UsedNodes.Items[i];

      // �����ڵ���
      List.Count := FNodeCount;
    end;
  finally
    UsedNodes.Free;
    FLock.Release;
  end;

  // �ͷ����� PFreeLink �Ľڵ���Դ

  while (PFreeLink <> Nil) do
  begin
    PNode := PFreeLink;
    PFreeLink := PFreeLink^.Next;
    if (PNode^.Data <> Nil) then
      FreeNodeObject(PNode);
    Dispose(PNode);
  end;
  
end;

procedure TObjectPool.Optimize;
begin
  OptimizeDetail(nil);    // �Ż���Դ���ָ�����ʼ��ʱ��״̬��
end;

procedure TObjectPool.Scan(var FromObject: Pointer; Callback: TScanListEvent);
var
  CancelScan: Boolean;
  PNode: PLinkRec;
begin
  // ���� ���� �������(����ǰҪ����)
  //  FromObject: һ��������ڴ濪ʼλ��
  CancelScan := False;
  PNode := FFirstNode;
  while (PNode <> Nil) and (CancelScan = False) do
  begin
    Callback(FObjectType, FromObject, PNode^.Data, CancelScan);
    PNode := PNode^.Next;
  end;
end;

procedure TObjectPool.UnLock;
begin
  FLock.Release;
end;

{ TDataListPool }

constructor TDataListPool.Create(AObjectType: TObjectType; ASize: Integer);
begin
  // ����һ����Դ�ڵ��б��ͷ�ʱ�ӿ��ٶ�
  FNodeList := TInDataList.Create;
  inherited;
end;

procedure TDataListPool.CreateObjData(const ALinkNode: PLinkRec);
begin
  FNodeList.Add(ALinkNode);  // �Ǽǵ��б�
end;

destructor TDataListPool.Destroy;
begin
  FreeListObjects(FNodeList);  // ���б�ɾ����Դ
  FNodeList.Free;
  inherited;
end;

procedure TDataListPool.Optimize;
begin
  OptimizeDetail(FNodeList);
end;

{ TIOCPSocketPool }

function TIOCPSocketPool.Clone(Source: TObject): TObject;
var
 Socket: TBaseSocketRef;
begin
  // ����һ�� TBaseSocket
  FLock.Acquire;
  try
    Socket := Pop^.Data;
    Socket.Clone(TBaseSocket(Source));
    Result := Socket;
  finally
    FLock.Release;
  end;
end;

constructor TIOCPSocketPool.Create(AObjectType: TObjectType; ASize: Integer);
begin
  case AObjectType of
    otBroker:        // ���� 
      FSocketClass := TSocketBroker;
    otSocket:        // TIOCPSocket
      FSocketClass := TIOCPSocket;
    otHttpSocket:    // THttpSocket
      FSocketClass := THttpSocket;
    otStreamSocket:  // TStreamSocket
      FSocketClass := TStreamSocket;
    otWebSocket:
      FSocketClass := TWebSocket;
    else
      raise Exception.Create('TBaseSocket ���ʹ���.');
  end;
  inherited;
end;

procedure TIOCPSocketPool.CreateObjData(const ALinkNode: PLinkRec);
begin
  inherited;
  // ����ڵ�� LinkNode.Data ���һ�� Socket ����,
  //   Socket.LinkNode ��¼����ڵ㣨˫���¼��������տռ䣩
  ALinkNode^.Data := TBaseSocketClass(FSocketClass).Create(Self, ALinkNode);
end;

procedure TIOCPSocketPool.GetSockets(List: TInList);
var
  PNode: PLinkRec;
begin
  // ����ʱ��ȡ���չ����ݵ�ȫ���ڵ�
  // �������͸�δͶ�� WSARecv �ɹ� Socket�������쳣��CPU ����
  FLock.Acquire;
  try
    PNode := FFirstNode;
    while (PNode <> Nil) do  // �������ñ�
    begin
      List.Add(PNode^.Data);
      PNode := PNode^.Next;
    end;
  finally
    FLock.Release;
  end;
end;

{ TIODataPool }

constructor TIODataPool.Create(ASize: Integer);
begin
  inherited Create(otIOData, ASize * 5); // 5 ������
end;

procedure TIODataPool.CreateObjData(const ALinkNode: PLinkRec);
var
  IOData: PPerIOData;
begin
  inherited;
  // ����ڵ�� LinkNode.Data ָ�� TPerIOData �ڴ��
  GetMem(ALinkNode^.Data, SizeOf(TPerIOData));

  IOData := PPerIOData(ALinkNode^.Data);
  IOData^.Node := ALinkNode;
  IOData^.Data.len := IO_BUFFER_SIZE;

  // �ڴ桢�����ڴ�Ҫ��ԣ������� out of memory��
  GetMem(IOData^.Data.buf, IO_BUFFER_SIZE);
end;

destructor TIODataPool.Destroy;
begin
  inherited;
end;

{ TStringHash }

procedure TStringHash.Add(const Key: AnsiString; Value: Pointer);
var
  Hash: Integer;
  Bucket: PHashItem;
begin
  FLock.Acquire;
  try
    Hash := HashOf(Key) mod Cardinal(Length(FBuckets));
    New(Bucket);
    Bucket^.Key := Key;
    Bucket^.Value := Value;
    Bucket^.Next := FBuckets[Hash];
    FBuckets[Hash] := Bucket;
    Inc(FCount);
  finally
    FLock.Release;
  end;
end;

procedure TStringHash.Clear;
var
  i: Integer;
  Prev, Next: PHashItem;
begin
  FLock.Acquire;
  try
    if (FCount > 0) then
      for i := 0 to Length(FBuckets) - 1 do
      begin
        Prev := FBuckets[i];
        FBuckets[i] := nil;
        while Assigned(Prev) do
        begin
          Next := Prev^.Next;
          FreeItemData(Prev);  // ����
          Dispose(Prev);
          Prev := Next;
          Dec(FCount);
        end;
      end;
  finally
    FLock.Release;
  end;
end;

constructor TStringHash.Create(Size: Cardinal);
begin
  SetLength(FBuckets, Size);
  FLock := TThreadLock.Create;  
end;

destructor TStringHash.Destroy;
begin
  Clear;
  FLock.Free;
  SetLength(FBuckets, 0);
  inherited Destroy;
end;

function TStringHash.Find(const Key: AnsiString): PPHashItem;
var
  Hash: Integer;
begin
  // Key �� AnsiString
  Hash := HashOf(Key) mod Cardinal(Length(FBuckets));
  Result := @FBuckets[Hash];
  while Result^ <> nil do
  begin
    if Result^.Key = Key then
      Exit
    else
      Result := @Result^.Next;
  end;
end;

procedure TStringHash.FreeItemData(Item: PHashItem);
begin
  // �ͷŽڵ����������
end;

function TStringHash.HashOf(const Key: AnsiString): Cardinal;
var
  i: Integer;
begin
  // Key �� AnsiString
  Result := 0;
  for i := 1 to Length(Key) do
    Result := ((Result shl 2) or (Result shr (SizeOf(Result) * 8 - 2))) xor Ord(Key[i]);
end;

procedure TStringHash.Lock;
begin
  FLock.Acquire;
end;

function TStringHash.Modify(const Key: AnsiString; Value: Pointer): Boolean;
var
  P: PHashItem;
begin
  FLock.Acquire;
  try
    P := Find(Key)^;
    if Assigned(P) then
    begin
      Result := True;
      P^.Value := Value;
    end else
      Result := False;
  finally
    FLock.Release;
  end;
end;

procedure TStringHash.Remove(const Key: AnsiString);
var
  P: PHashItem;
  Prev: PPHashItem;
begin
  FLock.Acquire;
  try
    Prev := Find(Key);
    P := Prev^;
    if Assigned(P) then
    begin
      Prev^ := P^.Next;   // �Ͽ� p
      FreeItemData(P);    // ����
      Dispose(P);         // ɾ�� p
      Dec(FCount);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TStringHash.Scan(var Dest: Pointer; CallEvent: TScanListEvent);
var
  i: Integer;
  P: PHashItem;
  CancelScan: Boolean;
begin
  // �����ڵ㣨Ҫ���ⲿ������
  //   ����TInClientManager.GetLoginedClients
  if (FCount > 0) then
  begin
    CancelScan := False;
    for i := 0 to Length(FBuckets) - 1 do
    begin
      P := FBuckets[i];
      while Assigned(P) do
      begin
        CallEvent(otEnvData, Dest, TObject(P^.Value), CancelScan);
        if CancelScan then
          Exit;
        P := P^.Next;
      end;
    end;
  end;
end;

procedure TStringHash.Scan(CallEvent: TScanHashEvent);
var
  i: Integer;
  Prev: PPHashItem;
  P: PHashItem;
begin
  // �����ڵ㣨Ҫ���ⲿ������
  if (FCount > 0) then
    for i := 0 to Length(FBuckets) - 1 do
    begin
      Prev := @FBuckets[i];
      P := Prev^;
      while Assigned(P) do
      begin
        if Assigned(CallEvent) then
          CallEvent(P^.Value);    // ���ö����ͷ� -> P^.Value = Nil
        if (P^.Value = Nil) then  // P^.Value = Nil �����ͷ�
        begin
          Dec(FCount);
          Prev^ := P^.Next;
          Dispose(P);             // �ͷŽڵ�ռ�
          P := Prev^;
        end else
        begin
          Prev := @P;
          P := P^.Next;
        end;
      end;
    end;
end;

procedure TStringHash.UnLock;
begin
  FLock.Release;
end;

function TStringHash.ValueOf(const Key: AnsiString): Pointer;
var
  P: PHashItem;
begin
  FLock.Acquire;
  try
    P := Find(Key)^;
    if Assigned(P) then
      Result := P^.Value
    else
      Result := Nil;
  finally
    FLock.Release;
  end;
end;

function TStringHash.ValueOf2(const Key: AnsiString): Pointer;
var
  P: PHashItem;
begin
  P := Find(Key)^;
  if Assigned(P) then
    Result := P^.Value
  else
    Result := Nil;
end;

{ TPreventAttack }

function TPreventAttack.CheckAttack(const PeerIP: String; MSecond, InterCount: Integer): Boolean;
var
  Item: PAttackInfo;
  TickCount: Int64;
begin
  // �����⹥��
  //   �����Ŀͻ������������࣬Ҳ��Ƶ��
  TickCount := GetUTCTickCount;
  Lock;
  try
    Item := Self.ValueOf2(PeerIP);
    if Assigned(Item) then
    begin
      // MSecond �����ڳ��� InterCount ���ͻ������ӣ�
      // ��������, 15 �����ڽ�ֹ����
      if (Item^.TickCount > TickCount) then  // ��������δ���
        Result := True
      else begin
        Result := (Item^.Count >= InterCount) and
                  (TickCount - Item^.TickCount <= MSecond);
        if Result then  // �ǹ���
          Item^.TickCount := TickCount + 900000  // 900 ��
        else
          Item^.TickCount := TickCount;
        Inc(Item^.Count);
      end;
    end else
    begin
      // δ�ظ����ӹ����Ǽ�
      Item := New(PAttackInfo);
      Item^.PeerIP := PeerIP;
      Item^.TickCount := TickCount;
      Item^.Count := 1;

      // ���� Hash ��
      Self.Add(PeerIP, Item);

      Result := False;
    end;
  finally
    UnLock;
  end;

end;

procedure TPreventAttack.DecRef(const PeerIP: String);
var
  Item: PAttackInfo;
begin
  // ���� IP ���ô���
  Lock;
  try
    Item := Self.ValueOf2(PeerIP);
    if Assigned(Item) and (Item^.Count > 0) then
      Dec(Item^.Count);
  finally
    UnLock;
  end;
end;

procedure TPreventAttack.FreeItemData(Item: PHashItem);
begin
  // �ͷŽڵ�ռ�
  Dispose(PAttackInfo(Item^.Value));
end;

end.


