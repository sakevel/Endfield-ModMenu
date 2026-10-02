#include "zml_plugin.h"
#include <Windows.h>
#include <wincrypt.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
namespace {
void check(bool value, const char* message) { if (!value) throw std::runtime_error(message); }
ZmlLuaTransform registered = nullptr;
void* userdata = nullptr;
int registrations = 0;
void log(void*, const char*) {}
int subscribe(void*, const char* path, ZmlLuaTransform fn, void* data) {
    if (std::string(path) != "UI/Panels/Watch/WatchCtrl") return 0;
    registered = fn; userdata = data; ++registrations; return 1;
}
void sink(void* output, const char* data, size_t size) { static_cast<std::string*>(output)->assign(data, size); }
}
int main(int argc, char** argv) { try {
    check(argc == 2, "Expected built DLL path");
    auto dll_path = std::filesystem::absolute(argv[1]);
    auto dll = LoadLibraryW(dll_path.c_str()); check(dll != nullptr, "LoadLibrary failed");
    auto entry = reinterpret_cast<ZmlPluginEntry>(GetProcAddress(dll, "ZML_PluginV1"));
    check(entry != nullptr, "Missing C ABI entry"); auto plugin = entry();
    check(plugin && plugin->abi == 1 && plugin->size == sizeof(ZmlPlugin), "Invalid descriptor");
    auto directory_u8 = dll_path.parent_path().u8string();
    std::string directory(reinterpret_cast<const char*>(directory_u8.data()), directory_u8.size());
    ZmlHost host{sizeof(ZmlHost), 1, nullptr, directory.c_str(), "", &log, &subscribe};
    check(!plugin->start(nullptr), "Null host rejected");
    auto invalid = host; invalid.abi = 99; check(!plugin->start(&invalid), "Invalid ABI rejected");
    auto absent = directory + "/absent-plugin-fixture"; invalid = host; invalid.mod_directory = absent.c_str();
    check(!plugin->start(&invalid) && registrations == 0, "Missing assets register no transform");
    check(plugin->start(&host) && registrations == 1 && registered, "Actual DLL initialized");
    const std::string source = "local RIGHT_BTN_ORDER = {}\ntable.sort(RIGHT_BTN_ORDER)\nself:BuildData()\nWatchCtrl._RelayoutRightList\nPhaseManager:OpenPhase(data.phaseId, data.openPhaseArg)\nHL.Commit(WatchCtrl)";
    std::string output;
    check(registered(userdata, source.data(), source.size(), &sink, &output) == 1, "Actual DLL transform");
    for (auto token : {"__ZML_WATCH_ICON__", "__ZML_NATIVE__", "__ZML_MODEL__"}) check(output.find(token) == output.npos, "No unresolved asset placeholders");
    const std::string prefix = "local watchData = \""; auto at = output.find(prefix);
    check(at != output.npos, "Dedicated ESC asset embedded"); at += prefix.size();
    auto end = output.find('"', at); check(end != output.npos, "Complete base64 literal");
    auto encoded = output.substr(at, end - at); DWORD size = 0;
    check(CryptStringToBinaryA(encoded.c_str(), static_cast<DWORD>(encoded.size()), CRYPT_STRING_BASE64, nullptr, &size, nullptr, nullptr) != 0, "Base64 size");
    std::string decoded(size, '\0');
    check(CryptStringToBinaryA(encoded.c_str(), static_cast<DWORD>(encoded.size()), CRYPT_STRING_BASE64, reinterpret_cast<BYTE*>(decoded.data()), &size, nullptr, nullptr) != 0, "Base64 decode");
    std::ifstream file(dll_path.parent_path() / "watch-icon.png", std::ios::binary);
    std::string expected{std::istreambuf_iterator<char>(file), {}};
    check(!expected.empty() && decoded == expected, "Actual DLL embeds exact dedicated PNG bytes");
    check(output.find("U.Color(49 / 255, 49 / 255, 49 / 255, 1)") != output.npos, "Exact ESC color emitted");
    auto before = output; check(!registered(userdata, "bad contract", 12, &sink, &output) && output == before, "Rejected contract has no sink mutation");
    FreeLibrary(dll); std::cout << "PASS: actual ModMenu DLL ABI/asset assembly/exact PNG/atomic transform\n"; return 0;
} catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; } }
