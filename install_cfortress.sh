#!/bin/sh

#################################################
## CLASSIC FORTRESS CLIENT INSTALLATION SCRIPT ##
#################################################

######################
##  INITIALIZATION  ##
######################

# functions
error() {
    echo
    printf "%s\n" "$*"

    [ -d $tmpdir ] && rm -rf $tmpdir

    exit 1
}
iffailed() {
    [ $fail -eq 1 ] && {
        echo "fail"
        printf "%s\n" "$*"
        exit 1
    }

    return 1
}

# initialize variables
eval settingsdir="~/.cfortress"
eval tmpdir="~/.cfortress_install"
defaultdir="~/cfortress"
github=https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master
fail=0

# initialize folders
rm -rf $tmpdir 2>/dev/null || error "ERROR: Could not remove temporary directory '$tmpdir'. Perhaps you have some permission problems."
mkdir $tmpdir 2>/dev/null || error "ERROR: Could not create setup folder '$tmpdir'. Perhaps you have some permission problems."
mkdir -p $tmpdir/game/fortress $tmpdir/game/id1 $tmpdir/game/qtv $tmpdir/game/qw $tmpdir/game/qwfwd

# check if unzip and curl are installed
[ `which unzip` ] || error "ERROR: The package 'unzip' is not installed. Please install it and run the installation again."
[ `which curl` ] || error "ERROR: The package 'curl' is not installed. Please install it and run the installation again."

# download cfort.ini
curl --silent --output $tmpdir/cfort.ini https://raw.githubusercontent.com/Classic-Fortress/client-installer/master/cfort.ini || \
    error "ERROR: Failed to download 'cfort.ini' (mirror information) from remote server. Try again later."

[ -s "$tmpdir/cfort.ini" ] || error "ERROR: Downloaded 'cfort.ini' but file is empty. Try again later."

######################
## FOLDER SELECTION ##
######################

# select install directory
printf "Where do you want to install Classic Fortress client? [$defaultdir]: " 
read installdir
eval installdir=$installdir

# use default install directory if user did not input a directory
[ -z "$installdir" ] && eval installdir=$defaultdir

