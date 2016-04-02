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
  protected
    procedure WMDropFiles (var Msg: TMessage); message wm_DropFiles;
  private
    procedure WriteFile(Text:string);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  ClMS:TMemoryStream;
  RcvFlsRep,GdCFls:integer;

  SrFileName,Path,Address:string;
  SrSize,SrFlRcvCnt:integer;
  Receive:boolean;
  SrMS:TMemoryStream;
  AlwRcvFls:boolean;

  AllwLs:TStringList;

implementation

{$R *.dfm}

function GetSpecialPath(CSIDL: word): string;
var
s:string;
begin
SetLength(s, MAX_PATH);
if not SHGetSpecialFolderPath(0, PChar(s), CSIDL, true)
then s:='';
result:=PChar(s);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
Ini:TIniFile;
begin
Address:=ParamStr(1);
Ini:=TIniFile.Create(ExtractFilePath(paramstr(0))+'setup.ini');
Path:=Ini.ReadString('Main','Path','');
if Trim(Path)='' then Path:=GetSpecialPath(CSIDL_DESKTOP);
Ini.Free;
if FileExists(ExtractFilePath(paramstr(0))+'Allow.txt') then begin AllwLs:=TStringList.Create; AllwLs.LoadFromFile(ExtractFilePath(paramstr(0))+'Allow.txt'); end;
Application.Title:=Caption;
DragAcceptFiles(Form1.Handle,true);
ServerSocket1.Active:=true;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
if Assigned(AllwLs) then AllwLs.Free;
if ClientSocket1.Active then ClientSocket1.Active:=false;
if ServerSocket1.Active then ServerSocket1.Active:=false;
end;

procedure TForm1.WMDropFiles(var Msg: TMessage);
var
i, Amount, Size, Count:integer;
Filename: PChar; BreakAll:boolean;

P:^Byte;
begin

if Trim(Address)='' then InputQuery('Sync Files','Введите IP адрес:',Address);
if Trim(Address)='' then BreakAll:=true;

ClientSocket1.Host:=Address;
StatusBar1.SimpleText:=' Подключение';
if ClientSocket1.Active=false then begin RcvFlsRep:=0; ClientSocket1.Active:=true; end;

BreakAll:=false;
Count:=0;
GdCFls:=0;

while RcvFlsRep<>1 do begin
if (RcvFlsRep=2) or (RcvFlsRep=3) then begin BreakAll:=true; break; end;
Application.ProcessMessages;
end;

ProgressBar1.Visible:=true;

inherited;
Amount:=DragQueryFile(Msg.WParam, $FFFFFFFF, Filename, 255);
for i:=0 to (Amount - 1) do begin

if BreakAll then break;

Size:=DragQueryFile(Msg.WParam, i, nil, 0) + 1;
Filename:=StrAlloc(Size);
DragQueryFile(Msg.WParam, i, Filename, Size);
inc(Count);

StatusBar1.SimpleText:=' Идет передача файлов ('+IntToStr(i+1)+' из '+IntToStr(Amount)+')';

if FileExists(StrPas(Filename)) then begin

ClMS:=TMemoryStream.Create;
ClMS.LoadFromFile(StrPas(Filename));

//FloatToStrF(ClMS.Size / 1024,fffixed,9,2)+' Мб'
ClientSocket1.Socket.SendText('STARTSENDFILE:'+ExtractFileName(StrPas(Filename))+'@'+IntToStr(ClMS.Size)+';');
ClMS.Position:=0;
P:=ClMS.Memory;
ClientSocket1.Socket.SendBuf(P^, ClMS.Size);

while (Count<>GdCFls) do begin
Application.ProcessMessages;
if RcvFlsRep=3 then begin BreakAll:=true; break; end;
end;

end;
StrDispose(Filename);
end;

//if DirectoryExists(StrPas(Filename)) then 

DragFinish(Msg.WParam);

case RcvFlsRep of
1: if Count=GdCFls then StatusBar1.SimpleText:=' Все файлы успешно переданы';
2: StatusBar1.SimpleText:=' Пользователь не одобрил передачу файлов';
3: StatusBar1.SimpleText:=' Не удалось подключиться';
end;

ProgressBar1.Visible:=false;
end;

function asmIsNumb(s: string): boolean;
asm // eax->s ; Result->eax
	push	esi
  mov   esi,eax         // esi <- s
  mov   ecx,[eax-4]     // ecx <- Length(s)
  cld                   // inc edi
