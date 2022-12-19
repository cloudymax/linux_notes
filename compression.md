# Compressing files


## pigz

Pigz is multi-threaded gzip. It compresses single files and can be tricked into compressing directories using tar

```bash
export PIGZ_THREADS=8
export PIGS_COMPRESSION_LEVEL=9
export PIGZ_TARGET_DIR="smolk8s"

# Single file
pigz -$COMPRESSION_LEVEL -k -p$CPU_CORES ubuntu-20.04-beta-desktop-amd64.iso

# Directory

tar --use-compress-program="pigz -$PIGZ_COMPRESSION_LEVEL -k -p$PIGZ_THREADS" \
-cf $PIGZ_TARGET_DIR.tar.gz $PIGZ_TARGET_DIR

# Decompress
pigz -dc smolk8s.tar.gz | tar xf -
```
