# rbdbackuptool  
Its a rbd backuptool service written with bash, for ceph.  
This tool can only full-backup. Its not supports incremental backup yet.  
If your rbd names do not start with "sda,sdb" then you should edit the rbdbackup.conf  

```
sda=false
sdb=true
images=false
poolname=buluthan
#fstype = nfs, cifs, zfspool, dir
fstype=nfs
holdexports=2 # will not delete last 'n' export. min=1
destination=/mnt/test
```
