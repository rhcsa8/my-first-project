Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Путь к файлу сохранения
$saveFilePath = "$env:APPDATA\PingUtility\hostss.csv"

# Функция загрузки сохраненных узлов
function Load-SavedHosts {
    if (Test-Path $saveFilePath) {
        try {
            $content = Import-Csv $saveFilePath -ErrorAction Stop
            return $content
        }
        catch {
            return @()
        }
    }
    return @()
}

# Функция сохранения узлов
function Save-Hosts {
    $hostsDir = Split-Path $saveFilePath -Parent
    if (!(Test-Path $hostsDir)) {
        New-Item -ItemType Directory -Path $hostsDir -Force
    }
    
    $hostList = @()
    foreach ($item in $listViewHosts.Items) {
        $hostList += [PSCustomObject]@{
            Alias = $item.SubItems[0].Text
            Host = $item.SubItems[1].Text
        }
    }
    
    try {
        $hostList | Export-Csv $saveFilePath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Error "Ошибка сохранения файла: $($_.Exception.Message)"
    }
}

# Функция для создания формы длительного пинга
function Show-LongPingForm {
    param($hostName, $aliasName)
    
    $displayName = if ($aliasName) { "$aliasName ($hostName)" } else { $hostName }
    
    $longPingForm = New-Object System.Windows.Forms.Form
    $longPingForm.Text = "Длительный Ping: $displayName"
    $longPingForm.Size = New-Object System.Drawing.Size(650, 500)
    $longPingForm.StartPosition = "CenterScreen"
    $longPingForm.FormBorderStyle = "FixedDialog"
    $longPingForm.MaximizeBox = $false
    
    # Текстовое поле для вывода
    $textBoxOutput = New-Object System.Windows.Forms.TextBox
    $textBoxOutput.Location = New-Object System.Drawing.Point(10, 10)
    $textBoxOutput.Size = New-Object System.Drawing.Size(615, 350)
    $textBoxOutput.Multiline = $true
    $textBoxOutput.ScrollBars = "Vertical"
    $textBoxOutput.ReadOnly = $true
    $longPingForm.Controls.Add($textBoxOutput)
    
    # Кнопка остановки/запуска
    $buttonToggle = New-Object System.Windows.Forms.Button
    $buttonToggle.Location = New-Object System.Drawing.Point(10, 370)
    $buttonToggle.Size = New-Object System.Drawing.Size(100, 30)
    $buttonToggle.Text = "Остановить"
    $longPingForm.Controls.Add($buttonToggle)
    
    # Кнопка очистки
    $buttonClear = New-Object System.Windows.Forms.Button
    $buttonClear.Location = New-Object System.Drawing.Point(120, 370)
    $buttonClear.Size = New-Object System.Drawing.Size(100, 30)
    $buttonClear.Text = "Очистить"
    $longPingForm.Controls.Add($buttonClear)
    
    # Кнопка копирования
    $buttonCopy = New-Object System.Windows.Forms.Button
    $buttonCopy.Location = New-Object System.Drawing.Point(230, 370)
    $buttonCopy.Size = New-Object System.Drawing.Size(100, 30)
    $buttonCopy.Text = "Копировать"
    $longPingForm.Controls.Add($buttonCopy)
    
    # Кнопка показа статистики
    $buttonStats = New-Object System.Windows.Forms.Button
    $buttonStats.Location = New-Object System.Drawing.Point(340, 370)
    $buttonStats.Size = New-Object System.Drawing.Size(120, 30)
    $buttonStats.Text = "Показать статистику"
    $buttonStats.Enabled = $false
    $longPingForm.Controls.Add($buttonStats)
    
    # Статус бар
    $statusBar = New-Object System.Windows.Forms.StatusBar
    $statusBar.Text = "Запуск длительного пинга..."
    $longPingForm.Controls.Add($statusBar)
    
    # Переменные для статистики
    $script:packetsSent = 0
    $script:packetsReceived = 0
    $script:packetsLost = 0
    $script:minTime = [double]::MaxValue
    $script:maxTime = [double]::MinValue
    $script:avgTime = 0
    $script:totalTime = 0
    
    # Переменные для управления процессом
    $script:isRunning = $true
    $script:pingTimer = $null
    $script:startTime = Get-Date
    
    # Создаем обработчик события для таймера
    $timerHandler = {
        try {
            $result = Test-Connection -ComputerName $hostName -Count 1 -ErrorAction Stop
            $script:packetsSent++
            $script:packetsReceived++
            
            $responseTime = $result.ResponseTime
            $script:totalTime += $responseTime
            $script:avgTime = $script:totalTime / $script:packetsReceived
            
            if ($responseTime -lt $script:minTime) { $script:minTime = $responseTime }
            if ($responseTime -gt $script:maxTime) { $script:maxTime = $responseTime }
            
            $outputText = "[$(Get-Date -Format 'HH:mm:ss')] Ответ от $hostName: время=${responseTime}ms TTL=$($result.ResponseTimeToLive)"
            $longPingForm.Invoke([action]{
                $textBoxOutput.AppendText($outputText + [Environment]::NewLine)
                $textBoxOutput.SelectionStart = $textBoxOutput2.Length
                $textBoxOutput.ScrollToCaret()
                $statusBar.Text = "Отправлено: $script:packetsSent, Получено: $script:packetsReceived, Потеряно: $script:packetsLost"
            })
        }
        catch {
            $script:packetsSent++
            $script:packetsLost++
            
            $outputText = "[$(Get-Date -Format 'HH:mm:ss')] Нет ответа от $hostName"
            $longPingForm.Invoke([action]{
                $textBoxOutput.AppendText($outputText + [Environment]::NewLine)
                $textBoxOutput.SelectionStart = $textBoxOutput.Text.Length
                $textBoxOutput.ScrollToCaret()
                $statusBar.Text = "Отправлено: $script:packetsSent, Получено: $script:packetsReceived, Потеряно: $script:packetsLost"
            })
        }
    }
    
    # Функция показа статистики
    function Show-Statistics {
        $endTime = Get-Date
        $duration = $endTime - $script:startTime
        
        $statsForm = New-Object System.Windows.Forms.Form
        $statsForm.Text = "Статистика пинга: $displayName"
        $statsForm.Size = New-Object System.Drawing.Size(400, 300)
        $statsForm.StartPosition = "CenterScreen"
        
        $textBoxStats = New-Object System.Windows.Forms.TextBox
        $textBoxStats.Location = New-Object System.Drawing.Point(10, 10)
        $textBoxStats.Size = New-Object System.Drawing.Size(365, 240)
        $textBoxStats.Multiline = $true
        $textBoxStats.ReadOnly = $true
        $textBoxStats.ScrollBars = "Vertical"
        
        $lossPercentage = if ($script:packetsSent -gt 0) { ($script:packetsLost / $script:packetsSent) * 100 } else { 0 }
        
        $statsText = @"
Статистика Ping для $displayName
Пакетов: отправлено = $script:packetsSent, получено = $script:packetsReceived, потеряно = $script:packetsLost
($([math]::Round($lossPercentage, 2))% потерь)

Приблизительное время приема-передачи в мс:
    Минимальное = $(if ($script:minTime -eq [double]::MaxValue) { "0" } else { [math]::Round($script:minTime) })ms,
    Максимальное = $(if ($script:maxTime -eq [double]::MinValue) { "0" } else { [math]::Round($script:maxTime) })ms,
    Среднее = $([math]::Round($script:avgTime))ms

Длительность теста: $("{0:hh}:{0:mm}:{0:ss}" -f $duration)
"@
        
        $textBoxStats.Text = $statsText
        $statsForm.Controls.Add($textBoxStats)
        
        $buttonClose = New-Object System.Windows.Forms.Button
        $buttonClose.Location = New-Object System.Drawing.Point(150, 260)
        $buttonClose.Size = New-Object System.Drawing.Size(75, 23)
        $buttonClose.Text = "Закрыть"
        $buttonClose.DialogResult = "OK"
        $statsForm.Controls.Add($buttonClose)
        
        $statsForm.ShowDialog()
    }
    
    # Функция остановки пинга
    function Stop-LongPing {
        if ($script:pingTimer -ne $null) {
            $script:pingTimer.Stop()
            $script:pingTimer.Dispose()
            $script:pingTimer = $null
        }
        $script:isRunning = $false
        $buttonToggle.Text = "Запустить"
        $buttonStats.Enabled = $true
        $statusBar.Text = "Пинг остановлен. Отправлено: $script:packetsSent, Получено: $script:packetsReceived, Потеряно: $script:packetsLost"
    }
    
    # Функция запуска пинга
    function Start-LongPing {
        $script:isRunning = $true
        $buttonToggle.Text = "Остановить"
        $buttonStats.Enabled = $false
        $statusBar.Text = "Выполняется ping $hostName..."
        
        # Создаем и запускаем таймер для периодического пинга
        $script:pingTimer = New-Object System.Windows.Forms.Timer
        $script:pingTimer.Interval = 1000  # 1 секунда
        $script:pingTimer.Add_Tick($timerHandler)
        $script:pingTimer.Start()
    }
    
    # Обработчик кнопки переключения
    $buttonToggle.Add_Click({
        if ($script:isRunning) {
            Stop-LongPing
        }
        else {
            Start-LongPing
        }
    })
    
    $buttonClear.Add_Click({
        $textBoxOutput.Text = ""
        $statusBar.Text = "Очищено"
    })
    
    $buttonCopy.Add_Click({
        if ($textBoxOutput.Text.Length -gt 0) {
            try {
                $textBoxOutput.SelectAll()
                $textBoxOutput.Copy()
                $textBoxOutput.SelectionStart = 0
                $textBoxOutput.SelectionLength = 0
                $statusBar.Text = "Текст скопирован в буфер обмена"
            }
            catch {
                try {
                    [System.Windows.Forms.Clipboard]::SetText($textBoxOutput.Text)
                    $statusBar.Text = "Текст скопирован в буфер обмена"
                }
                catch {
                    $statusBar.Text = "Ошибка копирования: $($_.Exception.Message)"
                }
            }
        }
    })
    
    $buttonStats.Add_Click({
        Show-Statistics
    })
    
    # Обработчик закрытия формы
    $longPingForm.Add_FormClosing({
        if ($script:pingTimer -ne $null) {
            $script:pingTimer.Stop()
            $script:pingTimer.Dispose()
        }
    })
    
    # Запускаем пинг при открытии формы
    Start-LongPing
    
    # Показать форму
    $longPingForm.ShowDialog()
}

