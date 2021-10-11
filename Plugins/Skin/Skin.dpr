library Skin;


uses
  windows,messages,JPEG,graphics;   

type
  TPluginInfo = record
  
  //���� �� ��� WinConsul �������� ������ (�����) �������
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

type
  TRgb = record
  r,g,b:byte;
  ir,ig,ib:integer;
  end;
  
type
 //����� WinConsul, �� �� ����� ��������� ��� WinConsul � ���������
 TOptions = record
 speed:integer;    //��������, �������� ������������ ����, ���� �������������, �� ���� �������������
 value:integer;    //������ ����
 divider:integer; //����� ������ ��������, �.�. ������ ������� ����� ����������� ��� maxXSize div divider
 transparency:integer;//������� ������������ ����
 HistoryFont,
 EditFont:TLogFont;
 HistoryColor:TRGB;
 ConsoleIsUp:boolean;//=true; //������� �������� ������ ���� true, ����� �����
 InConsoleMode:string;//=' [in console mode]';//[31.10.2005] ����������� � ��� ��� ������� ����������� � ������ CMD (�������)
 UseIEHistory:boolean;//=true;
 HistoryLinesCout:byte; //���������� ����� ������� ������
 HistoryLines:array of PChar; //������ �������
 HistoryEdit:array of PChar;//������� ��� ���������
 HistoryEditCout:byte; //���������� ����� ������� ������
 AboutF1:array of PChar;

 EditFontColor:TRgb;
 HistoryFontColor:TRgb;

end;

type
  TAlign=(aLeft,aCenter,aRight);//������������ ��������
  TMethod=(mNormal,mStretch);//����� ��������� - ���������� ��� ����������

const
  //���� ��� ����������/������ �����
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

//���� ��� ����� �� �����
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
  s:integer;//����� ����� ��� ��������� �� ����������� �����������
begin
DC:=GetDC(H);
c.Handle:=DC;

r.Left:=0; //������ �����
r.Top:=0;//������ ������
r.Right:=MaxXSize;
r.Bottom:=(MaxXSize div WinConsulOptions.divider);

case m of
mStretch: ;
mNormal: begin

  //�������/��������� WinConsul ����� ������
  {
  b:=CreateSolidBrush(bColor);
  //getwindowrect(h,r);   //����� ���� ����� ���� �� ��������� ��������� ������� ��������� ����
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
                    s:=(MaxXSize div 2);//�������� ����
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
  DC:hDC; //����������� ����� ���� ������������ ������ GetDC(Hwn), ���������� �� ����� ������
begin
 //���������� ���������
case msg of
 wm_create: LoadImage(DefaultImageFileName);//������� (����) ������-������ ��������
 wm_destroy:FreeImage;
 wm_paint:  begin
             if ErrorLoadImage then exit;
             DC:=GetDC(Hwn);
             DrawImage(Hwn,mnormal,aRight,0{clNone});//������ ��� ����
             DrawHistory(DC,WinConsulOptions.HistoryLines);//����� �������
             result:=1;//������� WinConsul ����� ��� ������ �� ������������ ��� ���������  (WM_PAINT), �.�. �� ����������������
             releaseDC(Hwn,DC);
             exit;
            end;
 wm_size: begin//���� ���������� ������ ��������
            MaxXSize:=GetSystemMetrics (SM_CXSCREEN);
            MaxYSize:=GetSystemMetrics (SM_CYSCREEN);
          end;
end;//msg
end;


function PluginEditProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
var
  buff:PChar;
begin
 //���������� ���������
case msg of
  //������� ������� �������
  wm_KeyDown: begin
      //������� ��� ������
      case wpr of
        //Enter
        vk_Up: if not ErrorLoadImage then
                  //����� �� ������� �������� ����� - �.�. ����� �� ���� ������ ����������� ������� (��������� �������)
                  if (GetKeyState ( VK_SHIFT )<0) then result:=1;
                //[17:14 02.11.2005] �������� �������� ����� �� ������ ������ :)
     end; //wpr
 end;//wm_KeyDown
end;//msg
end;


function InitPlugin(h:THandle;var p:TPluginInfo):boolean;export;
begin
p.ConsoleWindowProc:=@PluginWindowProc;//�������� ��������� ��������� ���� ������� �� WinConsul
p.ConsoleEditProc:=@PluginEditProc;
WinConsulOptions:=p.Options; //�������� �� WinConsul �����/���������
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

