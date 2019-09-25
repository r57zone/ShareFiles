unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ScktComp, StdCtrls, XPMan, ComCtrls, ShellAPI, ExtCtrls, IniFiles;

type
  TMain = class(TForm)
    ClientSocket: TClientSocket;
    ServerSocket: TServerSocket;
    XPManifest: TXPManifest;
    ProgressBar: TProgressBar;
    StatusBar: TStatusBar;
    DragAndDropImage: TImage;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ClientSocketRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientSocketError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure StatusBarClick(Sender: TObject);
    procedure ClientSocketDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ServerSocketClientConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ServerSocketClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure ServerSocketClientError(Sender: TObject;
      Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
      var ErrorCode: Integer);
  protected
    procedure WMDropFiles (var Msg: TMessage); message wm_DropFiles;
  private
    procedure AddDir(FolderPath: string);
    procedure AddFile(FilePath: string);
    procedure Send;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Main: TMain;
  LastRequest, LastFile, LocalPath, CurPath, Address:string;
  FileList, AllwLs: TStringList;
  SendFilesCount, SendedFilesCount: int64;
  RcvFlsRep: integer;
  AlwRcvFls: boolean;
  BreakAll, Receive: boolean;
  FSize, ReceiveFilesCount, ReceivedFilesCount: int64;
  FStream: TFileStream;

  ID_ENTER_IP, ID_CONNECT, ID_ALLOW_CONNECTION, ID_NOT_ALLOW_RECEIVE_FILES,
  ID_FAIL_CONNECT, ID_CONNECTION_LOST, ID_SEND_FILES, ID_SEND_FILES_ABORTED,
  ID_RECEIVE_FILES, ID_SUCCESS_RECEIVED_FILES, ID_SUCCESS_SENDED_FILES: string;
  ID_ABOUT_TITLE, ID_LAST_UPDATE: string;

implementation

{$R *.dfm}

function GetFileSize(const FileName: string): int64;
var
  SearchFile: TSearchRec;
begin
   FindFirst(FileName, faAnyFile, SearchFile);
   Result:=(int64(SearchFile.FindData.nFileSizeHigh) * MAXDWORD) + int64(SearchFile.FindData.nFileSizeLow);
   FindClose(SearchFile);
end;

function GetLocaleInformation(Flag: integer): string;
var
  pcLCA: array [0..20] of Char;
begin
  if GetLocaleInfo(LOCALE_SYSTEM_DEFAULT, Flag, pcLCA, 19)<=0 then
    pcLCA[0]:=#0;
  Result:=pcLCA;
end;

procedure TMain.FormCreate(Sender: TObject);
var
  Ini: TIniFile;
