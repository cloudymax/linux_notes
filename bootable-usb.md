# create a bootable usb flash drive

## images

download the iso of your choice somehwere

```zsh
export IMAGE_DIR="/home/max/Desktop/image_files/ubuntu"
export IMAGE_FILE="ubuntu-18.04.5-desktop-amd64.iso"
```

## burning the image

```zsh
# disk configuration

sudo fdisk -l |grep "Disk /dev/"

export DISK_NAME="/dev/sdb"

sudo umount "$DISK_NAME"

sudo dd bs=4M if=$IMAGE_DIR/$IMAGE_FILE of="$DISK_NAME" status=progress oflag=sync

```

## As a Script

```zsh
crate_bootable_usb(){
  IMAGE_DIR="Downloads"
  IMAGE_FILE="ubuntu-21.10-live-server-amd64.iso"

  # be aware hadware changes the names of this shit
  # sd = sata/scsi/cd/dvd
  # hdb = IDE
  # fd = floppy

  # im making the assumption that it will be the only other disk
  DISK_NAME="/dev/sdb"
  
  # unmount the disk
  sudo umount "$DISK_NAME"

  ## dd the image to the drive

  sudo dd \
    bs=4M \
    if="/home/$USER"/"$IMAGE_DIR"/"$IMAGE_FILE" \
    of="$DISK_NAME" \
    status=progress \
    oflag=sync
}
```
