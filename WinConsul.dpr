program WinConsul;

uses
  windows,
  messages,
  shellapi,
  CMDMode,
  UseIERunHistory;

//{$R *.RES}

{VirEx (c) oct 2005}

//[21:38 01.11.2005]
type
  TRgb = record
  r,g,b:byte;
  ir,ig,ib:integer;
  end;

type
  TPluginInfo = record
  
  //ниже то что WinConsul передаст плагину
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

//функция инициализации плагина во время его загрузки InitPlugin
TPluginInitFunction=function (h:THandle;var p:TPluginInfo):boolean;

type
 TOptions = record
 speed:integer;    //значение, скорость сворачивания окна, если отрицательное, то окно сворачивается
 value:integer;    //высота окна
 divider:integer; //часть высоты монитора, т.е. высота консоли будет вычисляться как maxXSize div divider
 transparency:integer;//процент прозрачности окна

 //[30.10.2005] параметры шрифтов хистори и поля ввода
 HistoryFont,
 EditFont:TLogFont;

 //[21:38 01.11.2005]
 HistoryColor:TRGB;

 ConsoleIsUp:boolean;//=true; //консоль выезжает сверху если true, иначе снизу

 InConsoleMode:string;//=' [in console mode]';//[31.10.2005] уведомление о том что команда выполнилась в режиме CMD (консоли)

 UseIEHistory:boolean;//=true;

 //история команд выводимая на экран [20:03 04.10.2005]
 HistoryLinesCout:byte; //количество строк истории команд
 HistoryLines:array of PChar; //строки истории
 {для истории две функции:
  AddHistory() //добавить в историю (вставка снизу, остальное сдвигается вверх)
  DrawHistory()//отрисовка истории в консоли
 }

 HistoryEdit:array of PChar;//история для автоввода
 HistoryEditCout:byte; //количество строк истории команд
 AboutF1:array of PChar;

 EditFontColor:TRgb;
 HistoryFontColor:TRgb;
end;


var
 Instance: HWnd;
 WindowClass: TWndClass;
 Handle,HandleEdit: HWnd;
 OldEditProc:Pointer;
 msg: TMsg;
 ExtFlag:Boolean;  //флаг завершения работы программы
 WndStatus:boolean;//статус окна, видимое невидимое

 maxXSize:integer;  //максимальная высота консоли
 maxYSize:integer;  //максимальная длина (ширина) консоли

 HandleFocus: HWnd;//фокус окна другой программы
 DC:hDC;           //контекст окна для рисования

 IsWin9x:Boolean; //в какой мы форточке...

 Options:TOptions;

 Plugins:array of ^TPluginInfo;

 i: integer;mutex:integer;
const
  mutextext='WIN_CONSUL_STOP_DOUBLE_RUN';
  WM_IDLE=WM_USER+4444;

//{$IFDEF WIN32}       //если не Windows NT
//  IsWin9x=true; //старый эффект появления окна - растягивание и сжатие окна
//{$ELSE}              //если Windows NT+
//  IsWin9x=false; //новый эффект - перемещение полупрозрачного окна-консоли за пределы экрана
//{$ENDIF}

{
Автор:       Эдгар, Songoku@tut.by, Берлин
Copyright:   http://www.wasm.ru/
Дата:        23 февраля 2003 г.
}
function isWindows9x: Bool; {True=Win9x} {False=NT}
asm
  xor eax, eax
  mov ecx, cs
  xor cl, cl
  jecxz @@quit
  inc eax
@@quit:
end;

//[21:04 30.10.2005] - установка шрифта для ЛЮБОГО окна
//здесь f:TLogFont я сделал для того, чтобы не вписывать
//во входные параметры кучу инфы о шрифте а вставил переменную
function SetFont(HandleWnd:hWnd;f:TLogFont):hFont;
var
  hNewFont:hFont;
begin
//можно чтонибудь изменить :)
//f.lfHeight:=-5;
//f.lfCharSet:=DEFAULT_CHARSET;

hNewFont := CreateFontIndirect(f);
//sendmessage(HandleWnd,WM_SetFont,hNewFont,1);
result:=hNewFont;
//selectObject(GetDC(HandleWnd),hNewFont);
//DeleteObject(hNewFont);
end;

{
[31.10.2005] ну вот, даже не понадобилась, завёл я инфу о шрифтах поля ввода и консоли в структуры HistoryFont и EditFont
и это стало реально ненужно
//var - для того чтобы сохранялось в переменной
function GetFont(HandleWnd:hWnd;var f:TLogFont):boolean;
var
  hOldFont:hFont;
begin
result:=false;
hOldFont:=sendmessage(HandleWnd,WM_GetFont,0,0);
if hOldFont>0 then result:=true //есть дескриптор шрифта
else exit; //иначе выход т.к. следующая функция ниже может переписать свойства шрифта ненужными значениями
GetObject(hOldFont,SizeOf(f),Addr(f));//получаем по дескриптору шрифта свойства шрифта в f
end;
}

//добавляем историю команд
//все строки смещаются вверх а добавляемая дописывается в самом низу
//var здесь не случаен, он необходим чтобы РЕАЛЬНО изменить массив
//входящий как параметр, без var процедура не сканает
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
//getmem(h[High(h)],SizeOf(s));
//move(s,h[High(h)],SizeOf(s));
h[High(h)]:=s;
end;

