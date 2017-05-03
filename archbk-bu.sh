backup_archbk () {
  
  # creates, enables, and starts netctl profile for hidden ssid in Arch Linux
  # or starts wifi-menu for ssid that's not hidden
  # installs wget and cgpt, if user chooses option to install Arch Linux ARM to internal flash memory
  # gives option to install Arch Linux ARM to internal flash memory

  spinner()
  {
    local pid=$1
    local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
      local temp=${spinstr#?}
      printf "%c" "$spinstr"
      local spinstr=$temp${spinstr%"$temp"}
      sleep $delay
      printf "\b\b\b\b\b\b"
    done
    printf " \b\b\b\b"
  }

  echo 1>&2
  echo "****************" 1>&2
  echo "**            **" 1>&2
  echo "**  Warning!  **" 1>&2
  echo "**            **" 1>&2
  echo "****************" 1>&2
  echo 1>&2
  echo 1>&2
  echo "$type $media will be formatted." 1>&2
  echo 1>&2
  echo "all data on the device will be wiped" 1>&2
  echo 1>&2
  echo 1>&2
  read -p "do you want to continue with this backup? [y/N] : " a
  if [ $a ]; then
    if [ $a = 'n' ]; then
      exit 5
    fi
  else
    continue
  fi

  step=1

  umount /dev/$media* 2> /dev/null
  
  fdisk /dev/$media 1> /dev/null <<EOF
  g
  w
EOF
  
  cgpt create /dev/$media 1> /dev/null
  
  cgpt add -i 1 -t kernel -b $KERNEL_BEGINNING_SECTOR -s $KERNEL_SIZE -l Kernel -S 1 -T 5 -P 10 /dev/$media 1> /dev/null
  
  DEVICE_SIZE="$(cgpt show /dev/$media | grep "Sec GPT table" | sed -r 's/[0-9]*[ ]*Sec GPT table//' | sed 's/[ ]*//')"

  P2_BEGINNING_SECTOR="$(expr $KERNEL_BEGINNING_SECTOR + $KERNEL_SIZE)"
  P2_SIZE="$(expr $DEVICE_SIZE - $P2_BEGINNING_SECTOR)"

  echo
  echo "$step) creating root partition on target device"
  step="$(expr $step + 1)"
  add_root_partition="$(echo "cgpt add -i 2 -t data -b $P2_BEGINNING_SECTOR -s $P2_SIZE -l Root /dev/$media")"
  
	(eval $add_root_partition 1> /dev/null) &
  spinner $!

  partx -a "/dev/$media" 1> /dev/null 2>&1
  
	(mkfs.ext4 -F "/dev/$p2" 1> /dev/null 2>&1) &
	spinner $!
  
  cd /tmp && mkdir arch_tmp 2> /dev/null && cd arch_tmp
  
  mkdir root 2> /dev/null 1>&2
  mount /dev/$p2 root/

  # rsync backup to target device
  
  echo
  echo "$step) writing kernel image to target device kernel partition"
  step="$(expr $step + 1)"
	(dd if=/boot/vmlinux.kpart of=/dev/$p1 1> /dev/null 2>&1) &
	spinner $!
  
  echo
  echo "$step) unmounting target device"
  step="$(expr $step + 1)"
	(umount root) &
	spinner $!
  
  cd .. && rm -rf arch_tmp

}
 
# make sure that user entered backup device falls under script's constraints 
# if constraints are met, initializes varibles needed for backup
init () {

  # returns root device of given partition, if valid partition is entered  
  return_device () {

    part="$1"

    if [ ${#part} -gt 7 ]; then
      dev="$(echo $part | sed 's/p[0-9]*$//')"
    elif [ ${#part} -gt 4 ] && [ ${#part} -lt 7 ]; then
      dev="$(echo $part | sed 's/[0-9]*$//')"
    else
      dev="$1"
    fi

    echo $dev

  }

  # if script wasn't ran as root, quit
  if [ "$(whoami)" != 'root' ]; then
    echo
    echo 'script must be ran as root'
    echo
    echo 'try "sudo sh archbk-bu"'
    echo
    exit 1
  fi

  # if one arg wasn't entered, quit  
  if [ ! $1 ]; then
    echo
    echo 'no backup device entered'
    echo
    exit 2
  fi

  # if entered arg isn't a valid device, quit
  if [ ! -e /dev/$1 ]; then
    echo
    echo 'invalid backup device'
    echo
    exit 3
  fi

  # get get device names for root device and user entered backup device
  rootpart="$(lsblk | grep '/$' | awk '{print $1}' | sed 's/[^0-9a-z]*//')"
  rootdev="$(return_device $rootpart)"
  budev="$(return_device $1)"

  # if root device is the same as user entered backup device, quit
  if [ $rootdev == $budev ]; then  
    echo
    echo 'backup device cannot be the same as root device'
    echo
    exit 4
  fi
  
  # initialize $media as $budev
  media="$budev"

  # set partition variables for target device
  if [ ${#media} -gt 3 ]; then
    p1=$media"p1"
    p2=$media"p2"
    if [ $media = "mmcblk0" ]; then
      type="Internal Flash Memory aka"
    else
      type="SDcard"
    fi
  else
    p1=$media"1"
    p2=$media"2"
    type="USB drive"
  fi

  kpart="$(lsblk | grep $rootdev[0-9a-z]1 | awk '{print $1}' | sed 's/[^0-9a-z]*//')"
  
  KERNEL_SIZE="$(fdisk -l /dev/$kpart | grep '[0-9] sectors' | awk '{print $7}')"
  KERNEL_BEGINNING_SECTOR='8192'
 
}

main () {

  init $1
  backup_archbk
}

main $1 
