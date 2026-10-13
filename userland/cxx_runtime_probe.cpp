/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Exercise the real GNU C++ runtime linked against RV32-musl on XNU.
 */
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <memory>
#include <numeric>
#include <sstream>
#include <stdexcept>
#include <string>
#include <typeinfo>
#include <vector>
#include <sys/wait.h>
#include <unistd.h>

#define CHECK(test) do { if (!(test)) { \
    std::printf("[native-cxx] FAIL line=%d: %s\n", __LINE__, #test); \
    return 1; } } while (0)
static unsigned constructed, destroyed;
static bool finished, child_mode;
static thread_local unsigned tls_value = 37;
struct Startup {
    Startup() { constructed = 1; }
    ~Startup() {
        if (!finished || constructed != 1) {
            std::puts("[native-cxx] FAIL global destructor state");
            _exit(87);
        }
        if (!child_mode) std::puts("[native-cxx-gate-D] CRT global constructor destructor fork-exec reinitialization PASS");
    }
} startup;
struct Cleanup { ~Cleanup() { destroyed++; } };
struct Base { virtual ~Base() {} };
struct Derived : Base { int value; explicit Derived(int n) : value(n) {} };
__attribute__((noinline)) static void throw_across_frame(unsigned n)
{
    Cleanup cleanup;
    std::string text = "Syllable native C++ " + std::to_string(n);
    if ((n & 1) == 0) throw std::runtime_error(text);
    throw n;
}
int main(int argc, char **argv)
{
    std::setvbuf(stdout, 0, _IONBF, 0);
    CHECK(constructed == 1 && destroyed == 0 && tls_value == 37);
    if (argc == 2 && !std::strcmp(argv[1], "child")) {
        child_mode = true;
        std::string value(8192, 'c');
        CHECK(value.size() == 8192 && value.at(8191) == 'c');
        finished = true;
        return 0;
    }
    {
        std::vector<int> numbers;
        std::map<std::string, unsigned> values;
        std::string text;
        for (unsigned i = 0; i < 1024; i++) {
            numbers.push_back(1023 - i);
            text += char('a' + i % 26);
            values[std::to_string(i)] = i;
        }
        std::sort(numbers.begin(), numbers.end());
        CHECK(std::accumulate(numbers.begin(), numbers.end(), 0U) == 523776U);
        CHECK(text.size() == 1024 && text.substr(0, 3) == "abc" && values.at("1023") == 1023);
        std::ostringstream output;
        output << "RV" << 32 << ':' << values.size();
        CHECK(output.str() == "RV32:1024");
        std::unique_ptr<Base> object(new Derived(32));
        CHECK(dynamic_cast<Derived *>(object.get()) && dynamic_cast<Derived *>(object.get())->value == 32);
        CHECK(typeid(*object) == typeid(Derived));
    }
    std::puts("[native-cxx-gate-A] GNU string vector map sort streams allocator RTTI musl PASS");
    unsigned caught = 0;
    for (unsigned i = 0; i < 10000; i++) {
        try {
            throw_across_frame(i);
        } catch (const std::runtime_error &error) {
            CHECK((i & 1) == 0 && std::string(error.what()) == "Syllable native C++ " + std::to_string(i));
            caught++;
        } catch (unsigned value) {
            CHECK((i & 1) == 1 && value == i);
            caught++;
        }
    }
    CHECK(caught == 10000 && destroyed == 10000);
    bool bounds = false;
    try { std::vector<int>().at(1); } catch (const std::out_of_range &) { bounds = true; }
    CHECK(bounds);
    std::puts("[native-cxx-gate-B] DWARF unwind exceptions=10000 destructors=10000 out_of_range PASS");
    tls_value = 0x72763332U;
    for (unsigned i = 0; i < 16; i++) {
        pid_t child = fork(); CHECK(child >= 0);
        if (!child) {
            CHECK(tls_value == 0x72763332U);
            tls_value = 0;
            execl("/bin/cxx-runtime-probe", "cxx-runtime-probe", "child", (char *)0);
            _exit(88);
        }
        int status;
        CHECK(waitpid(child, &status, 0) == child && WIFEXITED(status) && WEXITSTATUS(status) == 0);
    }
    CHECK(destroyed == 10000 && tls_value == 0x72763332U);
    std::puts("[native-cxx-gate-C] independent static C++ exec cycles=16 parent heap TLS isolated and reset PASS");
    finished = true;
    std::puts("[native-cxx] gates A-C PASS; D requires the real exit destructor");
    return 0;
}
