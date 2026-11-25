// PeaZip Modern Shell Extension - independent companion to PeaZip.
// x64, Windows 11, C++17 / Windows SDK. No PeaZip code is embedded.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <shobjidl.h>
#include <shlwapi.h>
#include <shellapi.h>
#include <atomic>
#include <new>
#include <string>
#include <vector>
#include <cwchar>
#include <algorithm>

#pragma comment(lib, "Ole32.lib")
#pragma comment(lib, "Shell32.lib")
#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "Uuid.lib")

// Must match packaging/AppxManifest.xml
// {C8425781-09D3-4DEB-A947-30CD4509C7C4}
static constexpr CLSID CLSID_PeaZipMenu =
{ 0xC8425781, 0x09D3, 0x4DEB, {0xA9,0x47,0x30,0xCD,0x45,0x09,0xC7,0xC4} };

static std::atomic<long> g_active{0};
static std::atomic<long> g_locks{0};

// Exact ordering of the classic PeaZip Windows context menu.
// Test is an optional (disabled by default) extra after the extraction group.
enum class CommandId {
    Root, ExtractDialog, ExtractHere, ExtractSmart, ExtractNewFolder, Test,
    OpenAsArchive, BrowsePath, AddGUI, Add7Z, AddZIP, Encrypt7Z,
    Convert, HashTools
};
static constexpr CommandId kChildren[] = {
    CommandId::ExtractDialog, CommandId::ExtractHere, CommandId::ExtractSmart,
    CommandId::ExtractNewFolder, CommandId::Test,
    CommandId::OpenAsArchive, CommandId::BrowsePath,
    CommandId::AddGUI, CommandId::Add7Z, CommandId::AddZIP,
    CommandId::Encrypt7Z, CommandId::Convert, CommandId::HashTools
};
static constexpr ULONG kChildCount = sizeof(kChildren) / sizeof(kChildren[0]);

struct CommandSpec { CommandId id; const wchar_t* key; const wchar_t* label; int icon; bool shownDefault; };
static constexpr CommandSpec kSpecs[] = {
    {CommandId::ExtractDialog, L"ExtractDialog", L"Extract...", 4, true},
    {CommandId::ExtractHere, L"ExtractHere", L"Extract here", 4, true},
    {CommandId::ExtractSmart, L"ExtractSmart", L"Extract here (smart new folder)", 14, true},
    {CommandId::ExtractNewFolder, L"ExtractNewFolder", L"Extract here (in new folder)", 14, true},
    {CommandId::Test, L"Test", L"Test archive(s)", 1, false},
    {CommandId::OpenAsArchive, L"OpenAsArchive", L"Open as archive", -1, true},
    {CommandId::BrowsePath, L"BrowsePath", L"Browse path with PeaZip", 8, true},
    {CommandId::AddGUI, L"AddGUI", L"Add to archive", 2, true},
    {CommandId::Add7Z, L"Add7Z", L"Add to 7Z", 10, true},
    {CommandId::AddZIP, L"AddZIP", L"Add to ZIP", 13, true},
    {CommandId::Encrypt7Z, L"Encrypt7Z", L"Encrypt (7Z)", 0, true},
    {CommandId::Convert, L"Convert", L"Convert", 7, true},
    {CommandId::HashTools, L"HashTools", L"CRC, hash and file tools", 9, true},
};

