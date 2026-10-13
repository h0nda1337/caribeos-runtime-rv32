/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Tests genuine Syllable String, not a GUI/String replacement.
 */
#include <util/string.h>
#include <atheos/types.h>
extern "C" {
#include <atheos/msgport.h>
}
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <sys/wait.h>
#include <unistd.h>

#define CHECK(test) do { if (!(test)) { \
    std::printf("[syllable-string] FAIL line=%d errno=%d: %s\n", __LINE__, errno, #test); \
    return 1; } } while (0)
static constexpr unsigned ROUNDS = 10000;
static os::String initial("genuine Syllable String CRT");

static bool child_ok(pid_t child)
{
    int status;
    return waitpid(child, &status, 0) == child && WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

static bool format_twice(os::String &a, os::String &b, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    try {
        a.Format(format, args);
        b.Format(format, args);
    } catch (...) {
        va_end(args);
        throw;
    }
    va_end(args);
    return a == b;
}

static os::String packet(unsigned sequence)
{
    os::String text;
    text.Format("Syllable/XNU:%08u:%08x:", sequence, sequence ^ 0x72763332U);
    if (sequence % 1000 == 0) text += std::string(5000, static_cast<char>('a' + sequence % 26));
    return text;
}

static int peer(port_id destination, port_id reply)
{
    CHECK(initial == "genuine Syllable String CRT");
    port_id own = create_port("syllable-string-peer", 1);
    CHECK(own > 0);
    CHECK(send_msg_x(reply, 0, &own, sizeof(own), 5000000) == 0);
    char input[8192];
    for (unsigned sequence = 0; sequence < ROUNDS; ++sequence) {
        uint32 code = 0;
        std::memset(input, 0x7f, sizeof(input));
        CHECK(get_msg_x(own, &code, input, sizeof(input), 5000000) == 0 && code == sequence);
        os::String expected = packet(sequence);
        CHECK(input[expected.Length()] == 0);
        os::String text(input, expected.Length());
        CHECK(text == expected);
        text += ":reply";
        CHECK(send_msg_x(destination, sequence, text.c_str(), text.Length() + 1, 5000000) == 0);
    }
    CHECK(delete_port(own) == 0);
    return 0;
}

static int basics()
{
    os::String empty, filled(4, 'x'), a("Caribe"), b(a), c(std::string("Syllable"));
    CHECK(empty.empty() && filled == "xxxx" && b == a && c.Length() == 8);
    CHECK(os::String(a, 1, 3) == "ari" && os::String(std::string("abcd"), 1, 2) == "bc");
    CHECK(os::String("abcd", 3) == "abc" && os::String(a.begin(), a.end()) == a);
    a += '-'; a += c; a += std::string("!"); a += "!";
    CHECK(a == "Caribe-Syllable!!" && (b + '!' + c) == "Caribe!Syllable");
    CHECK(a.find("Syllable") == 7 && a.find("missing") == static_cast<size_t>(os::String::npos));
    CHECK(a.substr(7, 8) == c && a.Compare("Caribe-Syllable!!") == 0);
    CHECK(b.Compare(std::string("Caribe")) == 0 && b.Compare(os::String("Caribe")) == 0);
    CHECK(b.CompareNoCase("caribe") == 0 && b.CompareNoCase(std::string("CARIBE")) == 0);
    CHECK(b.CompareNoCase(os::String("CARIBE")) == 0);
    CHECK(b < "Z" && b > "A" && b != "other" && b < std::string("Z"));
    CHECK(b > os::String("A") && b != std::string("other"));
    b[0] = 'c'; const os::String &constant = b; CHECK(constant[0] == 'c');
    b = std::string("abcde"); b.erase(1, 2); CHECK(b == "ade");
    b.erase(b.begin()); CHECK(b == "de"); b.erase(b.begin(), b.end()); CHECK(b.empty());
    b.reserve(9000); b.resize(6, 'z'); b.Resize(3); CHECK(b == "zzz");
    b.str() = "native"; const std::string &standard = b; CHECK(standard == b.const_str());
    CHECK(os::String("A\xc2\xa2\xe2\x82\xac\xf0\x9f\x98\x80").CountChars() == 4);
    const char binary[] = {'a', '\0', 'b'};
    CHECK(os::String(binary, 3).Length() == 3);
    bool caught = false;
    try { (void)b.substr(b.Length() + 1); } catch (const std::out_of_range &) { caught = true; }
    CHECK(caught);
    std::puts("[syllable-string-gate-A] genuine upstream constructors operators find UTF8 proxy API PASS");
    return 0;
}

static int hardening()
{
    for (unsigned i = 0; i < ROUNDS; ++i) {
        os::String empty, whitespace(" \t\r\n "), text(" \tCaribeOS\n\t ");
        CHECK(empty.RStrip().LStrip().Strip().empty());
        CHECK(whitespace.RStrip().empty());
        CHECK(os::String(" \t ").LStrip().empty());
        CHECK(text.Strip() == "CaribeOS");
        CHECK(text.Lower() == "caribeos" && text.Upper() == "CARIBEOS");
    }
    os::String high("\xff\x80 a \xff"); high.Strip().Lower().Upper();
    CHECK(static_cast<unsigned char>(high[0]) == 255 && static_cast<unsigned char>(high[1]) == 128);
    std::string large(6000, 'q');
    os::String a("unchanged"), b;
    CHECK(format_twice(a, b, "%s:%08x:%d:%s", large.c_str(), 0x72763332U, -17, "tail"));
    CHECK(a.Length() == 6018 && a.substr(6000) == ":72763332:-17:tail");
    a.Format("%c%c%c", 'a', 0, 'b'); CHECK(a.Length() == 3 && a[1] == 0 && a[2] == 'b');
    a = "unchanged";
    bool caught = false;
    try { a.Format("%"); } catch (const std::runtime_error &) { caught = true; }
    CHECK(caught && a == "unchanged");
    std::puts("[syllable-string-gate-B] trim=10000 empty all-space signed-ctype va-copy large-format error-preservation PASS");
    return 0;
}

static int lifecycle()
{
    initial = "parent String state";
    for (unsigned i = 0; i < 16; ++i) {
        pid_t child = fork(); CHECK(child >= 0);
        if (child == 0) {
            if (initial != "parent String state") _exit(12);
            initial = "isolated child String state";
            execl("/bin/syllable-string-probe", "syllable-string-probe", "--lifecycle", nullptr);
            _exit(13);
        }
        CHECK(child_ok(child) && initial == "parent String state");
    }
    std::puts("[syllable-string-gate-C] genuine String heap CRT fork-exec=16 isolation reinitialization PASS");
    return 0;
}

static int transport()
{
    port_id receive = create_port("syllable-string-server", 1);
    port_id handshake = create_port("syllable-string-handshake", 1);
    CHECK(receive > 0 && handshake > 0);
    char server[32], reply[32];
    std::snprintf(server, sizeof(server), "%d", receive);
    std::snprintf(reply, sizeof(reply), "%d", handshake);
    pid_t child = fork(); CHECK(child >= 0);
    if (child == 0) {
        execl("/bin/syllable-string-probe", "syllable-string-probe", "--peer", server, reply, nullptr);
        _exit(14);
    }
    port_id destination = -1;
    uint32 code = 0;
    CHECK(get_msg_x(handshake, &code, &destination, sizeof(destination), 5000000) == 0 && code == 0);
    CHECK(destination > 0 && delete_port(handshake) == 0);
    char input[8192];
    for (unsigned sequence = 0; sequence < ROUNDS; ++sequence) {
        os::String text = packet(sequence);
        CHECK(send_msg_x(destination, sequence, text.c_str(), text.Length() + 1, 5000000) == 0);
        std::memset(input, 0x7f, sizeof(input));
        CHECK(get_msg_x(receive, &code, input, sizeof(input), 5000000) == 0 && code == sequence);
        os::String expected = text + ":reply";
        CHECK(input[expected.Length()] == 0 && os::String(input, expected.Length()) == expected);
    }
    CHECK(child_ok(child) && delete_port(receive) == 0);
    std::puts("[syllable-string-gate-D] independent exec String/native-port rounds=10000 large-messages=10 PASS");
    return 0;
}

int main(int argc, char **argv)
{
    try {
        if (argc == 2 && std::strcmp(argv[1], "--lifecycle") == 0)
            return initial == "genuine Syllable String CRT" && os::String(8192, 's').Length() == 8192 ? 0 : 15;
        if (argc == 4 && std::strcmp(argv[1], "--peer") == 0)
            return peer(static_cast<port_id>(std::strtol(argv[2], nullptr, 10)),
                        static_cast<port_id>(std::strtol(argv[3], nullptr, 10)));
        CHECK(initial == "genuine Syllable String CRT");
        CHECK(basics() == 0 && hardening() == 0 && lifecycle() == 0 && transport() == 0);
        std::puts("[syllable-string] genuine Syllable String gates A-D PASS; native XNU, no Wayland/X11");
        return 0;
    } catch (const std::exception &error) {
        std::printf("[syllable-string] FAIL uncaught exception: %s\n", error.what());
        return 1;
    }
}