# check if selected directory is writable and isn't a file
[ -f $installdir ] && error "ERROR: '$installdir' already exists and is a file, not a directory. Exiting."
[ ! -w ${installdir%/*} ] && error "ERROR: You do not have write access to '$installdir'. Exiting."

######################
## MIRROR SELECTION ##
######################

echo
echo "Using directory '$installdir'"
echo
echo "Select a download mirror:"

# print mirrors and number them
grep "[0-9]\{1,2\}=\".*" $tmpdir/cfort.ini | cut -d "\"" -f2 | nl

printf "Enter mirror number [random]: "

# read user's input
read mirror

# get mirror address from cfort.ini
mirror=$(grep "^$mirror=[fhtp]\{3,4\}://[^ ]*$" $tmpdir/cfort.ini | cut -d "=" -f2)

# count mirrors
mirrors=$(grep "[0-9]=\"" $tmpdir/cfort.ini | wc -l)

[ -z $mirror ] && [ $mirrors -gt 1 ] && {

    # calculate range (amount of mirrors + 1)
    range=$(expr$(grep "[0-9]=\"" $tmpdir/cfort.ini | nl | tail -n1 | cut -f1) + 1)

    while [ -z "$mirror" ]; do

        # generate a random number
        number=$RANDOM

        # divide the random number with the calculated range and put the remainder in $number
        let "number %= $range"

        # get the nth mirror using the random number
        mirror=$(grep "^$number=[fhtp]\{3,4\}://[^ ]*$" $tmpdir/cfort.ini | cut -d "=" -f2)

    done

} || mirror=$(grep "^1=[fhtp]\{3,4\}://[^ ]*$" $tmpdir/cfort.ini | cut -d "=" -f2)

######################
##     DOWNLOAD     ##
######################


echo
printf "Downloading files.."

# detect system architecture
[ $(getconf LONG_BIT) = 64 ] && arch=x64 || arch=x86

# download game data
curl --silent --output $tmpdir/qsw106.zip $mirror/qsw106.zip && printf "." || fail=1
curl --silent --output $tmpdir/cfort-gpl.zip $mirror/cfort-gpl.zip && printf "." || fail=1
curl --silent --output $tmpdir/cfort-non-gpl.zip $mirror/cfort-non-gpl.zip && printf "." || fail=1
curl --silent --output $tmpdir/cfort-bin.zip $mirror/cfort-bin-$arch.zip && printf "." || fail=1

# check if files contain anything
[ -s $tmpdir/qsw106.zip ] || fail=1
[ -s $tmpdir/cfort-gpl.zip ] || fail=1
[ -s $tmpdir/cfort-non-gpl.zip ] || fail=1
[ -s $tmpdir/cfort-bin.zip ] || fail=1

iffailed "Could not download game files. Try again later." || printf "."

# download configuration files
curl --silent --output $tmpdir/game/fortress/default.cfg $github/default.cfg && printf "." || fail=1

iffailed "Could not download configuration file. Try again later."

[ -s $tmpdir/game/fortress/default.cfg ] || fail=1

iffailed "Some of the downloaded files didn't contain any data. Try again later." || echo "done"

######################
##   INSTALLATION   ##
######################

printf "Installing files.."

unzip -qqo $tmpdir/qsw106.zip -d $tmpdir/game/ ID1/PAK0.PAK 2>/dev/null && printf "." || fail=1
unzip -qqo $tmpdir/cfort-gpl.zip -d $tmpdir/game/ 2>/dev/null && printf "." || fail=1
unzip -qqo $tmpdir/cfort-non-gpl.zip -d $tmpdir/game/ 2>/dev/null && printf "." || fail=1
unzip -qqo $tmpdir/cfort-bin.zip -d $tmpdir/game/ 2>/dev/null && printf "." || fail=1

iffailed "Could not unpack setup files. Something might be wrong with your installation directory."

# rename pak0.pak
(mv $tmpdir/game/ID1/PAK0.PAK $tmpdir/game/id1/pak0.pak 2>/dev/null && rm -rf $tmpdir/game/ID1) || fail=1

iffailed "Could not rename pak0.pak. Something might be wrong with your installation directory." || printf "."

# convert dos file endings to unix
for file in $(find $tmpdir -type f -iname "*.cfg" -or -iname "*.txt" -or -iname "*.sh" -or -iname "README"); do
    [ -f $file ] && cat $file | tr -d '\015' > $tmpdir/dos2unix 2>/dev/null || fail=1
    (rm $file && mv $tmpdir/dos2unix $file 2>/dev/null) || fail=1
done

iffailed "Could not convert files to unix line endings. Perhaps you have some permission problems." || printf "."

# set permissions
find $tmpdir/game -type f -exec chmod -f 644 {} \;
find $tmpdir/game -type d -exec chmod -f 755 {} \;
chmod -f +x $tmpdir/game/cfortress 2>/dev/null || fail=1

iffailed "Could not give game files the appropriate permissions. Perhaps you have some permission problems." || printf "."

# copy game dir to install dir
mkdir -p $installdir
cp -a $tmpdir/game/* $installdir/ 2>/dev/null || fail=1

iffailed "Could not move Classic Fortress client to '$installdir/'. Perhaps you have some permission problems." || printf "."

# write install directory to install_dir
mkdir -p $settingsdir
echo $installdir > $settingsdir/install_dir 2>/dev/null || fail=1

iffailed "Could not save install directory information to '$settingsdir/install_dir'. Perhaps you have some permission problems." || printf "."

# create symlinks
touch $installdir/fortress/config.cfg
[ ! -L $installdir/fortress/config.cfg ] && (ln -s $settingsdir/client.conf $installdir/fortress/config.cfg 2>/dev/null || fail=1)

iffailed "Could not create symlinks to configuration files. Perhaps you have some permission problems." || printf "."

# remove temporary directory
rm -rf $tmpdir 2>/dev/null || fail=1

iffailed "Could not remove temporary directory. Perhaps you have some permission problems." || echo "done"

echo
echo "SUCCESS!"
