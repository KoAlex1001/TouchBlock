#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetName TouchBlock
;@Ahk2Exe-SetDescription Auto-disable touchscreen in laptop mode
;@Ahk2Exe-UpdateManifest 1
;@Ahk2Exe-SetMainIcon touch_on.ico

if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp
}

; ===== files and settings =====
appDir := A_AppData "\TouchBlock"
DirCreate(appDir)
iconOn := appDir "\touch_on.ico"
iconOff := appDir "\touch_off.ico"
iniFile := appDir "\settings.ini"
logFile := appDir "\debug.log"
FileInstall("touch_on.ico", iconOn, 1)
FileInstall("touch_off.ico", iconOff, 1)
try {
    if (FileGetSize(logFile) > 100000)
        FileDelete(logFile)
}

autoMode := IniRead(iniFile, "Settings", "Auto", "1") = "1"
notify := IniRead(iniFile, "Settings", "Notify", "1") = "1"
refreshMode := 1          ; 0 = none, 1 = soft (no flicker), 2 = restart graphics
try refreshMode := Integer(IniRead(iniFile, "Settings", "RefreshMode", "1"))
toastMs := 2500
try toastMs := Integer(IniRead(iniFile, "Settings", "ToastMs", "2500"))

; ===== language =====
strings := Map()
strings["st_on"] := ["Тач: включён", "Touch: on"]
strings["st_off"] := ["Тач: отключён", "Touch: off"]
strings["manual"] := [" (вручную)", " (manual)"]
strings["tip_on"] := ["TouchBlock: тач включён", "TouchBlock: touch on"]
strings["tip_off"] := ["TouchBlock: тач отключён", "TouchBlock: touch off"]
strings["m_toggle"] := ["Переключить режим", "Toggle touch"]
strings["m_force"] := ["Включить принудительно", "Force enable"]
strings["m_auto"] := ["Автоматика по режиму ноутбука", "Auto-switch by laptop mode"]
strings["m_notify"] := ["Уведомления", "Notifications"]
strings["m_refresh"] := ["Обновление после включения тача", "Refresh after enabling touch"]
strings["r_none"] := ["Не обновлять", "No refresh"]
strings["r_soft"] := ["Мягко (без мигания)", "Soft (no flicker)"]
strings["r_gfx"] := ["Перезапуск графики (мигает)", "Restart graphics (flickers)"]
strings["m_dur"] := ["Время показа уведомления", "Notification duration"]
strings["d_15"] := ["1,5 секунды", "1.5 seconds"]
strings["d_25"] := ["2,5 секунды", "2.5 seconds"]
strings["d_40"] := ["4 секунды", "4 seconds"]
strings["m_startup"] := ["Запускать при входе в систему", "Start at login"]
strings["m_lang"] := ["Язык / Language", "Language / Язык"]
strings["l_auto"] := ["Автоматически", "Automatic"]
strings["m_exit"] := ["Выход", "Exit"]
strings["t_auto_on"] := ["Автоматика включена", "Auto-switching on"]
strings["t_auto_on2"] := ["Тач следует за режимом ноутбука", "Touch follows laptop mode"]
strings["t_auto_off"] := ["Автоматика выключена", "Auto-switching off"]
strings["t_auto_off2"] := ["Тач остаётся как есть", "Touch stays as it is"]
strings["t_notify_on"] := ["Уведомления включены", "Notifications on"]
strings["t_dur"] := ["Время показа изменено", "Duration changed"]
strings["sec"] := [" с", " s"]
strings["t_start_on"] := ["Автозапуск включён", "Autostart on"]
strings["t_start_on2"] := ["Программа стартует при входе", "Starts when you sign in"]
strings["t_start_off"] := ["Автозапуск выключен", "Autostart off"]
strings["t_lang"] := ["Язык: Русский", "Language: English"]
strings["t_error"] := ["Ошибка", "Error"]
strings["t_touch_on"] := ["Тачскрин включён", "Touchscreen on"]
strings["t_touch_on2"] := ["Планшетный режим", "Tablet mode"]
strings["t_touch_off"] := ["Тачскрин отключён", "Touchscreen off"]
strings["t_touch_off2"] := ["Режим ноутбука", "Laptop mode"]
strings["found"] := ["найдено: ", "found: "]

