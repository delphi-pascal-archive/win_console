library Options;


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

const
  //���� ��� ����������/������ �����
  OptionsFileName='Plugins\WinConsulOptions.xml';

var
  WinConsulOptions:^TOptions;


//��������� �����
procedure LoadOptions(FileName:string);
var
  FindData: TWin32FindData;
  //i:integer;
begin

//���� ��� ����� �� �����
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

//��������� ���������
procedure SaveOptions(FileName:string);
//var
  //i:integer;
begin

CreateXML;//������� xml

CreateNodeText('main','');//������� �����

//������� ���������
CreateAttribute(['main'],'app','WinConsul');//������� �����
CreateAttribute(['main'],'creater','Saver/Loader options');//������� �����
CreateAttribute(['main'],'ver','1.xxx');//������� �����

//CreateAttribute(['main'],'comment',p.comment);//������� �����
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
 //���������� ���������
case msg of
 wm_create: LoadOptions(OptionsFileName);//������� (����) ������-������ ��������
 wm_destroy: SaveOptions(OptionsFileName);//������� �������
end;//msg
end;

{
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
p.ConsoleWindowProc:=@PluginWindowProc;//�������� ��������� ��������� ���� ������� �� WinConsul
//p.ConsoleEditProc:=@PluginEditProc;
WinConsulOptions:=p.Options; //�������� �� WinConsul �����/���������
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

