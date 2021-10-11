library Example;


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


//����� ��� ��������� �������� ���� �������
function PluginWindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
begin
 //���������� ���������
case msg of
 wm_create: ;//������� (����) ������-������ ��������
 wm_destroy: ;//������� �������
end;//msg
end;


//����� ��� ��������� ���� �����
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
        vk_return:begin
         getmem(buff,255);
         SendMessage(Hwn,wm_gettext,255,integer(buff));//�������� ������ �� ���� �����
         if buff='test' then MessageBox(Hwn,'Text','Caption',MB_OK);
         if buff='load' then ;
         //result:=1;//������� ���� ����� WinConsul ����� �� ������������ ����� ��� ��������� (vk_return)
        end; //vk_return
     end; //wpr
 end;//wm_KeyDown
end;//msg
end;

//������� ������� ������������� �������
function InitPlugin(h:THandle;var p:TPluginInfo):boolean;export;
begin
p.ConsoleWindowProc:=@PluginWindowProc;//�������� ��������� ��������� ���� ������� �� WinConsul
p.ConsoleEditProc:=@PluginEditProc;//�������� ��������� ��������� ���� ����� �� WinConsul
WinConsulOptions:=p.Options; //�������� �� WinConsul �����/���������
p.signature:='WinConsulPlugin';
p.name:=     'plugin: Example';
p.version:=  1.0;
p.comment:=  'Created by VirEx (c) for WinConsul';

result:=true;//������������� ������ �������
end;

exports
 InitPlugin;


begin
end.

