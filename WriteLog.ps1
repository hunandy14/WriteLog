# 輸出LOG
function WriteLog {
    param (
        [Parameter(Position = 0, ParameterSetName = "")]
        [String] $Path,
        [Parameter(Position = 1, ParameterSetName = "")]
        [String] $FormatType = "yyyy/MM/dd HH:mm:ss.fff",

        [Parameter(ParameterSetName = "")]
        [Text.Encoding] $Encoding,
        [Switch] $UTF8,
        [Switch] $UTF8BOM,
        
        [Parameter(ParameterSetName = "")]
        [Switch] $NoDate,
        [Switch] $OutNull,
        
        [Parameter(ValueFromPipeline)]
        [String] $Msg
    )
    # 檢測路徑
    if  (!$Path) {
        if ($PSCommandPath) {
            $Path = ((Get-Item $PSCommandPath).BaseName + ".log")
        } else { Write-Error "Input Path `"$Path`" is Null."; return }
    } $Path = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location -PSProvider FileSystem).ProviderPath, $Path))
    
    # 處理編碼
    if (!$Encoding) {
        if ($UTF8) {              # 預選項1 : UTF8
            $Enc = New-Object System.Text.UTF8Encoding $False
        } elseif ($UTF8BOM) {     # 預選項2 : UTF8BOM
            $Enc = New-Object System.Text.UTF8Encoding $True
        } else {                  # 預設編碼: 系統語言
            if (!$__SysEnc__) {
                $Script:__SysEnc__ = [Text.Encoding]::GetEncoding((powershell -nop "([Text.Encoding]::Default).WebName"))
            } $Enc = $__SysEnc__
        }
    } else { $Enc = $Encoding }
    
    # 追加時間標記
    if ($NoDate) { $LogStr = $Msg } else {
        $LogStr = "[$((Get-Date).Tostring($FormatType))] $Msg"
    }
    
    # 輸出檔案
    if (!(Test-Path $Path)) { New-Item $Path -Force | Out-Null }
    [IO.File]::AppendAllText($Path, "$LogStr`r`n", $Enc)
    if (!$OutNull) {
        if ($Msg -match "^Error:: ") {
            Write-Host $LogStr -ForegroundColor:Red
        } elseif ($Msg -match "^Warring:: ") {
            Write-Host $LogStr -ForegroundColor:Yellow
        } elseif ($Msg -match "^Info:: ") {
            Write-Host $LogStr -ForegroundColor:Yellow
        } else {
            Write-Host $LogStr
        }
    }
} # ("ABCDEㄅㄆㄇㄈあいうえお")|WriteLog -UTF8BOM
# ("ABCDEㄅㄆㄇㄈあいうえお")|WriteLog 'log\WriteLog.log' -UTF8BOM
# ("Error:: ABCDEㄅㄆㄇㄈあいうえお")|WriteLog 'log\WriteLog.log' -UTF8BOM
# ("ABCDEㄅㄆㄇㄈあいうえお")|WriteLog -Encoding ([Text.Encoding]::GetEncoding('UTF-8')) -UTF8BOM
# ("ABCDEㄅㄆㄇㄈあいうえお")|WriteLog -OutNull -UTF8BOM
# @("ABCDE", "ㄅㄆㄇㄈ", "あいうえお") -join "`r`n" |WriteLog -UTF8BOM
# (@("ABCDE", "ㄅㄆㄇㄈ", "あいうえお")|Out-String).TrimEnd("`r`n") |WriteLog -UTF8BOM
