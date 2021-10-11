library Starsss;


uses
  windows,messages;

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
 //����� WinConsul
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
  NumStars = 2000; // ���������� ����,
                   // ��������� ����� ���������� �������� ����

  RangeY = 5000; // ������������ ���������� �� ��������� ��������� �� ������,
                   // ��������� ���������� ���� � ������

  RangeR = 7000; // ������������ ���������� �������� �� ���� ������ �� ������,
                   // ��������� ���������� ���� �� �����

  Height = 500; // ������ �����������,
                   // ��������� ���������� ������ ����������� �� ���������

  Basis = 250; // ���������� �� ��������� ���������
                   // ��������� ������������ ���������� ���� � ������ � ��
                   // ���������� �� �����

  DeltaY = 10; // ��� ��������� ����������, ��������� ��������� ��������
  DeltaT = 0.02; // ���������� �������, ��������� ��������� ��������
  Period1 = 0.1; // ������ �������� ����
  Amplitude2 = 0.3; // ��������� ������������ ��������� ����
  Period2 = 1.0; // ������ ������������ ���������
  Period3 = 0.1; // ������ ��������� ����������� �������� ����.


  Direction = 1; // ����������� �������� 1 - � �����������, -1 - �� ����
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


//����� ��� ��������� �������� ���� �������
function PluginWindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
var
  r:Trect;

begin
 //���������� ���������
case msg of
 wm_create: begin
            InitializeStars;//������� (����) ������-������ ��������
            p:=CreatePen(ps_solid,2,rgb(255,255,255));
            b:=createsolidbrush(0);
            end;
 wm_destroy:begin//������� �������
            DeleteObject(p);
            DeleteObject(b);
            end;

 //wm_idle:  ; // ��� ������� ���������� ����� WinConsul "�����������", �� � �������� ���������

 wm_size: begin
           MaxXSize:=GetSystemMetrics (SM_CXSCREEN);
           MaxYSize:=GetSystemMetrics (SM_CYSCREEN);
           X0 := MaxXSize div 2;
           Y0 := (MaxYSize div 2) * 3 div 2;
          end;

WM_ACTIVATE: begin
               if (lo(wPr)=WA_ACTIVE) then begin//���� ������� ������� � ������� ��
                 dc:=GetDC(Hwn);
                 SetTimer(Hwn,99,85,nil)//������ ������
               end else begin
                 ReleaseDC(dc,hwn);
                 KillTimer(Hwn,99);//������� ������
               end;
             end;
WM_TIMER: begin
          if wpr<>99 then exit; //���� ��� �� ��� ������ �� �����
            selectobject(dc,p);
            //getwindowrect(hwn,r);
            r.Left:=0; //������ �����
            r.Top:=0;//������ ������
            r.Right:=MaxXSize;
            r.Bottom:=(MaxXSize div WinConsulOptions.divider)-25;
            //selectobject(dc,b);
            fillrect(dc,r,b);
            PaintStars(dc);
            result:=1;
          end;
WM_PAINT: begin  //��������� ��������� ��� ������ ���������� � ����� ��� ��������� ���������� ������
            //getwindowrect(hwn,r);
            r.Left:=0; //������ �����
            r.Top:=0;//������ ������
            r.Right:=MaxXSize;
            r.Bottom:=(MaxXSize div WinConsulOptions.divider)-25;
            //selectobject(dc,b);
            fillrect(dc,r,b);
            PaintStars(dc);
            result:=1;
          end;
end;

end;

//������� ������� ������������� �������
function InitPlugin(h:THandle;var p:TPluginInfo):boolean;export;
begin
p.ConsoleWindowProc:=@PluginWindowProc;//�������� ��������� ��������� ���� ������� �� WinConsul
WinConsulOptions:=p.Options; //�������� �� WinConsul �����/���������
p.signature:='WinConsulPlugin';
p.name:=     'plugin: Stars';
p.version:=  1.001;
p.comment:=  'Created by VirEx (c) for WinConsul';

result:=true;//������������� ������ �������
end;

exports
 InitPlugin;


begin
end.

