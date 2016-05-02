unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ScktComp, StdCtrls, XPMan, ComCtrls, ShellAPI, ExtCtrls, IniFiles, ShlObj;

type
  TForm1 = class(TForm)
    ClientSocket1: TClientSocket;
    ServerSocket1: TServerSocket;
    XPManifest1: TXPManifest;
    ProgressBar1: TProgressBar;
    StatusBar1: TStatusBar;
    Label1: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ClientSocket1Read(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientSocket1Error(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure StatusBar1Click(Sender: TObject);
    procedure ClientSocket1Disconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ServerSocket1ClientConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ServerSocket1ClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure ServerSocket1ClientError(Sender: TObject;
      Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
      var ErrorCode: Integer);
  protected
    procedure WMDropFiles (var Msg: TMessage); message wm_DropFiles;
  private
    function AddDir(FolderPath:string):boolean;
    function AddFile(FilePath:string):boolean;
    function Send:boolean;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  LastRequest,LastFile,LocalPath,Path,Address:string;
  FileList,AllwLs:TStringList;
  SendFilesCount,SendedFilesCount:int64;
  RcvFlsRep:integer;
  AlwRcvFls:boolean;
  BreakAll,Receive:boolean;
  FSize,ReceiveFilesCount,ReceivedFilesCount:int64;
  FStream: TFileStream;

implementation

{$R *.dfm}

function xGetFileSize(const FileName: String):int64;
var
  s: TSearchRec;
begin
  FindFirst(FileName, faAnyFile, s);
  Result:=(Int64(s.FindData.nFileSizeHigh)*MAXDWORD)+Int64(s.FindData.nFileSizeLow);
  FindClose(s);
end;

function GetSpecialPath(CSIDL: word): string;
var
  s:string;
begin
  SetLength(s, MAX_PATH);
  if not SHGetSpecialFolderPath(0, PChar(s), CSIDL, true) then s:='';
  result:=PChar(s);
end;

function asmIsNumb(s: string): boolean;
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

procedure TForm1.FormCreate(Sender: TObject);
var
  Ini:TIniFile;
begin
  //Проверка на повторый запуск
  if FindWindow('TForm1', 'eFile') <> 0 then begin
  SetForegroundWindow(FindWindow('TForm1', 'eFile'));
  Halt;
  end;
  Caption:='eFile';
  //Адрес передачи по умолчанию
  Address:=ParamStr(1);

  Ini:=TIniFile.Create(ExtractFilePath(paramstr(0))+'setup.ini');
  ClientSocket1.Port:=Ini.ReadInteger('Main','Port',5371);
  ServerSocket1.Port:=Ini.ReadInteger('Main','Port',5371);
  Path:=Ini.ReadString('Main','Path','');
  if Trim(Path)='' then Path:=GetSpecialPath(CSIDL_DESKTOP);
  Ini.Free;
  if FileExists(ExtractFilePath(paramstr(0))+'Allow.txt') then begin AllwLs:=TStringList.Create; AllwLs.LoadFromFile(ExtractFilePath(paramstr(0))+'Allow.txt'); end;
  Application.Title:=Caption;
  DragAcceptFiles(Form1.Handle,true);
  FileList:=TStringList.Create;
  ServerSocket1.Active:=true;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if Assigned(AllwLs) then AllwLs.Free;
  FileList.Free;
  if ClientSocket1.Active then ClientSocket1.Active:=false;
  if ServerSocket1.Active then ServerSocket1.Active:=false;
end;

procedure TForm1.WMDropFiles(var Msg: TMessage);
var
  i, Amount, Size:integer;
  Filename: PChar;
  RunOnce:boolean;
begin
  if Trim(Address)='' then InputQuery(Caption,'Введите IP адрес:',Address);
  if Trim(Address)='' then BreakAll:=true;

  ClientSocket1.Host:=Address;
  StatusBar1.SimpleText:=' Подключение';
  if ClientSocket1.Active=false then ClientSocket1.Active:=true;

  BreakAll:=false;
  FileList.Clear;
  SendFilesCount:=0;
  RunOnce:=false;

  //Ждем разрешения на передачу файлов
  while RcvFlsRep<>1 do begin
    if (RcvFlsRep=2) or (RcvFlsRep=3) then begin BreakAll:=true; Break; end;
    Application.ProcessMessages;
  end;

  case RcvFlsRep of
    2: StatusBar1.SimpleText:=' Пользователь не одобрил передачу файлов';
    3: StatusBar1.SimpleText:=' Не удалось подключиться';
  end;

  //В случае отмены или неудачи выходим
  if BreakAll then Exit;

  ProgressBar1.Visible:=true;

  //Обработка Drag&Drop
  inherited;
  Amount:=DragQueryFile(Msg.WParam, $FFFFFFFF, Filename, 255);
  for i:=0 to (Amount - 1) do begin
    Size:=DragQueryFile(Msg.WParam, i, nil, 0) + 1;
    Filename:=StrAlloc(Size);
    DragQueryFile(Msg.WParam, i, Filename, Size);

    //В случае отмены или неудачи выходим
    if BreakAll then Exit;

    //Узнаем папку передаваемых файлов
    if RunOnce=false then begin LocalPath:=ExtractFilePath(StrPas(FileName)); RunOnce:=true; end;
    if Length(ExtractFilePath(StrPas(FileName)))<Length(LocalPath) then LocalPath:=ExtractFilePath(StrPas(FileName));


    if FileExists(StrPas(Filename)) then AddFile(StrPas(Filename)) else
      if DirectoryExists(StrPas(Filename)) then AddDir(StrPas(Filename));

    StrDispose(Filename);
  end;

  DragFinish(Msg.WParam);

  //Считаем количество файлов
  for i:=0 to FileList.Count-1 do
    if copy(FileList.Strings[i],1,5)='FILE ' then inc(SendFilesCount);

  //Передаем количество файлов
  LastRequest:='%FILES_COUNT '+IntToStr(SendFilesCount)+'%';
  ClientSocket1.Socket.SendText(LastRequest);
end;

procedure TForm1.ClientSocket1Read(Sender: TObject;
  Socket: TCustomWinSocket);
var
  RcvText:string;
begin
  RcvText:=Socket.ReceiveText;
  //Последний запрос, в случае неудачной отправки или приема, можно запросить повторно
  if pos('%LAST_REQUEST%',RcvText)>0 then Socket.SendText(LastRequest);

  if pos('%SUCESS_FILE%',RcvText)>0 then begin Send; inc(SendedFilesCount); end;
  if pos('%SUCESS_DIR%',RcvText)>0 then Send;
  if pos('%FILES_COUNT_OK%',RcvText)>0 then Send;

  if pos('%FILES_ALLOW_OK%',RcvText)>0 then begin RcvFlsRep:=1; SendedFilesCount:=0; end;

  //Команда на передачу файла
  if pos('%SEND%',RcvText)>0 then begin ProgressBar1.Position:=0; ProgressBar1.Visible:=true; StatusBar1.SimpleText:=' Идет передача файлов ('+IntToStr(SendedFilesCount)+' из '+IntToStr(SendFilesCount)+')'; ClientSocket1.Socket.SendStream(TFileStream.Create(LastFile, fmOpenRead or fmShareDenyWrite)); end;

  if (RcvText[1]='%') and (RcvText[Length(RcvText)]='%') then begin
    if copy(RcvText,1,14)='%PROGRESS_BAR ' then begin
      delete(RcvText,1,14);
      RcvText:=copy(RcvText,1,pos('%',RcvText)-1);
      if asmIsNumb(RcvText) then ProgressBar1.Position:=StrToInt(RcvText);
    end;
  end;
end;

procedure TForm1.ClientSocket1Error(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  BreakAll:=true;
  case ErrorCode of
    10061: StatusBar1.SimpleText:=' Не удалось подключиться';
  else StatusBar1.SimpleText:=' Подключение потеряно';
  end;
  RcvFlsRep:=3;
  ErrorCode:=0;
end;

procedure TForm1.StatusBar1Click(Sender: TObject);
begin
  Application.MessageBox('eFile 0.7'+#13#10+'https://github.com/r57zone'+#13#10+'Последнее обновление: 03.05.2016','О программе...',0);
end;

procedure TForm1.ClientSocket1Disconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
RcvFlsRep:=3;
end;

procedure TForm1.ServerSocket1ClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  //Разрешаем только одно подключение
  if ServerSocket1.Socket.ActiveConnections=1 then begin
    AlwRcvFls:=false;
    FStream:=nil;
    BreakAll:=false;
    Receive:=false;
    ReceivedFilesCount:=0;

  //Проверяем есть ли в списке "Allow.txt" адрес, чтобы не запрашивать подверждение
  if Assigned(AllwLs) then if pos(Socket.RemoteAddress,AllwLs.Text)>0 then begin
    AlwRcvFls:=true; ServerSocket1.Socket.Connections[0].SendText('%FILES_ALLOW_OK%'); end else
    case MessageBox(Handle,Pchar('Разрешить подключение '+Socket.RemoteHost+' '+Socket.RemoteAddress),PChar(Caption),35) of
      6: begin AlwRcvFls:=true; ServerSocket1.Socket.Connections[0].SendText('%FILES_ALLOW_OK%'); end;
      7: Socket.Close;
      2: Socket.Close;
    end;
  end else Socket.Close;
end;

//Количество символов в строке
function CountCharStr(Symb:char;Str:string):integer;
var
  i:integer;
begin
  Result:=0;
  for i:=1 to Length(Str) do
    if Str[i]=Symb then Result:=Result+1;
end;

procedure TForm1.ServerSocket1ClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
var
  iLen: Integer;
  Bfr: Pointer;
  FName,RcvText:string;
begin

  //В случае отмены или неудачи выходим
  if BreakAll then begin
    Receive:=false;
    FStream.Free;
    ProgressBar1.Visible:=false;
    StatusBar1.SimpleText:=' Передача файлов прервана';
    Exit;
  end;

  //Прием файла
  if Receive then begin
    StatusBar1.SimpleText:=' Идет прием файла ('+IntToStr(ReceivedFilesCount)+' из '+IntToStr(ReceiveFilesCount)+')';
    iLen:=Socket.ReceiveLength;
    GetMem(Bfr, iLen);
    try
      Socket.ReceiveBuf(Bfr^, iLen);
      FStream.Write(Bfr^, iLen);
      ProgressBar1.Position:=(FStream.Size*100) div FSize;
      Socket.SendText('%PROGRESS_BAR '+IntToStr(ProgressBar1.Position)+'%');

      if FStream.Size=FSize then begin //Завершаем если размер соответствует размеру оригигала
        Receive:=false;
        FStream.Free;
        Socket.SendText('%SUCESS_FILE%');
        inc(ReceivedFilesCount);
        if (ReceiveFilesCount=ReceivedFilesCount) then begin
          StatusBar1.SimpleText:=' Все файлы успешно переданы';
          ReceivedFilesCount:=0;
          ProgressBar1.Visible:=false;
          ProgressBar1.Position:=0;
        end;
      end;
    finally
      FreeMem(Bfr);
    end;

  end else begin
    //Прием команд
    RcvText:=Socket.ReceiveText;


    if (RcvText[1]='%') and (RcvText[Length(RcvText)]='%') and (CountCharStr('%',RcvText)=2) then begin

      //Создание папки
      if copy(RcvText,1,5)='%DIR ' then begin
        delete(RcvText,1,5);
        FName:=copy(RcvText,1,pos('%',RcvText)-1);
        if not (DirectoryExists(Path+'\'+FName)) then CreateDir(Path+'\'+FName);
        Socket.SendText('%SUCESS_DIR%');
      end;

      //Создание файла
      if copy(RcvText,1,6)='%FILE ' then begin
          delete(RcvText,1,6);
          FName:=copy(RcvText,1,pos('@',RcvText)-1);
          delete(RcvText,1,pos('@',RcvText));
          FSize:=StrToInt((copy(RcvText,1,pos('%',RcvText)-1)));
          FStream:=TFileStream.Create(Path+'\'+FName, fmCreate or fmShareDenyWrite);

          if FSize<>0 then Receive:=true else begin //Пустые файлы
            Receive:=false;
            FStream.Free;
            Socket.SendText('%SUCESS_FILE%');
            inc(ReceivedFilesCount);
            if (ReceiveFilesCount=ReceivedFilesCount) then begin
              StatusBar1.SimpleText:=' Все файлы успешно переданы';
              ReceivedFilesCount:=0;
              ProgressBar1.Visible:=false;
              ProgressBar1.Position:=0;
            end;
          end;

          //Разрешение на передачу файла
          Socket.SendText('%SEND%');
      end;

      //Количество файлов для передачи
      if copy(RcvText,1,13)='%FILES_COUNT ' then begin
        delete(RcvText,1,13);
        ReceiveFilesCount:=StrToInt(copy(RcvText,1,pos('%',RcvText)-1));
        Socket.SendText('%FILES_COUNT_OK%');
        ProgressBar1.Visible:=true;
      end;

    end else Socket.SendText('%LAST_REQUEST%'); //Запрашиваем последний повторно, в случае неудачи

  end;

end;

//Добавление папок в список, рекурсивно
function TForm1.AddDir(FolderPath: string): boolean;
var
  SR:TSearchRec; FolderPathNew:string;
begin
  //Отправляем название новой папки, без полного адреса
  FolderPathNew:=FolderPath;
  Delete(FolderPathNew,1,Length(LocalPath));
  FileList.Add('DIR '+FolderPathNew);

  if FolderPath[Length(FolderPath)]<>'\' then FolderPath:=FolderPath+'\';

  if FindFirst(FolderPath + '*.*', faAnyFile, SR) = 0 then begin
    repeat
      if (SR.Attr<>faDirectory) then AddFile(FolderPath+SR.Name); //Ищем файлы

      if (SR.Attr=faDirectory) and (SR.Name<>'.') and (SR.Name<>'..') then AddDir(FolderPath+SR.Name); //Ищем папки

    until FindNext(SR)<>0;
    FindClose(SR);
  end;

  Result:=true;
end;

//Добавление файлов в список
function TForm1.AddFile(FilePath: string): boolean;
begin
  Delete(FilePath,1,Length(LocalPath));
  FileList.Add('FILE '+FilePath);
  Result:=true;
end;

//Отправка файлов и папок поочередно
function TForm1.Send: boolean;
begin
  //В случае отмены или неудачи выходим
  if BreakAll then begin
    StatusBar1.SimpleText:=' Передача файлов прервана';
    Exit;
  end;

  //Список файлов и папок на отправку
  if FileList.Count>0 then begin
    if copy(FileList.Strings[0],1,5)='FILE ' then begin
      ProgressBar1.Position:=0;
      LastFile:=LocalPath+copy(FileList.Strings[0],6,Length(FileList.Strings[0]));
      LastRequest:='%FILE '+copy(FileList.Strings[0],6,Length(FileList.Strings[0]))+'@'+IntToStr(xGetFileSize(LocalPath+copy(FileList.Strings[0],6,Length(FileList.Strings[0]))))+'%';
      ClientSocket1.Socket.SendText(LastRequest);
    end;
    if copy(FileList.Strings[0],1,4)='DIR ' then begin
      ProgressBar1.Position:=0;
      LastRequest:='%DIR '+copy(FileList.Strings[0],5,Length(FileList.Strings[0]))+'%';
      ClientSocket1.Socket.SendText(LastRequest);
    end;
    FileList.Delete(0); //Удаление после отправки
  end;
  
  //Все файлы переданы
  if FileList.Count=0 then begin
    ProgressBar1.Visible:=false;
    StatusBar1.SimpleText:=' Все файлы переданы';
    FileList.Clear;
  end;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  //Разрешение на отмену
  if Key=VK_ESCAPE then BreakAll:=true;
end;

procedure TForm1.ServerSocket1ClientError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  BreakAll:=true;
  case ErrorCode of
    10061: StatusBar1.SimpleText:=' Не удалось подключиться';
  else StatusBar1.SimpleText:=' Подключение потеряно';
  end;
  RcvFlsRep:=3;
  ErrorCode:=0;
end;

end.
