unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ScktComp, StdCtrls, ComCtrls, ShellAPI, ExtCtrls, IniFiles,
  Menus, ShlObj; // IdHashCRC

type
  TMain = class(TForm)
    ClientSocket: TClientSocket;
    ServerSocket: TServerSocket;
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
    //procedure SendFileInChunks(const FilePath: string);
    procedure ReceivedReset;
    procedure SentReset;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Main: TMain;
  LastSentCommand, CurSendFile, CurReceivingFile, LocalPath, SavePath, CurAddress: string;
  AddressBook: string;
  FileList, AllowIPs: TStringList;
  SendFilesCount, SentFilesCount: integer;
  SendPermission: integer;
  ReceivingFiles: boolean;
  ReceiveFilesCount, ReceivedFilesCount: integer;
  LastProgressSent: integer;

  StopRequest: boolean;
  ReceivedFileStream: TFileStream; // Обработка ClientRead срабатывает несколько раз
  ReceivedFileOrFolderName: string;
  ReceivedFileDate: integer;
  //ReceivedCRC32File: Cardinal;
  ReceivedFileSize: int64;

  // Перевод
  IDS_ENTER_IP, IDS_ENTER_NAME, IDS_CONNECT, IDS_ALLOW_CONNECTION, IDS_NOT_ALLOW_RECEIVE_FILES,
  IDS_FAIL_CONNECT, IDS_CONNECTION_LOST, IDS_SENDING_FILES, IDS_SENDING_FILES_ABORTED,
  IDS_RECEIVING_FILES, IDS_RECEIVING_FILES_ABORTED, IDS_SUCCESS_RECEIVED_FILES,
  IDS_SUCCESS_SENT_FILES: string;

  IDS_NAME, IDS_IP_ADDRESS, IDS_ADD, IDS_EDIT, IDS_REMOVE, IDS_SELECT, IDS_CANCEL,
  IDS_SELECT_FOLDER, IDS_FOLDER_RECEIVING_FILES, IDS_PORT, IDS_IPS_WITHOUT_ASKING, IDS_OK: string;

  IDS_ABOUT_TITLE, IDS_LAST_UPDATE: string;

const
  PermissionAllow = 1;
  PermissionDenied = 2;
  PermissionMissing = 3;

implementation

uses Unit2, Unit3;

{$R *.dfm}
{$R DragAndDrop.res}

function GetUserDefaultUILanguage: LANGID; stdcall; external 'kernel32.dll';

function GetFileSize(const FileName: string): int64;
var
  SearchFile: TSearchRec;
begin
   FindFirst(FileName, faAnyFile, SearchFile);
   //Result:=(int64(SearchFile.FindData.nFileSizeHigh) * MAXDWORD) + int64(SearchFile.FindData.nFileSizeLow);
   Result:=(int64(SearchFile.FindData.nFileSizeHigh) shl 32) or int64(SearchFile.FindData.nFileSizeLow);
   FindClose(SearchFile);
end;

function GetLocaleInformation(Flag: integer): string; // If there are multiple languages in the system (with sorting) / Если в системе несколько языков (с сортировкой)
var
  pcLCA: array [0..63] of Char;
begin
  if GetLocaleInfo((DWORD(SORT_DEFAULT) shl 16) or Word(GetUserDefaultUILanguage), Flag, pcLCA, Length(pcLCA)) <= 0 then
    pcLCA[0]:=#0;
  Result:=pcLCA;
end;

function GetDesktopPath: string;
var
  Path: array[0..MAX_PATH] of Char;
begin
  SHGetSpecialFolderPath(0, Path, CSIDL_DESKTOPDIRECTORY, False);
  Result := StrPas(Path);
end;

procedure TMain.FormCreate(Sender: TObject);
var
  Ini: TIniFile; i: integer; DebugMode: integer;
  SystemLang, LangFileName: string;
