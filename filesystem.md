# File System commands

## Disk resizing

```zsh
export DISK="/dev/nvme0n1p3"
export LOGICAL_VOLUME="/dev/mapper/ubuntu--vg-ubuntu--lv"

# Show, expand a physcal volume
sudo pvs
sudo pvresize "$DISK"

# Show, expand a logical volume
sudo lvs
sudo lvresize -l +100%FREE "$LOGICAL_VOLUME"

# Expand filesystem
sudo resize2fs "$LOGICAL_VOLUME"

# Show volume groups
sudo vgs
```
