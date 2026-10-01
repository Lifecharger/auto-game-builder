# Registers the Windows scheduled task "Lifecharger Weekly Report" (Mondays 09:07 local time).
#
#   Run from an ELEVATED PowerShell for the full setup (runs whether or not anyone is logged on,
#   S4U = no stored password):   powershell -ExecutionPolicy Bypass -File install_weekly_task.ps1
#   Without elevation it falls back to "run only when the user is logged on".
#
# pythonw is resolved from PATH at run time (cmd "start"), so no console window appears. Missed runs
# (PC off at 09:07) start at the next boot/logon; the task never wakes the PC. The script writes its
# own log (weekly_report.log) next to the reports in weekly_report.output_dir.
param([string]$TaskName = 'Lifecharger Weekly Report')
$script = Join-Path $PSScriptRoot 'weekly_report.py'
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c start `"`" pythonw `"$script`"" -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At '09:07'
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
$user = "$env:USERDOMAIN\$env:USERNAME"
$desc = 'Weekly performance + health report (AGB tools/reports/weekly_report.py). Mondays 09:07; catches up at next start if missed.'
try {
    $p = New-ScheduledTaskPrincipal -UserId $user -LogonType S4U -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $p `
        -Description $desc -Force -ErrorAction Stop | Out-Null
    Write-Output "registered '$TaskName' (runs whether or not the user is logged on)"
} catch {
    $p = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $p `
        -Description $desc -Force -ErrorAction Stop | Out-Null
    Write-Output "registered '$TaskName' ONLY WHEN LOGGED ON (S4U needs an elevated shell: $($_.Exception.Message))"
}
