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
  
  //���� �� ��� WinConsul �������� �������
  ConsoleWindowProc:Pointer;//���������� (���� �������) ��������� ��������� ��������� �� ��
  ConsoleEditProc:Pointer;  //���������� (���� ����� �������) ��������� ��������� ��������� �� ��
  Options:Pointer;          //��� ��������� ������� (��������� �������)

  signature:PChar;          //����������� � ������� �������

  //���� ��, ��� ������ ������ ��� ��������� ��� WinConsul
  name:string;
  version:double;
  comment:string;

  //������������ ������ WinConsul
  hModulePlugin:THandle;  //��� ��������/�������� ������� - ��� ����� (������)

 end;

//������� ������������� ������� �� ����� ��� �������� InitPlugin
TPluginInitFunction=function (h:THandle;var p:TPluginInfo):boolean;

type
 TOptions = record
 speed:integer;    //��������, �������� ������������ ����, ���� �������������, �� ���� �������������
 value:integer;    //������ ����
 divider:integer; //����� ������ ��������, �.�. ������ ������� ����� ����������� ��� maxXSize div divider
 transparency:integer;//������� ������������ ����

 //[30.10.2005] ��������� ������� ������� � ���� �����
 HistoryFont,
 EditFont:TLogFont;

 //[21:38 01.11.2005]
 HistoryColor:TRGB;

 ConsoleIsUp:boolean;//=true; //������� �������� ������ ���� true, ����� �����

 InConsoleMode:string;//=' [in console mode]';//[31.10.2005] ����������� � ��� ��� ������� ����������� � ������ CMD (�������)

 UseIEHistory:boolean;//=true;

 //������� ������ ��������� �� ����� [20:03 04.10.2005]
 HistoryLinesCout:byte; //���������� ����� ������� ������
 HistoryLines:array of PChar; //������ �������
 {��� ������� ��� �������:
  AddHistory() //�������� � ������� (������� �����, ��������� ���������� �����)
  DrawHistory()//��������� ������� � �������
 }

 HistoryEdit:array of PChar;//������� ��� ���������
 HistoryEditCout:byte; //���������� ����� ������� ������
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
 ExtFlag:Boolean;  //���� ���������� ������ ���������
 WndStatus:boolean;//������ ����, ������� ���������

 maxXSize:integer;  //������������ ������ �������
 maxYSize:integer;  //������������ ����� (������) �������

 HandleFocus: HWnd;//����� ���� ������ ���������
 DC:hDC;           //�������� ���� ��� ���������

 IsWin9x:Boolean; //� ����� �� ��������...

 Options:TOptions;

 Plugins:array of ^TPluginInfo;

 i: integer;mutex:integer;
const
  mutextext='WIN_CONSUL_STOP_DOUBLE_RUN';
  WM_IDLE=WM_USER+4444;

//{$IFDEF WIN32}       //���� �� Windows NT
//  IsWin9x=true; //������ ������ ��������� ���� - ������������ � ������ ����
//{$ELSE}              //���� Windows NT+
//  IsWin9x=false; //����� ������ - ����������� ��������������� ����-������� �� ������� ������
//{$ENDIF}

