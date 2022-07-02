# File Transfer Notes

based on: https://gist.github.com/KartikTalwar/4393116

## SCP

### From Local to remote:

```zsh
export LOCAL_DIR="/home/$USER/test-data"
export REMOTE_USER="max"
export REMOTE_DIR="/home/$USER/test-data"
export REMOTE_HOST="littlebradley"
export REMOTE_PORT="22"
export FILE="ubuntu-21.10-live-server-amd64.iso"
export CYPHER='aes128-gcm@openssh.com'
export SSH_KEY_FILE='/home/max/.ssh/flatbradley'

scp -i $SSH_KEY_FILE \
-p -r -P "$REMOTE_PORT" \
-c "$CYPHER" \
"$LOCAL_DIR"/"$FILE" \
"$REMOTE_USER"@"$REMOTE_HOST":"$REMOTE_DIR"/"$FILE"

```

### From Remote to Local:

```zsh
export REMOTE_USER="max"
export REMOTE_DIR="/home/$USER/test-data"
export REMOTE_HOST="littlebradley"
export REMOTE_PORT="22"
export LOCAL_DIR="/home/$USER/test-data"
export FILE="ubuntu-21.10-live-server-amd64.iso"
export CYPHER='aes128-gcm@openssh.com'
export SSH_KEY_FILE='/home/max/.ssh/flatbradley'

scp -i $SSH_KEY_FILE \
-p -r -P "$REMOTE_PORT" \
-c "$CYPHER" \
"$REMOTE_USER"@"$REMOTE_HOST":"$REMOTE_DIR"/"$FILE" "$LOCAL_DIR"/"$FILE"

```

### Passthrough

```zsh
export REMOTE_USER="max"
export REMOTE_DIR="/home/$USER/test-data"
export REMOTE_HOST="flatbradley"
export REMOTE_PORT="22"
export LOCAL_DIR="/home/$USER/test-data"
export FILE="ubuntu-21.10-live-server-amd64.iso"
export CYPHER='aes128-gcm@openssh.com'
export SSH_KEY_FILE='/home/max/.ssh/flatbradley'

scp -i $SSH_KEY_FILE -p -r -P "$REMOTE_PORT" -c "$CYPHER" "$REMOTE_USER"@"$REMOTE_HOST":"$REMOTE_DIR"/"$FILE" "$LOCAL_DIR"/"$FILE"



## Fast RSYNC

using this nonsense: [The fastest remote directory rsync over ssh archival I can muster](https://gist.github.com/KartikTalwar/4393116)

### Local to remote host
```zsh

sudo touch "$LOG_FILE"
tmux new-session -d -s rsync_"$FILE"
tmux send -t rsync_"$FILE" "export RSYNC_SKIP_COMPRESS='3fr/3g2/3gp/3gpp/7z/aac/ace/amr/apk/appx/appxbundle/arc/arj/arw/asf/avi/bz2/cab/cr2/crypt[5678]/dat/dcr/deb/dmg/drc/ear/erf/flac/flv/gif/gpg/gz/iiq/iso/jar/jp2/jpeg/jpg/k25/kdc/lz/lzma/lzo/m4[apv]/mef/mkv/mos/mov/mp[34]/mpeg/mp[gv]/msi/nef/oga/ogg/ogv/opus/orf/pef/png/qt/rar/rpm/rw2/rzip/s7z/sfx/sr2/srf/svgz/t[gb]z/tlz/txz/vob/wim/wma/wmv/xz/zip'
export USER='max'
export HOST='littlebradley'
export PORT='22'
export REMOTE_DIR='/home/$USER'
export LOCAL_DIR='/home/$USER'
export FILE='test-data'
export LOG_FILE='/var/log/transfers.log'
export FORMAT='json'
export BACKUP_DIR='/home/max/backups'
export SSH_KEY_FILE='/home/max/.ssh/flatbradley'
export CYPHER='aes128-gcm@openssh.com'
rsync --times \
--archive \
--log-file='$LOG_FILE' \
--inplace \
--checksum \
--compress \
--skip-compress='$RSYNC_SKIP_COMPRESS' \
--recursive \
--human-readable \
--verbose \
--progress \
-p -b -e 'ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ControlMaster=no -o ControlPath=none -T -c '$CYPHER' -o Compression=no -x' \
$LOCAL_DIR/$FILE $USER@$HOST:$REMOTE_DIR" ENTER

tmux attach-session -t rsync_"$FILE"
tmux kill-session -t session_one
```

### Remote to Local

```zsh

sudo touch "$LOG_FILE"
tmux new-session -d -s rsync_"$FILE"
tmux send -t rsync_"$FILE" "export RSYNC_SKIP_COMPRESS='3fr/3g2/3gp/3gpp/7z/aac/ace/amr/apk/appx/appxbundle/arc/arj/arw/asf/avi/bz2/cab/cr2/crypt[5678]/dat/dcr/deb/dmg/drc/ear/erf/flac/flv/gif/gpg/gz/iiq/iso/jar/jp2/jpeg/jpg/k25/kdc/lz/lzma/lzo/m4[apv]/mef/mkv/mos/mov/mp[34]/mpeg/mp[gv]/msi/nef/oga/ogg/ogv/opus/orf/pef/png/qt/rar/rpm/rw2/rzip/s7z/sfx/sr2/srf/svgz/t[gb]z/tlz/txz/vob/wim/wma/wmv/xz/zip'
export USER='max'
export HOST='littlebradley'
export PORT='22'
export REMOTE_DIR='/home/$USER'
export LOCAL_DIR='/home/$USER'
export FILE='test-data'
export LOG_FILE='/var/log/transfers.log'
export FORMAT='json'
export BACKUP_DIR='/home/max/backups'
export SSH_KEY_FILE='/home/max/.ssh/flatbradley'
export CYPHER='aes128-gcm@openssh.com'
rsync --times \
--archive \
--log-file='$LOG_FILE' \
--inplace \
--checksum \
--compress \
--skip-compress='$RSYNC_SKIP_COMPRESS' \
--recursive \
--human-readable \
--verbose \
--progress \
-p -b -e 'ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ControlMaster=no -o ControlPath=none -T -c '$CYPHER' -o Compression=no -x' \
$USER@$HOST:$REMOTE_DIR/$FILE $LOCAL_DIR" ENTER

tmux attach-session -t rsync_"$FILE"
tmux kill-session -t rsync_"$FILE"
  
  
