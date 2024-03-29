@echo off

setlocal enabledelayedexpansion

rem -l: Build based on the local state of the repositories (no git)
set local_build=
:args
if "%1" neq "" (
    if "%1"=="-l" (
        set local_build=1
    )
    SHIFT
    GOTO :args
)

if not exist build\ (
    mkdir build\
)

if not defined local_build (
    if not exist imgui\ (
        git clone git@github.com:ocornut/imgui.git
    ) else (
        pushd imgui\
        git pull > nul
        popd
    )
)
copy imgui\*.cpp build\ > nul
copy imgui\*.h build\ > nul
copy imgui\backends\imgui_impl_win32* build\ > nul

if not defined local_build (
    if not exist dear_bindings\ (
        git clone git@github.com:dearimgui/dear_bindings.git
    ) else (
        pushd dear_bindings\
        git pull > nul
        popd
    )
)

rem NOTE: PLY is a required dependency of Dear Bindings.
if not defined local_build (
    if not exist ply\ (
        git clone git@github.com:dabeaz/ply.git
    ) else (
        pushd ply\
        git pull > nul
        popd
    )
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
    lib *.obj -nologo -OUT:cimgui_win32_%%g_debug.lib
    del /q *.obj

    rem -MT: Statically link MSVC CRT
    cl imgui*.cpp cimgui*.cpp !compiler_flags! -MT
    lib *.obj -nologo -OUT:cimgui_win32_%%g.lib
    del /q *.obj

    del /q imgui_impl_%%g*
    del /q cimgui_impl_%%g*.cpp
)
del /q *.cpp
del /q *.json
del /q imgui*.*
del /q imstb*.*
popd

endlocal
