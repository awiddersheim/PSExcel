#handle PS2
if(-not $PSScriptRoot)
{
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

$PSVersion = $PSVersionTable.PSVersion.Major
Import-Module $PSScriptRoot\..\PSExcel -Force

#Set up some data we will use in testing
    $ExistingXLSXFile = "$PSScriptRoot\Working.xlsx"
    Remove-Item $ExistingXLSXFile  -force -ErrorAction SilentlyContinue
    Copy-Item $PSScriptRoot\Test.xlsx $ExistingXLSXFile -force

    $NewXLSXFile = "$PSScriptRoot\New.xlsx"
    Remove-Item $NewXLSXFile  -force -ErrorAction SilentlyContinue

    $Files = Get-ChildItem $PSScriptRoot | Where {-not $_.PSIsContainer}

Describe "New-Excel PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should create an ExcelPackage' {
            $Excel = New-Excel
            $Excel -is [OfficeOpenXml.ExcelPackage] | Should Be $True
            $Excel.Dispose()
            $Excel = $Null

            $Excel = New-Excel -Path $NewXLSXFile
            $Excel -is [OfficeOpenXml.ExcelPackage] | Should Be $True
            $Excel.Dispose()
            $Excel = $Null

        }

        It 'should reflect the correct path' {
            Remove-Item $NewXLSXFile -force -ErrorAction silentlycontinue
            $Excel = New-Excel -Path $NewXLSXFile
            $Excel.File | Should be $NewXLSXFile
            $Excel.Dispose()
            $Excel = $Null
        }

        It 'should not create a file' {
            Test-Path $NewXLSXFile | Should Be $False
        }
    }
}

Describe "Import-XLSX PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should import data with expected results' {
            $ExcelData = Import-XLSX -Path $ExistingXLSXFile
            $Props = $ExcelData[0].PSObject.Properties | Select -ExpandProperty Name

            $ExcelData.count | Should be 10
            $Props[0] | Should be 'Name'
            $Props[1] | Should be 'Val'
           
            $Exceldata[0].val | Should be '944041859'
            $Exceldata[0].name | Should be 'Prop1'

        }
        It 'should parse numberformat for dates' {
            $ExcelData = Import-XLSX -Path $ExistingXLSXFile
             
            $Exceldata[0].Date -is [datetime] | Should be $True
            $Exceldata[0].Date.Month | Should be 1
            $Exceldata[0].Date.Year | Should be 2015
            $Exceldata[0].Date.Hour | Should be 4
        }

        It 'should replace headers' {
            $ExcelData = Import-XLSX -Path $ExistingXLSXFile -Header one, two, three
            $Props = $ExcelData[0].PSObject.Properties | Select -ExpandProperty Name

            $Props[0] | Should be 'one'
            $Props[1] | Should be 'two' 
            $Props[2] | Should be 'three'  
        }
    }
}

Describe "Export-XLSX PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should create a file' {
            $Files | Export-XLSX -Path $NewXLSXFile

            Test-Path $NewXLSXFile | Should Be $True

        }

        It 'should add the correct number of rows' {
            $ExportedData = Import-XLSX -Path $NewXLSXFile
            $Files.Count | Should be $ExportedData.count
        }

        It 'should build pivot tables' {

            Remove-Item $NewXLSXFile -ErrorAction SilentlyContinue -force
            
            Get-ChildItem C:\Windows |
                Where {-not $_.PSIsContainer} |
                Export-XLSX -Path $NewXLSXFile -PivotRows Extension -PivotValues Length

            $Excel = New-Excel -Path $NewXLSXFile
            
            $WorkSheet = @( $Excel | Get-Worksheet -Name PivotTable1 )

            $worksheet[0].PivotTables[0].RowFields[0].Name | Should be Extension
        }

        It 'should build pivot charts' {

            Remove-Item $NewXLSXFile -ErrorAction SilentlyContinue -force
            
            Get-ChildItem C:\Windows |
                Where {-not $_.PSIsContainer} |
                Export-XLSX -Path $NewXLSXFile -PivotRows Extension -PivotValues Length -ChartType Pie

            $Excel = New-Excel -Path $NewXLSXFile
            
            $WorkSheet = @( $Excel | Get-Worksheet -Name PivotTable1 )

            $WorkSheet[0].Drawings[0].ChartType.ToString() | Should be 'Pie' 

        }

    }
}

