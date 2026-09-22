// Smoke test for the MinGW-w64 cross toolchain provisioned by pixi.
// Build on linux-64 with:  pixi run hello:x64  ->  .pixi/hello-win64.exe
#include <windows.h>
#include <cstdio>

int main() {
    MessageBoxA(NULL, "XXMI cross-compilation works.", "hello win64", MB_OK);
    std::printf("hello from a MinGW-w64 cross-compiled Windows binary\n");
    return 0;
}