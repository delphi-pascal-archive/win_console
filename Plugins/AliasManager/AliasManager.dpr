library AliasManager;


uses
  windows,messages,Classes,Sysutils,ShellApi;

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
  TOnShowWindow=procedure;

const
  AliasesFileName='Plugins\Aliases.txt';

var
  WinConsulOptions:^TOptions;
  OnShowWindow:TOnShowWindow;
  AliasesList:TStringList;
  ErrorLoadAliases:boolean;
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

function GetCommand(s:string):string;
var
  i:integer;
  str:string;
begin
for i:=1 to Length(s) do begin
if s[i]=' ' then break;
str:=str+s[i];
end;
result:=str;
end;

// ������� ����� ����������� � leftChar � RigthChar
function GetParam(str,leftChar,RigthChar:string):string;
var
  Tstart,Tend,i:integer;
  s:string;
begin
result:='';
s:='';
Tstart:=pos(LeftChar,str)+1;//������� ����� ����� �������

i:=Length(str);
while i>0 do begin
if str[i]=RigthChar then break;
dec(i);
end;
Tend:=i;                    //����� ������ �������


i:=Tstart;
while i<Tend do begin
s:=s+str[i];
inc(i);
end;

result:=s;//copy(str,Tstart,Tend);
end;

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
h[High(h)]:=s;
end;


procedure LoadAliases(FileName:string);
var
  i:integer;
  s_:string;
  s:PChar;
begin
try
AliasesList.LoadFromFile(FileName);
except
ErrorLoadAliases:=true;
exit;
end;

//��������� � ��������
for i:=0 to AliasesList.Count-1 do begin
s_:=GetCommand(AliasesList[i]);
GetMem(s,Length(s_));
//move(s_,s^,Length(s_));
s:=PChar(s_+#0);
AddHistory(s, WinConsulOptions.HistoryEdit);
end;
end;

//����� ��� ��������� �������� ���� �������
function PluginWindowProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
begin
 //���������� ���������
case msg of
 wm_create: begin
            AliasesList:=TStringList.Create;
            LoadAliases(AliasesFileName);//������� (����) ������-������ ��������
            end;
 wm_destroy:begin
            AliasesList.Clear;
            AliasesList.Free;
            end;//������� �������
end;//msg
end;


//����� ��� ��������� ���� �����
function PluginEditProc (Hwn,msg,wpr,lpr: longint): longint; stdcall;
var
  buff,s:PChar;
  i:integer;
begin
 //���������� ���������
case msg of
  //������� ������� �������
  wm_KeyDown: begin
      //������� ��� ������
      case wpr of
        //Enter
        vk_return:begin
         if ErrorLoadAliases then exit;
         getmem(buff,255);
         SendMessage(Hwn,wm_gettext,255,integer(buff));//�������� ������ �� ���� �����
         for i:=0 to AliasesList.Count-1 do
          if GetCommand(AliasesList[i])=buff then
            if RunApp(PChar(GetParam(AliasesList[i],'"','"'))) then begin
             GetMem(s,Length(GetCommand(AliasesList[i])));
             s:=PChar(GetCommand(AliasesList[i])+' [alias]');
             AddHistory(s, WinConsulOptions.HistoryLines);
             SendMessage(FindWindow('DX',nil),wm_paint,0,0);//����������� �������
             OnShowWindow; //�������� ��������
             result:=1;// ������������� ���������� ��������� ������� WinConsul
            end;
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
p.name:=     'plugin: AliasManager';
p.version:=  1.001;
p.comment:=  'Created by VirEx (c) for WinConsul';
//DrawHistory:=GetProcAddress(h,'DrawHistory');
OnShowWindow:=GetProcAddress(h,'OnShowWindow');
ErrorLoadAliases:=false;

result:=true;//������������� ������ �������
end;

exports
 InitPlugin;


begin
end.

