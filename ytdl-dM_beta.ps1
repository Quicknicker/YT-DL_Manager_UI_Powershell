#Caution! This file is more vulnerable to errors than the stable version.

#v22092021
#NB

$ytdl_dir = ""                                          # write YouTube-dl location here
$youtube_dl_location = "$ytdl_dir\youtube-dl.exe"
$ffmpeg_location = "$ytdl_dir\ffmpeg\bin"               # change ffmpeg location if needed
$dir = ""                                               # write target location here
$logdir = "$dir\download-log.txt"                       # change log location if needed
$isLogging = $true                                      # toggle logging
$vLogdir = "$dir\verboseLog.txt"
$verboseLog = $false                                    # toggle verbose logging
$ytAPIKey = ""                                          # write your YouTubeAPI-Key here

$url = ""
$errorCount = 0


# functions

[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null


function Get-VideoInfo {
    param(
        [Parameter(Mandatory = $True)]
        [string]$videoUrl,

        [Parameter(Mandatory = $True)]
        [ValidateSet('title', 'duration', 'id', 'etag', 'playlistId', 'itemLength', 'pTitle')]
        [string]$infoType,

        [Parameter(Mandatory = $False)]
        [boolean]$isPlaylist = $False
    )

    if ($isPlaylist -eq $False)
    {

        $regex = '[^ ]*v='
        $videoID = $videoURL -replace $regex
        $regex = '&[^ ]*'
        $videoID = $videoID -replace $regex
        $metadata = irm "https://www.googleapis.com/youtube/v3/videos?id=$videoID&key=$ytAPIKey&part=snippet&part=contentDetails"
        if ($infoType -eq 'duration')
        {
            $videoDuration = $metadata.items.contentDetails.duration

            $regex = '(^[A-Z]*)'
            $videoDuration = $videoDuration -replace $regex

            $regex = 'H[^ ]*'
            $videoM = $videoDuration -replace $regex
            if ($videoM -ne $videoDuration)
            {
                [int]$videoM *= 60
            }

            $regex = 'M[^ ]*'
            $videoM2 = $videoDuration -replace $regex
            $regex = '[^ ]*H'
            if ($videoM -ne $videoDuration)
            {
                $videoM += $videoM2 -replace $regex
            } else
            {
                $videoM = $videoM2
            }

            $regex = '[^ ]*M'
            $videoS = $videoDuration -replace $regex
            $regex = 'S[^ ]*'
            $videoS = $videoS -replace $regex

            $videoInfo = [int]$videoM*60 + $videoS

        } elseif ($infoType -eq 'title')
        {
            $videoInfo = $metadata.items.snippet.title
        } elseif ($infoType -eq 'id')
        {
            $videoInfo = $metadata.items.id
        } elseif ($infoType -eq 'etag')
        {
            $videoInfo = $metadata.etag
        }

    } else
    {
        $regex = '[^ ]*list='
        $listID = $videoURL -replace $regex
        $regex = '&[^ ]*'
        $listID = $listID -replace $regex
        $metadata = irm "https://www.googleapis.com/youtube/v3/playlistItems?playlistId=$listID&key=$ytAPIKey&maxResults=50&part=snippet&part=contentDetails"

        $videoInfo = @()

        if ($infoType -eq 'title')
        {
            foreach ($item in $metadata.items)
            {
                $videoInfo += $item.snippet.title
            }
        } elseif ($infoType -eq 'id')
        {
            foreach ($item in $metadata.items)
            {
                $videoInfo += $item.contentDetails.videoId
            }
        } elseif ($infoType -eq 'etag')
        {
            $videoInfo = $metadata.etag
        } elseif ($infoType -eq 'playlistId')
        {
            $videoInfo = $listID
        } elseif ($infoType -eq 'itemLength')
        {
            $videoInfo = $metadata.pageInfo.totalResults
        } elseif ($infoType -eq 'pTitle')
        {
            $metadata = irm "https://www.googleapis.com/youtube/v3/playlists?id=$listID&key=$ytAPIKey&part=snippet&part=contentDetails"
            $videoInfo = $metadata.items[0].snippet.title
        }

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

function verboseLog {
        # create log at first launch
        if (-not [System.IO.File]::Exists($vLogdir))
        {
            New-Item -Path "$vLogdir" -ItemType File
        }


        # get info
        if ($vBoth -eq 2 -or $sub -eq 'y' -or $quality -eq 'b')
        {
            $title = [System.IO.Path]::GetFileNameWithoutExtension("$dir\$((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -First 1).Name")
        } else
        {
            $title = Get-VideoInfo -videoUrl $url -infoType title
            $videoID = Get-VideoInfo -videoUrl $url -infoType id
            $videoEtag = Get-VideoInfo -videoUrl $url -infoType etag
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
        Add-Content $vLogdir -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm")      $title              Id= $videoID; Etag= $videoEtag"
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


# URL
$Geturl = {
    $promptURL = Read-Host -Prompt 'Enter URL or type "C"'
    if (($promptURL -eq 'C') -or $promptURL -eq '')
    {
        if ((Get-Clipboard) -eq $null -or (Get-Clipboard) -eq "")
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

    # set params

    .$Geturl


    # type
    Write-Host 'Video / Audio'
    $type = Read-Host -Prompt 'Choose a type'

    # subtitles / vQuality
    $vBoth = 1
    if (($type -eq 'Video') -or ($type -eq 'V') -or ($type -eq ''))
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
        } else
        {
            Write-Host 'opus / mp3 / both (b)'
            $quality = Read-Host -Prompt 'Choose a quality'
        }
    }

    # check for double
    $fileTitle = Get-VideoInfo -videoUrl $url -infoType title
    if ($type -eq 'V' -or $type -eq 'Video' -or $type -eq '')
    {
        $fileTitle += '.mp4'
    } elseif ((($type -eq 'Audio') -or ($type -eq 'A')) -and ($quality -eq 'mp3' -or $quality -eq 'm' -or $quality -eq ''))
    {
        $fileTitle += '.mp3'
    } elseif ((($type -eq 'Audio') -or ($type -eq 'A')) -and ($quality -eq 'opus' -or $quality -eq 'o'))
    {
        $fileTitle += '.opus'
    }
    <#$ErrorActionPreference = 'Ignore'
    $cmd_process = (Get-Process youtube-dl).Id | Out-Null
    Wait-Process $cmd_process | Out-Null
    $ErrorActionPreference = 'Continue'#>

    #[System.Windows.Forms.MessageBox]::Show("$dir\$fileTitle","Error",0) | Out-Null

    $number = ''
    $ErrorActionPreference = 'SilentlyContinue'
    if ([System.IO.File]::Exists("$dir\$fileTitle") -or (Get-Process youtube-dl -ErrorAction SilentlyContinue) -ne $null)
    {
        $ErrorActionPreference = 'Continue'

        #[System.Windows.Forms.MessageBox]::Show("TEST001","Error",0) | Out-Null

        #$fileTitle += '_'
        $_fileTitle = $fileTitle
        $number = 0
        while ([System.IO.File]::Exists("$dir\$_fileTitle"))
        {
            #[System.Windows.Forms.MessageBox]::Show("TEST002","Error",0) | Out-Null
            $_fileTitle = $fileTitle + [String]$number
            $number++
        }
        <#$fileTitle += $number
        Rename-Item -Path "$dir\$fileTitle" -NewName "$(fileTitle)_$number"
        #--------------------------------------------------------------------------------------------------------------------------------------- READ-HOST Line334
        Read-host '10sek to rename file with same name'
        Start-Sleep -Seconds 10#>
    }
    

    # download
    #$ErrorActionPreference = "SilentlyContinue"

    if ((($type -eq 'Video') -or ($type -eq 'V') -or ($type -eq '')) -and (($sub -eq 'n') -or ($sub -eq '')))
    {

        if ($vBoth -eq 2)
        {
            $fquality = "bestvideo+bestaudio"
            $b = "_b"
        }

        for ($i = 0; $i -lt $vBoth; $i++)
        {
            Write-Host 'Starting Youtube-dl...'
            Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s$b$number.%(ext)s -f $fquality --ignore-config --hls-prefer-native --ffmpeg-location $ffmpeg_location --merge-output-format mp4 $url")
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
        
        Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s$number.%(ext)s -f $fquality --ignore-config --hls-prefer-native --write-sub --ffmpeg-location $ffmpeg_location --merge-output-format mp4 $url")
        
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
        <#Write-Host 'opus / mp3 / both (b)'
        $quality = Read-Host -Prompt 'Choose a quality'#>

        Write-Host 'Starting Youtube-dl...'
        if (($quality -eq 'opus') -or ($quality -eq 'o'))
        {
            Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s$number.%(ext)s -x --audio-format best --audio-quality 0 --ignore-config --hls-prefer-native --ffmpeg-location $ffmpeg_location $url")
        }
        elseif (($quality -eq 'mp3') -or ($quality -eq 'm') -or ($quality -eq ''))
        {
            Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s$number.%(ext)s -x --audio-format mp3 --audio-quality 0 --ignore-config --hls-prefer-native --ffmpeg-location $ffmpeg_location $url")
        }
        elseif (($quality -eq 'both') -or ($quality -eq 'b'))
        {
            Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s$number.%(ext)s -x --audio-format mp3 --audio-quality 0 --ignore-config --hls-prefer-native --ffmpeg-location $ffmpeg_location $url")
            $cmd_process = (Get-Process youtube-dl).Id
            Wait-Process $cmd_process
            Start-Process $youtube_dl_location -ArgumentList ("-o $dir\%(title)s$number.%(ext)s -x --audio-format best --audio-quality 0 --ignore-config --hls-prefer-native --ffmpeg-location $ffmpeg_location $url")

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

        # log playlists
        if ($url.Contains('playlist?list='))
        {
            $title = Get-VideoInfo -videoUrl $url -infoType title -isPlaylist $True
            $videoID = Get-VideoInfo -videoUrl $url -infoType id -isPlaylist $True
            $videoEtag = Get-VideoInfo -videoUrl $url -infoType etag -isPlaylist $True
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
            
            Add-Content $logdir -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm")      PlaylistDownload      Id= $(Get-VideoInfo -videoUrl $url -infoType playlistId -isPlaylist $True); Etag= $videoEtag"
            for ($i = 0; $i -lt (Get-VideoInfo -videoUrl $url -infoType itemLength -isPlaylist $True); $i++)
            {
                Add-Content $logdir -Value "       " -NoNewline; Add-Content $logdir -Value $title[$i] -NoNewline; Add-Content $logdir -Value "      Id= " -NoNewline; Add-Content $logdir -Value $videoID[$i]
            }

        } else
        {

            # append new file to log
            # if vid is longer than 1H -> addon
            if ((Get-VideoInfo -videoUrl $url -infoType duration) -gt 3600)
            {
                $addon = '      TIME CAN DIFFER'
            }

            # get title of video
            if ($vBoth -eq 2 -or $sub -eq 'y' -or $quality -eq 'bo' -or $quality -eq 'both')
            {
                $title = [System.IO.Path]::GetFileNameWithoutExtension("$dir\$((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -First 1).Name")
            } else
            {
                $title = Get-VideoInfo -videoUrl $url -infoType title
                $videoID = Get-VideoInfo -videoUrl $url -infoType id
                $videoEtag = Get-VideoInfo -videoUrl $url -infoType etag
                if ($type -eq 'V' -or $type -eq 'Video' -or $type -eq '')
                {
                    $title = $title + '.mp4'
                } elseif ((($type -eq 'Audio') -or ($type -eq 'A')) -and ($quality -eq 'mp3' -or $quality -eq 'm' -or $quality -eq ''))
                {
                    $title = $title + '.mp3'
                } elseif ((($type -eq 'Audio') -or ($type -eq 'A')) -and ($quality -eq 'opus' -or $quality -eq 'o'))
                {
                    $title = $title + '.opus'
                }
            }
            Add-Content $logdir -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm")      $title$addon              Id= $videoID; Etag= $videoEtag"
        }
    }

    if (($url.Contains('playlist?list=')) -and ($errorCount -eq 0))
    {
        Start-Sleep -Seconds 1
        $cmd_process = (Get-Process youtube-dl).Id
        Wait-Process $cmd_process
        Start-Sleep -Seconds 3

        $titles = @();
        for ($i = 0; $i -lt (Get-VideoInfo -videoUrl $url -infoType itemLength -isPlaylist $True); $i++)
        {
            $titles += ((Get-ChildItem $dir) | Sort-Object CreationTime -Descending | Select-Object -Skip $i | Select-Object -First 1).Name
        }

        $pTitle = (Get-VideoInfo -videoUrl $url -infoType pTitle -isPlaylist $True)
        New-Item -Path "$dir\$pTitle" -ItemType Directory | Out-Null

        <#for ($i = 0; $i -lt (Get-VideoInfo -videoUrl $url -infoType itemLength -isPlaylist $True); $i++)
        {
            Move-Item $dir\$titles[$i] $dir\$pTitle
        }#>

        foreach ($title in $titles)
        {
            Move-Item $dir\$title $dir\$pTitle
        }
    }

    if ($verboseLog -eq $true)
    {
        verboseLog
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
