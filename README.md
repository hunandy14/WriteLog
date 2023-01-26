PowerSell 日誌輸出器
===

快速使用
```ps1
irm bit.ly/WriteLog|iex; "ABCDE" |WriteLog '.\WriteLog.log'
```

<br>

詳細說明
```ps1
# 載入函式庫
irm bit.ly/WriteLog|iex;

# 指定輸出路徑 (優先度：參數, 全域, 檔名)
"ABCDE" |WriteLog '.\WriteLog.log'
$Script:__LoggerSetting__ = @{Path = Pwsh.log}

# 指定輸出編碼
"ABCDEㄅㄆㄇㄈあいうえお" |WriteLog -UTF8
"ABCDEㄅㄆㄇㄈあいうえお" |WriteLog -UTF8BOM
"ABCDEㄅㄆㄇㄈあいうえお" |WriteLog -Encoding ([Text.Encoding]::GetEncoding('UTF-8'))
"ABCDEㄅㄆㄇㄈあいうえお" |WriteLog -Encoding ([Text.Encoding]::GetEncoding(950))
$Script:__LoggerSetting__ = @{Encoding=65001}
$Script:__LoggerSetting__ = @{Encoding='UTF-8'}

# 自訂日期格式
"LogMsg" |WriteLog -FormatType "yyyy/MM/dd HH:mm:ss.fff"

# 不輸出日期
"LogMsg" |WriteLog -NoDate

# 不輸出到終端機上
"LogMsg" |WriteLog -OutNull

# 設定日誌層級 ('OFF', 'FATAL', 'ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE', 'ALL')
$Script:__LoggerSetting__ = @{LogLevel='ALL'}
# 設定信息層級 ('FATAL', 'ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE')
'LogMsg' |WriteLog -UTF8BOM -Level ERROR
'WARN::LogMsg' |WriteLog

# 自動追加層級字串
'LogMsg' |WriteLog -Level ERROR -AddLevelToMsg

# 指定日誌檔案大小與數量 (預設::10MB, 5)
$Script:__LoggerSetting__ = @{MaxFileSize=10MB; MaxBackupIndex=5}

```

<br><br><br>

輸入為物件處理範例
```ps1
@("ABCDE", "ㄅㄆㄇㄈ", "あいうえお") -join "`r`n" |WriteLog
(@("ABCDE", "ㄅㄆㄇㄈ", "あいうえお")|Out-String).TrimEnd("`r`n") |WriteLog
```
