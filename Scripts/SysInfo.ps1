param($ControllerProcessID, $PhysicalCPUs)

Import-Module ".\Modules\Include.psm1"

Set-OsFlags

if ($IsLinux) {Import-Module ".\Modules\OCDaemon.psm1"}

$ControllerProcess = Get-Process -Id $ControllerProcessID -ErrorAction Ignore
if ($ControllerProcess -eq $null) {return}

$ControllerProcess.Handle >$null

if ($False -and $IsWindows -and (Test-IsElevated)) {
    #kill off all running GetCPU.exe
    try {
        Get-Process -Name "GetCPU" -ErrorAction Ignore | Foreach-Object {
            if (Send-CtrlC $_.Id) {
                $StopWatch = [System.Diagnostics.Stopwatch]::New()
                $StopWatch.Start()
                while (-not $_.HasExited -and $StopWatch.Elapsed.TotalSeconds -le 10) {
                    Start-Sleep -Milliseconds 500
                }
            }

            if (-not $_.HasExited) {
                $_.Kill()
            }
        }
    } catch {}

    #start a new instance of GetCPU.exe
    $GetCPU_FilePath = [IO.Path]::GetFullPath(".\Includes\getcpu\GetCPU.exe")
    $GetCPU_Process = Start-SubProcess -FilePath $GetCPU_FilePath -ArgumentList "--repeat=10000" -WorkingDirectory (Split-Path $GetCPU_FilePath)
}

$count = 0

do {

    $end = $ControllerProcess.WaitForExit(500)
    if (-not $end -and $count -le 0) {
        try {
            $GetCPU_Running = $IsWindows -and (Get-Process -Name "GetCPU" -ErrorAction Ignore)
            if ($SysInfo = Get-SysInfo -PhysicalCPUs $PhysicalCPUs -FromRegistry $GetCPU_Running) {
                Set-ContentJson -PathToFile ".\Data\sysinfo.json" -Data $SysInfo -Quiet > $null
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }
        $count = 60
    }
    $count--

} until ($end)

if ($GetCPU_Process) {
    Stop-SubProcess -Job $GetCPU_Process
}
