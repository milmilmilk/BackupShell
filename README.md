BackupShell
================

Linuxのフルバックアップ用のシェルスクリプト。

# 使い方
1. ソースコードの`USERNAME`と`BackupHDD`を適切に書き換える。
2. `/etc/cron.d/[適当なファイル名]`に`0 *     * * *   root    /home/USERNAME/Documents/bin/backup '/media/USERNAME/BackupHDD/backup'`って書いて`$ service restart cron`を実行する。
3. バックアップディスクBackupHDDを起動時にマウントするために`/etc/fstab`に`/dev/sdb1 /media/USERNAME/BackupHDD ext4 defaults 0 0`って書く。

# 環境
Ubuntu 18.04.4 LTS

# 仕様
`rsync`を使ってバックアップする。前回のバックアップから変更がないファイルは、前回のファイルへのハードリンクが作成される。以下の行でバックアップを作成する。
```
time rsync -aHAXv --delete ${exclude} --link-dest="${backupTo}/${latestDir}" "${backupDirectory}" "${backupTo}/${today}" | tee "${backupTo}/${today}backup.log"
```

古いバックアップほどバックアップ間隔が広くなるようにしてある。今日からn日前のバックアップはn日間隔になるようにする。つまり、2^i 日前のバックアップが存在する。

[Rsync によるフルシステムバックアップ](https://wiki.archlinux.jp/index.php/Rsync_%E3%81%AB%E3%82%88%E3%82%8B%E3%83%95%E3%83%AB%E3%82%B7%E3%82%B9%E3%83%86%E3%83%A0%E3%83%90%E3%83%83%E3%82%AF%E3%82%A2%E3%83%83%E3%83%97)
