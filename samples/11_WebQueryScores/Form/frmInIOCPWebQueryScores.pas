unit frmInIOCPWebQueryScores;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, iocp_sockets, iocp_managers, iocp_server,
  http_base, http_objects, fmIOCPSvrInfo;

type
  TFormInIOCPWebQueryScores = class(TForm)
    InIOCPServer1: TInIOCPServer;
    InHttpDataProvider1: TInHttpDataProvider;
    btnStart: TButton;
    btnStop: TButton;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    procedure FormCreate(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure InHttpDataProvider1Get(Sender: TObject; Request: THttpRequest;
      Respone: THttpRespone);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure InHttpDataProvider1Accept(Sender: TObject; Request: THttpRequest;
      var Accept: Boolean);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
  private
    { Private declarations }
    FAppDir: String;
    FWebSitePath: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPWebQueryScores: TFormInIOCPWebQueryScores;

implementation

uses
  iocp_log, iocp_utils, iocp_msgPacks, http_utils;

type

  // ׼��֤��
  TExamNumber = string[10];

  // �ɼ���¼
  PStudentScores = ^TStudentScores;
  TStudentScores = record
    ExamNo: TExamNumber;   // ׼��֤��
    Scores: AnsiString;    // JSON ��ʽ�ĳɼ���
  end;

  // �����ַ�������
  PThreadChars = ^TThreadChars;
  TThreadChars = array[0..2] of AnsiChar;

var
  // ��������
  FScores: array of TStudentScores;

procedure LoadFromTextFile(const FileName: string);
  procedure ExtractString(var Scores, LeftValue: AnsiString);
  var
    i: Integer;
  begin
    // ��ȡ�������
    i := Pos(#9, Scores);
    if (i > 0) then
    begin
      LeftValue := Copy(Scores, 1, i - 1);
      Delete(Scores, 1, i);
    end else
    begin
      LeftValue := Scores;
      Scores := '';
    end;
  end;
  procedure WriteData(const S: AnsiString; var ToBuf: PAnsiChar; ItemType: Integer);
  begin
    // д�ֶλ��ֶ�ֵ
    if (Length(S) > 0) then
    begin
      System.Move(S[1], ToBuf^, Length(S));
      Inc(ToBuf, Length(S));
    end;
    case ItemType of
      0:  // �ֶ�
        PThreadChars(ToBuf)^ := AnsiString('":"');
      1:  // ֵ
        PThreadChars(ToBuf)^ := AnsiString('","')
      else  // ����
        PThreadChars(ToBuf)^ := AnsiString('"}]');
    end;
    Inc(ToBuf, 3);  // ǰ�� 3 �ֽ�
  end;
var
  i: Integer;
  LeftVal, S: AnsiString;
  Student: PStudentScores;
  p: PAnsiChar;
  Strs: TStrings;
begin
  // ���� TAB �ָ����ı��ļ�����ɼ����������⣩
  // �ֶΣ�׼��֤��	����	����	��ѧ	�ܷ�	�ȼ�
  // JSON: [{"ExamNo":"123456789","name":"..","chinese":"80","maths":"90","total":"170","level":"AAAA"}]
  Strs := TStringList.Create;
  try
    Strs.LoadFromFile(FileName);

    // �������鳤�ȣ�ÿ��һ����¼��
    SetLength(FScores, Strs.Count);

    for i := 0 to Strs.Count - 1 do
    begin
      S := Trim(Strs[i]);
      if (Length(S) = 0) or (S[1] = '/') then  // Ϊ�ջ�ע��
        Continue;
        
      Student := @FScores[i];
      SetLength(Student^.Scores, Length(S) * 5);  // Ԥ�� JSON �ռ�
      p := PAnsiChar(Student^.Scores); // д��ĵ�ַ

      // ��ʼ
      PThreadChars(p)^ := AnsiString('[{"');
      Inc(p, 3);  // ǰ�� 3 �ֽ�

      // ���ݲ��࣬��һ��ȡ�ֶ����ݣ�����
      
      // 1. ׼��֤��
      WriteData('examNo', p, 0);
      ExtractString(S, LeftVal);

      Student^.ExamNo := LeftVal;
      WriteData(LeftVal, p, 1);

      // 2. ����
      WriteData('name', p, 0);
      ExtractString(S, LeftVal);
      WriteData(LeftVal, p, 1);

      // 3. ����
      WriteData('chinese', p, 0);
      ExtractString(S, LeftVal);
      WriteData(LeftVal, p, 1);

      // 4. ��ѧ
      WriteData('maths', p, 0);
      ExtractString(S, LeftVal);
      WriteData(LeftVal, p, 1);

      // 5. �ܷ�
      WriteData('total', p, 0);
      ExtractString(S, LeftVal);
      WriteData(LeftVal, p, 1);

      // 6. �ȼ�
      WriteData('level', p, 0);
      ExtractString(S, LeftVal);
      WriteData(LeftVal, p, 2);  // ����

      // ɾ������Ŀռ�
      Delete(FScores[i].Scores, Integer(p - PAnsiChar(FScores[i].Scores)) + 1, 999);
      
    end;
  finally
    Strs.Free;
  end;
end;

{$R *.dfm}

procedure TFormInIOCPWebQueryScores.btnStartClick(Sender: TObject);
begin
  iocp_log.TLogThread.InitLog;  // ������־

  // ���� TAB �ָ����ı��ļ�����ɼ�
  // �����������ɼ�������Թ̶����������ݿ⣬ֱ��ʹ�����鱣��ɼ���
  LoadFromTextFile(FWebSitePath + 'scores.txt');

  InIOCPServer1.Active := True;  // ��������
  FrameIOCPSvrInfo1.Start(InIOCPServer1);  // ��ʼͳ��
end;

procedure TFormInIOCPWebQueryScores.btnStopClick(Sender: TObject);
begin
  InIOCPServer1.Active := False;   // ֹͣ����
  FrameIOCPSvrInfo1.Stop;       // ֹͣͳ��
  iocp_log.TLogThread.StopLog;  // ֹͣ��־
  if (FScores <> nil) then  // �ͷ�����
    SetLength(FScores, 0);
end;

procedure TFormInIOCPWebQueryScores.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  btnStopClick(nil);
end;

procedure TFormInIOCPWebQueryScores.FormCreate(Sender: TObject);
begin
  FAppDir := ExtractFilePath(Application.ExeName); // ����·��
  FWebSitePath := FAppDir + AddBackslash(InHttpDataProvider1.RootDirectory);  // ��վ·��
  MyCreateDir(FAppDir + 'log');  // ��־·��
end;

procedure TFormInIOCPWebQueryScores.InHttpDataProvider1Accept(Sender: TObject;
  Request: THttpRequest; var Accept: Boolean);
begin
  // �ڴ��ж��Ƿ��������:
  //   Request.Method: ����
  //      Request.URI��·��/��Դ
  IF (Request.Method = hmGet) then
    Accept := True   // Request.URI = '/QueryScores';  // ����
  else
    Accept := False; // �ܾ�
end;

procedure TFormInIOCPWebQueryScores.InHttpDataProvider1Get(Sender: TObject;
  Request: THttpRequest; Respone: THttpRespone);
var
  i: Integer;
  ExamNo: TExamNumber;
  Scores: PStudentScores;
begin
  // Get: ��ѯ׼��֤�ţ����� JSON ���ݣ�����������������
  if (Request.URI = '/queryScores.do') then
  begin
    // ��ѯ�ɼ�
    ExamNo := Request.Params.AsString['exam_no'];
    if (Length(ExamNo) > 0) then
      for i := 0 to High(FScores) do
      begin
        Scores := @FScores[i];
        if (Scores^.ExamNo = ExamNo) then // �ҵ���¼
        begin
          Respone.SetContent(Scores^.Scores);  // ���� JSON �ɼ�
          Exit;
        end;
      end;
    // ���������ڣ�
    Respone.SetContent('NOT_EXISTS');
  end else
  if (Request.URI = '/return') then
  begin
    // �ض�λ
    Respone.Redirect('/');
  end else
  if (Request.URI = '/query.htm') then
  begin
    // ���ز�ѯҳ
    Respone.TransmitFile(FWebSitePath + 'query.htm');
  end else
  if (Request.URI = '/favicon.ico') then
  begin
    Respone.StatusCode := 204;  // û�ж���
  end else
  begin
    // ������ҳ
    Respone.TransmitFile(FWebSitePath + 'index.htm');
  end;
end;

procedure TFormInIOCPWebQueryScores.InIOCPServer1AfterOpen(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
end;

end.
