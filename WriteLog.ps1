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
        
        [Parameter(ParameterSetName = "")]
        [ValidateSet( # 信息層級
            'OFF',          # 無
            'FATAL',        # 紅底
            'ERROR',        # 紅字
            'WARN',         # 黃字
            'INFO',         # 無
            'DEBUG',        # 白字
            'TRACE',        # 藍字
            'ALL'           # 無
        )]
        [String] $Level,
        
        [Parameter(ValueFromPipeline)]
        [String] $Msg
    )
    # 設定值
    if (!$__LoggerSetting__) {
        $Script:__LoggerSetting__ = [PSCustomObject]@{
            LogLevel       = 'INFO'
            MsgLevel       = 'INFO'
            MaxFileSize    = 10MB
            MaxBackupIndex = 5
        }
    }
    
    # 檢測路徑
    if  (!$Path) {
        if ($PSCommandPath) {
            $Path = ((Get-Item $PSCommandPath).BaseName + ".log")
        } else { Write-Error "Input Path `"$Path`" is Null."; return }
    } $Path = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location -PSProvider FileSystem).ProviderPath, $Path))
    if (!(Test-Path $Path)) { New-Item $Path -Force | Out-Null }
            
    # 日誌檔案大小管理超出限制自動備份
    $MxSiz = $__LoggerSetting__.MaxFileSize
    $MxIdx = $__LoggerSetting__.MaxBackupIndex
    if (((Get-ChildItem $Path -EA:Stop).Length) -ge $MxSiz) {
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
       
    # 獲取層級映射表
    $LvTable   = (Get-Variable "Level").Attributes.ValidValues
    $LvMapping = @{}; for ($i = 0; $i -lt $LvTable.Count; $i++) { $LvMapping += @{$LvTable[$i]=$i} }
    # 獲取日誌層級
    $LogLvInfo = $__LoggerSetting__.LogLevel
    if (!$LogLvInfo) { $LogLvInfo = $LvTable[($LvTable.Count-1)] } # 全域值打錯時的預設值
    $LogLvRank = $LvMapping[$LogLvInfo]
    # Write-Host "Logレベル:: [$LogLvInfo,$LogLvRank]"
    # 獲取信息層級
    if (!$Level) {
        $MsgLvInfo = $__LoggerSetting__.MsgLevel
        if (!$MsgLvInfo) { $MsgLvInfo = $LvTable[0] } # 全域值打錯時的預設值
    } else { $MsgLvInfo = $Level }
    $MsgLvRank = $LvMapping[$MsgLvInfo]
    # Write-Host "Msgレベル:: [$MsgLvInfo,$MsgLvRank]"
    
    # 時間標記
    if (!$NoDate) { $Date = "[$((Get-Date).Tostring($FormatType))] " } else { $Date = "" }
    
    # 輸出日誌
    if (($LogLvRank -ge $MsgLvRank) -and ($LogLvRank -gt 0)) {
        # Write-Host "ログに出力しました。"
        [IO.File]::AppendAllText($Path, "$Date$Msg`r`n", $Enc)
    } else { $Msg = "*$Msg" } # 信息層級低於日誌層級時添加星號警示
    
    # 輸出到終端機
    if (!$OutNull) {
        if ($Null) {
        } elseif ($Msg -match "^OFF::") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg
        } elseif ($Msg -match "^FATAL::") {
            Write-Host $Date -NoNewline -ForegroundColor:Red
            Write-Host $Msg -ForegroundColor:Red
        } elseif ($Msg -match "^ERROR::") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg -ForegroundColor:Red
        } elseif ($Msg -match "^WARN::") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg -ForegroundColor:Yellow
        } elseif ($Msg -match "^INFO::") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg
        } elseif ($Msg -match "^DEBUG::") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg
        } elseif ($Msg -match "^TRACE::") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg
        } elseif ($Msg -match "^ALL::") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg
        } else {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg
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
# $Script:__LoggerSetting__ = $Null; ("ABCDEㄅㄆㄇㄈあいうえお")|WriteLog -UTF8BOM

# $Script:__LoggerSetting__ = [PSCustomObject]@{
#     LogLevel       = ''
#     MsgLevel       = ''
#     MaxFileSize    = 10MB
#     MaxBackupIndex = 5
# }
# 'OFF::OFF'     |WriteLog -UTF8BOM
# 'FATAL::FATAL' |WriteLog -UTF8BOM
# 'ERROR::ERROR' |WriteLog -UTF8BOM
# 'WARN::WARN'   |WriteLog -UTF8BOM
# 'INFO::INFO'   |WriteLog -UTF8BOM
# 'DEBUG::DEBUG' |WriteLog -UTF8BOM
# 'TRACE::TRACE' |WriteLog -UTF8BOM
# 'ALL::ALL'     |WriteLog -UTF8BOM
