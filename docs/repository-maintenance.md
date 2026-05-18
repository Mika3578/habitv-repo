# Repository maintenance

## Why Maven SNAPSHOT artifacts are timestamped

When you deploy a `-SNAPSHOT` version with Maven, each deploy creates a unique
timestamped build identifier (for example `4.1.0-20260518.163022-1`). Maven
writes those files alongside `maven-metadata.xml`, which points clients at the
latest snapshot. This is normal Maven behavior for mutable snapshot versions.

## Why habitv-repo needs pruning

habitv-repo is a static GitHub Pages Maven repository. Every deploy adds new
timestamped files under each `*-SNAPSHOT` directory. Older timestamped builds
are no longer needed once newer builds exist, but they remain on disk and in
Git unless you remove them.

## Recommended retention

Keep the **latest 3** timestamped SNAPSHOT builds per version directory
(`-Keep 3`). The pruning script also always keeps the build currently referenced
by `maven-metadata.xml` (jar extension, no classifier), even if it would
otherwise fall outside that window.

Release version directories (names that do **not** end with `-SNAPSHOT`) are
never modified. Protected files (`maven-metadata.xml`, checksums, `index.html`)
are never deleted.

## Dry-run (preview changes)

Always preview first:

```powershell
pwsh scripts/prune-snapshots.ps1 -RepositoryRoot repository -Keep 3 -DryRun
```

Dry-run lists scanned directories, builds that would be kept, and files that
would be deleted without changing anything on disk.

## Real purge

After reviewing dry-run output:

```powershell
pwsh scripts/prune-snapshots.ps1 -RepositoryRoot repository -Keep 3
```

Omit `-DryRun` only when you intend to delete obsolete files.

## Git repository size

Deleting files from the working tree and committing the change **does not**
shrink the historical size of the Git repository. Old blobs remain in history
until history is rewritten (for example `git filter-repo`), which is a separate,
explicit operation and is **out of scope** for this maintenance workflow.

## Script location

`scripts/prune-snapshots.ps1`
