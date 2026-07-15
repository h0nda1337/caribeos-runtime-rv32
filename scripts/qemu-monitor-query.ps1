param(
  [ValidateRange(1, 65535)]
  [int]$Port,
  [string[]]$Command = @(
    "info cpus",
    "cpu 0",
    "info registers",
    "cpu 1",
    "info registers"
  ),
  [ValidateRange(1, 30)]
  [int]$TimeoutSeconds = 5
)

$ErrorActionPreference = "Stop"
$client = [Net.Sockets.TcpClient]::new()

try {
  $client.Connect("127.0.0.1", $Port)
  $client.NoDelay = $true
  $stream = $client.GetStream()
  $stream.ReadTimeout = 250
  $stream.WriteTimeout = 2000
  $encoding = [Text.Encoding]::ASCII
  $buffer = [byte[]]::new(4096)

  function Read-MonitorOutput {
    param([DateTime]$Deadline)

    $text = ""
    do {
      while ($stream.DataAvailable) {
        $count = $stream.Read($buffer, 0, $buffer.Length)
        if ($count -le 0) {
          return $text
        }
        $text += $encoding.GetString($buffer, 0, $count)
      }
      if ($text -match '\(qemu\)\s*$') {
        return $text
      }
      Start-Sleep -Milliseconds 25
    } while ([DateTime]::UtcNow -lt $Deadline)
    return $text
  }

  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  [void](Read-MonitorOutput -Deadline $deadline)
  foreach ($item in $Command) {
    $bytes = $encoding.GetBytes($item + "`n")
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
    Read-MonitorOutput -Deadline $deadline
  }
} finally {
  $client.Dispose()
}