Describe "Close-Excel PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should close an excelpackage' {
            $Excel = New-Excel -Path $NewXLSXFile
            $File = $Excel.File
            $Excel | Close-Excel
            $Excel.File -like $File | Should be $False
        }

        It 'should save when requested' {
            Remove-Item $NewXLSXFile -Force -ErrorAction SilentlyContinue
            $Excel = New-Excel -Path $NewXLSXFile
            [void]$Excel.Workbook.Worksheets.Add(1)
            $Excel | Close-Excel -Save
            Test-Path $NewXLSXFile | Should be $True
        }

        It 'should save as a specified path' {
            $Excel = New-Excel -Path $NewXLSXFile
            $Excel | Close-Excel -Path "$NewXLSXFile`2"
            Test-Path "$NewXLSXFile`2" | Should be $True
            Remove-Item "$NewXLSXFile`2" -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Save-Excel PS$PSVersion" {
    
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should save an xlsx file' {
            
            Remove-Item $NewXLSXFile -Force -ErrorAction SilentlyContinue
            
            $Excel = New-Excel -Path $NewXLSXFile
            [void]$Excel.Workbook.Worksheets.Add(1)
            $Excel | Save-Excel
            
            Test-Path $NewXLSXFile | Should be $True
        }

        It 'should close an excelpackage when specified' {
            
            Remove-Item $NewXLSXFile -Force -ErrorAction SilentlyContinue

            $Excel = New-Excel -Path $NewXLSXFile
            [void]$Excel.Workbook.Worksheets.Add(1)
            $File = $Excel.File
            $Excel | Save-Excel -Close
            
            $Excel.File -like $File | Should be $False
        }

        It 'should save as a specified path' {
            
            Remove-Item "$NewXLSXFile`2" -Force -ErrorAction SilentlyContinue
            Remove-Item "$NewXLSXFile" -Force -ErrorAction SilentlyContinue

            $Excel = New-Excel -Path $NewXLSXFile
            [void]$Excel.Workbook.Worksheets.Add(1)
            $Excel | Save-Excel -Path "$NewXLSXFile`2"
            
            Test-Path "$NewXLSXFile`2" | Should be $True
            Remove-Item "$NewXLSXFile`2" -Force -ErrorAction SilentlyContinue
        }

        It 'should return a fresh excelpackage when passthru is specified' {
            
            #If you want to save twice, you need to pull the excel package back in, otherwise, it bombs out.

            Remove-Item "$NewXLSXFile" -Force -ErrorAction SilentlyContinue
            
            $Excel = New-Excel -Path $NewXLSXFile
            [void]$Excel.Workbook.Worksheets.Add(1)
            $Excel = $Excel | Save-Excel -Passthru
            
            $Excel -is [OfficeOpenXml.ExcelPackage] | Should Be $True 

            [void]$Excel.Workbook.Worksheets.Add(2)
            @($Excel.Workbook.Worksheets).count | Should be 2
            $Excel | Save-Excel

            $Excel = New-Excel -Path $NewXLSXFile
            @($Excel.Workbook.Worksheets).count | Should be 2
            
            Remove-Item "$NewXLSXFile" -Force -ErrorAction SilentlyContinue
        }
    }
}


# Describe "Format-Cell PS$PSVersion" {}
# Describe "Get-Workbook PS$PSVersion" {}
Describe "Get-Worksheet PS$PSVersion" {

 Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'Should return a worksheet' {
         
            $Excel = New-Excel -Path $ExistingXLSXFile
            $WorkSheet = $Excel | Get-Worksheet
            $WorkSheet -is [OfficeOpenXml.ExcelWorksheet] | Should Be $True
            $WorkSheet.Name | Should Be 'WorkSheet1'

        }
    }

}

Describe "Search-CellValue PS$PSVersion" {

    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'Should find cells' {
            
            $Result = @( Search-CellValue -Path $ExistingXLSXFile -FilterScript {$_ -eq "Prop2" -or ($_ -is [datetime] -and $_.day -like 7)} )
            $Result.Count | Should be 2
            $Result[0].Row | Should be 3
            $Result[0].Match | Should be 'Prop2'

        }

        It 'Should return raw when specified' {
            $Result = @( Search-CellValue -Path $ExistingXLSXFile -FilterScript {$_ -eq 'Prop3'} -as Raw )
            $Result.count | Should be 1
            $Result[0] -is [string] | Should be $True
        }

        It 'Should return ExcelRange if specified' {
            $Result = @( Search-CellValue -Path $ExistingXLSXFile -FilterScript {$_ -is [string]} -as Passthru )
            $Result.count | Should be 13
            $Result[0] -is [OfficeOpenXml.ExcelRangeBase] | Should be $True
        }
    }
}

Remove-Item $NewXLSXFile -force -ErrorAction SilentlyContinue
Remove-Item $ExistingXLSXFile -force -ErrorAction SilentlyContinue