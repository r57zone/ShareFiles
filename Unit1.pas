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
    LblInfo: TLabel;
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
    function AddDir(FolderPath: string): boolean;
    function AddFile(FilePath: string): boolean;
    function Send: boolean;
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

implementation

{$R *.dfm}

function GetFileSize(const FileName: string): int64;
var
  s: TSearchRec;
begin
   FindFirst(FileName, faAnyFile, s);
   Result:=(int64(s.FindData.nFileSizeHigh) * MAXDWORD) + int64(s.FindData.nFileSizeLow);
   FindClose(s);
end;

function IsNum(s: string): boolean;
asm
	push	esi
  mov   esi,eax
  mov   ecx,[eax-4]
  cld
@@Comp:
  lodsb
  cmp   al,'0'
  jb    @@Fail
  cmp   al,'9'
  ja    @@Fail
  loop  @@Comp
  mov   eax,1
  jmp   @@Exit
@@Fail:
  xor   eax,eax
@@Exit:
  pop   esi
end;

procedure TMain.FormCreate(Sender: TObject);
var
  Ini: TIniFile;
begin
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
  i, Amount, Size:integer;
  FileName: PChar;
  RunOnce:boolean;
begin
  if Trim(Address)='' then
    InputQuery(Caption, 'Введите IP адрес:', Address);

  if Trim(Address)='' then
    BreakAll:=true;

  ClientSocket.Host:=Address;
  StatusBar.SimpleText:=' Подключение';
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
    2: StatusBar.SimpleText:=' Пользователь не одобрил передачу файлов';
    3: StatusBar.SimpleText:=' Не удалось подключиться';
  end;

  //В случае отмены или неудачи выходим
  if BreakAll then
    Exit;

  ProgressBar.Visible:=true;

  //Обработка Drag & Drop
  inherited;
  Amount:=DragQueryFile(Msg.WParam, $FFFFFFFF, Filename, 255);
  for i:=0 to (Amount - 1) do begin
    Size:=DragQueryFile(Msg.WParam, i, nil, 0) + 1;
    Filename:=StrAlloc(Size);
    DragQueryFile(Msg.WParam, i, Filename, Size);

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
    if Copy(FileList.Strings[i], 1, 5) = 'FILE ' then inc(SendFilesCount);

  //Передаем количество файлов
  LastRequest:='%FILES_COUNT ' + IntToStr(SendFilesCount) + '%';
  ClientSocket.Socket.SendText(LastRequest);
end;

procedure TMain.ClientSocketRead(Sender: TObject;
  Socket: TCustomWinSocket);
var
  RcvText: string;
begin
  RcvText:=Socket.ReceiveText;

  //Последний запрос, в случае неудачной отправки или приема, можно запросить повторно
  if Pos('%LAST_REQUEST%', RcvText) > 0 then
    Socket.SendText(LastRequest);

  if Pos('%SUCESS_FILE%', RcvText) > 0 then begin
    Send;
    inc(SendedFilesCount);
  end;

  if Pos('%SUCESS_DIR%', RcvText) > 0 then
    Send;

  if Pos('%FILES_COUNT_OK%', RcvText) > 0 then
    Send;

  if Pos('%FILES_ALLOW_OK%', RcvText) > 0 then begin
    RcvFlsRep:=1;
    SendedFilesCount:=0;
  end;

  //Команда на передачу файла
  if Pos('%SEND%', RcvText) > 0 then begin
    ProgressBar.Position:=0;
    ProgressBar.Visible:=true;
    StatusBar.SimpleText:=' Идет передача файлов (' + IntToStr(SendedFilesCount) + ' из ' + IntToStr(SendFilesCount) + ')';
    ClientSocket.Socket.SendStream(TFileStream.Create(LastFile, fmOpenRead or fmShareDenyWrite));
  end;

  if (RcvText[1] = '%') and (RcvText[Length(RcvText)] = '%') then begin
    if Copy(RcvText, 1, 14) = '%PROGRESS_BAR ' then begin
      Delete(RcvText, 1, 14);
      RcvText:=Copy(RcvText, 1, Pos('%', RcvText) - 1);
      if IsNum(RcvText) then
        ProgressBar.Position:=StrToInt(RcvText);
    end;
  end;
