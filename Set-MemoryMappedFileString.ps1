function Set-MemoryMappedFileString {
<#
.SYNOPSIS

Write the contents of a string in a memory mapped file.


.DESCRIPTION

Write the contents of a string in a memory mapped file.

The memory mapped file as specified by 'MapName' will not be locked for 
writing. You have to perform a custom locking (e.g. via a Mutex or 
Semphore) yourself.


.EXAMPLE

$MapName = 'myMemoryMappedFile';
$Content = 'Edgar Schnittenfittich';
$mmf = Set-MemoryMappedFileString -MapName $MapName -Content $Content -Global;
$mmf;

Get-MemoryMappedFileString -MapName $MapName -Size 100000 -Global

Set-MemoryMappedFileString -Close $mmf

In this example a memory mapped called 'myMemoryMappedFile' file is created 
in the global namespace (visible across terminal sessions on the same machine). 
Its contents is subsequently read back and then the file is closed.


.LINK

Online Version: http://dfch.biz/PS/System/IO/Set-MemoryMappedFileString/


.NOTES

See module manifest for dependencies and further requirements.


#>
[CmdletBinding(
	HelpURI='http://dfch.biz/PS/System/IO/Set-MemoryMappedFileString/'
)]

[OutputType([string])]
[OutputType([Boolean], ParameterSetName = 'close')]

Param 
(
	[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'write')]
	[alias("m")]
	[alias("map")]
	[string] $MapName
	, 
	[Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'write')]
	[alias("c")]
	[string] $Content
	, 
	[Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'write')]
	[alias("s")]
	[int] $Size = $Content.Length +4 # account for leading [int]
	,
	[Parameter(Mandatory = $false, Position = 3, ParameterSetName = 'write')]
	[alias("g")]
	[switch] $Global = $false
	, 
	[Parameter(Mandatory = $false, ParameterSetName = 'close')]
	[System.IO.MemoryMappedFiles.MemoryMappedFile] $Close
)

BEGIN 
{
	$datBegin = [datetime]::Now;
	[string] $fn = $MyInvocation.MyCommand.Name;
	Log-Debug -fn $fn -msg "CALL. MapName: '$MapName'; Content.Length: '$($Content.Length)'. Size: '$Size'. Global: '$Global'. ParameterSetName '$($PsCmdlet.ParameterSetName)'" -fac 1;
}
PROCESS 
{
	[boolean] $fReturn = $false;
	$null = $null;

	try 
	{
		# Parameter validation
		if('close' -eq $PsCmdlet.ParameterSetName) 
		{
			if(!$Close) {
				Log-Warn $fn "MemoryMappedFile is empty." -v; 
				throw($gotoFailure);
			}
			$Close.Dispose();
			$fReturn = $true;
			$OutputParameter = $fReturn;
			throw($gotoSuccess);
		}

		[int] $mmfContentLength = $Content.Length;
		if( ($MmfContentLength * [char]::Length) -gt ($Size - 4) ) 
		{
			Log-Critical $fn "MmfContentLength for MapName '$MapName' is '$MmfContentLength'."; 
			throw($gotoFailure);
		}
		
		# create MMF
		$mmf = [System.IO.MemoryMappedFiles.MemoryMappedFile]::CreateOrOpen($MapName, $Size);
		if(!$mmf) 
		{
			Log-Critical $fn "CreateOrOpen for MapName '$MapName' FAILED."; 
			throw($gotoFailure);
		}
		
		$mmfStream = $mmf.CreateViewStream(0, 0);
		if(!$mmfStream) 
		{
			Log-Critical $fn "CreateViewStream for MapName '$MapName' FAILED."; 
			throw($gotoFailure);
		}
		$mmfStream.Position = 0;
		
		$writer = New-Object System.IO.BinaryWriter($mmfStream);
		if(!$writer) 
		{
			Log-Critical $fn "New-Object System.IO.BinaryWriter for MapName '$MapName' FAILED."; 
			throw($gotoFailure);
		}
		# write length of array
		$writer.Write($mmfContentLength);
		# write contents, convert string to array first
		$writer.Write($Content.toCharArray(), 0, $mmfContentLength);

		Log-Info $fn "Writing string mmfContent[$MmfContentLength] to MapName '$MapName' SUCCEEDED." -v;
		$OutputParameter = $mmf;
		$fReturn = $true;
	}
	catch 
	{
		if($gotoSuccess -eq $_.Exception.Message) 
		{
			$fReturn = $true;
		} 
		else 
		{
			[string] $ErrorText = "catch [$($_.FullyQualifiedErrorId)]";
			$ErrorText += (($_ | fl * -Force) | Out-String);
			$ErrorText += (($_.Exception | fl * -Force) | Out-String);
			$ErrorText += (Get-PSCallStack | Out-String);
			
			Log-Error $fn $ErrorText -fac 3;
			if($gotoFailure -ne $_.Exception.Message) { Write-Verbose ("$fn`n$ErrorText"); }
			$fReturn = $false;
			$OutputParameter = $null;
		}
	}
	finally 
	{
		# Clean up
		if('close' -ne $PsCmdlet.ParameterSetName) 
		{
			if($writer) 
			{ 
				$writer.Flush(); 
				$writer.Close(); 
				$writer.Dispose();
			}
			if($mmfStream) 
			{
				$mmfStream.Close();
				$mmfStream.Dispose();
			}
		}
	}
	return $OutputParameter;
}

