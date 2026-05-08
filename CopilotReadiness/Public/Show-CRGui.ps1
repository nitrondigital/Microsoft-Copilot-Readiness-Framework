function Show-CRGui {
    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        throw 'Show-CRGui is supported on Windows only.'
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Microsoft Copilot Readiness Assessment'
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(980, 788)
    $form.MinimumSize = New-Object System.Drawing.Size(960, 748)

    $defaultFont = New-Object System.Drawing.Font('Segoe UI', 9)
    $form.Font = $defaultFont

    $lblTenant = New-Object System.Windows.Forms.Label
    $lblTenant.Text = 'Tenant Admin URL (required)'
    $lblTenant.Location = New-Object System.Drawing.Point(20, 20)
    $lblTenant.AutoSize = $true
    $form.Controls.Add($lblTenant)

    $txtTenant = New-Object System.Windows.Forms.TextBox
    $txtTenant.Location = New-Object System.Drawing.Point(20, 42)
    $txtTenant.Size = New-Object System.Drawing.Size(610, 24)
    $txtTenant.Text = 'https://contoso-admin.sharepoint.com'
    $form.Controls.Add($txtTenant)

    $btnSignIn = New-Object System.Windows.Forms.Button
    $btnSignIn.Text = 'Sign In'
    $btnSignIn.Location = New-Object System.Drawing.Point(650, 40)
    $btnSignIn.Size = New-Object System.Drawing.Size(90, 28)
    $form.Controls.Add($btnSignIn)

    $btnDisconnect = New-Object System.Windows.Forms.Button
    $btnDisconnect.Text = 'Sign Out'
    $btnDisconnect.Location = New-Object System.Drawing.Point(750, 40)
    $btnDisconnect.Size = New-Object System.Drawing.Size(90, 28)
    $btnDisconnect.Enabled = $false
    $form.Controls.Add($btnDisconnect)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = 'Status: Not connected'
    $lblStatus.Location = New-Object System.Drawing.Point(20, 74)
    $lblStatus.Size = New-Object System.Drawing.Size(920, 22)
    $form.Controls.Add($lblStatus)

    $lblOutput = New-Object System.Windows.Forms.Label
    $lblOutput.Text = 'Output Folder'
    $lblOutput.Location = New-Object System.Drawing.Point(20, 104)
    $lblOutput.AutoSize = $true
    $form.Controls.Add($lblOutput)

    $txtOutput = New-Object System.Windows.Forms.TextBox
    $txtOutput.Location = New-Object System.Drawing.Point(20, 126)
    $txtOutput.Size = New-Object System.Drawing.Size(730, 24)
    $txtOutput.Text = (Join-Path -Path $env:USERPROFILE -ChildPath 'CopilotReadinessReports')
    $form.Controls.Add($txtOutput)

    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = 'Browse...'
    $btnBrowse.Location = New-Object System.Drawing.Point(760, 124)
    $btnBrowse.Size = New-Object System.Drawing.Size(80, 28)
    $form.Controls.Add($btnBrowse)

    $grpAssessments = New-Object System.Windows.Forms.GroupBox
    $grpAssessments.Text = 'Assessments'
    $grpAssessments.Location = New-Object System.Drawing.Point(20, 166)
    $grpAssessments.Size = New-Object System.Drawing.Size(920, 138)
    $form.Controls.Add($grpAssessments)

    $chkCA = New-Object System.Windows.Forms.CheckBox
    $chkCA.Text = 'Conditional Access Policies'
    $chkCA.Location = New-Object System.Drawing.Point(16, 28)
    $chkCA.Size = New-Object System.Drawing.Size(220, 24)
    $chkCA.Checked = $true
    $grpAssessments.Controls.Add($chkCA)

    $chkExternal = New-Object System.Windows.Forms.CheckBox
    $chkExternal.Text = 'External User Access'
    $chkExternal.Location = New-Object System.Drawing.Point(250, 28)
    $chkExternal.Size = New-Object System.Drawing.Size(180, 24)
    $chkExternal.Checked = $true
    $grpAssessments.Controls.Add($chkExternal)

    $chkLabels = New-Object System.Windows.Forms.CheckBox
    $chkLabels.Text = 'Sensitivity Label Coverage'
    $chkLabels.Location = New-Object System.Drawing.Point(16, 60)
    $chkLabels.Size = New-Object System.Drawing.Size(220, 24)
    $chkLabels.Checked = $true
    $grpAssessments.Controls.Add($chkLabels)

    $chkOvershared = New-Object System.Windows.Forms.CheckBox
    $chkOvershared.Text = 'Overshared Content'
    $chkOvershared.Location = New-Object System.Drawing.Point(250, 60)
    $chkOvershared.Size = New-Object System.Drawing.Size(180, 24)
    $chkOvershared.Checked = $true
    $grpAssessments.Controls.Add($chkOvershared)

    $chkIncludeOneDrive = New-Object System.Windows.Forms.CheckBox
    $chkIncludeOneDrive.Text = 'Include OneDrive'
    $chkIncludeOneDrive.Location = New-Object System.Drawing.Point(470, 28)
    $chkIncludeOneDrive.Size = New-Object System.Drawing.Size(150, 24)
    $grpAssessments.Controls.Add($chkIncludeOneDrive)

    $lblSample = New-Object System.Windows.Forms.Label
    $lblSample.Text = 'Sample size per drive (0 = full scan)'
    $lblSample.Location = New-Object System.Drawing.Point(470, 62)
    $lblSample.Size = New-Object System.Drawing.Size(220, 20)
    $grpAssessments.Controls.Add($lblSample)

    $numSampleSize = New-Object System.Windows.Forms.NumericUpDown
    $numSampleSize.Location = New-Object System.Drawing.Point(700, 60)
    $numSampleSize.Size = New-Object System.Drawing.Size(90, 24)
    $numSampleSize.Minimum = 0
    $numSampleSize.Maximum = 5000
    $numSampleSize.Value = 100
    $grpAssessments.Controls.Add($numSampleSize)

    $chkRetention = New-Object System.Windows.Forms.CheckBox
    $chkRetention.Text = 'Retention Labels & Policies'
    $chkRetention.Location = New-Object System.Drawing.Point(16, 88)
    $chkRetention.Size = New-Object System.Drawing.Size(220, 24)
    $chkRetention.Checked = $true
    $grpAssessments.Controls.Add($chkRetention)

    $btnRunSelected = New-Object System.Windows.Forms.Button
    $btnRunSelected.Text = 'Run Selected'
    $btnRunSelected.Location = New-Object System.Drawing.Point(20, 318)
    $btnRunSelected.Size = New-Object System.Drawing.Size(120, 32)
    $btnRunSelected.Enabled = $false
    $form.Controls.Add($btnRunSelected)

    $btnRunAll = New-Object System.Windows.Forms.Button
    $btnRunAll.Text = 'Run All'
    $btnRunAll.Location = New-Object System.Drawing.Point(150, 318)
    $btnRunAll.Size = New-Object System.Drawing.Size(100, 32)
    $btnRunAll.Enabled = $false
    $form.Controls.Add($btnRunAll)

    $btnGenerateReport = New-Object System.Windows.Forms.Button
    $btnGenerateReport.Text = 'Generate HTML Report'
    $btnGenerateReport.Location = New-Object System.Drawing.Point(270, 318)
    $btnGenerateReport.Size = New-Object System.Drawing.Size(170, 32)
    $btnGenerateReport.Enabled = $false
    $form.Controls.Add($btnGenerateReport)

    $btnOpenReport = New-Object System.Windows.Forms.Button
    $btnOpenReport.Text = 'Open Report'
    $btnOpenReport.Location = New-Object System.Drawing.Point(450, 318)
    $btnOpenReport.Size = New-Object System.Drawing.Size(110, 32)
    $btnOpenReport.Enabled = $false
    $form.Controls.Add($btnOpenReport)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 360)
    $progressBar.Size = New-Object System.Drawing.Size(920, 18)
    $progressBar.Style = 'Blocks'
    $form.Controls.Add($progressBar)

    $txtLog = New-Object System.Windows.Forms.TextBox
    $txtLog.Location = New-Object System.Drawing.Point(20, 386)
    $txtLog.Size = New-Object System.Drawing.Size(920, 338)
    $txtLog.Multiline = $true
    $txtLog.ScrollBars = 'Vertical'
    $txtLog.ReadOnly = $true
    $txtLog.Font = New-Object System.Drawing.Font('Consolas', 9)
    $form.Controls.Add($txtLog)

    $logQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    $script:CRLogSink = {
        param($line)
        $null = $logQueue.Enqueue($line)
    }

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 300
    $timer.Add_Tick({
        while ($true) {
            $nextLine = $null
            if (-not $logQueue.TryDequeue([ref]$nextLine)) {
                break
            }

            $txtLog.AppendText($nextLine + [Environment]::NewLine)
            $txtLog.SelectionStart = $txtLog.TextLength
            $txtLog.ScrollToCaret()
        }
    })
    $timer.Start()

    $isTenantUrlValid = {
        param([string]$TenantUrl)
        return [regex]::IsMatch($TenantUrl.Trim(), '^https://[a-z0-9-]+-admin\.sharepoint\.com/?$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    $updateControlState = {
        $tenantValid = & $isTenantUrlValid $txtTenant.Text
        $isConnected = $script:CRState.Connected -and ($script:CRState.TenantUrl -eq $txtTenant.Text.Trim().TrimEnd('/'))
        $hasSelection = $chkCA.Checked -or $chkExternal.Checked -or $chkLabels.Checked -or $chkOvershared.Checked -or $chkRetention.Checked

        $btnSignIn.Enabled = $tenantValid
        $btnDisconnect.Enabled = $isConnected
        $btnRunAll.Enabled = $tenantValid -and $isConnected
        $btnRunSelected.Enabled = $tenantValid -and $isConnected -and $hasSelection
        $btnGenerateReport.Enabled = $null -ne $script:CRLastResults
        $btnOpenReport.Enabled = -not [string]::IsNullOrWhiteSpace($script:CRLastReportPath) -and (Test-Path -Path $script:CRLastReportPath)
    }

    $runAssessments = {
        param([string[]]$AssessmentNames)

        if ($AssessmentNames.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Select at least one assessment.', 'Validation', 'OK', 'Warning') | Out-Null
            return
        }

        $outputPath = $txtOutput.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($outputPath)) {
            [System.Windows.Forms.MessageBox]::Show('Output folder is required.', 'Validation', 'OK', 'Warning') | Out-Null
            return
        }

        if (-not (Test-Path -Path $outputPath)) {
            $null = New-Item -ItemType Directory -Path $outputPath -Force
        }

        $progressBar.Style = 'Marquee'
        $form.UseWaitCursor = $true
        $btnRunAll.Enabled = $false
        $btnRunSelected.Enabled = $false
        $btnGenerateReport.Enabled = $false

        try {
            $results = Invoke-CRAssessment -Assessments $AssessmentNames -TenantUrl $txtTenant.Text.Trim() -OutputPath $outputPath -IncludeOneDrive:$chkIncludeOneDrive.Checked -SampleSize ([int]$numSampleSize.Value) -CheckCopilotApps
            $script:CRLastResults = $results
            [System.Windows.Forms.MessageBox]::Show('Assessment execution completed.', 'Copilot Readiness', 'OK', 'Information') | Out-Null
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Assessment execution failed: $($_.Exception.Message)", 'Copilot Readiness', 'OK', 'Error') | Out-Null
        }
        finally {
            $progressBar.Style = 'Blocks'
            $form.UseWaitCursor = $false
            & $updateControlState
        }
    }

    $btnBrowse.Add_Click({
        $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderDialog.SelectedPath = if (Test-Path -Path $txtOutput.Text) { $txtOutput.Text } else { [Environment]::GetFolderPath('Desktop') }

        if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtOutput.Text = $folderDialog.SelectedPath
        }

        & $updateControlState
    })

    $btnSignIn.Add_Click({
        if (-not (& $isTenantUrlValid $txtTenant.Text)) {
            [System.Windows.Forms.MessageBox]::Show('Tenant URL must be in the format https://<tenant>-admin.sharepoint.com', 'Validation', 'OK', 'Warning') | Out-Null
            return
        }

        try {
            # Connect to Graph and Exchange Online from the GUI thread.
            # Security & Compliance (Connect-IPPSSession) is intentionally excluded here:
            # its MSAL localhost OAuth callback deadlocks on the WinForms STA thread.
            # Get-CRRetentionAssessment handles S&C self-connection in a fresh STA runspace.
            $context = Connect-CRTenant -TenantUrl $txtTenant.Text.Trim() -Service Graph, ExchangeOnline
            $displayAs = if ([string]::IsNullOrWhiteSpace($context.ConnectedUser)) { $context.TenantId } else { $context.ConnectedUser }
            $lblStatus.Text = "Status: Connected as $displayAs to $($context.OrganizationName)"
        }
        catch {
            $lblStatus.Text = 'Status: Connection failed'
            [System.Windows.Forms.MessageBox]::Show("Sign-in failed: $($_.Exception.Message)", 'Authentication Error', 'OK', 'Error') | Out-Null
        }

        & $updateControlState
    })

    $btnDisconnect.Add_Click({
        Disconnect-CRTenant
        $lblStatus.Text = 'Status: Not connected'
        & $updateControlState
    })

    $btnRunSelected.Add_Click({
        $selectedAssessments = @()
        if ($chkCA.Checked) { $selectedAssessments += 'CAPolicies' }
        if ($chkExternal.Checked) { $selectedAssessments += 'ExternalUserAccess' }
        if ($chkLabels.Checked) { $selectedAssessments += 'LabelCoverage' }
        if ($chkOvershared.Checked) { $selectedAssessments += 'OversharedContent' }
        if ($chkRetention.Checked) { $selectedAssessments += 'RetentionLabels' }

        & $runAssessments $selectedAssessments
    })

    $btnRunAll.Add_Click({
        & $runAssessments @('CAPolicies', 'ExternalUserAccess', 'LabelCoverage', 'OversharedContent', 'RetentionLabels')
    })

    $btnGenerateReport.Add_Click({
        if ($null -eq $script:CRLastResults) {
            [System.Windows.Forms.MessageBox]::Show('Run at least one assessment first.', 'Validation', 'OK', 'Warning') | Out-Null
            return
        }

        try {
            $reportPath = New-CRReadinessReport -Results $script:CRLastResults -OutputPath $txtOutput.Text.Trim() -TenantUrl $txtTenant.Text.Trim()
            $script:CRLastReportPath = $reportPath
            [System.Windows.Forms.MessageBox]::Show("Report generated:`n$reportPath", 'Report Generated', 'OK', 'Information') | Out-Null
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to generate report: $($_.Exception.Message)", 'Report Error', 'OK', 'Error') | Out-Null
        }

        & $updateControlState
    })

    $btnOpenReport.Add_Click({
        if (-not [string]::IsNullOrWhiteSpace($script:CRLastReportPath) -and (Test-Path -Path $script:CRLastReportPath)) {
            Start-Process -FilePath $script:CRLastReportPath
        }
    })

    foreach ($control in @($txtTenant, $txtOutput, $chkCA, $chkExternal, $chkLabels, $chkOvershared, $chkRetention, $chkIncludeOneDrive)) {
        if ($control -is [System.Windows.Forms.TextBox]) {
            $control.Add_TextChanged({ & $updateControlState })
        }
        elseif ($control -is [System.Windows.Forms.CheckBox]) {
            $control.Add_CheckedChanged({ & $updateControlState })
        }
    }

    $form.Add_Shown({
        & $updateControlState
    })

    $form.Add_FormClosing({
        try {
            $timer.Stop()
            $script:CRLogSink = $null
            Disconnect-CRTenant
        }
        catch {
            # Ignore cleanup failures.
        }
    })

    $null = $form.ShowDialog()
}
