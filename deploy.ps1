param(
    [Parameter(Mandatory=$false)]
    [string]$VersionIncrement = "patch",
    
    [Parameter(Mandatory=$false)]
    [string]$CommitMessage = "New version release"
)

# Script to automate deployment of new versions of the LossPunishment addon
Write-Host "LossPunishment Deployment Script" -ForegroundColor Green
Write-Host "---------------------------" -ForegroundColor Green

# Function to increment semantic version
function Increment-Version {
    param (
        [string]$Version,
        [string]$Type
    )
    
    $parts = $Version.Split('.')
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]
    
    switch ($Type) {
        "major" { 
            $major += 1
            $minor = 0
            $patch = 0
        }
        "minor" { 
            $minor += 1
            $patch = 0
        }
        "patch" { 
            $patch += 1
        }
        default {
            Write-Host "Invalid version increment type. Using 'patch' as default." -ForegroundColor Yellow
            $patch += 1
        }
    }
    
    return "$major.$minor.$patch"
}

# 1. Get current version from .toc file
$tocContent = Get-Content "LossPunishment.toc"
$versionLine = $tocContent | Where-Object { $_ -match "## Version:" }
$currentVersion = $versionLine -replace "## Version:", "" -replace " ", ""
Write-Host "Current version: $currentVersion" -ForegroundColor Cyan

# 2. Increment version based on parameter
$newVersion = Increment-Version -Version $currentVersion -Type $VersionIncrement
Write-Host "New version: $newVersion" -ForegroundColor Cyan

# 3. Update version in .toc file
$tocContent = $tocContent -replace "## Version: $currentVersion", "## Version: $newVersion"
Set-Content -Path "LossPunishment.toc" -Value $tocContent

# Update version in Core.lua
$coreLuaContent = Get-Content "Core.lua"
$coreLuaContent = $coreLuaContent -replace 'LP.Version = ".*"', "LP.Version = ""$newVersion""" 
Set-Content -Path "Core.lua" -Value $coreLuaContent
Write-Host "Updated version in Core.lua and .toc file" -ForegroundColor Cyan

# 4. Stage only the necessary files (not everything)
Write-Host "Staging specific addon files..." -ForegroundColor Yellow
git add LossPunishment.toc
git add Core.lua
git add UI.lua
git add Options.lua
# Add any other specific files that should be included in the release
# git add README.md
# git add LICENSE

# 5. Commit with message
$fullCommitMessage = "$CommitMessage (v$newVersion)"
Write-Host "Committing: $fullCommitMessage" -ForegroundColor Yellow
git commit -m $fullCommitMessage

# 6. Create tag
$tagName = "v$newVersion"
Write-Host "Creating tag: $tagName" -ForegroundColor Yellow
git tag -a $tagName -m "Version $newVersion"

# 7. Push to GitHub
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
git push origin main
git push origin $tagName

Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "Version $newVersion has been pushed to GitHub." -ForegroundColor Green
Write-Host "GitHub Actions will now create a release automatically." -ForegroundColor Green 