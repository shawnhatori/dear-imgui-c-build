# Dear ImGui C Build
Dear ImGui C Build gets the latest versions of
[dear_imgui](https://github.com/ocornut/imgui) and
[dear_bindings](https://github.com/dearimgui/dear_bindings), and uses them to
generate C bindings for Dear ImGui. These bindings, along with Dear ImGui
source, are then compiled into a C-compatible static library. Unique static
libraries are created for the Win32 platform backend with each of the DX11,
DX12, OpenGL3, and Vulkan graphics API backends, as well as debug and
production (i.e. `-MTd` vs `-MT`).

## Requirements
* Git
* Python 3.8x+ (required for Dear Bindings)
* Microsoft Visual C++ (MSVC)
* Optional: Vulkan SDK (required for Vulkan backend)

## Usage
```
build
```
The build script will clone the required projects (or update them if they
already exist), generate the bindings, and run the compiler for all backend
permutations. For each graphics API, the resulting `build` directory contains
the `.h` headers to include and the `.lib` static library to link against in a
C application.
