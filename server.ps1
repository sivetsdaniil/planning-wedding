# --- ОСНОВНАЯ КОНФИГУРАЦИЯ СЕРВЕРА ---
$port = 8000
$root = "d:\planning-wedding"
$commentsFile = Join-Path $root "comments.json"
$adminPassword = "admin" # Пароль для админ-панели

if (-not (Test-Path $commentsFile)) {
    "[]" | Out-File -FilePath $commentsFile -Encoding UTF8
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

Write-Host "Server started at http://localhost:$port/"
Write-Host "Press Ctrl+C to stop"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        try {
            if ($request.HttpMethod -eq "GET" -and $request.Url.LocalPath -eq "/get-comments") {
                $content = Get-Content -Path $commentsFile -Raw -Encoding UTF8
                if ([string]::IsNullOrWhiteSpace($content)) { $content = "[]" }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
                $response.ContentType = "application/json; charset=utf-8"
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } 
            elseif ($request.HttpMethod -eq "POST" -and $request.Url.LocalPath -eq "/add-comment") {
                $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
                $body = $reader.ReadToEnd()
                $newComment = $body | ConvertFrom-Json
                
                $newComment | Add-Member -MemberType NoteProperty -Name "id" -Value ([guid]::NewGuid().ToString())
                $newComment | Add-Member -MemberType NoteProperty -Name "date" -Value (Get-Date -Format "dd.MM.yyyy HH:mm")
                $newComment | Add-Member -MemberType NoteProperty -Name "approved" -Value $false # По умолчанию требует одобрения

                $commentsContent = Get-Content -Path $commentsFile -Raw -Encoding UTF8
                $comments = if ([string]::IsNullOrWhiteSpace($commentsContent)) { @() } else { $commentsContent | ConvertFrom-Json }
                if ($null -eq $comments) { $comments = @() }
                if ($comments -isnot [Array]) { $comments = @($comments) }
                
                $comments += $newComment
                $json = @($comments) | ConvertTo-Json -Depth 10
                $json | Out-File -FilePath $commentsFile -Encoding UTF8
                
                $response.ContentType = "application/json"
                $message = [System.Text.Encoding]::UTF8.GetBytes('{"status": "success"}')
                $response.ContentLength64 = $message.Length
                $response.OutputStream.Write($message, 0, $message.Length)
            }
            elseif ($request.HttpMethod -eq "POST" -and $request.Url.LocalPath -eq "/admin-action") {
                $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
                $body = $reader.ReadToEnd()
                $data = $body | ConvertFrom-Json
                
                if ($data.password -ne $adminPassword) {
                    $response.StatusCode = 403
                    $message = [System.Text.Encoding]::UTF8.GetBytes('{"status": "error", "message": "Wrong password"}')
                    $response.ContentLength64 = $message.Length
                    $response.OutputStream.Write($message, 0, $message.Length)
                } else {
                    $commentsContent = Get-Content -Path $commentsFile -Raw -Encoding UTF8
                    $comments = if ([string]::IsNullOrWhiteSpace($commentsContent)) { @() } else { $commentsContent | ConvertFrom-Json }
                    if ($null -eq $comments) { $comments = @() }
                    if ($comments -isnot [Array]) { $comments = @($comments) }

                    if ($data.action -eq "approve") {
                        foreach ($c in $comments) { if ($c.id -eq $data.id) { $c.approved = $true } }
                    } elseif ($data.action -eq "delete") {
                        $comments = $comments | Where-Object { $_.id -ne $data.id }
                    }

                    $json = @($comments) | ConvertTo-Json -Depth 10
                    $json | Out-File -FilePath $commentsFile -Encoding UTF8
                    
                    $response.ContentType = "application/json"
                    $message = [System.Text.Encoding]::UTF8.GetBytes('{"status": "success"}')
                    $response.ContentLength64 = $message.Length
                    $response.OutputStream.Write($message, 0, $message.Length)
                }
            }
            else {
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
                    $response.ContentLength64 = $message.Length
                    $response.OutputStream.Write($message, 0, $message.Length)
                }
            }
        } catch {
            Write-Host "Error processing request: $_" -ForegroundColor Red
            $response.StatusCode = 500
            $message = [System.Text.Encoding]::UTF8.GetBytes('{"status": "error", "message": "' + $_.ToString().Replace('"', '\"') + '"}')
            $response.ContentType = "application/json"
            $response.ContentLength64 = $message.Length
            $response.OutputStream.Write($message, 0, $message.Length)
        }
        $response.Close()
    }
} finally {
    $listener.Stop()
}
