@echo off
for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe`) do (
    "%%i" StereovisionHacks.sln /p:Configuration=Release /p:Platform=x64 /m
    exit /b %errorlevel%
)
echo ERROR: Could not find MSBuild. Please install Visual Studio with C++ build tools.
exit /b 1
