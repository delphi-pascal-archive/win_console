��� ������� ������ ���� � ����� Plugins, � ���� ������������ *.dll

� ������� ������ ���� �������������� ������� ������������� �������:
function InitPlugin(h:THandle;var p:TPluginInfo):boolean;export;
���:
 h - ����� ������ WinConsul (��� Instance)
 ��������� ��� ��������� �� WinConsul ��������� �������/��������, ������� GetProcAddress, ��������:
 DrawHistory:=GetProcAddress(h,'DrawHistory');

 P - ���������, ���������� � �������, ����� ��� ��������� ������ ������� ���������� � ���� WinConsul,
 � � ���� ������� �������� �� WinConsul �����/��������� � ��������� ���������

 ��������� ���������� � �������:
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

  //������������ ������ � WinConsul
  hModulePlugin:THandle;  //��� ��������/�������� ������� - ��� ����� (������)
 end;

� ����� Plugins\Example - ������ �������� �������