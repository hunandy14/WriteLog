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
    # 設定值
    if (!$__LoggerSetting__) {
        $Script:__LoggerSetting__ = [PSCustomObject]@{
            MaxFileSize    = 10MB;
            MaxBackupIndex = 5
        }
    }
    
    # 檢測路徑
    if  (!$Path) {
        if ($PSCommandPath) {
            $Path = ((Get-Item $PSCommandPath).BaseName + ".log")
        } else { Write-Error "Input Path `"$Path`" is Null."; return }
    } $Path = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location -PSProvider FileSystem).ProviderPath, $Path))
            
    # 日誌檔案大小管理超出限制自動備份
    $MxSiz = $__LoggerSetting__.MaxFileSize
    $MxIdx = $__LoggerSetting__.MaxBackupIndex
    if (((Get-ChildItem $Path).Length) -ge $MxSiz) {
        # 獲取清單
        $FileName  = [IO.Path]::GetFileNameWithoutExtension($Path)
        $Extension = [IO.Path]::GetExtension($Path)
        $FileDir   = [IO.Path]::GetDirectoryName($Path)
        $List = @(); for ($i = 1; $i -lt $MxIdx; $i++) {
            $LogFile = "$FileName`_$i$Extension"
            if (Test-Path $LogFile) { $List += Get-ChildItem $LogFile }
        }
        # 備份檔案
        $BkName = "$FileDir\"+ $FileName+ "_1"+ $Extension
        for ($i = 0; $i -lt $List.Count; $i++) {
            $Item   = $List[$i]
            $idx = $i+1
            $Dir = Split-Path $Item
            if ($List.Count -lt ($MxIdx-1)) {
                $Name1  = "$Dir\"+ $Item.Name
                $Name2  = "$Dir\"+ $FileName+ "_$idx"+ $Item.Extension
                $BkName = "$Dir\"+ $FileName+ "_$($idx+1)"+ $Item.Extension
                if (($Name1 -ne $Name2) -and ($Name1 -match ".log$")) {
                    # Write-Host "備份重命名:: $Name1 -> $Name2"
                    Move-Item $Name1 $Name2 -Force |Out-Null
                }
            } else {
                if ($i -gt 0) {
                    $Name1  = "$Dir\"+ $Item.Name
                    $Name2  = "$Dir\"+ $FileName+ "_$i"+ $Item.Extension
                    $BkName = "$Dir\"+ $FileName+ "_$($i+1)"+ $Item.Extension
                    if (($Name1 -ne $Name2) -and ($Name1 -match ".log$")) {
                        # Write-Host "滿了重命名:: $Name1 -> $Name2"
                        Move-Item $Name1 $Name2 -Force |Out-Null
                    }
                }
            }
        }
        if ($Path -and $BkName -and ($Path -match ".log$")) {
            # Write-Host "備份日誌檔:: $Path -> $BkName"
            Move-Item $Path $BkName -Force |Out-Null
        }
    }
    
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
# $Script:__LoggerSetting__ = $Null; ("ABCDEㄅㄆㄇㄈあいうえお")|WriteLog -UTF8BOM
