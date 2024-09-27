# �ק�᪺ Register-Logger ��ơA�N Rotate-LogFile �]�m�����]�ò��������n���Ѽ�
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

    # �˴����|
    $Path = [IO.Path]::GetFullPath($Path)
    if (!(Test-Path $Path)) { New-Item $Path -Force | Out-Null }

    # �w�q��x�ŧO�Ψ�������C��M�T�w����
    $LogLevels = @{
        'INFO'     = @{ Color = 'Green';    Label = 'INFO   ' }
        'WARNING'  = @{ Color = 'Yellow';   Label = 'WARNING' }
        'ERROR'    = @{ Color = 'Red';      Label = 'ERROR  ' }
    }

    # �Ыؤ�x��ƪ��}����
    $logScriptBlock = {
        param(
            [string]$Message,
            [ValidateSet('INFO', 'WARNING', 'ERROR')]
            [string]$Level = 'INFO',
            [ValidateSet('stdout', 'stderr')]
            [string]$ConsoleChannel = 'stdout',
            [int]$ExitCode
        )

        # �����e�ɶ��W�A�榡�� yyyy-MM-dd HH:mm:ss.fff
        $timestamp = [DateTime]::Now.ToString($DateFormat)

        # �p�G�ҥΤF ShowCallerInfo�A�h����եΰ�̫H���Τ��W
        $callerInfo = ""
        if ($ShowCallerInfo) {
            $callerInfo = (Get-PSCallStack)[1].Command
        }

        # ����������C��M����
        $levelInfo = $LogLevels[$Level]
        $levelColor = $levelInfo.Color
        $levelLabel = $levelInfo.Label
        $dateColor = 'DarkGray'

        # �ͦ���x���ءA�]�t�Τ��]�t�եΪ̫H��
        if ($ShowCallerInfo) {
            $logEntry = "$timestamp $levelLabel $callerInfo - $Message"
        } else {
            $logEntry = "$timestamp $levelLabel - $Message"
        }

        # �ھ� ConsoleChannel ���ȨӨM�w��X����ӳq�D
        if ($ConsoleChannel -eq 'stderr') {
            $orgEnc = [Console]::OutputEncoding; try {
                [Console]::OutputEncoding = [Text.Encoding]::Default
                [Console]::Error.WriteLine($logEntry)
            } finally { [Console]::OutputEncoding = $orgEnc }
        } else {
            # ��X�������
            Write-Host -NoNewline -ForegroundColor $dateColor "$timestamp "
            # ��X�ŧO�����A�ϥΫ��w���C��
            Write-Host -NoNewline -ForegroundColor $levelColor "$levelLabel "
            # �p�G�ҥΤF�A��X��ƦW�٩Τ��W
            if ($ShowCallerInfo) { Write-Host -NoNewline "$callerInfo " }
            # ��X�T�������A�ϥ��q�{�C��
            Write-Host "- $Message"
        }

        # �g�J��x���A�å[�W���~�B�z
        try {
            [System.IO.File]::AppendAllText($Path, "$logEntry`r`n", $Encoding)
        } catch {
            $exceptionType = $_.Exception.GetType().Name
            $exceptionMessage = ($_.Exception.Message)
            Write-Error "�g�J��x��󥢱�: [$exceptionType] $exceptionMessage" -EA Stop
        }

        # �p�G���ѤF ExitCode�A�h�X�{��
        if ($PSBoundParameters.ContainsKey('ExitCode')) { exit $ExitCode }
    }

    # �ˬd��x���j�p�A�W�L MaxSizeMB �h�i��u��
    $RotateLogFile = {
        
        # �ˬd��x���j�p�O�_�W�L���w���̤j��
        if (((Get-Item $Path -ErrorAction Stop).Length) -ge $MaxSize) {
            # ����{������x�ƥ����ƶq
            $files = Get-Item "$Path.[1-$MaxFiles]" -ErrorAction SilentlyContinue
            $cuIdx = if ($files) { [int]($files[-1].Extension.TrimStart('.')) } else { 0 }
            $nextidx = if ($cuIdx -ge $MaxFiles) { $cuIdx } else { $cuIdx + 1 }

            # �w�q���j���R�W���
            $rename_log = {
                param (
                    [string]$cuName,  # ��e���W��
                    [int]$cuIdx       # ��e������
                )

                # �������G���ޤp�� 1 �ɰ���
                if ($cuIdx -eq 0) { return }
                $oldFileName = "$Path.$cuIdx"

                # �p�G��e���ު����s�b�A���j���R�W�W�@�Ӥ��
                if (Test-Path $oldFileName) {
                    rename_log $oldFileName ($cuIdx - 1)
                }

                # ���歫�R�W�ާ@
                Write-Host "���R�W $cuName -> $oldFileName" -ForegroundColor yellow
                Move-Item $cuName $oldFileName -Force | Out-Null
            }

            # �I�s���j���R�W���
            &$rename_log $Path $nextidx
        }
    }

    # �ˬd�úu�ʤ�x���
    & $RotateLogFile

    # �Ыس��]�A����~���ܶq
    $logScriptBlock = $logScriptBlock.GetNewClosure()
    
    # ���U��x���
    Set-Item -Path Function:Script:$FunctionName -Value $logScriptBlock
}

# �ϥ� Register-Logger ���U��x��ơA�ñҥ� ShowCallerInfo
# Register-Logger -Path 'projectA.log' -Encoding ([Text.Encoding]::UTF8)

# �ϥμзǳq�D��X�T��
# Write-LogFile "�o�O�@�ӫH���T��"

# �ϥμзǳq�D��Xĵ�i�T��
# Write-LogFile "�o�O�@�Ӹ}������ĵ�i�T��" -Level 'WARNING'

# �ϥο��~�q�D��X���~�T��
# Write-LogFile "�o�O�@�ӿ��~�T��" -Level 'ERROR' -ConsoleChannel stderr -ExitCode 1
