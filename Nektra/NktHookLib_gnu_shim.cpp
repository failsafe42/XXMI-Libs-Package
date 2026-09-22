// GNU-ABI forwarding shim for the MSVC-built NktHookLib64.lib.
//
// The rest of this project is compiled with the Itanium C++ ABI
// (zig x86_64-windows-gnu), but Nektra ships NktHookLib64.lib as an
// MSVC-A BI static library.  Its object members only define the MSVC
// decorated symbols (?Hook@CNktHookLib@@...).  The C++ symbols referenced
// by this module's own sources are Itanium-mangled (_ZN11CNktHookLib...),
// so they can never resolve against the MSVC lib as-is.
//
// This TU defines the exact Itanium-mangled names that DLLMainHook.cpp,
// HookedDevice.cpp, HookedContext.cpp, lock.cpp and cursor.cpp reference
// and forwards every call one-to-one to the MSVC implementation.  The
// Win64 calling convention is shared between the two ABIs (this* in RCX,
// members slot into the normal parameter registers), so the forwarders are
// just ordinary functions calling the MSVC decorated symbols.

#include "NktHookLib.h"

// ------------------------------------------------------------------
// MSVC-decorated entry points provided by NktHookLib64.lib
// ------------------------------------------------------------------

extern "C" void* NKT_fwd_Ctor(void* pThis) __asm__("??0CNktHookLib@@QEAA@XZ");
extern "C" void  NKT_fwd_Dtor(void* pThis) __asm__("??1CNktHookLib@@QEAA@XZ");
extern "C" unsigned long NKT_fwd_Hook1(void* pThis, unsigned long long* lpHookId, void** lpCallOriginal,
                                       void* lpProcToHook, void* lpNewProcAddr, unsigned long dwFlags)
    __asm__("?Hook@CNktHookLib@@QEAAKPEA_KPEAPEAXPEAX2K@Z");
extern "C" void NKT_fwd_UnhookAll(void* pThis) __asm__("?UnhookAll@CNktHookLib@@QEAAXXZ");
extern "C" unsigned long NKT_fwd_SetEnableDebugOutput(void* pThis, int bEnable)
    __asm__("?SetEnableDebugOutput@CNktHookLib@@QEAAKH@Z");

extern "C" void* NKT_fwd_GetProcedureAddress(void* hDll, const char* szProcNameA)
    __asm__("?GetProcedureAddress@NktHookLibHelpers@@YAPEAXPEAUHINSTANCE__@@PEBD@Z");
extern "C" void* NKT_fwd_GetModuleBaseAddress(const wchar_t* szDllNameW)
    __asm__("?GetModuleBaseAddress@NktHookLibHelpers@@YAPEAUHINSTANCE__@@PEB_W@Z");
extern "C" void NKT_fwd_DebugVPrint(const char* szFormatA, char* argptr)
    __asm__("?DebugVPrint@NktHookLibHelpers@@YAXPEBDPEAD@Z");

// ------------------------------------------------------------------
// Itanium ABI definitions (these names are what the app references)
// ------------------------------------------------------------------

CNktHookLib::CNktHookLib()
{
    NKT_fwd_Ctor(this);
}

CNktHookLib::~CNktHookLib()
{
    NKT_fwd_Dtor(this);
}

DWORD CNktHookLib::Hook(__out SIZE_T* lpnHookId, __out LPVOID* lplpCallOriginal,
                        __in LPVOID lpProcToHook, __in LPVOID lpNewProcAddr, __in DWORD dwFlags)
{
    return (DWORD)NKT_fwd_Hook1(this, lpnHookId, lplpCallOriginal, lpProcToHook, lpNewProcAddr, dwFlags);
}

VOID CNktHookLib::UnhookAll()
{
    NKT_fwd_UnhookAll(this);
}

DWORD CNktHookLib::SetEnableDebugOutput(__in BOOL bEnable)
{
    return (DWORD)NKT_fwd_SetEnableDebugOutput(this, bEnable);
}

LPVOID NktHookLibHelpers::GetProcedureAddress(__in HINSTANCE hDll, __in LPCSTR szProcNameA)
{
    return NKT_fwd_GetProcedureAddress(hDll, szProcNameA);
}

HINSTANCE NktHookLibHelpers::GetModuleBaseAddress(__in_z LPCWSTR szDllNameW)
{
    return (HINSTANCE)NKT_fwd_GetModuleBaseAddress(szDllNameW);
}

VOID NktHookLibHelpers::DebugVPrint(__in LPCSTR szFormatA, __in va_list argptr)
{
    NKT_fwd_DebugVPrint(szFormatA, argptr);
}