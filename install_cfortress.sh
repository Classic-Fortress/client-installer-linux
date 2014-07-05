#!/bin/sh

# Classic Fortress Client Installer Script (for Linux)
# by Empezar & dimman

defaultdir="~/cfortress"

error() {
    printf "ERROR: %s\n" "$*"
    [ -n "$created" ] || {
        cd
        echo "The directory $installdir is about to be removed, press ENTER to confirm or CTRL+C to exit." 
        read dummy
        rm -rf $installdir
    }
    exit 1
}

# Check if unzip is installed
which unzip >/dev/null || error "The package 'unzip' is not installed. Please install it and run the installation again."

# Check if curl is installed
which curl >/dev/null || error "The package 'curl' is not installed. Please install it and run the installation again."

echo
echo "Welcome to the Classic Fortress Client installation"
echo "==================================================="
echo
echo "Press ENTER to use [default] option."
echo

# Create the Classic Fortress folder
printf "Where do you want to install Classic Fortress? [$defaultdir]: " 
read installdir

eval installdir=$installdir

[ ! -z "$installdir" ] || eval installdir=$defaultdir

if [ -d "$installdir" ]; then
    if [ -w "$installdir" ]; then
        created=0
    else
        error "You do not have write access to '$installdir'. Exiting."
    fi
else
    if [ -e "$installdir" ]; then
        error "'$installdir' already exists but is a file, not a directory. Exiting."
        exit
    else
        mkdir -p $installdir 2>/dev/null || error "Failed to create install dir: '$installdir'"
        created=1
    fi
fi
if [ -w "$installdir" ]; then
    eval confdir="~/.cfortress"
    mkdir -p $confdir
    cd $installdir
    installdir=$(pwd)
    echo $installdir > $confdir/install_dir
else
    error "You do not have write access to $installdir. Exiting."
fi
echo;echo "* Installing Classic Fortress into: $installdir"
echo

# Download cfort.ini
wget --inet4-only -q -O $installdir/cfort.ini https://raw.githubusercontent.com/Classic-Fortress/client-installer/master/cfort.ini || error "Failed to download cfort.ini"
[ -s "$installdir/cfort.ini" ] || error "Downloaded cfort.ini but file is empty?! Exiting."

# List all the available mirrors
echo "From what mirror would you like to download Classic Fortress?"
mirrors=$(grep "[0-9]\{1,2\}=\".*" cfort.ini | cut -d "\"" -f2 | nl | wc -l)
grep "[0-9]\{1,2\}=\".*" cfort.ini | cut -d "\"" -f2 | nl
printf "Enter mirror number [random]: " 
read mirror
mirror=$(grep "^$mirror=[fhtp]\{3,4\}://[^ ]*$" cfort.ini | cut -d "=" -f2)
if [ -n "$mirror" ] && [ $mirrors > 1 ]; then
    range=$(expr$(grep "[0-9]\{1,2\}=\".*" cfort.ini | cut -d "\"" -f2 | nl | tail -n1 | cut -f1) + 1)
    while [ -z "$mirror" ]
    do
        number=$RANDOM
        let "number %= $range"
        mirror=$(grep "^$number=[fhtp]\{3,4\}://[^ ]*$" cfort.ini | cut -d "=" -f2)
        mirrorname=$(grep "^$number=\".*" cfort.ini | cut -d "\"" -f2)
    done
else
    mirror=$(grep "^1=[fhtp]\{3,4\}://[^ ]*$" cfort.ini | cut -d "=" -f2)
    mirrorname=$(grep "^1=\".*" cfort.ini | cut -d "\"" -f2)
fi
echo;echo "* Using mirror: $mirrorname"
mkdir -p $installdir/fortress $installdir/qw
echo

# Download all the packages
echo "=== Downloading ==="
wget --inet4-only -O $installdir/qsw106.zip $mirror/qsw106.zip || error "Failed to download $mirror/qsw106.zip"
wget --inet4-only -O $installdir/cfort-gpl.zip $mirror/cfort-gpl.zip || error "Failed to download $mirror/cfort-gpl.zip"
wget --inet4-only -O $installdir/cfort-non-gpl.zip $mirror/cfort-non-gpl.zip || error "Failed to download $mirror/cfort-non-gpl.zip"
if [ $(getconf LONG_BIT) = 64 ]; then
    wget --inet4-only -O $installdir/cfort-bin-x64.zip $mirror/cfort-bin-x64.zip || error "Failed to download $mirror/cfort-bin-x64.zip"
    [ -s "$installdir/cfort-bin-x64.zip" ] || error "Downloaded cfort-bin-x64.zip but file is empty?!"
