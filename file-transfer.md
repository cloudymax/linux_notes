# File Transfer Notes

## SFTP

From Local to remote:

```zsh
export USER="max"
export HOST="littlebradley"
export PORT="22"
export REMOTE_DIR="home/$USER"
export LOCAL_DIR="home/$USER"
export FILE="test.txt"

sftp $USER@$HOST:$PORT /$REMOTE_DIR/$FILE $LOCAL_DIR/$FILE
```


## RSYNC

using this nonsense: [The fastest remote directory rsync over ssh archival I can muster](https://gist.github.com/KartikTalwar/4393116)

### Local to remote host
```zsh

export RSYNC_SKIP_COMPRESS=3fr/3g2/3gp/3gpp/7z/aac/ace/amr/apk/appx/appxbundle/arc/arj/arw/asf/avi/bz2/cab/cr2/crypt[5678]/dat/dcr/deb/dmg/drc/ear/erf/flac/flv/gif/gpg/gz/iiq/iso/jar/jp2/jpeg/jpg/k25/kdc/lz/lzma/lzo/m4[apv]/mef/mkv/mos/mov/mp[34]/mpeg/mp[gv]/msi/nef/oga/ogg/ogv/opus/orf/pef/png/qt/rar/rpm/rw2/rzip/s7z/sfx/sr2/srf/svgz/t[gb]z/tlz/txz/vob/wim/wma/wmv/xz/zip

export USER="max"
export HOST="littlebradley"
export PORT="22"
export REMOTE_DIR="/home/$USER"
export LOCAL_DIR="/home/$USER"
export FILE="test-data"

rsync --times \
  --links \
  --hard-links \
  --skip-compress=$RSYNC_SKIP_COMPRESS \
  --recursive \
  --progress \
  --human-readable \
  --verbose \
  -e '/usr/bin/ssh -T -c aes256-gcm@openssh.com -o Compression=no -x' \
  $LOCAL_DIR/$FILE $USER@$HOST:$REMOTE_DIR/$FILE
```

### Remote to Local

```zsh

export RSYNC_SKIP_COMPRESS=3fr/3g2/3gp/3gpp/7z/aac/ace/amr/apk/appx/appxbundle/arc/arj/arw/asf/avi/bz2/cab/cr2/crypt[5678]/dat/dcr/deb/dmg/drc/ear/erf/flac/flv/gif/gpg/gz/iiq/iso/jar/jp2/jpeg/jpg/k25/kdc/lz/lzma/lzo/m4[apv]/mef/mkv/mos/mov/mp[34]/mpeg/mp[gv]/msi/nef/oga/ogg/ogv/opus/orf/pef/png/qt/rar/rpm/rw2/rzip/s7z/sfx/sr2/srf/svgz/t[gb]z/tlz/txz/vob/wim/wma/wmv/xz/zip

export USER="max"
export HOST="littlebradley"
export PORT="22"
export REMOTE_DIR="/home/$USER"
export LOCAL_DIR="/home/$USER"
export FILE="test-data"

rsync --times \
  --links \
  --hard-links \
  --skip-compress=$RSYNC_SKIP_COMPRESS \
  --recursive \
  --human-readable \
  --verbose \
  --progress \
  -p -e '/usr/bin/ssh -T -c aes256-gcm@openssh.com -o Compression=no -x' \
  $USER@$HOST:$REMOTE_DIR/$FILE $LOCAL_DIR/$FILE
  
  