{
�����:       �����, Songoku@tut.by, ������
Copyright:   http://www.wasm.ru/
����:        23 ������� 2003 �.
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

//[21:04 30.10.2005] - ��������� ������ ��� ������ ����
//����� f:TLogFont � ������ ��� ����, ����� �� ���������
//�� ������� ��������� ���� ���� � ������ � ������� ����������
function SetFont(HandleWnd:hWnd;f:TLogFont):hFont;
var
  hNewFont:hFont;
begin
//����� ��������� �������� :)
//f.lfHeight:=-5;
//f.lfCharSet:=DEFAULT_CHARSET;

hNewFont := CreateFontIndirect(f);
//sendmessage(HandleWnd,WM_SetFont,hNewFont,1);
result:=hNewFont;
//selectObject(GetDC(HandleWnd),hNewFont);
//DeleteObject(hNewFont);
end;

{
[31.10.2005] �� ���, ���� �� ������������, ���� � ���� � ������� ���� ����� � ������� � ��������� HistoryFont � EditFont
� ��� ����� ������� �������
//var - ��� ���� ����� ����������� � ����������
function GetFont(HandleWnd:hWnd;var f:TLogFont):boolean;
var
  hOldFont:hFont;
begin
result:=false;
hOldFont:=sendmessage(HandleWnd,WM_GetFont,0,0);
if hOldFont>0 then result:=true //���� ���������� ������
else exit; //����� ����� �.�. ��������� ������� ���� ����� ���������� �������� ������ ��������� ����������
GetObject(hOldFont,SizeOf(f),Addr(f));//�������� �� ����������� ������ �������� ������ � f
end;
}

//��������� ������� ������
//��� ������ ��������� ����� � ����������� ������������ � ����� ����
//var ����� �� �������, �� ��������� ����� ������� �������� ������
//�������� ��� ��������, ��� var ��������� �� �������
procedure AddHistory(s:PChar;var h:array of PChar);
var
  i:integer;
begin
//High - ���������� ��������� � �������

if High(h)<2 then exit;
i:=0;//���� ������ ����
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
//High - ���������� ��������� � �������

if High(h)<2 then exit;
i:=0;//���� ������ ����
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
  f:hfont;//����� �� ��������� ����� �������� GDI �������� - � ������ ������ ������� �������
begin
//GetWindowRect(Handle,r);
//[22:41 22.10.2005] ����: ��� ������ ������ ������� (ctrl+f12) �� ���������� �������
//(��. ���� ������� ������ �������������� � GetWindowRect ������� �� ���� �������� ��������� RECT)
//������� ���������� ��� ����� ��� ���������� ������ DrawText � ������ ���:
r.Left:=5; //������ �����
r.Top:=15;//������ ������ ����� �������� �� ���������� :)
r.Right:=MaxXSize;
r.Bottom:=(MaxXSize div Options.divider);

SetBkMode(DC, TRANSPARENT);

//SetTextColor(DC, rgb(255,255,255));//����� �����
SetTextColor(DC, rgb(Options.HistoryFontColor.r,Options.HistoryFontColor.g,Options.HistoryFontColor.b));//

//SetTextCharacterExtra(DC,0);//����������� ��� ��������� ������


//�� ����� ���� ��������� ��� ������ � ������� ������ �� ������� ������ �� �����
//[23:21 30.10.2005]
//������������� ���� �����
f:=SetFont(Handle,Options.HistoryFont); //����������� ����� ���������� ����� ����� ���� ����� ������� ������-�����
SelectObject(DC,f);  
//����� ��� �������
GetTextMetrics(DC, t);
//��������� � ����� ������ ����� �������� �� ����� (��������� ����� ������ �� �������)
y:=(GetSystemMetrics (SM_CYSCREEN) div Options.divider) div t.tmHeight;//14; //���������� ��������� � ������� �����, div t.tmHeight - ��� ������ �������� ������ ��� DrawText
for i:=(High(h)-y) to High(h) do
s:=s + h[i]+#13;//#13 ������ ������� - �������� ������, ����� � ���: Char(VK_RETURN)
//TextOut(DC,5,(i+1)*15+HistoryCout, h[i], Length(h[i]));//*15 - ����� �������� �� 15 ��������, +HistoryCout - ������� ������� ���� ����� � ���� �����
//ExtTextOut(DC,0,(i+1)*10 ,ETO_RTLREADING	,@r, h[i], Length(h[i]),0);
//ExtTextOut(DC,5,(i+1)*15+HistoryCout ,ETO_RTLREADING	,@r, h[i], Length(h[i]),0);
//DrawText(DC,h[i],Length(h[i]),r,DT_EDITCONTROL);
//DrawText ��������� ������� ������������� �����
DrawText(DC,PChar(s),Length(PChar(s)),r,DT_EDITCONTROL);

DeleteObject(f); //��� ������ ����������� �� �������-������
SetBkMode(DC, OPAQUE);
end;

//[22.10.2005] ��������� ��������� ���������� - Pen
procedure ShowGradient2(prmDC:hDC;prmRed,prmGreen,prmBlue:byte;ClientWidth,ClientHeight:integer);
var
Row:Word ;
wrkPenNew:hPen;//����� �����

//[23:53 24.10.2005]
//��� ��������� ��� ���������� ����, ����� ���������� ������ ��� 800x600 (������� � ���� ���� �����:)
wrkDelta:integer;  //�������� ���������� ��������

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

//������ ���� �������� :)
//SetBkColor(prmDC, RGB(prmRed, prmGreen, prmBlue));
SetBkMode(prmDC, Transparent);
SetTextColor(prmDC, rgb(-Options.HistoryColor.r,-Options.HistoryColor.g,-Options.HistoryColor.b));//��������������� ���� ������ (�� ��������� � ����)
//SetTextCharacterExtra(prmDC,0);//����������� ��� ��������� ������
SelectObject(prmDC,GetStockObject(DEFAULT_GUI_FONT));
TextOut(prmDC, 5,0, 'WinConsul 26.11.2005 VirEx (c)', 30);
end;



//������ ���� ��������������
//h:hwnd          ����� ���� ������� ������� ����������
//procent:integer ������� ������������, ���������� 170 ��� �������
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

//��������� �� ������� � ���������
while i<Length(command_) do begin
if GetParams then params:=params+command_[i] else
if command_[i]<>' ' then command:=command+command_[i];
if command_[i]= ' ' then GetParams:=true;
inc(i);
end;

result:=(31<ShellExecute(0,'open',PChar(command),PChar(params),nil,1));
end;

//���/����. �������� ���������/������� �������
procedure OnShowWindow;
begin

WndStatus:= not WndStatus;

//��� ���������� ���� ���������� ������ ��������
 MaxXSize:=GetSystemMetrics (SM_CXSCREEN);
 MaxYSize:=GetSystemMetrics (SM_CYSCREEN);

//"������ �� �����" ���� �����
MoveWindow(HandleEdit,4,(MaxXSize div Options.divider)-23,MaxXSize-8,20,true);

case WndStatus of
false:begin
      Options.speed:=-Options.speed;
      SetTimer(Handle,1,10,nil{@TimerProc});
      end;
true: begin
      Options.speed:=-Options.speed;
      SetTimer(Handle,1,5,nil{@TimerProc});
      SendMessage(HandleEdit,wm_settext,0,0);//������� ���� �����
      end;
end;
end;

//[23:51 16.11.2005] ������ ������ :)
procedure CreateRainBow(var r:TRGB);
begin
        inc(r.r,r.ir);
        inc(r.g,r.ig);
        inc(r.b,r.ib);
      // ���� ��� ��� ���������� �� ���� �� ����..
      // ������ ������ "����������" � ���� ������ ����� �� mspaint (������ ������ � ������� �������� rgb :)

      //������� - ������
       if r.r=255 then
         //if HistoryFontColor.b=0 then
          if r.g<255 then
              begin
              r.ir:=0;
              r.ig:=5;
              r.ib:=0;
              end;

       //������ - �������
       if r.g=255 then
         //if HistoryFontColor.b=0 then
          if r.r>0 then
              begin
              r.ir:=-5;
              r.ig:=0;
              r.ib:=0;
              end;

       //������� - ������-�����
       if r.g=255 then
         //if HistoryFontColor.b=0 then
          if r.r=0 then
              begin
              r.ir:=0;
              r.ig:=0;
              r.ib:=5;
              end;

       //������-����� - (�����) �����
       if r.b=255 then
         //if HistoryFontColor.r=0 then
          if r.g>0 then
              begin
              r.ir:=0;
              r.ig:=-5;
              r.ib:=0;
              end;

       //(�����) ����� - ����������
       if r.b=255 then
         //if HistoryFontColor.g=0 then
          if r.r<255 then
              begin
              r.ir:=5;
              r.ig:=0;
              r.ib:=0;
              end;

       //���������� - �������
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

  i,l,SelStart,SelLength:integer; //��� ���������

  LFont: TLogFont; hOldFont: HFont; //��� ���� ����� - ������ ����� ��� ctrl+left/rigth

  m:TMSG;//��� ���������� �� ����� ����� ������� enter � ���� �����

  CMDLog:PChar;
  CMDLogTmp:PChar;

 r:Trect;
  dc:hdc;
begin
if ExtFlag then exit;
 // if hwn=HandleEdit then
 //result:=DefWindowProc(Hwn,Msg,wPr,Lpr);
 result:=CallWindowProc(OldEditProc,HandleEdit,Msg,wPr,Lpr); //msg

//�������� ���� �������� ��������� � �� ��������� ���������
//���� ������� ���������� ����� ����� ��������� ������� �� ���������
//�� �� ����� ������� � ��������� ��������� ConsoleEditProc �������� Result:=1
for i:=0 to High(Plugins) do
 if CallWindowProc(Plugins[i].ConsoleEditProc,HandleEdit,Msg,wPr,Lpr)=1 then exit;

//if result=0 then exit;

 //���������� ���������
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
  //������� ������� �������
  wm_KeyDown: begin

      //������� ��� ������
      case wpr of

        //Enter
        vk_return:begin
         getmem(buff,255);
         SendMessage(Hwn,wm_gettext,255,integer(buff));
         if buff='exit' then ExtFlag:=true else

        //���� ������� + enter ������ ����������� ���������� � ������ ����� � �������
        //�� ����������� ����������
         if GetKeyState ( VK_CONTROL )<0 then begin

           //if RunConsoleApp(buff,HistoryLines) then
           if RunCMDCommand(PChar(buff)) then begin

            //GetMem(CMDLog,256);//������� ���� ������� ������
            ReadCMDResult(CMDLog);

            getmem(CMDLogTmp,Length(CMDLog));
            OemToChar(CMDLog,CMDLogTmp);

            //================== draw start
            //������� �������������� �� ����� ������� �������
            r.Left:=5; //������ �����
            r.Top:=15;//������ ������ ����� �������� �� ���������� :)
            r.Right:=MaxYSize;
            r.Bottom:=(MaxXSize div Options.divider);
            DC:=GetDC(Handle);
            ShowGradient2(dc,Options.HistoryColor.r,Options.HistoryColor.g,Options.HistoryColor.b,MaxXSize,MaxYSize);
            SetTextColor(DC, rgb(255,255,255));// ����� ���� ������

            hOldFont:=SetFont(Handle,Options.HistoryFont);
            SelectObject(DC,hOldFont);
            DrawText(dc,PChar(CMDLogTmp),Length(CMDLogTmp),r,DT_EDITCONTROL);
            DeleteObject(hOldFont);
            ReleaseDC(Handle,DC);
            //=============  end draw

            //FreeMem(CMDLog);
           end;

           getmem(bufftmp,Length(buff)+Length(Options.InConsoleMode));
           bufftmp:=PChar(buff+Options.InConsoleMode);  //(������� + [in console mode])
           AddHistory(buff,Options.HistoryEdit); //��������� ������� ��� ���������
           AddHistory(bufftmp,Options.HistoryLines);//��������� ������� ��� ������ �� �����
           //���� ������� ����� ����������� � HistoryLines �����
           //sendmessage(handle,wm_paint,0,0);//�� ������ - �������������� ���� � �������
           sendmessage(handleEdit,wm_settext,0,0);
           end else

           //���� ������ enter �� ������� ������
           if RunApp(buff) then begin
            AddHistory(buff,Options.HistoryLines);//��������� ������� ��� ������ �� �����
            AddHistory(buff,Options.HistoryEdit); //��������� ������� ��� ���������
            if Options.UseIEHistory then AddIEHistory(buff,Options.HistoryEdit);
            sendmessage(handle,wm_paint,0,0);//�������������� ���� � �������
            OnShowWindow;//�������� ��������/��������
            end;
        //freemem(buff,255); - �� ������� ����� ����� ������� ����������� � ������� ����� ����������... � move �� ��������

        //�������� ������������ �����
        //������ �������� P.O.D (http://forum.sources.ru/) �������:
        m.hwnd:=Hwn;
        m.message:=msg;
        m.wParam:=wpr;
        m.lParam:=lpr;
        PeekMessage(m,HandleEdit,WM_CHAR,WM_CHAR,PM_REMOVE);
        end;

        //����� Esc
        VK_ESCAPE: begin

        //�������� ������������ �����
        m.hwnd:=Hwn;
        m.message:=msg;
        m.wParam:=wpr;
        m.lParam:=lpr;
        PeekMessage(m,HandleEdit,WM_CHAR,WM_CHAR,PM_REMOVE);

        OnShowWindow;//�������� �������� ("����������") �������
        end;

        //�����
        VK_LEFT:begin

        //[0:15 25.10.2005] ���������� ������ � ������� (!)
        //�� ���������� VK_RIGHT
        if (GetKeyState ( VK_SHIFT )<0) then begin
        if (Options.HistoryFont.lfHeight+1)>=-2 then exit;//fix
        inc(Options.HistoryFont.lfHeight);
        sendmessage(Handle,wm_paint,0,0);

        //��� ����������� ���� ����� (����� ����� � ������� �������)
        getmem(buff,256);
        sendmessage(HandleEdit,WM_gettext,256,integer(buff));
        sendmessage(HandleEdit,WM_settext,0,integer(buff));
        freemem(buff,256);
        end;

        //���������� ������ � ���� �����
        if (GetKeyState ( VK_CONTROL )<0) then begin//���� ����� ctrl ��
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

        //�����
        VK_UP:begin

        if not IsWin9x then begin
        //������������� ������������ (���� ����� �������)
        if GetKeyState ( VK_CONTROL )<0 then
        if (Options.transparency+10)<256 then
        inc(Options.transparency,10);
        SetTrans(Handle,Options.transparency);
        end;

        //[17:14 02.11.2005] �������� �������� ����� �� ������ ������ :)
        if (GetKeyState ( VK_SHIFT )<0) then begin
        CreateRainBow(Options.HistoryColor);

        sendmessage(Handle,wm_paint,0,0);

        //��� ����������� ���� ����� (������ ����� � ������� �������)
        getmem(buff,256);
        sendmessage(HandleEdit,WM_gettext,256,integer(buff));
        sendmessage(HandleEdit,WM_settext,0,integer(buff));
        freemem(buff,256);
        end;
        end;

        //������
        VK_RIGHT:begin

        //[0:15 25.10.2005] ���������� ������ � �������(!)
        if (GetKeyState ( VK_SHIFT )<0) then begin
        if (Options.HistoryFont.lfHeight-1)<=-100 then exit;//fix
        dec(Options.HistoryFont.lfHeight);
        sendmessage(Handle,wm_paint,0,0);

        //��� ����������� ���� ����� (������ ����� � ������� �������)
        getmem(buff,256);
        sendmessage(HandleEdit,WM_gettext,256,integer(buff));
        sendmessage(HandleEdit,WM_settext,0,integer(buff));
        freemem(buff,256);
        end;

        //���������� ������ � ���� �����
        if (GetKeyState ( VK_CONTROL )<0) then begin//���� ����� ctrl ��
        hOldFont:=sendmessage(HandleEdit,WM_GetFont,0,0); //�������� ����� ������ ���� �����
        GetObject(hOldFont,SizeOf(LFont),Addr(LFont)); //�������� � ������� ������ �������� ������
        DeleteObject(hOldFont);//������� ������ ������-����� �.�. ��� �������� ���� � ������, ��� � ������� � ������� ����� �����
        dec(LFont.lfHeight);//����������� �����, �.�. �������� ����� � ������������� ����
        dec(Options.EditFont.lfHeight);
        //LFont.lfFaceName := 'Tahoma';//����� �������� ��� ������ :)
        hOldFont := CreateFontIndirect(LFont); //������ ����� ����� �� ������ ���������� ������ ������� ������
        sendmessage(HandleEdit,WM_SetFont,hOldFont,1);//������������� ����� �����

        end;
        end;

        //����
        VK_DOWN:begin
        if IsWin9x then exit;

        //������������� ������������ (���� ����� �������)
        if GetKeyState ( VK_CONTROL )<0 then begin
        if (Options.transparency+10)>0 then
        dec(Options.transparency,10);
        SetTrans(Handle,Options.transparency);
        end;

        if (GetKeyState ( VK_SHIFT )<0) then begin

        //������ ������ :)
        CreateRainBow(Options.HistoryFontColor);

        sendmessage(Handle,wm_paint,0,0);

        //��� ����������� ���� ����� (������ ����� � ������� �������)
        getmem(buff,256);
        sendmessage(HandleEdit,WM_gettext,256,integer(buff));
        sendmessage(HandleEdit,WM_settext,0,integer(buff));
        freemem(buff,256);
        end;
        end;

        //����� ������ �� F1
        //[0:56 25.10.2005]
        VK_F1: begin
        //��������� ���� � �������
        for i:=0 to High(Options.AboutF1) do AddHistory(PChar(Options.AboutF1[i]),Options.HistoryLines);
        sendmessage(handle,wm_paint,0,0);//����������� ������� � ��� ����������� ������
        sendmessage(handleEdit,wm_settext,0,0);//�.�. ���� ����� "�����������" �� ������� ���
        end;

        //[23:07 02.11.2005] ������������� ��� ����� �������� ������� ������ ��� �����
        VK_F2: begin
        Options.ConsoleIsUp:=not Options.ConsoleIsUp;
        WndStatus:= false;
        Options.value:=10;
        Options.speed:=-Options.speed;
        OnShowWindow;

        end;

        end;//wpr
  end;  //wm_KeyDown

 //[12:59 23.10.2005] �������� !!!
 //������������ ����� ������� (��� ����� ������)
 wm_Char:begin
         if not (char(wpr) in [' '..'�']) then exit;//[22:51 02.11.2005] ������������ �������� �� ������� ������ (�� ������� �� ��������� �����, �� ������� ���������: backspace  � �.�.)
         getmem(buff,255);
         SendMessage(Hwn,wm_gettext,255,integer(buff));//�������� ����� �� ���� �����
         if buff='' then begin
          freemem(buff,255);
          exit;
         end;
         l:=Length(buff);
         for i:=0 to High(Options.HistoryEdit) do  //������� ���� �� ����� ������� � �������
          if Copy(Options.HistoryEdit[i],0,l)=buff then begin //���� ������ ��������� ������� �������� � �������� ������� ��
          buff:=Options.HistoryEdit[i];
          SelStart:=l;
          SelLength:=Length(buff);
          SendMessage(HandleEdit,WM_Settext,0,Integer(buff));//�������� �������������� ����� � ���� �����
          SendMessage(HandleEdit,EM_SETSEL,SelStart,SelLength);//�������� �� ��� ����������� ������������
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

//�������� ���� �������� ��������� � �� ��������� ���������
//���� ������� ���������� ����� ����� ��������� ������� �� ���������
//�� �� ����� ������������ PeekMessage( , , , ,PM_REMOVE);

for i:=0 to High(Plugins) do
 if CallWindowProc(Plugins[i].ConsoleWindowProc,Hwn,Msg,wPr,Lpr)=1 then exit;

 case msg of

   //���� ������ ����������� - ������ TForm1.FormCreate...
   wm_create:;

   //���� ���-�� ������� :)
   wm_destroy: ;//ExtFlag:=true;

   WM_ACTIVATE:
   //���� ���� ����� ���������� � ��� �������� �� ����� �� �������� "������������"
    if ((wPr shl 16)=WA_INACTIVE)and(Options.value>=(MaxXSize div Options.divider))		then OnShowWindow;

   wm_paint : begin
       //DC:=CreateDC('DISPLAY',nil,nil,nil); //- ����� �������� ����� �� ������

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

      //��� ������ ������� ������ ��� ���������� ����
      if IsWin9x then begin
        if Options.speed>0 then  ShowWindow(Handle,SW_SHOW);
        if Options.value=0 then  ShowWindow(Handle,SW_HIDE);
      end;

      //��� ��������� ������� ���������� ��� ��� ����� � ���������� ��� ����� ������� ��������
      if Options.value>=(MaxXSize div Options.divider) then begin        //������� "�������"
        HandleFocus:=GetForegroundWindow;
        SetForegroundWindow(Handle);
        SetFocus(HandleEdit);
        KillTimer(Handle,1);
        Options.value:=(MaxXSize div Options.divider);//[13:03 29.10.2005] - ����� ���� �� �������� �� �������
        end else
      if Options.value<=0 then begin              //������� ����������
        SetForegroundWindow(HandleFocus);
        SetFocus(HandleFocus);
        KillTimer(Handle,1);
        end else

      //[23:07 02.11.2005]
      if Options.ConsoleIsUp then
      //������� �������� ������
      MoveWindow(Handle,0,Options.Value-(MaxXSize div Options.divider)+Options.speed,MaxXSize,(MaxXSize div Options.divider),true)
      else
      //������� �������� ����� :)
      MoveWindow(Handle,0,MaxYSize-Options.Value-Options.speed,MaxXSize,(MaxXSize div Options.divider),true);
 end;

   wm_KeyDown:
    if wpr=VK_ESCAPE then OnShowWindow;

   //������� ������� ctrl+F12
   WM_HOTKEY: OnShowWindow;


  end;//msg

end;

{
//�������� �� ������, ��������� �� �����
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

//������� � ��������� ����� �� �������� Plugins
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
  //��������� ����� ���� � �������
  getmem(Plugins[High(Plugins)],SizeOf(TPluginInfo));

  
                                                     // ������ ��� ����� �������
  Plugins[High(Plugins)].hModulePlugin:=LoadLibrary(PChar(s+string(FindData.cFileName)));//��������� ������

  InitPlugin:=GetProcAddress(Plugins[High(Plugins)].hModulePlugin,'InitPlugin'); //�������� ��������� ������������� �������
  if @InitPlugin=nil then break;//����� ������� � ������ ���, ������ ��� �� ��� ������

  Plugins[High(Plugins)].Options:=@Options;//��� ������� ��������� ��������� (������� ������ �� ��������� ��������)
  //�������������� :)
  try
  InitPlugin(hInstance,Plugins[High(Plugins)]^);//�������� ��� ������ :)
  except
  break;
  end;

  {
  //���� ������ ��� ���� �� ���������� ��������
  //����� ��������� ��� ���� � ��� �� ������ ���������� � 2� ������ (� ������� �������)
  k:=High(Plugins);
  if k>0 then
  if PluginAlreadyExists(Plugins[k]) then begin
  Plugins[k]^.ConsoleWindowProc:=nil;
  Plugins[k]^.ConsoleEditProc:=nil;
  Plugins[k]^.Options:=nil;
  FreeLibrary(Plugins[k].hModulePlugin);//��������� ������
  freemem(Plugins[k],SizeOf(TPluginInfo));
  SetLength(Plugins,k-1);
  break;//��������� ��������
  end;
  }

  //���������� � ������� ����� ������ � ��� ����������
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


mutex := CreateMutex(nil,true,mutextext);//������������� �������

//=============== �������
//�������� ������ ��� ������� (GetMem ��� PChar �� ��������)
SetLength(Options.HistoryLines,Options.HistoryLinesCout);
//�������� ������ ��� ������� ��������
for i:=0 to high(Options.HistoryLines) do GetMem(Options.HistoryLines[i],256);
//������� ��� �������� �� ������ (�.�. �������� ������)
for i:=0 to high(Options.HistoryLines) do
  fillmemory(Options.HistoryLines[i],256,0); //for y:=0 to Length(Options.HistoryLines[i]) do Options.HistoryLines[i][y]:=#0;
//==================

//============= ������� ���� �����
//������ �� X ������
SetLength(Options.HistoryEdit,Options.HistoryEditCout);
//�������� ������ ��� ������� ��������
for i:=0 to high(Options.HistoryEdit) do GetMem(Options.HistoryEdit[i],256);
//������� �� ������ ������� ����� ��������� ����� �� �������� ������
for i:=0 to high(Options.HistoryEdit) do fillmemory(Options.HistoryEdit[i],256,0);
AddHistory('exit',Options.HistoryEdit);//�������� ����� ������ :)


//===========================

//��������� ���� � �������
for i:=0 to High(Options.AboutF1) do
  AddHistory(Options.AboutF1[i],Options.HistoryLines);

//��������� �������
FindAndLoadPlugins;


instance :=GetModuleHandle(nil);

 WindowClass.style:=CS_NOCLOSE;// CS_NOCLOSE - ��������� �� ��������� ���� ��� ������� alt+f4
 WindowClass.Lpfnwndproc:=@windowproc;
 WindowClass.Hinstance:=Instance;
 WindowClass.HbrBackground:= 0;//color_btnface;
 WindowClass.LpszClassName:='DX';
 WindowClass.Hcursor:=LoadCursor(0,IDC_ARROW);

 RegisterClass(WindowClass);

 //������������ ������ ������ ���� � ��������
 MaxXSize:=GetSystemMetrics (SM_CXSCREEN);
 MaxYSize:=GetSystemMetrics (SM_CYSCREEN);

 //������ ���� �������
 Handle:=CreateWindowEx(WS_EX_TOPMOST or WS_EX_TOOLWINDOW,'DX','',WS_POPUP, 0,-(MaxXSize div Options.divider), MaxYSize, (MaxXSize  div Options.divider),0,0,instance, nil);
 
 //������ ���� ����� (����������� ����)
 HandleEdit:=CreateWindowEx(0,'EDIT','',WS_CHILD or WS_BORDER, 0,0,  (MaxXSize div Options.divider)-100,20 ,handle,0,instance, @EditWindowProc);
 //���������� ��������� ��������� ��������� �� windows � ���� ����� - EDIT (����� ������������� ������ �� ��� ��� ����� � ��������� - ����������� ���� � �.�. �������� ������ ���������� ������� - EDIT'� )
 OldEditProc:=Pointer(GetWindowLong(HandleEdit,GWL_WNDPROC));
 //������������� ���� ��������� ��������� ���������
 SetWindowLong(HandleEdit,GWL_WNDPROC,Integer(@EditWindowProc));

 //������ ��������� ����� �� ��������� (��� ���� ����� EDIT)
 //SendMessage(Handle, wm_SetFont, GetStockObject(DEFAULT_GUI_FONT), 0);

 //[23:18 16.11.2005] fix
 sendmessage(HandleEdit,WM_SetFont,SetFont(HandleEdit,Options.EditFont),1);
 //SetFont(Handle,HistoryFont); - ��� �������� ������ � DrawHistory

  if not IsWin9x then
 //������������� ���� ������� ����-����������
 SetTrans(Handle,Options.transparency);

 //����� ���� ������� ���� ����� � ���: UpdateWindow (Handle);
 ShowWindow(Handle,SW_SHOW);

 //������ ����� ���� �����
 ShowWindow(HandleEdit,SW_SHOW);

 //������������ ������� ������� ��� ����� ������� ctrl+F12
 if not  RegisterHotKey(Handle,1,MOD_CONTROL,vk_F12) then begin
 MessageBox(0,'Not register hot-key Ctrl+F12!'{'RegisterHotKey not install'},'Error',0);
 ExtFlag:=true;
 end;

 if Options.UseIEHistory then LoadIEHistory(Options.HistoryEdit);

 //����� �������� ��� ��������� ���������� ��������� (����)
 while (GetMessage(msg, 0, 0, 0)) do
  begin
  //��� ������� ������� ������� ��������� �� ������� F1 ���!
  //if not PeekMessage(msg, 0, 0, 0, PM_REMOVE) then SendMessage(Handle,WM_IDLE,0,0);//msg.message:=WM_NULL;

   if ExtFlag then exit;
   translatemessage(msg);
   dispatchmessage (msg);
  end;

end;

exports
  DrawHistory,//��� ������� Skin
  OnShowWindow;

begin
//��� ������� �������� ���� ��� ���� ������� ������� �� ����� � ���������
//SystemParametersInfo(SPI_SETBEEP,0,nil,0); //��������� �����
//SysTemparametersInfo(SPI_SETBEEP,1,nil,0); //��������

Options.ConsoleIsUp:=true;//������� �������� ������
Options.InConsoleMode:=' [in console mode]'#0;

Options.HistoryColor.r:=210;
Options.HistoryColor.g:=210;
Options.HistoryColor.b:=255;

Options.speed:=-10;

isWin9x:=IsWindows9x;

 ExtFlag:=false;    //�� ��������� ��������� �� ����������� :)
 Options.transparency:=200;//������������ �������

 Options.HistoryEditCout:=100;//���������� ����� ��� ��������� (������ �� 100 ������)

 Options.divider:=4; //������ ������� - �������� ������ �������� (������)
 Options.HistoryLinesCout:=100;//���������� ����� ������� ��������� �� �����

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
Options.AboutF1[1]:='ctrl+F12 - �����/������� WinConsul';
Options.AboutF1[2]:='ctrl+up/down - ������������ ���� (XP)';
Options.AboutF1[3]:='ctrl+left/right - ����������/���������� ������ ���� �����';
Options.AboutF1[4]:='shift+left/right - ����������/���������� ������ ������ � ������� ������';
Options.AboutF1[5]:='shift+up - ��������� �������� �����';
Options.AboutF1[6]:='shift+down - ��������� ����� �������';
Options.AboutF1[7]:='ctrl+enter - ������ �������/��������� � ������ ������� CMD [in console mode]';
Options.AboutF1[8]:='F1 - ����� ���� ������';
Options.AboutF1[9]:='F2 - ������� ����������� ������/�����';
Options.AboutF1[10]:='exit - ����� �� ���������';

//===============================================================================

 //������ �� ���������� ������� �������
 //���� ������� �� ���������� �� ������ ���������
 if OpenMutex(MUTEX_ALL_ACCESS,false,mutextext) = 0 then
  Main;

//===============================================================================

  //����������� ������
  for i:=0 to high(Plugins) do begin
   //Plugins[i].PluginProc:=nil;
   //Plugins[i].Options:=nil;
   CallWindowProc(Plugins[i].ConsoleWindowProc,Handle,WM_DESTROY,0,0);//����
   try
    FreeLibrary(Plugins[i]^.hModulePlugin);
   except
   end;
   FreeMem(Plugins[i],SizeOf(TPluginInfo));
  end;
  SetLength(Plugins,0);

  KillTimer(Handle,1);       //������� ������
  UnregisterHotKey(Handle,1);//������� ������� �������

  //����������� ������ (������� �� ��������� �������), ��� �������� ������ ������� ������
  //for i:=0 to high(Options.HistoryLines) do fillmemory(Options.HistoryLines[i],length(Options.HistoryLines[i]),0);//freeMem(Options.HistoryLines[i]);

  //������� ������ ������� (FreeMem ��� PChar �� ��������)
  SetLength(Options.HistoryLines,0);

  //������� ������ ������� ���� �����
  SetLength(Options.HistoryEdit,0);

  //������� �������
  //���� � �� �����������, �.�. �� ��� ����������� ���� ��������� ����������� :)
  ReleaseMutex(mutex);

  CloseCMDMode;

  //UnRegisterClass(WindowClass.lpszClassName,instance);
  //DestroyWindow(HandleEdit);
  //DestroyWindow(Handle);
  //FreeLibrary(instance);
end.                         
