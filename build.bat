@echo off

setlocal enabledelayedexpansion

if not exist build\ (
    mkdir build\
)

if not exist imgui\ (
    git clone git@github.com:ocornut/imgui.git
) else (
    pushd imgui\
    git pull > nul
    popd
)
copy imgui\*.cpp build\ > nul
copy imgui\*.h build\ > nul
copy imgui\backends\imgui_impl_win32* build\ > nul

if not exist dear_bindings\ (
    git clone git@github.com:dearimgui/dear_bindings.git
) else (
    pushd dear_bindings\
    git pull > nul
    popd
)

rem NOTE: PLY is a required dependency of Dear Bindings.
if not exist ply\ (
    git clone git@github.com:dabeaz/ply.git
) else (
    pushd ply\
    git pull > nul
    popd
)
xcopy /s /i /e /y ply\src\ply dear_bindings\ply > nul

pushd build
python ..\dear_bindings\dear_bindings.py imgui.h -o cimgui
python ..\dear_bindings\dear_bindings.py --backend imgui_impl_win32.h -o cimgui_impl_win32
for %%g in (dx11
            dx12
            opengl3
            vulkan
) do (
    copy ..\imgui\backends\imgui_impl_%%g* . > nul
    python ..\dear_bindings\dear_bindings.py --backend imgui_impl_%%g.h -o cimgui_impl_%%g
    if not exist %%g\ (
        mkdir %%g\
    )
    copy ..\imgui\imconfig.h %%g\ > nul

    rem -std: Set language standard to C++14
    rem -I: Set include dir path
    rem -O2: Enable performance optimizations
    rem -Oi: Generate intrinsic functions
    rem -EHa-: Disable exceptions (C++)
    rem -GR-: Disable run-time type information (RTTI) (C++)
    rem -c: Compile without linking
    rem -nologo: Suppress startup banner
    set compiler_flags=-std:c++14 -I!VULKAN_SDK!\Include\ -O2 -Oi -EHa -GR- -c -nologo

    rem -MTd: Statically link debug MSVC CRT
    cl imgui*.cpp cimgui*.cpp !compiler_flags! -MTd
    lib *.obj -nologo -OUT:%%g\cimgui_win32_%%g_debug.lib

    rem -MT: Statically link MSVC CRT
    cl imgui*.cpp cimgui*.cpp !compiler_flags! -MT
    lib *.obj -nologo -OUT:%%g\cimgui_win32_%%g.lib

    copy cimgui*.h %%g\ > nul
    copy cimgui*.json %%g\ > nul
    del /q imgui_impl_%%g*
    del /q cimgui_impl_%%g*
)
del /q *.*
popd

endlocal