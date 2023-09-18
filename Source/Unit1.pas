unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ScktComp, StdCtrls, XPMan, ComCtrls, ShellAPI, ExtCtrls, IniFiles, IdHashCRC,
  Menus;

type
  TMain = class(TForm)
    ClientSocket: TClientSocket;
    ServerSocket: TServerSocket;
    XPManifest: TXPManifest;
    ProgressBar: TProgressBar;
    StatusBar: TStatusBar;
    DragAndDropImage: TImage;
    MainMenu: TMainMenu;
    ConsBtn: TMenuItem;
    ExitBtn: TMenuItem;
    HelpBtn: TMenuItem;
    AboutBtn: TMenuItem;
    ConSelBtn: TMenuItem;
    Line: TMenuItem;
    FileBtn: TMenuItem;
    SettingsBtn: TMenuItem;
    Line2: TMenuItem;
    AbortBtn: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ClientSocketRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientSocketError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure ClientSocketDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ServerSocketClientConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ServerSocketClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ServerSocketClientError(Sender: TObject;
      Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
      var ErrorCode: Integer);
    procedure AboutBtnClick(Sender: TObject);
    procedure ExitBtnClick(Sender: TObject);
    procedure ServerSocketClientDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ClientSocketConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ConSelBtnClick(Sender: TObject);
    procedure SettingsBtnClick(Sender: TObject);
    procedure N5Click(Sender: TObject);
  protected
    procedure WMDropFiles (var Msg: TMessage); message wm_DropFiles;
  private
    procedure AddDir(FolderPath: string);
    procedure AddFile(FilePath: string);
    procedure Send;
    procedure ReceivedReset;
    procedure SentReset;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Main: TMain;
  LastRequest, LastSendFile, LastReceivingFile, LocalPath, CurPath, CurAddress: string;
  AddressBook: string;
  FileList, AllowIPs: TStringList;
  SendFilesCount, SentFilesCount: integer;
  ReceivingFilesPermission: integer;
  AllowReceivingFiles: boolean;
  ReceivingFiles: boolean;
  ReceiveFilesCount, ReceivedFilesCount: integer;

  StopRequest: boolean;
  ReceivedFileStream: TFileStream; // Обработка ClientRead срабатывает несколько раз
  ReceivedFileOrFolderName: string;
  ReceivedFileDate: integer;
  //ReceivedCRC32File: Cardinal;
  ReceivedFileSize: int64;

  // Перевод
  ID_ENTER_IP, ID_ENTER_NAME, ID_CONNECT, ID_ALLOW_CONNECTION, ID_NOT_ALLOW_RECEIVE_FILES,
  ID_FAIL_CONNECT, ID_CONNECTION_LOST, ID_SEND_FILES, ID_SEND_FILES_ABORTED,
  ID_RECEIVE_FILES, ID_RECEIVE_FILES_ABORTED, ID_SUCCESS_RECEIVED_FILES,
  ID_SUCCESS_SENT_FILES: string;

  ID_NAME, ID_IP_ADDRESS, ID_ADD, ID_EDIT, ID_REMOVE, ID_SELECT, ID_CANCEL,
  ID_SELECT_FOLDER, ID_FOLDER_RECEIVING_FILES, ID_PORT, ID_IPS_WITOUT_ASKING, ID_OK: string;

  ID_ABOUT_TITLE, ID_LAST_UPDATE: string;

const
  PermissionAllow = 1;
  PermissionDenied = 2;
  PermissionMissing = 3;

implementation

uses Unit2, Unit3;

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
  Ini: TIniFile; i: integer; DebugMode: integer;