//[23:39 09.11.2005]
procedure AddIEHistory(s:PChar;var h:array of PChar);
var
  i:integer;
begin
//High - количество элементов в массиве

if High(h)<2 then exit;
i:=0;//идем сверху вниз
while i<High(h) do begin
  if string(s)=string(h[i]) then exit;
  inc(i);
end;
SaveIEHistory(s);

end;

procedure DrawHistory(DC:HDC;var h:array of PChar);
var
  i,y:integer;
  r:trect;
  s:string;
  t:TextMetric;
  f:hfont;//чтобы не оставлять много открытых GDI объектов - в данном случае хэндлов шрифтов
begin
//GetWindowRect(Handle,r);
//[22:41 22.10.2005] фикс: при первом вызове консоли (ctrl+f12) не выводилось хистори
//(тк. окно консоли только сформировалось и GetWindowRect получал от окна неверные параметры RECT)
//поэтому подсмотрев что нужно для правильной работы DrawText я сделал так:
r.Left:=5; //отступ слева
r.Top:=15;//отступ сверху чтобы копирайт не переписать :)
r.Right:=MaxXSize;
r.Bottom:=(MaxXSize div Options.divider);

SetBkMode(DC, TRANSPARENT);

//SetTextColor(DC, rgb(255,255,255));//белый шрифт
SetTextColor(DC, rgb(Options.HistoryFontColor.r,Options.HistoryFontColor.g,Options.HistoryFontColor.b));//

//SetTextCharacterExtra(DC,0);//растягивает или уменьшает строку


//не будем тупо добавлять все строки а добавим только те которые влезут на экран
//[23:21 30.10.2005]
//устанавливаем свой шрифт
f:=SetFont(Handle,Options.HistoryFont); //обязательно через переменную чтобы можно было потом закрыть объект-шрифт
SelectObject(DC,f);  
//узнаём его метрику
GetTextMetrics(DC, t);
//вычисляем с какой строки нужно выводить на экран (последние энные строки из массива)
y:=(GetSystemMetrics (SM_CYSCREEN) div Options.divider) div t.tmHeight;//14; //количество выводимых в хистори строк, div t.tmHeight - это высота символов текста для DrawText
for i:=(High(h)-y) to High(h) do
s:=s + h[i]+#13;//#13 символ каретки - перевода строки, можно и так: Char(VK_RETURN)
//TextOut(DC,5,(i+1)*15+HistoryCout, h[i], Length(h[i]));//*15 - между строками по 15 пикселей, +HistoryCout - смещаем хистори вниз ближе к полю ввода
//ExtTextOut(DC,0,(i+1)*10 ,ETO_RTLREADING	,@r, h[i], Length(h[i]),0);
//ExtTextOut(DC,5,(i+1)*15+HistoryCout ,ETO_RTLREADING	,@r, h[i], Length(h[i]),0);
//DrawText(DC,h[i],Length(h[i]),r,DT_EDITCONTROL);
//DrawText позволяет вывести многострочный текст
DrawText(DC,PChar(s),Length(PChar(s)),r,DT_EDITCONTROL);

DeleteObject(f); //вот теперь избавляемся от объекта-шрифта
SetBkMode(DC, OPAQUE);
end;

//[22.10.2005] рисование градиента карандашом - Pen
procedure ShowGradient2(prmDC:hDC;prmRed,prmGreen,prmBlue:byte;ClientWidth,ClientHeight:integer);
var
Row:Word ;
wrkPenNew:hPen;//новая кисть

//[23:53 24.10.2005]
//это добавлено для устранения бага, когда разрешение больше чем 800x600 (которое у меня чаще всего:)
wrkDelta:integer;  //желаемое количество оттенков

begin
wrkDelta:=255 div (1+ClientHeight);
if wrkDelta=0 then wrkDelta:=1;

for Row := 0 to 1+(ClientHeight) do begin
wrkPenNew:=CreatePen(PS_SOLID,1,RGB(prmRed, prmGreen, prmBlue));
SelectObject(prmDC,wrkPenNew);

MoveToEx(prmDC,0,Row,nil);
LineTo(prmDC,ClientWidth,Row);


DeleteObject(wrkPenNew);

if prmRed > wrkDelta then Dec(prmRed,wrkDelta);
if prmGreen > wrkDelta then Dec(prmGreen,wrkDelta);
if prmBlue  > wrkDelta then Dec(prmBlue,wrkDelta);

end;

//ставим свой копирайт :)
//SetBkColor(prmDC, RGB(prmRed, prmGreen, prmBlue));
SetBkMode(prmDC, Transparent);
SetTextColor(prmDC, rgb(-Options.HistoryColor.r,-Options.HistoryColor.g,-Options.HistoryColor.b));//инвертированный цвет текста (по отношению к фону)
//SetTextCharacterExtra(prmDC,0);//растягивает или уменьшает строку
SelectObject(prmDC,GetStockObject(DEFAULT_GUI_FONT));
TextOut(prmDC, 5,0, 'WinConsul 26.11.2005 VirEx (c)', 30);
end;



//делаем окно полупрозначным
//h:hwnd          хэндл окна которое сделать прозрачным
//procent:integer процент прозрачности, рекомендую 170 для консоли
procedure SetTrans(h:hwnd;procent:integer);
var
  old: longint;
