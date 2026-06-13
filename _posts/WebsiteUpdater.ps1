# --- Configuration ---
# Use the directory where this script file is physically located
$TargetDir = $PSScriptRoot

# Get current date details
$CurrentDate = Get-Date
$CurrentYearMonthStr = $CurrentDate.ToString("yyyy-MM")
$CurrentMonthFirst = Get-Date -Year $CurrentDate.Year -Month $CurrentDate.Month -Day 1

# --- 1. Handle Photo Files (Current Month Only) ---
Write-Host "Checking photo files..." -ForegroundColor Cyan

# Find the most recent photo file using the YYYY-MM pattern
$LatestPhotoFile = Get-ChildItem -Path $TargetDir -Filter "*-*-01-photo.html" | 
    Where-Object { $_.BaseName -match '^\d{4}-\d{2}-01-photo$' } | 
    Sort-Object Name -Descending | 
    Select-Object -First 1

if ($LatestPhotoFile) {
    $TargetPhotoName = "${CurrentYearMonthStr}-01-photo.html"
    $TargetPhotoPath = Join-Path $TargetDir $TargetPhotoName

    if (Test-Path $TargetPhotoPath) {
        Write-Host "Photo file for the current month already exists: $TargetPhotoName" -ForegroundColor Yellow
    } else {
        # Extract the old YYYY-MM string from the template filename to find/replace it inside the content
        $OldYearMonthStr = $LatestPhotoFile.Name.Substring(0, 7)

        # Copy content from the most recent file found
        Copy-Item -Path $LatestPhotoFile.FullName -Destination $TargetPhotoPath
        Write-Host "Created $TargetPhotoName (copied from $($LatestPhotoFile.Name))" -ForegroundColor Green

        # Read the file content, update the date string (e.g., 2026-04.jpg -> 2026-06.jpg), and save it back
        # Uses UTF8 encoding to prevent formatting corruption
        $Content = Get-Content -Path $TargetPhotoPath -Raw
        $UpdatedContent = $Content -replace [regex]::Escape($OldYearMonthStr), $CurrentYearMonthStr
        Set-Content -Path $TargetPhotoPath -Value $UpdatedContent -Encoding UTF8
        Write-Host "Updated date strings inside $TargetPhotoName from '$OldYearMonthStr' to '$CurrentYearMonthStr'" -ForegroundColor DarkGreen
    }
} else {
    Write-Host "No recent photo files found in this directory. Doing nothing." -ForegroundColor Gray
}

# --- 2. Handle Meeting Files (Backfill Gap to Current Month) ---
Write-Host "`nChecking meeting files..." -ForegroundColor Cyan

# Find the most recent meeting file
$LatestMeetingFile = Get-ChildItem -Path $TargetDir -Filter "*-*-01-meeting.md" | 
    Where-Object { $_.BaseName -match '^\d{4}-\d{2}-01-meeting$' } | 
    Sort-Object Name -Descending | 
    Select-Object -First 1

if ($LatestMeetingFile) {
    # Extract the year and month from the filename (first 7 characters: YYYY-MM)
    $LatestMeetingStr = $LatestMeetingFile.Name.Substring(0, 7)
    $LatestMeetingDate = [datetime]::ParseExact($LatestMeetingStr, "yyyy-MM", $null)
    
    # Start iterating from the month *after* the most recent file
    $LoopDate = $LatestMeetingDate.AddMonths(1)
    
    # Loop through every month up to and including the current month
    while ($LoopDate -le $CurrentMonthFirst) {
        $LoopYearMonthStr = $LoopDate.ToString("yyyy-MM")
        $TargetMeetingName = "${LoopYearMonthStr}-01-meeting.md"
        $TargetMeetingPath = Join-Path $TargetDir $TargetMeetingName
        
        if (-not (Test-Path $TargetMeetingPath)) {
            Copy-Item -Path $LatestMeetingFile.FullName -Destination $TargetMeetingPath
            Write-Host "Backfilled missing file: $TargetMeetingName (copied from $($LatestMeetingFile.Name))" -ForegroundColor Green
        } else {
            Write-Host "File already exists: $TargetMeetingName" -ForegroundColor Yellow
        }
        
        # Move to the next month
        $LoopDate = $LoopDate.AddMonths(1)
    }
} else {
    Write-Host "No recent meeting files found in this directory. Doing nothing." -ForegroundColor Gray
}