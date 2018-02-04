#!/bin/bash
#
# Script to download the latest Raspbian image and copy it on SD 
#
# Copyright (c) 2018, Couchberries / Tomas Hozza <thozza [AT] gmail [DOT] com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


DOWNLOAD_LINK="https://downloads.raspberrypi.org/raspbian_lite_latest"
IMG_ARCHIVE_NAME="*-raspbian-*-lite.zip"
ENABLE_SSHD=true

DD_BS="8M"

# TODO: add possibility to pass the device path on command line
OUT_IF=""

# download the latest image
wget --trust-server-names -nc "$DOWNLOAD_LINK"

ARCHIVES=($(find . -name "$IMG_ARCHIVE_NAME" | sort -r))
LATEST_ARCHIVE=${ARCHIVES[0]}
LATEST_IMAGE="${LATEST_ARCHIVE%.*}.img"

# unzip the image
if [ ! -f "$LATEST_IMAGE" ]
then
    unzip "$LATEST_ARCHIVE"
fi

function choose_output_dev {
    # SD Card devices
    MMC_DEVS=($(ls /dev/mmcblk*))
    for i in $(seq 0 $((${#MMC_DEVS[@]} - 1)));
    do
        # strip all partition numbers
        MMC_DEVS[$i]=${MMC_DEVS[$i]%p*}
    done
    MMC_DEVS=$(echo "${MMC_DEVS[@]}" | tr ' ' '\n' | sort | uniq)

    # Solid state devices
    DISK_DEVS=($(ls /dev/sd*))
    for i in $(seq 0 $((${#DISK_DEVS[@]} - 1)));
    do
        # strip all partition numbers
        DISK_DEVS[$i]=${DISK_DEVS[$i]%[[:digit:]]*}
    done
    DISK_DEVS=$(echo "${DISK_DEVS[@]}" | tr ' ' '\n' | sort | uniq)
    
    # merge devices
    OUTPUT_DEVS=($MMC_DEVS $DISK_DEVS)

    while true;
    do
        echo "Choose device to which you want to install the image:"
        for i in $(seq 0 $((${#OUTPUT_DEVS[@]} - 1)));
        do
            echo "[$i] ${OUTPUT_DEVS[$i]}"
        done
        
        read -p "Device number: " DEVICE_NUM
        if [ "$DEVICE_NUM" -lt 0 -o "$DEVICE_NUM" -gt ${#OUTPUT_DEVS[@]} ]
        then
            echo "You MUST pass correct device number!"
            echo
            continue
        else
            eval "$1"="${OUTPUT_DEVS[$DEVICE_NUM]}"
            break
        fi
    done
}

choose_output_dev OUT_IF

DD_COMMAND="dd if=$LATEST_IMAGE of=$OUT_IF bs=$DD_BS"

RUN_DD=0
while true;
do
    read -p "Run the following command? '$DD_COMMAND' [yes/no] " RESPONSE
    if [ "$RESPONSE" != "yes" -a "$RESPONSE" != "no" ]
    then
        echo "You MUST type 'yes' or 'no'"
        echo
        continue
    else
        if [ "$RESPONSE" == "yes" ]
        then
            RUN_DD=1
        fi
        break
    fi
done

if [ "$RUN_DD" -eq 1 ]
then
    sudo $DD_COMMAND
    sync
    sync
fi

# enable sshd by creating 'ssh' file on /boot partition
TEMP_DIR=$(mktemp -d)
BOOT_PARTITION="$OUT_IF"p1
if [ $ENABLE_SSHD ]; then
    echo "Mounting '$BOOT_PARTITION' to '$TEMP_DIR'"
    sudo mount $BOOT_PARTITION $TEMP_DIR
    echo "Creating 'ssh' file on /boot partition to enable sshd"
    sudo touch "$TEMP_DIR/ssh"
    echo "Unmounting $TEMP_DIR"
    sync
    sudo umount $TEMP_DIR
fi
rm -rf "$TEMP_DIR"
