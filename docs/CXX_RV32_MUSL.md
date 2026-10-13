# GNU C++ Runtime on XNU RV32

The installed GCC 15.1.0 compiler supports RV32IMAC, but its bundled libstdc++
is configured for newlib. Using it with musl by inventing `_impure_ptr` or
mixing FILE layouts would not be a sound port. This profile builds unchanged
GNU libstdc++/libsupc++ sources against our actual musl sysroot.

```powershell
.\scripts\build-cxx-rv32.ps1 -Jobs 4
.\testproject.ps1 -Mode graphics -Smp 2 -NativeCxx
```

The preparer verifies the pinned GNU publisher SHA-512, records SHA-256 for
each selected input and refuses modified cached sources. The complete archive
is retained under ignored third_party, including its original license texts.
Configuration is static RV32 soft-float, generic locale and a single-thread
model. No GCC compiler rebuild is required for this initial profile.

The C++ wrapper excludes newlib C/C++ headers, uses musl C headers and exposes
only compiler-internal headers such as unwind.h. Linking uses musl crt1/crti,
matching RV32 GCC crtbegin/crtend and libgcc, and the newly built libstdc++.
The ordinary graphics decorator fallback runtime is not used by this test.

The independent executable verifies std::string/vector/map/sort/streams,
allocation, RTTI/dynamic_cast, 10,000 throws across a separate call frame,
10,000 unwind destructors, out_of_range, static initialization/finalization,
and 16 fork/exec cycles with heap and thread_local isolation/reinitialization.
The runner requires the real global exit destructor and Bash exit status zero.
It also runs native IPC, shared-area, private-VM, graphics/input/restart and
SMP kernel gates; no X11/Wayland service is started.

**TLS limitation:** this installed GCC was built with --disable-tls and
--disable-threads. C++ thread_local uses GNU emulated TLS and a single-thread
runtime, not ELF PT_TLS/native GUI threads. The runner records that actual
model and checks the emutls runtime when PT_TLS is absent. A native thread
port and suitable toolchain configuration remain required for AppServer's
multi-threaded execution. Header/function configure probes do not establish
that every corresponding kernel syscall or library facility works.

The optional executable is packaged in separate `build/initrd-cxx.img`.
The normal `build/initrd.img` remains unchanged; the C++ graphics runner loads
the selected image into the HFS+ initrd file before boot. Result metadata
hashes that actual selected image plus library/probe and GCC CRT/unwind inputs.
Normal graphics sessions require neither a C++ rebuild nor this extra image.

Gates/logs/captures use `build/graphics-tests/*-native-cxx/`. Profile/ABI errors
overwrite the latest result as FAIL instead of leaving a stale previous PASS.
The genuine Syllable Message/Looper/AppServer are still not compiled by this
profile; it supplies the real C++ prerequisite for that next work.
GNU licenses are retained. No new Release binary or paid service is created.
