# 修改後的 Register-Logger 函數，將 Rotate-LogFile 設置為閉包並移除不必要的參數
function Register-Logger {
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Path,
        [string]$FunctionName = 'Write-LogFile',
        [string]$DateFormat = 'yyyy-MM-dd HH:mm:ss.fff',
        [Switch]$ShowCallerInfo,
        [Text.Encoding]$Encoding = (New-Object System.Text.UTF8Encoding $True),
        [int]$MaxSize = 10MB,
        [int]$MaxFiles = 5
    ) [IO.Directory]::SetCurrentDirectory(((Get-Location -PSProvider FileSystem).ProviderPath))

    # 檢測路徑
    $Path = [IO.Path]::GetFullPath($Path)
    if (!(Test-Path $Path)) { New-Item $Path -Force | Out-Null }

    # 定義日誌級別及其對應的顏色和固定長度
    $LogLevels = @{
        'INFO'     = @{ Color = 'Green';    Label = 'INFO   ' }
        'WARNING'  = @{ Color = 'Yellow';   Label = 'WARNING' }
        'ERROR'    = @{ Color = 'Red';      Label = 'ERROR  ' }
    }

    # 創建日誌函數的腳本塊
    $logScriptBlock = {
        param(
            [string]$Message,
            [ValidateSet('INFO', 'WARNING', 'ERROR')]
            [string]$Level = 'INFO',
            [ValidateSet('stdout', 'stderr')]
            [string]$ConsoleChannel = 'stdout',
            [int]$ExitCode
        )

        # 獲取當前時間戳，格式為 yyyy-MM-dd HH:mm:ss.fff
        $timestamp = [DateTime]::Now.ToString($DateFormat)

        # 如果啟用了 ShowCallerInfo，則獲取調用堆棧信息或文件名
        $callerInfo = ""
        if ($ShowCallerInfo) {
            $callerInfo = (Get-PSCallStack)[1].Command
        }

        # 獲取對應的顏色和標籤
        $levelInfo = $LogLevels[$Level]
        $levelColor = $levelInfo.Color
        $levelLabel = $levelInfo.Label
        $dateColor = 'DarkGray'

        # 生成日誌條目，包含或不包含調用者信息
        if ($ShowCallerInfo) {
            $logEntry = "$timestamp $levelLabel $callerInfo - $Message"
        } else {
            $logEntry = "$timestamp $levelLabel - $Message"
        }

        # 根據 ConsoleChannel 的值來決定輸出到哪個通道
        if ($ConsoleChannel -eq 'stderr') {
            $orgEnc = [Console]::OutputEncoding; try {
                [Console]::OutputEncoding = [Text.Encoding]::Default
                [Console]::Error.WriteLine($logEntry)
            } finally { [Console]::OutputEncoding = $orgEnc }
        } else {
            # 輸出日期部分
            Write-Host -NoNewline -ForegroundColor $dateColor "$timestamp "
            # 輸出級別部分，使用指定的顏色
            Write-Host -NoNewline -ForegroundColor $levelColor "$levelLabel "
            # 如果啟用了，輸出函數名稱或文件名
            if ($ShowCallerInfo) { Write-Host -NoNewline "$callerInfo " }
            # 輸出訊息部分，使用默認顏色
            Write-Host "- $Message"
        }

        # 寫入日誌文件，並加上錯誤處理
        try {
            [System.IO.File]::AppendAllText($Path, "$logEntry`r`n", $Encoding)
        } catch {
            $exceptionType = $_.Exception.GetType().Name
            $exceptionMessage = ($_.Exception.Message)
            Write-Error "寫入日誌文件失敗: [$exceptionType] $exceptionMessage" -EA Stop
        }

        # 如果提供了 ExitCode，退出程序
        if ($PSBoundParameters.ContainsKey('ExitCode')) { exit $ExitCode }
    }

    # 檢查日誌文件大小，超過 MaxSizeMB 則進行滾動
    $RotateLogFile = {
        
        # 檢查日誌文件大小是否超過指定的最大值
        if (((Get-Item $Path -ErrorAction Stop).Length) -ge $MaxSize) {
            # 獲取現有的日誌備份文件數量
            $files = Get-Item "$Path.[1-$MaxFiles]" -ErrorAction SilentlyContinue
            $cuIdx = if ($files) { [int]($files[-1].Extension.TrimStart('.')) } else { 0 }
            $nextidx = if ($cuIdx -ge $MaxFiles) { $cuIdx } else { $cuIdx + 1 }

            # 定義遞迴重命名函數
            $rename_log = {
                param (
                    [string]$cuName,  # 當前文件名稱
                    [int]$cuIdx       # 當前文件索引
                )

                # 停止條件：索引小於 1 時停止
                if ($cuIdx -eq 0) { return }
                $oldFileName = "$Path.$cuIdx"

                # 如果當前索引的文件存在，遞迴重命名上一個文件
                if (Test-Path $oldFileName) {
                    rename_log $oldFileName ($cuIdx - 1)
                }

                # 執行重命名操作
                Write-Host "重命名 $cuName -> $oldFileName" -ForegroundColor yellow
                Move-Item $cuName $oldFileName -Force | Out-Null
            }

            # 呼叫遞迴重命名函數
            &$rename_log $Path $nextidx
        }
    }

    # 檢查並滾動日誌文件
    & $RotateLogFile

    # 創建閉包，捕獲外部變量
    $logScriptBlock = $logScriptBlock.GetNewClosure()
    
    # 註冊日誌函數
    Set-Item -Path Function:Script:$FunctionName -Value $logScriptBlock
}

# 使用 Register-Logger 註冊日誌函數，並啟用 ShowCallerInfo
# Register-Logger -Path 'projectA.log' -Encoding ([Text.Encoding]::UTF8)

# 使用標準通道輸出訊息
# Write-LogFile "這是一個信息訊息"

# 使用標準通道輸出警告訊息
# Write-LogFile "這是一個腳本內的警告訊息" -Level 'WARNING'

# 使用錯誤通道輸出錯誤訊息
# Write-LogFile "這是一個錯誤訊息" -Level 'ERROR' -ConsoleChannel stderr -ExitCode 1