begin
  // Translate / Перевод
  SystemLang:=GetLocaleInformation(LOCALE_SENGLANGUAGE);
  if SystemLang = 'Chinese' then
    SystemLang:='Chinese (Simplified)'
  else if Pos('Spanish', SystemLang) > 0 then
    SystemLang:='Spanish'
  else if Pos('Portuguese', SystemLang) > 0 then
    SystemLang:='Portuguese';

  LangFileName:=SystemLang + '.ini';
  if not FileExists(ExtractFilePath(ParamStr(0)) + 'Languages\' + LangFileName) then
    LangFileName:='English.Ini';
  Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Languages\' + LangFileName);

  FileBtn.Caption:=Ini.ReadString('Main', 'FILE', 'File');
  SettingsBtn.Caption:=Ini.ReadString('Main', 'SETTINGS', 'Settings');
  ExitBtn.Caption:=Ini.ReadString('Main', 'EXIT', 'Exit');
  ConsBtn.Caption:=Ini.ReadString('Main', 'CONNECTIONS', 'Connections');
  ConSelBtn.Caption:=Ini.ReadString('Main', 'SELECT', 'Select');
  AbortBtn.Caption:=Ini.ReadString('Main', 'ABORT', 'Abort');
  HelpBtn.Caption:=Ini.ReadString('Main', 'HELP', 'Help');
  IDS_ABOUT_TITLE:=Ini.ReadString('Main', 'ABOUT_TITLE', 'About...');
  AboutBtn.Caption:=IDS_ABOUT_TITLE;

  IDS_CONNECT:=Ini.ReadString('Main', 'CONNECT', 'Connect');
  IDS_ALLOW_CONNECTION:=Ini.ReadString('Main', 'ALLOW_CONNECTION', 'Allow connection');
  IDS_NOT_ALLOW_RECEIVE_FILES:=Ini.ReadString('Main', 'NOT_ALLOW_RECEIVE_FILES', 'The user did not approve file transfer');
  IDS_FAIL_CONNECT:=Ini.ReadString('Main', 'FAIL_CONNECT', 'Failed to connect');
  IDS_CONNECTION_LOST:=Ini.ReadString('Main', 'CONNECTION_LOST', 'Connection lost');
  IDS_SENDING_FILES:=Ini.ReadString('Main', 'SENDING_FILES', 'Sending files: %d of %d, %d%%');
  IDS_SENDING_FILES_ABORTED:=Ini.ReadString('Main', 'SENDING_FILES_ABORTED', 'File sending aborted');
  IDS_RECEIVING_FILES:=Ini.ReadString('Main', 'RECEIVING_FILES', 'Receiving files: %d of %d, current %d%%');
  IDS_RECEIVING_FILES_ABORTED:=Ini.ReadString('Main', 'RECEIVING_FILES_ABORTED', 'File receiving aborted');
  IDS_SUCCESS_RECEIVED_FILES:=Ini.ReadString('Main', 'SUCCESS_RECEIVED_FILES', 'All files received successfully');
  IDS_SUCCESS_SENT_FILES:=Ini.ReadString('Main', 'SUCCESS_SENT_FILES', 'All files sent successfully');

  IDS_NAME:=Ini.ReadString('Main', 'NAME', 'Name');
  IDS_IP_ADDRESS:=Ini.ReadString('Main', 'IP_ADDRESS', 'IP address');
  IDS_ENTER_NAME:=Ini.ReadString('Main', 'ENTER_NAME', 'Enter the title:');
  IDS_ENTER_IP:=Ini.ReadString('Main', 'ENTER_IP', 'Enter IP address:');
  IDS_ADD:=Ini.ReadString('Main', 'ADD', 'Add');
  IDS_EDIT:=Ini.ReadString('Main', 'EDIT', 'Edit');
  IDS_REMOVE:=Ini.ReadString('Main', 'REMOVE', 'Remove');
  IDS_SELECT:=Ini.ReadString('Main', 'SELECT', 'Select');
  IDS_CANCEL:=Ini.ReadString('Main', 'CANCEL', 'Cancel');

  IDS_SELECT_FOLDER:=Ini.ReadString('Main', 'SELECT_FOLDER', 'Select folder');
  IDS_FOLDER_RECEIVING_FILES:=Ini.ReadString('Main', 'FOLDER_RECEIVING_FILES', 'Folder for receiving files:');
  IDS_PORT:=Ini.ReadString('Main', 'PORT', 'Port:');
  IDS_IPS_WITHOUT_ASKING:=Ini.ReadString('Main', 'IPS_WITHOUT_ASKING', 'Receive from the following IPs without asking:');
  IDS_OK:=Ini.ReadString('Main', 'OK', 'OK');

  IDS_LAST_UPDATE:=Ini.ReadString('Main', 'LAST_UPDATE', 'Last update:');
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
  SavePath:=Ini.ReadString('Main', 'Path', '');
  if Trim(SavePath) = '' then SavePath:=GetDesktopPath + '\';
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
  StopRequest := true;
  SendPermission := PermissionMissing;

  if Assigned(ReceivedFileStream) then
    FreeAndNil(ReceivedFileStream);

  try
    if ClientSocket.Active then
      ClientSocket.Active:=false;
    if ServerSocket.Active then
      ServerSocket.Active:=false;
  except
  end;

  AllowIPs.Free;
  FileList.Free;
end;

procedure TMain.WMDropFiles(var Msg: TMessage);
var
  i, Amount, Size: integer;
  FileName: PChar;
  RunOnce: boolean;
begin
  RunOnce:=false;
  // Если передача идёт
  if ReceivingFiles = false then begin
  
    if Trim(CurAddress) = '' then
      ConnectionsForm.ShowModal;

    if Trim(CurAddress) = '' then
      Exit;

    StatusBar.SimpleText:=' ' + IDS_CONNECT;
    ClientSocket.Host:=CurAddress;

    if not ClientSocket.Active then begin
      ClientSocket.Close;
      ClientSocket.Open;
      SendPermission:=0;
    end;

    StopRequest:=false;
    FileList.Clear;
    SendFilesCount:=0;
    SentFilesCount:=0;

    // Ждем разрешения на передачу файлов
    while SendPermission <> PermissionAllow do begin
      if (SendPermission = PermissionDenied) or (SendPermission = PermissionMissing) then begin
        StopRequest:=true;
        Break;
      end;
      if Application.Terminated then begin
        StopRequest:= true;
        Break;
      end;
      Sleep(1);
      Application.ProcessMessages;
    end;

    case SendPermission of
      PermissionDenied: StatusBar.SimpleText:=' ' + IDS_NOT_ALLOW_RECEIVE_FILES;
      PermissionMissing: StatusBar.SimpleText:=' ' + IDS_FAIL_CONNECT;
    end;

    // В случае отмены или неудачи выходим
    if StopRequest then begin
      DragFinish(Msg.WParam);
      Exit;
    end;

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
    LastSentCommand:='%FILES_COUNT ' + IntToStr(SendFilesCount) + '%';
    ClientSocket.Socket.SendText(LastSentCommand);
  end;
end;

procedure TMain.ClientSocketRead(Sender: TObject;
  Socket: TCustomWinSocket);
var
  RcvText: string;
begin
  if Application.Terminated or (csDestroying in ComponentState) then
    Exit;
  Application.ProcessMessages;

  if StopRequest then begin
    Socket.Close;
    ClientSocket.Active:=false;
    StatusBar.SimpleText:=' ' + IDS_CONNECTION_LOST;
    AbortBtn.Enabled:=false;
    Exit;
  end;

  RcvText:=Socket.ReceiveText;

  // Последний запрос, в случае неудачной отправки или приема можно запросить повторно
  if Pos('%LAST_REQUEST%', RcvText) > 0 then
    Socket.SendText(LastSentCommand);

  if Pos('%SUCCESS_FILE%', RcvText) > 0 then begin
    Send;
    Inc(SentFilesCount);
  end;

  if Pos('%FILE_CORRUPTED%', RcvText) > 0 then // Пробуем снова
    ClientSocket.Socket.SendText(LastSentCommand);

  if Pos('%SUCCESS_DIR%', RcvText) > 0 then
    Send;

  if Pos('%FILES_COUNT_OK%', RcvText) > 0 then
    Send;

  if Pos('%FILES_ALLOW_OK%', RcvText) > 0 then
    SendPermission:=PermissionAllow;

  // Команда на отправку файла
  if Pos('%SEND%', RcvText) > 0 then begin
    ProgressBar.Position:=0;
    ProgressBar.Visible:=true;
    StatusBar.SimpleText:=Format(' ' + IDS_SENDING_FILES, [SentFilesCount, SendFilesCount, ProgressBar.Position]);

    try
      ClientSocket.Socket.SendStream(TFileStream.Create(CurSendFile, fmOpenRead or fmShareDenyWrite));
      //SendFileInChunks(CurSendFile);
    except
      StatusBar.SimpleText:=' ' + IDS_FAIL_CONNECT;
      StopRequest:=true;
    end;

    // ToDo: Нужно очищать потом V (но нужно как-то иначе нужно, поскольку переиспользуется)

    {try
      FileStream :=TFileStream.Create(LastSendFile, fmOpenRead or fmShareDenyWrite);
      ClientSocket.Socket.SendStream(FileStream);
    finally
      FileStream.Free;
    end;}

  end;

  if (Length(RcvText) > 0) and (RcvText[1] = '%') and (RcvText[Length(RcvText)] = '%') and (Copy(RcvText, 1, 14) = '%PROGRESS_BAR ') then begin
    Delete(RcvText, 1, 14);
    RcvText:=Copy(RcvText, 1, Pos('%', RcvText) - 1);
    ProgressBar.Position:=StrToIntDef(RcvText, 0);
    StatusBar.SimpleText:=Format(' ' + IDS_SENDING_FILES, [SentFilesCount, SendFilesCount, ProgressBar.Position]);
  end;
end;

procedure TMain.ClientSocketError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  if Application.Terminated or (csDestroying in ComponentState) then begin
    case ErrorCode of
      10061: StatusBar.SimpleText:=' ' + IDS_FAIL_CONNECT;
    else
      StatusBar.SimpleText:=' ' + IDS_CONNECTION_LOST;
    end;
    ErrorCode:=0;
    Exit;
  end;
  try
    StopRequest:=true;
    SendPermission:=PermissionMissing;
    case ErrorCode of
      10061: StatusBar.SimpleText:=' ' + IDS_FAIL_CONNECT;
    else
      StatusBar.SimpleText:=' ' + IDS_CONNECTION_LOST;
    end;
    ErrorCode:=0;
    SentReset;
    if ClientSocket.Active then
      ClientSocket.Close;
  except
    StatusBar.SimpleText:=' ' + IDS_CONNECTION_LOST;
  end;
end;

procedure TMain.ClientSocketDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  if Application.Terminated or (csDestroying in ComponentState) then
    Exit;
  StopRequest:=true;
  SentReset;
  if ClientSocket.Active then
    ClientSocket.Close;
end;

procedure TMain.ServerSocketClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  if Application.Terminated or (csDestroying in ComponentState) then
    Exit;
  // Разрешаем только одно подключение
  if ServerSocket.Socket.ActiveConnections = 1 then begin

    // Инициализация приёма файлов
    ReceivedFileStream:=nil; // В случае прошлой ошибки с приёмом
    StopRequest:=false;
    ReceivingFiles:=false;
    ReceivedFilesCount:=0;

    // Проверяем есть ли в списке "Allow.txt" адрес, чтобы не запрашивать подверждение
    if (AllowIPs.Count > 0) and (Pos(Socket.RemoteAddress, AllowIPs.Text) > 0) then
      ServerSocket.Socket.Connections[0].SendText('%FILES_ALLOW_OK%')
    else
      case MessageBox(Handle,  PChar(Format(IDS_ALLOW_CONNECTION, [Socket.RemoteHost, Socket.RemoteAddress])), PChar(Caption), MB_YESNOCANCEL or MB_ICONQUESTION or MB_TOPMOST) of
        6: ServerSocket.Socket.Connections[0].SendText('%FILES_ALLOW_OK%');
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
  if Application.Terminated or (csDestroying in ComponentState) then
    Exit;
  // В случае отмены или неудачи выходим
  if StopRequest then begin

    ReceivingFiles:=false;
    if Assigned(ReceivedFileStream) then
      FreeAndNil(ReceivedFileStream);
      
    if CurReceivingFile <> '' then // Удаляем последний файл, если он нецел
      DeleteFile(SavePath + CurReceivingFile);
    StatusBar.SimpleText:=' ' + IDS_RECEIVING_FILES_ABORTED;
    ReceivedReset;
    ServerSocket.Socket.Connections[0].Close;;
    Exit;
  end;

  // Получение файла
  if ReceivingFiles then begin
    StatusBar.SimpleText:=Format(' ' + IDS_RECEIVING_FILES, [ReceivedFilesCount, ReceiveFilesCount, ProgressBar.Position]);
    LengthFile:=Socket.ReceiveLength;
    GetMem(BufferFile, LengthFile);
    try
      Socket.ReceiveBuf(BufferFile^, LengthFile);
      ReceivedFileStream.Write(BufferFile^, LengthFile);
      ProgressBar.Position:=(ReceivedFileStream.Size * 100) div ReceivedFileSize;
      //Socket.SendText('%PROGRESS_BAR ' + IntToStr(ProgressBar.Position) + '%');

      if Abs(ProgressBar.Position - LastProgressSent) > 0 then begin
        Socket.SendText('%PROGRESS_BAR ' + IntToStr(ProgressBar.Position) + '%');
        LastProgressSent:=ProgressBar.Position;
        StatusBar.SimpleText:=Format(' ' + IDS_RECEIVING_FILES, [ReceivedFilesCount, ReceiveFilesCount, ProgressBar.Position]);
      end;

      if ReceivedFileStream.Size = ReceivedFileSize then begin // Завершаем если размер соответствует размеру оригигала
        ReceivingFiles:=false;
        ReceivedFileStream.Free;
        ReceivedFileStream:=nil;

        Application.ProcessMessages;
        Sleep(20); // Даём время перед отправкой подтверждения

        if ( FileSetDate(SavePath + ReceivedFileOrFolderName, ReceivedFileDate ) = 0)  and
               ( GetFileSize( SavePath + ReceivedFileOrFolderName ) = ReceivedFileSize ) then begin
                CurReceivingFile:=''; // Очищаем, поскольку файл успешно передан
                Socket.SendText('%SUCCESS_FILE%');
                Inc(ReceivedFilesCount);
                AbortBtn.Enabled:=false;
         end else begin
            DeleteFile(SavePath + ReceivedFileOrFolderName);
            Socket.SendText('%FILE_CORRUPTED%');
            AbortBtn.Enabled:=false;
         end;

        if (ReceiveFilesCount = ReceivedFilesCount) then begin
          StatusBar.SimpleText:=' ' + IDS_SUCCESS_RECEIVED_FILES;
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

    if (Length(RcvText) > 0) and (RcvText[1] = '%') and (RcvText[Length(RcvText)] = '%') and (CountCharStr('%', RcvText) = 2) then begin

      // Создание папки
      if Copy(RcvText, 1, 5) = '%DIR ' then begin
        Delete(RcvText, 1, 5);
        ReceivedFileOrFolderName:=Copy(RcvText, 1, Pos('%', RcvText) - 1);
        if not (DirectoryExists(SavePath + ReceivedFileOrFolderName)) then
          CreateDir(SavePath + ReceivedFileOrFolderName);
        Socket.SendText('%SUCCESS_DIR%');
      end;

      // Создание файла
      if Copy(RcvText, 1, 6) = '%FILE ' then begin
      
          Delete(RcvText, 1, 6);
          ReceivedFileOrFolderName:=Copy(RcvText, 1, Pos(#9, RcvText) - 1);
          CurReceivingFile:=ReceivedFileOrFolderName;

          Delete(RcvText, 1, Pos(#9, RcvText));
          ReceivedFileSize:=StrToInt64((Copy(RcvText, 1, Pos(#9, RcvText) - 1)));

          //Delete(RcvText, 1, Pos(#9, RcvText));
          //ReceivedCRC32File:=StrToInt64((Copy(RcvText, 1, Pos(#9, RcvText) - 1))); // Cardinal

          Delete(RcvText, 1, Pos(#9, RcvText));
          ReceivedFileDate:=StrToInt((Copy(RcvText, 1, Pos('%', RcvText) - 1)));

          ReceivedFileStream:=TFileStream.Create(SavePath + ReceivedFileOrFolderName, fmCreate or fmShareDenyWrite);

          LastProgressSent:=0;
          ProgressBar.Position:=0;

          if ReceivedFileSize <> 0 then begin
            ReceivingFiles:=true;
            AbortBtn.Enabled:=true;
            Application.ProcessMessages;
            Sleep(10); // Даём время на обработку предыдущих данных
            Socket.SendText('%SEND%');

          end else begin // Пустые файлы
            ReceivingFiles:=false;
            ReceivedFileStream.Free;
            ReceivedFileStream:=nil;

            //Socket.SendText('%SUCCESS_FILE%');
            //Inc(ReceivedFilesCount);

            if ( FileSetDate(SavePath + ReceivedFileOrFolderName, ReceivedFileDate ) = 0)  and
               ( GetFileSize( SavePath + ReceivedFileOrFolderName ) = ReceivedFileSize ) then begin
                CurReceivingFile:=''; // Очищаем, поскольку файл успешно передан
                Socket.SendText('%SUCCESS_FILE%');
                Inc(ReceivedFilesCount);
                AbortBtn.Enabled:=false;
            end else begin
              DeleteFile(SavePath + ReceivedFileOrFolderName);
              Socket.SendText('%FILE_CORRUPTED%');
              AbortBtn.Enabled:=false;
            end;

            if (ReceiveFilesCount = ReceivedFilesCount) then begin
              StatusBar.SimpleText:=' ' + IDS_SUCCESS_RECEIVED_FILES;
              ReceivedFilesCount:=0;
              ReceivedReset;
            end;
          end;

          // Разрешение на передачу файла
          //Socket.SendText('%SEND%');
      end;

      // Количество файлов для передачи
      if Copy(RcvText, 1, 13) = '%FILES_COUNT ' then begin
        Delete(RcvText, 1, 13);
        ReceiveFilesCount:=StrToInt(Copy(RcvText, 1, Pos('%', RcvText) - 1));
        Socket.SendText('%FILES_COUNT_OK%');
        ProgressBar.Visible:=true;
      end;

    end else if Length(RcvText) > 0 then
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
    StatusBar.SimpleText:=' ' + IDS_SENDING_FILES_ABORTED;
    Exit;
  end;

  if ClientSocket.Active = false then begin
    StatusBar.SimpleText:=' ' + IDS_FAIL_CONNECT;
    Exit;
  end;

  // Список файлов и папок на отправку
  if FileList.Count > 0 then begin

    if Copy(FileList.Strings[0], 1, 5) = 'FILE ' then begin
      ProgressBar.Position:=0;

      SentFileName:=Copy(FileList.Strings[0], 6, Length(FileList.Strings[0]));
      CurSendFile:=LocalPath + SentFileName;

      LastSentCommand:='%FILE ' + SentFileName + #9 +
                              IntToStr(GetFileSize(LocalPath + SentFileName)) + #9 + // Размер файла
                              IntToStr(FileAge(LocalPath + SentFileName)) + '%'; // Дата изменения

      ClientSocket.Socket.SendText(LastSentCommand);
    end;

    if Copy(FileList.Strings[0], 1, 4) = 'DIR ' then begin
      ProgressBar.Position:=0;
      LastSentCommand:='%DIR ' + Copy(FileList.Strings[0], 5, Length(FileList.Strings[0])) + '%';
      ClientSocket.Socket.SendText(LastSentCommand);
    end;

    FileList.Delete(0); // Удаление после отправки
  end;
  
  // Все файлы переданы
  if FileList.Count = 0 then begin
    ProgressBar.Visible:=false;
    StatusBar.SimpleText:=' ' + IDS_SUCCESS_SENT_FILES;
    AbortBtn.Enabled:=false;
    FileList.Clear;
  end;
end;

procedure TMain.ServerSocketClientError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  if Application.Terminated or (csDestroying in ComponentState) then begin
    case ErrorCode of
      10061: StatusBar.SimpleText:=' ' + IDS_FAIL_CONNECT;
    else
      StatusBar.SimpleText:=' ' + IDS_CONNECTION_LOST;
    end;
    ErrorCode:=0;
    Exit;
  end;
  StopRequest:=true;
  SendPermission:=PermissionMissing;
  case ErrorCode of
    10061: StatusBar.SimpleText:=' ' + IDS_FAIL_CONNECT;
  else
    StatusBar.SimpleText:=' ' + IDS_CONNECTION_LOST;
  end;
  ErrorCode:=0;
  ReceivedReset;

  if Assigned(ReceivedFileStream) then // Очищаем незавершённый приём
    FreeAndNil(ReceivedFileStream);

  if (CurReceivingFile <> '') and (FileExists(SavePath + CurReceivingFile)) and
     (GetFileSize(SavePath + CurReceivingFile) <> ReceivedFileSize) then
    DeleteFile(SavePath + CurReceivingFile);
end;

procedure TMain.AboutBtnClick(Sender: TObject);
begin
  Application.MessageBox(PChar(Caption + ' 1.0.1' + #13#10 +
  IDS_LAST_UPDATE + ': 29.03.26' + #13#10 +
  'https://r57zone.github.io' + #13#10 +
  'r57zone@gmail.com'), PChar(IDS_ABOUT_TITLE), MB_ICONINFORMATION);
end;

procedure TMain.ExitBtnClick(Sender: TObject);
begin
  Close;
end;

procedure TMain.ServerSocketClientDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  if Application.Terminated or (csDestroying in ComponentState) then
    Exit;
  ReceivedReset;

  if Assigned(ReceivedFileStream) then // Очищаем незавершённый приём
    FreeAndNil(ReceivedFileStream);

  if (CurReceivingFile <> '') and ( FileExists(SavePath + CurReceivingFile) )  and
     ( GetFileSize( SavePath + CurReceivingFile) <> ReceivedFileSize ) then
    DeleteFile(SavePath + CurReceivingFile);
end;

procedure TMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  StopRequest:=true;
  SendPermission:=PermissionMissing;
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

{procedure TMain.SendFileInChunks(const FilePath: string);
const
  ChunkSize = 32768; // 32 KB
var
  FileStream: TFileStream;
  Buffer: array[0..32767] of Byte;
  BytesRead: Integer;
begin
  FileStream:=TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
  try
    while FileStream.Position < FileStream.Size do begin
      if StopRequest then Break;
      BytesRead:=FileStream.Read(Buffer, ChunkSize);
      ClientSocket.Socket.SendBuf(Buffer, BytesRead);
      Application.ProcessMessages; // даём UI обновиться
    end;
  finally
    FileStream.Free;
  end;
end;}

end.
