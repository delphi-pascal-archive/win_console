library AliasManager;


uses
  windows,messages,Classes,Sysutils,ShellApi;

type
  TPluginInfo = record
  
  //ниже то что WinConsul передаст нашему (этому) плагину
  ConsoleWindowProc:Pointer;//консольная (окно консоли) процедура обработки сообщений от ОС
  ConsoleEditProc:Pointer;  //консольная (поле ввода консоли) процедура обработки сообщений от ОС
  Options:Pointer;          //это настройки консоли (доступные плагину)

  signature:PChar;          //реализуется в будущих версиях

  //ниже то, что плагин должен сам заполнять для WinConsul
  name:string;
  version:double;
  comment:string;

  //используется только WinConsul
  hModulePlugin:THandle;  //для загрузки/выгрузки плагина - его хэндл (модуль)
 end;

type
  TRgb = record
  r,g,b:byte;
  ir,ig,ib:integer;
  end;
  
type
 //опции WinConsul
 TOptions = record
 speed:integer;    //значение, скорость сворачивания окна, если отрицательное, то окно сворачивается
 value:integer;    //высота окна
 divider:integer; //часть высоты монитора, т.е. высота консоли будет вычисляться как maxXSize div divider
 transparency:integer;//процент прозрачности окна
 HistoryFont,
 EditFont:TLogFont;
 HistoryColor:TRGB;
 ConsoleIsUp:boolean;//=true; //консоль выезжает сверху если true, иначе снизу
 InConsoleMode:string;//=' [in console mode]';//[31.10.2005] уведомление о том что команда выполнилась в режиме CMD (консоли)
 UseIEHistory:boolean;//=true;
 HistoryLinesCout:byte; //количество строк истории команд
 HistoryLines:array of PChar; //строки истории
 HistoryEdit:array of PChar;//история для автоввода
 HistoryEditCout:byte; //количество строк истории команд
 AboutF1:array of PChar;
end;

type
  TOnShowWindow=procedure;

const
  AliasesFileName='Plugins\Aliases.txt';

var
  WinConsulOptions:^TOptions;
  OnShowWindow:TOnShowWindow;
  AliasesList:TStringList;
  ErrorLoadAliases:boolean;
function RunApp(command_:Pchar):boolean;
var
i:integer;
command,params:string;
GetParams:boolean;
begin
params:='';
command:='';
GetParams:=false;
i:=0;

//разделяем на команду и параметры
while i<Length(command_) do begin
if GetParams then params:=params+command_[i] else
if command_[i]<>' ' then command:=command+command_[i];
if command_[i]= ' ' then GetParams:=true;
inc(i);
end;

result:=(31<ShellExecute(0,'open',PChar(command),PChar(params),nil,1));
end;

function GetCommand(s:string):string;
var
  i:integer;
  str:string;
begin
for i:=1 to Length(s) do begin
if s[i]=' ' then break;
str:=str+s[i];
end;
result:=str;
end;

// выводит слово заключенное в leftChar и RigthChar
function GetParam(str,leftChar,RigthChar:string):string;
var
  Tstart,Tend,i:integer;
  s:string;
begin
result:='';
s:='';
Tstart:=pos(LeftChar,str)+1;//находим самую левую кавычку

i:=Length(str);
while i>0 do begin
if str[i]=RigthChar then break;
dec(i);
end;
Tend:=i;                    //самая правая кавычка


i:=Tstart;
while i<Tend do begin
s:=s+str[i];
inc(i);
end;

result:=s;//copy(str,Tstart,Tend);
end;

procedure AddHistory(s:PChar;var h:array of PChar);
var
  i:integer;
begin
//High - количество элементов в массиве
if High(h)<2 then exit;
i:=0;//идем сверху вниз
while i<High(h) do begin
  h[i]:=h[i+1];
  inc(i);
end;
h[High(h)]:=s;
end;


procedure LoadAliases(FileName:string);
var
  i:integer;
  s_:string;
  s:PChar;
begin
try
AliasesList.LoadFromFile(FileName);
except
ErrorLoadAliases:=true;
exit;
end;

//добавляем в автоввод
for i:=0 to AliasesList.Count-1 do begin
s_:=GetCommand(AliasesList[i]);
GetMem(s,Length(s_));
//move(s_,s^,Length(s_));
s:=PChar(s_+#0);
AddHistory(s, WinConsulOptions.HistoryEdit);
end;
end;

//здесь все сообщения главного окна хистори
function PluginWindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
begin
 //фильтрация сообщений
case msg of
 wm_create: begin
            AliasesList:=TStringList.Create;
            LoadAliases(AliasesFileName);//консоль (окно) только-только создаётся
            end;
 wm_destroy:begin
            AliasesList.Clear;
            AliasesList.Free;
            end;//консоль умирает
end;//msg
end;


//здесь все сообщения поля ввода
function PluginEditProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
var
  buff,s:PChar;
  i:integer;
begin
 //фильтрация сообщений
case msg of
  //событие нажатия клавиши
  wm_KeyDown: begin
      //смотрим что нажали
      case wpr of
        //Enter
        vk_return:begin
         if ErrorLoadAliases then exit;
         getmem(buff,255);
         SendMessage(Hwn,wm_gettext,255,integer(buff));//получаем строку из поля ввода
         for i:=0 to AliasesList.Count-1 do
          if GetCommand(AliasesList[i])=buff then
            if RunApp(PChar(GetParam(AliasesList[i],'"','"'))) then begin
             GetMem(s,Length(GetCommand(AliasesList[i])));
             s:=PChar(GetCommand(AliasesList[i])+' [alias]');
             AddHistory(s, WinConsulOptions.HistoryLines);
             SendMessage(FindWindow('DX',nil),wm_paint,0,0);//перерисовка хистори
             OnShowWindow; //анимация закрытия
             result:=1;// предотвращаем дальнейшую обработку команды WinConsul
            end;
         //result:=1;//говорим полю ввода WinConsul чтобы не обрабатывала далее это сообщение (vk_return)
        end; //vk_return
     end; //wpr
 end;//wm_KeyDown
end;//msg
end;

//главная функция инициализации плагина
function InitPlugin(h:THandle;var p:TPluginInfo):boolean;export;
begin
p.ConsoleWindowProc:=@PluginWindowProc;//получаем процедуру обработки окна консоли от WinConsul
p.ConsoleEditProc:=@PluginEditProc;//получаем процедуру обработки поля ввода от WinConsul
WinConsulOptions:=p.Options; //получаем от WinConsul опции/настройки
p.signature:='WinConsulPlugin';
p.name:=     'plugin: AliasManager';
p.version:=  1.001;
p.comment:=  'Created by VirEx (c) for WinConsul';
//DrawHistory:=GetProcAddress(h,'DrawHistory');
OnShowWindow:=GetProcAddress(h,'OnShowWindow');
ErrorLoadAliases:=false;

result:=true;//инициализация прошла успешно
end;

exports
 InitPlugin;


begin
end.

