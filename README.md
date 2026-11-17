# TouchBlock

**English** | [Русский](#русский)

A small Windows tray utility that disables the touchscreen while a convertible laptop is in normal laptop mode and enables it when the screen is flipped open into tablet mode. The stylus keeps working in both modes.

Developed and tested on an **ASUS Zenbook/ROG Flow X16** with Windows 11. It may work on other 2-in-1 laptops, but that is untested.

## Features

- Automatic switching: touch is off in laptop mode, on in tablet mode
- Tray icon that reflects the current state, with a right-click menu
- Manual toggle and "force enable"
- Auto-switching can be paused (manual mode)
- Optional notifications (styled popup, adjustable duration)
- Re-syncs after resume from sleep
- Optional start at login (Task Scheduler, no UAC prompt)
- Interface languages: English and Russian (auto-detected, switchable from the menu)

## How it works

- The laptop/tablet mode is read with `GetSystemMetrics(SM_CONVERTIBLESLATEMODE)`.
- The touchscreen device (`HID-compliant touch screen`) is found through WMI and disabled or enabled with `pnputil`, falling back to PowerShell `Disable-PnpDevice` if `pnputil` fails.
- The pen is a separate HID device (`HID-compliant pen`), so it is not affected.
- After touch is re-enabled, an optional refresh nudges Windows to apply the tablet posture (see below).

## Install

**Option 1: installer.** Build it yourself (see below) or download `TouchBlock_Setup.exe` from Releases. Windows SmartScreen may warn about an unknown publisher because the installer is not signed.

**Option 2: run the script.**
1. Install [AutoHotkey v2](https://www.autohotkey.com/) (the regular installer, not the Microsoft Store version).
2. Run `TouchBlock.ahk`. It asks for administrator rights, which are required to disable devices.

## Settings (tray menu)

| Item | Meaning |
|------|---------|
| Auto-switch by laptop mode | Turn automatic switching on or off |
| Notifications | Show or hide popups (errors are always shown) |
| Refresh after enabling touch | `No refresh`, `Soft (no flicker)` (experimental), or `Restart graphics (flickers)` |
| Notification duration | 1.5 / 2.5 / 4 seconds |
| Start at login | Creates or removes a Task Scheduler task |
| Language | Automatic, Russian, English |

Settings are stored in `%APPDATA%\TouchBlock\settings.ini`. A diagnostic log is written to `%APPDATA%\TouchBlock\debug.log`.

### About the refresh option

On the author's laptop, Windows did not apply the tablet taskbar layout when touch was re-enabled after the flip. Restarting the graphics stack (Win+Ctrl+Shift+B) fixed it but makes the screen flicker. The "Soft" option broadcasts the same `ConvertibleSlateMode` setting-change message Windows uses and does not flicker, but it is **experimental** and may not work on every device. If the tablet layout does not appear, switch to "Restart graphics".

## Build

1. Install [AutoHotkey v2](https://www.autohotkey.com/) with its Ahk2Exe compiler (use the v2 base file, 64-bit).
2. Right-click `TouchBlock.ahk` and choose **Compile Script**. The icons `touch_on.ico` and `touch_off.ico` are embedded.
3. Optional installer: install [Inno Setup](https://jrsoftware.org/isinfo.php), put the compiled `TouchBlock.exe` next to `installer/TouchBlock.iss` (or adjust the path in the `[Files]` section) and compile the `.iss`.

The icons in this repository are simple placeholders. Replace them with your own `.ico` files if you like, keeping the same names.

## Known limitations

- Blocking touch without disabling the device (mouse hook) does not work: modern apps receive touch through the pointer API.
- Needs administrator rights.
- Antivirus software sometimes flags compiled AutoHotkey executables; this is a false positive.
- The device name filter matches `touch screen` and the Russian `сенсорный экран`. Other Windows languages may need an extra name in `FindTouchIds()`.

## License

MIT, see [LICENSE](LICENSE).

---

## Русский

Небольшая утилита в трее для Windows: отключает тачскрин, пока ноутбук-трансформер находится в обычном режиме, и включает его при раскрытии экрана в планшетный режим. Стилус работает в обоих режимах.

Разрабатывалась и проверялась на **ASUS Flow X16** с Windows 11. На других ноутбуках-трансформерах может работать, но это не проверено.

### Возможности

- Автоматическое переключение: в режиме ноутбука тач выключен, в планшетном включён
- Значок в трее показывает состояние, меню по правой кнопке
- Ручное переключение и принудительное включение
- Автоматику можно приостановить (ручной режим)
- Уведомления (можно отключить, настраивается время показа)
- Синхронизация состояния после выхода из сна
- Автозапуск при входе через Планировщик заданий, без запроса UAC
- Языки интерфейса: русский и английский (определяется автоматически, переключается из меню)

### Установка

**Вариант 1: установщик.** Соберите его сами (см. ниже) или скачайте `TouchBlock_Setup.exe` из раздела Releases. SmartScreen может предупредить о неизвестном издателе, так как установщик не подписан.

**Вариант 2: запуск скрипта.**
1. Установите [AutoHotkey v2](https://www.autohotkey.com/) обычным установщиком, не версией из Microsoft Store.
2. Запустите `TouchBlock.ahk`. Скрипт запросит права администратора, они нужны для отключения устройств.

### Сборка

1. Установите AutoHotkey v2 вместе с компилятором Ahk2Exe (базовый файл v2, 64-bit).
2. Щёлкните правой кнопкой по `TouchBlock.ahk` и выберите **Compile Script**. Значки `touch_on.ico` и `touch_off.ico` вшиваются в exe.
3. Установщик (по желанию): установите Inno Setup, положите собранный `TouchBlock.exe` рядом с `installer/TouchBlock.iss` и скомпилируйте `.iss`.

Значки в репозитории простые, заменяйте их своими `.ico` с теми же именами.

### Параметр «Обновление после включения тача»

У автора Windows не применяла планшетный вид панели задач, если тач включался уже после переворота. Перезапуск графики (Win+Ctrl+Shift+B) помогает, но экран мигает. Вариант «Мягко» отправляет системное сообщение о смене режима и не мигает, но он **экспериментальный** и может не работать на некоторых устройствах. Если планшетный вид не появляется, выберите «Перезапуск графики».

### Ограничения

- Блокировка касаний без отключения устройства (через хук мыши) не работает: современные приложения получают касания напрямую.
- Нужны права администратора.
- Антивирусы иногда ругаются на собранные exe из AutoHotkey, это ложное срабатывание.
- Поиск устройства работает по именам `touch screen` и «сенсорный экран». Для других языков Windows может понадобиться добавить имя в `FindTouchIds()`.

### Лицензия

MIT, см. [LICENSE](LICENSE).