begin
  //Перевод
  if FileExists(ExtractFilePath(ParamStr(0)) + 'Languages\' + GetLocaleInformation(LOCALE_SENGLANGUAGE) + '.ini') then
    Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Languages\' + GetLocaleInformation(LOCALE_SENGLANGUAGE) + '.ini')
  else
    Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Languages\English.ini');
  ID_ENTER_IP:=Ini.ReadString('Main', 'ID_ENTER_IP', '');
  ID_CONNECT:=Ini.ReadString('Main', 'ID_CONNECT', '');
  ID_ALLOW_CONNECTION:=Ini.ReadString('Main', 'ID_ALLOW_CONNECTION', '');
  ID_NOT_ALLOW_RECEIVE_FILES:=Ini.ReadString('Main', 'ID_NOT_ALLOW_RECEIVE_FILES', '');
  ID_FAIL_CONNECT:=Ini.ReadString('Main', 'ID_FAIL_CONNECT', '');
  ID_CONNECTION_LOST:=Ini.ReadString('Main', 'ID_CONNECTION_LOST', '');
  ID_SEND_FILES:=Ini.ReadString('Main', 'ID_SEND_FILES', '');
  ID_SEND_FILES_ABORTED:=Ini.ReadString('Main', 'ID_SEND_FILES_ABORTED', '');
  ID_RECEIVE_FILES:=Ini.ReadString('Main', 'ID_RECEIVE_FILES', '');
  ID_SUCCESS_RECEIVED_FILES:=Ini.ReadString('Main', 'ID_SUCCESS_RECEIVED_FILES', '');
  ID_SUCCESS_SENDED_FILES:=Ini.ReadString('Main', 'ID_SUCCESS_SENDED_FILES', '');
  ID_ABOUT_TITLE:=Ini.ReadString('Main', 'ID_ABOUT_TITLE', '');
  ID_LAST_UPDATE:=Ini.ReadString('Main', 'ID_LAST_UPDATE', '');
  Ini.Free;

  //Проверка на повторый запуск
  if FindWindow('TMain', 'eFile') <> 0 then begin
    SetForegroundWindow(FindWindow('TMain', 'eFile'));
    Halt;
  end;
  Caption:='eFile';
  Application.Title:=Caption;

  //Адрес передачи по умолчанию
  Address:=ParamStr(1);

  Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Setup.ini');
  ClientSocket.Port:=Ini.ReadInteger('Main', 'Port', 5371);
  ServerSocket.Port:=Ini.ReadInteger('Main', 'Port', 5371);
  CurPath:=Ini.ReadString('Main', 'Path', '');
  if Trim(CurPath) = '' then
    CurPath:=GetEnvironmentVariable('USERPROFILE') + '\Desktop\';
  Ini.Free;

  if FileExists(ExtractFilePath(ParamStr(0)) + 'Allow.txt') then begin
    AllwLs:=TStringList.Create;
    AllwLs.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'Allow.txt');
  end;

  DragAcceptFiles(Main.Handle,true);
  FileList:=TStringList.Create;
  ServerSocket.Active:=true;
end;

procedure TMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if Assigned(AllwLs) then AllwLs.Free;
  FileList.Free;
  if ClientSocket.Active then
    ClientSocket.Active:=false;
  if ServerSocket.Active then
    ServerSocket.Active:=false;
end;

procedure TMain.WMDropFiles(var Msg: TMessage);
var
  i, Amount, Size: integer;
  FileName: PChar;
  RunOnce: boolean;
begin
  if Trim(Address)='' then
    InputQuery(Caption, ID_ENTER_IP, Address);

  if Trim(Address)='' then
    BreakAll:=true;

  ClientSocket.Host:=Address;
  StatusBar.SimpleText:=' ' + ID_CONNECT;
  if ClientSocket.Active = false then
    ClientSocket.Active:=true;

  BreakAll:=false;
  FileList.Clear;
  SendFilesCount:=0;
  RunOnce:=false;

  //Ждем разрешения на передачу файлов
  while RcvFlsRep <> 1 do begin
    if (RcvFlsRep = 2) or (RcvFlsRep = 3) then begin
      BreakAll:=true;
      Break;
    end;
    Application.ProcessMessages;
  end;

  case RcvFlsRep of
    2: StatusBar.SimpleText:=' ' + ID_NOT_ALLOW_RECEIVE_FILES;
    3: StatusBar.SimpleText:=' ' + ID_FAIL_CONNECT;
  end;

  //В случае отмены или неудачи выходим
  if BreakAll then
    Exit;

  ProgressBar.Visible:=true;

  //Обработка Drag & Drop
  inherited;
  Amount:=DragQueryFile(Msg.WParam, $FFFFFFFF, FileName, 255);
  for i:=0 to Amount - 1 do begin
    Size:=DragQueryFile(Msg.WParam, i, nil, 0) + 1;
    FileName:=StrAlloc(Size);
    DragQueryFile(Msg.WParam, i, FileName, Size);

    //В случае отмены или неудачи выходим
    if BreakAll then
      Exit;

    //Узнаем папку передаваемых файлов
    if RunOnce = false then begin
      LocalPath:=ExtractFilePath(StrPas(FileName));
      RunOnce:=true;
    end;

    if Length(ExtractFilePath(StrPas(FileName))) < Length(LocalPath) then
      LocalPath:=ExtractFilePath(StrPas(FileName));

    if FileExists(StrPas(Filename)) then
      AddFile(StrPas(Filename))
    else if DirectoryExists(StrPas(Filename)) then
      AddDir(StrPas(Filename));

    StrDispose(Filename);
  end;

  DragFinish(Msg.WParam);

  //Считаем количество файлов
  for i:=0 to FileList.Count - 1 do
    if Copy(FileList.Strings[i], 1, 5) = 'FILE ' then Inc(SendFilesCount);

  //Отправляем количество файлов
  LastRequest:='%FILES_COUNT ' + IntToStr(SendFilesCount) + '%';
  ClientSocket.Socket.SendText(LastRequest);
