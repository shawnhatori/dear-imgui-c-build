#!/bin/bash

set -euo pipefail

show_usage() {
    cat << EOF
Usage: build.sh [OPTIONS] <project_dir>"

OPTIONAL FLAGS:
    -l            Build based on the local state of the repositories

REQUIRED ARGUMENTS:
    <project_dir> The absolute path to the target project directory
EOF

    exit 1
}

local_build=0
while getopts "l" o; do
    case "${o}" in
        l)
            local_build=1
            ;;
        \?)
            show_usage
            ;;
    esac
done
shift "$((OPTIND - 1))"

project_dir="${1:-"$PWD"}"
mkdir -p "$project_dir/build"

imgui_tag="v1.91.9b"
if [[ "$local_build" -eq 0 ]]; then
    if [[ ! -d "$project_dir/imgui" ]]; then
        pushd "$project_dir" > /dev/null
        git clone git@github.com:ocornut/imgui.git
        popd > /dev/null
    fi
    pushd "$project_dir/imgui" > /dev/null
    git checkout "tags/$imgui_tag" > /dev/null
    popd > /dev/null

    if [[ ! -d "$project_dir/dear_bindings" ]]; then
        pushd "$project_dir" > /dev/null
        git clone git@github.com:dearimgui/dear_bindings.git
        popd > /dev/null
    else
        pushd "$project_dir/dear_bindings" > /dev/null
        git pull > /dev/null
        popd > /dev/null
    fi

    # NOTE: PLY is a required dependency for Dear Bindings.
    if [[ ! -d "$project_dir/ply" ]]; then
        pushd "$project_dir" > /dev/null
        git clone git@github.com:dabeaz/ply.git
        popd > /dev/null
    fi
    pushd "$project_dir/ply" > /dev/null
    git checkout tags/3.11 > /dev/null
    popd > /dev/null
fi

cp "$project_dir/imgui/"*.cpp "$project_dir/build/"
cp "$project_dir/imgui/"*.h "$project_dir/build/"
cp "$project_dir/imgui/backends/imgui_impl_win32"* "$project_dir/build/"
cp -r "$project_dir/ply/ply/". "$project_dir/dear_bindings/ply/"

os=$(uname -s)
case "$os" in
    MINGW* | MSYS* | CYGWIN*)
        os="windows"
        ;;
    Linux*)
        os="linux"
        ;;
    *)
        os="unknown"
        echo "OS is not supported."
        exit 2
        ;;
esac

cl="clang-cl"
# cl="cl"
if [[ "$os" == "windows" ]]; then
    vulkan_sdk_dir="$VULKAN_SDK"
else
    vulkan_sdk_dir="$HOME/vulkan-sdk/x86_64"
fi
if [[ "$os" == "windows" ]]; then
    windows_sdk_dir="/c/WindowsSDK"
else
    windows_sdk_dir="$HOME/windows-sdk"
fi

# -std: Set language standard to C++14
# -D: Set preprocessor macro
# -Zi: Generate debug info (PDB)
# -Oi: Generate intrinsic functions
# -EHa-: Disable exceptions (C++)
# -GR-: Disable run-time type information (RTTI) (C++)
# -nologo: Suppress startup banner
# -O2: Enable performance optimizations
# -c: Compile without linking
cl_flags=(
    "-std:c++14"
    "-DWINDOWS"
    "-DUNICODE"
    "-Zi"
    "-Oi"
    "-EHa-"
    "-GR-"
    "-nologo"
    "-O2"
    "-c"
)
if [[ "$cl" == "clang-cl" ]]; then
    # --target: Set the compilation target (architecture-vendor-os-environment)
    # -fuse-ld: Set the linker
    # -vctoolsdir: Set the directory for the VC Tools CRT
    # -winsdkdir: Set the directory for the Windows SDK
    cl_flags+=(
        "--target=x86_64-pc-windows-msvc"
        "-fuse-ld=lld-link"
        "-vctoolsdir" "$windows_sdk_dir/crt"
        "-winsdkdir" "$windows_sdk_dir/sdk"
    )
fi
pushd "$project_dir/build" > /dev/null
echo ""
python ../dear_bindings/dear_bindings.py imgui.h --imconfig-path imconfig.h -o dcimgui
python ../dear_bindings/dear_bindings.py imgui_impl_win32.h --backend --include imgui.h --imconfig-path imconfig.h -o dcimgui_impl_win32
backends=(
    "dx11"
    "dx12"
    "vulkan"
)
for b in "${backends[@]}"; do
    cp "../imgui/backends/imgui_impl_$b"* .
    echo ""
    python ../dear_bindings/dear_bindings.py "imgui_impl_$b.h" --backend --include imgui.h --imconfig-path imconfig.h -o "dcimgui_impl_$b"

    # -MTd: Statically link debug MSVC CRT
    compile_lib=(
        "$cl"
        "imgui*.cpp"
        "dcimgui*.cpp"
        "${cl_flags[@]}"
        "-I$vulkan_sdk_dir/include"
        "-MTd"
    )
    "${compile_lib[@]}"
    lib *.obj -nologo "-OUT:dcimgui_win32_{$b}_debug.lib"
    rm -rf *.obj

    # -MT: Statically link MSVC CRT
    compile_lib[-1]="-MT"
    "${compile_lib[@]}"
    lib *.obj -nologo "-OUT:dcimgui_win32_$b.lib"
    rm -rf *.obj

    rm -rf "imgui_impl_$b"*
    rm -rf "dcimgui_impl_$b"*.cpp
done
rm -rf *.cpp
rm -rf *.json
rm -rf imgui*.*
rm -rf imstb*.*
popd > /dev/null