# Создание главной формы
$form = New-Object System.Windows.Forms.Form
$form.Text = "Ping Utility"
$form.Size = New-Object System.Drawing.Size(900, 550)
$form.StartPosition = "CenterScreen"
$form.Add_FormClosing({ Save-Hosts })

# Список узлов с алиасами
$labelHosts = New-Object System.Windows.Forms.Label
$labelHosts.Location = New-Object System.Drawing.Point(10, 10)
$labelHosts.Size = New-Object System.Drawing.Size(300, 20)
$labelHosts.Text = "Список узлов для проверки:"
$form.Controls.Add($labelHosts)

# Заменим ListBox на ListView для отображения нескольких колонок
$listViewHosts = New-Object System.Windows.Forms.ListView
$listViewHosts.Location = New-Object System.Drawing.Point(10, 30)
$listViewHosts.Size = New-Object System.Drawing.Size(300, 200)
$listViewHosts.View = "Details"
$listViewHosts.FullRowSelect = $true
$listViewHosts.MultiSelect = $true
$listViewHosts.GridLines = $true

# Добавляем колонки
$listViewHosts.Columns.Add("Алиас", 120)
$listViewHosts.Columns.Add("Узел", 150)

$form.Controls.Add($listViewHosts)

# Загрузка сохраненных узлов
$savedHosts = Load-SavedHosts
if ($savedHosts.Count -gt 0) {
    foreach ($node in $savedHosts) {
        $item = New-Object System.Windows.Forms.ListViewItem($node.Alias)
        $item.SubItems.Add($node.Host)
        $listViewHosts.Items.Add($item)
    }
}
else {
    # Добавление начальных узлов если нет сохраненных
    $initialNodes = @(
        @{Alias = "Google DNS"; Host = "8.8.8.8"},
        @{Alias = "Cloudflare DNS"; Host = "1.1.1.1"},
        @{Alias = "Google"; Host = "google.com"},
        @{Alias = "Microsoft"; Host = "microsoft.com"},
        @{Alias = "Яндекс"; Host = "ya.ru"}
    )
    
    foreach ($node in $initialNodes) {
        $item = New-Object System.Windows.Forms.ListViewItem($node.Alias)
        $item.SubItems.Add($node.Host)
        $listViewHosts.Items.Add($item)
    }
}

