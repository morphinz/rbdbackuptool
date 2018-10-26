# rbdbackuptool  
Its a rbd backuptool service written with bash, for ceph.  
This tool can only full-backup. Its not supports incremental backup yet.  
If your rbd names do not start with "sda,sdb" then you should edit the rbdbackup.conf  

```
sda=false #
sdb=true
images=false  #It will backup any image if its have a snapshot named "@image"
poolname=mycephpool
fstype=nfs    #fstype = nfs, cifs, zfs, dir
destination=/mnt/test
```