begin
  // Перевод
  if FileExists(ExtractFilePath(ParamStr(0)) + 'Languages\' + GetLocaleInformation(LOCALE_SENGLANGUAGE) + '.ini') then
    Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Languages\' + GetLocaleInformation(LOCALE_SENGLANGUAGE) + '.ini')
  else
    Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Languages\English.ini');

  FileBtn.Caption:=Ini.ReadString('Main', 'ID_FILE', '');
  SettingsBtn.Caption:=Ini.ReadString('Main', 'ID_SETTINGS', '');
  ExitBtn.Caption:=Ini.ReadString('Main', 'ID_EXIT', '');
  ConsBtn.Caption:=Ini.ReadString('Main', 'ID_CONNECTIONS', '');
  ConSelBtn.Caption:=Ini.ReadString('Main', 'ID_SELECT', '');
  AbortBtn.Caption:=Ini.ReadString('Main', 'ID_ABORT', '');
  HelpBtn.Caption:=Ini.ReadString('Main', 'ID_HELP', '');
  ID_ABOUT_TITLE:=Ini.ReadString('Main', 'ID_ABOUT_TITLE', '');
  AboutBtn.Caption:=ID_ABOUT_TITLE;

  ID_CONNECT:=Ini.ReadString('Main', 'ID_CONNECT', '');
  ID_ALLOW_CONNECTION:=Ini.ReadString('Main', 'ID_ALLOW_CONNECTION', '');
  ID_NOT_ALLOW_RECEIVE_FILES:=Ini.ReadString('Main', 'ID_NOT_ALLOW_RECEIVE_FILES', '');
  ID_FAIL_CONNECT:=Ini.ReadString('Main', 'ID_FAIL_CONNECT', '');
  ID_CONNECTION_LOST:=Ini.ReadString('Main', 'ID_CONNECTION_LOST', '');
  ID_SEND_FILES:=Ini.ReadString('Main', 'ID_SEND_FILES', '');
  ID_SEND_FILES_ABORTED:=Ini.ReadString('Main', 'ID_SEND_FILES_ABORTED', '');
  ID_RECEIVE_FILES:=Ini.ReadString('Main', 'ID_RECEIVE_FILES', '');
  ID_RECEIVE_FILES_ABORTED:=Ini.ReadString('Main', 'ID_RECEIVE_FILES_ABORTED', '');
  ID_SUCCESS_RECEIVED_FILES:=Ini.ReadString('Main', 'ID_SUCCESS_RECEIVED_FILES', '');
  ID_SUCCESS_SENT_FILES:=Ini.ReadString('Main', 'ID_SUCCESS_SENT_FILES', '');

  ID_NAME:=Ini.ReadString('Main', 'ID_NAME', '');
  ID_IP_ADDRESS:=Ini.ReadString('Main', 'ID_IP_ADDRESS', '');
  ID_ENTER_NAME:=Ini.ReadString('Main', 'ID_ENTER_NAME', '');
  ID_ENTER_IP:=Ini.ReadString('Main', 'ID_ENTER_IP', '');
  ID_ADD:=Ini.ReadString('Main', 'ID_ADD', '');
  ID_EDIT:=Ini.ReadString('Main', 'ID_EDIT', '');
  ID_REMOVE:=Ini.ReadString('Main', 'ID_REMOVE', '');
  ID_SELECT:=Ini.ReadString('Main', 'ID_SELECT', '');
  ID_CANCEL:=Ini.ReadString('Main', 'ID_CANCEL', '');

  ID_SELECT_FOLDER:=Ini.ReadString('Main', 'ID_SELECT_FOLDER', '');
  ID_FOLDER_RECEIVING_FILES:=Ini.ReadString('Main', 'ID_FOLDER_RECEIVING_FILES', '');
  ID_PORT:=Ini.ReadString('Main', 'ID_PORT', '');
  ID_IPS_WITOUT_ASKING:=Ini.ReadString('Main', 'ID_IPS_WITOUT_ASKING', '');
  ID_OK:=Ini.ReadString('Main', 'ID_OK', '');

  ID_LAST_UPDATE:=Ini.ReadString('Main', 'ID_LAST_UPDATE', '');
  Ini.Free;

  DebugMode:=-1;
  for i:=1 to ParamCount do begin
    if ParamStr(i) = '-debug' then
      DebugMode:=StrToIntDef(ParamStr(i + 1), 0);

    // Адрес передачи по умолчанию
    if ParamStr(i) = '-d' then
      CurAddress:=ParamStr(i + 1);
  end;

  // Проверка на повторый запуск
  if (DebugMode = -1) and (FindWindow('TMain', 'ShareFiles') <> 0) then begin
    SetForegroundWindow(FindWindow('TMain', 'ShareFiles'));
    Halt;
  end;
  
  Caption:='ShareFiles';
  if DebugMode <> -1 then
    if DebugMode = 0 then
      Caption:=Caption + ' - Server'
    else
      Caption:=Caption + ' - Client';
  Application.Title:=Caption;

  Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Setup.ini');
  ClientSocket.Port:=Ini.ReadInteger('Main', 'Port', 5371);
  ServerSocket.Port:=Ini.ReadInteger('Main', 'Port', 5371);
  AddressBook:=Ini.ReadString('Main', 'AddressBook', '');
  AllowIPs:=TStringList.Create;
  AllowIPs.Text:=StringReplace(Ini.ReadString('Main', 'IPsWithoutRequest', ''), ';', #13#10, [rfReplaceAll]);
  CurPath:=Ini.ReadString('Main', 'Path', '');
  if Trim(CurPath) = '' then CurPath:=GetEnvironmentVariable('USERPROFILE') + '\Desktop\';
  Ini.Free;

  FileList:=TStringList.Create;

  if DebugMode <> 1 then
    ServerSocket.Active:=true;

  if DebugMode <> -1 then begin
    FormStyle:=FSStayOnTop;
    Position:=poDesigned;
    Top:=Screen.Height div 2 - Height div 2;
    if DebugMode = 0 then
      Left:=Screen.Width div 2
    else
      Left:=Screen.Width div 2 - Width;;
  end;

  DragAcceptFiles(Main.Handle, true);
end;

procedure TMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if ClientSocket.Active then
    ClientSocket.Active:=false;
  if ServerSocket.Active then
    ServerSocket.Active:=false;
  AllowIPs.Free;
  FileList.Free;
end;

procedure TMain.WMDropFiles(var Msg: TMessage);
var
  i, Amount, Size: integer;
  FileName: PChar;
  RunOnce: boolean;
begin
  // Если передача идёт
  if ReceivingFiles = false then begin
  
    if Trim(CurAddress) = '' then
      ConnectionsForm.ShowModal;

    if Trim(CurAddress) = '' then
      Exit;

    StatusBar.SimpleText:=' ' + ID_CONNECT;
    ClientSocket.Host:=CurAddress;

    if not ClientSocket.Active then begin
      ClientSocket.Close;
      ClientSocket.Open;
    end;

    StopRequest:=false;
    FileList.Clear;
    SendFilesCount:=0;
    SentFilesCount:=0;
    RunOnce:=false;

    // Ждем разрешения на передачу файлов
    while ReceivingFilesPermission <> PermissionAllow do begin
      if (ReceivingFilesPermission = PermissionDenied) or (ReceivingFilesPermission = PermissionMissing) then begin
        StopRequest:=true;
        Break;
      end;
      Sleep(1);
      Application.ProcessMessages;
    end;

    case ReceivingFilesPermission of
      PermissionDenied: StatusBar.SimpleText:=' ' + ID_NOT_ALLOW_RECEIVE_FILES;
      PermissionMissing: StatusBar.SimpleText:=' ' + ID_FAIL_CONNECT;
    end;

    // В случае отмены или неудачи выходим
    if StopRequest then
      Exit;

    ProgressBar.Visible:=true;
    AbortBtn.Enabled:=true;
  end;

  // Обработка Drag & Drop
  inherited;
  Amount:=DragQueryFile(Msg.WParam, $FFFFFFFF, FileName, 255);
  for i:=0 to Amount - 1 do begin
    Size:=DragQueryFile(Msg.WParam, i, nil, 0) + 1;
    FileName:=StrAlloc(Size);
    DragQueryFile(Msg.WParam, i, FileName, Size);

    // Узнаем папку передаваемых файлов
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

  // Считаем количество файлов
  for i:=0 to FileList.Count - 1 do
    if Copy(FileList.Strings[i], 1, 5) = 'FILE ' then
      Inc(SendFilesCount);

  // Нельзя передавать во время передачи файла
  if (ReceivingFiles = false) and (ClientSocket.Active) then begin // ToDo отправлять новое количество, а пока пропуск
    // Отправляем количество файлов
    LastRequest:='%FILES_COUNT ' + IntToStr(SendFilesCount) + '%';
    ClientSocket.Socket.SendText(LastRequest);
  end;
end;

procedure TMain.ClientSocketRead(Sender: TObject;
  Socket: TCustomWinSocket);
var
  RcvText: string; FileStream: TFileStream;
begin
  Application.ProcessMessages;

  if StopRequest then begin
    Socket.Close;
    ClientSocket.Active:=false;
    StatusBar.SimpleText:=' ' + ID_CONNECTION_LOST;
    AbortBtn.Enabled:=false;
    Exit;
  end;

  RcvText:=Socket.ReceiveText;

  // Последний запрос, в случае неудачной отправки или приема можно запросить повторно
  if Pos('%LAST_REQUEST%', RcvText) > 0 then
    Socket.SendText(LastRequest);

  if Pos('%SUCCESS_FILE%', RcvText) > 0 then begin
    Send;
    Inc(SentFilesCount);
  end;

  if Pos('%FILE_CORRUPTED%', RcvText) > 0 then // Пробуем снова
    Send;

  if Pos('%SUCCESS_DIR%', RcvText) > 0 then
    Send;

  if Pos('%FILES_COUNT_OK%', RcvText) > 0 then
    Send;

  if Pos('%FILES_ALLOW_OK%', RcvText) > 0 then
    ReceivingFilesPermission:=PermissionAllow;

  // Команда на отправку файла
  if Pos('%SEND%', RcvText) > 0 then begin
    ProgressBar.Position:=0;
    ProgressBar.Visible:=true;
    StatusBar.SimpleText:=Format(' ' + ID_SEND_FILES, [SentFilesCount, SendFilesCount]);

    try
      ClientSocket.Socket.SendStream(TFileStream.Create(LastSendFile, fmOpenRead or fmShareDenyWrite));
    except
      StatusBar.SimpleText:=' ' + ID_FAIL_CONNECT;
    end;
    // ToDo: Нужно очищать потом V

    {try
      FileStream :=TFileStream.Create(LastSendFile, fmOpenRead or fmShareDenyWrite);
      ClientSocket.Socket.SendStream(FileStream);
    finally
      FileStream.Free;
    end;}

  end;

  if (RcvText[1] = '%') and (RcvText[Length(RcvText)] = '%') and (Copy(RcvText, 1, 14) = '%PROGRESS_BAR ') then begin
    Delete(RcvText, 1, 14);
    RcvText:=Copy(RcvText, 1, Pos('%', RcvText) - 1);
    ProgressBar.Position:=StrToIntDef(RcvText, 0);
  end;
end;

procedure TMain.ClientSocketError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  try
    StopRequest:=true;
    case ErrorCode of
      10061: StatusBar.SimpleText:=' ' + ID_FAIL_CONNECT;
    else
      StatusBar.SimpleText:=' ' + ID_CONNECTION_LOST;
    end;
    ErrorCode:=0;
    SentReset;
    if ClientSocket.Active then
      ClientSocket.Close;
  except
    StatusBar.SimpleText:=' ' + ID_CONNECTION_LOST;
  end;
end;

procedure TMain.ClientSocketDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  StopRequest:=true;
  SentReset;
  if ClientSocket.Active then
    ClientSocket.Close;
end;

procedure TMain.ServerSocketClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  // Разрешаем только одно подключение
  if ServerSocket.Socket.ActiveConnections = 1 then begin

    // Инициализация приема файлов
    AllowReceivingFiles:=false;
    ReceivedFileStream:=nil; // В случае прошлой ошибки с приёмом
    StopRequest:=false;
    ReceivingFiles:=false;
    ReceivedFilesCount:=0;

    // Проверяем есть ли в списке "Allow.txt" адрес, чтобы не запрашивать подверждение
    if (AllowIPs.Count > 0) and (Pos(Socket.RemoteAddress, AllowIPs.Text) > 0) then begin
      AllowReceivingFiles:=true;
      ServerSocket.Socket.Connections[0].SendText('%FILES_ALLOW_OK%');
    end else
      case MessageBox(Handle, PChar(ID_ALLOW_CONNECTION + ' ' + Socket.RemoteHost + ' ' + Socket.RemoteAddress), PChar(Caption), 35 or MB_TOPMOST) of
        6: begin
            AllowReceivingFiles:=true;
            ServerSocket.Socket.Connections[0].SendText('%FILES_ALLOW_OK%');
          end;
        7: ServerSocket.Socket.Connections[0].Close;
        2: ServerSocket.Socket.Connections[0].Close;
      end;
  end else
    ServerSocket.Socket.Connections[0].Close;
end;

// Количество символов в строке
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
  RcvText: string;
begin
  // В случае отмены или неудачи выходим
  if StopRequest then begin

    ReceivingFiles:=false;
    ReceivedFileStream.Free;
    if LastReceivingFile <> '' then // Удаляем последний файл, если он нецел
      DeleteFile(CurPath + '\' + LastReceivingFile);
    StatusBar.SimpleText:=' ' + ID_RECEIVE_FILES_ABORTED;
    ReceivedReset;
    ServerSocket.Socket.Connections[0].Close;;
    Exit;
  end;

  // Получение файла
  if ReceivingFiles then begin
    StatusBar.SimpleText:=Format(' ' + ID_RECEIVE_FILES, [ReceivedFilesCount, ReceiveFilesCount]);
    LengthFile:=Socket.ReceiveLength;
    GetMem(BufferFile, LengthFile);
    try
      Socket.ReceiveBuf(BufferFile^, LengthFile);
      ReceivedFileStream.Write(BufferFile^, LengthFile);
      ProgressBar.Position:=(ReceivedFileStream.Size * 100) div ReceivedFileSize;
      Socket.SendText('%PROGRESS_BAR ' + IntToStr(ProgressBar.Position) + '%');

      if ReceivedFileStream.Size = ReceivedFileSize then begin // Завершаем если размер соответствует размеру оригигала
        ReceivingFiles:=false;
        ReceivedFileStream.Free;

        if ( FileSetDate(CurPath + '\' + ReceivedFileOrFolderName, ReceivedFileDate ) = 0)  and
               ( GetFileSize( CurPath + '\' + ReceivedFileOrFolderName ) = ReceivedFileSize ) then begin
                LastReceivingFile:=''; // Очищаем, поскольку файл успешно передан
                Socket.SendText('%SUCCESS_FILE%');
                Inc(ReceivedFilesCount);
                AbortBtn.Enabled:=false;
         end else begin
            DeleteFile(CurPath + '\' + ReceivedFileOrFolderName);
            Socket.SendText('%FILE_CORRUPTED%');
            AbortBtn.Enabled:=false;
         end;

        if (ReceiveFilesCount = ReceivedFilesCount) then begin
          StatusBar.SimpleText:=' ' + ID_SUCCESS_RECEIVED_FILES;
          ReceivedFilesCount:=0;
          ReceivedReset;
        end;
      end;
    finally
      FreeMem(BufferFile);
    end;

  end else begin

    // Приём команд
    RcvText:=Socket.ReceiveText;

    if (RcvText[1] = '%') and (RcvText[Length(RcvText)] = '%') and (CountCharStr('%', RcvText) = 2) then begin

      // Создание папки
      if Copy(RcvText, 1, 5) = '%DIR ' then begin
        Delete(RcvText, 1, 5);
        ReceivedFileOrFolderName:=Copy(RcvText, 1, Pos('%', RcvText) - 1);
        if not (DirectoryExists(CurPath + '\' + ReceivedFileOrFolderName)) then
          CreateDir(CurPath + '\' + ReceivedFileOrFolderName);
        Socket.SendText('%SUCCESS_DIR%');
      end;

      // Создание файла
      if Copy(RcvText, 1, 6) = '%FILE ' then begin
      
          Delete(RcvText, 1, 6);
          ReceivedFileOrFolderName:=Copy(RcvText, 1, Pos(#9, RcvText) - 1);
          LastReceivingFile:=ReceivedFileOrFolderName;

          Delete(RcvText, 1, Pos(#9, RcvText));
          ReceivedFileSize:=StrToInt((Copy(RcvText, 1, Pos(#9, RcvText) - 1)));

          //Delete(RcvText, 1, Pos(#9, RcvText));
          //ReceivedCRC32File:=StrToInt64((Copy(RcvText, 1, Pos(#9, RcvText) - 1))); // Cardinal

          Delete(RcvText, 1, Pos(#9, RcvText));
          ReceivedFileDate:=StrToInt((Copy(RcvText, 1, Pos('%', RcvText) - 1)));

          ReceivedFileStream:=TFileStream.Create(CurPath + '\' + ReceivedFileOrFolderName, fmCreate or fmShareDenyWrite);

          if ReceivedFileSize <> 0 then begin
            ReceivingFiles:=true;
            AbortBtn.Enabled:=true;
          end else begin // Пустые файлы
            ReceivingFiles:=false;
            ReceivedFileStream.Free;

            Socket.SendText('%SUCCESS_FILE%');
            Inc(ReceivedFilesCount);

            if ( FileSetDate(CurPath + '\' + ReceivedFileOrFolderName, ReceivedFileDate ) = 0)  and
               ( GetFileSize( CurPath + '\' + ReceivedFileOrFolderName ) = ReceivedFileSize ) then begin
                LastReceivingFile:=''; // Очищаем, поскольку файл успешно передан
                Socket.SendText('%SUCCESS_FILE%');
                Inc(ReceivedFilesCount);
                AbortBtn.Enabled:=false;
            end else begin
              DeleteFile(CurPath + '\' + ReceivedFileOrFolderName);
              Socket.SendText('%FILE_CORRUPTED%');
              AbortBtn.Enabled:=false;
            end;

            if (ReceiveFilesCount = ReceivedFilesCount) then begin
              StatusBar.SimpleText:=' ' + ID_SUCCESS_RECEIVED_FILES;
              ReceivedFilesCount:=0;
              ReceivedReset;
            end;
          end;

          // Разрешение на передачу файла
          Socket.SendText('%SEND%');
      end;

      // Количество файлов для передачи
      if Copy(RcvText, 1, 13) = '%FILES_COUNT ' then begin
        Delete(RcvText, 1, 13);
        ReceiveFilesCount:=StrToInt(Copy(RcvText, 1, Pos('%', RcvText) - 1));
        Socket.SendText('%FILES_COUNT_OK%');
        ProgressBar.Visible:=true;
      end;

    end else
      Socket.SendText('%LAST_REQUEST%'); // В случае неудачи запрашиваем последний запрос повторно

  end;
end;

// Добавление папок в список, рекурсивно
procedure TMain.AddDir(FolderPath: string);
var
  SR: TSearchRec; FolderPathNew: string;
begin
  // Отправляем название новой папки, без полного адреса
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

// Добавление файлов в список
procedure TMain.AddFile(FilePath: string);
begin
  Delete(FilePath, 1, Length(LocalPath));
  FileList.Add('FILE ' + FilePath);
end;

// Отправка файлов и папок поочередно
procedure TMain.Send;
var
  SentFileName: string;
begin
  // В случае отмены или неудачи выходим
  if StopRequest then begin
    StatusBar.SimpleText:=' ' + ID_SEND_FILES_ABORTED;
    Exit;
  end;

  if ClientSocket.Active = false then begin
    StatusBar.SimpleText:=' ' + ID_FAIL_CONNECT;
    Exit;
  end;

  // Список файлов и папок на отправку
  if FileList.Count > 0 then begin

    if Copy(FileList.Strings[0], 1, 5) = 'FILE ' then begin
      ProgressBar.Position:=0;

      SentFileName:=Copy(FileList.Strings[0], 6, Length(FileList.Strings[0]));
      LastSendFile:=LocalPath + SentFileName;

      LastRequest:='%FILE ' + SentFileName + #9 +
                              IntToStr(GetFileSize(LocalPath + SentFileName)) + #9 + // Размер файла
                              IntToStr(FileAge(LocalPath + SentFileName)) + '%'; // Дата изменения

      ClientSocket.Socket.SendText(LastRequest);
    end;

    if Copy(FileList.Strings[0], 1, 4) = 'DIR ' then begin
      ProgressBar.Position:=0;
      LastRequest:='%DIR ' + Copy(FileList.Strings[0], 5, Length(FileList.Strings[0])) + '%';
      ClientSocket.Socket.SendText(LastRequest);
    end;

    FileList.Delete(0); // Удаление после отправки
  end;
  
  // Все файлы переданы
  if FileList.Count = 0 then begin
    ProgressBar.Visible:=false;
    StatusBar.SimpleText:=' ' + ID_SUCCESS_SENT_FILES;
    AbortBtn.Enabled:=false;
    FileList.Clear;
  end;
end;

procedure TMain.ServerSocketClientError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  StopRequest:=true;
  case ErrorCode of
    10061: StatusBar.SimpleText:=' ' + ID_FAIL_CONNECT;
  else
    StatusBar.SimpleText:=' ' + ID_CONNECTION_LOST;
  end;
  ReceivingFilesPermission:=PermissionMissing;
  ErrorCode:=0;
  ReceivedReset;

  {if Assigned(ReceivedFileStream) then begin
    FreeAndNil(ReceivedFileStream);
    ReceivedFileStream:=nil; // В случае прошлой ошибки с приёмом.
  end;

  if ( FileExists(CurPath + '\' + LastReceivingFile) )  and
     ( GetFileSize( CurPath + '\' + LastReceivingFile) <> ReceivedFileSize ) then
    DeleteFile(CurPath + '\' + LastReceivingFile); }
end;

procedure TMain.AboutBtnClick(Sender: TObject);
begin
  Application.MessageBox(PChar(Caption + ' 0.8' + #13#10 +
  ID_LAST_UPDATE + ': 18.09.2023' + #13#10 +
  'https://r57zone.github.io' + #13#10 +
  'r57zone@gmail.com'), PChar(ID_ABOUT_TITLE), MB_ICONINFORMATION);
end;

procedure TMain.ExitBtnClick(Sender: TObject);
begin
  Close;
end;

procedure TMain.ServerSocketClientDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  ReceivedReset;

  {if Assigned(ReceivedFileStream) then begin
    FreeAndNil(ReceivedFileStream);
    ReceivedFileStream:=nil; // В случае прошлой ошибки с приёмом.
  end;
  
  if ( FileExists(CurPath + '\' + LastReceivingFile) )  and
     ( GetFileSize( CurPath + '\' + LastReceivingFile) <> ReceivedFileSize ) then
    DeleteFile(CurPath + '\' + LastReceivingFile); }
end;

procedure TMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  StopRequest:=true;
end;

procedure TMain.ClientSocketConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  AbortBtn.Enabled:=true;
end;

procedure TMain.ReceivedReset;
begin
  ProgressBar.Position:=0;
  ProgressBar.Visible:=false;
  AbortBtn.Enabled:=false;
end;

procedure TMain.SentReset;
begin
  ProgressBar.Position:=0;
  ProgressBar.Visible:=false;
  AbortBtn.Enabled:=false;
end;

procedure TMain.ConSelBtnClick(Sender: TObject);
begin
  ConnectionsForm.ShowModal;
end;

procedure TMain.SettingsBtnClick(Sender: TObject);
begin
  SettingsForm.ShowModal;
end;

procedure TMain.N5Click(Sender: TObject);
begin
  StopRequest:=true;
  AbortBtn.Enabled:=false;
end;

end.