# Поля для ввода нового узла
$labelAlias = New-Object System.Windows.Forms.Label
$labelAlias.Location = New-Object System.Drawing.Point(10, 240)
$labelAlias.Size = New-Object System.Drawing.Size(140, 20)
$labelAlias.Text = "Алиас (необязательно):"
$form.Controls.Add($labelAlias)

$textBoxAlias = New-Object System.Windows.Forms.TextBox
$textBoxAlias.Location = New-Object System.Drawing.Point(10, 260)
$textBoxAlias.Size = New-Object System.Drawing.Size(140, 20)
$form.Controls.Add($textBoxAlias)

$labelHost = New-Object System.Windows.Forms.Label
$labelHost.Location = New-Object System.Drawing.Point(160, 240)
$labelHost.Size = New-Object System.Drawing.Size(100, 20)
$labelHost.Text = "Узел:"
$form.Controls.Add($labelHost)

$textBoxHost = New-Object System.Windows.Forms.TextBox
$textBoxHost.Location = New-Object System.Drawing.Point(160, 260)
$textBoxHost.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($textBoxHost)

# Кнопка добавления узла
$buttonAddHost = New-Object System.Windows.Forms.Button
$buttonAddHost.Location = New-Object System.Drawing.Point(270, 260)
$buttonAddHost.Size = New-Object System.Drawing.Size(40, 23)
$buttonAddHost.Text = "Добавить"
$form.Controls.Add($buttonAddHost)

