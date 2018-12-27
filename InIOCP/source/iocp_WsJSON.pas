(*
 * iocp WebSocket ������Ϣ JSON ��װ��Ԫ
 *)
unit iocp_WsJSON;

interface

{$I in_iocp.inc}

uses
  Windows, Classes, SysUtils, Variants, DB,
  iocp_base, iocp_msgPacks;

type

  // ˵�������Ǽ򵥵� JSON ��װ��ֻ֧�ֵ���¼��
   
  TCustomJSON = class(TBasePack)
  protected
    FUTF8CharSet: Boolean;     // UTF-8 �ַ���
  private
    function GetAsRecord(const Index: String): TCustomJSON;
    procedure SetAsRecord(const Index: String; const Value: TCustomJSON);
  protected
    // д�����ֶ�
    procedure WriteExtraFields(var Buffer: PAnsiChar); virtual;
    // ������ƵĺϷ���
    procedure CheckFieldName(const Value: AnsiString); override;
    // ������ݵĺϷ���
    procedure CheckStringValue(const Value: AnsiString); override;
    // ����������ڴ���
    procedure SaveToMemStream(Stream: TMemoryStream); override;
    // ɨ���ڴ�飬��������
    procedure ScanBuffers(ABuffer: PAnsiChar; ASize: Cardinal); override;
  public
    property B[const Name: String]: Boolean read GetAsBoolean write SetAsBoolean;
    property D[const Name: String]: TDateTime read GetAsDateTime write SetAsDateTime;
    property F[const Name: String]: Double read GetAsFloat write SetAsFloat;
    property I[const Name: String]: Integer read GetAsInteger write SetAsInteger;
    property I64[const Name: String]: Int64 read GetAsInt64 write SetAsInt64;
    property R[const Name: String]: TCustomJSON read GetAsRecord write SetAsRecord;  // ��¼
    property S[const Name: String]: String read GetAsString write SetAsString;
    property V[const Name: String]: Variant read GetAsVariant write SetAsVariant;  // �䳤
  end;

  TBaseJSON = class(TCustomJSON)
  protected
    FOwner: TObject;           // ����
    FAttachment: TStream;      // ������
    FMsgId: Int64;             // ��Ϣ Id
  private
    function GetAction: Integer;
    function GetHasAttachment: Boolean;
    procedure SetAction(const Value: Integer);
    procedure SetAttachment(const Value: TStream);
    procedure SetJSONText(const Value: AnsiString);    
  protected
    // д�����ֶ�
    procedure WriteExtraFields(var Buffer: PAnsiChar); override;
    // ɨ���ڴ�飬��������
    procedure ScanBuffers(ABuffer: PAnsiChar; ASize: Cardinal); override;    
  public
    constructor Create(AOwner: TObject);
    destructor Destroy; override;
    procedure Close; virtual;    
  public
    // Ԥ������
    property Action: Integer read GetAction write SetAction;
    property Attachment: TStream read FAttachment write SetAttachment;
    property HasAttachment: Boolean read GetHasAttachment;
    property MsgId: Int64 read FMsgId;
    property Owner: TObject read FOwner;
    property Text: AnsiString write SetJSONText;  // ֻд
    property UTF8CharSet: Boolean read FUTF8CharSet;
  end;

  // �����õ� JSON ��Ϣ
  
  TSendJSON = class(TBaseJSON)
  protected
    FDataSet: TDataSet;        // Ҫ���͵����ݼ�����������
    FFrameSize: Int64;         // ֡����
    FServerMode: Boolean;      // �����ʹ��
  private
    procedure InterSendDataSet(ASender: TObject);
    procedure SetDataSet(Value: TDataset);
  protected
    procedure InternalSend(ASender: TObject; AMasking: Boolean);
  protected
    property DataSet: TDataSet read FDataSet write SetDataSet;  // ����˹���
  public
    procedure Close; override;
  end;

implementation

uses
  iocp_Winsock2, iocp_lists, http_utils, iocp_utils, iocp_senders;
  
{ TCustomJSON }

procedure TCustomJSON.CheckFieldName(const Value: AnsiString);
var
  i: Integer;
