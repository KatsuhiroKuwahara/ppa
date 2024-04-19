. $PSScriptRoot\..\Core.ps1
. $PSScriptRoot\..\TableOperations.ps1
. $PSScriptRoot\..\CommonFunctions.ps1
. $PSScriptRoot\MetadataOperations.ps1

# Change this to the URL of your Dataverse environment
Connect 'https://yourorg.crm.dynamics.com/' 

# Change this if you want to keep the records created by this sample
$deleteCreatedRecords = $true 
$recordsToDelete = @()
$publisherId = $null
$languageCode = 1033

Invoke-DataverseCommands { 

   #region Section 0: Create Publisher and Solution

   $publisherData = @{
      'uniquename'                     = 'examplepublisher'
      'friendlyname'                   = 'Example Publisher'
      'description'                    = 'An example publisher for samples'
      'customizationprefix'            = 'sample'
      'customizationoptionvalueprefix' = 72700
   } 

   # Check if the publisher already exists
   $publisherQuery = "?`$filter=uniquename eq "
   $publisherQuery += "'$($publisherData.uniquename)' "
   $publisherQuery += "and customizationprefix eq "
   $publisherQuery += "'$($publisherData.customizationprefix)' "
   $publisherQuery += "and customizationoptionvalueprefix eq "
   $publisherQuery += "$($publisherData.customizationoptionvalueprefix)"
   $publisherQuery += "&`$select=friendlyname"

   $publisherQueryResults = (Get-Records `
         -setName 'publishers' `
         -query $publisherQuery).value
   
   if ($publisherQueryResults.Length -eq 0) {
      # Create the publisher if it doesn't exist
      $publisherId = New-Record `
         -setName 'publishers' `
         -body $publisherData
      
      Write-Host 'Example Publisher created successfully'
      $publisherRecordToDelete = @{ 
         'setName' = 'publishers'
         'id'      = $publisherId 
      }
      $recordsToDelete += $publisherRecordToDelete

   }
   else {
      # Example Publisher already exists
      Write-Host "$($publisherQueryResults[0].friendlyname) already exists"
      $publisherId = $publisherQueryResults[0].publisherid
   }

   $solutionData = @{
      'uniquename'             = 'metadataexamplesolution'
      'friendlyname'           = 'Metadata Example Solution'
      'description'            = 'An example solution for metadata samples'
      'version'                = '1.0.0.0'
      'publisherid@odata.bind' = "/publishers($publisherId)"
   }

   # Check if the solution already exists
   $solutionQuery = "?`$filter=uniquename eq "
   $solutionQuery += "'$($solutionData.uniquename)' "
   $solutionQuery += "and _publisherid_value eq $publisherId"
   $solutionQuery += "&`$select=friendlyname"

   $solutionQueryResults = (Get-Records `
         -setName 'solutions' `
         -query $solutionQuery).value
   
   if ($solutionQueryResults.Length -eq 0) {
      # Create the solution if it doesn't exist
      $solutionId = New-Record `
         -setName 'solutions' `
         -body $solutionData
      
      Write-Host 'Example Solution created successfully'
      # Must be deleted before publisher, so add it to the beginning of the array
      $solutionRecordToDelete = @{ 
         'setName' = 'solutions'
         'id'      = $solutionId 
      }
      $recordsToDelete += $solutionRecordToDelete
   }
   else {
      # Example Solution already exists
      Write-Host "$($solutionQueryResults[0].friendlyname) already exists"
      $solutionId = $solutionQueryResults[0].solutionid
   }
   #endregion Section 0: Create Publisher and Solution

   #region Section 1: Create, Retrieve and Update Table
   
   # Definition of new 'sample_BankAccount' table to create
   $bankAccountTableData = @{
      '@odata.type'           = "Microsoft.Dynamics.CRM.EntityMetadata"
      'SchemaName'            = "$($publisherData.customizationprefix)_BankAccount"
      'DisplayName'           = @{
         '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
         'LocalizedLabels' = @(
            @{
               '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
               'Label'        = 'Bank Account'
               'LanguageCode' = $languageCode
            }
         )
      }
      'DisplayCollectionName' = @{
         '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
         'LocalizedLabels' = @(
            @{
               '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
               'Label'        = 'Bank Accounts'
               'LanguageCode' = $languageCode
            }
         )
      }
      'Description'           = @{
         '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
         'LocalizedLabels' = @(
            @{
               '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
               'Label'        = 'A table to store information about customer bank accounts'
               'LanguageCode' = $languageCode
            }
         )
      }
      'HasActivities'         = $false
      'HasNotes'              = $false
      'OwnershipType'         = 'UserOwned'
      'PrimaryNameAttribute'  = "$($publisherData.customizationprefix)_name"
      'Attributes'            = @(
         @{
            '@odata.type'   = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
            'IsPrimaryName' = $true
            'SchemaName'    = "$($publisherData.customizationprefix)_Name"
            'RequiredLevel' = @{
               'Value' = 'ApplicationRequired'
            }
            'DisplayName'   = @{
               '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
               'LocalizedLabels' = @(
                  @{
                     '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
                     'Label'        = 'Name'
                     'LanguageCode' = $languageCode
                  }
               )
            }
            'Description'   = @{
               '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
               'LocalizedLabels' = @(
                  @{
                     '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
                     'Label'        = 'The name of the bank account'
                     'LanguageCode' = $languageCode
                  }
               )
            }
            'MaxLength'     = 100
         }
      )
   }

   # Check if the table already exists
   $tableQuery = "?`$filter=SchemaName eq "
   $tableQuery += "'$($bankAccountTableData.SchemaName)' "
   $tableQuery += "&`$select=SchemaName,DisplayName"
   
   $tableQueryResults = (Get-Tables `
         -query $tableQuery).value

   if ($tableQueryResults.Length -eq 0) {
      # Create the table if it doesn't exist
      $tableId = New-Table `
         -body $bankAccountTableData `
         -solutionUniqueName $solutionData.uniquename
            
      Write-Host 'Example Table created successfully'
      $tableToDelete = @{ 
         'setName' = 'EntityDefinitions'
         'id'      = $tableId 
      }
      $recordsToDelete += $tableToDelete
   }
   else {
      # Example table already exists
      Write-Host "$($tableQueryResults[0].DisplayName.UserLocalizedLabel.Label) table already exists"
      $tableId = $tableQueryResults[0].MetadataId
   }

   # Retrieve the table to update it
   $table = Get-Table `
      -logicalName ($bankAccountTableData.SchemaName.ToLower())

   Write-Host "Retrieved $($table.DisplayName.UserLocalizedLabel.Label) table."

   # Update the table
   $table.HasActivities = $true
   $table.Description = @{
      '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
      'LocalizedLabels' = @(
         @{
            '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
            'Label'        = 'Contains information about customer bank accounts'
            'LanguageCode' = $languageCode
         }
      )
   }
   # Send the request to update the table
   # TODO: Uncomment this later...
   # Update-Table `
   #    -table $table `
   #    -solutionUniqueName $solutionData.uniquename `
   #    -mergeLabels $true

   # Write-Host "$($table.DisplayName.UserLocalizedLabel.Label) table updated successfully"

   #endregion Section 1: Create, Retrieve and Update Table

   #region Section 2: Create, Retrieve and Update Columns

   $tableAttributesPath = "EntityDefinitions(LogicalName='"
   $tableAttributesPath += "$($bankAccountTableData.SchemaName.ToLower())')"
   $tableAttributesPath += "/Attributes"

   #region Boolean

   $boolColumnData = @{
      '@odata.type'   = 'Microsoft.Dynamics.CRM.BooleanAttributeMetadata'
      'SchemaName'    = "$($publisherData.customizationprefix)_Boolean"
      'DefaultValue'  = $false
      'RequiredLevel' = @{
         'Value' = 'None'
      }
      'DisplayName'   = @{
         '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
         'LocalizedLabels' = @(
            @{
               '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
               'Label'        = 'Sample Boolean'
               'LanguageCode' = $languageCode
            }
         )
      }
      'Description'   = @{
         '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
         'LocalizedLabels' = @(
            @{
               '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
               'Label'        = 'Sample Boolean column description'
               'LanguageCode' = $languageCode
            }
         )
      }
      'OptionSet'     = @{
         '@odata.type' = 'Microsoft.Dynamics.CRM.BooleanOptionSetMetadata'
         'TrueOption'  = @{
            'Value' = 1
            'Label' = @{
               '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
               'LocalizedLabels' = @(
                  @{
                     '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
                     'Label'        = 'True'
                     'LanguageCode' = $languageCode
                  }
               )
            }
         }
         'FalseOption' = @{
            'Value' = 0
            'Label' = @{
               '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
               'LocalizedLabels' = @(
                  @{
                     '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
                     'Label'        = 'False'
                     'LanguageCode' = $languageCode
                  }
               )
            }
         }
      }
   }

   # Check if the column already exists
   $boolColumnQuery = "?`$filter=SchemaName eq "
   $boolColumnQuery += "'$($boolColumnData.SchemaName)'"
   $boolColumnQuery += "&`$select=SchemaName,DisplayName"
   
   $boolColumnQueryResults = (Get-TableColumns `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -query $boolColumnQuery).value

   if ($boolColumnQueryResults.Length -eq 0) {
      # Create the column if it doesn't exist
      $boolColumnId = New-Column `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -column $boolColumnData `
         -solutionUniqueName $solutionData.uniquename
            
      Write-Host 'Example Boolean column created successfully'



      $boolColumnToDelete = @{ 
         'setName' = $tableAttributesPath
         'id'      = $boolColumnId 
      }
      $recordsToDelete += $boolColumnToDelete
   }
   else {
      # Example bool column already exists
      Write-Host "$($boolColumnQueryResults[0].DisplayName.UserLocalizedLabel.Label) table already exists"
      $boolColumnId = $boolColumnQueryResults[0].MetadataId
   }

   $retrievedBooleanColumn1 = Get-Column `
      -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
      -logicalName ($boolColumnData.SchemaName.ToLower()) `
      -type 'Boolean' `
      -query "?`$expand=OptionSet" # So options will be returned

   $trueOption = $retrievedBooleanColumn1.OptionSet.TrueOption;
   $falseOption = $retrievedBooleanColumn1.OptionSet.FalseOption;
   
   Write-Host "Original Option Labels:"
   Write-Host " True Option Label: $($trueOption.Label.UserLocalizedLabel.Label)"
   Write-Host " False Option Label: $($falseOption.Label.UserLocalizedLabel.Label)"

   # Update the column
   $retrievedBooleanColumn1.DisplayName = @{
      '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
      'LocalizedLabels' = @(
         @{
            '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
            'Label'        = 'Sample Boolean Column Updated'
            'LanguageCode' = $languageCode
         }
      )
   }
   $retrievedBooleanColumn1.Description = @{
      '@odata.type'     = 'Microsoft.Dynamics.CRM.Label'
      'LocalizedLabels' = @(
         @{
            '@odata.type'  = 'Microsoft.Dynamics.CRM.LocalizedLabel'
            'Label'        = 'Sample Boolean column description updated'
            'LanguageCode' = $languageCode
         }
      )
   }
   $retrievedBooleanColumn1.RequiredLevel = @{
      'Value' = 'ApplicationRequired'
   }

   Update-Column `
      -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
      -column $retrievedBooleanColumn1 `
      -type 'Boolean' `
      -solutionUniqueName $solutionData.uniquename `
      -mergeLabels $true

   Write-Host "Sample Boolean Column updated successfully"

   #region Update option values

   # Update the True Option Label
   Update-OptionValue `
      -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
      -columnLogicalName ($boolColumnData.SchemaName.ToLower()) `
      -value 1 `
      -label 'Up' `
      -languageCode $languageCode `
      -solutionUniqueName ($solutionData.uniquename) `
      -mergeLabels $true
   
   # Update the False Option Label
   Update-OptionValue `
      -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
      -columnLogicalName ($boolColumnData.SchemaName.ToLower()) `
      -value 0 `
      -label 'Down' `
      -languageCode $languageCode `
      -solutionUniqueName ($solutionData.uniquename) `
      -mergeLabels $true

   Write-Host "Option values updated successfully"

   $retrievedBooleanColumn2 = Get-Column `
      -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
      -logicalName ($boolColumnData.SchemaName.ToLower()) `
      -type 'Boolean' `
      -query "?`$expand=OptionSet" # So options will be returned

   $trueOption = $retrievedBooleanColumn2.OptionSet.TrueOption;
   $falseOption = $retrievedBooleanColumn2.OptionSet.FalseOption;
   
   Write-Host "Updated Option Labels:"
   Write-Host " True Option Label: $($trueOption.Label.UserLocalizedLabel.Label)"
   Write-Host " False Option Label: $($falseOption.Label.UserLocalizedLabel.Label)"

   #endregion Update option values

   #endregion Boolean

   #region DateTime
   $dateTimeColumnData = @{
      '@odata.type'    = 'Microsoft.Dynamics.CRM.DateTimeAttributeMetadata'
      SchemaName       = "$($publisherData.customizationprefix)_DateTime"
      RequiredLevel    = @{
         Value = 'None'
      }
      DisplayName      = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample DateTime'
               LanguageCode = $languageCode
            }
         )
      }
      Description      = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample DateTime column description'
               LanguageCode = $languageCode
            }
         )
      }
      DateTimeBehavior = @{
         Value = 'DateOnly'
      }
      Format           = 'DateOnly'
      ImeMode          = 'Disabled'
   }

   # Check if the column already exists
   $dateTimeColumnQuery = "?`$filter=SchemaName eq "
   $dateTimeColumnQuery += "'$($dateTimeColumnData.SchemaName)'"
   $dateTimeColumnQuery += "&`$select=SchemaName,DisplayName"
   
   $dateTimeColumnQueryResults = (Get-TableColumns `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -query $dateTimeColumnQuery).value

   if ($dateTimeColumnQueryResults.Length -eq 0) {
      # Create the column if it doesn't exist
      $dateTimeColumnId = New-Column `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -column $dateTimeColumnData `
         -solutionUniqueName $solutionData.uniquename
            
      Write-Host 'Example DateTime column created successfully'

      $dateTimeColumnToDelete = @{ 
         'setName' = $tableAttributesPath
         'id'      = $dateTimeColumnId 
      }
      $recordsToDelete += $dateTimeColumnToDelete
   }
   else {
      # Example DateTime column already exists
      Write-Host "$($dateTimeColumnQueryResults[0].DisplayName.UserLocalizedLabel.Label) table already exists"
      $dateTimeColumnId = $dateTimeColumnQueryResults[0].MetadataId
   }

   # Retrieve the dateTime column
   $dateTimeColumn = Get-Column `
      -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
      -logicalName ($dateTimeColumnData.SchemaName.ToLower()) `
      -type 'DateTime' `
      -query "?`$select=SchemaName,DisplayName,DateTimeBehavior,Format,ImeMode"
   
   Write-Host "Retrieved $($dateTimeColumn.DisplayName.UserLocalizedLabel.Label) column."
   Write-Host " DateTimeBehavior: $($dateTimeColumn.DateTimeBehavior.Value)"
   Write-Host " Format: $($dateTimeColumn.Format)"

   #endregion DateTime

   #region Decimal
   $decimalColumnData = @{
      '@odata.type' = 'Microsoft.Dynamics.CRM.DecimalAttributeMetadata'
      SchemaName    = "$($publisherData.customizationprefix)_Decimal"
      RequiredLevel = @{
         Value = 'None'
      }
      DisplayName   = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample Decimal'
               LanguageCode = $languageCode
            }
         )
      }
      Description   = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample Decimal column description'
               LanguageCode = $languageCode
            }
         )
      }
      MaxValue      = 100
      MinValue      = 0
      Precision     = 1
   }

   # Check if the column already exists
   $decimalColumnQuery = "?`$filter=SchemaName eq "
   $decimalColumnQuery += "'$($decimalColumnData.SchemaName)'"
   $decimalColumnQuery += "&`$select=SchemaName,DisplayName"

   $decimalColumnQueryResults = (Get-TableColumns `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -query $decimalColumnQuery).value

   if ($decimalColumnQueryResults.Length -eq 0) {
      # Create the column if it doesn't exist
      $decimalColumnId = New-Column `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -column $decimalColumnData `
         -solutionUniqueName $solutionData.uniquename
            
      Write-Host 'Example Decimal column created successfully'

      $decimalColumnToDelete = @{ 
         'setName' = $tableAttributesPath
         'id'      = $decimalColumnId 
      }
      $recordsToDelete += $decimalColumnToDelete
   }
   else {
      # Example Decimal column already exists
      Write-Host "$($decimalColumnQueryResults[0].DisplayName.UserLocalizedLabel.Label) table already exists"
      $decimalColumnId = $decimalColumnQueryResults[0].MetadataId
   }

   # Retrieve the decimal column
   $decimalColumn = Get-Column `
      -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
      -logicalName ($decimalColumnData.SchemaName.ToLower()) `
      -type 'Decimal' `
      -query "?`$select=SchemaName,DisplayName,MaxValue,MinValue,Precision"

   Write-Host "Retrieved $($decimalColumn.DisplayName.UserLocalizedLabel.Label) column."
   Write-Host " MaxValue: $($decimalColumn.MaxValue)"
   Write-Host " MinValue: $($decimalColumn.MinValue)"
   Write-Host " Precision: $($decimalColumn.Precision)"

   #endregion Decimal

   #region Integer
   $integerColumnData = @{
      '@odata.type' = 'Microsoft.Dynamics.CRM.IntegerAttributeMetadata'
      SchemaName    = "$($publisherData.customizationprefix)_Integer"
      RequiredLevel = @{
         Value = 'None'
      }
      DisplayName   = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample Integer'
               LanguageCode = $languageCode
            }
         )
      }
      Description   = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample Integer column description'
               LanguageCode = $languageCode
            }
         )
      }
      MaxValue      = 100
      MinValue      = 0
      Format        = 'None'
   }

   # Check if the column already exists
   $integerColumnQuery = "?`$filter=SchemaName eq "
   $integerColumnQuery += "'$($integerColumnData.SchemaName)'"
   $integerColumnQuery += "&`$select=SchemaName,DisplayName"

   $integerColumnQueryResults = (Get-TableColumns `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -query $integerColumnQuery).value
   
   if ($integerColumnQueryResults.Length -eq 0) {
      # Create the column if it doesn't exist
      $integerColumnId = New-Column `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -column $integerColumnData `
         -solutionUniqueName $solutionData.uniquename
            
      Write-Host 'Example Integer column created successfully'

      $integerColumnToDelete = @{ 
         'setName' = $tableAttributesPath
         'id'      = $integerColumnId 
      }
      $recordsToDelete += $integerColumnToDelete
   }
   else {
      # Example Integer column already exists
      Write-Host "$($integerColumnQueryResults[0].DisplayName.UserLocalizedLabel.Label) table already exists"
      $integerColumnId = $integerColumnQueryResults[0].MetadataId
   }

   # Retrieve the integer column
   $integerColumn = Get-Column `
      -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
      -logicalName ($integerColumnData.SchemaName.ToLower()) `
      -type 'Integer' `
      -query "?`$select=SchemaName,DisplayName,MaxValue,MinValue,Format"
   
   Write-Host "Retrieved $($integerColumn.DisplayName.UserLocalizedLabel.Label) column."
   Write-Host " MaxValue: $($integerColumn.MaxValue)"
   Write-Host " MinValue: $($integerColumn.MinValue)"
   Write-Host " Format: $($integerColumn.Format)"

   #endregion Integer

   #region Memo

   $memoColumnData = @{
      '@odata.type' = 'Microsoft.Dynamics.CRM.MemoAttributeMetadata'
      SchemaName    = "$($publisherData.customizationprefix)_Memo"
      RequiredLevel = @{
         Value = 'None'
      }
      DisplayName   = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample Memo'
               LanguageCode = $languageCode
            }
         )
      }
      Description   = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample Memo column description'
               LanguageCode = $languageCode
            }
         )
      }
      Format        = 'Text'
      ImeMode       = 'Disabled'
      MaxLength     = 500
   }

   # Check if the column already exists
   $memoColumnQuery = "?`$filter=SchemaName eq "
   $memoColumnQuery += "'$($memoColumnData.SchemaName)'"
   $memoColumnQuery += "&`$select=SchemaName,DisplayName"

   $memoColumnQueryResults = (Get-TableColumns `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -query $memoColumnQuery).value

   if ($memoColumnQueryResults.Length -eq 0) {
      # Create the column if it doesn't exist
      $memoColumnId = New-Column `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -column $memoColumnData `
         -solutionUniqueName $solutionData.uniquename
            
      Write-Host 'Example Memo column created successfully'

      $memoColumnToDelete = @{ 
         'setName' = $tableAttributesPath
         'id'      = $memoColumnId 
      }
      $recordsToDelete += $memoColumnToDelete
   }
   else {
      # Example Memo column already exists
      Write-Host "$($memoColumnQueryResults[0].DisplayName.UserLocalizedLabel.Label) table already exists"
      $memoColumnId = $memoColumnQueryResults[0].MetadataId
   }

   # Retrieve the memo column
   $memoColumn = Get-Column `
      -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
      -logicalName ($memoColumnData.SchemaName.ToLower()) `
      -type 'Memo' `
      -query "?`$select=SchemaName,DisplayName,Format,ImeMode,MaxLength"

   Write-Host "Retrieved $($memoColumn.DisplayName.UserLocalizedLabel.Label) column."
   Write-Host " Format: $($memoColumn.Format)"
   Write-Host " ImeMode: $($memoColumn.ImeMode)"
   Write-Host " MaxLength: $($memoColumn.MaxLength)"

   #endregion Memo

   #region Money

   $moneyColumnData = @{
      '@odata.type'   = 'Microsoft.Dynamics.CRM.MoneyAttributeMetadata'
      SchemaName      = "$($publisherData.customizationprefix)_Money"
      RequiredLevel   = @{
         Value = 'None'
      }
      DisplayName     = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample Money'
               LanguageCode = $languageCode
            }
         )
      }
      Description     = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample Money column description'
               LanguageCode = $languageCode
            }
         )
      }
      MaxValue        = 1000.00
      MinValue        = 0.00
      Precision       = 1
      PrecisionSource = 1
      ImeMode         = 'Disabled'
   }

   # Check if the column already exists
   $moneyColumnQuery = "?`$filter=SchemaName eq "
   $moneyColumnQuery += "'$($moneyColumnData.SchemaName)'"
   $moneyColumnQuery += "&`$select=SchemaName,DisplayName"

   $moneyColumnQueryResults = (Get-TableColumns `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -query $moneyColumnQuery).value

   if ($moneyColumnQueryResults.Length -eq 0) {
      # Create the column if it doesn't exist
      $moneyColumnId = New-Column `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -column $moneyColumnData `
         -solutionUniqueName $solutionData.uniquename
            
      Write-Host 'Example Money column created successfully'

      $moneyColumnToDelete = @{ 
         'setName' = $tableAttributesPath
         'id'      = $moneyColumnId 
      }
      $recordsToDelete += $moneyColumnToDelete
   }
   else {
      # Example Money column already exists
      Write-Host "$($moneyColumnQueryResults[0].DisplayName.UserLocalizedLabel.Label) table already exists"
      $moneyColumnId = $moneyColumnQueryResults[0].MetadataId
   }

   # Retrieve the money column
   $moneyColumn = Get-Column `
      -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
      -logicalName ($moneyColumnData.SchemaName.ToLower()) `
      -type 'Money' `
      -query "?`$select=SchemaName,DisplayName,MaxValue,MinValue,Precision,PrecisionSource,ImeMode"

   Write-Host "Retrieved $($moneyColumn.DisplayName.UserLocalizedLabel.Label) column."
   Write-Host " MaxValue: $($moneyColumn.MaxValue)"
   Write-Host " MinValue: $($moneyColumn.MinValue)"
   Write-Host " Precision: $($moneyColumn.Precision)"
   Write-Host " PrecisionSource: $($moneyColumn.PrecisionSource)"
   Write-Host " ImeMode: $($moneyColumn.ImeMode)"


   #endregion Money

   #region Picklist

   $picklistColumnData = @{
      '@odata.type' = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
      SchemaName    = "$($publisherData.customizationprefix)_Picklist"
      RequiredLevel = @{
         Value = 'None'
      }
      DisplayName   = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample Choice'
               LanguageCode = $languageCode
            }
         )
      }
      Description   = @{
         LocalizedLabels = @(
            @{
               Label        = 'Sample Choice column description'
               LanguageCode = $languageCode
            }
         )
      }
      OptionSet     = @{
         '@odata.type' = 'Microsoft.Dynamics.CRM.OptionSetMetadata'
         OptionSetType = 'Picklist'
         IsGlobal      = $false
         Options       = @(
            @{
               '@odata.type' = 'Microsoft.Dynamics.CRM.OptionMetadata'
               Label         = @{
                  LocalizedLabels = @(
                     @{
                        Label        = 'Bravo'
                        LanguageCode = $languageCode
                     }
                  )
               }
               Value         = [int]$publisherData.customizationoptionvalueprefix + '0000'
            },
            @{
               '@odata.type' = 'Microsoft.Dynamics.CRM.OptionMetadata'
               Label         = @{
                  LocalizedLabels = @(
                     @{
                        Label        = 'Delta'
                        LanguageCode = $languageCode
                     }
                  )
               }
               Value         = [int]$publisherData.customizationoptionvalueprefix + '0001'
            },
            @{
               '@odata.type' = 'Microsoft.Dynamics.CRM.OptionMetadata'
               Label         = @{
                  LocalizedLabels = @(
                     @{
                        Label        = 'Alpha'
                        LanguageCode = $languageCode
                     }
                  )
               }
               Value         = [int]$publisherData.customizationoptionvalueprefix + '0002'
            },
            @{
               '@odata.type' = 'Microsoft.Dynamics.CRM.OptionMetadata'
               Label         = @{
                  LocalizedLabels = @(
                     @{
                        Label        = 'Charlie'
                        LanguageCode = $languageCode
                     }
                  )
               }
               Value         = [int]$publisherData.customizationoptionvalueprefix + '0003'
            },
            @{
               '@odata.type' = 'Microsoft.Dynamics.CRM.OptionMetadata'
               Label         = @{
                  LocalizedLabels = @(
                     @{
                        Label        = 'Foxtrot'
                        LanguageCode = $languageCode
                     }
                  )
               }
               Value         = [int]$publisherData.customizationoptionvalueprefix + '0004'
            }
         )
      }
   }

   # Check if the column already exists
   $picklistColumnQuery = "?`$filter=SchemaName eq "
   $picklistColumnQuery += "'$($picklistColumnData.SchemaName)'"
   $picklistColumnQuery += "&`$select=SchemaName,DisplayName"

   $picklistColumnQueryResults = (Get-TableColumns `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -query $picklistColumnQuery).value

   if ($picklistColumnQueryResults.Length -eq 0) {
      # Create the column if it doesn't exist
      $picklistColumnId = New-Column `
         -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
         -column $picklistColumnData `
         -solutionUniqueName $solutionData.uniquename
            
      Write-Host 'Example Picklist column created successfully'

      $picklistColumnToDelete = @{ 
         'setName' = $tableAttributesPath
         'id'      = $picklistColumnId 
      }
      $recordsToDelete += $picklistColumnToDelete
   }
   else {
      # Example Picklist column already exists
      Write-Host "$($picklistColumnQueryResults[0].DisplayName.UserLocalizedLabel.Label) table already exists"
      $picklistColumnId = $picklistColumnQueryResults[0].MetadataId
   }

   # Retrieve the picklist column
   $picklistColumn = Get-Column `
      -tableLogicalName ($bankAccountTableData.SchemaName.ToLower()) `
      -logicalName ($picklistColumnData.SchemaName.ToLower()) `
      -type 'Picklist' `
      -query "?`$select=SchemaName,DisplayName&`$expand=OptionSet"

   Write-Host "Retrieved $($picklistColumn.DisplayName.UserLocalizedLabel.Label) column."

   Write-Host 'Retrieved Choice column options:'
   foreach ($option in $picklistColumn.OptionSet.Options) {
      Write-Host " Label: $($option.Label.UserLocalizedLabel.Label)"
      Write-Host " Value: $($option.Value)"
   }


   #endregion Picklist


   #endregion Section 2: Create, Retrieve and Update Columns

   #region Section 3: Create and use Global OptionSet
   #endregion Section 3: Create and use Global OptionSet

   #region Section 4: Create Customer Relationship
   #endregion Section 4: Create Customer Relationship

   #region Section 5: Create and retrieve a one-to-many relationship
   #endregion Section 5: Create and retrieve a one-to-many relationship

   #region Section 6: Create and retrieve a many-to-one relationship
   #endregion Section 6: Create and retrieve a many-to-one relationship

   #region Section 7: Create and retrieve a many-to-many relationship
   #endregion Section 7: Create and retrieve a many-to-many relationship

   #region Section 8: Export managed solution
   #endregion Section 8: Export managed solution

   #region Section 9: Delete sample records
   if ($deleteCreatedRecords) {
      Write-Host 'Deleting sample records...'

      # In the reverse order of creation, delete the records created by this sample
      for ($i = $recordsToDelete.Length - 1; $i -ge 0; $i--) {
         $recordToDelete = $recordsToDelete[$i]
         Remove-Record -setName $recordToDelete.setName -id $recordToDelete.id | Out-Null
         Write-Host "$($recordToDelete.setName) record with ID: $($recordToDelete.id) deleted"
      }
   }
   #endregion Section 9: Delete sample records

   #region Section 10: Import and Delete managed solution
   #endregion Section 10: Import and Delete managed solution

}