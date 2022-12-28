git submodule update --init --recursive

curl -L https://github.com/ldc-developers/ldc/releases/download/v1.29.0/ldc2-1.29.0-windows-x64.7z --output ldc2-1.29.0-windows-x64.7z
7z x ldc2-1.29.0-windows-x64.7z
curl -L https://github.com/redthing1/dray/releases/download/v$env:DRAY_VERSION/raylib-dev_win64_msvc16.zip.zip --output raylib-dev_win64_msvc16.zip.zip
7z x raylib-dev_win64_msvc16.zip.zip
7z x raylib-dev_win64_msvc16.zip
curl -L https://github.com/redthing1/dray/releases/download/v4.0.0-r3/winlibs_extra.7z --output winlibs_extra.7z
7z x winlibs_extra.7z
curl -L https://github.com/glfw/glfw/releases/download/3.3.7/glfw-3.3.7.bin.WIN64.zip --output glfw-3.3.7.bin.WIN64.zip
unzip glfw-3.3.7.bin.WIN64.zip
move glfw-3.3.7.bin.WIN64/lib-vc2022/glfw3_mt.lib ./glfw3_mt.lib
cd ext
git clone --depth 1 https://github.com/redthing1/dray
cd dray
move ../../raylib-dev_win64_msvc16/lib/raylib.lib ./raylib.lib
move ../../WinMM.lib ./WinMM.lib
set WINLIB_BASE="../../ldc2-1.28.1-windows-x64/lib/"
set WINLIB_MINGW="../../ldc2-1.28.1-windows-x64/lib/mingw"
echo %WINLIB_BASE%
dub build --compiler ldc2 -B release

cd ../..

move ext/dray/WinMM.lib ./WinMM.lib