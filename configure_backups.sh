# Load variables
source set_variables.sh

# Set up mc binary
echo setting up NFS backups
mkdir ~/bin
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
mv mc ~/bin

# Set up velero binary
tar -xvf velero-v1.0.0-linux-amd64.tar.gz
mv velero-v1.0.0-linux-amd64/velero ~/bin/velero 
rm -rf velero-v1.0.0-linux-amd64
rm velero-v1.0.0-linux-amd64.tar.gz

# Re source PATH
source ~/.bash_profile

# Configure minio client and make backup buckets
mc config host add lake $minio_url $minio_key $minio_secret
mc mb lake/kubernetes-nfs
mc mb lake/kubernetes-configs

# Configure velero minio creds
cat > credentials-velero <<EOF
[default]
aws_access_key_id = $minio_key
aws_secret_access_key = $minio_secret
EOF

# Set up velero minio account
velero install \
    --provider aws \
    --bucket kubernetes-configs \
    --secret-file ./credentials-velero \
    --use-volume-snapshots=false \
    --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=$minio_url

## First back up
tar -zcvf latest-nfs.tar.gz /data/nfs
mc cp latest-nfs.tar.gz lake/kubernetes-nfs/$(date '+%Y-%m-%d')-nfs.tar.gz
mc cp lake/kubernetes-nfs/$(date '+%Y-%m-%d')-nfs.tar.gz lake/kubernetes-nfs/latest-nfs.tar.gz
rm latest-nfs.tar.gz

velero backup create kubernetes-configs-$(date '+%Y-%m-%d')

# Create a weekly backup cron
cat > weekly_backup_script.sh <<EOF
source /home/centos-master/.bash_profile
tar -zcvf latest-nfs.tar.gz /data/nfs
mc cp latest-nfs.tar.gz lake/kubernetes-nfs/\$(date '+%Y-%m-%d')-nfs.tar.gz
mc cp lake/kubernetes-nfs/\$(date '+%Y-%m-%d')-nfs.tar.gz lake/kubernetes-nfs/latest-nfs.tar.gz
rm latest-nfs.tar.gz
velero backup create kubernetes-configs-\$(date '+%Y-%m-%d')
EOF

touch backup_logs.txt
(crontab -l 2>/dev/null; echo "0 2 * * 0 /bin/bash /home/centos-master/weekly_backup_script.sh > /home/centos-master/backup_logs.txt") | crontab -

## Restoring
# best way to restore is restore a VM snapshot, but if that's not an option you can try restore from the velero backup
#mc cp lake/kubernetes-volumes/latest-nfs.tar.gz ~/
#tar -xvf ~/latest-nfs.tar.gz
#cp -r data/nfs/* /data/nfs/
#rm -rf data
#velero restore create --from-backup kubernetes-configs
#velero restore get
#rm latest-nfs.tar.gz
#reboot
# even now you may run into errors and need to manually reapply some configs...
