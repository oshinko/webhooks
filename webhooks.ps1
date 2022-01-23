Add-Type -AssemblyName System.Windows.Forms

# 定数定義
$MUTEX_NAME = "Global\mutex"  # 多重起動チェック用

# このファイル
$This = Get-ChildItem $PSCommandPath

function Make-Startup-Shortcut {
  # スタートアップに配置するショートカットのパス
  $StartupPath = $env:APPDATA + "\Microsoft\Windows\Start Menu\Programs\Startup"
  $ShortcutPath = "$($StartupPath)\$($This.Name).lnk"

  if (!(Test-Path $ShortcutPath)) {
    # ショートカットが無い場合に生成する
    $ws = New-Object -ComObject WScript.Shell
    $Shortcut = $ws.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.WorkingDirectory = Split-Path -Parent $This
    $Shortcut.Arguments = "-NoProfile -ExecutionPolicy Unrestricted .\" + $This.Name
    $Shortcut.WindowStyle = 7  # 最小化
    $Shortcut.Save()
  }
}

function Main() {
  Make-Startup-Shortcut

  $Mutex = New-Object System.Threading.Mutex($false, $MUTEX_NAME)

  if ($Mutex.WaitOne(0, $false)) {  # 多重起動していない場合
    # タスクバー非表示
    $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

    # アプリケーションコンテキストを作成
    $ApplicationCtx = New-Object System.Windows.Forms.ApplicationContext

    # PowerShell のアイコンを取得
    $Path = Get-Process -id $pid | Select-Object -ExpandProperty Path
    $Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($Path)

    # タスクトレイのアイコンを設定
    $NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $NotifyIcon.Text = (Get-Culture).TextInfo.ToTitleCase($This.BaseName)
    $NotifyIcon.Icon = $icon
    $NotifyIcon.Visible = $true

    # メニューを設定
    $Quit = New-Object System.Windows.Forms.MenuItem
    $Quit.Text = "Quit"
    $Quit.add_Click({ $ApplicationCtx.ExitThread() })
    $NotifyIcon.ContextMenu = New-Object System.Windows.Forms.ContextMenu
    $NotifyIcon.ContextMenu.MenuItems.AddRange($Quit)

    # サーバーを起動
    $HTTPD = Start-Process `
      .\.venv\scripts\flask `
      "run --host 0.0.0.0 --port 8888" `
      -NoNewWindow `
      -PassThru

    # アプリケーションを起動
    [void][System.Windows.Forms.Application]::Run($ApplicationCtx)

    # サーバーを停止 (アプリケーションが Quit された)
    Stop-Process -Id $HTTPD.Id

    $NotifyIcon.Visible = $false
    $Mutex.ReleaseMutex()
  }

  $Mutex.Close()
}

Main
