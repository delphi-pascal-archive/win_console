library Example;


uses
  windows,messages;

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

var
  WinConsulOptions:^TOptions;


//здесь все сообщения главного окна хистори
function PluginWindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
begin
 //фильтрация сообщений
case msg of
 wm_create: ;//консоль (окно) только-только создаётся
 wm_destroy: ;//консоль умирает
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
         if buff='test' then MessageBox(Hwn,'Text','Caption',MB_OK);
         if buff='load' then ;
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
p.name:=     'plugin: Example';
p.version:=  1.0;
p.comment:=  'Created by VirEx (c) for WinConsul';

result:=true;//инициализация прошла успешно
end;

exports
 InitPlugin;


begin
end.