# Кнопка удаления узла
$buttonRemoveHost = New-Object System.Windows.Forms.Button
$buttonRemoveHost.Location = New-Object System.Drawing.Point(10, 290)
$buttonRemoveHost.Size = New-Object System.Drawing.Size(90, 23)
$buttonRemoveHost.Text = "Удалить"
$form.Controls.Add($buttonRemoveHost)

# Кнопка редактирования узла
$buttonEditHost = New-Object System.Windows.Forms.Button
$buttonEditHost.Location = New-Object System.Drawing.Point(110, 290)
$buttonEditHost.Size = New-Object System.Drawing.Size(90, 23)
$buttonEditHost.Text = "Редактировать"
$form.Controls.Add($buttonEditHost)

# Кнопка запуска пинга
$buttonPing = New-Object System.Windows.Forms.Button
$buttonPing.Location = New-Object System.Drawing.Point(10, 320)
$buttonPing.Size = New-Object System.Drawing.Size(100, 30)
$buttonPing.Text = "Start Ping"
$form.Controls.Add($buttonPing)

# Кнопка очистки результатов
$buttonClear = New-Object System.Windows.Forms.Button
$buttonClear.Location = New-Object System.Drawing.Point(120, 320)
$buttonClear.Size = New-Object System.Drawing.Size(100, 30)
$buttonClear.Text = "Clear Results"
$form.Controls.Add($buttonClear)

# Кнопка сохранения списка
$buttonSave = New-Object System.Windows.Forms.Button
$buttonSave.Location = New-Object System.Drawing.Point(230, 320)
$buttonSave.Size = New-Object System.Drawing.Size(100, 30)
$buttonSave.Text = "Save List"
$form.Controls.Add($buttonSave)

# Кнопка длительного пинга
$buttonLongPing = New-Object System.Windows.Forms.Button
$buttonLongPing.Location = New-Object System.Drawing.Point(340, 320)
$buttonLongPing.Size = New-Object System.Drawing.Size(100, 30)
$buttonLongPing.Text = "Long Ping"
$form.Controls.Add($buttonLongPing)

# Таблица для результатов
$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Location = New-Object System.Drawing.Point(370, 30)
$dataGridView.Size = New-Object System.Drawing.Size(600, 550)
$dataGridView.AutoSizeColumnsMode = "Fill"
$dataGridView.SelectionMode = "FullRowSelect"
$dataGridView.ReadOnly = $true
$dataGridView.AllowUserToAddRows = $false
$dataGridView.RowHeadersVisible = $false

# Настройка столбцов таблицы
$dataGridView.Columns.Add("Alias", "Алиас")
$dataGridView.Columns.Add("Host", "Узел")
$dataGridView.Columns.Add("Status", "Статус")
$dataGridView.Columns.Add("ResponseTime", "Время ответа (ms)")
$dataGridView.Columns.Add("Timestamp", "Время проверки")