end;

procedure TMain.ClientSocketError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  BreakAll:=true;
  case ErrorCode of
    10061: StatusBar.SimpleText:=' Не удалось подключиться';
  else
    StatusBar.SimpleText:=' Подключение потеряно';
  end;
  RcvFlsRep:=3;
  ErrorCode:=0;
end;

procedure TMain.StatusBarClick(Sender: TObject);
begin
  Application.MessageBox(PChar(Caption + ' 0.7.1' + #13#10 +
  'Последнее обновление: 31.07.2018' + #13#10 +
  'https://r57zone.github.io' + #13#10 +
  'r57zone@gmail.com'), 'О программе...', MB_ICONINFORMATION);
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
    case MessageBox(Handle, PChar('Разрешить подключение ' + Socket.RemoteHost + ' ' + Socket.RemoteAddress), PChar(Caption), 35) of
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
  iLen: integer;
  Bfr: Pointer;
  FName, RcvText: string;
begin
  //В случае отмены или неудачи выходим
  if BreakAll then begin
    Receive:=false;
    FStream.Free;
    ProgressBar.Visible:=false;
    StatusBar.SimpleText:=' Передача файлов прервана';
    Exit;
  end;

  //Прием файла
  if Receive then begin
    StatusBar.SimpleText:=' Идет прием файла (' + IntToStr(ReceivedFilesCount) + ' из ' + IntToStr(ReceiveFilesCount) + ')';
    iLen:=Socket.ReceiveLength;
    GetMem(Bfr, iLen);
    try
      Socket.ReceiveBuf(Bfr^, iLen);
      FStream.Write(Bfr^, iLen);
      ProgressBar.Position:=(FStream.Size*100) div FSize;
      Socket.SendText('%PROGRESS_BAR ' + IntToStr(ProgressBar.Position) + '%');

      if FStream.Size = FSize then begin //Завершаем если размер соответствует размеру оригигала
        Receive:=false;
        FStream.Free;
        Socket.SendText('%SUCESS_FILE%');
        inc(ReceivedFilesCount);
        if (ReceiveFilesCount = ReceivedFilesCount) then begin
          StatusBar.SimpleText:=' Все файлы успешно переданы';
          ReceivedFilesCount:=0;
          ProgressBar.Visible:=false;
          ProgressBar.Position:=0;
        end;
      end;
    finally
      FreeMem(Bfr);
    end;

  end else begin
    //Прием команд
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
            inc(ReceivedFilesCount);
            if (ReceiveFilesCount = ReceivedFilesCount) then begin
              StatusBar.SimpleText:=' Все файлы успешно переданы';
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
      Socket.SendText('%LAST_REQUEST%'); //Запрашиваем последний повторно, в случае неудачи

  end;

end;

//Добавление папок в список, рекурсивно
function TMain.AddDir(FolderPath: string): boolean;
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

  Result:=true;
end;

//Добавление файлов в список
function TMain.AddFile(FilePath: string): boolean;
begin
  Delete(FilePath, 1, Length(LocalPath));
  FileList.Add('FILE '+ FilePath);
  Result:=true;
end;

//Отправка файлов и папок поочередно
function TMain.Send: boolean;
begin
  //В случае отмены или неудачи выходим
  if BreakAll then begin
    StatusBar.SimpleText:=' Передача файлов прервана';
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
    StatusBar.SimpleText:=' Все файлы переданы';
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
    10061: StatusBar.SimpleText:=' Не удалось подключиться';
  else
    StatusBar.SimpleText:=' Подключение потеряно';
  end;
  RcvFlsRep:=3;
  ErrorCode:=0;
end;

end.
