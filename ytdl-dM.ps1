#v31122020
#NB (https://github.com/Quicknicker/YT-DL_Manager_Powershell)

$ytdl_dir = ""                                          # write YouTube-dl location here
$youtube_dl_location = "$ytdl_dir\youtube-dl.exe"
$ffmpeg_location = "$ytdl_dir\ffmpeg\bin"               # change ffmpeg location if needed
$dir = ""                                               # write target location here
$logdir = "$dir\download-log.txt"                       # change log location if needed
$isLogging = $true                                      # toggle logging
$ytAPIkey = ""                                          # write your API-Key here (see description)


$url = ""
$errorCount = 0


# functions

[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null


function Get-VideoInfo {
    param(
        [Parameter(Mandatory = $True)]
        [string]$videoURL,

        [Parameter(Mandatory = $True)]
        [ValidateSet('title', 'duration')]
        [string]$infoType
    )

    $regex = '[^ ]*v='
    $videoID = $videoURL -replace $regex
    $regex = '&t[^ ]*'
    $videoID = $videoID -replace $regex
    if ($infoType -eq 'duration')
    {
        $metadata = irm "https://www.googleapis.com/youtube/v3/videos?id=$videoID&key=$ytAPIkey&part=contentDetails"
        $videoDuration = $metadata.items.contentDetails.duration

        $regex = '(^[A-Z]*)'
        $videoDuration = $videoDuration -replace $regex

        $regex = 'M[^ ]*'
        $videoM = $videoDuration -replace $regex
        [int]$videoM *= 60

        $regex = '[^ ]*M'
        $videoS = $videoDuration -replace $regex
        $regex = 'S[^ ]*'
        $videoS = $videoS -replace $regex

        [int]$videoInfo = $videoM + $videoS

    } elseif ($infoType -eq 'title')
    {
        $metadata = irm "https://www.googleapis.com/youtube/v3/videos?id=$videoID&key=AIzaSyA0efdXk-WaYhGSefbAMxU2VZjcLnsv8w4&part=snippet"
        $videoInfo = $metadata.items.snippet.title
    }
    
    $videoInfo
}

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


# URL
$Geturl = {
    $promptURL = Read-Host -Prompt 'Enter URL or type "C"'
    if ($promptURL -eq 'C')
    {
        if ((Get-Clipboard) -eq $null)
        {
            Write-Host "Problem with Userinput..."
            Start-Sleep -Seconds 2
            exit
        }
        else
        {
            $url = Get-Clipboard
        }
    }
    else
    {
        if (($promptURL -match "/") -or ($promptURL -match "."))
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

    # delete timecode
    $regex = '&t[^ ]*'
    $url = $url -replace $regex
}

# process
$download = {
    cls



    .$Geturl


        # type
        Write-Host 'Video / Audio'
        $type = Read-Host -Prompt 'Choose a type'

        # subtitles / vQuality
        $vBoth = 1
        if (($type -eq 'Video') -or ($type -eq 'V'))
        {
            Write-Host 'Y / N'
            $sub = Read-Host -Prompt 'Subtitle?'

            Write-Host ''

            Write-Host 'high / best / both (bo)'
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
            else
            {
                Write-Host "Problem with Userinput..."
                Start-Sleep -Seconds 2
                exit
            }
        }
        else
        {
            if (($type -ne 'Audio') -and ($type -ne 'A'))
            {
                Write-Host "Problem with Userinput..."
                Start-Sleep -Seconds 2
                exit
            }
        }

    

    # download
    #$ErrorActionPreference = "SilentlyContinue"

    if ((($type -eq 'Video') -or ($type -eq 'V')) -and (($sub -eq 'n') -or ($sub -eq '')))
    {

        if ($vBoth -eq 2)
        {
            $fquality = "bestvideo+bestaudio"
            $b = "_b"
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
            }
        }
        if ($vBoth -eq 2)
        {

            $ErrorActionPreference = 'Ignore'
            $cmd_process = (Get-Process youtube-dl -ErrorAction Ignore).Id
            Wait-Process $cmd_process
            Start-Sleep -Seconds 1
            $ErrorActionPreference = 'Continue'
        
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
        
        $ErrorActionPreference = 'Ignore'
        $cmd_process = (Get-Process youtube-dl -ErrorAction Ignore).Id
        Wait-Process $cmd_process
        Start-Sleep -Seconds 1
        $ErrorActionPreference = 'Continue'
        
        $title1 = ((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -Skip 1 | Select-Object -First 1).Name
        $title2 = ((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -First 1).Name
        $title = [System.IO.Path]::GetFileNameWithoutExtension("$dir\$title2")
        New-Item -Path "$dir\$title" -ItemType Directory | Out-Null
        Move-Item $dir\$title1 $dir\$title
        Move-Item $dir\$title2 $dir\$title
    }
    elseif (($type -eq 'Audio') -or ($type -eq 'A'))
    {
        Write-Host 'opus / mp3 / both (b)'
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
            $cmd_process = (Get-Process youtube-dl).Id
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
            $errorCount += 1
        }
    }
    else
    {
        Write-Host 'Thats not a valid filetype'
        $errorCount += 1
    }

    Write-Host ''

    
        
    # hide toggle
    $ErrorActionPreference = 'Ignore'
    $pwsh_process = (Get-Process powershell) | Sort-Object StartTime | Select-Object -First 1
    $ytdl_process = (Get-Process youtube-dl) | Sort-Object StartTime | Select-Object -First 1
    $pwsh_process | Set-WindowState -State HIDE
    $ytdl_process | Set-WindowState -State HIDE
    $ErrorActionPreference = 'Continue'

    # append log
    if (($isLogging -eq $true) <#-and ($Error.Count -eq 0)#> -and ($errorCount -eq 0))
    {
        

        # create log at first launch
        if (-not [System.IO.File]::Exists($logdir))
        {
            New-Item -Path "$logdir" -ItemType File
        }

        # append new file to log
        if ((Get-VideoInfo -videoURL $url -infoType duration) -gt 3600)
        {
            $addon = '      time can differ'
        }

        # get title of video
        if ($vBoth -eq 2 -or $sub -eq 'y' -or $quality -eq 'b')
        {
            $title = [System.IO.Path]::GetFileNameWithoutExtension("$dir\$((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -First 1).Name")
        } else
        {
            $title = Get-VideoInfo -videoURL $url -infoType title
            if ($type -eq 'V' -or $type -eq 'Video')
            {
                $title = $title + '.mp4'
            } elseif ((($type -eq 'Audio') -or ($type -eq 'A')) -and ($quality -eq 'mp3' -or $quality -eq 'm'))
            {
                $title = $title + '.mp3'
            } elseif ((($type -eq 'Audio') -or ($type -eq 'A')) -and ($quality -eq 'opus' -or $quality -eq 'o'))
            {
                $title = $title + '.opus'
            }
        }
        Add-Content $logdir -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm")      $title$addon"
    }
        
    # add another URL
    if ($vBoth -eq 2 -or $sub -eq 'y' -or $quality -eq 'b')
    {
        # wait until download finished
        $cmd_process = (Get-Process youtube-dl -erroraction 'silentlycontinue').id

        if ($cmd_process -ne $null -and $cmd_process -ne 0)
        {
            Wait-Process $cmd_process
        }
    }

    $result = "Proceed", "Add URL" | Out-GridView -PassThru -Title "Choose option"
        
    if ($result -eq 'Add URL')
    {
        $pwsh_process | Set-WindowState -State SHOW
        &$download
    }
    
    # hide toggle
    $ytdl_process | Set-WindowState -State SHOW
        
    $cmd_process = (Get-Process youtube-dl -erroraction 'silentlycontinue').id
        
    if ($cmd_process -ne $null -and $cmd_process -ne 0)
    {
    Wait-Process $cmd_process
    }

    $pwsh_process | Set-WindowState -State SHOW

    # finish
    cls
    Write-Host 'Finished'
    Read-Host "Press enter to exit..."
        
    exit

    
}

# run
&$download
