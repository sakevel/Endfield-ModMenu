#include "patch.hpp"
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
namespace { void check(bool b, const char* m) { if (!b) throw std::runtime_error(m); }
std::string read(const char* p) { std::ifstream f(p,std::ios::binary); check(bool(f),"Missing fixture"); return {std::istreambuf_iterator<char>(f),{}}; } }
int main(int argc,char** argv) { try {
        std::string base = "local RIGHT_BTN_ORDER = {}\ntable.sort(RIGHT_BTN_ORDER)\nself:BuildData()\nWatchCtrl._RelayoutRightList\nPhaseManager:OpenPhase(data.phaseId, data.openPhaseArg)\nHL.Commit(WatchCtrl)";
        std::string result = "untouched";
        check(menu_mod::edit(base, "local ZMLModMenu = {}", result), "Current contract patched");
        check(result.find("RIGHT_BTN_ORDER[#RIGHT_BTN_ORDER + 1] = 93") != result.npos, "Slot registered");
        check(result.find("_G.ZMLModMenu.mount(self)") != result.npos, "Attachment inserted before snapshot");
        auto patched = result;
        check(!menu_mod::edit(patched, "extension", result) && result == patched, "No duplicate patch");
        for (auto anchor : {"self:BuildData()", "HL.Commit(WatchCtrl)", "table.sort(RIGHT_BTN_ORDER)"}) {
            auto broken = base; broken.erase(broken.find(anchor), std::string_view(anchor).size());
            check(!menu_mod::edit(broken, "extension", result) && result == patched, "Missing anchor is atomic");
            check(!menu_mod::edit(base + anchor, "extension", result) && result == patched, "Ambiguous anchor is atomic");
        }

        if(argc >= 3) { auto source=read(argv[1]), extension=read(argv[2]);
            check(menu_mod::edit(source,extension,result),"Actual current WatchCtrl accepted");
            if(argc >= 4) std::ofstream(argv[3],std::ios::binary)<<result;
        }
        std::cout<<"PASS: independent Mod patch atomicity / optional Watch fixture\n"; return 0;
    } catch(const std::exception& e) { std::cerr<<e.what()<<'\n';return 1; } }
