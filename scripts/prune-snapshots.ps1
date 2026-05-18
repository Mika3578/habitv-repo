#Requires -Version 7.0
<#
.SYNOPSIS
    Prune obsolete Maven timestamped SNAPSHOT artifacts from a static repository tree.

.DESCRIPTION
    Scans SNAPSHOT version directories under RepositoryRoot, keeps the latest N
    timestamped builds, and always preserves the build referenced by maven-metadata.xml.
    Protected files (metadata, index.html) are never deleted.

.PARAMETER RepositoryRoot
    Path to the Maven repository root (default: repository).

.PARAMETER Keep
    Number of latest timestamped SNAPSHOT builds to retain (default: 3, minimum: 1).

.PARAMETER DryRun
    List actions without deleting files. Omit this switch to perform deletions.
    Run with -DryRun first to review planned changes.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = 'repository',

    [Parameter()]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Keep = 3,

    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProtectedFileNames = @(
    'maven-metadata.xml',
    'maven-metadata.xml.md5',
    'maven-metadata.xml.sha1'
)

# artifact-{baseVersion}-{yyyyMMdd.HHmmss}-{buildNumber}[-{classifier}][.jar|.pom][.md5|.sha1]
$SnapshotArtifactRegex = [regex]::new(
    '^(?<prefix>.+)-(?<base>\d+\.\d+\.\d+(?:\.\d+)?)-(?<timestamp>\d{8}\.\d{6})-(?<build>\d+)(?<classifier>-[^.]+)?(?<ext>\.(?:jar|pom)(?:\.(?:md5|sha1))?)?$',
    [System.Text.RegularExpressions.RegexOptions]::Compiled
)

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    switch ($Level) {
        'Warning' { Write-Warning $Message }
        'Error' { Write-Error $Message }
        default { Write-Host $Message }
    }
}

function Resolve-RepositoryRoot {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Repository root does not exist: $Path"
    }

    $item = Get-Item -LiteralPath $Path
    if ($item.LinkType) {
        throw "Repository root must not be a symlink: $Path"
    }

    return [System.IO.Path]::GetFullPath($item.FullName)
}

function Test-PathUnderRoot {
    param(
        [string]$Root,
        [string]$CandidatePath
    )

    $fullCandidate = [System.IO.Path]::GetFullPath($CandidatePath)
    $rootWithSeparator = $Root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
        [System.IO.Path]::DirectorySeparatorChar

    return $fullCandidate.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase) -or
        $fullCandidate.Equals($Root, [StringComparison]::OrdinalIgnoreCase)
}

function Get-MetadataReferencedSnapshotValue {
    param([string]$MetadataPath)

    if (-not (Test-Path -LiteralPath $MetadataPath)) {
        return $null
    }

    try {
        [xml]$xml = Get-Content -LiteralPath $MetadataPath -Encoding UTF8
        $nodes = $xml.metadata.versioning.snapshotVersions.snapshotVersion
        if (-not $nodes) {
            return $null
        }

        foreach ($node in @($nodes)) {
            $extension = [string]$node.extension
            $classifier = ''
            if ($node.PSObject.Properties.Match('classifier').Count -gt 0) {
                $classifier = [string]$node.classifier
            }

            if ($extension -eq 'jar' -and [string]::IsNullOrWhiteSpace($classifier)) {
                return [string]$node.value
            }
        }

        return $null
    }
    catch {
        throw "Failed to parse maven-metadata.xml at '$MetadataPath': $($_.Exception.Message)"
    }
}

function Get-SnapshotBuildKey {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    if ($Value -match '^(\d+\.\d+\.\d+(?:\.\d+)?)-(\d{8}\.\d{6})-(\d+)$') {
        return $Value
    }

    return $null
}

function Get-BuildSortKey {
    param([string]$BuildKey)

    if ($BuildKey -match '^(\d+\.\d+\.\d+(?:\.\d+)?)-(\d{8}\.\d{6})-(\d+)$') {
        return [pscustomobject]@{
            BaseVersion = $Matches[1]
            Timestamp   = $Matches[2]
            BuildNumber = [int]$Matches[3]
            SortKey     = '{0}|{1:D10}' -f $Matches[2], [int]$Matches[3]
        }
    }

    return $null
}

