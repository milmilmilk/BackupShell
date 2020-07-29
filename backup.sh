#!/bin/bash

backupDirectory='/' # バックアップするディレクトリ
# backupTo='/media/USERNAME/BackupHDD/backup' # バックアップ先
exclude='--exclude sys --exclude proc --exclude run --exclude media --exclude mnt --exclude swapfile --exclude home/USERNAME/GoogleDrive --exclude home/USERNAME/.local/share/Trash --include home/USERNAME/Downloads/prev --exclude home/USERNAME/Documents/kaneiwa/wordnetlabeling/tmp' # rsyncのexclude
tempDir=('dev' 'tmp' 'lost+found') # 一時ファイルなど．最新の履歴だけ保持する．

formatunixtime() {
	dirDate=`echo "${1%%_*}" | sed -e 's!-!/!g'`
	dirTime=`echo "${1#*_}" | sed -e 's!-!:!g'`
	echo `date -d "${dirDate} ${dirTime}" +%s`
}

# 引数を受け取る
if [ $# = 0 -o $# -ge 4 ] ; then
	echo "useage: $0 [backupTo] # Ubuntu whole backup"
	echo "useage: $0 [backupDirectory] [backupTo]"
	echo "useage: $0 [backupDirectory] [backupTo] [exclude]"
	exit 1
fi
if [ $# = 1 ] ; then
	backupTo="$1"
fi
if [ $# -ge 2 ] ; then
	backupDirectory="$1"
	backupTo="$2"
	exclude=' '
	if [ $# -ge 3 ] ; then
		exclude="$3"
	fi
fi

if [ ! -e ${backupDirectory} ] ; then
	echo "バックアップ元の${backupDirectory}がありません"
	exit 1
fi
if [ ! -d ${backupTo} ] ; then
	echo "バックアップ先の${backupTo}がありません"
	exit 1
fi

# 最新のバックアップを探す
latest=0
latestDir=''
for dir in `ls -r ${backupTo}` ; do
	if [ -d "${backupTo}/${dir}" ] ; then
		utime=`formatunixtime ${dir}`
		if [ ${latest} -lt ${utime} ] ; then
			latest=${utime}
			latestDir=${dir}
		fi
	fi
done

# 他のバックアップを作成中ならバックアップしない
if [ -e "${backupTo}/${latestDir}backup.log" ] ; then
	echo "processing... '${backupTo}/${latestDir}'"
	exit 1
fi


# 今日の日付を取得
today=`date +%Y-%m-%d_%H-%M-%S`
mkdir "${backupTo}/${today}"

# バックアップを作成
if [ "${latestDir}" = '' ] ; then
	# 完全バックアップ
	echo "${backupDirectory}の完全バックアップを作成します。"
	time rsync -aHAXv --delete ${exclude} "${backupDirectory}" "${backupTo}/${today}" | tee "${backupTo}/${today}backup.log"
	status=$?
else
	# 差分バックアップ
	echo "${latestDir}からの差分バックアップを作成します。"
	time rsync -aHAXv --delete ${exclude} --link-dest="${backupTo}/${latestDir}" "${backupDirectory}" "${backupTo}/${today}" | tee "${backupTo}/${today}backup.log"
	status=$?
	if [ ${status} = 0 ] ; then
		for td in ${tempDir[@]} ; do rm -rv "${backupTo}/${latestDir}/${td}" | tee "${backupTo}/${today}backup.log" ; done
		status=$?
	fi
fi

if [ ${status} != 0 ] ; then
	echo "バックアップに失敗しました: ${today} (status=${status})"
	exit 1
fi

echo 'バックアップ作成が完了しました'

# ログファイルを削除する。
if [ $? = 0 ] ; then
	rm "${backupTo}/${today}backup.log"
else
	mv "${backupTo}/${today}backup.log" "${backupTo}/${today}/backup_status${?}.log"
fi

sleep 1

#================================================
# ===      古いバックアップを削除する．      ===
#================================================

# dir3 - 2^i - 2^{i-2} < dir1 < dir2 < dir3 < today - 2^i + 2^{i-2} = baseH のとき，dir2を削除する．
today=$(date +%s)
for ((i=13 ; i<25 ; i++)) ; do # 2^13秒から2^25秒間隔でバックアップ
	pow0=$((2 ** i))
	pow1=$((${pow0} / 2))
	pow2=$((${pow1} / 2))
	base=$((today - ${pow0}))
	baseH=$((base + ${pow2}))
	for dir in `ls -r ${backupTo}` ; do
		if [ -d "${backupTo}/${dir}" ] ; then
			utime=`formatunixtime ${dir}`
			if [ ${utime} -lt ${baseH} ] ; then
				prev=$((utime - ${pow0}))
				prevL=$((prev - ${pow2}))
				existCount=0
				for dj in `ls ${backupTo}` ; do
					if [ -d "${backupTo}/${dj}" ] ; then
						djtime=`formatunixtime ${dj}`
						if [ ${existCount} = 0 ] ; then
							if [ ${prevL} -le ${djtime} ] ; then
								echo "dir=${dir} dj=${dj} pow0=${pow0} pow1=${pow1} pow2=${pow2}"
								existCount=$((${existCount} + 1))
							fi
						else
							if [ ${djtime} -lt ${utime} ] ; then
								echo "古いバックアップ${dj}を削除します"
								rm -rf "${backupTo}/${dj}"
							fi
						fi
					fi
				done
			fi
		fi
	done
done