@@Comp:
  lodsb                 // al <- s[si] ; si <- si+1
  cmp   al,'0'
  jb    @@Fail          // if al<'0'
  cmp   al,'9'
  ja    @@Fail          // if al>'9'
  loop  @@Comp          // if cx<>0 ; cx <- cx-1;
  mov   eax,1           // TRUE
  jmp   @@Exit
@@Fail:
  xor   eax,eax         // FALSE
@@Exit:
  pop   esi
end;

procedure TForm1.ClientSocket1Read(Sender: TObject;
  Socket: TCustomWinSocket);
var
RcvText:string;
begin
RcvText:=Socket.ReceiveText;

if RcvText='ALLOWRECEIVEFILES' then RcvFlsRep:=1;

if RcvText='DISALLOWRECEIVEFILES' then RcvFlsRep:=2;

if (copy(RcvText,1,12)='PROGRESSBAR:') and (length(RcvText)<16) then if asmIsNumb(copy(RcvText,13,length(RcvText)-12)) then ProgressBar1.Position:=StrToInt(copy(RcvText,13,length(RcvText)-12));

if pos('ENDSENDFILE',RcvText)>0 then begin inc(GdCFls); ClMS.Free; end;
end;

procedure TForm1.ClientSocket1Error(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
case ErrorCode of
10061: StatusBar1.SimpleText:=' Не удалось подключиться';
else StatusBar1.SimpleText:=' Подключение потеряно';
end;
RcvFlsRep:=3;
ErrorCode:=0;
ClientSocket1.Active:=false;
end;

procedure TForm1.StatusBar1Click(Sender: TObject);
begin
Application.MessageBox('eFile 0.2'+#13#10+'https://github.com/r57zone'+#13#10+'Последнее обновление: 02.04.2016','О программе...',0);
end;

procedure TForm1.ClientSocket1Disconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
RcvFlsRep:=3;
end;

procedure TForm1.ServerSocket1ClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
if ServerSocket1.Socket.ActiveConnections=1 then begin
AlwRcvFls:=false;
SrFlRcvCnt:=0;
if Assigned(AllwLs) then if pos(Socket.RemoteAddress,AllwLs.Text)>0 then begin
AlwRcvFls:=true; ServerSocket1.Socket.Connections[0].SendText('ALLOWRECEIVEFILES'); end else
case MessageBox(Handle,Pchar('Разрешить подключение '+Socket.RemoteHost+' '+Socket.RemoteAddress),'Sync Files',35) of
6: begin AlwRcvFls:=true; ServerSocket1.Socket.Connections[0].SendText('ALLOWRECEIVEFILES'); end;
7: Socket.Close;
2: Socket.Close;
end;
end else Socket.Close;
end;

procedure TForm1.ServerSocket1ClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
var
RcvText:string;
begin
if AlwRcvFls then begin
RcvText:=Socket.ReceiveText;
if Receive then WriteFile(RcvText) else
if copy(RcvText,1,14)='STARTSENDFILE:' then begin
SrMS:=TMemoryStream.Create;
delete(RcvText,1,14);
SrFileName:=copy(RcvText,1,pos('@', RcvText)-1);
delete(RcvText,1,Pos('@',RcvText));
SrSize:=StrToInt(copy(RcvText,1,pos(';',RcvText)-1));
delete(RcvText,1,pos(';',RcvText));
StatusBar1.SimpleText:=' Идет прием файла '+SrFileName;
Receive:=true;
WriteFile(RcvText);
end;
end;
end;

procedure TForm1.WriteFile(Text:string);
begin
if SrMS.Size<SrSize then
SrMS.Write(Text[1],length(Text));
if not ProgressBar1.Visible then ProgressBar1.Visible:=true;
ProgressBar1.Position:=SrMS.Size*100 div SrSize;
ServerSocket1.Socket.Connections[0].SendText('PROGRESSBAR:'+IntToStr(ProgressBar1.Position));
sleep(5);
if SrMS.Size=SrSize then begin
Receive:=false;
ServerSocket1.Socket.Connections[0].SendText('ENDSENDFILE');
SrMS.Position:=0;
SrMS.SaveToFile(Path+'\'+SrFileName);
SrMS.Free;
inc(SrFlRcvCnt);
ProgressBar1.Visible:=false;
StatusBar1.SimpleText:=' Файлов принято: '+IntToStr(SrFlRcvCnt);
end;
end;

end.