DetectLang() {
    return (SubStr(A_Language, 3) = "19") ? "ru" : "en"     ; 0419 = Russian
}

langSetting := IniRead(iniFile, "Settings", "Language", "auto")
if (langSetting != "ru" && langSetting != "en")
    langSetting := "auto"
lang := (langSetting = "auto") ? DetectLang() : langSetting

T(key) {
    global strings, lang
    if !strings.Has(key)
        return key
    return strings[key][lang = "ru" ? 1 : 2]
}

; ===== state =====
refreshDelay := 500
lastState := -1
touchOn := true
touchIds := []
usePs := false           ; true if pnputil does not work and PowerShell is needed
busy := false
lastInfo := ""
toastGui := ""
toastAlpha := 255
startupOn := TaskExists()
statusItem := ""
miAuto := "", miNotify := "", miStartup := ""
durChoices := [], refChoices := [], langChoices := []
durMenu := "", refMenu := "", langMenu := ""

; wait for the taskbar (Explorer may not be ready right after sign-in), up to 60 s
Loop 120 {
    if WinExist("ahk_class Shell_TrayWnd")
        break
    Sleep(500)
}

BuildMenu()
UpdateChecks()
UpdateTray()

fixCount := 0
SetTimer(FixTray, 3000)                                   ; re-add the tray icon three times after start
tbMsg := DllCall("RegisterWindowMessage", "str", "TaskbarCreated", "uint")
OnMessage(tbMsg, (*) => SetTimer(RefreshTrayIcon, -1000)) ; Explorer restarted

SetTimer(CheckMode, 300)
OnMessage(0x218, OnPower)          ; WM_POWERBROADCAST: resume from sleep
if !autoMode
    SetTimer(() => SetTouch(true, false, true), -500)   ; in manual mode start with touch enabled

; ===== tray menu =====
StatusText() {
    global touchOn, autoMode
    return T(touchOn ? "st_on" : "st_off") (autoMode ? "" : T("manual"))
}

BuildMenu() {
    global statusItem, miAuto, miNotify, miStartup
    global durChoices, refChoices, langChoices, durMenu, refMenu, langMenu, touchOn
    miAuto := T("m_auto")
    miNotify := T("m_notify")
    miStartup := T("m_startup")
    durChoices := [[1500, T("d_15")], [2500, T("d_25")], [4000, T("d_40")]]
    refChoices := [[0, T("r_none")], [1, T("r_soft")], [2, T("r_gfx")]]
    langChoices := [["auto", T("l_auto")], ["ru", "Русский"], ["en", "English"]]
    statusItem := StatusText()

    A_TrayMenu.Delete()
    A_TrayMenu.Add(statusItem, (*) => 0)
    A_TrayMenu.Disable(statusItem)
    A_TrayMenu.Add()
    A_TrayMenu.Add(T("m_toggle"), (*) => SetTouch(!touchOn))
    A_TrayMenu.Add(T("m_force"), (*) => SetTouch(true, false))
    A_TrayMenu.Add()
    A_TrayMenu.Add(miAuto, ToggleAuto)
    A_TrayMenu.Add(miNotify, ToggleNotify)

    refMenu := Menu()
    for item in refChoices
        refMenu.Add(item[2], SetRefreshMode.Bind(item[1]))
    A_TrayMenu.Add(T("m_refresh"), refMenu)

    durMenu := Menu()
    for item in durChoices
        durMenu.Add(item[2], SetDuration.Bind(item[1]))
    A_TrayMenu.Add(T("m_dur"), durMenu)

    A_TrayMenu.Add(miStartup, ToggleStartup)

    langMenu := Menu()
    for item in langChoices
        langMenu.Add(item[2], SetLanguage.Bind(item[1]))
    A_TrayMenu.Add(T("m_lang"), langMenu)

    A_TrayMenu.Add()
    A_TrayMenu.Add(T("m_exit"), (*) => ExitApp())
    A_TrayMenu.Default := T("m_toggle")
}

