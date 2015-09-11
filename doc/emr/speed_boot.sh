#!/bin/bash

RUNHASH=4cd199c2f3412f66284c1147cfb327a98fb23dd2
NEKONAME=neko-1.8.2-linux
NETFILE=network.out
SHAPEFILE=shapes.out

# dependencies
sudo apt-get update
sudo apt-get install -y libgc-dev

# install neko
wget http://nekovm.org/_media/$NEKONAME.tar.gz
tar -xvzf $NEKONAME.tar.gz
export NEKOPATH=$PWD/$NEKONAME
#echo $NEKOPATH
export LD_LIBRARY_PATH=$NEKOPATH:$LD_LIBRARY_PATH
#echo $LD_LIBRARY_PATH
export PATH=$NEKOPATH:$PATH
#echo $PATH

# saving env vars 
echo "export NEKOPATH=$NEKOPATH" >> /home/hadoop/conf/hadoop-user-env.sh
echo "export LD_LIBRARY_PATH=$NEKOPATH:$LD_LIBRARY_PATH" >> /home/hadoop/conf/hadoop-user-env.sh
echo "export PATH=$NEKOPATH:$PATH" >> /home/hadoop/conf/hadoop-user-env.sh

# prepare mapper and reducer
cd $NEKONAME
wget http://malaco.s3.amazonaws.com/big-speed/$RUNHASH/bin/speed_mapper.n
nekotools boot speed_mapper.n

# prepare emme network (net and shapes)
cd ..
wget http://malaco.s3.amazonaws.com/big-speed/$RUNHASH/data/$NETFILE
echo "export EMME_NET=$PWD/$NETFILE" >> /home/hadoop/conf/hadoop-user-env.sh
wget http://malaco.s3.amazonaws.com/big-speed/$RUNHASH/data/$SHAPEFILE
echo "export EMME_SHP=$PWD/$SHAPEFILE" >> /home/hadoop/conf/hadoop-user-env.sh