else
    wget --inet4-only -O $installdir/cfort-bin-x86.zip $mirror/cfort-bin-x86.zip || error "Failed to download $mirror/cfort-bin-x86.zip"
    [ -s "$installdir/cfort-bin-x86.zip" ] || error "Downloaded cfort-bin-x86.zip but file is empty?!"
fi

[ -s "$installdir/qsw106.zip" ] || error "Downloaded qwsv106.zip but file is empty?!"
[ -s "$installdir/cfort-gpl.zip" ] || error "Downloaded cfort-gpl.zip but file is empty?!"
[ -s "$installdir/cfort-non-gpl.zip" ] || error "Downloaded cfort-non-gpl.zip but file is empty?!"

# Download configuration files
wget --inet4-only -O $installdir/fortress/default.cfg https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg || error "Failed to download default.cfg"

[ -s "$installdir/fortress/default.cfg" ] || error "Downloaded fortress/default.cfg but file is empty?!"

# Extract all the packages
echo "=== Installing ==="
printf "* Extracting Quake Shareware..."
(unzip -qqo $installdir/qsw106.zip ID1/PAK0.PAK 2>/dev/null && echo done) || echo fail
printf "* Extracting Classic Fortress setup files (1 of 2)..."
(unzip -qqo $installdir/cfort-gpl.zip 2>/dev/null && echo done) || echo fail
printf "* Extracting Classic Fortress setup files (2 of 2)..."
(unzip -qqo $installdir/cfort-non-gpl.zip 2>/dev/null && echo done) || echo fail
printf "* Extracting Classic Fortress binaries..."
if [ $(getconf LONG_BIT) = 64 ]
then
    (unzip -qqo $installdir/cfort-bin-x64.zip 2>/dev/null && echo done) || echo fail
else
    (unzip -qqo $installdir/cfort-bin-x86.zip 2>/dev/null && echo done) || echo fail
fi
echo

# Rename files
echo "=== Cleaning up ==="
printf "* Renaming files..."
(mv $installdir/ID1/PAK0.PAK $installdir/qw/pak0.pak 2>/dev/null && rm -rf $installdir/ID1 && echo done) || echo fail

# Remove distribution files
printf "* Removing setup files..."
(rm -rf $installdir/qsw106.zip $installdir/cfort-gpl.zip $installdir/cfort-non-gpl.zip $installdir/cfort-bin-x86.zip $installdir/cfort-bin-x64.zip $installdir/cfort.ini && echo done) || echo fail

# Create symlinks
printf "* Creating symlinks to configuration files..."
[ -e $confdir/client.conf ] || touch $confdir/client.conf
[ -L $installdir/fortress/config.cfg ] || ln -s $confdir/client.conf $installdir/fortress/config.cfg
echo "done"

# Create media folders
printf "* Creating media folders..."
mkdir -p $confdir/demos $confdir/screenshots $confdir/logs
[ -e $installdir/fortress/demos ] || ln -s $confdir/demos $installdir/fortress/demos
[ -e $installdir/fortress/screenshots ] || ln -s $confdir/screenshots $installdir/fortress/screenshots
[ -e $installdir/fortress/logs ] || ln -s $confdir/logs $installdir/fortress/logs
echo "done"

# Convert DOS files to UNIX
printf "* Converting DOS files to UNIX..."
for file in $(find $installdir -type f -iname "*.cfg" -or -iname "*.txt" -or -iname "*.sh" -or -iname "README")
do
    [ ! -f "$file" ] || cat $file|tr -d '\015' > tmpfile
    rm $file
    mv tmpfile $file
done
echo "done"

# Set the correct permissions
printf "* Setting permissions..."
find $installdir -type f -exec chmod -f 644 {} \;
find $installdir -type d -exec chmod -f 755 {} \;
chmod -f +x $installdir/cfortress 2>/dev/null
echo "done"

echo;echo "Installation complete!"
echo