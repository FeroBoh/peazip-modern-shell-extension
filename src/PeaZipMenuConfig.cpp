// PeaZip Modern Menu configuration UI (standalone, no runtime or PowerShell).
// MIT licensed independent community companion: no PeaZip source embedded.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <commctrl.h>
#include <commdlg.h>
#include <shlwapi.h>
#include <algorithm>
#include <string>
#include <vector>
#include <cwchar>
#include <utility>

#pragma comment(lib, "Comctl32.lib")
#pragma comment(lib, "Comdlg32.lib")
#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "Advapi32.lib")

static constexpr wchar_t kBase[] = L"Software\\PeaZipModernMenu";
static constexpr wchar_t kCommands[] = L"Software\\PeaZipModernMenu\\Commands";

struct Spec { const wchar_t* key; const wchar_t* label; bool defaultShown; };
static constexpr Spec kSpecs[] = {
    {L"ExtractDialog", L"Extract...", true},
    {L"ExtractHere", L"Extract here", true},
    {L"ExtractSmart", L"Extract here (smart new folder)", true},
    {L"ExtractNewFolder", L"Extract here (in new folder)", true},
    {L"Test", L"Test archive(s) [optional]", false},
    {L"OpenAsArchive", L"Open as archive", true},
    {L"BrowsePath", L"Browse path with PeaZip", true},
    {L"AddGUI", L"Add to archive", true},
    {L"Add7Z", L"Add to 7Z", true},
    {L"AddZIP", L"Add to ZIP", true},
    {L"Encrypt7Z", L"Encrypt (7Z)", true},
    {L"Convert", L"Convert", true},
    {L"HashTools", L"CRC, hash and file tools", true}
};
static constexpr size_t kSpecCount = sizeof(kSpecs) / sizeof(kSpecs[0]);
struct Entry { size_t specIndex; bool checked; };
static std::vector<Entry> g_entries;
static HWND g_window = nullptr, g_list = nullptr, g_detect = nullptr,
            g_separator = nullptr, g_path = nullptr, g_up = nullptr, g_down = nullptr;
static HFONT g_font = nullptr;
static bool g_refreshing = false;

enum ControlId { ID_LIST=101, ID_UP, ID_DOWN, ID_RESTORE, ID_DETECT, ID_SEPARATOR,
                 ID_PATH, ID_BROWSE, ID_SAVE, ID_CANCEL };

static DWORD ReadDword(const wchar_t* subkey, const wchar_t* key, DWORD fallback) {
    DWORD value = fallback, bytes = sizeof(value);
    return RegGetValueW(HKEY_CURRENT_USER, subkey, key, RRF_RT_REG_DWORD,
                        nullptr, &value, &bytes) == ERROR_SUCCESS ? value : fallback;
}

static std::wstring ReadString(const wchar_t* subkey, const wchar_t* valueName) {
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, subkey, 0, KEY_QUERY_VALUE, &key) != ERROR_SUCCESS)
        return L"";
    DWORD type = 0, bytes = 0;
    LONG err = RegQueryValueExW(key, valueName, nullptr, &type, nullptr, &bytes);
    std::wstring result;
    if (err == ERROR_SUCCESS && type == REG_SZ && bytes >= sizeof(wchar_t) && bytes <= 65536) {
        std::wstring value(bytes / sizeof(wchar_t) + 1, L'\0');
        err = RegQueryValueExW(key, valueName, nullptr, &type,
                               reinterpret_cast<BYTE*>(value.data()), &bytes);
        if (err == ERROR_SUCCESS) {
            value.resize(wcsnlen_s(value.c_str(), value.size()));
            result = std::move(value);
        }
    }
    RegCloseKey(key);
    return result;
}

static bool PutDword(HKEY key, const wchar_t* name, DWORD value) {
    return RegSetValueExW(key, name, 0, REG_DWORD,
                          reinterpret_cast<const BYTE*>(&value), sizeof(value)) == ERROR_SUCCESS;
}
static bool PutString(HKEY key, const wchar_t* name, const std::wstring& value) {
    return RegSetValueExW(key, name, 0, REG_SZ,
                          reinterpret_cast<const BYTE*>(value.c_str()),
                          static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t))) == ERROR_SUCCESS;
}

