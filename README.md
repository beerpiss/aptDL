# aptDL
Downloads Cydia repositories (paid packages not included)

Dist repos are also not supported for now.

# Usage
```
.\main.ps1 <-s REPO_URL> <-cr | -co> [-o OUTPUT_DIR] [-cd COOLDOWN_SECONDS]

Required arguments:
  -s: Repo to download
  -cr: Rename downloaded files to PACKAGENAME-VERSION.deb
  -co: Don't rename downloaded files
-cr and -co are mutually exclusive.
  
Optional arguments:
  -o: Output directory (relative to the script's directory, default is .\output)
  -cd: Time to wait between downloads (default 5 seconds, so as not to hit rate limit)
```

# TODO
- [ ] Support for dist repos
- [ ] Input file