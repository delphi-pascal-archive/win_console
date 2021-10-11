library GetWeather;


uses
  windows,messages,UseXML;

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
TDrawHistory=procedure(DC:HDC;var h:array of PChar); 

var
  WinConsulOptions:^TOptions;
  DrawHistory:TDrawHistory;

function GetCommand(command_:string):string;
var
  i:integer;
begin
i:=1;
//разделяем на команду и параметры
while i<Length(command_) do begin
if command_[i]<>' ' then result:=result+command_[i] else exit;
inc(i);
end;
end;

function GetParam(command_:string):string;
var
  i:integer;
  GetParams:boolean;
  s:string;
begin
s:='';
GetParams:=false;
i:=1;
//разделяем на команду и параметры
while i<Length(command_)+1 do begin
if GetParams then s:=s+command_[i];
if command_[i]= ' ' then GetParams:=true;
inc(i);
end;
result:=s;//или PChar(s);
end;

procedure AddHistory(s:string;var h:array of PChar);
var
  i:integer;
  str:PChar;
begin
//High - количество элементов в массиве
if High(h)<2 then exit;
i:=0;//идем сверху вниз
while i<High(h) do begin
  h[i]:=h[i+1];
  inc(i);
end;
s:=s+#0;//обязательно добавляем иначе будут кракозябры
getmem(str,Length(s));
CopyMemory(str,PChar(s),Length(s));
h[i]:=str;
end;


procedure GetWeatherInfo(City:string);
var
  URL,CityID,s:string;
begin
if City='' then exit;

//находим ID города
URL:='http://xoap.weather.com/search/search?where='+City+#0;

//для теста
if City='last' then URL:='LastWeatherCityID.xml';

LoadXML(URL);

CityID:=GetNodeItemText(['search','loc'],'id');

if CityID='' then begin
s:=City+' is not found';
AddHistory(s,WinConsulOptions.HistoryLines);
exit;
end;
//SaveXML('LastWeatherCityID.xml');
//загружаем инфу по ID города
URL:='http://xoap.weather.com/weather/local/'+CityID+'?cc=*&dayf=0&prod=xoap&link=xoap&par=1006341644&key=0647abc97052c741&unit=m'+#0;

if City='last' then URL:='LastWeatherInfo.xml'; //- для теста

LoadXML(URL);

SaveXML('LastWeatherInfo.xml');

 //инфа
 s:='город = ' +GetNodeText(['weather','loc ','dnam']);
 AddHistory(s,WinConsulOptions.HistoryLines);

 //s:=s+'восход = ' + GetNodeVariant(['weather','loc ','sunr']);
 //s:=s+'заход  = ' + GetNodeVariant(['weather','loc ','suns']);
 //s:=s+'часовой пояс = '+GetNodeVariant(['weather','loc ','zone']);
 //s:=s+'локальное время = ' + GetNodeVariant(['weather','cc','lsup']);

 //if integer(GetNodeVariant(['weather','cc','tmp']))<>0 then
 //s_:='температура С = ' + GetNodeVariant(['weather','cc','tmp'])
 //else
 //s_:='температура С = 0';
 s:='температура С = ' + GetNodeText(['weather','cc','tmp']);
 //s:=PChar('температура = ' +GetNodeText(['weather','cc','tmp'])+#0);
 AddHistory(s,WinConsulOptions.HistoryLines);

 //s:=s+'погода = ' + GetNodeTextFromID(['//weather','//cc'],4);

 s:='давление рт.ст.= '+ GetNodeText(['weather','cc','bar','r']);
 //s:=PChar('давление рт.ст.= '+GetNodeText(['weather','cc','bar','r'])+#0);
 AddHistory(s,WinConsulOptions.HistoryLines);

 //s:=s+'давление = '+ GetNodeText(['//weather','//cc','//bar','//d']);

 s:='ветер м/c = '+ GetNodeText(['weather','cc','wind','s'])+#0;
 //s:=PChar('ветер м/c = '+GetNodeText(['weather','cc','wind','s'])+#0);
 AddHistory(s,WinConsulOptions.HistoryLines);

 s:='направление = '+GetNodeText(['weather','cc','wind','t']);
 //s:=PChar('направление = '+GetNodeText(['weather','cc','wind','t'])+#0);
 AddHistory(s,WinConsulOptions.HistoryLines);

 //s:=s+'видимость км.  = ' + GetNodeText(['//weather','//cc','//vis']);
 //s:=s+'луна = '+ GetNodeTextFromID(['//weather','//moon'],1);
 URL:='';
 CityID:='';
 s:='';
end;

//здесь все сообщения главного окна хистори
function PluginWindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
begin
 //фильтрация сообщений
case msg of
 wm_create: CreateXML;//консоль (окно) только-только создаётся
 wm_destroy:DestroyXML;//консоль умирает
end;//msg
end;


//здесь все сообщения поля ввода
function PluginEditProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
var
  buff:PChar;
begin
 //фильтрация сообщений
case msg of
  //событие нажатия клавиши
  wm_KeyDown: begin
      //смотрим что нажали
      case wpr of
        //Enter
        vk_return:begin
         getmem(buff,255);
         SendMessage(Hwn,wm_gettext,255,integer(buff));//получаем строку из поля ввода
         if GetCommand(buff)='getWeather' then begin
            GetWeatherInfo(GetParam(buff));
            SendMessage(FindWindow('DX',nil),wm_paint,0,0);//перерисовка хистори
            sendmessage(getwindow(FindWindow('DX',nil),GW_CHILD	),WM_settext,0,0{integer(buff)});//перерисовывается поле ввода
            result:=1;//говорим полю ввода WinConsul чтобы не обрабатывала далее это сообщение (vk_return)
            end;
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
p.name:=     'plugin: GetWeather';
p.version:=  1.0;
p.comment:=  'Created by VirEx (c) for WinConsul';

//добавляем в автоввод
AddHistory(PChar('getWeather'),WinConsulOptions.HistoryEdit);

DrawHistory:=GetProcAddress(h,'DrawHistory');

result:=true;//инициализация прошла успешно
end;

exports
 InitPlugin;


begin
end.