; ===== settings =====
SaveSettings() {
    global iniFile, autoMode, notify, refreshMode, toastMs, langSetting
    IniWrite(autoMode ? 1 : 0, iniFile, "Settings", "Auto")
    IniWrite(notify ? 1 : 0, iniFile, "Settings", "Notify")
    IniWrite(refreshMode, iniFile, "Settings", "RefreshMode")
    IniWrite(toastMs, iniFile, "Settings", "ToastMs")
    IniWrite(langSetting, iniFile, "Settings", "Language")
}

SetCheck(m, name, state) {
    if state
        m.Check(name)
    else
        m.Uncheck(name)
}

UpdateChecks() {
    global autoMode, notify, refreshMode, startupOn, toastMs, langSetting
    global durMenu, durChoices, refMenu, refChoices, langMenu, langChoices
    global miAuto, miNotify, miStartup
    SetCheck(A_TrayMenu, miAuto, autoMode)
    SetCheck(A_TrayMenu, miNotify, notify)
    SetCheck(A_TrayMenu, miStartup, startupOn)
    for item in durChoices
        SetCheck(durMenu, item[2], toastMs = item[1])
    for item in refChoices
        SetCheck(refMenu, item[2], refreshMode = item[1])
    for item in langChoices
        SetCheck(langMenu, item[2], langSetting = item[1])
}

ToggleAuto(*) {
    global autoMode, lastState
    autoMode := !autoMode
    SaveSettings()
    UpdateChecks()
    UpdateTray()
    if autoMode {
        lastState := -1        ; CheckMode will apply the current mode right away
        ShowToast(T("t_auto_on"), T("t_auto_on2"), "30A46C")
    } else {
        ShowToast(T("t_auto_off"), T("t_auto_off2"), "F5A524")
    }
}

ToggleNotify(*) {
    global notify
    notify := !notify
    SaveSettings()
    UpdateChecks()
    if notify
        ShowToast(T("t_notify_on"), "", "30A46C", true)
}

SetRefreshMode(mode, *) {
    global refreshMode, refChoices
    refreshMode := mode
    SaveSettings()
    UpdateChecks()
    for item in refChoices
        if (item[1] = mode)
            ShowToast(T("m_refresh"), item[2], "30A46C")
}

SetDuration(ms, *) {
    global toastMs
    toastMs := ms
    SaveSettings()
    UpdateChecks()
    ShowToast(T("t_dur"), ms / 1000 T("sec"), "30A46C")
}

SetLanguage(code, *) {
    global langSetting, lang
    langSetting := code
    lang := (code = "auto") ? DetectLang() : code
    SaveSettings()
    BuildMenu()
    UpdateChecks()
    UpdateTray()
    ShowToast(T("t_lang"), "", "30A46C")
}

SoftRefresh() {
    ; the same message Windows broadcasts when laptop/tablet mode changes
    DllCall("SendMessageTimeoutW", "ptr", 0xFFFF, "uint", 0x1A, "uptr", 0, "str", "ConvertibleSlateMode", "uint", 2, "uint", 1000, "ptr*", &res := 0)
}

; ===== autostart via Task Scheduler =====
TaskExists() {
    return RunWait(A_ComSpec ' /c schtasks /query /tn "TouchBlock" >nul 2>&1', , "Hide") = 0
}

PsQ(s) {
    return StrReplace(s, "'", "''")
}