# Настройка ширины столбцов
$dataGridView.Columns["Alias"].Width = 100
$dataGridView.Columns["Host"].Width = 120
$dataGridView.Columns["Status"].Width = 80
$dataGridView.Columns["ResponseTime"].Width = 80
$dataGridView.Columns["Timestamp"].Width = 120

$form.Controls.Add($dataGridView)

# Статус бар
$statusBar = New-Object System.Windows.Forms.StatusBar
$statusBar.Text = "Готов к работе. Узлов: $($listViewHosts.Items.Count)"
$form.Controls.Add($statusBar)

# Функция добавления узла
function Add-Node {
    $alias = $textBoxAlias.Text.Trim()
    $hostValue = $textBoxHost.Text.Trim()
    
    if (-not $hostValue) {
        $statusBar.Text = "Введите имя узла"
        return
    }
    
    # Проверяем, существует ли уже такой узел
    $exists = $false
    foreach ($item in $listView2Hosts.Items) {
        if ($item.SubItems[1].Text -eq $hostValue) {
            $exists = $true
            break
        }
    }
    
    if ($exists) {
        $statusBar.Text = "Узел уже существует в списке"
        return
    }
    
    # Добавляем новый узел
    $item = New-Object System.Windows.Forms.ListViewItem($alias)
    $item.SubItems.Add($hostValue)
    $listViewHosts.Items.Add($item)
    
    $textBoxAlias.Text = ""
    $textBoxHost.Text = ""
    $statusBar.Text = "Узел добавлен. Всего: $($listViewHosts.Items.Count)"
    Save-Hosts
}

# Функция удаления узла
function Remove-Node {
    if ($listViewHosts.SelectedItems.Count -gt 0) {
        $removedCount = 0
        foreach ($selectedItem in $listViewHosts.SelectedItems) {
            $listViewHosts.Items.Remove($selectedItem)
            $removedCount++
        }
        $statusBar.Text = "Удалено узлов: $removedCount. Всего: $($listViewHosts.Items.Count)"
        Save-Hosts
    }
    else {
        $statusBar.Text = "Выберите узел для удаления"
    }
}

# Функция редактирования узла
function Edit-Node {
    if ($listViewHosts.SelectedItems.Count -eq 1) {
        $selectedItem = $listViewHosts.SelectedItems[0]
        
        $editForm = New-Object System.Windows.Forms.Form
        $editForm.Text = "Редактировать узел"
        $editForm.Size = New-Object System.Drawing.Size(350, 150)
        $editForm.StartPosition = "CenterScreen"
        
        $labelAlias = New-Object System.Windows.Forms.Label
        $labelAlias.Location = New-Object System.Drawing.Point(10, 10)
        $labelAlias.Size = New-Object System.Drawing.Size(150, 20)
        $labelAlias.Text = "Алиас:"
        $editForm.Controls.Add($labelAlias)
        
        $textBoxEditAlias = New-Object System.Windows.Forms.TextBox
        $textBoxEditAlias.Location = New-Object System.Drawing.Point(10, 30)
        $textBoxEditAlias.Size = New-Object System.Drawing.Size(300, 20)
        $textBoxEditAlias.Text = $selectedItem.SubItems[0].Text
        $editForm.Controls.Add($textBoxEditAlias)
        
        $labelHost = New-Object System.Windows.Forms.Label
        $labelHost.Location = New-Object System.Drawing.Point(10, 60)
        $labelHost.Size = New-Object System.Drawing.Size(150, 20)
        $labelHost.Text = "Узел:"
        $editForm.Controls.Add($labelHost)
        
        $textBoxEditHost = New-Object System.Windows.Forms.TextBox
        $textBoxEditHost.Location = New-Object System.Drawing.Point(10, 80)
        $textBoxEditHost.Size = New-Object System.Drawing.Size(300, 20)
        $textBoxEditHost.Text = $selectedItem.SubItems[1].Text
        $editForm.Controls.Add($textBoxEditHost)
        
        $buttonSave = New-Object System.Windows.Forms.Button
        $buttonSave.Location = New-Object System.Drawing.Point(120, 110)
        $buttonSave.Size = New-Object System.Drawing.Size(75, 23)
        $buttonSave.Text = "Сохранить"
        $buttonSave.DialogResult = "OK"
        $editForm.Controls.Add($buttonSave)
        
        $editForm.AcceptButton = $buttonSave
        
        if ($editForm.ShowDialog() -eq "OK") {
            $selectedItem.SubItems[0].Text = $textBoxEditAlias.Text.Trim()
            $selectedItem.SubItems[1].Text = $textBoxEditHost.Text.Trim()
            $statusBar.Text = "Узел обновлен"
            Save-Hosts
        }
    }
    else {
        $statusBar.Text = "Выберите один узел для редактирования"
    }
}

