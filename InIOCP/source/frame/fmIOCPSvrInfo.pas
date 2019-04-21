unit fmIOCPSvrInfo;

interface

{$I in_iocp.inc}        // ģʽ����

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, 
  Dialogs, ExtCtrls, StdCtrls, Grids, iocp_server;

type
  TFrameIOCPSvrInfo = class(TFrame)
    lbl1: TLabel;
    lblStartTime: TLabel;
    lblCliPool: TLabel;
    lblClientInfo: TLabel;
    lbl3: TLabel;
    lblIODataInfo: TLabel;
    lbl6: TLabel;
    lblThreadInfo: TLabel;
    lblLeftEdge: TLabel;
    lblDataPackInf: TLabel;
    lbl14: TLabel;
    lblDBConCount: TLabel;
    lbl16: TLabel;
    lblDataByteInfo: TLabel;
    lblMemeryUsed: TLabel;
    lblMemUsed: TLabel;
    lbl19: TLabel;
    lblWorkTimeLength: TLabel;
    bvl1: TBevel;
    lbl12: TLabel;
    lblCheckTime: TLabel;
    lblAcceptExCount: TLabel;
    lblAcceptExCnt: TLabel;
    Label3: TLabel;
    lblWorkCount: TLabel;
  private
    { Private declarations }
    FServer: TInIOCPServer;    // ������
    FTimer: TTimer;            // ������
    FRefreshCount: Cardinal;   // ˢ�´���
    FShowing: Boolean;         // �Ƿ���ǰ����ʾ
    procedure GetServerInfo(Sender: TObject);
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Start(AServer: TInIOCPServer);
    procedure Stop;
    property Showing: Boolean read FShowing write FShowing;
  end;

implementation

uses
  iocp_base, iocp_utils;

var
  FMaxInfo: TWorkThreadMaxInf; // ������ٶ�

{$R *.dfm}

{ TFrameIOCPSvrInfo }

constructor TFrameIOCPSvrInfo.Create(AOwner: TComponent);
begin
  inherited;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 1000;     // ���һ��
  FTimer.OnTimer := GetServerInfo;

  FShowing := True;
  lblStartTime.Caption := 'δ����';
end;

destructor TFrameIOCPSvrInfo.Destroy;
begin
  inherited;
end;

procedure TFrameIOCPSvrInfo.GetServerInfo(Sender: TObject);
var
  ActiveCount: Integer;
  CountA, CountB: Integer;
  CountC, CountD, CountE: Integer;
  WorkTotalCount: IOCP_LARGE_INTEGER;
  CheckTimeOut: TDateTime;
  ThreadSummary: TWorkThreadSummary;