begin
  if procent>0 then begin
    old:=GetWindowLongA(Handle,GWL_EXSTYLE);
    SetWindowLongA(Handle,GWL_EXSTYLE,old or WS_EX_LAYERED);
    SetLayeredWindowAttributes(handle, 0, procent, LWA_ALPHA);
  end else
    SetWindowLongA(Handle,GWL_EXSTYLE,old or WS_EX_LAYERED);
end;


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

//вкл/выкл. анимации появления/скрытия консоли
procedure OnShowWindow;
begin

WndStatus:= not WndStatus;

//тут повторимся если разрешение экрана поменяли
 MaxXSize:=GetSystemMetrics (SM_CXSCREEN);
 MaxYSize:=GetSystemMetrics (SM_CYSCREEN);

//"ставим на место" поле ввода
MoveWindow(HandleEdit,4,(MaxXSize div Options.divider)-23,MaxXSize-8,20,true);

case WndStatus of
false:begin
      Options.speed:=-Options.speed;
      SetTimer(Handle,1,10,nil{@TimerProc});
      end;
true: begin
      Options.speed:=-Options.speed;
      SetTimer(Handle,1,5,nil{@TimerProc});
      SendMessage(HandleEdit,wm_settext,0,0);//очищаем поле ввода
      end;
end;
end;

//[23:51 16.11.2005] делаем радугу :)
procedure CreateRainBow(var r:TRGB);
begin
        inc(r.r,r.ir);
        inc(r.g,r.ig);
        inc(r.b,r.ib);
      // знаю что код реализован не ахти но всёже..
      // логику работы "подсмотрел" в окне выбора цвета из mspaint (двигал мышкой и смотрел значения rgb :)

      //красный - желтый
       if r.r=255 then
         //if HistoryFontColor.b=0 then
          if r.g<255 then
              begin
              r.ir:=0;
              r.ig:=5;
              r.ib:=0;
              end;

       //желтый - зеленый
       if r.g=255 then
         //if HistoryFontColor.b=0 then
          if r.r>0 then
              begin
              r.ir:=-5;
              r.ig:=0;
              r.ib:=0;
              end;

       //зеленый - светло-синий
       if r.g=255 then
         //if HistoryFontColor.b=0 then
          if r.r=0 then
              begin
              r.ir:=0;
              r.ig:=0;
              r.ib:=5;
              end;

       //светло-синий - (темно) синий
       if r.b=255 then
         //if HistoryFontColor.r=0 then
          if r.g>0 then
              begin
              r.ir:=0;
              r.ig:=-5;
              r.ib:=0;
              end;

       //(темно) синий - фиолетовый
       if r.b=255 then
         //if HistoryFontColor.g=0 then
          if r.r<255 then
              begin
              r.ir:=5;
              r.ig:=0;
              r.ib:=0;
              end;

       //фиолетовый - красный
       if r.r=255 then
         //if HistoryFontColor.g=0 then
          if r.b>0 then
              begin
              r.ir:=0;
              r.ig:=0;
              r.ib:=-5;
              end;

end;


function EditWindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
var
  buff,bufftmp:PChar;

  i,l,SelStart,SelLength:integer; //для автоввода

  LFont: TLogFont; hOldFont: HFont; //для поля ввода - меняем шрифт при ctrl+left/rigth

  m:TMSG;//для избавления от звука после нажатия enter в поле ввода

  CMDLog:PChar;
  CMDLogTmp:PChar;

 r:Trect;
  dc:hdc;
begin
if ExtFlag then exit;
 // if hwn=HandleEdit then
 //result:=DefWindowProc(Hwn,Msg,wPr,Lpr);
 result:=CallWindowProc(OldEditProc,HandleEdit,Msg,wPr,Lpr); //msg

//посылаем всем плугинам сообщения в их процедуру обработки
//если плугину необходимо будет убить сообщение которое он обработал
//то он может указать в процедуре обработки ConsoleEditProc значение Result:=1
for i:=0 to High(Plugins) do
 if CallWindowProc(Plugins[i].ConsoleEditProc,HandleEdit,Msg,wPr,Lpr)=1 then exit;

