# --- ОСНОВНАЯ КОНФИГУРАЦИЯ СЕРВЕРА ---
$port = 8000
$root = "d:\planning-wedding"

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