begin
  inherited;
  for i := 1 to Length(Value) do
    if (Value[i] in ['''', '"', ':', ',', '{', '}']) then
      raise Exception.Create('�������Ʋ��Ϸ�.');
end;

procedure TCustomJSON.CheckStringValue(const Value: AnsiString);
begin
  if Pos('",', Value) > 0 then
    raise Exception.Create('���ݲ��ܴ���������.');
end;

function TCustomJSON.GetAsRecord(const Index: String): TCustomJSON;
var
  Stream: TStream;
begin
  // ��תΪ������תΪ TCustomJSON
  Stream := GetAsStream(Index);
  if Assigned(Stream) then
    try
      Result := TCustomJSON.Create;
      Result.Initialize(Stream);
    finally
      Stream.Free;
    end
  else
    Result := nil;
end;

procedure TCustomJSON.SaveToMemStream(Stream: TMemoryStream);
const
  BOOL_VALUES: array[Boolean] of string = ('False', 'True');
var
  i: Integer;
  S, JSON: AnsiString;
  p: PAnsiChar;
begin
  // ������Ϣ�� JSON �ı�����֧�����飩

  // 1. JSON ���� = ÿ�ֶζ༸���ַ������� +
  //                INIOCP_JSON_HEADER + JSON_CHARSET_UTF8 + MsgOwner
  SetLength(JSON, Integer(FSize) + FList.Count * 25 + 60);
  p := PAnsiChar(JSON);

  // 2. д�����ֶ�
  WriteExtraFields(p);

  // 3. �����б��ֶ�
  for i := 0 to FList.Count - 1 do
    with Fields[i] do
      case VarType of
        etNull:
          VarToJSON(p, Name, 'Null', True, False, i = FList.Count - 1);
        etBoolean:
          VarToJSON(p, Name, BOOL_VALUES[AsBoolean], True, False, i = FList.Count - 1);
        etCardinal..etInt64:
          VarToJSON(p, Name, AsString, True, False, i = FList.Count - 1);
        etDateTime:  // �����ַ���
          VarToJSON(p, Name, AsString, False, False, i = FList.Count - 1);
        etString:
          if FUTF8CharSet then
            VarToJSON(p, Name, System.AnsiToUtf8(AsString), False, False, i = FList.Count - 1)
          else
            VarToJSON(p, Name, AsString, False, False, i = FList.Count - 1);
        etRecord, etStream: begin  // ��������δ��
          // ���ܺ������������볤����Ϣ�����������������޷�ʶ��
          // "_Variant":{"Length":1234,"Data":"aaaa... ..."}
          if (VarType = etRecord) then
            S := '"' + Name + '":{"Length":' + IntToStr(Size) + ',"Record":'
          else
            S := '"' + Name + '":{"Length":' + IntToStr(Size) + ',"Data":"';

          System.Move(S[1], p^, Length(S));
          Inc(p, Length(S));

          // ֱ������д�룬���ٸ��ƴ���
          TStream(DataRef).Position := 0;
          TStream(DataRef).Read(p^, Size);
          Inc(p, Size);

          if (VarType = etRecord) then
          begin
            if (i = FList.Count - 1) then
              PDblChars(p)^ := AnsiString('}}')
            else
              PDblChars(p)^ := AnsiString('},');
            Inc(p, 2);
          end else
          begin
            if (i = FList.Count - 1) then
              PThrChars(p)^ := AnsiString('"}}')
            else
              PThrChars(p)^ := AnsiString('"},');
            Inc(p, 3);
          end;
        end;
      end;

  // 4. ɾ������ռ�
  Delete(JSON, p - PAnsiChar(JSON) + 1, Length(JSON));

  // 5. д����
  Stream.Write(JSON[1], Length(JSON));

end;

procedure TCustomJSON.ScanBuffers(ABuffer: PAnsiChar; ASize: Cardinal);

  function ExtractData(var p: PAnsiChar; var StreamType: Boolean): TMemoryStream;
  var
    Len: Integer;
    pa: PAnsiChar;
    S: AnsiString;
  begin
    // ��ȡ Variant �������ݣ���ʽ��
    //   {"Length":5,"Data":"abcde"}
    pa := nil;
    Result := nil;

    Len := 0;
    Inc(p, 8);  // �� : ǰ����

    repeat
      case p^ of
        ':':
          if (Len = 0) then  // ����λ��
            pa := p + 1
          else begin  // ����λ��
            Result := TMemoryStream.Create;
            StreamType := CompareBuffer(p - 6, '"Data"');
            if StreamType then // ��������
            begin
              Inc(p, 2);
              Result.Size := Len;
              System.Move(p^, Result.Memory^, Len);
              Inc(p, Len);
            end else
            begin  // �� JSON ��¼
              Inc(p);
              Result.Size := Len;
              System.Move(p^, Result.Memory^, Len);
              Inc(p, Len - 1);
            end;
            // ע��Result.Position := 0;
          end;
        ',': begin  // ȡ����
          SetString(S, pa, p - pa);
          Len := StrToInt(S);
        end;
      end;

      Inc(p);
    until (p^ = '}');

  end;

  procedure AddJSONField(const AName: String; AValue: AnsiString; StringType: Boolean);
  begin
    // ����һ������/�ֶ�
    if StringType then // DateTime Ҳ��Ϊ String
    begin
      if FUTF8CharSet then
        SetAsString(AName, System.UTF8Decode(AValue))
      else
        SetAsString(AName, AValue);
    end else
    if (AValue = 'True') then
      SetAsBoolean(AName, True)
    else
    if (AValue = 'False') then
      SetAsBoolean(AName, False)
    else
    if (AValue = 'Null') or (AValue = '""') or (AValue = '') then
      SetAsString(AName, '')
    else
    if (Pos('.', AValue) > 0) then  // ��ͨ����
      SetAsFloat(AName, StrToFloat(AValue))
    else
    if (Length(AValue) < 10) then  // 2147 4836 47
      SetAsInteger(AName, StrToInt(AValue))
    else
      SetAsInt64(AName, StrToInt64(AValue));
  end;

var
  Level: Integer;   // ���Ų��
  DblQuo: Boolean;  // ˫����
  WaitVal: Boolean; // �ȴ�ֵ
  p, pEnd: PAnsiChar;
  pD, pD2: PAnsiChar;

  FldName: String;
  FldValue: AnsiString;
  StreamType: Boolean;  // �Ƿ�Ϊ������
  Stream: TMemoryStream;
  JSONRec: TCustomJSON;
begin
  // ɨ��һ���ڴ棬������ JSON �ֶΡ��ֶ�ֵ
  // ��ȫ��ֵתΪ�ַ�������֧�����飬�����쳣��

  // �ȼ���ַ��������ִ�Сд
  p := PAnsiChar(ABuffer + Length(INIOCP_JSON_FLAG));
  FUTF8CharSet := SearchInBuffer(p, 50, JSON_CHARSET_UTF8);

  // ɨ�跶Χ
  p := ABuffer;
  pEnd := PAnsiChar(p + ASize);

  // ���ݿ�ʼ������λ��
  pD := nil;
  pD2 := nil;

  Level   := 0;      // ���
  DblQuo  := False;
  WaitVal := False;  // �ȴ��ֶ�ֵ

  // ��������ȡ�ֶΡ�ֵ

  repeat

(*  {"Id":123,"Name":"��","Boolean":True,"Stream":Null,
     "_Variant":{"Length":5,"Data":"aaaa"},"_zzz":2345}  *)

    case p^ of  // ���������˫���ź������ƻ����ݵ�һ����
      '{':
        if (DblQuo = False) then  // ������
        begin
          Inc(Level);
          if (Level > 1) then  // �ڲ㣬��� Variant ����
          begin
            DblQuo := False;
            WaitVal := False;
            Stream := ExtractData(p, StreamType);
            if StreamType then  // ������
              SetAsStream(FldName, Stream)  // ���� String������ CheckStringValue
            else begin
              // ��¼����
              JSONRec := TCustomJSON.Create;
              JSONRec.Initialize(Stream);
              SetAsRecord(FldName, JSONRec);
            end;
            Dec(Level);  // �����
          end;
        end;

      '"':  // ��㣺Level = 1
        if (DblQuo = False) then
          DblQuo := True
        else begin
          DblQuo := False;
          pD2 := p;
        end;

      ':':  // ���,���ţ�"Name":
        if (DblQuo = False) and (Level = 1) then
        begin
          WaitVal := True;
          SetString(FldName, pD, pD2 - pD);
          FldName := TrimRight(FldName);
          pD := nil;
          pD2 := nil;
        end;

      ',', '}':  // ֵ������xx,
        if WaitVal then  // Length(FldName) > 0
        begin
          if (pD2 = nil) then  // ǰ��û������
          begin
            SetString(FldValue, pD, p - pD);
            AddJSONField(FldName, Trim(FldValue), False);
          end else
          begin
            SetString(FldValue, pD, pD2 - pD);
            AddJSONField(FldName, FldValue, True);  // ��Ҫ Trim(FldValue)
          end;
          pD := nil;
          pD2 := nil;
          WaitVal := False;
        end;

      else
        if (DblQuo or WaitVal) and (pD = nil) then  // ���ơ����ݿ�ʼ
          pD := p;
    end;

    Inc(p);

  until (p >= pEnd);

  FUTF8CharSet := False;  // �Ѿ�ת��
  
end;

procedure TCustomJSON.SetAsRecord(const Index: String; const Value: TCustomJSON);
var
  Variable: TListVariable;
begin
  Variable.Data := Value;
  SetField(etRecord, Index, @Variable);
end;

procedure TCustomJSON.WriteExtraFields(var Buffer: PAnsiChar);
begin
  // �����ַ����ֶΣ�JSON_CHARSET_UTF8��JSON_CHARSET_DEF
  Buffer^ := AnsiChar('{');
  Inc(Buffer);
  if FUTF8CharSet then
    PInIOCPJSONField(Buffer)^ := JSON_CHARSET_UTF8
  else
    PInIOCPJSONField(Buffer)^ := JSON_CHARSET_DEF;
  Inc(Buffer, Length(JSON_CHARSET_UTF8) - 1);  // ����� " ��Ҫ
end;

{ TBaseJSON }

procedure TBaseJSON.Close;
begin
  // �رո�����
  if Assigned(FAttachment) then
  begin
    FAttachment.Free;
    FAttachment := nil;
  end;
end;

constructor TBaseJSON.Create(AOwner: TObject);
begin
  inherited Create;
  FOwner := AOwner;
  FMsgId := GetUTCTickCount;
end;

destructor TBaseJSON.Destroy;
begin
  Close;
  inherited;  // �Զ� Clear;
end;

function TBaseJSON.GetAction: Integer;
begin
  Result := GetAsInteger('__action');  // ��������
end;

function TBaseJSON.GetHasAttachment: Boolean;
begin
  Result := GetAsBoolean('__has_attach');  // �Ƿ������
end;

procedure TBaseJSON.ScanBuffers(ABuffer: PAnsiChar; ASize: Cardinal);
begin
  inherited;
  FOwner := TObject(GetAsInt64('__MSG_OWNER'));  // ��Ϣ��������д��
end;

procedure TBaseJSON.SetAction(const Value: Integer);
begin
  SetAsInteger('__action', Value);  // ��������
end;

procedure TBaseJSON.SetAttachment(const Value: TStream);
begin
  // ���ø���������һ�� __has_attach ����
  Close;  // �ͷ����е���
  FAttachment := Value;
  SetAsBoolean('__has_attach', Assigned(FAttachment) and (FAttachment.Size > 0));
end;

procedure TBaseJSON.SetJSONText(const Value: AnsiString);
begin
  // �� JSON �ı���ʼ��������
  if (FList.Count > 0) then
    Clear;
  if (Value <> '') then
    ScanBuffers(PAnsiChar(Value), Length(Value));
end;

procedure TBaseJSON.WriteExtraFields(var Buffer: PAnsiChar);
var
  S: AnsiString;
begin
  // д�븽����Ϣ
  
  // 1. ���� InIOCP ��־�ֶΣ�INIOCP_JSON_HEADER
  PInIOCPJSONField(Buffer)^ := INIOCP_JSON_FLAG;
  Inc(Buffer, Length(INIOCP_JSON_FLAG));

  // 2. �����ַ����ֶΣ�JSON_CHARSET_UTF8��JSON_CHARSET_DEF
  if FUTF8CharSet then
    PInIOCPJSONField(Buffer)^ := JSON_CHARSET_UTF8
  else
    PInIOCPJSONField(Buffer)^ := JSON_CHARSET_DEF;
  Inc(Buffer, Length(JSON_CHARSET_UTF8));

  // 3. ����������Ҫ��ȡ����д��
  S := '__MSG_OWNER":' + IntToStr(Int64(FOwner)) + ',';
  System.Move(S[1], Buffer^, Length(S));
  Inc(Buffer, Length(S));
  
end;

{ TSendJSON }

procedure TSendJSON.Close;
begin
  inherited;
  if Assigned(FDataSet) then
    FDataSet := nil;
end;

procedure TSendJSON.InternalSend(ASender: TObject; AMasking: Boolean);
var
  oSender: TBaseTaskSender;
  JSON: TMemoryStream;
begin
  // ��������

  if (FList.Count = 0) then
    Exit;

  // ������
  oSender := TBaseTaskSender(ASender);
  oSender.Masking := AMasking;

  // ת���� JSON ��
  JSON := TMemoryStream.Create;

  SaveToStream(JSON, True);  // �Զ����������
  
  FFrameSize := JSON.Size;
  oSender.OpCode := ocText;  // JSON �����ı������ܸ�
  oSender.Send(JSON, FFrameSize, True);  // �Զ��ͷ�

  // ���� ����
  if Assigned(FAttachment) then
    try
      FFrameSize := FAttachment.Size;
      if (FFrameSize = 0) then
        FAttachment.Free   // ֱ���ͷ�
      else begin
        if (FServerMode = False) then
          Sleep(5);
        oSender.OpCode := ocBiary;  // ���� ���������ƣ����ܸ�
        oSender.Send(FAttachment, FFrameSize, True);  // �Զ��ͷ�
      end;
    finally
      FAttachment := nil;  // �Ѿ��ͷ�
    end
  else
  if Assigned(FDataSet) then
    try
      if (FServerMode = False) then
        Sleep(5);
      InterSendDataSet(oSender);
    finally
      FDataSet.Active := False;
      FDataSet := nil;
    end;

  // ����Ͷ��ʱ������˿��ܼ�����Ϣճ����һ��Win7 64 λ���׳��֣���
  // �½����쳣�������Ϣ������
  if (FServerMode = False) then
    Sleep(15);

end;

procedure TSendJSON.InterSendDataSet(ASender: TObject);
  function CharSetText(const S: AnsiString): AnsiString; // {$IFDEF USE_INLINE} inline; {$ENDIF}
  begin
    if FUTF8CharSet then  // UTF-8 �ַ���
      Result := System.UTF8Encode(S)
    else
      Result := S;
  end;

  procedure MarkFrameSize(AData: PWsaBuf; AFrameSize: Integer; ALastFrame: Byte);
  var
    pb: PByte;
  begin
    // ����ˣ����� WebSocket ֡��Ϣ
    //   ���� RSV1/RSV2/RSV3
    pb := PByte(AData^.buf);
    pb^ := ALastFrame + Byte(ocBiary);  // �к��֡����λ = 0��������
    Inc(pb);

    pb^ := 126;  // �� 126���ͻ��˴� 3��4�ֽ�ȡ����
    Inc(pb);

    TByteAry(pb)[0] := TByteAry(@AFrameSize)[1];
    TByteAry(pb)[1] := TByteAry(@AFrameSize)[0];

    // �������ݳ���
    AData^.len := AFrameSize + 4;
  end;

var
  oSender: TBaseTaskSender;
  XData: PWsaBuf;  // ���ռ�

  i, k, n, m, Idx: integer;
  EmptySize, Offset: Integer;
  p: PAnsiChar;

  Desc, JSON: AnsiString;
  Names: TStringAry;
  Field: TField;

begin
  // ���ٰ����ݼ�תΪ JSON������ Blob �ֶ����ݣ�
  // ע�⣺��������������ÿ�ֶγ��Ȳ��ܳ��� IO_BUFFER_SIZE

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

    // 2. ÿ����¼תΪ JSON��������ʱ����

    oSender := TBaseTaskSender(ASender);
    XData := oSender.Data;   // �����������ռ�

    // ���鿪ʼ��֡���� 4 �ֽ�
    (XData.buf + 4)^ := AnsiChar('[');

    EmptySize := IO_BUFFER_SIZE - 5;  // �ռ䳤��
    Offset := 5;  // д��λ��

    while not Dataset.Eof do
    begin
      SetLength(JSON, n);    // Ԥ���¼�ռ�
      p := PAnsiChar(JSON);
      Idx := 0;              // ���ݵ�ʵ�ʳ���

      // ��¼ -> JSON
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


      Inc(Idx);  // ��¼��������� , �� ]
      Delete(JSON, Idx + 1, n - Idx);   // ɾ����������

      // �ռ䲻�� -> �ȷ�������д������
      if (Idx > EmptySize) then
      begin
        MarkFrameSize(XData, Offset - 4, 0);  // ����֡��Ϣ
        oSender.SendBuffers;  // ���̷��ͣ�

        EmptySize := IO_BUFFER_SIZE - 4; // ��ԭ
        Offset := 4;  // ��ԭ
      end;
      
      // ��һ����¼
      Dataset.Next;
      
      // ���� JSON���´���ʱ����
      if Dataset.Eof then
        JSON[Idx] := AnsiChar(']')  // ������
      else
        JSON[Idx] := AnsiChar(','); // δ����

      System.Move(JSON[1], (XData.buf + Offset)^, Idx);
      Dec(EmptySize, Idx); // �ռ�-
      Inc(Offset, Idx);    // λ��+      
      
    end;

    // �������һ֡
    if (Offset > 4) then
    begin
      MarkFrameSize(XData, Offset - 4, Byte($80));  // ����֡��Ϣ
      oSender.SendBuffers;  // ���̷��ͣ�
    end;

  finally
    Dataset.EnableControls;
  end;

end;

procedure TSendJSON.SetDataSet(Value: TDataset);
begin
  Close;  // �ر����и���
  FDataSet := Value;
  SetAsBoolean('__has_attach', Assigned(Value) and Value.Active and not Value.IsEmpty);
end;

end.
