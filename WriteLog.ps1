# 輸出LOG
function WriteLog {
    param (
        [Parameter(Position = 0, ParameterSetName = "")]
        [String] $Path, # 優先度：參數, 全域, 檔名
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
            'FATAL',        # 紅字且日期也紅字
            'ERROR',        # 紅字
            'WARN',         # 黃字
            'INFO',         # 藍
            'DEBUG',        # 紫
            'TRACE',        # 無
            'ALL'           # 無
        )]
        [String] $Level,
        [Switch] $AddLevelToMsg,
        
        [Parameter(ValueFromPipeline)]
        [String] $Msg
    )
    # 設定值
    if (!$__LoggerSetting__) {
        $Script:__LoggerSetting__ = [PSCustomObject]@{
            Path           = $Null      # 'Pwsh.log'
            Encoding       = $Null      # New-Object System.Text.UTF8Encoding $True
            LogLevel       = $Null      # 'ALL'
            MsgLevel       = $Null      # 'INFO'
            AddLevelToMsg  = $Null      # $False
            MaxFileSize    = $Null      # 10MB
            MaxBackupIndex = $Null      # 5
        }
    }
    
    # 檢測路徑
    if  (!$Path) {
        if ($__LoggerSetting__.Path) {
            $Path = $__LoggerSetting__.Path
        } elseif ($PSCommandPath) {
            $Path = ((Get-Item $PSCommandPath).BaseName + ".log")
        } else { Write-Error "Input Path `"$Path`" is Null."; return }
    } $Path = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location -PSProvider FileSystem).ProviderPath, $Path))
    if (!(Test-Path $Path)) { New-Item $Path -Force | Out-Null }
    
    # 日誌檔案大小管理超出限制自動備份
    $MxSiz = $__LoggerSetting__.MaxFileSize
    $MxIdx = $__LoggerSetting__.MaxBackupIndex
    if (!$MxSiz -or ($MxSiz -le 0)) { $MxSiz = 10MB }
    if (!$MxSiz -or ($MxIdx -le 0)) { $MxIdx = 5 }
    # Write-Host "MxSiz=$MxSiz, MxIdx=$MxIdx"
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
        } else {                  # 預設編碼: 全域值設定, 系統語言
            if ($__LoggerSetting__.Encoding) {
                $Enc = $__LoggerSetting__.Encoding
            } else {
                if (!$__SysEnc__) {
                    $Script:__SysEnc__ = [Text.Encoding]::GetEncoding((powershell -nop "([Text.Encoding]::Default).WebName"))
                } $Enc = $__SysEnc__
            }
        }
    } else { $Enc = $Encoding }
    
    
    
    # 獲取層級映射表
    $LvTable   = (Get-Variable "Level").Attributes.ValidValues
    $LvMapping = @{}; for ($i = 0; $i -lt $LvTable.Count; $i++) { $LvMapping += @{$LvTable[$i]=[int]$i} }
    # 獲取日誌層級
    $LogLvInfo = $__LoggerSetting__.LogLevel
    if ($LogLvInfo) { $LogLvRank = $LvMapping[$LogLvInfo] }
    if ($LogLvRank -isnot [int]) { # LogLv全域值打錯時的強制校正
        # Write-Host "LogLv全域值打錯時的強制校正"
        $LogLvInfo = $LvTable[($LvTable.Count-1)]
        $LogLvRank = $LvMapping[$LogLvInfo]
    }
    # 獲取信息層級
    if (!$Level) {
        if ($Msg -match "^(.*?)::") { $StrLvInfo = $Matches[1] }
        # Level沒有但是Str有, 且LvMapping裡查的到
        if ($StrLvInfo -and $LvMapping[$StrLvInfo]) {
            $MsgLvInfo = $StrLvInfo
        } else { # Level和Str都沒有取全域值
            $MsgLvInfo = $__LoggerSetting__.MsgLevel
        }
    } else { # Level有就取Level的值, 無視Str
        $MsgLvInfo = $Level
    }
    if ($MsgLvInfo) { $MsgLvRank = $LvMapping[$MsgLvInfo] }
    if ($MsgLvRank -isnot [int]) { # MsgLv的(Str值,全域值)打錯的強制校正
        # Write-Host "MsgLv的(Str值,全域值)打錯的強制校正"
        $MsgLvInfo = $LvTable[0]
        $MsgLvRank = $LvMapping[$MsgLvInfo]
    }
    # Write-Host "Logレベル:: [$LogLvInfo,$LogLvRank]"
    # Write-Host "Msgレベル:: [$MsgLvInfo,$MsgLvRank]"
    
    # 根據層級追加層級信息到Msg字串中
    if (!$AddLevelToMsg -and ($__LoggerSetting__.AddLevelToMsg -is [bool])) {
        # 如果AddLevelToMsg參數沒設定就從全域變數取值
        $AddLevelToMsg = $__LoggerSetting__.AddLevelToMsg
    }
    if ($AddLevelToMsg) {
        # 判定字串層級是否有效
        if ($Msg -match "^(.*?)::") { $StrLvInfo = $Matches[1] }
        if ($StrLvInfo -and $LvMapping[$StrLvInfo]) { # 字串層級有效修改層級
            $Msg = $Msg -replace("^$StrLvInfo","$MsgLvInfo")
        } else { # 字串層級無效直接添加
            $Msg = "$MsgLvInfo::$Msg"
        }
    }
    
    
    
    # 時間標記
    if (!$NoDate) { $Date = "[$((Get-Date).Tostring($FormatType))] " } else { $Date = "" }
    
    # 輸出日誌
    if (($LogLvRank -ge $MsgLvRank) -and ($LogLvRank -gt 0)) {
        # Write-Host "ログに出力しました。"
        [IO.File]::AppendAllText($Path, "$Date$Msg`r`n", $Enc)
    } else { $Date = "*$Date" } # 信息層級低於日誌層級時添加星號警示
    
    # 輸出到終端機
    if (!$OutNull) {
        if ($Null) {
        } elseif ($MsgLvInfo -eq "OFF") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg
        } elseif ($MsgLvInfo -eq "FATAL") {
            Write-Host $Date -NoNewline -ForegroundColor:Red
            Write-Host $Msg -ForegroundColor:Red
        } elseif ($MsgLvInfo -eq "ERROR") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg -ForegroundColor:Red
        } elseif ($MsgLvInfo -eq "WARN") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg -ForegroundColor:Yellow
        } elseif ($MsgLvInfo -eq "INFO") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg -ForegroundColor:Cyan
        } elseif ($MsgLvInfo -eq "DEBUG") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg -ForegroundColor:Magenta
        } elseif ($MsgLvInfo -eq "TRACE") {
            Write-Host $Date -NoNewline -ForegroundColor:DarkGray
            Write-Host $Msg
        } elseif ($MsgLvInfo -eq "ALL") {
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
#     AddLevelToMsg  = $true
#     MaxFileSize    = 0
#     MaxBackupIndex = 0
# }
# 'OFF::LogMsg'   |WriteLog -UTF8BOM
# 'FATAL::LogMsg' |WriteLog -UTF8BOM
# 'ERROR::LogMsg' |WriteLog -UTF8BOM
# 'WARN::LogMsg'  |WriteLog -UTF8BOM
# 'INFO::LogMsg'  |WriteLog -UTF8BOM
# 'DEBUG::LogMsg' |WriteLog -UTF8BOM
# 'TRACE::LogMsg' |WriteLog -UTF8BOM
# 'ALL::LogMsg'   |WriteLog -UTF8BOM
# 'LogMsg' |WriteLog -UTF8BOM -Level:OFF
# 'LogMsg' |WriteLog -UTF8BOM -Level:FATAL
# 'LogMsg' |WriteLog -UTF8BOM -Level:ERROR
# 'LogMsg' |WriteLog -UTF8BOM -Level:WARN
# 'LogMsg' |WriteLog -UTF8BOM -Level:INFO
# 'LogMsg' |WriteLog -UTF8BOM -Level:DEBUG
# 'LogMsg' |WriteLog -UTF8BOM -Level:TRACE
# 'LogMsg' |WriteLog -UTF8BOM -Level:ALL
#
# 'ERROR::ERROR' |WriteLog -UTF8BOM -Level:FATAL
# 'ERROR::ERROR' |WriteLog -UTF8BOM
# 'ABCD' |WriteLog -UTF8BOM -Level:FATAL
# 'ABCD' |WriteLog -UTF8BOM
#
# 'ERROR::ERROR' |WriteLog -UTF8BOM -Level:FATAL -AddLevelToMsg
# 'ERROR' |WriteLog -UTF8BOM -Level:FATAL
# 
# $Script:__LoggerSetting__ = @{LogLevel='OFF'}
# "ABCDE" |WriteLog '.\WriteLog.log'
