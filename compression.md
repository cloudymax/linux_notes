# Compressing files


## pigz

Pigz is multi-threaded gzip. It compresses single files and can be tricked into compressing directories using tar

```bash
export PIGZ_THREADS=24
export PIGS_COMPRESSION_LEVEL=9
export PIGZ_TARGET_DIR="/media"

# Single file
pigz -$COMPRESSION_LEVEL -k -p$CPU_CORES ubuntu-20.04-beta-desktop-amd64.iso

# Directory

tar --use-compress-program="pigz -$PIGZ_COMPRESSION_LEVEL -k -p$PIGZ_THREADS" \
-cf $PIGZ_TARGET_DIR.tar.gz $PIGZ_TARGET_DIR

# Decompress
pigz -dc smolk8s.tar.gz | tar xf -
```

## Upload to B2

```bash
export BUCKET_NAME="vmt-emergency-backups"
export B2_ACCOUNT=""
/home/linuxbrew/.linuxbrew/bin/b2 authorize_account $B2_ACCOUNT
/home/linuxbrew/.linuxbrew/bin/b2 upload_file $BUCKET_NAME $PIGZ_TARGET_DIR.tar.gz  somedir/$PIGZ_TARGET_DIR.tar.gz --threads 24
```