function Get-SnapshotBuildGroups {
    param([string]$SnapshotDirectory)

    $groups = @{}
    $entries = Get-ChildItem -LiteralPath $SnapshotDirectory -File -Force |
        Where-Object { -not $_.LinkType }

    foreach ($entry in $entries) {
        $name = $entry.Name
        if ($ProtectedFileNames -contains $name) {
            continue
        }
        if ($name -eq 'index.html') {
            continue
        }

        $match = $SnapshotArtifactRegex.Match($name)
        if (-not $match.Success) {
            continue
        }

        $buildKey = '{0}-{1}-{2}' -f $match.Groups['base'].Value, $match.Groups['timestamp'].Value, $match.Groups['build'].Value
        if (-not $groups.ContainsKey($buildKey)) {
            $groups[$buildKey] = [System.Collections.Generic.List[string]]::new()
        }

        $groups[$buildKey].Add($entry.FullName)
    }

    return $groups
}

function Get-BuildsToKeep {
    param(
        [hashtable]$BuildGroups,
        [int]$KeepCount,
        [string]$MetadataReferencedBuildKey
    )

    $buildKeys = @($BuildGroups.Keys)
    if ($buildKeys.Count -eq 0) {
        return [string[]]@()
    }

    $sorted = $buildKeys |
        ForEach-Object {
            $sort = Get-BuildSortKey -BuildKey $_
            if ($null -eq $sort) {
                return $null
            }
            [pscustomobject]@{
                BuildKey = $_
                SortKey  = $sort.SortKey
            }
        } |
        Where-Object { $null -ne $_ } |
        Sort-Object -Property SortKey -Descending

    $keepSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($build in $sorted | Select-Object -First $KeepCount) {
        [void]$keepSet.Add($build.BuildKey)
    }

    if (-not [string]::IsNullOrWhiteSpace($MetadataReferencedBuildKey)) {
        [void]$keepSet.Add($MetadataReferencedBuildKey)
    }

    return [string[]]($keepSet | Sort-Object)
}

function Remove-BuildFiles {
    param(
        [string[]]$FilePaths,
        [string]$RepositoryRootFull,
        [bool]$IsDryRun
    )

    $deleted = [System.Collections.Generic.List[string]]::new()

    foreach ($filePath in $FilePaths) {
        $item = Get-Item -LiteralPath $filePath -Force
        if ($item.LinkType) {
            Write-Log "Skipping symlink: $filePath" -Level Warning
            continue
        }

        if (-not (Test-PathUnderRoot -Root $RepositoryRootFull -CandidatePath $filePath)) {
            throw "Refusing to delete file outside repository root: $filePath"
        }

        if ($IsDryRun) {
            Write-Log "[dry-run] Would delete: $filePath"
        }
        else {
            Remove-Item -LiteralPath $filePath -Force
            Write-Log "Deleted: $filePath"
        }

        $deleted.Add($filePath)
    }

    return $deleted
}

$repositoryRootFull = Resolve-RepositoryRoot -Path $RepositoryRoot
$isDryRun = [bool]$DryRun

Write-Log "Repository root: $repositoryRootFull"
Write-Log "Keep latest builds: $Keep"
Write-Log $(if ($isDryRun) { 'Mode: dry-run (no files will be deleted)' } else { 'Mode: execute (files will be deleted)' })

$scannedSnapshotDirectories = [System.Collections.Generic.List[string]]::new()
$skippedDirectories = [System.Collections.Generic.List[string]]::new()
$keptBuildsLog = [System.Collections.Generic.List[string]]::new()
$deletedFiles = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$snapshotDirectories = Get-ChildItem -LiteralPath $repositoryRootFull -Directory -Recurse -Force |
    Where-Object { $_.Name.EndsWith('-SNAPSHOT', [StringComparison]::Ordinal) -and -not $_.LinkType } |
    Sort-Object -Property FullName

