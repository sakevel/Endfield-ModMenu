# ZML public SDK snapshot

Only `include/zml_plugin.h`, native ABI1, is vendored here. It is a public contract, not loader implementation.
Source: sibling Endfield-ModLoader `include/zml_plugin.h`, 2026-10-02.
SHA256: `7183439F463940759A650F19BB50C4DAF309B0C06D772A3A32009A3C1C60AE9D`.
The Mod builds using this snapshot alone; no loader sources, runtime DLL, MinHook or other project's code are linked.
Update intentionally when the SDK changes; never copy loader private implementation.
