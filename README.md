# AIOS Enterprise v9.1.4

Codename: NightWatch Patch 4

This patch fixes the remaining Windows PowerShell 5.1 watcher state warning related to null values.

Expected watcher log after update:

```text
Watcher started...
Created BUG-AUTO-...
Skipped duplicate fingerprint ...
```

There should be no repeating `State reset because it could not be read` messages.
