object FormInIOCPStreamServer: TFormInIOCPStreamServer
  Left = 345
  Top = 290
  Caption = 'InIOCP '#25968#25454#27969#26381#21153
  ClientHeight = 408
  ClientWidth = 564
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #23435#20307
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  Scaled = False
  OnCreate = FormCreate
  PixelsPerInch = 120
  TextHeight = 12
  object Memo1: TMemo
    Left = 8
    Top = 230
    Width = 426
    Height = 160
    ImeName = #35895#27468#25340#38899#36755#20837#27861' 2'
    Lines.Strings = (
      'TInIOCPServer '#19981#24102#20219#20309#31649#29702#22120#65292#36825#26159#21407#22987#25968#25454#27969#26381#21153#12290
      #35831#29992' Socket '#36830#25509#12289#21457#36865#20219#20309#25968#25454#65292' '#21487#20197#29992#24037#20855#36719#20214' httptest.exe '#27979#35797#12290)
    TabOrder = 0
  end
  object btnStart: TButton
    Left = 453
    Top = 287
    Width = 75
    Height = 25
    Caption = #21551#21160
    TabOrder = 1
    OnClick = btnStartClick
  end
  object btnStop: TButton
    Left = 453
    Top = 328
    Width = 75
    Height = 25
    Caption = #20572#27490
    Enabled = False
    TabOrder = 2
    OnClick = btnStopClick
  end
  object Edit1: TEdit
    Left = 453
    Top = 246
    Width = 100
    Height = 20
    ImeName = #35895#27468#25340#38899#36755#20837#27861' 2'
    TabOrder = 3
    Text = '127.0.0.1'
  end
  inline FrameIOCPSvrInfo1: TFrameIOCPSvrInfo
    Left = 8
    Top = 16
    Width = 547
    Height = 201
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -15
    Font.Name = #23435#20307
    Font.Style = []
    ParentFont = False
    TabOrder = 4
    ExplicitLeft = 8
    ExplicitTop = 16
    ExplicitWidth = 547
    inherited Label3: TLabel
      Left = 326
      Width = 68
      Height = 15
      ExplicitLeft = 326
      ExplicitWidth = 68
      ExplicitHeight = 15
    end
    inherited lblWorkCount: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
    inherited lbl1: TLabel
      Left = 35
      Width = 68
      Height = 15
      ExplicitLeft = 35
      ExplicitWidth = 68
      ExplicitHeight = 15
    end
    inherited lbl12: TLabel
      Left = 326
      Width = 68
      Height = 15
      ExplicitLeft = 326
      ExplicitWidth = 68
      ExplicitHeight = 15
    end
    inherited lblAcceptExCount: TLabel
      Left = 16
      Width = 87
      Height = 15
      ExplicitLeft = 16
      ExplicitWidth = 87
      ExplicitHeight = 15
    end
    inherited lbl14: TLabel
      Left = 176
      Width = 68
      Height = 15
      ExplicitLeft = 176
      ExplicitWidth = 68
      ExplicitHeight = 15
    end
    inherited lbl16: TLabel
      Left = 26
      Width = 77
      Height = 15
      ExplicitLeft = 26
      ExplicitWidth = 77
      ExplicitHeight = 15
    end
    inherited lblMemeryUsed: TLabel
      Left = 326
      Width = 68
      Height = 15
      ExplicitLeft = 326
      ExplicitWidth = 68
      ExplicitHeight = 15
    end
    inherited lbl19: TLabel
      Left = 35
      Width = 68
      Height = 15
      ExplicitLeft = 35
      ExplicitWidth = 68
      ExplicitHeight = 15
    end
    inherited lbl3: TLabel
      Left = 50
      Width = 53
      Height = 15
      ExplicitLeft = 50
      ExplicitWidth = 53
      ExplicitHeight = 15
    end
    inherited lbl6: TLabel
      Left = 35
      Width = 68
      Height = 15
      ExplicitLeft = 35
      ExplicitWidth = 68
      ExplicitHeight = 15
    end
    inherited lblLeftEdge: TLabel
      Left = 11
      Width = 92
      Height = 15
      ExplicitLeft = 11
      ExplicitWidth = 92
      ExplicitHeight = 15
    end
    inherited lblAcceptExCnt: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
    inherited lblDataByteInfo: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
    inherited lblCheckTime: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
    inherited lblClientInfo: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
    inherited lblCliPool: TLabel
      Left = 50
      Width = 53
      Height = 15
      ExplicitLeft = 50
      ExplicitWidth = 53
      ExplicitHeight = 15
    end
    inherited lblDBConCount: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
    inherited lblIODataInfo: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
    inherited lblMemUsed: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
    inherited lblDataPackInf: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
    inherited lblStartTime: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
    inherited lblThreadInfo: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
    inherited lblWorkTimeLength: TLabel
      Width = 8
      Height = 15
      ExplicitWidth = 8
      ExplicitHeight = 15
    end
  end
  object InIOCPServer1: TInIOCPServer
    ServerAddr = '127.0.0.1'
    StartParams.TimeOut = 0
    ThreadOptions.BusinessThreadCount = 8
    ThreadOptions.PushThreadCount = 4
    ThreadOptions.WorkThreadCount = 4
    OnDataReceive = InIOCPServer1DataReceive
    OnDataSend = InIOCPServer1DataSend
    AfterOpen = InIOCPServer1AfterOpen
    AfterClose = InIOCPServer1AfterClose
    Left = 320
    Top = 272
  end
end