END 
{
	$datEnd = [datetime]::Now;
	Log-Debug -fn $fn -msg "RET. fReturn: [$fReturn]. Execution time: [$(($datEnd - $datBegin).TotalMilliseconds)]ms. Started: [$($datBegin.ToString('yyyy-MM-dd HH:mm:ss.fffzzz'))]." -fac 2;
}

} # function
if($MyInvocation.ScriptName) { Export-ModuleMember -Function Set-MemoryMappedFileString; } 


# SIG # Begin signature block
# MIILewYJKoZIhvcNAQcCoIILbDCCC2gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQULAiHMMUbcw6xSdDV4GXdkkk3
# f12gggjdMIIEKDCCAxCgAwIBAgILBAAAAAABL07hNVwwDQYJKoZIhvcNAQEFBQAw
# VzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNV
# BAsTB1Jvb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw0xMTA0
# MTMxMDAwMDBaFw0xOTA0MTMxMDAwMDBaMFExCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMScwJQYDVQQDEx5HbG9iYWxTaWduIENvZGVTaWdu
# aW5nIENBIC0gRzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCyTxTn
# EL7XJnKrNpfvU79ChF5Y0Yoo/ENGb34oRFALdV0A1zwKRJ4gaqT3RUo3YKNuPxL6
# bfq2RsNqo7gMJygCVyjRUPdhOVW4w+ElhlI8vwUd17Oa+JokMUnVoqni05GrPjxz
# 7/Yp8cg10DB7f06SpQaPh+LO9cFjZqwYaSrBXrta6G6V/zuAYp2Zx8cvZtX9YhqC
# VVrG+kB3jskwPBvw8jW4bFmc/enWyrRAHvcEytFnqXTjpQhU2YM1O46MIwx1tt6G
# Sp4aPgpQSTic0qiQv5j6yIwrJxF+KvvO3qmuOJMi+qbs+1xhdsNE1swMfi9tBoCi
# dEC7tx/0O9dzVB/zAgMBAAGjgfowgfcwDgYDVR0PAQH/BAQDAgEGMBIGA1UdEwEB
# /wQIMAYBAf8CAQAwHQYDVR0OBBYEFAhu2Lacir/tPtfDdF3MgB+oL1B6MEcGA1Ud
# IARAMD4wPAYEVR0gADA0MDIGCCsGAQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxz
# aWduLmNvbS9yZXBvc2l0b3J5LzAzBgNVHR8ELDAqMCigJqAkhiJodHRwOi8vY3Js
# Lmdsb2JhbHNpZ24ubmV0L3Jvb3QuY3JsMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB8G
# A1UdIwQYMBaAFGB7ZhpFDZfKiVAvfQTNNKj//P1LMA0GCSqGSIb3DQEBBQUAA4IB
# AQAiXMXdPfQLcNjj9efFjgkBu7GWNlxaB63HqERJUSV6rg2kGTuSnM+5Qia7O2yX
# 58fOEW1okdqNbfFTTVQ4jGHzyIJ2ab6BMgsxw2zJniAKWC/wSP5+SAeq10NYlHNU
# BDGpeA07jLBwwT1+170vKsPi9Y8MkNxrpci+aF5dbfh40r5JlR4VeAiR+zTIvoSt
# vODG3Rjb88rwe8IUPBi4A7qVPiEeP2Bpen9qA56NSvnwKCwwhF7sJnJCsW3LZMMS
# jNaES2dBfLEDF3gJ462otpYtpH6AA0+I98FrWkYVzSwZi9hwnOUtSYhgcqikGVJw
# Q17a1kYDsGgOJO9K9gslJO8kMIIErTCCA5WgAwIBAgISESFgd9/aXcgt4FtCBtsr
# p6UyMA0GCSqGSIb3DQEBBQUAMFExCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i
# YWxTaWduIG52LXNhMScwJQYDVQQDEx5HbG9iYWxTaWduIENvZGVTaWduaW5nIENB
# IC0gRzIwHhcNMTIwNjA4MDcyNDExWhcNMTUwNzEyMTAzNDA0WjB6MQswCQYDVQQG
# EwJERTEbMBkGA1UECBMSU2NobGVzd2lnLUhvbHN0ZWluMRAwDgYDVQQHEwdJdHpl
# aG9lMR0wGwYDVQQKDBRkLWZlbnMgR21iSCAmIENvLiBLRzEdMBsGA1UEAwwUZC1m
# ZW5zIEdtYkggJiBDby4gS0cwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDTG4okWyOURuYYwTbGGokj+lvBgo0dwNYJe7HZ9wrDUUB+MsPTTZL82O2INMHp
# Q8/QEMs87aalzHz2wtYN1dUIBUaedV7TZVme4ycjCfi5rlL+p44/vhNVnd1IbF/p
# xu7yOwkAwn/iR+FWbfAyFoCThJYk9agPV0CzzFFBLcEtErPJIvrHq94tbRJTqH9s
# ypQfrEToe5kBWkDYfid7U0rUkH/mbff/Tv87fd0mJkCfOL6H7/qCiYF20R23Kyw7
# D2f2hy9zTcdgzKVSPw41WTsQtB3i05qwEZ3QCgunKfDSCtldL7HTdW+cfXQ2IHIt
# N6zHpUAYxWwoyWLOcWcS69InAgMBAAGjggFUMIIBUDAOBgNVHQ8BAf8EBAMCB4Aw
# TAYDVR0gBEUwQzBBBgkrBgEEAaAyATIwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93
# d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wCQYDVR0TBAIwADATBgNVHSUE
# DDAKBggrBgEFBQcDAzA+BgNVHR8ENzA1MDOgMaAvhi1odHRwOi8vY3JsLmdsb2Jh
# bHNpZ24uY29tL2dzL2dzY29kZXNpZ25nMi5jcmwwUAYIKwYBBQUHAQEERDBCMEAG
# CCsGAQUFBzAChjRodHRwOi8vc2VjdXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9n
# c2NvZGVzaWduZzIuY3J0MB0GA1UdDgQWBBTwJ4K6WNfB5ea1nIQDH5+tzfFAujAf
# BgNVHSMEGDAWgBQIbti2nIq/7T7Xw3RdzIAfqC9QejANBgkqhkiG9w0BAQUFAAOC
# AQEAB3ZotjKh87o7xxzmXjgiYxHl+L9tmF9nuj/SSXfDEXmnhGzkl1fHREpyXSVg
# BHZAXqPKnlmAMAWj0+Tm5yATKvV682HlCQi+nZjG3tIhuTUbLdu35bss50U44zND
# qr+4wEPwzuFMUnYF2hFbYzxZMEAXVlnaj+CqtMF6P/SZNxFvaAgnEY1QvIXI2pYV
# z3RhD4VdDPmMFv0P9iQ+npC1pmNLmCaG7zpffUFvZDuX6xUlzvOi0nrTo9M5F2w7
# LbWSzZXedam6DMG0nR1Xcx0qy9wYnq4NsytwPbUy+apmZVSalSvldiNDAfmdKP0S
# CjyVwk92xgNxYFwITJuNQIto4zGCAggwggIEAgEBMGcwUTELMAkGA1UEBhMCQkUx
# GTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExJzAlBgNVBAMTHkdsb2JhbFNpZ24g
# Q29kZVNpZ25pbmcgQ0EgLSBHMgISESFgd9/aXcgt4FtCBtsrp6UyMAkGBSsOAwIa
# BQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgor
# BgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3
# DQEJBDEWBBQki2sUz27ogGCcl/mzdkHE+64HTjANBgkqhkiG9w0BAQEFAASCAQCR
# q/LuOiGZvO4EwfQ2S++07XOaGrdWxgk0iykyd3+q1/VHG5opyuP4C+d7bb+D2LDz
# cYR6XjC6AmjnyILtmSTf/K1gmFBUae2t70wXFTASEJIcRRJrOHVhLNL4tuxWbt0U
# 44FzHGBdinZTjJWcB2pjlcKWomusQUqfumwpUOePkay5mFshJaDYVN8Pe3y9vec5
# CXWhABfMnfvoyvOusc9Zza0b5HJaacThG7pQbd6kIBwu8jUIPG6q8/lWp9amBbf+
# /A9Psrm+f+20IePZ9r8/pFPfi5aKHuB6MaKkLFcW6BmEj1Uhy1YsnIKZkvLPocE1
# 1cQKdwtUgcHiQTnbRhjy
# SIG # End signature block