ToggleStartup(*) {
    global startupOn, appDir
    if startupOn {
        RunWait(A_ComSpec ' /c schtasks /delete /tn "TouchBlock" /f >nul 2>&1', , "Hide")
    } else {
        exe := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
        arg := A_IsCompiled ? "" : " -Argument '" Chr(34) PsQ(A_ScriptFullPath) Chr(34) "'"
        code := "$ErrorActionPreference = 'Stop'`r`n"
            . "$a = New-ScheduledTaskAction -Execute '" PsQ(exe) "'" arg "`r`n"
            . "$t = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME`r`n"
            . "$t.Delay = 'PT10S'`r`n"
            . "$p = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest`r`n"
            . "$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0`r`n"
            . "Register-ScheduledTask -TaskName 'TouchBlock' -Action $a -Trigger $t -Principal $p -Settings $s -Force | Out-Null`r`n"
        ps1 := appDir "\startup.ps1"
        try FileDelete(ps1)
        f := FileOpen(ps1, "w", "UTF-8")
        f.Write(code)
        f.Close()
        RunWait(A_ComSpec ' /c powershell -NoProfile -ExecutionPolicy Bypass -File "' ps1 '" >nul 2>&1', , "Hide")
    }
    startupOn := TaskExists()
    UpdateChecks()
    if startupOn
        ShowToast(T("t_start_on"), T("t_start_on2"), "30A46C")
    else
        ShowToast(T("t_start_off"), "", "F5A524")
}

; ===== resume from sleep =====
OnPower(wParam, lParam, msg, hwnd) {
    if (wParam = 7 || wParam = 18)      ; PBT_APMRESUMESUSPEND / PBT_APMRESUMEAUTOMATIC
        SetTimer(AfterResume, -3000)
}

AfterResume() {
    global autoMode, lastState, touchOn
    if autoMode {
        mode := DllCall("GetSystemMetrics", "int", 0x2003)
        lastState := mode
        SetTouch(mode = 0, false, true)
    } else {
        SetTouch(touchOn, false, true)
    }
}

; ===== tray icon =====
RefreshTrayIcon() {
    global touchOn, iconOn, iconOff
    try {
        A_IconHidden := true
        A_IconHidden := false
    }
    try TraySetIcon(touchOn ? iconOn : iconOff)
}

FixTray() {
    global fixCount
    fixCount += 1
    RefreshTrayIcon()
    if (fixCount >= 3)
        SetTimer(FixTray, 0)
}

; ===== main logic =====
UpdateTray() {
    global touchOn, iconOn, iconOff, statusItem
    try TraySetIcon(touchOn ? iconOn : iconOff)
    A_IconTip := T(touchOn ? "tip_on" : "tip_off") (autoMode ? "" : T("manual"))
    newName := StatusText()
    if (newName != statusItem) {
        A_TrayMenu.Rename(statusItem, newName)
        A_TrayMenu.Disable(newName)
        statusItem := newName
    }
}

CheckMode() {
    global lastState, autoMode, busy
    if (!autoMode || busy)
        return
    mode := DllCall("GetSystemMetrics", "int", 0x2003)  ; 1 = laptop, 0 = tablet
    if (mode = lastState)
        return
    lastState := mode
    SetTouch(mode = 0)
}

Log(msg) {
    global logFile
    try FileAppend(A_Now " " msg "`n", logFile, "UTF-8")
}

FindTouchIds() {
    ids := []
    try {
        wmi := ComObjGet("winmgmts:\\.\root\cimv2")
        q := "SELECT PNPDeviceID FROM Win32_PnPEntity WHERE Name LIKE '%сенсорный экран%' OR Name LIKE '%touch screen%'"
        for dev in wmi.ExecQuery(q)
            ids.Push(dev.PNPDeviceID)
    }
    return ids
}

