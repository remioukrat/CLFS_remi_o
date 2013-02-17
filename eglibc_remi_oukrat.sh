#!/bin/bash 

BINUTILS="binutils-2.22"
KERNEL="linux-3.5.3"
GCC="gcc-4.7.2"

########################################Prérequis#######################################
echo "Installation des paquets : Mot de passe root et connexion internet nécessaires" 
su -c '
aptitude update &&
aptitude install gawk &&
aptitude install libppl-dev &&
aptitude install bison &&
aptitude install libmpc-dev &&
aptitude install make &&
aptitude install build-essential &&
aptitude install libsvn-dev &&
aptitude install flex &&
aptitude install libmpfr-dev &&
aptitude install libgmp-dev &&
aptitude install ppl &&
aptitude install m4 &&
aptitude install autogen &&
aptitude install subversion &&
aptitude install texinfo &&
aptitude install diffutils &&
aptitude install autoconf &&
aptitude install cloog-ppl &&
aptitude install libcloog-ppl-dev &&
aptitude install pkg-config &&
aptitude install dconf-tools &&
aptitude install libpthread-stub0-dev &&
aptitude install libevent-pthreads-2.0-5 &&
aptitude install pthread &&
aptitude install libqt4-dev &&
aptitude install gperf &&
aptitude install libpthread-workqueue-dev'
echo "Téléchargements réussis"

#On se place dans HOME
cd

echo "Vérification de la présence d'une version précédente"
if [ -d MaEgCross ] 
	then
		echo "egCross déjà présente"
		echo "Suppression de la egCross précédente"
		rm -r MaEgCross
		echo "egCross supprimée"
	else
		echo "Pas de egCross présente"
		echo "Création de l'architecture"
		mkdir -p MaEgCross/sources/archives
		mkdir MaEgCross/build
		mkdir -p MaEgCross/arm/sysroot
		echo "Architecture construite"
fi

echo "Exportation des variables d'environnement"
export THREADS=$(egrep -c 'processor' /proc/cpuinfo) 	       # Nombres de THREADS
export SRCDIR=$HOME/MaEgCross/sources                            # Dossier sources 
export BUILDIR=$HOME/MaEgCross/build                            # Dossier paquets compilés 
export TARGETMACH=arm-none-linux-gnueabi			       # ARCH Target 
export BUILDMACH=$(gcc -dumpmachine)			              	       # Arch build 
export INSTALLDIR=$HOME/MaEgCross/arm		      	       # Dossier contenant la Cross 
export SYSROOTDIR=$HOME/MaEgCross/arm/sysroot		       # Dossier lib et header 
export ARCHIVES=$HOME/MaEgCross/sources/archives
echo "Variables d'environnement exportées"

echo "Telechargement des paquets nécessaires"
cd $SRCDIR
svn co http://www.eglibc.org/svn/branches/eglibc-2_16 eglibc-2.16    # On récupére la branche eGlibC 2.16
cd eglibc-2.16							     # On copie le fichier ports/ dans libc/
cp -R ports/ libc/			

cd $ARCHIVES
wget http://ftp.gnu.org/gnu/binutils/$BINUTILS.tar.bz2     
wget http://www.kernel.org/pub/linux/kernel/v3.x/$KERNEL.tar.bz2 
wget http://ftp.gnu.org/gnu/gcc/$GCC/$GCC.tar.bz2     

echo "Paquets téléchargés"

tar xvjf $BINUTILS.tar.bz2    
echo "Extraction BINUTILS réussi" 
mv $BINUTILS ../
echo "Déplacement du dossier réussi" 
#------------------------------------------------------------
tar xvjf $KERNEL.tar.bz2 
echo "Extraction KERNEL réussi" 
mv $KERNEL ../ 
echo "Déplacement du dossier réussi" 
#-----------------------------------------------------------
tar xvjf $GCC.tar.bz2 
echo "Extraction GCC réussi" 
mv $GCC ../
echo "Déplacement du dossier réussi" 
#-----------------------------------------------------------

echo "Il faut détruire le dossier archives"
cd ..
rm -r archives
if [ ! -d archives ]    # On test
then
	echo "Suppression des archives"	
fi

# BINUTILS
cd $BUILDIR
mkdir binutils && cd binutils
echo "-Compilation BINUTILS" 
../../sources/$BINUTILS/configure \
 	--disable-werror \
	--build=$BUILDMACH \
	--target=$TARGETMACH \
	--with-sysroot=$SYSROOTDIR \
	--prefix=$INSTALLDIR 			

make -j $THREADS

make install

echo "Compilation BINUTILS réussi" 



echo "Etape des en-têtes"
cd $SRCDIR/$KERNEL
make mrproper

echo "Configuration ARM de base"
make ARCH=arm integrator_defconfig
echo "ARM de base configuré"