static const CommandSpec* SpecFor(CommandId id) noexcept {
    for (const auto& spec : kSpecs) if (spec.id == id) return &spec;
    return nullptr;
}
static const wchar_t* GetLabel(CommandId id) noexcept {
    const auto* spec = SpecFor(id);
    return spec ? spec->label : L"PeaZip";
}
static DWORD GetDwordConfig(const wchar_t* subkey, const wchar_t* valueName, DWORD fallback) {
    DWORD val = fallback, bytes = sizeof(val);
    auto status = RegGetValueW(HKEY_CURRENT_USER, subkey, valueName,
                               RRF_RT_REG_DWORD, nullptr, &val, &bytes);
    return status == ERROR_SUCCESS ? val : fallback;
}
static bool IsCommandShown(CommandId id) {
    const auto* spec = SpecFor(id);
    if (!spec) return true;
    return GetDwordConfig(L"Software\\PeaZipModernMenu\\Commands", spec->key,
                          spec->shownDefault ? 1 : 0) != 0;
}
// Stable REG_SZ serialization, shared with PeaZipMenuConfig.exe.
// Unknown/duplicate keys are discarded, missing keys appended in classic order.
// This makes the configuration forward/backward-compatible with v1.1.x.
static std::vector<CommandId> OrderedChildren() {
    std::vector<CommandId> result;
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\PeaZipModernMenu", 0,
                      KEY_QUERY_VALUE, &key) == ERROR_SUCCESS) {
        DWORD type = 0, bytes = 0;
        LONG status = RegQueryValueExW(key, L"CommandOrder", nullptr, &type,
                                       nullptr, &bytes);
        if (status == ERROR_SUCCESS && type == REG_SZ &&
            bytes >= sizeof(wchar_t) && bytes <= 8192) {
            std::wstring str(bytes / sizeof(wchar_t) + 1, L'\0');
            status = RegQueryValueExW(key, L"CommandOrder", nullptr, &type,
                                      reinterpret_cast<BYTE*>(str.data()), &bytes);
            if (status == ERROR_SUCCESS) {
                str.resize(wcsnlen_s(str.c_str(), str.size()));
                size_t begin = 0;
                while (begin <= str.size()) {
                    size_t end = str.find(L';', begin);
                    if (end == std::wstring::npos) end = str.size();
                    const auto token = str.substr(begin, end - begin);
                    for (const auto& spec : kSpecs) {
                        if (token == spec.key &&
                            std::find(result.begin(), result.end(), spec.id) == result.end()) {
                            result.push_back(spec.id);
                            break;
                        }
                    }
                    if (end == str.size()) break;
                    begin = end + 1;
                }
            }
        }
        RegCloseKey(key);
    }
    for (auto id : kChildren) {
        if (std::find(result.begin(), result.end(), id) == result.end())
            result.push_back(id);
    }
    return result;
}

// Separators are computed by transitions between adjacent *visible* groups
// in the user's custom order. Never insert a leading separator.

static int CommandGroup(CommandId id) noexcept {
    if (id == CommandId::HashTools) return 3;
    if (id == CommandId::AddGUI || id == CommandId::Add7Z ||
        id == CommandId::AddZIP || id == CommandId::Encrypt7Z ||
        id == CommandId::Convert) return 2;
    if (id == CommandId::OpenAsArchive || id == CommandId::BrowsePath) return 1;
    return 0;
}
static bool IsNewGroup(CommandId id) {
    if (GetDwordConfig(L"Software\\PeaZipModernMenu", L"ShowSeparators", 1) == 0)
        return false;
    int priorGroup = -1;
    for (auto current : OrderedChildren()) {
        if (!IsCommandShown(current)) continue;
        const int group = CommandGroup(current);
        if (current == id) return priorGroup >= 0 && priorGroup != group;
        priorGroup = group;
    }
    return false;
}

static HRESULT DupString(const std::wstring& in, PWSTR* out) noexcept {
    if (!out) return E_POINTER;
    *out = nullptr;
    const size_t bytes = (in.size() + 1) * sizeof(wchar_t);
    auto* p = static_cast<PWSTR>(CoTaskMemAlloc(bytes));
    if (!p) return E_OUTOFMEMORY;
    memcpy(p, in.c_str(), bytes);
    *out = p;
    return S_OK;
}

static bool IsRegularFile(const std::wstring& path) noexcept {
    DWORD attr = GetFileAttributesW(path.c_str());
    return attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY);
}

static std::wstring GetEnvironment(const wchar_t* key) {
    const DWORD length = GetEnvironmentVariableW(key, nullptr, 0);
    if (length == 0 || length > 32768) return L"";
    std::wstring value(length, L'\0');
    DWORD written = GetEnvironmentVariableW(key, value.data(), length);
    if (!written || written >= length) return L"";
    value.resize(written);
    return value;
}