end;

procedure TMain.ClientSocketRead(Sender: TObject;
  Socket: TCustomWinSocket);
var
  RcvText: string;
begin
  RcvText:=Socket.ReceiveText;

  //Последний запрос, в случае неудачной отправки или приема можно запросить повторно
  if Pos('%LAST_REQUEST%', RcvText) > 0 then
    Socket.SendText(LastRequest);

  if Pos('%SUCESS_FILE%', RcvText) > 0 then begin
    Send;
    Inc(SendedFilesCount);
  end;

  if Pos('%SUCESS_DIR%', RcvText) > 0 then
    Send;

  if Pos('%FILES_COUNT_OK%', RcvText) > 0 then
    Send;

  if Pos('%FILES_ALLOW_OK%', RcvText) > 0 then begin
    RcvFlsRep:=1;
    SendedFilesCount:=0;
  end;

  //Команда на отправку файла
  if Pos('%SEND%', RcvText) > 0 then begin
    ProgressBar.Position:=0;
    ProgressBar.Visible:=true;
    StatusBar.SimpleText:=Format(' ' + ID_SEND_FILES, [SendedFilesCount, SendFilesCount]);
    ClientSocket.Socket.SendStream(TFileStream.Create(LastFile, fmOpenRead or fmShareDenyWrite));
  end;

  if (RcvText[1] = '%') and (RcvText[Length(RcvText)] = '%') then begin
    if Copy(RcvText, 1, 14) = '%PROGRESS_BAR ' then begin
      Delete(RcvText, 1, 14);
      RcvText:=Copy(RcvText, 1, Pos('%', RcvText) - 1);
      ProgressBar.Position:=StrToIntDef(RcvText, 0);
    end;
  end;
end;

procedure TMain.ClientSocketError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  BreakAll:=true;
  case ErrorCode of
    10061: StatusBar.SimpleText:=' ' + ID_FAIL_CONNECT;
  else
    StatusBar.SimpleText:=' ' + ID_CONNECTION_LOST;
  end;
  RcvFlsRep:=3;
  ErrorCode:=0;
end;

procedure TMain.StatusBarClick(Sender: TObject);
begin
  Application.MessageBox(PChar(Caption + ' 0.7.2' + #13#10 +
  ID_LAST_UPDATE + ': 25.09.2018' + #13#10 +
  'https://r57zone.github.io' + #13#10 +
  'r57zone@gmail.com'), PChar(ID_ABOUT_TITLE), MB_ICONINFORMATION);
end;

procedure TMain.ClientSocketDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  RcvFlsRep:=3;
end;

