library Options;


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
 //опции WinConsul, мы их будем загружать для WinConsul и сохранять
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
 EditFontColor:TRgb;
 HistoryFontColor:TRgb;
end;

const
  //файл для сохранения/чтения опций
  OptionsFileName='Plugins\WinConsulOptions.xml';

var
  WinConsulOptions:^TOptions;


//загружаем опции
procedure LoadOptions(FileName:string);
var
  FindData: TWin32FindData;
  //i:integer;
begin

//если нет файла то выход
if FindFirstFile(PChar(FileName), FindData)=INVALID_HANDLE_VALUE then exit;

CreateXML;

LoadXML(FileName);

{
for i:=0 to GetNodesCount(['main','AboutF1']) do begin
try
AddHistory(PChar(GetNodeText(['main','AboutF1',Variant(char(i+65))])),WinConsulOptions.AboutF1);
finally
end;
end;
}
WinConsulOptions.ConsoleIsUp:=Boolean(GetNodeVariant(['main','ConsoleIsUp']));
WinConsulOptions.speed:=-Integer(GetNodeVariant(['main','speed']));
WinConsulOptions.transparency:=Integer(GetNodeVariant(['main','transparency']));
WinConsulOptions.divider:=Integer(GetNodeVariant(['main','divider']));
WinConsulOptions.HistoryLinesCout:=Integer(GetNodeVariant(['main','HistoryLinesCout']));
WinConsulOptions.HistoryEditCout:=Integer(GetNodeVariant(['main','HistoryEditCout']));
WinConsulOptions.UseIEHistory:=Boolean(GetNodeVariant(['main','UseIEHistory']));
WinConsulOptions.HistoryColor.r:=Integer(GetNodeVariant(['main','HistoryColor','r']));
WinConsulOptions.HistoryColor.g:=Integer(GetNodeVariant(['main','HistoryColor','g']));
WinConsulOptions.HistoryColor.b:=Integer(GetNodeVariant(['main','HistoryColor','b']));
WinConsulOptions.EditFont.lfHeight:=Integer(GetNodeVariant(['main','EditFont','lfHeight']));
WinConsulOptions.EditFont.lfWeight:=Integer(GetNodeVariant(['main','EditFont','lfWeight']));
//EditFont.lfFaceName:=AnsiChar(GetNodeVariant(['main','EditFont','lfFaceName']));
WinConsulOptions.HistoryFont.lfHeight:=Integer(GetNodeVariant(['main','HistoryFont','lfHeight']));
WinConsulOptions.HistoryFont.lfWeight:=Integer(GetNodeVariant(['main','HistoryFont','lfWeight']));
//EditFont.lfFaceName:=AnsiChar(GetNodeVariant(['main','EditFont','lfFaceName']));

WinConsulOptions.HistoryFontColor.r:=Integer(GetNodeVariant(['main','HistoryFontColor','r']));
WinConsulOptions.HistoryFontColor.g:=Integer(GetNodeVariant(['main','HistoryFontColor','g']));
WinConsulOptions.HistoryFontColor.b:=Integer(GetNodeVariant(['main','HistoryFontColor','b']));

DestroyXML;
end;

//сохраняем настройки
procedure SaveOptions(FileName:string);
//var
  //i:integer;
begin

CreateXML;//очищаем xml

CreateNodeText('main','');//главная ветка

//добавим аттрибуты
CreateAttribute(['main'],'app','WinConsul');//главная ветка
CreateAttribute(['main'],'creater','Saver/Loader options');//главная ветка
CreateAttribute(['main'],'ver','1.xxx');//главная ветка

//CreateAttribute(['main'],'comment',p.comment);//главная ветка
{
CreateNodeText(['main'],'AboutF1','');
for i:=0 to length(WinConsulOptions.AboutF1)-1 do
  CreateNodeText(['main','AboutF1'],Variant(char(i+65)),WinConsulOptions^.AboutF1[i]);
}
CreateNodeText(['main'],'ConsoleIsUp',Variant(WinConsulOptions.ConsoleIsUp)) ;
CreateNodeText(['main'],'UseIEHistory',Variant(WinConsulOptions.UseIEHistory));
CreateNodeText(['main'],'speed',Variant(WinConsulOptions.speed));
CreateNodeText(['main'],'transparency',Variant(WinConsulOptions.transparency));
CreateNodeText(['main'],'divider',Variant(WinConsulOptions.divider));
CreateNodeText(['main'],'HistoryLinesCout',Variant(WinConsulOptions.HistoryLinesCout));
CreateNodeText(['main'],'HistoryEditCout',Variant(WinConsulOptions.HistoryEditCout));
CreateNodeText(['main'],'HistoryColor','');
CreateNodeText(['main','HistoryColor'],'r',Variant(WinConsulOptions.HistoryColor.r));
CreateNodeText(['main','HistoryColor'],'g',Variant(WinConsulOptions.HistoryColor.g));
CreateNodeText(['main','HistoryColor'],'b',Variant(WinConsulOptions.HistoryColor.b));
CreateNodeText(['main'],'HistoryFont','');
CreateNodeText(['main','HistoryFont'],'lfHeight',Variant(WinConsulOptions.HistoryFont.lfHeight));
CreateNodeText(['main','HistoryFont'],'lfWeight',Variant(WinConsulOptions.HistoryFont.lfWeight));
//CreateNodeText(['main','HistoryFont'],'lfFaceName',HistoryFont.lfFaceName);
CreateNodeText(['main'],'HistoryFontColor','');
CreateNodeText(['main','HistoryFontColor'],'r',Variant(WinConsulOptions.HistoryFontColor.r));
CreateNodeText(['main','HistoryFontColor'],'g',Variant(WinConsulOptions.HistoryFontColor.g));
CreateNodeText(['main','HistoryFontColor'],'b',Variant(WinConsulOptions.HistoryFontColor.b));
CreateNodeText(['main'],'EditFont','');
CreateNodeText(['main','EditFont'],'lfHeight',Variant(WinConsulOptions.EditFont.lfHeight));
CreateNodeText(['main','EditFont'],'lfWeight',Variant(WinConsulOptions.EditFont.lfWeight));
//CreateNodeText(['main','EditFont'],'lfFaceName',EditFont.lfFaceName);


SaveXML(FileName);

DestroyXML;
end;


function PluginWindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
begin
 //фильтрация сообщений
case msg of
 wm_create: LoadOptions(OptionsFileName);//консоль (окно) только-только создаётся
 wm_destroy: SaveOptions(OptionsFileName);//консоль умирает
end;//msg
end;

{
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
         if buff='save' then SaveOptions(OptionsFileName);
         if buff='load' then LoadOptions(OptionsFileName);
        end; //vk_return
     end; //wpr
 end;//wm_KeyDown
end;//msg
end;
}

function InitPlugin(h:THandle;var p:TPluginInfo):boolean;export;
begin
p.ConsoleWindowProc:=@PluginWindowProc;//получаем процедуру обработки окна консоли от WinConsul
//p.ConsoleEditProc:=@PluginEditProc;
WinConsulOptions:=p.Options; //получаем от WinConsul опции/настройки
p.signature:='WinConsulPlugin';
p.name:=     'plugin: Saver/Loader options';
p.version:=  1.001;
p.comment:=  'Created by VirEx (c) for WinConsul';

result:=true;
end;

exports
 InitPlugin;


begin
end.