//if result=0 then exit;

 //фильтрация сообщений
 case msg of
{
wm_paint: begin
   dc:=GetDC(Hwn);

   p.hdc:=dc;
   p.fErase:=true;//rgb(Options.HistoryFontColor.r,Options.HistoryFontColor.g,Options.HistoryFontColor.b);
   getwindowrect(HandleEdit,p.rcPaint);
   beginpaint(HandleEdit,p);
  //b:=Createpen(PS_SOLID,1,(rgb(Options.HistoryFontColor.r,Options.HistoryFontColor.g,Options.HistoryFontColor.b)));
  //selectobject(dc,b);
   SetBkMode(dc, Transparent);
  //sendmessage(HandleEdit,WM_CTLCOLOREDIT,255,255);
  SetTextColor(dc, rgb(Options.HistoryFontColor.r,Options.HistoryFontColor.g,Options.HistoryFontColor.b));//
  TextOut(dc, 0, 0, 'g', 1);
  InvalidateRect(Hwn,@p.rcPaint,true);
  endpaint(HandleEdit,p);

  //SetBkColor(dc,0);
  //fff:=dc;
  asm
  mov eax,fff;
  mov al,byte(dc);
  mov ah,byte(0);
  end;
  sendmessage(handleedit,WM_CtlColorEdit,dc,fff);
  releasedc(Hwn,dc);
  //result:=1;
end;
}
  //событие нажатия клавиши
  wm_KeyDown: begin

      //смотрим что нажали
      case wpr of

        //Enter
        vk_return:begin
         getmem(buff,255);
         SendMessage(Hwn,wm_gettext,255,integer(buff));
         if buff='exit' then ExtFlag:=true else

        //если контрол + enter запуск консольного приложения и прямой вывод в консоль
        //из консольного приложения
         if GetKeyState ( VK_CONTROL )<0 then begin

           //if RunConsoleApp(buff,HistoryLines) then
           if RunCMDCommand(PChar(buff)) then begin

            //GetMem(CMDLog,256);//функция сама выделит память
            ReadCMDResult(CMDLog);

            getmem(CMDLogTmp,Length(CMDLog));
            OemToChar(CMDLog,CMDLogTmp);

            //================== draw start
            //выведем самостоятельно на экран хистори консоли
            r.Left:=5; //отступ слева
            r.Top:=15;//отступ сверху чтобы копирайт не переписать :)
            r.Right:=MaxYSize;
            r.Bottom:=(MaxXSize div Options.divider);
            DC:=GetDC(Handle);
            ShowGradient2(dc,Options.HistoryColor.r,Options.HistoryColor.g,Options.HistoryColor.b,MaxXSize,MaxYSize);
            SetTextColor(DC, rgb(255,255,255));// белый цвет шрифта

            hOldFont:=SetFont(Handle,Options.HistoryFont);
            SelectObject(DC,hOldFont);
            DrawText(dc,PChar(CMDLogTmp),Length(CMDLogTmp),r,DT_EDITCONTROL);
            DeleteObject(hOldFont);
            ReleaseDC(Handle,DC);
            //=============  end draw

            //FreeMem(CMDLog);
           end;

           getmem(bufftmp,Length(buff)+Length(Options.InConsoleMode));
           bufftmp:=PChar(buff+Options.InConsoleMode);  //(команда + [in console mode])
           AddHistory(buff,Options.HistoryEdit); //добавляем хистори для автоввода
           AddHistory(bufftmp,Options.HistoryLines);//добавляем хистори для вывода на экран
           //надо сделать чтобы добавлялось в HistoryLines снизу
           //sendmessage(handle,wm_paint,0,0);//не канает - перерисовываем окно с хистори
           sendmessage(handleEdit,wm_settext,0,0);
           end else

           //если просто enter то обычный запуск
           if RunApp(buff) then begin
            AddHistory(buff,Options.HistoryLines);//добавляем хистори для вывода на экран
            AddHistory(buff,Options.HistoryEdit); //добавляем хистори для автоввода
            if Options.UseIEHistory then AddIEHistory(buff,Options.HistoryEdit);
            sendmessage(handle,wm_paint,0,0);//перерисовываем окно с хистори
            OnShowWindow;//анимация открытия/закрытия
            end;
        //freemem(buff,255); - не очищаем буфер чтобы команда сохранилась в истории иначе кракозябры... и move не помогает

        //убийство стандартного звука
        //скажем товарищу P.O.D (http://forum.sources.ru/) спасибо:
        m.hwnd:=Hwn;
        m.message:=msg;
        m.wParam:=wpr;
        m.lParam:=lpr;
        PeekMessage(m,HandleEdit,WM_CHAR,WM_CHAR,PM_REMOVE);
        end;

        //нажат Esc
        VK_ESCAPE: begin

        //убийство стандартного звука
        m.hwnd:=Hwn;
        m.message:=msg;
        m.wParam:=wpr;
        m.lParam:=lpr;
        PeekMessage(m,HandleEdit,WM_CHAR,WM_CHAR,PM_REMOVE);

        OnShowWindow;//анимация закрытия ("задвигания") консоли
        end;

        //влево
        VK_LEFT:begin

        //[0:15 25.10.2005] уменьшение шрифта в хистори (!)
        //всё аналогично VK_RIGHT
        if (GetKeyState ( VK_SHIFT )<0) then begin
        if (Options.HistoryFont.lfHeight+1)>=-2 then exit;//fix
        inc(Options.HistoryFont.lfHeight);
        sendmessage(Handle,wm_paint,0,0);

        //для перерисовки поля ввода (возмём текст и вставим обратно)
        getmem(buff,256);
        sendmessage(HandleEdit,WM_gettext,256,integer(buff));
        sendmessage(HandleEdit,WM_settext,0,integer(buff));
        freemem(buff,256);
        end;

        //уменьшение шрифта в поле ввода
        if (GetKeyState ( VK_CONTROL )<0) then begin//если нажат ctrl то
        hOldFont:=sendmessage(HandleEdit,WM_GetFont,0,0); //
        GetObject(hOldFont,SizeOf(LFont),Addr(LFont));
        DeleteObject(hOldFont);
        inc(LFont.lfHeight);
        inc(Options.EditFont.lfHeight);
        //LFont.lfFaceName := 'Tahoma';
        hOldFont := CreateFontIndirect(LFont);
        sendmessage(HandleEdit,WM_SetFont,hOldFont,1);
        //DeleteObject(hOldFont);

        end;
        end;

        //вверх
        VK_UP:begin

        if not IsWin9x then begin
        //устанавливаем прозрачность (если нажат контрол)
        if GetKeyState ( VK_CONTROL )<0 then
        if (Options.transparency+10)<256 then
        inc(Options.transparency,10);
        SetTrans(Handle,Options.transparency);
        end;

        //[17:14 02.11.2005] изменяем цветовую схему по цветам радуги :)
        if (GetKeyState ( VK_SHIFT )<0) then begin
        CreateRainBow(Options.HistoryColor);

        sendmessage(Handle,wm_paint,0,0);

        //для перерисовки поля ввода (возммём текст и вставим обратно)
        getmem(buff,256);
        sendmessage(HandleEdit,WM_gettext,256,integer(buff));
        sendmessage(HandleEdit,WM_settext,0,integer(buff));
        freemem(buff,256);
        end;
        end;

        //вправо
        VK_RIGHT:begin

        //[0:15 25.10.2005] увеличение шрифта в хистори(!)
        if (GetKeyState ( VK_SHIFT )<0) then begin
        if (Options.HistoryFont.lfHeight-1)<=-100 then exit;//fix
        dec(Options.HistoryFont.lfHeight);
        sendmessage(Handle,wm_paint,0,0);

        //для перерисовки поля ввода (возммём текст и обратно вставим)
        getmem(buff,256);
        sendmessage(HandleEdit,WM_gettext,256,integer(buff));
        sendmessage(HandleEdit,WM_settext,0,integer(buff));
        freemem(buff,256);
        end;

        //увеличение шрифта в поле ввода
        if (GetKeyState ( VK_CONTROL )<0) then begin//если нажат ctrl то
        hOldFont:=sendmessage(HandleEdit,WM_GetFont,0,0); //получаем хэндл шрифта поля ввода
        GetObject(hOldFont,SizeOf(LFont),Addr(LFont)); //получаем с помощью хэндла свойства шрифта
        DeleteObject(hOldFont);//убираем старый объект-шрифт т.к. уже получили инфу о шрифте, щас её изменим и сделаем новый шрифт
        dec(LFont.lfHeight);//увеличиваем шрифт, т.к. значение здесь в отрицательном виде
        dec(Options.EditFont.lfHeight);
        //LFont.lfFaceName := 'Tahoma';//можно поменять тип шрифта :)
        hOldFont := CreateFontIndirect(LFont); //делаем новый шрифт на основе измененных свойст старого шрифта
        sendmessage(HandleEdit,WM_SetFont,hOldFont,1);//устанавливаем новый шрифт

        end;
        end;

        //вниз
        VK_DOWN:begin
        if IsWin9x then exit;

        //устанавливаем прозрачность (если нажат контрол)
        if GetKeyState ( VK_CONTROL )<0 then begin
        if (Options.transparency+10)>0 then
        dec(Options.transparency,10);
        SetTrans(Handle,Options.transparency);
        end;

        if (GetKeyState ( VK_SHIFT )<0) then begin

        //делаем радугу :)
        CreateRainBow(Options.HistoryFontColor);

        sendmessage(Handle,wm_paint,0,0);

        //для перерисовки поля ввода (возммём текст и вставим обратно)
        getmem(buff,256);
        sendmessage(HandleEdit,WM_gettext,256,integer(buff));
        sendmessage(HandleEdit,WM_settext,0,integer(buff));
        freemem(buff,256);
        end;
        end;

        //вывод помощи по F1
        //[0:56 25.10.2005]
        VK_F1: begin
        //добавляем хэлп в хистори
        for i:=0 to High(Options.AboutF1) do AddHistory(PChar(Options.AboutF1[i]),Options.HistoryLines);
        sendmessage(handle,wm_paint,0,0);//перерисовка консоли с уже добавленным хэлпом
        sendmessage(handleEdit,wm_settext,0,0);//т.к. поле ввода "перекрашено" то очищаем его
        end;

        //[23:07 02.11.2005] устанавливаем где будет выезжать консоль сверху или снизу
        VK_F2: begin
        Options.ConsoleIsUp:=not Options.ConsoleIsUp;
        WndStatus:= false;
        Options.value:=10;
        Options.speed:=-Options.speed;
        OnShowWindow;

        end;

        end;//wpr
  end;  //wm_KeyDown

 //[12:59 23.10.2005] автоввод !!!
 //пользователь нажал клавишу (нам нужен символ)
 wm_Char:begin
         if not (char(wpr) in [' '..'я']) then exit;//[22:51 02.11.2005] обязательная проверка на водимый символ (от пробела до последней буквы, не включая служебные: backspace  и т.п.)
         getmem(buff,255);
         SendMessage(Hwn,wm_gettext,255,integer(buff));//получаем текст из поля ввода
         if buff='' then begin
          freemem(buff,255);
          exit;
         end;
         l:=Length(buff);
         for i:=0 to High(Options.HistoryEdit) do  //смотрим есть ли такая команда в хистори
          if Copy(Options.HistoryEdit[i],0,l)=buff then begin //если первые введенные символы подходят к элементу хистори то
          buff:=Options.HistoryEdit[i];
          SelStart:=l;
          SelLength:=Length(buff);
          SendMessage(HandleEdit,WM_Settext,0,Integer(buff));//печатаем предполагаемый текст в поле ввода
          SendMessage(HandleEdit,EM_SETSEL,SelStart,SelLength);//выделяем то что недопечатал пользователь
         end;
        end;

 end;