static std::wstring ReadConfiguredExecutable() {
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\PeaZipModernMenu", 0,
                      KEY_QUERY_VALUE, &key) != ERROR_SUCCESS) return L"";
    DWORD type = 0, bytes = 0;
    LONG status = RegQueryValueExW(key, L"ExecutablePath", nullptr, &type, nullptr, &bytes);
    if (status != ERROR_SUCCESS || (type != REG_SZ && type != REG_EXPAND_SZ) ||
        bytes < sizeof(wchar_t) || bytes > 65536) {
        RegCloseKey(key); return L"";
    }
    std::wstring value(bytes / sizeof(wchar_t) + 1, L'\0');
    status = RegQueryValueExW(key, L"ExecutablePath", nullptr, &type,
                              reinterpret_cast<BYTE*>(value.data()), &bytes);
    RegCloseKey(key);
    if (status != ERROR_SUCCESS) return L"";
    value.resize(wcsnlen_s(value.c_str(), value.size()));
    if (type == REG_EXPAND_SZ) {
        DWORD needed = ExpandEnvironmentStringsW(value.c_str(), nullptr, 0);
        if (needed && needed <= 32768) {
            std::wstring expanded(needed, L'\0');
            DWORD wrote = ExpandEnvironmentStringsW(value.c_str(), expanded.data(), needed);
            if (wrote && wrote <= needed) {
                expanded.resize(wcsnlen_s(expanded.c_str(), expanded.size()));
                return expanded;
            }
        }
    }
    return value;
}

static std::wstring LocatePeaZip() {
    // User-configured path always wins (portable installations supported).
    const auto configured = ReadConfiguredExecutable();
    if (IsRegularFile(configured)) return configured;
    const auto pfiles = GetEnvironment(L"ProgramFiles");
    const auto pfilesx86 = GetEnvironment(L"ProgramFiles(x86)");
    for (const auto& base : {pfiles, pfilesx86}) {
        if (!base.empty()) {
            std::wstring candidate = base + L"\\PeaZip\\peazip.exe";
            if (IsRegularFile(candidate)) return candidate;
        }
    }
    return L"";
}

// Quote one Windows command-line argument using the standard
// CommandLineToArgvW/CreateProcess backslash-and-quote rules.
static std::wstring QuoteArgument(const std::wstring& raw) {
    std::wstring quoted;
    quoted.reserve(raw.size() + 2);
    quoted += L'"';
    size_t slashes = 0;
    for (wchar_t c : raw) {
        if (c == L'\\') { ++slashes; continue; }
        if (c == L'"') {
            quoted.append(slashes * 2 + 1, L'\\');
            quoted += c;
        } else {
            quoted.append(slashes, L'\\');
            quoted += c;
        }
        slashes = 0;
    }
    quoted.append(slashes * 2, L'\\');
    quoted += L'"';
    return quoted;
}

static HRESULT ReadPaths(IShellItemArray* selection, std::vector<std::wstring>& result) {
    if (!selection) return E_INVALIDARG;
    DWORD n = 0;
    HRESULT hr = selection->GetCount(&n);
    if (FAILED(hr)) return hr;
    if (!n) return E_INVALIDARG;
    // Avoid very large allocations in Explorer. Limit is documented in README.
    if (n > 4096) return HRESULT_FROM_WIN32(ERROR_TOO_MANY_NAMES);
    result.reserve(n);
    for (DWORD i = 0; i < n; ++i) {
        IShellItem* item = nullptr;
        hr = selection->GetItemAt(i, &item);
        if (FAILED(hr)) return hr;
        PWSTR path = nullptr;
        hr = item->GetDisplayName(SIGDN_FILESYSPATH, &path);
        item->Release();
        if (FAILED(hr)) return hr; // Virtual items deliberately unsupported.
        if (!path || !*path) { CoTaskMemFree(path); return E_INVALIDARG; }
        result.emplace_back(path);
        CoTaskMemFree(path);
    }
    return S_OK;
}

// Fast file-extension classification: no file I/O or content inspection on the UI thread.
// This is intentionally conservative; "Open as archive" always remains available
// for archives without a standard extension or unusual archive formats.
static bool LooksLikeArchive(const std::wstring& name) {
    const wchar_t* suffixes[] = {
        L".zip",L".zipx",L".7z",L".rar",L".r00",L".r01",L".tar",
        L".gz",L".tgz",L".bz2",L".tbz",L".tbz2",L".xz",L".txz",
        L".zst",L".tzst",L".z",L".cab",L".iso",L".udf",L".wim",
        L".swm",L".arj",L".lzh",L".lha",L".ace",L".arc",L".pea",
        L".zpaq",L".paq",L".deb",L".rpm",L".cpio",L".dmg",L".hfs",
        L".001",L".002",L".img",L".apk",L".jar",L".war",L".ear",
        L".epub",L".cbz",L".cbr",L".xpi",L".crx",L".squashfs"
    };
    for (const auto* ext : suffixes) {
        size_t n = wcslen(ext);
        if (name.size() >= n && _wcsicmp(name.c_str() + name.size() - n, ext) == 0)
            return true;
    }
    return false;
}
static bool IsExtractionCommand(CommandId id) noexcept {
    return id == CommandId::ExtractDialog || id == CommandId::ExtractHere ||
           id == CommandId::ExtractSmart || id == CommandId::ExtractNewFolder ||
           id == CommandId::Test;
}
static HRESULT GetExtractionState(IShellItemArray* items, EXPCMDSTATE* state) {
    // For all other commands there is no need to read the selection.
    if (!items || !state) return S_OK;
    if (GetDwordConfig(L"Software\\PeaZipModernMenu", L"DetectArchives", 1) == 0)
        return S_OK;
    DWORD count = 0;
    if (FAILED(items->GetCount(&count)) || count == 0) return S_OK;
    for (DWORD i = 0; i < count; ++i) {
        IShellItem* item = nullptr;
        if (FAILED(items->GetItemAt(i, &item))) return S_OK;
        PWSTR path = nullptr;
        HRESULT hr = item->GetDisplayName(SIGDN_FILESYSPATH, &path);
        item->Release();
        if (FAILED(hr) || !path) { CoTaskMemFree(path); return S_OK; }
        bool known = LooksLikeArchive(path);
        CoTaskMemFree(path);
        if (!known) { *state = ECS_DISABLED; break; }
    }
    return S_OK;
}

