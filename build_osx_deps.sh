#!/usr/bin/env bash

# setup build directory
mkdir -p build/macosx64
mkdir -p junk

# update submodules
git submodule update --init --recursive

# download terra
cd junk
wget https://github.com/zdevito/terra/releases/download/release-2016-03-25/terra-OSX-x86_64-332a506.zip
unzip terra-OSX-x86_64-332a506.zip
cp -r terra-OSX-x86_64-332a506 ../terra

# Download SDL2
wget https://www.libsdl.org/release/SDL2-2.0.4.dmg
hdiutil attach SDL2-2.0.4.dmg
cp -r /Volumes/SDL2/SDL2.framework ../build/macosx64
hdiutil detach /Volumes/SDL2

cd ..
rm -r junk

# Build cimgui
cd thirdparty/cimgui/cimgui
make
cp cimgui.dylib ../../../build/macosx64/cimgui.dylib

cd ../../..

# Build nanovg and glut into libs dylib.
clang -c thirdparty/nanovg/src/nanovg.c -o build/macosx64/nanovg.o
clang -c thirdparty/include/glew.c -o build/macosx64/glew.o
clang -dynamiclib -undefined dynamic_lookup -fPIC -o build/macosx64/gamedeps.dylib build/macosx64/nanovg.o build/macosx64/glew.o
