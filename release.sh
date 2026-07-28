#!/bin/bash
###########
if [[ $1 != "" ]]
then
  owner=$(basename $1)
echo "change ownership from "$owner" to group2994"
fi
####  read the run directory name if present 
#
if [[ $2 != "" ]]
then
  release_dir=/nobackupp28/$(basename $2)
##
else
  release_dir=`pwd`
fi
#
echo "release directory: "$release_dir
chown -R $owner:s2994 $release_dir
chmod -R g+rx $release_dir
echo "setfacl -R -d -m u:gkoban:rx "$release_dir
setfacl -R -d -m u:gkoban:rwx $release_dir
echo "setfacl -R -m u:gkoban:rwx "$release_dir
setfacl -R -m u:gkoban:rwx $release_dir
echo "setfacl -R -d -m u:nbiro:rwx "$release_dir
setfacl -R -d -m u:nbiro:rwx $release_dir
echo "setfacl -R -m u:nbiro:rwx "$release_dir
setfacl -R -m u:nbiro:rwx $release_dir
echo "setfacl -R -d -m u:lzhao6:rwx "$release_dir
setfacl -R -d -m u:lzhao6:rwx $release_dir
echo "setfacl -R -m u:lzhao6:rwx "$release_dir
setfacl -R -m u:lzhao6:rwx $release_dir
echo "setfacl -R -d -m u:isokolov:rwx "$release_dir
setfacl -R -d -m u:isokolov:rwx $release_dir
echo "setfacl -R -m u:isokolov:rwx "$release_dir
setfacl -R -m u:isokolov:rwx $release_dir
echo "setfacl -R -d -m u:nsachdev:rwx "$release_dir
setfacl -R -d -m u:nsachdev:rwx $release_dir
echo "setfacl -R -m u:nsachdev:rwx "$release_dir
setfacl -R -m u:nsachdev:rwx $release_dir
#
#
exit 0 
#
######  return to calling script ######
#########################################
