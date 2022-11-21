BUILD_TYPE=silent

# override BUILD_TYPE with first arg
if [ $# -gt 0 ]; then
    BUILD_TYPE=$1
fi

echo "build configuration: $BUILD_TYPE"
git submodule update --init --recursive
dub build --compiler ldc2 -B release -c $BUILD_TYPE