begin
   // ����ֹͣ����ǰ�ˣ��������
  Inc(FRefreshCount, 1);  // ���� 1 ��
  if (FShowing = False) or (FServer.Active = False) then
    Exit;

  FTimer.Enabled := False;
  try

    // ��Ϊ��ɫ
    if (Tag = 0) then  
    begin
      Tag := 1;
      lblWorkTimeLength.Font.Color := clBlue;
      lblClientInfo.Font.Color := clBlue;
      lblWorkCount.Font.Color := clBlue;
      lblIODataInfo.Font.Color := clBlue;
      lblThreadInfo.Font.Color := clBlue;
      lblDataPackInf.Font.Color := clBlue;
      lblDataByteInfo.Font.Color := clBlue;
      lblCheckTime.Font.Color := clBlue;
      lblAcceptExCnt.Font.Color := clBlue;
      lblMemUsed.Font.Color := clBlue;
      lblDBConCount.Font.Color := clBlue;
    end;

    lblWorkTimeLength.Caption := GetTimeLengthEx(FRefreshCount);

    // 1. C/S��HTTP ģʽ��Socket �����������������=��ҵ���߳���
    FServer.GetClientInfo(CountA, CountB, CountC,
                          CountD, ActiveCount, WorkTotalCount);

    if Assigned(FServer.IOCPBroker) then  // ����ģʽ��Http�����͹���
      lblClientInfo.Caption := '�ܼ�:' + IntToStr(CountA + CountC) +
                               ',C/S:' + IntToStr(CountB) { ���ӵ� } +
                               ',�:' + IntToStr(ActiveCount) + '.' { ���е�ҵ��+������ }
    else
      lblClientInfo.Caption := '�ܼ�:' + IntToStr(CountA + CountC) +
                               ',C/S:' + IntToStr(CountB) { ���ӵ� } +
                               ',HTTP:' + IntToStr(CountD) { ���ӵ� } +
                               ',�:' + IntToStr(ActiveCount) + '.' { ���е�ҵ��+������ } ;

    lblWorkCount.Caption := IntToStr(WorkTotalCount);

    // 2. TPerIOData �أ�������C/S ʹ�á�HTTPʹ�á������б�ʹ��
    //    Socket �� RecvBuf �����գ����͵� TPerIOData ���գ����ԣ�
    //    CountA >= CountB + CountC + FServer.BusiWorkMgr.ThreadCount

    FServer.GetIODataInfo(CountA, CountB, CountC, CountD);

    if Assigned(FServer.IOCPBroker) then
      CountE := FServer.BusinessThreadCount * 2
    else
      CountE := FServer.BusinessThreadCount;

    if FServer.StreamMode then  // �� Http�����͹���
      lblIODataInfo.Caption := '�ܼ�:' + IntToStr(CountA) +
                               ',C/S:' + IntToStr(CountB) { ��� } +
                               ',������:' + IntToStr(CountE)
    else
      lblIODataInfo.Caption := '�ܼ�:' + IntToStr(CountA) +
                               ',C/S:' + IntToStr(CountB) { ��� } +
                               ',HTTP:' + IntToStr(CountC) { ��� } +
                               ',������:' + IntToStr(CountE) +
                               ',����:' + IntToStr(CountD) + '.';

    // 3. �߳�ʹ�ã������̡߳���ʱ��顢�ر��׽��֡�
    //              ҵ���̡߳������߳�(+1)�����
    FServer.GetThreadInfo(@ThreadSummary, CountA, CountB, CountC, CountD, CheckTimeOut);

    if FServer.StreamMode then  // ����ģʽ�����͹���
      lblThreadInfo.Caption := '�ܼ�:' + IntToStr(FServer.WorkThreadCount + CountA + CountC + 2) +
                               ',����:' + IntToStr(ThreadSummary.ActiveCount) { ��� } + '/' +
                                          IntToStr(FServer.WorkThreadCount) +
                               ',ҵ��:' + IntToStr(CountB) { ��� } + '/' + IntToStr(CountA) +
                               ',��ʱ:1,�ر�:1.'
    else
      lblThreadInfo.Caption := '�ܼ�:' + IntToStr(FServer.WorkThreadCount + CountA + CountC + 3) +
                               ',����:' + IntToStr(ThreadSummary.ActiveCount) { ��� } + '/' +
                                          IntToStr(FServer.WorkThreadCount) +
                               ',ҵ��:' + IntToStr(CountB) { ��� } + '/' + IntToStr(CountA) +
                               ',����:' + IntToStr(CountD) { ��� } + '/' + IntToStr(CountC) + '+1' +
                               ',��ʱ:1,�ر�:1.';    

    // 4. �����ٶ�(��/�룩
    if (ThreadSummary.PackInCount > FMaxInfo.MaxPackIn) then
      FMaxInfo.MaxPackIn := ThreadSummary.PackInCount;
    if (ThreadSummary.PackOutCount > FMaxInfo.MaxPackOut) then
      FMaxInfo.MaxPackOut := ThreadSummary.PackOutCount;

    lblDataPackInf.Caption := '�ܼ�:' + IntToStr(ThreadSummary.PackCount) + { '/' +
                                        IntToStr(FMaxInfo.MaxPackIn + FMaxInfo.MaxPackOut) + }
                              ',����:' + IntToStr(ThreadSummary.PackInCount) + '/' +
                                        IntToStr(FMaxInfo.MaxPackIn) +
                              ',����:' + IntToStr(ThreadSummary.PackOutCount) + '/' +
                                        IntToStr(FMaxInfo.MaxPackOut);


    // 5. �����ٶ�(�ֽ�/�룩
    if (ThreadSummary.ByteInCount > FMaxInfo.MaxByteIn) then
      FMaxInfo.MaxByteIn := ThreadSummary.ByteInCount;
    if (ThreadSummary.ByteOutCount > FMaxInfo.MaxByteOut) then
      FMaxInfo.MaxByteOut := ThreadSummary.ByteOutCount;

    lblDataByteInfo.Caption := '�ܼ�:' + GetTransmitSpeed(ThreadSummary.ByteCount {,
                                                          FMaxInfo.MaxByteIn + FMaxInfo.MaxByteOut } ) +
                               ',����:' + GetTransmitSpeed(ThreadSummary.ByteInCount, FMaxInfo.MaxByteIn) +
                               ',����:' + GetTransmitSpeed(ThreadSummary.ByteOutCount, FMaxInfo.MaxByteOut);

    // 6. ��ʱ���ʱ��
    if (CheckTimeOut > 0.1) then
      lblCheckTime.Caption := TimeToStr(CheckTimeOut);

    // 7. Socket Ͷ����, �ڴ�ʹ�����
    FServer.GetAcceptExCount(ActiveCount);

    lblAcceptExCnt.Caption := IntToStr(ActiveCount);
    lblMemUsed.Caption := GetTransmitSpeed(GetProcMemoryUsed);

    // 7.1 ��ģʵ����
    if (lblDBConCount.Caption = '-') and
      Assigned(TInIOCPServer(FServer).DatabaseManager) then
      lblDBConCount.Caption := IntToStr(CountA) + '*' +  // CountA δ�ı�
                               IntToStr(TInIOCPServer(FServer).DatabaseManager.DataModuleCount);

  finally
    // ������Ļ��ˢ��
    FTimer.Enabled := True;
  end;
end;

procedure TFrameIOCPSvrInfo.Start(AServer: TInIOCPServer);
begin
  FServer := AServer;
  FillChar(FMaxInfo, SizeOf(TWorkThreadMaxInf), 0);
  if not FServer.Active then
    FServer.Active := True;
  if FServer.Active then
  begin
    FRefreshCount := 0;
    lblStartTime.Font.Color := clBlue;
    lblStartTime.Caption := FormatDateTime('yyyy-mm-dd hh:mm:ss', Now);
    lblCheckTime.Caption := '';
    FTimer.Enabled := True;
  end;
end;

procedure TFrameIOCPSvrInfo.Stop;
begin
  if Assigned(FServer) then
  begin
    if FTimer.Enabled then
      FTimer.Enabled := False;
    if FServer.Active then
      FServer.Active := False;
    lblStartTime.Font.Color := clRed;
    lblStartTime.Caption := '����ֹͣ';
  end;
end;

end.