DeviceCmd(enable, id, viaPs) {
    global logFile
    if viaPs
        cmd := A_ComSpec ' /c chcp 65001 >nul & powershell -NoProfile -ExecutionPolicy Bypass -Command "' (enable ? "Enable" : "Disable") "-PnpDevice -InstanceId '" id "' -Confirm:$false -ErrorAction Stop" '" >> "' logFile '" 2>&1'
    else
        cmd := A_ComSpec ' /c chcp 65001 >nul & pnputil /' (enable ? "enable" : "disable") '-device "' id '" >> "' logFile '" 2>&1'
    code := RunWait(cmd, , "Hide")
    Log("id=" id " " (viaPs ? "powershell" : "pnputil") "=" code)
    return code
}

SetTouch(enable, refresh := true, quiet := false) {
    global touchOn, touchIds, refreshDelay, lastInfo, usePs, busy, refreshMode
    if busy
        return
    busy := true
    prev := touchOn
    touchOn := enable
    UpdateTray()

    if !touchIds.Length
        touchIds := FindTouchIds()

    ok := touchIds.Length > 0
    lastInfo := T("found") touchIds.Length
    Log((enable ? "enable" : "disable") " found=" touchIds.Length)

    for id in touchIds {
        code := 1
        if !usePs {
            code := DeviceCmd(enable, id, false)
            lastInfo .= ", pnputil: " code
        }
        if (usePs || (code != 0 && code != 3010)) {
            code := DeviceCmd(enable, id, true)
            lastInfo .= ", PowerShell: " code
            if (code = 0)
                usePs := true
        }
        if (code != 0 && code != 3010)
            ok := false
    }

    if !ok {
        touchIds := []                   ; look the device up again next time
        touchOn := prev
        UpdateTray()
    }

    if (ok && enable && refresh) {
        if (refreshMode = 1) {
            SoftRefresh()
        } else if (refreshMode = 2) {
            Sleep(refreshDelay)
            Send("#^+b")                 ; Win+Ctrl+Shift+B, restart the graphics stack
        }
    }
    busy := false

    if !ok
        ShowToast(T("t_error"), lastInfo, "E5484D", true)
    else if quiet
        return
    else if enable
        ShowToast(T("t_touch_on"), T("t_touch_on2"), "30A46C")
    else
        ShowToast(T("t_touch_off"), T("t_touch_off2"), "F5A524")
}

; ===== notifications =====
ShowToast(title, subtitle, color, force := false) {
    global toastGui, toastAlpha, notify, toastMs
    if (!notify && !force)
        return
    SetTimer(ToastHide, 0)
    SetTimer(ToastFade, 0)
    if toastGui {
        try toastGui.Destroy()
        toastGui := ""
    }

    s := A_ScreenDPI / 96
    w := Round(300 * s), h := Round(76 * s)

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
    g.BackColor := "202020"
    g.MarginX := 0, g.MarginY := 0

    g.Add("Text", "x0 y0 w" Round(7 * s) " h" h " Background" color)

    g.SetFont("s12 w600 cFFFFFF", "Segoe UI")
    g.Add("Text", "x" Round(26 * s) " y" Round(13 * s) " w" Round(260 * s) " BackgroundTrans", title)

    g.SetFont("s9 w400 cA0A0A0", "Segoe UI")
    g.Add("Text", "x" Round(26 * s) " y" Round(43 * s) " w" Round(260 * s) " BackgroundTrans", subtitle)

    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
    x := r - w - Round(16 * s)
    y := b - h - Round(16 * s)
    g.Show("NoActivate x" x " y" y " w" w " h" h)
    WinSetRegion("0-0 w" w " h" h " r" Round(18 * s) "-" Round(18 * s), g.Hwnd)

    toastGui := g
    toastAlpha := 255
    SetTimer(ToastHide, -toastMs)
}

ToastHide() {
    SetTimer(ToastFade, 30)
}

ToastFade() {
    global toastGui, toastAlpha
    toastAlpha -= 25
    if (toastAlpha <= 0) {
        SetTimer(ToastFade, 0)
        try toastGui.Destroy()
        toastGui := ""
        return
    }
    try WinSetTransparent(toastAlpha, toastGui.Hwnd)
}

OnExit((*) => SetTouch(true, false, true))
