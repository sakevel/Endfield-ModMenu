#include "zml_plugin.h"
#include "patch.hpp"
#include <Windows.h>
#include <filesystem>
#include <fstream>
#include <iterator>
namespace {
const ZmlHost* services = nullptr;
std::string extension;
int transform(void*, const char* source, size_t length, ZmlSink sink, void* writer) {
    try {
        std::string result;
        if (!menu_mod::edit(std::string_view(source, length), extension, result)) {
            services->log(services->owner, "WatchCtrl contract rejected/already patched; no partial changes"); return 0;
        }
        sink(writer, result.data(), result.size()); return 1;
    } catch (const std::exception& e) { services->log(services->owner, e.what()); return 0; }
}
int start(const ZmlHost* host) {
    if (!host || host->size != sizeof(ZmlHost) || host->abi != 1) return 0;
    services = host;
    try {
        auto file = std::filesystem::path(std::u8string(reinterpret_cast<const char8_t*>(host->mod_directory))) / L"mod-menu.lua";
        if (std::filesystem::file_size(file) > 128 * 1024) return 0;
        std::ifstream stream(file, std::ios::binary);
        extension.assign(std::istreambuf_iterator<char>(stream), {});
        if (extension.empty()) return 0;
        const std::string token = "__ZML_MODEL__";
        auto at = extension.find(token);
        if (at == extension.npos || extension.find(token, at + token.size()) != extension.npos) return 0;
        auto model_file = file.parent_path() / L"model.lua";
        if (std::filesystem::file_size(model_file) > 32 * 1024) return 0;
        std::ifstream model_stream(model_file, std::ios::binary);
        std::string model{std::istreambuf_iterator<char>(model_stream), {}};
        if (model.empty()) return 0;
        extension.replace(at, token.size(), "(function()\n" + model + "\nend)()");
        const std::string native_token = "__ZML_NATIVE__";
        at = extension.find(native_token);
        if (at == extension.npos || extension.find(native_token, at + native_token.size()) != extension.npos) return 0;
        auto native_file = file.parent_path() / L"native-ui.lua";
        if (std::filesystem::file_size(native_file) > 64 * 1024) return 0;
        std::ifstream native_stream(native_file, std::ios::binary);
        std::string native{std::istreambuf_iterator<char>(native_stream), {}};
        if (native.empty()) return 0;
        extension.replace(at, native_token.size(), "(function()\n" + native + "\nend)()");
        return host->transform_lua(host->owner, "UI/Panels/Watch/WatchCtrl", &transform, nullptr);
    } catch (const std::exception& e) { host->log(host->owner, e.what()); return 0; }
}
const ZmlPlugin descriptor{sizeof(ZmlPlugin), 1, "mod-menu", &start};
}
extern "C" __declspec(dllexport) const ZmlPlugin* ZML_PluginV1() { return &descriptor; }