# Функция пинга
function Ping-Nodes {
    if ($listViewHosts.Items.Count -eq 0) {
        $statusBar.Text = "Нет узлов для проверки"
        return
    }
    
    $dataGridView.Rows.Clear()
    $statusBar.Text = "Выполняется ping..."
    $form.Refresh()
    
    foreach ($item in $listViewHosts.Items) {
        $alias = $item.SubItems[0].Text
        $hostValue = $item.SubItems[1].Text
        
        if ($hostValue) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            try {
                $result = Test-Connection -ComputerName $hostValue -Count 2 -ErrorAction Stop
                $status = "Доступен"
                $responseTime = ($result | Measure-Object ResponseTime -Average).Average
                
                # Добавляем строку в таблицу
                $row = $dataGridView.Rows.Add($alias, $hostValue, $status, [math]::Round($responseTime), $timestamp)
                
                # Устанавливаем цвет фона для доступных узлов (зеленый)
                $dataGridView.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGreen
            }
            catch {
                $status = "Не доступен"
                $responseTime = "N/A"
                
                # Добавляем строку в таблицу
                $row = $dataGridView.Rows.Add($alias, $hostValue, $status, $responseTime, $timestamp)
                
                # Устанавливаем цвет фона для недоступных узлов (красный)
                $dataGridView.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightCoral
                
                # Устанавливаем цвет текста для лучшей читаемости
                $dataGridView.Rows[$row].DefaultCellStyle.ForeColor = [System.Drawing.Color]::DarkRed
            }
        }
    }
    
    $statusBar.Text = "Завершено. Проверено узлов: $($listViewHosts.Items.Count)"
}

# Функция очистки результатов
function Clear-Results {
    $dataGridView.Rows.Clear()
    $statusBar.Text = "Результаты очищены. Узлов: $($listViewHosts.Items.Count)"
}

# Функция ручного сохранения
function Manual-Save {
    Save-Hosts
    $statusBar.Text = "Список сохранен. Узлов: $($listViewHosts.Items.Count)"
}

# Функция запуска длительного пинга
function Start-LongPing {
    if ($dataGridView.SelectedRows.Count -eq 0) {
        $statusBar.Text = "Выберите узел из таблицы результатов"
        return
    }
    
    $selectedAlias = $dataGridView.SelectedRows[0].Cells["Alias"].Value
    $selectedHost = $dataGridView.SelectedRows[0].Cells["Host"].Value
    
    if ($selectedHost) {
        Show-LongPingForm -hostName $selectedHost -aliasName $selectedAlias
    }
}

# Обработчики кнопок
$buttonAddHost.Add_Click({ Add-Node })
$buttonRemoveHost.Add_Click({ Remove-Node })
$buttonEditHost.Add_Click({ Edit-Node })
$buttonPing.Add_Click({ Ping-Nodes })
$buttonClear.Add_Click({ Clear-Results })
$buttonSave.Add_Click({ Manual-Save })
$buttonLongPing.Add_Click({ Start-LongPing })

# Обработчик нажатия Enter в текстовом поле
$textBoxHost.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        Add-Node
        $_.SuppressKeyPress = $true
    }
})

# Обработчик изменения списка для обновления статуса
$listViewHosts.Add_SelectedIndexChanged({
    $statusBar.Text = "Выбрано: $($listViewHosts.SelectedItems.Count). Всего: $($listViewHosts.Items.Count)"
})

# Обработчик двойного клика по таблице
$dataGridView.Add_CellDoubleClick({
    Start-LongPing
})

# Обработчик двойного клика по списку узлов
$listViewHosts.Add_DoubleClick({
    Edit-Node
})

# Показать форму
$form.ShowDialog()