echo "Vérification de toutes les installations"
make ARCH=arm headers_check
echo "Installations valides"

echo "Installation des en-têtes"
make ARCH=arm INSTALL_HDR_PATH=$INSTALLDIR/sysroot/usr headers_install 
echo "En-têtes installés" 

echo "Création du dossier gcc minimaliste"


mkdir $BUILDIR/gcc-bootstrap &&
cd $BUILDIR/gcc-bootstrap

echo "Configuration"
../../sources/gcc-4.7.2/configure \
	--host=$BUILDMACH \
	--build=$BUILDMACH \
	--target=$TARGETMACH \
	--prefix=$INSTALLDIR \
	--without-headers \
	--enable-bootstrap \
	--enable-languages=c \
	--disable-threads \
	--enable-__cxa-atexit \
	--disable-libmudflap \
	--with-gnu-as \
	--with-gnu-ld \
	--with-newlib \
	--disable-libssp \
	--disable-libgomp \
	--disable-nls \
	--disable-shared
echo "Configuration terminée"

echo "Compilation"
make all-gcc install-gcc 
echo "Compilation terminée"

echo "Installation"
make all-target-libgcc install-target-libgcc 
echo "Installation gcc-bootstrap réussi" 

echo "Création d'un lien symbolique'"
ln -s $INSTALLDIR/lib/gcc/arm-none-linux-gnueabi/4.7.2/libgcc.a $INSTALLDIR/lib/gcc/arm-none-linux-gnueabi/4.7.2/libgcc_sh.a 


echo "Création des exports"
export CROSS=arm-none-linux-gnueabi
export CC=${CROSS}-gcc                          	 
export LD=${CROSS}-ld
export AS=${CROSS}-as
export AR=${CROSS}-ar
export PATH=$INSTALLDIR/bin:$PATH
export RANLIB=${CROSS}-ranlib



mkdir $BUILDIR/libc-header &&
cd $BUILDIR/libc-header
echo "Création d'un cache"
echo "libc_cv_forced_unwind=yes" > config.cache
echo "libc_cv_c_cleanup=yes" >> config.cache

echo "Configuration des headers de la eglibc"
../../sources/eglibc-2.16/libc/configure \
	--build=$BUILDMACH \
	--host=$TARGETMACH \
	--prefix=/usr \
	--with-headers=$SYSROOTDIR/usr/include \
	--config-cache \
	--enable-kernel=3.5.3 \
        --disable-profile --without-gd --without-cvs --enable-add-ons=ports,nptl 
echo "headers configurés"

echo "Compilation"			
make -k install-headers cross_compiling=yes install_root=$SYSROOTDIR
echo "Compilation terminée"

ln -s $INSTALLDIR/lib/gcc/arm-none-linux-gnueabi/4.7.2/libgcc.a $INSTALLDIR/lib/gcc/arm-none-linux-gnueabi/4.7.2/libgcc_eh.a 
ln -s $INSTALLDIR/lib/gcc/arm-none-linux-gnueabi/4.7.2/libgcc.a $INSTALLDIR/lib/gcc/arm-none-linux-gnueabi/4.7.2/libgcc_s.a 
echo "Compilation en-tete eglibc réussi"




mkdir $BUILDIR/eglibc
cd $BUILDIR/eglibc
echo "libc_cv_forced_unwind=yes" > config.cache
echo "libc_cv_c_cleanup=yes" >> config.cache
../../sources/eglibc-2.16/libc/configure \
	--build=$BUILDMACH \
	--host=$TARGETMACH \
	--prefix=/usr \
	--with-headers=$SYSROOTDIR/usr/include \
	--config-cache \
	--enable-kernel=3.5.3 \
    --disable-profile --without-gd --without-cvs --enable-add-ons=ports,nptl --with-tls

		
make -k install-headers cross_compiling=yes install_root=$SYSROOTDIR	
make -j$THREADS
make install_root=$SYSROOTDIR install

echo "Compilation eglibc réussi"





unset CROSS
unset CC
unset LD
unset AR
unset AS

# GCC

mkdir $BUILDIR/gcc
cd $BUILDIR/gcc
export CC=gcc
echo "libc_cv_forced_unwind=yes" > config.cache
echo "libc_cv_c_cleanup=yes" >> config.cache
../../sources/$GCC/configure \
	--build=$BUILDMACH \
	--target=$TARGETMACH \
	--prefix=$INSTALLDIR \
	--with-sysroot=$SYSROOTDIR \
	--enable-languages=c \
	--with-float=soft \
	--disable-sjlj-exceptions \
	--disable-nls \
	--enable-threads=posix \
	--disable-libmudflap \
	--disable-libssp \
	--with-gnu-as \
	--with-gnu-ld \
	--disable-multilib \
	--enable-long-longx	

make all-gcc
make install-gcc
echo "Compilation gcc réussi $NORMAL"



cd
cd MaEgCross/


