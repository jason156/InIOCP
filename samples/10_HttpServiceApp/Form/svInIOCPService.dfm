object InIOCP_HTTP_Service: TInIOCP_HTTP_Service
  OldCreateOrder = False
  OnCreate = ServiceCreate
  DisplayName = 'InIOCP HTTP '#26381#21153
  OnContinue = ServiceStart
  OnPause = ServiceStop
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 286
  Width = 514
  object InIOCPServer1: TInIOCPServer
    HttpDataProvider = InHttpDataProvider1
    ServerAddr = 'localhost'
    ServerPort = 80
    StartParams.TimeOut = 0
    ThreadOptions.BusinessThreadCount = 8
    ThreadOptions.PushThreadCount = 4
    ThreadOptions.WorkThreadCount = 4
    Left = 56
    Top = 48
  end
  object InHttpDataProvider1: TInHttpDataProvider
    KeepAlive = True
    OnInvalidSession = InHttpDataProvider1InvalidSession
    RootDirectory = 'web_site'
    OnGet = InHttpDataProvider1Get
    OnPost = InHttpDataProvider1Post
    Left = 192
    Top = 48
  end
end
