#v04122020
#NB

$youtube_dl_location = "D:\Desktop\Youtube-dl\youtube-dl.exe"
$ffmpeg_location = "D:\Desktop\Youtube-dl\ffmpeg\bin"
$dir = "D:\Music\Lieder\Download"
$url = ""
$logdir = "$dir\download-log.txt"

[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

# functions

function Set-WindowState {
	<#
	.LINK
	https://gist.github.com/Nora-Ballard/11240204
	#>

	[CmdletBinding(DefaultParameterSetName = 'InputObject')]
	param(
		[Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
		[Object[]] $InputObject,

		[Parameter(Position = 1)]
		[ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE',
					 'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED',
					 'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
		[string] $State = 'SHOW'
	)

	Begin {
		$WindowStates = @{
			'FORCEMINIMIZE'		= 11
			'HIDE'				= 0
			'MAXIMIZE'			= 3
			'MINIMIZE'			= 6
			'RESTORE'			= 9
			'SHOW'				= 5
			'SHOWDEFAULT'		= 10
			'SHOWMAXIMIZED'		= 3
			'SHOWMINIMIZED'		= 2
			'SHOWMINNOACTIVE'	= 7
			'SHOWNA'			= 8
			'SHOWNOACTIVATE'	= 4
			'SHOWNORMAL'		= 1
		}

		$Win32ShowWindowAsync = Add-Type -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
'@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru

		if (!$global:MainWindowHandles) {
			$global:MainWindowHandles = @{ }
		}
	}

	Process {
		foreach ($process in $InputObject) {
			if ($process.MainWindowHandle -eq 0) {
				if ($global:MainWindowHandles.ContainsKey($process.Id)) {
					$handle = $global:MainWindowHandles[$process.Id]
				} else {
					Write-Error "Main Window handle is '0'"
					continue
				}
			} else {
				$handle = $process.MainWindowHandle
				$global:MainWindowHandles[$process.Id] = $handle
			}

			$Win32ShowWindowAsync::ShowWindowAsync($handle, $WindowStates[$State]) | Out-Null
			Write-Verbose ("Set Window State '{1} on '{0}'" -f $MainWindowHandle, $State)
		}
	}
}

Add-Type @"
  using System;
  using System.Runtime.InteropServices;
  public class Tricks {
     [DllImport("user32.dll")]
     [return: MarshalAs(UnmanagedType.Bool)]
     public static extern bool SetForegroundWindow(IntPtr hWnd);
  }
"@

# process


$Geturl = {
    # Get-URL
    $promptURL = Read-Host -Prompt 'Enter URL or type "C"'
    if ($promptURL -eq 'C')
    {
        $url = Get-Clipboard
    }
    else
    {
        if ($promptURL -match "/")
        {
            $url = $promptURL
        }
        else
        {
            [System.Windows.Forms.MessageBox]::Show("Not a valid URL","Error",0) | Out-Null
            cls
            .$Geturl
        }
    }
}

$download = {
    cls



    .$Geturl

    

    # Type
    Write-Host 'Video / Audio'
    $type = Read-Host -Prompt 'Choose a type'

    # Subtitles / VQuality
    $vBoth = 1
    if (($type -eq 'Video') -or ($type -eq 'V'))
    {
        Write-Host 'Y / N'
        $sub = Read-Host -Prompt 'Subtitle?'

        Write-Host ''

        Write-Host 'high / best / both'
        $vquality = Read-Host -Prompt 'Videoquality?'

        if (($vquality -eq 'high') -or ($vquality -eq 'h') -or ($vquality -eq ''))
        {
            $fquality = "bestvideo+best"
        }
        elseif (($vquality -eq 'best') -or ($vquality -eq 'b'))
        {
            $fquality = "bestvideo+bestaudio"
            $b = "_b"
        }
        elseif (($vquality -eq 'both') -or ($vquality -eq 'bo'))
        {
            $vBoth = 2
        }
    }

    

    # Download
    if ((($type -eq 'Video') -or ($type -eq 'V')) -and (($sub -eq 'n') -or ($sub -eq '')))
    {

        if ($vBoth -eq 2)
        {
            $fquality = "bestvideo+bestaudio"
            $b = "_b"
            #Write-Host "test1    $vBoth"
        }

        for ($i = 0; $i -lt $vBoth; $i++)
        {
            Write-Host 'Starting Youtube-dl...'
            Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s$b.%(ext)s -f $fquality --ignore-config --hls-prefer-native --ffmpeg-location $ffmpeg_location --merge-output-format mp4 $url")
            if ($vBoth -eq 2)
            {
                $fquality = "bestvideo+best"
                $b = ""
                $cmd_process = (Get-Process youtube-dl).Id
                Wait-Process $cmd_process
                #Write-Host "test2    $vBoth"
            }
        }
        if ($vBoth -eq 2)
        {
            $cmd_process = (Get-Process youtube-dl).Id
            Wait-Process $cmd_process
            Start-Sleep -Seconds 1
        
            $title1 = ((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -Skip 1 | Select-Object -First 1).Name
            $title2 = ((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -First 1).Name
            Write-Host "$title1    $title2"
            $title = [System.IO.Path]::GetFileNameWithoutExtension("$dir\$title2")
            New-Item -Path "$dir\$title" -ItemType Directory | Out-Null
            Move-Item $dir\$title1 $dir\$title
            Move-Item $dir\$title2 $dir\$title
        }
    }
    elseif ((($type -eq 'Video') -or ($type -eq 'V')) -and ($sub -eq 'y'))
    {
        if ($vBoth -eq 2)
        {
            [System.Windows.Forms.MessageBox]::Show("You can´t download both qualities with subtitles.`nPlease try again with other options.","Error",0) | Out-Null
            .$download
        }

        Write-Host 'Starting Youtube-dl...'
        
        Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s.%(ext)s -f $fquality --ignore-config --hls-prefer-native --write-sub --ffmpeg-location $ffmpeg_location --merge-output-format mp4 $url")
        
        $cmd_process = (Get-Process youtube-dl).Id
        Wait-Process $cmd_process
        Start-Sleep -Seconds 1
        
        $title1 = ((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -Skip 1 | Select-Object -First 1).Name
        $title2 = ((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -First 1).Name
        $title = [System.IO.Path]::GetFileNameWithoutExtension("$dir\$title2")
        New-Item -Path "$dir\$title" -ItemType Directory | Out-Null
        Move-Item $dir\$title1 $dir\$title
        Move-Item $dir\$title2 $dir\$title
    }
    elseif (($type -eq 'Audio') -or ($type -eq 'A'))
    {
        Write-Host 'opus / mp3 / both'
        $quality = Read-Host -Prompt 'Choose a quality'

        Write-Host 'Starting Youtube-dl...'
        if (($quality -eq 'opus') -or ($quality -eq 'o'))
        {
            Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s.%(ext)s -x --audio-format best --audio-quality 0 --ignore-config --hls-prefer-native --ffmpeg-location $ffmpeg_location $url")
        }
        elseif (($quality -eq 'mp3') -or ($quality -eq 'm'))
        {
            Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s.%(ext)s -x --audio-format mp3 --audio-quality 0 --ignore-config --hls-prefer-native --ffmpeg-location $ffmpeg_location $url")
        }
        elseif (($quality -eq 'both') -or ($quality -eq 'b'))
        {
            Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s.%(ext)s -x --audio-format mp3 --audio-quality 0 --ignore-config --hls-prefer-native --ffmpeg-location $ffmpeg_location $url")
            $cmd_process = (Get-Process youtube-dl).Id
            Wait-Process $cmd_process
            Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s.%(ext)s -x --audio-format best --audio-quality 0 --ignore-config --hls-prefer-native --ffmpeg-location $ffmpeg_location $url")

            Start-Sleep -Seconds 1
            $cmd_process = (Get-Process youtube-dl).Id | Out-Null
            Wait-Process $cmd_process
            Start-Sleep -Seconds 3
        
            $title1 = ((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -Skip 1 | Select-Object -First 1).Name
            $title2 = ((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -First 1).Name
            $title = [System.IO.Path]::GetFileNameWithoutExtension("$dir\$title2")
            New-Item -Path "$dir\$title" -ItemType Directory | Out-Null
            Move-Item $dir\$title1 $dir\$title
            Move-Item $dir\$title2 $dir\$title
        }
        else
        {
            Write-Host 'Thats not a valid quality'
        }
    }
    else
    {
        Write-Host 'Thats not a valid filetype'
    }

    Write-Host ''

    
        # Add another URL

        $pwsh_process = (Get-Process powershell) | Sort-Object StartTime | Select-Object -First 1
        $ytdl_process = (Get-Process youtube-dl) | Sort-Object StartTime | Select-Object -First 1
        $pwsh_process | Set-WindowState -State HIDE
        $ytdl_process | Set-WindowState -State HIDE

        
        $result = "Proceed", "Add URL" | Out-GridView -PassThru -Title "Choose option"
        #$grid_process = (Get-Process powershell | Sort-Object StartTime -ErrorAction SilentlyContinue)
        #$grid_process = ($grid_process | Select-Object -First 1).MainWindowHandle
        #[Tricks]::SetForegroundWindow($grid_process)
        if ($result -eq 'Add URL')
        {
            $pwsh_process | Set-WindowState -State SHOW
            &$download
        }
    
        $ytdl_process | Set-WindowState -State SHOW
        
        $cmd_process = (Get-Process youtube-dl -erroraction 'silentlycontinue').id
        
        if ($cmd_process -ne $null -and $cmd_process -ne 0)
        {
        Wait-Process $cmd_process
        }

        $pwsh_process | Set-WindowState -State SHOW

        #append log
        $title = [System.IO.Path]::GetFileNameWithoutExtension("$dir\$((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -First 1).Name")
        Add-Content $logdir -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm")      $title"
        
        cls
        Write-Host 'Finished'
        Read-Host "Press enter to exit..."
        
        exit

    
}

&$download