procedure TMain.ServerSocketClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  //Разрешаем только одно подключение
  if ServerSocket.Socket.ActiveConnections = 1 then begin
    AlwRcvFls:=false;
    FStream:=nil;
    BreakAll:=false;
    Receive:=false;
    ReceivedFilesCount:=0;

  //Проверяем есть ли в списке "Allow.txt" адрес, чтобы не запрашивать подверждение
  if (Assigned(AllwLs)) and (Pos(Socket.RemoteAddress, AllwLs.Text) > 0) then begin
    AlwRcvFls:=true;
    ServerSocket.Socket.Connections[0].SendText('%FILES_ALLOW_OK%');
  end else
    case MessageBox(Handle, PChar(ID_ALLOW_CONNECTION + ' ' + Socket.RemoteHost + ' ' + Socket.RemoteAddress), PChar(Caption), 35) of
      6: begin
          AlwRcvFls:=true;
          ServerSocket.Socket.Connections[0].SendText('%FILES_ALLOW_OK%');
        end;
      7: Socket.Close;
      2: Socket.Close;
    end;
  end else
    Socket.Close;
end;

//Количество символов в строке
function CountCharStr(Symb: Char; Str: string): integer;
var
  i: integer;
begin
  Result:=0;
  for i:=1 to Length(Str) do
    if Str[i] = Symb then
      Result:=Result + 1;
end;

procedure TMain.ServerSocketClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
var
  LengthFile: integer;
  BufferFile: Pointer;
  FName, RcvText: string;
