# --- КОНФИГУРАЦИЯ ПОЧТЫ (ЗАПОЛНИТЕ ПРИ НЕОБХОДИМОСТИ) ---
$emailEnabled = $false  # Измените на $true, когда заполните данные ниже
$smtpServer = "smtp.gmail.com"
$smtpPort = 587
$fromEmail = "your-wedding-email@gmail.com"
$toEmail = "your-personal-email@gmail.com"
$smtpPassword = "your-app-password" # Это должен быть "Пароль приложения", а не основной пароль от почты

# --- ОСНОВНАЯ КОНФИГУРАЦИЯ СЕРВЕРА ---
$port = 8000
$root = "d:\planning-wedding"
$submissionsFile = Join-Path $root "submissions.txt"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

Write-Host "Server started at http://localhost:$port/"
Write-Host "Submissions will be saved to: $submissionsFile"
Write-Host "Press Ctrl+C to stop"

function Send-SubmissionEmail($dataJson) {
    if (-not $emailEnabled) { return }
    
    try {
        $data = $dataJson | ConvertFrom-Json
        $subject = "Новая заявка на свадьбу от: $($data.name)"
        $body = "Получена новая заявка!`n`nИмя: $($data.name)`nEmail: $($data.email)`nСообщение: $($data.message)"
        
        $secPassword = ConvertTo-SecureString $smtpPassword -AsPlainText -Force
        $creds = New-Object System.Management.Automation.PSCredential($fromEmail, $secPassword)
        
        Send-MailMessage -To $toEmail -From $fromEmail -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -UseSsl -Credential $creds
        Write-Host "Email sent successfully to $toEmail"
    } catch {
        Write-Host "Ошибка при отправке почты: $_" -ForegroundColor Red
    }
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        if ($request.HttpMethod -eq "POST" -and $request.Url.LocalPath -eq "/submit-form") {
            # Handle Form Submission
            $reader = New-Object System.IO.StreamReader($request.InputStream)
            $body = $reader.ReadToEnd()
            
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $entry = "`n--- Submission at $timestamp ---`n$body`n"
            Add-Content -Path $submissionsFile -Value $entry
            
            Write-Host "New form submission received and saved to submissions.txt"
            
            # Попытка отправить email
            Send-SubmissionEmail $body
            
            $response.ContentType = "application/json"
            $message = [System.Text.Encoding]::UTF8.GetBytes('{"status": "success", "message": "Сообщение получено!"}')
            $response.ContentLength64 = $message.Length
            $response.OutputStream.Write($message, 0, $message.Length)
        } else {
            # Handle Static Files
            $path = $request.Url.LocalPath
            if ($path -eq "/") { $path = "/index.html" }
            $filePath = Join-Path $root $path

            if (Test-Path $filePath) {
                $content = [System.IO.File]::ReadAllBytes($filePath)
                $extension = [System.IO.Path]::GetExtension($filePath).ToLower()
                
                $contentType = switch ($extension) {
                    ".html" { "text/html; charset=utf-8" }
                    ".css"  { "text/css" }
                    ".js"   { "application/javascript" }
                    ".json" { "application/json" }
                    default { "application/octet-stream" }
                }
                
                $response.ContentType = $contentType
                $response.ContentLength64 = $content.Length
                $response.OutputStream.Write($content, 0, $content.Length)
            } else {
                $response.StatusCode = 404
                $message = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
                $response.OutputStream.Write($message, 0, $message.Length)
            }
        }
        $response.Close()
    }
} finally {
    $listener.Stop()
}
