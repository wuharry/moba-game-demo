param([Parameter(Mandatory=$true)][string]$Script)
$ErrorActionPreference = 'Stop'
# Run with SysWOW64 WindowsPowerShell: use the already installed Lua 5.1 VM.
if ([IntPtr]::Size -ne 4) { throw 'This runner requires 32-bit WindowsPowerShell.' }
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LocalLua51 {
    const string Lib = @"C:\Program Files (x86)\BlueStacks X_msi5\plugins\lua\liblua_plugin.dll";
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool SetDllDirectory(string path);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr luaL_newstate();
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] public static extern void luaL_openlibs(IntPtr l);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] public static extern int luaL_loadfile(IntPtr l, string path);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] public static extern int lua_pcall(IntPtr l, int n, int r, int e);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr lua_tolstring(IntPtr l, int i, IntPtr len);
    [DllImport(Lib, CallingConvention=CallingConvention.Cdecl)] public static extern void lua_close(IntPtr l);
}
'@
if (-not [LocalLua51]::SetDllDirectory('C:\Program Files (x86)\BlueStacks X_msi5')) { throw 'Dependency search path failed.' }
$state = [LocalLua51]::luaL_newstate()
if ($state -eq [IntPtr]::Zero) { throw 'Lua state creation failed.' }
try {
    [LocalLua51]::luaL_openlibs($state)
    $result = [LocalLua51]::luaL_loadfile($state, (Resolve-Path -LiteralPath $Script).Path)
    if ($result -eq 0) { $result = [LocalLua51]::lua_pcall($state, 0, -1, 0) }
    if ($result -ne 0) {
        $message = [Runtime.InteropServices.Marshal]::PtrToStringAnsi([LocalLua51]::lua_tolstring($state, -1, [IntPtr]::Zero))
        throw $message
    }
} finally {
    [LocalLua51]::lua_close($state)
}
