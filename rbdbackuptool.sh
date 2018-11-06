#!/bin/bash -xe
config=/etc/rbdbackup.conf
logfile=/var/log/rbdbackup.log
poollist=/tmp/poollist.tmp
backuplist=/tmp/backuplist.tmp
source $config

#getting started
echo -e "\n *BACKUP TOOL STARTED!*" >> $logfile 
date >> $logfile 


#Functions start
function nfs { 
if mount | awk -v d="$destination" -v rs=1 '$3==d{rs=0;exit}END{exit(rs)}'; then
	echo -e "NFS mount ok." >> $logfile
else
	echo -e "NFS NOT mounted!!! Exiting \n" >> $logfile
	exit
fi
}

function cifs {
if mount | awk -v d="$destination" -v rs=1 '$3==d{rs=0;exit}END{exit(rs)}'; then
	echo -e "CIFS mount ok." >> $logfile
else
	echo -e "CIFS NOT mounted!!! Exiting \n" >> $logfile
	exit
fi
}

function zfspool {

if zfs list | grep -q "$destination"; then
	echo -e "ZFS mount ok." >> $logfile
else
	echo -e "ZFS NOT mounted!!! Exiting \n" >> $logfile
fi
}

function dir {
if [ -d "$destination" ]; then
	echo -e "Dir exist." >> $logfile
else
	echo -e "Dir not exist!!! Exiting \n" >> $logfile
	exit
fi
}
#Functions end

#call functions

if [ "$fstype" == "nfs" ]||[ "$fstype" == "cifs" ]||[ "$fstype" == "zfs" ]||[ "$fstype" == "dir" ]; then
$fstype
else
	echo -e "Fstype not defined as 'nfs,cifs,zfs,dir' in config. Define fstype first. \n" >> $logfile
	exit
fi


#check backupdir exist
if [ -d "$destination" ]; then
        touch $destination/touchtest && [ $? -eq 0 ] && rm $destination/touchtest || echo cannot touch ["$destination"] Permission denied
        #write-speed test
        dd if=/dev/zero of=$destination/writetest bs=256M count=5 >> $logfile 2>&1 && rm $destination/writetest
        echo -e "Write test success \n" >> $logfile
else
        echo Backup dir ["$destination"] not exist! Check the path first!
	exit
fi

echo -e "fstype == $fstype" >> $logfile

#get backup list
rbd ls -l buluthan | awk '{print $1}' | grep -v BHImage | sed -n '1!p' > $poollist
rm $backuplist

if [ "$sda" == true ]; then 
        cat $poollist | grep -v '@\|sdb\|img\|image' >> $backuplist
else
        echo "sda == false" >> $logfile
fi

if [ "$sdb" == true ]; then
        cat $poollist | grep sdb | grep -v '@\|img\|image' >> $backuplist
else
        echo "sdb == false" >> $logfile
fi

if [ "$images" == true ]; then
for i in $(ls $imgdir)
do 
uuid=`jq -r '.uuid' $imgdir/$i` 
source=`jq -r '.source' $imgdir/$i` 
echo "Backup started for image $poolname/$uuid" >> $logfile
mkdir -p $destination/images
rbd export $source - | pigz --fast > $destination/images/$uuid-image.gz
cp $imgdir/$i $destination/images/
echo -e "Backup finished. \n" >> $logfile
done

else
        echo -e "images == false \n" >> $logfile
fi

#save backups
success=0
failed=0

for i in $(cat $backuplist)
do
        currentdate=$(date +%Y%m%d%H%M)
        echo "Job Started at $(date)" >> $logfile
	echo "Backup started for $poolname/$i" >> $logfile
        rbd snap create $poolname/$i@backup-$currentdate
        rbd snap protect $poolname/$i@backup-$currentdate
        echo "snap created and protected" >> $logfile
        rbd export $poolname/$i@backup-$currentdate - | pigz --fast > $destination/$i-backup-$currentdate.gz
if [ $? -eq 0 ]; then
        echo "export successfull" >> $logfile
        success=$((success+1))
else
        echo "export failed" >> $logfile
        failed=$((failed+1))
fi
        rbd snap unprotect $poolname/$i@backup-$currentdate
        rbd snap remove $poolname/$i@backup-$currentdate
	echo "snap unprotected and removed" >> $logfile
	#clean old exports
	holded=$(($holdexports+1))
        cleanolderexports=$(ls -tp $destination | grep $i | tail +$holded)

if [ ! -z "$cleanolderexports" ]; then
        for c in $cleanolderexports
do
        rm $destination/$c
        echo "deleted export = $c" >> $logfile
done
else
        echo "**We did not find any export to delete.**" >> $logfile
fi
        echo -e "Job finished at $(date) \n" >> $logfile
done
echo "-------------------------------------------"  >> $logfile
echo Success= $success  >> $logfile
echo Failed= $failed  >> $logfile
echo Total=$(cat /tmp/backuplist.tmp | wc -l)  >> $logfile
echo "-------------------------------------------"  >> $logfile
date >> $logfile 
echo -e "***BACKUP TOOL FINISHED!*** \n" >> $logfile 
exit

