#!/bin/sh

botdir="/home/biletappi/bot"
export LC_ALL="fi_FI"
export LC_CTYPE="fi_FI"

cd "$botdir"
"$botdir/eggdrop" "$botdir/biletappi.conf"
