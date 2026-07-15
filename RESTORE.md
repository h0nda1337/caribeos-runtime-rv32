# Restore and Backup

Run the preservation helpers from this repository:

```powershell
.\tools\backup-caribeos.ps1 -BackupRoot F:\CaribeOS-Backups
.\tools\verify-caribeos-backup.ps1 -BackupDirectory <timestamped-backup>
.\tools\restore-caribeos-backup.ps1 -BackupDirectory <timestamped-backup> -DestinationRoot <new-path>
```

The backup script detects the sibling XNU repository, rejects incomplete Git
operations, creates `--all` bundles, verifies them, hashes outputs, and never
deletes older backups. Optional GitHub push requires an existing
`github-backup` remote and is always non-force.

The restore script refuses an existing destination. It clones verified bundles
into a new directory, checks the archive tag, and runs `git fsck --full`.

Manual equivalent:

```powershell
git bundle verify <backup>\caribeos-runtime-tranche201.bundle
git clone <backup>\caribeos-runtime-tranche201.bundle <new-path>
git -C <new-path> fsck --full
git -C <new-path> tag --verify tranche-201-stage2-complete
```

Raw pre-edit `.tar.gz` snapshots include generated and untracked files; Git
bundles contain the curated reproducible source. Keep both layers and their
SHA-256 files.