begin
  //В случае отмены или неудачи выходим
  if BreakAll then begin
    Receive:=false;
    FStream.Free;
    ProgressBar.Visible:=false;
    StatusBar.SimpleText:=' ' + ID_SEND_FILES_ABORTED;
    Exit;
  end;

  //Получение файла
  if Receive then begin
    StatusBar.SimpleText:=Format(' ' + ID_RECEIVE_FILES, [ReceivedFilesCount, ReceiveFilesCount]);
    LengthFile:=Socket.ReceiveLength;
    GetMem(BufferFile, LengthFile);
    try
      Socket.ReceiveBuf(BufferFile^, LengthFile);
      FStream.Write(BufferFile^, LengthFile);
      ProgressBar.Position:=(FStream.Size * 100) div FSize;
      Socket.SendText('%PROGRESS_BAR ' + IntToStr(ProgressBar.Position) + '%');

      if FStream.Size = FSize then begin //Завершаем если размер соответствует размеру оригигала
        Receive:=false;
        FStream.Free;
        Socket.SendText('%SUCESS_FILE%');
        Inc(ReceivedFilesCount);
        if (ReceiveFilesCount = ReceivedFilesCount) then begin
          StatusBar.SimpleText:=' ' + ID_SUCCESS_RECEIVED_FILES;
          ReceivedFilesCount:=0;
          ProgressBar.Visible:=false;
          ProgressBar.Position:=0;
        end;
      end;
    finally
      FreeMem(BufferFile);
    end;

  end else begin
    //Приём команд
    RcvText:=Socket.ReceiveText;

    if (RcvText[1] = '%') and (RcvText[Length(RcvText)] = '%') and (CountCharStr('%', RcvText) = 2) then begin

      //Создание папки
      if Copy(RcvText, 1, 5) = '%DIR ' then begin
        Delete(RcvText, 1, 5);
        FName:=Copy(RcvText, 1, Pos('%', RcvText) - 1);
        if not (DirectoryExists(CurPath + '\' + FName)) then
          CreateDir(CurPath + '\' + FName);
        Socket.SendText('%SUCESS_DIR%');
      end;

      //Создание файла
      if Copy(RcvText, 1, 6) = '%FILE ' then begin
          Delete(RcvText, 1, 6);
          FName:=Copy(RcvText, 1, Pos('@', RcvText) - 1);
          Delete(RcvText, 1, Pos('@', RcvText));
          FSize:=StrToInt((Copy(RcvText, 1, Pos('%', RcvText) - 1)));
          FStream:=TFileStream.Create(CurPath + '\' + FName, fmCreate or fmShareDenyWrite);

          if FSize <> 0 then
            Receive:=true
          else begin //Пустые файлы
            Receive:=false;
            FStream.Free;
            Socket.SendText('%SUCESS_FILE%');
            Inc(ReceivedFilesCount);
            if (ReceiveFilesCount = ReceivedFilesCount) then begin
              StatusBar.SimpleText:=' ' + ID_SUCCESS_RECEIVED_FILES;
              ReceivedFilesCount:=0;
              ProgressBar.Visible:=false;
              ProgressBar.Position:=0;
            end;
          end;

          //Разрешение на передачу файла
          Socket.SendText('%SEND%');
      end;

      //Количество файлов для передачи
      if Copy(RcvText, 1, 13) = '%FILES_COUNT ' then begin
        Delete(RcvText, 1, 13);
        ReceiveFilesCount:=StrToInt(Copy(RcvText, 1, Pos('%', RcvText) - 1));
        Socket.SendText('%FILES_COUNT_OK%');
        ProgressBar.Visible:=true;
      end;

    end else
      Socket.SendText('%LAST_REQUEST%'); //В случае неудачи запрашиваем последний запрос повторно 

  end;
end;

//Добавление папок в список, рекурсивно
procedure TMain.AddDir(FolderPath: string);
var
  SR: TSearchRec; FolderPathNew: string;
begin
  //Отправляем название новой папки, без полного адреса
  FolderPathNew:=FolderPath;
  Delete(FolderPathNew, 1, Length(LocalPath));
  FileList.Add('DIR ' + FolderPathNew);

  if FolderPath[Length(FolderPath)] <> '\' then
    FolderPath:=FolderPath + '\';

  if FindFirst(FolderPath + '*.*', faAnyFile, SR) = 0 then begin
    repeat
      if (SR.Attr <> faDirectory) then
        AddFile(FolderPath + SR.Name); //Ищем файлы

      if (SR.Attr = faDirectory) and (SR.Name <> '.') and (SR.Name <> '..') then
        AddDir(FolderPath + SR.Name); //Ищем папки

    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

//Добавление файлов в список
procedure TMain.AddFile(FilePath: string);
begin
  Delete(FilePath, 1, Length(LocalPath));
  FileList.Add('FILE '+ FilePath);
end;

//Отправка файлов и папок поочередно
procedure TMain.Send;
begin
  //В случае отмены или неудачи выходим
  if BreakAll then begin
    StatusBar.SimpleText:=' ' + ID_SEND_FILES_ABORTED;
    Exit;
  end;

  //Список файлов и папок на отправку
  if FileList.Count > 0 then begin
    if Copy(FileList.Strings[0], 1, 5) = 'FILE ' then begin
      ProgressBar.Position:=0;
      LastFile:=LocalPath + Copy(FileList.Strings[0], 6, Length(FileList.Strings[0]));
      LastRequest:='%FILE ' + Copy(FileList.Strings[0], 6, Length(FileList.Strings[0])) + '@' + IntToStr(GetFileSize(LocalPath + Copy(FileList.Strings[0], 6, Length(FileList.Strings[0])))) + '%';
      ClientSocket.Socket.SendText(LastRequest);
    end;
    if Copy(FileList.Strings[0], 1, 4) = 'DIR ' then begin
      ProgressBar.Position:=0;
      LastRequest:='%DIR ' + Copy(FileList.Strings[0], 5, Length(FileList.Strings[0])) + '%';
      ClientSocket.Socket.SendText(LastRequest);
    end;
    FileList.Delete(0); //Удаление после отправки
  end;
  
  //Все файлы переданы
  if FileList.Count = 0 then begin
    ProgressBar.Visible:=false;
    StatusBar.SimpleText:=' ' + ID_SUCCESS_SENDED_FILES;
    FileList.Clear;
  end;
end;

procedure TMain.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  //Разрешение на отмену
  if Key = VK_ESCAPE then
    BreakAll:=true;
end;

procedure TMain.ServerSocketClientError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  BreakAll:=true;
  case ErrorCode of
    10061: StatusBar.SimpleText:=' ' + ID_FAIL_CONNECT;
  else
    StatusBar.SimpleText:=' ' + ID_CONNECTION_LOST;
  end;
  RcvFlsRep:=3;
  ErrorCode:=0;
end;

end.
