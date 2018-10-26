#!/bin/bash -xe
set -e 
config=/root/ozkan/rbdbackup.conf
logfile=/root/ozkan/rbdbackup.log
poollist=/tmp/poollist.tmp
backuplist=/tmp/backuplist.tmp
source $config

#getting started
echo -e "\n *BACKUP TOOL STARTED!*" >> $logfile 
date >> $logfile 


#Functions start
function nfs { 
if ["mount | grep $destination | awk '{print $2}'" == on]; then
	echo -e "NFS mount ok." >> $logfile
else
	echo -e "NFS NOT mounted!!! Exiting \n" >> $logfile
	exit
fi
}

function cifs {
if ["mount | grep $destination | awk '{print $2}'" == on]; then
	echo -e "CIFS mount ok." >> $logfile
else
	echo -e "CIFS NOT mounted!!! Exiting \n" >> $logfile
	exit
fi
}

function zfs {
if [ ! -z "$(zfs list | grep $destination)"]; then
	echo -e "ZFS mount ok." >> $logfile
else
	echo -e "ZFS NOT mounted!!! Exiting \n" >> $logfile
	exit
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
	echo type=$fstype
else
	echo -e "Fstype not defined as 'nfs,cifs,zfs,dir' in config. Define fstype first. \n" >> $logfile
	exit
fi


#check backupdir exist
if [ -d "$destination" ]; then
        touch $destination/touchtest && [ $? -eq 0 ] && rm $destination/touchtest || echo cannot touch ["$destination"] Permission denied
        #write-speed test
        dd if=/dev/zero of=$destination/writetest bs=1G count=5 >> $logfile 2>&1 && rm $destination/writetest
        echo -e "Write test success \n" >> $logfile
else
        echo Backup dir ["$destination"] not exist! Check the path first!
	exit
fi

echo -e "fstype=$fstype" >> $logfile

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
        mkdir -p $destination/images
        cp /var/buluthan/image-meta/* $destination/images/
        cat $poollist | grep '@image' >> $backuplist

else
        echo "images == false" >> $logfile
fi


#save backups
success=0
failed=0
set +e

for i in $(cat $backuplist)
do
        currentdate=$(date +%Y%m%d%H%M)
	echo "Backup started at $(date) for $poolname/$i@backup-$currentdate" >> $logfile
        rbd snap create $poolname/$i@backup-$currentdate
        rbd snap protect $poolname/$i@backup-$currentdate
        echo "snap created and protected" >> $logfile
        rbd export $poolname/$i@backup-$currentdate - | pigz --fast > $destination/$i-backup-$currentdate
if [ $? -eq 0 ]; then
        echo "export successfull" >> $logfile
        success=$((success+1))
else
        echo "export failed" >> $logfile
        failed=$((failed+1))
fi
        rbd snap unprotect $poolname/$i@backup-$currentdate
        rbd snap remove $poolname/$i@backup-$currentdate
	echo -e "snap unprotected and removed. Job finished at $(date) \n" >> $logfile
done
echo "-------------------------------------------"
echo Success= $success
echo Failed= $failed
echo Total=$(cat /tmp/backuplist.tmp | wc -l)
echo "-------------------------------------------"
date >> $logfile 
echo -e "*BACKUP TOOL FINISHED!*" >> $logfile 
exit

