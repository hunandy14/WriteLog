PowerSell 日誌輸出器
===

快速使用
```ps1
irm bit.ly/WriteLog|iex; "ABCDE" |WriteLog '.\WriteLog.log'
```

詳細說明
```ps1
# 載入函式庫
irm bit.ly/WriteLog|iex;

# 指定輸出路徑
"ABCDE" |WriteLog '.\WriteLog.log'

# 指定輸出編碼為
"ABCDEㄅㄆㄇㄈあいうえお" |WriteLog -UTF8
"ABCDEㄅㄆㄇㄈあいうえお" |WriteLog -UTF8BOM
"ABCDEㄅㄆㄇㄈあいうえお" |WriteLog -Encoding ([Text.Encoding]::GetEncoding('UTF-8'))
"ABCDEㄅㄆㄇㄈあいうえお" |WriteLog -Encoding ([Text.Encoding]::GetEncoding(950))

# 自訂日期格式
"ABCDEㄅㄆㄇㄈあいうえお" |WriteLog -FormatType "yyyy/MM/dd HH:mm:ss.fff"

# 不輸出日期
"ABCDEㄅㄆㄇㄈあいうえお" |WriteLog -NoDate

# 不輸出到終端機上
"ABCDEㄅㄆㄇㄈあいうえお" |WriteLog -OutNull

# 輸入為物件處理範例
@("ABCDE", "ㄅㄆㄇㄈ", "あいうえお") -join "`r`n" |WriteLog
(@("ABCDE", "ㄅㄆㄇㄈ", "あいうえお")|Out-String).TrimEnd("`r`n") |WriteLog

```