static HRESULT InvokePeaZip(CommandId id, IShellItemArray* selection) {
    std::vector<std::wstring> paths;
    HRESULT hr = ReadPaths(selection, paths);
    if (FAILED(hr)) return hr;
    auto exe = LocatePeaZip();
    if (exe.empty()) {
        MessageBoxW(nullptr,
                    L"peazip.exe was not found. Configure HKCU\\Software\\PeaZipModernMenu\\ExecutablePath.",
                    L"PeaZip Modern Menu", MB_OK | MB_ICONWARNING);
        return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
    }
    std::vector<std::wstring> args;
    switch (id) {
        // The COM menu supplies the entire multi-selection in ONE argv list.
        // PeaZip's -add2multi* switches are for registry-backed context menus
        // that aggregate independent single-item invocations via temporary files.
        // Use direct multi-path switches instead. PeaZip may directly create
        // an archive, instead of showing the legacy -add2multi* confirmation UI.
    case CommandId::ExtractDialog: args.push_back(L"-ext2main"); break;
    case CommandId::ExtractHere: args.push_back(L"-ext2herei"); break;
    case CommandId::ExtractSmart: args.push_back(L"-ext2folderi"); break;
    case CommandId::ExtractNewFolder: args.push_back(L"-ext2newfolder"); break;
    case CommandId::Test: args.push_back(L"-ext2test"); break;
    case CommandId::OpenAsArchive: args.push_back(L"-ext2browseasarchive"); break;
    case CommandId::BrowsePath: args.push_back(L"-ext2browsepath"); break;
    case CommandId::AddGUI: args.push_back(L"-add2archive"); break;
    case CommandId::Add7Z: args.push_back(L"-add27z"); break;
    case CommandId::AddZIP: args.push_back(L"-add2zip"); break;
    case CommandId::Encrypt7Z: args.push_back(L"-add2multi7zencrypt"); break;
    case CommandId::Convert: args.push_back(L"-add2multiconvert"); break;
    case CommandId::HashTools: {
        // The upstream 11.4.0 Inno Setup menu calls PEA.EXE PEAUTILS 12 "%1".
        // Its multi-selection contract is not documented: disable this entry for
        // multi-select instead of dropping paths or opening many windows.
        if (paths.size() != 1) return E_INVALIDARG;
        auto pos = exe.find_last_of(L"\\/");
        if (pos == std::wstring::npos) return E_FAIL;
        exe = exe.substr(0, pos + 1) + L"pea.exe";
        if (!IsRegularFile(exe)) return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
        args = {L"PEAUTILS", L"12"};
        break;
    }
    default: return E_INVALIDARG;
    }
    // All paths are marshalled as a single process invocation; no shell expansion.
    args.insert(args.end(), paths.begin(), paths.end());
    std::wstring line = QuoteArgument(exe);
    for (const auto& arg : args) {
        line += L' ';
        line += QuoteArgument(arg);
        if (line.size() >= 32760) {
            MessageBoxW(nullptr,
                        L"The selection exceeds the Windows command-line length limit.",
                        L"PeaZip Modern Menu", MB_OK | MB_ICONWARNING);
            return HRESULT_FROM_WIN32(ERROR_BUFFER_OVERFLOW);
        }
    }
    std::vector<wchar_t> mutableLine(line.begin(), line.end());
    mutableLine.push_back(L'\0');
    STARTUPINFOW si{};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi{};
    if (!CreateProcessW(exe.c_str(), mutableLine.data(), nullptr, nullptr,
                        FALSE, 0, nullptr, nullptr, &si, &pi)) {
        auto err = GetLastError();
        MessageBoxW(nullptr, L"Unable to launch the PeaZip command.",
                    L"PeaZip Modern Menu", MB_OK | MB_ICONERROR);
        return HRESULT_FROM_WIN32(err);
    }
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return S_OK;
}

