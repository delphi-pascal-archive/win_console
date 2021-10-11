library Starsss;


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
   p:hpen;
   b:hbrush;
   dc:hdc;
   MaxXSize,MaxYSize:integer;
   
//const
  //WM_IDLE=WM_USER+4444;

//===============
type
  TPoint = packed record
    X, Y, Z, R, Phi: Double;
  end;

const
  NumStars = 2000; // Количество звёзд,
                   // управляет общей плотностью звёздного поля

  RangeY = 5000; // Максимальное расстояние от картинной плоскости до звезды,
                   // управляет плотностью звёзд в центре

  RangeR = 7000; // Максимальное радиальное удаление от луча зрения до звезды,
                   // управляет плотностью звёзд по краям

  Height = 500; // Высота наблюдателя,
                   // управляет положением центра изображения по вертикали

  Basis = 250; // Расстояние до картинной плоскости
                   // управляет соотношением количества звёзд в центре к их
                   // количеству по краям

  DeltaY = 10; // Шаг изменения координаты, управляет скоростью движения
  DeltaT = 0.02; // Приращение времени, управляет скоростью вращения
  Period1 = 0.1; // Период вращения звёзд
  Amplitude2 = 0.3; // Амплитуда вращательных колебаний звёзд
  Period2 = 1.0; // Период вращательных колебаний
  Period3 = 0.1; // Период изменения направления движения звёзд.


  Direction = 1; // Направление движения 1 - к наблюдателю, -1 - от него
var
 Stars : array [1..NumStars] of TPoint;
 Time: Double = 0;
 X0: Integer = 10;
 Y0: Integer = 100;
//===============


procedure InitializeStars;
var
  i: Integer;
begin
 Randomize;
 for i := 1 to NumStars do with Stars[i] do begin
  Y := Random(RangeY);
  R := RangeR - 2 * Random(RangeR);
  Phi := Random(628) / 100;
 end;
end;

procedure Perspective(const X, Y, Z, Height, Basis: Double; var XP, YP: Double);
var
 Den: Double;
begin
 Den:=Y+Basis;
 if Abs(Den)<1e-100 then Den:=1e-100;
 XP:=Basis*X/Den;
 YP:=(Basis*Z+Height*Y)/Den;
end;

procedure PaintStars(DC:hdc{Canvas:TCanvas});
var
 X, Y: Double;
 L, T: Integer;
 i: Integer;
 D: Double;
begin

//canvas.Handle:=GetDC(FindWindow('ShellTrayWnd',nil));
 for i := 1 to NumStars do begin
  //Application.ProcessMessages;
  with Stars[i] do begin
   D := Direction * sin (Period3 * Time);
   Y := Y - D * DeltaY;
   X := R * sin( (Period1 * Time + Phi) + Amplitude2 * cos (Period2 * time ));
   Z := R * cos( (Period1 * Time + Phi) + Amplitude2 * cos (Period2 * time ));
   if D > 0 then begin
    if Y < 0 then begin
     Y := RangeY;
     R := RangeR - 2 * Random(RangeR);
   // Phi := Random(628) / 100;
    end;
   end else begin
    if Y > RangeY then begin
     Y := 0;
     R := RangeR - 2 * Random(RangeR);
  // Phi := Random(628) / 100;
    end;
   end;
  end;
  Perspective(Stars[i].X, Stars[i].Y, Stars[i].Z, Height, Basis, X, Y);
  L := X0 + Round(X);
  T := Y0 - Round(Y);


  //Canvas.Pen.Color := clWhite;
  if Stars[i].Y < RangeY / 4 then begin
   Rectangle(dc,L, T, L+2, T+2);
  end else begin
   MoveToEx(dc,L+1, T+1,nil);
   LineTo(dc,L+1, T+1);
  end;

 end;

 Time := Time + DeltaT;
  
end;


//здесь все сообщения главного окна хистори
function PluginWindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
var
  r:Trect;

begin
 //фильтрация сообщений
case msg of
 wm_create: begin
            InitializeStars;//консоль (окно) только-только создаётся
            p:=CreatePen(ps_solid,2,rgb(255,255,255));
            b:=createsolidbrush(0);
            end;
 wm_destroy:begin//консоль умирает
            DeleteObject(p);
            DeleteObject(b);
            end;

 //wm_idle:  ; // это событие происходит когда WinConsul "простаивает", не в активном состоянии

 wm_size: begin
           MaxXSize:=GetSystemMetrics (SM_CXSCREEN);
           MaxYSize:=GetSystemMetrics (SM_CYSCREEN);
           X0 := MaxXSize div 2;
           Y0 := (MaxYSize div 2) * 3 div 2;
          end;

WM_ACTIVATE: begin
               if (lo(wPr)=WA_ACTIVE) then begin//если консоль выехала и активна то
                 dc:=GetDC(Hwn);
                 SetTimer(Hwn,99,85,nil)//делаем таймер
               end else begin
                 ReleaseDC(dc,hwn);
                 KillTimer(Hwn,99);//убираем таймер
               end;
             end;
WM_TIMER: begin
          if wpr<>99 then exit; //если это не наш таймер то выход
            selectobject(dc,p);
            //getwindowrect(hwn,r);
            r.Left:=0; //отступ слева
            r.Top:=0;//отступ сверху
            r.Right:=MaxXSize;
            r.Bottom:=(MaxXSize div WinConsulOptions.divider)-25;
            //selectobject(dc,b);
            fillrect(dc,r,b);
            PaintStars(dc);
            result:=1;
          end;
WM_PAINT: begin  //устраняем артефакты при первой прорисовке а также при изменении разрешения экрана
            //getwindowrect(hwn,r);
            r.Left:=0; //отступ слева
            r.Top:=0;//отступ сверху
            r.Right:=MaxXSize;
            r.Bottom:=(MaxXSize div WinConsulOptions.divider)-25;
            //selectobject(dc,b);
            fillrect(dc,r,b);
            PaintStars(dc);
            result:=1;
          end;
end;

end;

//главная функция инициализации плагина
function InitPlugin(h:THandle;var p:TPluginInfo):boolean;export;
begin
p.ConsoleWindowProc:=@PluginWindowProc;//получаем процедуру обработки окна консоли от WinConsul
WinConsulOptions:=p.Options; //получаем от WinConsul опции/настройки
p.signature:='WinConsulPlugin';
p.name:=     'plugin: Stars';
p.version:=  1.001;
p.comment:=  'Created by VirEx (c) for WinConsul';

result:=true;//инициализация прошла успешно
end;

exports
 InitPlugin;


begin
end.

