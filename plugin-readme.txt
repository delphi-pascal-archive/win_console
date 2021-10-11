Все плагины должны быть в папке Plugins, и быть библиотеками *.dll

В плагине должна быть экспортируемая функция инициализации плагина:
function InitPlugin(h:THandle;var p:TPluginInfo):boolean;export;
где:
 h - хэндл модуля WinConsul (его Instance)
 необходим для получения от WinConsul служебных функций/процедур, методом GetProcAddress, например:
 DrawHistory:=GetProcAddress(h,'DrawHistory');

 P - структура, информация о плагине, через эту структуру плагин передаёт информацию о себе WinConsul,
 и в свою очередь получает от WinConsul опции/настройки и процедуры обработки

 Структура информации о плагине:
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

  //используется только в WinConsul
  hModulePlugin:THandle;  //для загрузки/выгрузки плагина - его хэндл (модуль)
 end;

в папке Plugins\Example - пример создания плагина