$schoolYear = Read-Host -Prompt "Anna lukuvuosi (kaksi numeroa, lisataan kayttajatunnuksen peraan.)"
$fileName = "Oppilaat" + $schoolYear

class CsvRow {
[object] ${Tunnus}
[object] ${Etunimi}
[object] ${Sukunimi}
[object] ${Email}
}

$users = @()

Import-Csv .\nimet.csv | ForEach-Object {
	$firstname = $_.Etunimi
	$lastname = $_.Sukunimi
	$lengthFirst = $_.Etunimi.length
	$lengthLast = $_.Sukunimi.length
	
	if ($lengthFirst -lt 2)
	{
		for ($i = 1; $i -lt 2; $i++)
		{
		$firstname = $firstname + $i
		}
	}

	if ($lengthLast -lt 4)
	{
		for ($i = 1; $i -lt 4; $i++)
		{
		$lastname = $lastname + $i
		}
	}

	$subFirst = $firstname.Substring(0,2)
	$subLast = $lastname.Substring(0,4)
	$login = $subLast + $subFirst
	$login = $login.ToLower()
	$login = $login + $schoolYear
	$email = $login + "@rpkk.fi"
	$rowObj = [CsvRow]::new()
	$rowObj.'Tunnus' = $login
	$rowObj.'Etunimi' = $_.Etunimi
	$rowObj.'Sukunimi' = $_.Sukunimi
	$rowObj.'Email' = $email
	$users += $rowObj
}
$users | Out-File -Append .\$fileName.csv -Encoding UTF8