static void Load() {
    g_entries.clear();
    std::wstring order = ReadString(kBase, L"CommandOrder");
    size_t start = 0;
    while (start <= order.size()) {
        size_t stop = order.find(L';', start);
        if (stop == std::wstring::npos) stop = order.size();
        const std::wstring name = order.substr(start, stop - start);
        for (size_t i = 0; i < kSpecCount; ++i) {
            bool found = false;
            for (const auto& entry : g_entries) if (entry.specIndex == i) { found = true; break; }
            if (!found && name == kSpecs[i].key) {
                g_entries.push_back({i, ReadDword(kCommands, kSpecs[i].key,
                                      kSpecs[i].defaultShown ? 1U : 0U) != 0});
                break;
            }
        }
        if (stop == order.size()) break;
        start = stop + 1;
    }
    for (size_t i = 0; i < kSpecCount; ++i) {
        bool found = false;
        for (const auto& entry : g_entries) if (entry.specIndex == i) { found = true; break; }
        if (!found) g_entries.push_back({i, ReadDword(kCommands, kSpecs[i].key,
                                      kSpecs[i].defaultShown ? 1U : 0U) != 0});
    }
}

static void SyncChecks() {
    for (int i = 0; i < static_cast<int>(g_entries.size()); ++i)
        g_entries[i].checked = ListView_GetCheckState(g_list, i) != FALSE;
}
static int SelectedIndex() {
    return ListView_GetNextItem(g_list, -1, LVNI_SELECTED);
}
static void UpdateArrows() {
    int i = SelectedIndex();
    EnableWindow(g_up, i > 0);
    EnableWindow(g_down, i >= 0 && i < static_cast<int>(g_entries.size()) - 1);
}
static void RenderList(int select) {
    g_refreshing = true;
    ListView_DeleteAllItems(g_list);
    for (int i = 0; i < static_cast<int>(g_entries.size()); ++i) {
        const auto& entry = g_entries[i];
        LVITEMW item{};
        item.mask = LVIF_TEXT;
        item.iItem = i;
        item.pszText = const_cast<LPWSTR>(kSpecs[entry.specIndex].label);
        ListView_InsertItem(g_list, &item);
        ListView_SetCheckState(g_list, i, entry.checked ? TRUE : FALSE);
    }
    if (select >= 0 && select < static_cast<int>(g_entries.size())) {
        ListView_SetItemState(g_list, select, LVIS_SELECTED | LVIS_FOCUSED,
                              LVIS_SELECTED | LVIS_FOCUSED);
        ListView_EnsureVisible(g_list, select, FALSE);
    }
    g_refreshing = false;
    UpdateArrows();
}
static void MoveSelected(int offset) {
    const int i = SelectedIndex();
    const int j = i + offset;
    if (i < 0 || j < 0 || j >= static_cast<int>(g_entries.size())) return;
    SyncChecks();
    std::swap(g_entries[i], g_entries[j]);
    RenderList(j);
}

static bool Save() {
    SyncChecks();
    const int size = GetWindowTextLengthW(g_path);
    std::wstring path(size + 1, L'\0');
    GetWindowTextW(g_path, path.data(), size + 1);
    path.resize(size);
    if (!path.empty()) {
        const DWORD attrs = GetFileAttributesW(path.c_str());
        if (attrs == INVALID_FILE_ATTRIBUTES || (attrs & FILE_ATTRIBUTE_DIRECTORY) ||
            _wcsicmp(PathFindFileNameW(path.c_str()), L"peazip.exe") != 0) {
            MessageBoxW(g_window, L"Select an existing peazip.exe or leave the field empty.",
                        L"Invalid PeaZip path", MB_OK | MB_ICONWARNING);
            return false;
        }
    }
    HKEY base = nullptr, commands = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, kBase, 0, nullptr, 0, KEY_SET_VALUE,
                        nullptr, &base, nullptr) != ERROR_SUCCESS ||
        RegCreateKeyExW(HKEY_CURRENT_USER, kCommands, 0, nullptr, 0, KEY_SET_VALUE,
                        nullptr, &commands, nullptr) != ERROR_SUCCESS) {
        if (base) RegCloseKey(base);
        if (commands) RegCloseKey(commands);
        MessageBoxW(g_window, L"Could not open current-user registry settings.",
                    L"Registry error", MB_OK | MB_ICONERROR);
        return false;
    }
    bool ok = true;
    std::wstring order;
    for (const auto& e : g_entries) {
        const Spec& spec = kSpecs[e.specIndex];
        if (!order.empty()) order += L';';
        order += spec.key;
        ok = PutDword(commands, spec.key, e.checked ? 1 : 0) && ok;
    }
    ok = PutString(base, L"CommandOrder", order) && ok;
    ok = PutDword(base, L"DetectArchives",
                   SendMessageW(g_detect, BM_GETCHECK, 0, 0) == BST_CHECKED ? 1 : 0) && ok;
    ok = PutDword(base, L"ShowSeparators",
                   SendMessageW(g_separator, BM_GETCHECK, 0, 0) == BST_CHECKED ? 1 : 0) && ok;
    if (path.empty()) {
        const LONG status = RegDeleteValueW(base, L"ExecutablePath");
        ok = (status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND) && ok;
    } else ok = PutString(base, L"ExecutablePath", path) && ok;
    RegCloseKey(commands);
    RegCloseKey(base);
    if (!ok) {
        MessageBoxW(g_window, L"One or more settings could not be saved.",
                    L"Registry error", MB_OK | MB_ICONERROR);
        return false;
    }
    return true;
}

