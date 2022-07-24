#!/bin/bash

full_path=$(pwd)/$(basename $0)

rm -rf /tmp/test*
mkdir /tmp/test /tmp/test2

echo "bonjour" > /tmp/test/bonjour
ln -s /tmp/test/bonjour /tmp/test2/hello

cp /usr/bin/top /tmp/test
cp /usr/bin/ps /tmp/test
cp /usr/bin/ls /tmp/test2
cp /usr/bin/zip /tmp/test2

cp /usr/bin/time /tmp/test2
chmod 0555 /tmp/test2/time

cp $full_path /tmp/test2