end;

function WindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
var
  i: integer;
begin
if ExtFlag then exit;

 result:=defwindowproc(hwn,msg,wpr,lpr);

//посылаем всем плугинам сообщения в их процедуру обработки
//если плугину необходимо будет убить сообщение которое он обработал
//то он может использовать PeekMessage( , , , ,PM_REMOVE);

for i:=0 to High(Plugins) do
 if CallWindowProc(Plugins[i].ConsoleWindowProc,Hwn,Msg,wPr,Lpr)=1 then exit;

 case msg of

   //окно только создавается - аналог TForm1.FormCreate...
   wm_create:;

   //окно кто-то убивает :)
   wm_destroy: ;//ExtFlag:=true;

   WM_ACTIVATE:
   //если окно стало неактивным и оно раскрыто до конца то анимация "сворачивания"
    if ((wPr shl 16)=WA_INACTIVE)and(Options.value>=(MaxXSize div Options.divider))		then OnShowWindow;

   wm_paint : begin
       //DC:=CreateDC('DISPLAY',nil,nil,nil); //- будет рисовать прямо на экране

       DC:=GetDC(Handle);

       if IsWin9x then
       ShowGradient2(DC,Options.HistoryColor.r,Options.HistoryColor.g,Options.HistoryColor.b,MaxXSize,Options.value+Options.speed)
       else
       ShowGradient2(DC,Options.HistoryColor.r,Options.HistoryColor.g,Options.HistoryColor.b,MaxXSize,MaxYSize);


       DrawHistory(DC,Options.HistoryLines);
       
       ReleaseDC(Handle,DC);
   end;

   //
   WM_ERASEBKGND : ;



   WM_TIMER: begin
      //value:=value+speed;
      inc(Options.value,Options.speed);

      //при старом эффекте прячем или показываем окно
      if IsWin9x then begin
        if Options.speed>0 then  ShowWindow(Handle,SW_SHOW);
        if Options.value=0 then  ShowWindow(Handle,SW_HIDE);
      end;

      //при появлении консоли запоминаем где был фокус и возвращаем его когда консоль исчезает
      if Options.value>=(MaxXSize div Options.divider) then begin        //консоль "выехала"
        HandleFocus:=GetForegroundWindow;
        SetForegroundWindow(Handle);
        SetFocus(HandleEdit);
        KillTimer(Handle,1);
        Options.value:=(MaxXSize div Options.divider);//[13:03 29.10.2005] - чтобы окно не выезжало за границы
        end else
      if Options.value<=0 then begin              //консоль спряталась
        SetForegroundWindow(HandleFocus);
        SetFocus(HandleFocus);
        KillTimer(Handle,1);
        end else

      //[23:07 02.11.2005]
      if Options.ConsoleIsUp then
      //консоль выезжает сверху
      MoveWindow(Handle,0,Options.Value-(MaxXSize div Options.divider)+Options.speed,MaxXSize,(MaxXSize div Options.divider),true)
      else
      //консоль выезжает снизу :)
      MoveWindow(Handle,0,MaxYSize-Options.Value-Options.speed,MaxXSize,(MaxXSize div Options.divider),true);
 end;

   wm_KeyDown:
    if wpr=VK_ESCAPE then OnShowWindow;

   //горячая главиша ctrl+F12
   WM_HOTKEY: OnShowWindow;


  end;//msg