static HWND AddControl(HWND parent, DWORD ex, const wchar_t* cls, const wchar_t* caption,
                       DWORD style, int x, int y, int w, int h, int id) {
    HWND control = CreateWindowExW(ex, cls, caption, WS_CHILD | WS_VISIBLE | style,
                                   x, y, w, h, parent,
                                   reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),
                                   GetModuleHandleW(nullptr), nullptr);
    if (control && g_font) SendMessageW(control, WM_SETFONT,
                                        reinterpret_cast<WPARAM>(g_font), TRUE);
    return control;
}

static void Browse() {
    wchar_t buffer[32768]{};
    GetWindowTextW(g_path, buffer, 32768);
    OPENFILENAMEW dialog{};
    dialog.lStructSize = sizeof(dialog);
    dialog.hwndOwner = g_window;
    dialog.lpstrFile = buffer;
    dialog.nMaxFile = 32768;
    dialog.lpstrFilter = L"PeaZip executable (peazip.exe)\0peazip.exe\0All files\0*.*\0\0";
    dialog.nFilterIndex = 1;
    dialog.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST;
    if (GetOpenFileNameW(&dialog)) SetWindowTextW(g_path, buffer);
}

static LRESULT CALLBACK WindowProc(HWND wnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_CREATE: {
        g_window = wnd;
        g_font = static_cast<HFONT>(GetStockObject(DEFAULT_GUI_FONT));
        AddControl(wnd, 0, L"STATIC", L"Context menu commands — tick to show, select and use Move Up / Move Down",
                   0, 18, 16, 690, 24, 0);
        g_list = AddControl(wnd, WS_EX_CLIENTEDGE, WC_LISTVIEWW, L"",
                            LVS_REPORT | LVS_SINGLESEL | LVS_SHOWSELALWAYS | WS_TABSTOP,
                            18, 46, 566, 345, ID_LIST);
        ListView_SetExtendedListViewStyle(g_list, LVS_EX_FULLROWSELECT | LVS_EX_CHECKBOXES | LVS_EX_DOUBLEBUFFER);
        LVCOLUMNW col{};
        col.mask = LVCF_TEXT | LVCF_WIDTH;
        col.pszText = const_cast<LPWSTR>(L"Commands (checkbox = visible)");
        col.cx = 540;
        ListView_InsertColumn(g_list, 0, &col);
        g_up = AddControl(wnd, 0, L"BUTTON", L"Move Up", BS_PUSHBUTTON | WS_TABSTOP,
                          598, 52, 115, 34, ID_UP);
        g_down = AddControl(wnd, 0, L"BUTTON", L"Move Down", BS_PUSHBUTTON | WS_TABSTOP,
                            598, 94, 115, 34, ID_DOWN);
        AddControl(wnd, 0, L"BUTTON", L"Restore defaults", BS_PUSHBUTTON | WS_TABSTOP,
                   598, 146, 115, 35, ID_RESTORE);
        g_detect = AddControl(wnd, 0, L"BUTTON",
                              L"Disable extraction for unrecognized file extensions",
                              BS_AUTOCHECKBOX | WS_TABSTOP, 18, 407, 685, 25, ID_DETECT);
        g_separator = AddControl(wnd, 0, L"BUTTON",
                                 L"Show automatic separators when command categories change",
                                 BS_AUTOCHECKBOX | WS_TABSTOP, 18, 436, 685, 25, ID_SEPARATOR);
        AddControl(wnd, 0, L"STATIC", L"PeaZip executable (optional — blank means automatic discovery):",
                   0, 18, 474, 690, 20, 0);
        g_path = AddControl(wnd, WS_EX_CLIENTEDGE, L"EDIT", L"",
                            ES_AUTOHSCROLL | WS_TABSTOP, 18, 497, 565, 27, ID_PATH);
        AddControl(wnd, 0, L"BUTTON", L"Browse...", BS_PUSHBUTTON | WS_TABSTOP,
                   597, 496, 116, 29, ID_BROWSE);
        AddControl(wnd, 0, L"STATIC",
                   L"Settings are stored per user; changes normally appear on the next context menu open.",
                   0, 18, 540, 700, 23, 0);
        AddControl(wnd, 0, L"BUTTON", L"Save", BS_DEFPUSHBUTTON | WS_TABSTOP,
                   520, 575, 93, 34, ID_SAVE);
        AddControl(wnd, 0, L"BUTTON", L"Cancel", BS_PUSHBUTTON | WS_TABSTOP,
                   620, 575, 93, 34, ID_CANCEL);
        Load();
        RenderList(0);
        SendMessageW(g_detect, BM_SETCHECK,
                     ReadDword(kBase, L"DetectArchives", 1) ? BST_CHECKED : BST_UNCHECKED, 0);
        SendMessageW(g_separator, BM_SETCHECK,
                     ReadDword(kBase, L"ShowSeparators", 1) ? BST_CHECKED : BST_UNCHECKED, 0);
        const auto path = ReadString(kBase, L"ExecutablePath");
        SetWindowTextW(g_path, path.c_str());
        return 0;
    }
    case WM_NOTIFY: {
        const auto* notification = reinterpret_cast<const NMHDR*>(lp);
        if (notification && notification->idFrom == ID_LIST &&
            notification->code == LVN_ITEMCHANGED && !g_refreshing) UpdateArrows();
        return 0;
    }
    case WM_COMMAND:
        switch (LOWORD(wp)) {
        case ID_UP: MoveSelected(-1); return 0;
        case ID_DOWN: MoveSelected(+1); return 0;
        case ID_RESTORE:
            g_entries.clear();
            for (size_t i = 0; i < kSpecCount; ++i)
                g_entries.push_back({i, kSpecs[i].defaultShown});
            RenderList(0);
            SendMessageW(g_detect, BM_SETCHECK, BST_CHECKED, 0);
            SendMessageW(g_separator, BM_SETCHECK, BST_CHECKED, 0);
            return 0;
        case ID_BROWSE: Browse(); return 0;
        case ID_SAVE:
            if (Save()) DestroyWindow(wnd);
            return 0;
        case ID_CANCEL: DestroyWindow(wnd); return 0;
        }
        break;
    case WM_CLOSE: DestroyWindow(wnd); return 0;
    case WM_DESTROY: PostQuitMessage(0); return 0;
    }
    return DefWindowProcW(wnd, msg, wp, lp);
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int show) {
    INITCOMMONCONTROLSEX init{sizeof(init), ICC_LISTVIEW_CLASSES};
    InitCommonControlsEx(&init);
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.hInstance = instance;
    wc.lpfnWndProc = WindowProc;
    wc.lpszClassName = L"PeaZipModernMenuConfigWindow";
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_BTNFACE + 1);
    if (!RegisterClassExW(&wc)) return 1;
    HWND wnd = CreateWindowExW(0, wc.lpszClassName,
                               L"PeaZip Modern Menu — Configuration v1.2",
                               WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
                               CW_USEDEFAULT, CW_USEDEFAULT, 752, 668,
                               nullptr, nullptr, instance, nullptr);
    if (!wnd) return 2;
    ShowWindow(wnd, show);
    UpdateWindow(wnd);
    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        if (!IsDialogMessageW(wnd, &message)) {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
    }
    return static_cast<int>(message.wParam);
}