class PeaZipCommand final : public IExplorerCommand {
    std::atomic<ULONG> refs_{1};
    CommandId id_;
public:
    explicit PeaZipCommand(CommandId id) : id_(id) { ++g_active; }
    ~PeaZipCommand() { --g_active; }
    STDMETHODIMP QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (iid == IID_IUnknown || iid == IID_IExplorerCommand) {
            *out = static_cast<IExplorerCommand*>(this);
            AddRef(); return S_OK;
        }
        return E_NOINTERFACE;
    }
    STDMETHODIMP_(ULONG) AddRef() override { return ++refs_; }
    STDMETHODIMP_(ULONG) Release() override {
        ULONG n = --refs_;
        if (!n) delete this;
        return n;
    }
    STDMETHODIMP GetTitle(IShellItemArray*, LPWSTR* title) override {
        return DupString(GetLabel(id_), title);
    }
    STDMETHODIMP GetIcon(IShellItemArray*, LPWSTR* icon) override {
        if (!icon) return E_POINTER;
        *icon = nullptr;
        auto exe = LocatePeaZip();
        if (exe.empty()) return E_NOTIMPL;
        const auto* spec = SpecFor(id_);
        if (spec && spec->icon >= 0) {
            auto pos = exe.find_last_of(L"\\/");
            if (pos != std::wstring::npos) {
                auto icl = exe.substr(0, pos + 1) +
                           L"res\\share\\icons\\peazip_seven.icl";
                if (IsRegularFile(icl)) return DupString(icl + L"," +
                                          std::to_wstring(spec->icon), icon);
            }
        }
        return DupString(exe + L",0", icon);
    }
    STDMETHODIMP GetToolTip(IShellItemArray*, LPWSTR* tooltip) override {
        if (!tooltip) return E_POINTER;
        *tooltip = nullptr;
        return E_NOTIMPL;
    }
    STDMETHODIMP GetCanonicalName(GUID* guid) override {
        if (!guid) return E_POINTER;
        *guid = CLSID_PeaZipMenu;
        // Stable distinct GUID for each submenu item, base GUID retained for root.
        if (id_ != CommandId::Root) guid->Data1 += static_cast<DWORD>(id_);
        return S_OK;
    }
    STDMETHODIMP GetState(IShellItemArray* items, BOOL, EXPCMDSTATE* state) override {
        if (!state) return E_POINTER;
        *state = ECS_ENABLED;
        if (id_ == CommandId::Root) return S_OK;
        if (!IsCommandShown(id_)) { *state = ECS_HIDDEN; return S_OK; }
        if (id_ == CommandId::HashTools && items) {
            DWORD count = 0;
            if (SUCCEEDED(items->GetCount(&count)) && count > 1) {
                *state = ECS_DISABLED; return S_OK;
            }
        }
        if (IsExtractionCommand(id_)) return GetExtractionState(items, state);
        return S_OK;
    }
    STDMETHODIMP Invoke(IShellItemArray* items, IBindCtx*) override {
        if (id_ == CommandId::Root) return E_NOTIMPL;
        if (!IsCommandShown(id_)) return E_ACCESSDENIED;
        return InvokePeaZip(id_, items);
    }
    STDMETHODIMP GetFlags(EXPCMDFLAGS* flags) override {
        if (!flags) return E_POINTER;
        *flags = id_ == CommandId::Root ? ECF_HASSUBCOMMANDS :
                 (IsNewGroup(id_) ? ECF_SEPARATORBEFORE : ECF_DEFAULT);
        return S_OK;
    }
    STDMETHODIMP EnumSubCommands(IEnumExplorerCommand** commands) override;
};