end;

{
//загружен ли плагин, проверяет по имени
function PluginAlreadyExists(p:Pointer):boolean;
var
  i:integer;
begin
result:=false;
if p=nil then exit;
for i:=0 to High(Plugins) do
 if Plugins[i].name=TPluginInfo(p^).name then begin
 result:=true;
 exit;
 end;

end;
}

//находит и загружает опции из каталога Plugins
procedure FindAndLoadPlugins;
var
  FindData: _WIN32_FIND_DATAA;
  h:THandle;
  s:pchar;
  InitPlugin:TPluginInitFunction;
  //k:integer;
begin                   
//SetLength(Plugins,1);
getmem(s,259);
GetCurrentDirectory(259,PChar(s));
s:=PChar(s+'\plugins\');
h:=FindFirstFile(PChar(s+'*.dll'), FindData);
while h<>INVALID_HANDLE_VALUE do begin

SetLength(Plugins,Length(Plugins)+1);
  //добавляем новую инфу о планиге
  getmem(Plugins[High(Plugins)],SizeOf(TPluginInfo));

  
                                                     // полное имя файла плагина
  Plugins[High(Plugins)].hModulePlugin:=LoadLibrary(PChar(s+string(FindData.cFileName)));//загружаем плагин

  InitPlugin:=GetProcAddress(Plugins[High(Plugins)].hModulePlugin,'InitPlugin'); //получаем процедуру инициализации плагина
  if @InitPlugin=nil then break;//такой функции в помине нет, значит это не наш плугин

  Plugins[High(Plugins)].Options:=@Options;//даём плагину настройки программы (вообщем ссылку на структуру настроек)
  //предохраняемся :)
  try
  InitPlugin(hInstance,Plugins[High(Plugins)]^);//оживляем наш плугин :)
  except
  break;
  end;

  {
  //если плагин уже есть то пропускаем загрузку
  //может случиться что один и тот же плагин существует в 2х файлах (с разными именами)
  k:=High(Plugins);
  if k>0 then
  if PluginAlreadyExists(Plugins[k]) then begin
  Plugins[k]^.ConsoleWindowProc:=nil;
  Plugins[k]^.ConsoleEditProc:=nil;
  Plugins[k]^.Options:=nil;
  FreeLibrary(Plugins[k].hModulePlugin);//выгружаем плагин
  freemem(Plugins[k],SizeOf(TPluginInfo));
  SetLength(Plugins,k-1);
  break;//прерываем загрузку
  end;
  }

  //показываем в хистори какой плагин у нас загрузился
  AddHistory(PChar(Plugins[High(Plugins)]^.name),Options.HistoryLines);

  FindNextFile(h,FindData);
  if GetLastError=ERROR_NO_MORE_FILES then break;

end;
FindClose(h);
//freemem(s,1024);
end;

procedure Main;
var
  i: integer;
begin
if not CreateCMDMode('cmd') then AddHistory('==warning: Not create CMD mode (only XP)==',Options.HistoryLines);//messagebox(0,'Not create CMD mode!', 'Error create CMD',id_ok);


mutex := CreateMutex(nil,true,mutextext);//устанавливаем мьютекс

//=============== Хистори
//выделяем память для хистори (GetMem для PChar не подходит)
SetLength(Options.HistoryLines,Options.HistoryLinesCout);
//выделяем память для каждого элемента
for i:=0 to high(Options.HistoryLines) do GetMem(Options.HistoryLines[i],256);
//очищаем все элементы от мусора (т.к. выделили память)
for i:=0 to high(Options.HistoryLines) do
  fillmemory(Options.HistoryLines[i],256,0); //for y:=0 to Length(Options.HistoryLines[i]) do Options.HistoryLines[i][y]:=#0;
//==================

//============= хистори поля ввода
//память на X команд
SetLength(Options.HistoryEdit,Options.HistoryEditCout);
//выделяем память для каждого элемента
for i:=0 to high(Options.HistoryEdit) do GetMem(Options.HistoryEdit[i],256);
//очищаем от мусора который может появиться когда мы выделяли память
for i:=0 to high(Options.HistoryEdit) do fillmemory(Options.HistoryEdit[i],256,0);
AddHistory('exit',Options.HistoryEdit);//облегчим жизнь юзверю :)


//===========================

//добавляем хэлп в хистори
for i:=0 to High(Options.AboutF1) do
  AddHistory(Options.AboutF1[i],Options.HistoryLines);

//загружаем плагины
FindAndLoadPlugins;


instance :=GetModuleHandle(nil);

 WindowClass.style:=CS_NOCLOSE;// CS_NOCLOSE - позволяет не закрывать окно при нажатии alt+f4
 WindowClass.Lpfnwndproc:=@windowproc;
 WindowClass.Hinstance:=Instance;
 WindowClass.HbrBackground:= 0;//color_btnface;
 WindowClass.LpszClassName:='DX';
 WindowClass.Hcursor:=LoadCursor(0,IDC_ARROW);

 RegisterClass(WindowClass);

 //максимальный размер высоты окна в пикселях
 MaxXSize:=GetSystemMetrics (SM_CXSCREEN);
 MaxYSize:=GetSystemMetrics (SM_CYSCREEN);

 //создаём окно консоли
 Handle:=CreateWindowEx(WS_EX_TOPMOST or WS_EX_TOOLWINDOW,'DX','',WS_POPUP, 0,-(MaxXSize div Options.divider), MaxYSize, (MaxXSize  div Options.divider),0,0,instance, nil);
 
 //создаём поле ввода (подчиненное окно)
 HandleEdit:=CreateWindowEx(0,'EDIT','',WS_CHILD or WS_BORDER, 0,0,  (MaxXSize div Options.divider)-100,20 ,handle,0,instance, @EditWindowProc);
 //запоминаем процедуру обработки сообщений от windows к полю ввода - EDIT (чтобы перехватывать только то что нам нужно а остальное - перерисовка окна и т.п. оставить самому компоненту системы - EDIT'у )
 OldEditProc:=Pointer(GetWindowLong(HandleEdit,GWL_WNDPROC));
 //устанавливаем свою процедуру обработки сообщений
 SetWindowLong(HandleEdit,GWL_WNDPROC,Integer(@EditWindowProc));

 //ставим системный шрифт по умолчанию (для поля ввода EDIT)
 //SendMessage(Handle, wm_SetFont, GetStockObject(DEFAULT_GUI_FONT), 0);

 //[23:18 16.11.2005] fix
 sendmessage(HandleEdit,WM_SetFont,SetFont(HandleEdit,Options.EditFont),1);
 //SetFont(Handle,HistoryFont); - это работает только в DrawHistory

  if not IsWin9x then
 //устанавливаем нашу консоль полу-прозрачной
 SetTrans(Handle,Options.transparency);

 //видна сама консоль хотя можно и так: UpdateWindow (Handle);
 ShowWindow(Handle,SW_SHOW);

 //теперь видно поле ввода
 ShowWindow(HandleEdit,SW_SHOW);

 //регестрируем горячую клавишу для нашей консоли ctrl+F12
 if not  RegisterHotKey(Handle,1,MOD_CONTROL,vk_F12) then begin
 MessageBox(0,'Not register hot-key Ctrl+F12!'{'RegisterHotKey not install'},'Error',0);
 ExtFlag:=true;
 end;

 if Options.UseIEHistory then LoadIEHistory(Options.HistoryEdit);

 //здесь крутятся все сообщения посылаемые программе (окну)
 while (GetMessage(msg, 0, 0, 0)) do
  begin
  //это условие убивает реакцию программы на нажание F1 фак!
  //if not PeekMessage(msg, 0, 0, 0, PM_REMOVE) then SendMessage(Handle,WM_IDLE,0,0);//msg.message:=WM_NULL;

   if ExtFlag then exit;
   translatemessage(msg);
   dispatchmessage (msg);
  end;

end;

exports
  DrawHistory,//для плагина Skin
  OnShowWindow;

begin
//эта функция отрубает звук для всей системы поэтому не будем её применять
//SystemParametersInfo(SPI_SETBEEP,0,nil,0); //выключить звуки
//SysTemparametersInfo(SPI_SETBEEP,1,nil,0); //включить

Options.ConsoleIsUp:=true;//консоль выезжает сверху
Options.InConsoleMode:=' [in console mode]'#0;

Options.HistoryColor.r:=210;
Options.HistoryColor.g:=210;
Options.HistoryColor.b:=255;

Options.speed:=-10;

isWin9x:=IsWindows9x;

 ExtFlag:=false;    //по умолчанию программа не выгружается :)
 Options.transparency:=200;//прозрачность консоли

 Options.HistoryEditCout:=100;//количество строк для автоввода (память на 100 команд)

 Options.divider:=4; //высота консоли - четверть высоты монитора (экрана)
 Options.HistoryLinesCout:=100;//количество строк истории выводимой на экран

 Options.UseIEHistory:=false;//true;

 ZeroMemory(@Options.EditFont,SizeOf(Options.EditFont));
 ZeroMemory(@Options.HistoryFont,SizeOf(Options.EditFont));
 Options.EditFont.lfHeight:=-12;
 Options.EditFont.lfCharSet:=204;
 Options.EditFont.lfFaceName:='Tahoma';
 Options.EditFont.lfWeight:=FW_SEMIBOLD ;

 Options.HistoryFontColor.r:=255;
 Options.HistoryFontColor.g:=255;
 Options.HistoryFontColor.b:=255;

 Options.HistoryFont:=Options.EditFont;
 Options.HistoryFont.lfHeight:=-12;
 Options.HistoryFont.lfWeight:=FW_BOLD ;

SetLength(Options.AboutF1,11);
Options.AboutF1[0]:='== F1 help ==';
Options.AboutF1[1]:='ctrl+F12 - показ/скрытие WinConsul';
Options.AboutF1[2]:='ctrl+up/down - прозрачность окна (XP)';
Options.AboutF1[3]:='ctrl+left/right - уменьшение/увеличение шрифта поля ввода';
Options.AboutF1[4]:='shift+left/right - уменьшение/увеличение шрифта текста в истории команд';
Options.AboutF1[5]:='shift+up - изменение цветовой гаммы';
Options.AboutF1[6]:='shift+down - изменение цвета хистори';
Options.AboutF1[7]:='ctrl+enter - запуск команды/программы в режиме консоли CMD [in console mode]';
Options.AboutF1[8]:='F1 - вывод этой помощи';
Options.AboutF1[9]:='F2 - консоль появляеться сверху/снизу';
Options.AboutF1[10]:='exit - выход из программы';

//===============================================================================

 //защита от повторного запуска консоли
 //если мьютекс не установлен то запуск программы
 if OpenMutex(MUTEX_ALL_ACCESS,false,mutextext) = 0 then
  Main;

//===============================================================================

  //освобождаем память
  for i:=0 to high(Plugins) do begin
   //Plugins[i].PluginProc:=nil;
   //Plugins[i].Options:=nil;
   CallWindowProc(Plugins[i].ConsoleWindowProc,Handle,WM_DESTROY,0,0);//фикс
   try
    FreeLibrary(Plugins[i]^.hModulePlugin);
   except
   end;
   FreeMem(Plugins[i],SizeOf(TPluginInfo));
  end;
  SetLength(Plugins,0);

  KillTimer(Handle,1);       //убираем таймер
  UnregisterHotKey(Handle,1);//убираем горячую клавишу

  //освобождаем память (очищаем от элементов хистори), тут вылетает ошибка поэтому уберем
  //for i:=0 to high(Options.HistoryLines) do fillmemory(Options.HistoryLines[i],length(Options.HistoryLines[i]),0);//freeMem(Options.HistoryLines[i]);

  //очищаем список истории (FreeMem для PChar не подходит)
  SetLength(Options.HistoryLines,0);

  //очищаем список хистори поля ввода
  SetLength(Options.HistoryEdit,0);

  //убиваем мьютекс
  //хотя и не обязательно, т.к. он сам уничтожется если программа выгружается :)
  ReleaseMutex(mutex);

  CloseCMDMode;

  //UnRegisterClass(WindowClass.lpszClassName,instance);
  //DestroyWindow(HandleEdit);
  //DestroyWindow(Handle);
  //FreeLibrary(instance);
end.                         
