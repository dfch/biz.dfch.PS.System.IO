function Get-MemoryMappedFileString {
<#
.SYNOPSIS

Reads the contents of a memory mapped file as a string.


.DESCRIPTION

Reads the contents of a memory mapped file as a string.

The memory mapped file as specified by 'MapName' will not be locked for 
reading. You have to perform a custom locking (e.g. via a Mutex or 
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

Online Version: http://dfch.biz/PS/System/IO/Get-MemoryMappedFileString/


.NOTES

See module manifest for dependencies and further requirements.


#>

[CmdletBinding(
	HelpURI='http://dfch.biz/PS/System/IO/Get-MemoryMappedFileString/'
)]

[OutputType([string])]
Param 
(
	[Parameter(Mandatory = $true, Position = 0)]
	[alias("m")]
	[alias("map")]
	[string] $MapName = $(throw("You must specify a string for this parameter."))
	, 
	[Parameter(Mandatory = $false, Position = 1)]
	[alias("s")]
	[int] $Size = 1024*1024-4
	, 
	[Parameter(Mandatory = $false, Position = 2)]
	[alias("g")]
	[switch] $Global = $false
)

BEGIN 
{
	$datBegin = [datetime]::Now;
	[string] $fn = $MyInvocation.MyCommand.Name;
	Log-Debug -fn $fn -msg "CALL. MapName: '$MapName'; Size: '$Size'. Global: '$Global'" -fac 1;
}
PROCESS 
{
	[boolean] $fReturn = $false;
	$null = $null;

	try 
	{
		# Parameter validation
		# N/A
		# adjust size for leading [int] that specifies the size
		$Size += 4;
		
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
		
		$reader = New-Object System.IO.BinaryReader($mmfStream);
		if(!$reader) 
		{
			Log-Critical $fn "New-Object System.IO.BinaryReader for MapName '$MapName' FAILED."; 
			throw($gotoFailure);
		}
		
		# check if number of char to read is non-zero
		[int] $MmfContentLength = $reader.ReadInt32();
		if(0 -ge $MmfContentLength) 
		{
			Log-Critical $fn "MmfContentLength for MapName '$MapName' is '$MmfContentLength'."; 
			throw($gotoFailure);
		}
		
		# check if created MMF view is large enough for the referenced chars
		# account for leading [int32] which is 4 bytes
		if( ($MmfContentLength * [char]::Length) -gt ($Size - 4) ) 
		{
			Log-Critical $fn "MmfContentLength for MapName '$MapName' is '$MmfContentLength'."; 
			throw($gotoFailure);
		}

		# read contents
		$achMmfContent = $reader.ReadChars($MmfContentLength);
		if( (!$achMmfContent) -or (!$achMmfContent.Length) ) 
		{
			Log-Critical $fn "achMmfContent.Length for MapName '$MapName' is 0."; 
			throw($gotoFailure);
		}

		# construct string from char[]
		$mmfContent = [string]::Join('', $achMmfContent);
		if( (!$mmfContent) -or (!$mmfContent.Length) ) 
		{
			Log-Critical $fn "mmfContent.Length for MapName '$MapName' is 0."; 
			throw($gotoFailure);
		}
		
		Log-Info $fn "Reading mmfContent[$MmfContentLength] from MapName '$MapName' SUCCEEDED." -v;
		$OutputParameter = $mmfContent;
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
		if($reader) 
		{ 
			$reader.Close(); 
			$reader.Dispose();
		}
		if($mmfStream) 
		{
			$mmfStream.Close();
			$mmfStream.Dispose();
		}
		if($mmf) 
		{
			$mmf.Dispose();
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
if($MyInvocation.ScriptName) { Export-ModuleMember -Function Get-MemoryMappedFileString; } 

# SIG # Begin signature block
# MIILewYJKoZIhvcNAQcCoIILbDCCC2gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUdd8klavZMPdfnWJUfdSQuFjT
# pL6gggjdMIIEKDCCAxCgAwIBAgILBAAAAAABL07hNVwwDQYJKoZIhvcNAQEFBQAw
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
# DQEJBDEWBBSlURHW96Xz0eiie0X4AcrXNP92FzANBgkqhkiG9w0BAQEFAASCAQAc
# Unwtbseoo96yhDYeM3Va2skbWuj43oZVTnbcumH6m6n4O4l8bhKCI91eTTaWsuMz
# LkBfuaG4JSkZWsN1ol/EyEEpU5n8VDzXUtkpJdgd+EASDJ/zhcf+hZJI5RXcD9GT
# 3vFW29OM7rAMK5igU/JQTpHNJx/Ow72iQeEzJHlehgxaoggwLvMqxI6smY8RKUkv
# aQyzVIW5xK+9fg1E7/DVMIanq3TLeHDcAeyhsw9Mho0+MfU14tg+H+HfcgtDDo0y
# J5xYX+WxixiEnKiYmPg71PD1mz3yvB6s/TD0wmtAvDGZSaVm2QGaopy//u5ngqLD
# 4P9UHHCgBP5sFptjQSIM
# SIG # End signature block
