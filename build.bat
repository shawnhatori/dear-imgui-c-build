@echo off

setlocal enabledelayedexpansion

set project_dir=%~dp0

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

if not exist !project_dir!\build\ (
	mkdir !project_dir!\build\
)

if not defined local_build (
    if not exist !project_dir!\imgui\ (
        pushd !project_dir!
        git clone git@github.com:ocornut/imgui.git
        popd
    )
    pushd !project_dir!\imgui\
    git checkout tags/v1.91.9b
    popd
)
copy !project_dir!\imgui\*.cpp !project_dir!\build\ > nul
copy !project_dir!\imgui\*.h !project_dir!\build\ > nul
copy !project_dir!\imgui\backends\imgui_impl_win32* !project_dir!\build\ > nul

if not defined local_build (
    if not exist !project_dir!\dear_bindings\ (
        pushd !project_dir!
        git clone git@github.com:dearimgui/dear_bindings.git
        popd
    ) else (
        pushd !project_dir!\dear_bindings\
        git pull > nul
        popd
    )
)

rem NOTE: PLY is a required dependency of Dear Bindings.
if not defined local_build (
    if not exist ply\ (
        pushd !project_dir!
        git clone git@github.com:dabeaz/ply.git
        popd
    )
    pushd !project_dir!\ply\
    git checkout tags/3.11
    popd
)
xcopy /s /i /e /y !project_dir!\ply\ply !project_dir!\dear_bindings\ply > nul

pushd !project_dir!\build
python ..\dear_bindings\dear_bindings.py imgui.h --imconfig-path imconfig.h -o dcimgui
python ..\dear_bindings\dear_bindings.py imgui_impl_win32.h --backend --include imgui.h --imconfig-path imconfig.h -o dcimgui_impl_win32
for %%g in (dx11
            dx12
            vulkan
) do (
    copy ..\imgui\backends\imgui_impl_%%g* . > nul
    python ..\dear_bindings\dear_bindings.py imgui_impl_%%g.h --backend --include imgui.h --imconfig-path imconfig.h -o dcimgui_impl_%%g

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
    cl imgui*.cpp dcimgui*.cpp !compiler_flags! -MTd
    lib *.obj -nologo -OUT:dcimgui_win32_%%g_debug.lib
    del /q *.obj

    rem -MT: Statically link MSVC CRT
    cl imgui*.cpp dcimgui*.cpp !compiler_flags! -MT
    lib *.obj -nologo -OUT:dcimgui_win32_%%g.lib
    del /q *.obj

    del /q imgui_impl_%%g*
    del /q dcimgui_impl_%%g*.cpp
)
del /q *.cpp
del /q *.json
del /q imgui*.*
del /q imstb*.*
popd

endlocal
