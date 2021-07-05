<#Tämä skripti luo oppilaiden nimitiedostosta jokaiselle käyttäjätunnuksen ja salasanan sekä lisää henkilöt palvelimelle. 
skripti käynnistetään parametrilla -file tiedostonnimi (.\AddU.ps1 -file TVT20)
Lähtötiedostosta(csv) tulee löytyä sarakkeet "Etunimi" ja "Sukunimi".
Lopuksi skripti tekee csv:n josta löytyvät jokaisen käsitellyn henkilön etunimi, sukunimi, ryhmä, tunnus, salasana ja email.#>

param([String]$file) 
$ErrorActionPreference = 'silentlycontinue'
$FileExists = Test-Path .\$file.*

If ($FileExists -eq $False) {  #Tässä testataan onko haluttua tiedostoa olemassa. Jos ei, niin lopetetaan.
	Write-Host "Tiedostoa $file ei ole."
	exit
}

$toMeasure = Import-Csv .\$file.* | Measure-Object
$emptyOrNot =  $toMeasure.Count

if ($emptyOrNot -eq 0) {	#Tässä testataan onko haluttu tiedosto tyhjä. Jos on, niin lopetetaan.
	Write-Host "Tiedosto $file on tyhja."
	exit
}

function Scrambler ([string]$inputStr){     #Tämä funktio sotkee luodun salasanan merkkien järjestyksen.
   $charArray = $inputStr.ToCharArray()   
   $scrambledStrArray = $charArray | Get-Random -Count $charArray.Length     
   $outputStr = -join $scrambledStrArray
   return $outputStr
}

function Pword ()	#Tässä tehdään salasana joka lähetetään Scrambler funktiolle.
{
	$characters1 = -join ((65..90) | Get-Random -Count 3 | % {[char]$_})
	$characters2 = -join ((97..122) | Get-Random -Count 3 | % {[char]$_})
	$characters3 = -join ((48..57) | Get-Random -Count 3 | % {[char]$_})
	$passwordRaw = $characters1 + $characters2 + $characters3
	$password =  Scrambler ($passwordRaw)
	return $password
}

$schoolYear = Get-Date -Format "yy" #Tässä haetaan vuosiluvun kaksi viimeistä numeroa käyttäjätunnusta varten.

class Student {
[object] ${Etunimi}	
[object] ${Sukunimi}
[object] ${Ryhma}
[object] ${Tunnus}
[object] ${Salasana}
[object] ${Email}
}

$activeUnits=@()
$units = Get-ADObject -Filter { ObjectClass -eq 'organizationalunit' }	#Tarkistetaan onko OU:ta olemassa. Jos ei, niin luodaan.
$units | ForEach-Object {
	$activeUnits += $_.Name
}

if ($file -notin $activeUnits) {
    New-ADOrganizationalUnit $file -path 'OU=opiskelijat,DC=VirtualRPKK,DC=local'
}

$students = @()
$loginStorage = @()
$activeUsers = @(Get-ADUser -Filter * -SearchBase "DC=VirtualRPKK, DC=local" | Select SAMAccountName)
$source = Import-Csv .\$file.* #Tuodaan nimitiedosto.
$source | ForEach-Object {
	$firstname = $_.Etunimi
	$lastname = $_.Sukunimi
	$fullname = $_.Etunimi+" "+$_.Sukunimi
	$lengthFirst = $_.Etunimi.length
	$lengthLast = $_.Sukunimi.length
	
	if ($lengthFirst -lt 2) #Tässä tarkistetaan onko etunimi riittävän pitkä. Jos ei, niin nimeä jatketaan.
	{
		for ($i = 1; $i -lt 2; $i++)
		{
		$firstname = $firstname + $i
		}
	}

	if ($lengthLast -lt 4) #Tässä tarkistetaan onko sukunimi riittävän pitkä. Jos ei, niin nimeä jatketaan.
	{
		for ($i = 1; $i -lt 4; $i++)
		{
		$lastname = $lastname + $i
		}
	}

	$subFirst = $firstname.Substring(0,2) #Tässä luodaan käyttäjätunnus.
	$subLast = $lastname.Substring(0,4)
	$login = $subLast + $subFirst
	$login = $login.ToLower()
	$login = $login + $schoolYear
	
	if ($loginStorage -contains $login) #Tässä tarkistetaan onko samanniminen käyttäjä jo luotu. Jos on, niin käyttäjätunnusta muutetaan.
	{
		$tempVarEnd = $login.Substring(4,2)
		$tempVarStart = $login.SubString(0,4)
		$login = $tempVarEnd + $tempVarStart + $schoolYear    
	}

    $loginStorage += $login


    $activeUsers | ForEach-Object {

    if ($login -eq $_.SAMAccountName) { #Tässä tarkistetaan onko luotu käyttäjä jo olemassa palvelimella. Jos on, niin käyttäjätunnusta muutetaan.
        $tempArr = $login.ToCharArray()    
        
        if ($tempArr[5] -eq '2')
        {
            $tempArr[5] = '3'
        }
        elseif ($tempArr[5] -eq '3')
        {
            $tempArr[5] = '4'
        }
        elseif ($tempArr[5] -eq '4')
        {
            $tempArr[5] = '5'
        }
        else
        {
            $tempArr[5] = '2'
        }
        $login = [system.String]::Join("", $tempArr)
    }
}
	
	$pw = Pword
	$securepw = ConvertTo-SecureString $pw -AsPlainText -Force
	$email = $login + "@rpkk.fi"
	$studentObj = [Student]::new() #Tässä luodaan luokasta Student oliota.
	$studentObj.'Etunimi' = $_.Etunimi
	$studentObj.'Sukunimi' = $_.Sukunimi
	$studentObj.'Ryhma' = $file
	$studentObj.'Tunnus' = $login
	$studentObj.'Salasana' = $pw
	$studentObj.'Email' = $email
	$students += $studentObj #Tässä lisätään luotu olio taulukkoon ja alempana luodaan ADUser sekä lisätään henkilö OU:hun.
	New-ADUser -Name $fullname -GivenName $_.Etunimi -Surname $_.Sukunimi -SamAccountName $login -UserPrincipalName $login -EmailAddress $email -Path "OU=$file,OU=opiskelijat,DC=VirtualRPKK,DC=local" -AccountPassword $securepw -Enabled $true
	$counter = $counter + 1
}
$outputFile = $file+"Valmiit"
$students | Export-Csv -Path .\$outputFile.csv -Encoding UTF8 -NoTypeInformation
Write-Host "Valmis. Luotiin $counter tunnusta."