foreach ($snapshotDirectory in $snapshotDirectories) {
    $relativePath = [System.IO.Path]::GetRelativePath($repositoryRootFull, $snapshotDirectory.FullName)
    $scannedSnapshotDirectories.Add($relativePath)

    Write-Log ""
    Write-Log "Scanning SNAPSHOT directory: $relativePath"

    $metadataPath = Join-Path -Path $snapshotDirectory.FullName -ChildPath 'maven-metadata.xml'
    $metadataReferencedValue = $null
    $metadataReferencedBuildKey = $null

    try {
        $metadataReferencedValue = Get-MetadataReferencedSnapshotValue -MetadataPath $metadataPath
        $metadataReferencedBuildKey = Get-SnapshotBuildKey -Value $metadataReferencedValue
        if ($metadataReferencedValue) {
            Write-Log "Metadata-referenced snapshot (jar): $metadataReferencedValue"
        }
    }
    catch {
        $warning = "Could not parse metadata for '$relativePath': $($_.Exception.Message). Keeping latest $Keep build(s) only."
        $warnings.Add($warning)
        Write-Log $warning -Level Warning
        $metadataReferencedBuildKey = $null
    }

    $buildGroups = Get-SnapshotBuildGroups -SnapshotDirectory $snapshotDirectory.FullName
    if ($buildGroups.Count -eq 0) {
        Write-Log "No timestamped SNAPSHOT artifacts found; skipping."
        $skippedDirectories.Add($relativePath)
        continue
    }

    $buildsToKeep = Get-BuildsToKeep -BuildGroups $buildGroups -KeepCount $Keep -MetadataReferencedBuildKey $metadataReferencedBuildKey
    $buildsToKeepSet = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($buildKey in $buildsToKeep) {
        [void]$buildsToKeepSet.Add($buildKey)
    }

    Write-Log "Builds to keep ($($buildsToKeep.Count)): $($buildsToKeep -join ', ')"

    foreach ($buildKey in ($buildsToKeep | Sort-Object)) {
        $keptBuildsLog.Add("$relativePath :: $buildKey")
    }

    foreach ($buildKey in ($buildGroups.Keys | Sort-Object)) {
        if ($buildsToKeepSet.Contains($buildKey)) {
            continue
        }

        $filesToDelete = @($buildGroups[$buildKey])
        Write-Log "Pruning build: $buildKey ($($filesToDelete.Count) file(s))"
        $removed = Remove-BuildFiles -FilePaths $filesToDelete -RepositoryRootFull $repositoryRootFull -IsDryRun $isDryRun
        foreach ($path in $removed) {
            $deletedFiles.Add([System.IO.Path]::GetRelativePath($repositoryRootFull, $path))
        }
    }
}

Write-Log ""
Write-Log "========== Summary =========="
Write-Log "SNAPSHOT directories scanned: $($scannedSnapshotDirectories.Count)"
Write-Log "SNAPSHOT directories skipped (no timestamped artifacts): $($skippedDirectories.Count)"
Write-Log "Builds kept: $($keptBuildsLog.Count)"
Write-Log "Files $(if ($isDryRun) { 'that would be deleted' } else { 'deleted' }): $($deletedFiles.Count)"
Write-Log "Warnings: $($warnings.Count)"

if ($scannedSnapshotDirectories.Count -gt 0) {
    Write-Log ""
    Write-Log "Scanned SNAPSHOT directories:"
    foreach ($dir in $scannedSnapshotDirectories) {
        Write-Log "  - $dir"
    }
}

if ($skippedDirectories.Count -gt 0) {
    Write-Log ""
    Write-Log "Skipped directories:"
    foreach ($dir in $skippedDirectories) {
        Write-Log "  - $dir"
    }
}

if ($keptBuildsLog.Count -gt 0) {
    Write-Log ""
    Write-Log "Builds kept:"
    foreach ($entry in $keptBuildsLog) {
        Write-Log "  - $entry"
    }
}

if ($deletedFiles.Count -gt 0) {
    Write-Log ""
    Write-Log $(if ($isDryRun) { 'Files that would be deleted:' } else { 'Files deleted:' })
    foreach ($file in $deletedFiles) {
        Write-Log "  - $file"
    }
}

if ($warnings.Count -gt 0) {
    Write-Log ""
    Write-Log "Warnings:"
    foreach ($warning in $warnings) {
        Write-Log "  - $warning" -Level Warning
    }
}