class PeaZipCommandEnumerator final : public IEnumExplorerCommand {
    std::atomic<ULONG> refs_{1};
    std::vector<CommandId> ordered_;
    size_t next_ = 0;
public:
    PeaZipCommandEnumerator() : ordered_(OrderedChildren()) { ++g_active; }
    PeaZipCommandEnumerator(const std::vector<CommandId>& order, size_t index)
        : ordered_(order), next_(index) { ++g_active; }
    ~PeaZipCommandEnumerator() { --g_active; }
    STDMETHODIMP QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (iid == IID_IUnknown || iid == IID_IEnumExplorerCommand) {
            *out = static_cast<IEnumExplorerCommand*>(this);
            AddRef(); return S_OK;
        }
        return E_NOINTERFACE;
    }
    STDMETHODIMP_(ULONG) AddRef() override { return ++refs_; }
    STDMETHODIMP_(ULONG) Release() override {
        ULONG n = --refs_;
        if (!n) delete this;
        return n;
    }
    STDMETHODIMP Next(ULONG requested, IExplorerCommand** out, ULONG* fetched) override {
        if (!out || (requested != 1 && !fetched)) return E_POINTER;
        if (fetched) *fetched = 0;
        for (ULONG i = 0; i < requested; ++i) out[i] = nullptr;
        ULONG got = 0;
        while (got < requested && next_ < ordered_.size()) {
            CommandId id = ordered_[next_++];
            if (!IsCommandShown(id)) continue;
            auto* child = new (std::nothrow) PeaZipCommand(id);
            if (!child) return E_OUTOFMEMORY;
            out[got++] = child;
        }
        if (fetched) *fetched = got;
        return got == requested ? S_OK : S_FALSE;
    }
    STDMETHODIMP Skip(ULONG count) override {
        ULONG skipped = 0;
        while (skipped < count && next_ < ordered_.size()) {
            if (IsCommandShown(ordered_[next_])) ++skipped;
            ++next_;
        }
        return skipped == count ? S_OK : S_FALSE;
    }
    STDMETHODIMP Reset() override { next_ = 0; return S_OK; }
    STDMETHODIMP Clone(IEnumExplorerCommand** out) override {
        if (!out) return E_POINTER;
        *out = new (std::nothrow) PeaZipCommandEnumerator(ordered_, next_);
        return *out ? S_OK : E_OUTOFMEMORY;
    }
};

STDMETHODIMP PeaZipCommand::EnumSubCommands(IEnumExplorerCommand** out) {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (id_ != CommandId::Root) return E_NOTIMPL;
    *out = new (std::nothrow) PeaZipCommandEnumerator;
    return *out ? S_OK : E_OUTOFMEMORY;
}

class PeaZipClassFactory final : public IClassFactory {
    std::atomic<ULONG> refs_{1};
public:
    PeaZipClassFactory() { ++g_active; }
    ~PeaZipClassFactory() { --g_active; }
    STDMETHODIMP QueryInterface(REFIID iid, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (iid == IID_IUnknown || iid == IID_IClassFactory) {
            *out = static_cast<IClassFactory*>(this);
            AddRef(); return S_OK;
        }
        return E_NOINTERFACE;
    }
    STDMETHODIMP_(ULONG) AddRef() override { return ++refs_; }
    STDMETHODIMP_(ULONG) Release() override {
        ULONG n = --refs_;
        if (!n) delete this;
        return n;
    }
    STDMETHODIMP CreateInstance(IUnknown* outer, REFIID iid, void** out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (outer) return CLASS_E_NOAGGREGATION;
        auto* obj = new (std::nothrow) PeaZipCommand(CommandId::Root);
        if (!obj) return E_OUTOFMEMORY;
        HRESULT hr = obj->QueryInterface(iid, out);
        obj->Release();
        return hr;
    }
    STDMETHODIMP LockServer(BOOL lock) override {
        if (lock) ++g_locks; else --g_locks;
        return S_OK;
    }
};

// Exported through PeaZipShellExtension.def (avoid C2375 against combaseapi.h).
extern "C" HRESULT __stdcall DllGetClassObject(
    REFCLSID clsid, REFIID iid, LPVOID* out) {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (clsid != CLSID_PeaZipMenu) return CLASS_E_CLASSNOTAVAILABLE;
    auto* factory = new (std::nothrow) PeaZipClassFactory;
    if (!factory) return E_OUTOFMEMORY;
    HRESULT hr = factory->QueryInterface(iid, out);
    factory->Release();
    return hr;
}
extern "C" HRESULT __stdcall DllCanUnloadNow(void) {
    return g_active == 0 && g_locks == 0 ? S_OK : S_FALSE;
}
