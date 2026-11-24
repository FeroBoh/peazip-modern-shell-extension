#define WIN32_LEAN_AND_MEAN
#include <windows.h>
// MSIX application identity needs an executable; the Explorer COM server
// is the actual feature, and peazip.exe remains the real application.
int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) { return 0; }
