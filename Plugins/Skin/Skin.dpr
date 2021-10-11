library Skin;


uses
  windows,messages,JPEG,graphics;   

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

type
  TAlign=(aLeft,aCenter,aRight);//выравнивание картинки
  TMethod=(mNormal,mStretch);//метод рисования - нормальный или растянутый

const
  //файл для сохранения/чтения опций
  DefaultImageFileName='plugins\SkinImg.JPG';

type
TDrawHistory=procedure(DC:HDC;var h:array of PChar);

var
  WinConsulOptions:^TOptions;
  MyJPG : TJPEGImage;
  c:TCanvas;
  DrawHistory:TDrawHistory;
  MaxXSize,MaxYSize:integer;//
  ErrorLoadImage:boolean;

procedure LoadImage(FileName:string);
var
  FindData: TWin32FindData;
  //i:integer;
begin

//если нет файла то выход
if FindFirstFile(PChar(FileName), FindData)=INVALID_HANDLE_VALUE then begin
ErrorLoadImage:=true;
exit;
end;

try
MyJPG := TJPEGImage.Create;
c:=TCanvas.Create;
MyJPG.LoadFromFile(DefaultImageFileName);
except
ErrorLoadImage:=true;
//MyJPG.Free;
end;
end;

procedure FreeImage;
begin
c.Free;
MyJPG.Free;
end;

procedure DrawImage(H:hWnd;m:TMethod;a:TAlign;bColor:integer);
var
  DC:hDC;
  r:TRect;
  s:integer;//сдвиг слева для рисования не растянутого изображения
begin
DC:=GetDC(H);
c.Handle:=DC;

r.Left:=0; //отступ слева
r.Top:=0;//отступ сверху
r.Right:=MaxXSize;
r.Bottom:=(MaxXSize div WinConsulOptions.divider);

case m of
mStretch: ;
mNormal: begin

  //очищаем/заполняем WinConsul одним цветом
  {
  b:=CreateSolidBrush(bColor);
  //getwindowrect(h,r);   //здесь окно может быть не полностью развёрнуто поэтому заполняем сами
  FillRect(c.Handle,r,b);
  DeleteObject(b);
  }
  c.Brush.Color:=bColor;
  c.FillRect(r);

          case a of
          aLeft:   begin
                    r.Top:=0;
                    r.Left:= 0;
                    r.Right:=c.ClipRect.Right div 3;
                    r.Bottom:=c.ClipRect.Bottom;
                    end;
          aCenter: begin 
                    s:=(MaxXSize div 2);//середина окна
                    s:=s-(c.ClipRect.Right div 2)+(c.ClipRect.Right div 3);
                    r.Top:=0;
                    r.Left:= s;
                    r.Right:=s+(c.ClipRect.Right div 3);
                    r.Bottom:=c.ClipRect.Bottom;
                    end;
          aRight:  begin
                    s:=MaxXSize - (c.ClipRect.Right div 3);
                    //s:=s-(c.ClipRect.Right div 2)+(c.ClipRect.Right div 3);
                    r.Top:=0;
                    r.Left:= s;
                    r.Right:=s+(c.ClipRect.Right div 3);
                    r.Bottom:=c.ClipRect.Bottom;
                    end;
          end;
end;
end;


C.StretchDraw(r,MyJPG);

ReleaseDC(H,DC);
end;

function PluginWindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
var
  DC:hDC; //обязательно иначе если использовать только GetDC(Hwn), дексриптор не будет закрыт
begin
 //фильтрация сообщений
case msg of
 wm_create: LoadImage(DefaultImageFileName);//консоль (окно) только-только создаётся
 wm_destroy:FreeImage;
 wm_paint:  begin
             if ErrorLoadImage then exit;
             DC:=GetDC(Hwn);
             DrawImage(Hwn,mnormal,aRight,0{clNone});//рисуем наш скин
             DrawHistory(DC,WinConsulOptions.HistoryLines);//пишем хистори
             result:=1;//говорим WinConsul чтобы оно больше не обрабатывало это сообщение  (WM_PAINT), т.е. не перерисовывалось
             releaseDC(Hwn,DC);
             exit;
            end;
 wm_size: begin//если разрешение экрана поменяли
            MaxXSize:=GetSystemMetrics (SM_CXSCREEN);
            MaxYSize:=GetSystemMetrics (SM_CYSCREEN);
          end;
end;//msg
end;


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
        vk_Up: if not ErrorLoadImage then
                  //чтобы не изменял цветовую гамму - т.е. чтобы не было лишней перерисовки хистори (устраняет мигание)
                  if (GetKeyState ( VK_SHIFT )<0) then result:=1;
                //[17:14 02.11.2005] изменяем цветовую схему по цветам радуги :)
     end; //wpr
 end;//wm_KeyDown
end;//msg
end;


function InitPlugin(h:THandle;var p:TPluginInfo):boolean;export;
begin
p.ConsoleWindowProc:=@PluginWindowProc;//получаем процедуру обработки окна консоли от WinConsul
p.ConsoleEditProc:=@PluginEditProc;
WinConsulOptions:=p.Options; //получаем от WinConsul опции/настройки
p.signature:='WinConsulPlugin';
p.name:=     'plugin: Skin image';
p.version:=  1.001;
p.comment:=  'Created by VirEx (c) for WinConsul';
DrawHistory:=GetProcAddress(h,'DrawHistory');
ErrorLoadImage:=false;
result:=true;
end;

exports
 InitPlugin;


begin
end.

