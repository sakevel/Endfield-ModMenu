#include "zml_plugin.h"
#include "patch.hpp"
#include <Windows.h>
#include <wincrypt.h>
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
            services->log(services->owner, "WatchCtrl patch rejected"); return 0;
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
        // Independent ESC alpha mask, not the multicolor registry icon.
        auto glyph_file = file.parent_path() / L"watch-icon.png";
        if (std::filesystem::file_size(glyph_file) > 64 * 1024) return 0;
        std::ifstream glyph_stream(glyph_file, std::ios::binary);
        std::string glyph{std::istreambuf_iterator<char>(glyph_stream), {}};
        if (glyph.size() < 33 || glyph.substr(0, 8) != std::string("\x89PNG\r\n\x1a\n", 8)) return 0;
        DWORD encoded_size = 0;
        constexpr DWORD flags = CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF;
        if (!CryptBinaryToStringA(reinterpret_cast<const BYTE*>(glyph.data()), static_cast<DWORD>(glyph.size()), flags, nullptr, &encoded_size)) return 0;
        std::string encoded(encoded_size, '\0');
        if (!CryptBinaryToStringA(reinterpret_cast<const BYTE*>(glyph.data()), static_cast<DWORD>(glyph.size()), flags, encoded.data(), &encoded_size)) return 0;
        while (!encoded.empty() && encoded.back() == '\0') encoded.pop_back();
        const std::string glyph_token = "__ZML_WATCH_ICON__";
        auto glyph_at = native.find(glyph_token);
        if (glyph_at == native.npos || native.find(glyph_token, glyph_at + glyph_token.size()) != native.npos) return 0;
        native.replace(glyph_at, glyph_token.size(), "\"" + encoded + "\"");
        extension.replace(at, native_token.size(), "(function()\n" + native + "\nend)()");
        return host->transform_lua(host->owner, "UI/Panels/Watch/WatchCtrl", &transform, nullptr);
    } catch (const std::exception& e) { host->log(host->owner, e.what()); return 0; }
}
const ZmlPlugin descriptor{sizeof(ZmlPlugin), 1, "mod-menu", &start};
}
extern "C" __declspec(dllexport) const ZmlPlugin* ZML_PluginV1() { return &descriptor; }
