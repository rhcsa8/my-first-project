# Скрипт для проверки состояния служб на серверах
# ServiceStatusReport.ps1

# Настройки
$servers = "127.0.0.1"
#, "Server2", "Server3" # Список серверов для проверки
$services = @{
"127.0.0.1" = "MSSQLSERVER", "SQLServerAgent", "W3SVC", "BITS"
#"Server2" = "MSSQLSERVER", "SQLServerAgent", "W3SVC", "BITS"
#"Server3" = "W3SVC", "BITS", "WinRM"
}
$reportPath = "C:\Reports\ServiceStatus_$(Get-Date -Format 'yyyyMMdd').html" # Путь к файлу отчета
$sendEmail = $true # Отправлять ли email-отчет
$emailParams = @{
From = "monitoring@yourdomain.com"
To = "admin@yourdomain.com"
Subject = "Отчет о состоянии служб на серверах - $(Get-Date -Format 'yyyy-MM-dd')"
SmtpServer = "smtp.yourdomain.com"
}

# Создаем директорию для отчетов, если она не существует
if (!(Test-Path (Split-Path $reportPath -Parent))) {
New-Item -ItemType Directory -Path (Split-Path $reportPath -Parent) -Force | Out-Null
}

# Создаем HTML-заголовок отчета
$htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
<title>Отчет о состоянии служб на серверах</title>
<style>
body { font-family: Arial, sans-serif; margin: 20px; }
h1 { color: #0066cc; }
table { border-collapse: collapse; width: 100%; margin-top: 20px; }
th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
th { background-color: #f2f2f2; }
tr:nth-child(even) { background-color: #f9f9f9; }
.running { color: green; font-weight: bold; }
.stopped { color: red; font-weight: bold; }
.other { color: orange; font-weight: bold; }
.summary { margin-top: 20px; font-weight: bold; }
</style>
</head>
<body>
<h1>Отчет о состоянии служб на серверах</h1>
<p>Дата создания: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
"@

# Создаем HTML-содержимое отчета
$htmlBody = ""
$totalServices = 0
$runningServices = 0
$stoppedServices = 0
$otherServices = 0

foreach ($server in $servers) {
$htmlBody += "<h2>Сервер: $server</h2>"
$htmlBody += "<table><tr><th>Служба</th><th>Отображаемое имя</th><th>Состояние</th><th>Тип запуска</th></tr>"

try {
foreach ($service in $services[$server]) {
$totalServices++
$svc = Get-Service -ComputerName $server -Name $service -ErrorAction SilentlyContinue

if ($svc) {
$startupType = (Get-WmiObject -ComputerName $server -Class Win32_Service -Filter "Name='$service'").StartMode

$statusClass = "other"
if ($svc.Status -eq "Running") {
$statusClass = "running"
$runningServices++
}
elseif ($svc.Status -eq "Stopped") {
$statusClass = "stopped"
$stoppedServices++
}
else {
$otherServices++
}

$htmlBody += "<tr><td>$($svc.Name)</td><td>$($svc.DisplayName)</td><td class='$statusClass'>$($svc.Status)</td><td>$startupType</td></tr>"
}
else {
$htmlBody += "<tr><td>$service</td><td>Не найдена</td><td class='stopped'>Ошибка</td><td>Неизвестно</td></tr>"
$stoppedServices++
}
}
}
catch {
$htmlBody += "<tr><td colspan='4'>Ошибка при подключении к серверу: $_</td></tr>"
}

$htmlBody += "</table>"
}

# Добавляем сводную информацию
$htmlSummary = @"
<div class="summary">
<p>Всего проверено служб: $totalServices</p>
<p>Запущено: <span class="running">$runningServices</span></p>
<p>Остановлено: <span class="stopped">$stoppedServices</span></p>
<p>В другом состоянии: <span class="other">$otherServices</span></p>
</div>
"@

# Создаем HTML-футер отчета
$htmlFooter = @"
</body>
</html>
"@

# Собираем полный HTML-отчет
$htmlReport = $htmlHeader + $htmlBody + $htmlSummary + $htmlFooter

# Сохраняем отчет в файл
$htmlReport | Out-File -FilePath $reportPath -Encoding UTF8

# Отправляем email с отчетом
if ($sendEmail) {
try {
Send-MailMessage @emailParams -Body "Отчет о состоянии служб на серверах во вложении." -Attachments $reportPath -BodyAsHtml
Write-Host "Email с отчетом отправлен"
}
catch {
Write-Host "ОШИБКА: Не удалось отправить email с отчетом. Ошибка: $_"
}
}

Write-Host "Отчет создан: $reportPath"