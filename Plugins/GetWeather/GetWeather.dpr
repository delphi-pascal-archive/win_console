library GetWeather;


uses
  windows,messages,UseXML;

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
//��������� �� ������� � ���������
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
//��������� �� ������� � ���������
while i<Length(command_)+1 do begin
if GetParams then s:=s+command_[i];
if command_[i]= ' ' then GetParams:=true;
inc(i);
end;
result:=s;//��� PChar(s);
end;

procedure AddHistory(s:string;var h:array of PChar);
var
  i:integer;
  str:PChar;
begin
//High - ���������� ��������� � �������
if High(h)<2 then exit;
i:=0;//���� ������ ����
while i<High(h) do begin
  h[i]:=h[i+1];
  inc(i);
end;
s:=s+#0;//����������� ��������� ����� ����� ����������
getmem(str,Length(s));
CopyMemory(str,PChar(s),Length(s));
h[i]:=str;
end;


procedure GetWeatherInfo(City:string);
var
  URL,CityID,s:string;
begin
if City='' then exit;

//������� ID ������
URL:='http://xoap.weather.com/search/search?where='+City+#0;

//��� �����
if City='last' then URL:='LastWeatherCityID.xml';

LoadXML(URL);

CityID:=GetNodeItemText(['search','loc'],'id');

if CityID='' then begin
s:=City+' is not found';
AddHistory(s,WinConsulOptions.HistoryLines);
exit;
end;
//SaveXML('LastWeatherCityID.xml');
//��������� ���� �� ID ������
URL:='http://xoap.weather.com/weather/local/'+CityID+'?cc=*&dayf=0&prod=xoap&link=xoap&par=1006341644&key=0647abc97052c741&unit=m'+#0;

if City='last' then URL:='LastWeatherInfo.xml'; //- ��� �����

LoadXML(URL);

SaveXML('LastWeatherInfo.xml');

 //����
 s:='����� = ' +GetNodeText(['weather','loc ','dnam']);
 AddHistory(s,WinConsulOptions.HistoryLines);

 //s:=s+'������ = ' + GetNodeVariant(['weather','loc ','sunr']);
 //s:=s+'�����  = ' + GetNodeVariant(['weather','loc ','suns']);
 //s:=s+'������� ���� = '+GetNodeVariant(['weather','loc ','zone']);
 //s:=s+'��������� ����� = ' + GetNodeVariant(['weather','cc','lsup']);

 //if integer(GetNodeVariant(['weather','cc','tmp']))<>0 then
 //s_:='����������� � = ' + GetNodeVariant(['weather','cc','tmp'])
 //else
 //s_:='����������� � = 0';
 s:='����������� � = ' + GetNodeText(['weather','cc','tmp']);
 //s:=PChar('����������� = ' +GetNodeText(['weather','cc','tmp'])+#0);
 AddHistory(s,WinConsulOptions.HistoryLines);

 //s:=s+'������ = ' + GetNodeTextFromID(['//weather','//cc'],4);

 s:='�������� ��.��.= '+ GetNodeText(['weather','cc','bar','r']);
 //s:=PChar('�������� ��.��.= '+GetNodeText(['weather','cc','bar','r'])+#0);
 AddHistory(s,WinConsulOptions.HistoryLines);

 //s:=s+'�������� = '+ GetNodeText(['//weather','//cc','//bar','//d']);

 s:='����� �/c = '+ GetNodeText(['weather','cc','wind','s'])+#0;
 //s:=PChar('����� �/c = '+GetNodeText(['weather','cc','wind','s'])+#0);
 AddHistory(s,WinConsulOptions.HistoryLines);

 s:='����������� = '+GetNodeText(['weather','cc','wind','t']);
 //s:=PChar('����������� = '+GetNodeText(['weather','cc','wind','t'])+#0);
 AddHistory(s,WinConsulOptions.HistoryLines);

 //s:=s+'��������� ��.  = ' + GetNodeText(['//weather','//cc','//vis']);
 //s:=s+'���� = '+ GetNodeTextFromID(['//weather','//moon'],1);
 URL:='';
 CityID:='';
 s:='';
end;

//����� ��� ��������� �������� ���� �������
function PluginWindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
begin
 //���������� ���������
case msg of
 wm_create: CreateXML;//������� (����) ������-������ ��������
 wm_destroy:DestroyXML;//������� �������
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
         if GetCommand(buff)='getWeather' then begin
            GetWeatherInfo(GetParam(buff));
            SendMessage(FindWindow('DX',nil),wm_paint,0,0);//����������� �������
            sendmessage(getwindow(FindWindow('DX',nil),GW_CHILD	),WM_settext,0,0{integer(buff)});//���������������� ���� �����
            result:=1;//������� ���� ����� WinConsul ����� �� ������������ ����� ��� ��������� (vk_return)
            end;
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
p.name:=     'plugin: GetWeather';
p.version:=  1.0;
p.comment:=  'Created by VirEx (c) for WinConsul';

//��������� � ��������
AddHistory(PChar('getWeather'),WinConsulOptions.HistoryEdit);

DrawHistory:=GetProcAddress(h,'DrawHistory');

result:=true;//������������� ������ �������
end;

exports
 InitPlugin;


begin
end.

