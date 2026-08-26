#pragma once

#include <windows.h>
#include <ole2.h>
#include <shlobj.h>
#include <string>
#include <vector>

namespace clipdock {

class SimpleDropSource : public IDropSource {
 public:
  SimpleDropSource() : ref_count_(1), button_down_seen_(false) {}
  virtual ~SimpleDropSource() = default;

  // IUnknown
  STDMETHODIMP QueryInterface(REFIID riid, void** ppvObject) override {
    if (!ppvObject) return E_POINTER;
    if (riid == IID_IUnknown || riid == IID_IDropSource) {
      *ppvObject = static_cast<IDropSource*>(this);
      AddRef();
      return S_OK;
    }
    *ppvObject = nullptr;
    return E_NOINTERFACE;
  }

  STDMETHODIMP_(ULONG) AddRef() override {
    return InterlockedIncrement(&ref_count_);
  }

  STDMETHODIMP_(ULONG) Release() override {
    ULONG count = InterlockedDecrement(&ref_count_);
    if (count == 0) {
      delete this;
      return 0;
    }
    return count;
  }

  // IDropSource
  STDMETHODIMP QueryContinueDrag(BOOL fEscapePressed, DWORD grfKeyState) override {
    if (fEscapePressed) {
      return DRAGDROP_S_CANCEL;
    }
    bool is_down = (GetAsyncKeyState(VK_LBUTTON) & 0x8000) != 0 ||
                   (GetAsyncKeyState(VK_RBUTTON) & 0x8000) != 0 ||
                   (grfKeyState & (MK_LBUTTON | MK_RBUTTON)) != 0;
    if (is_down) {
      button_down_seen_ = true;
      return S_OK;
    }
    return DRAGDROP_S_DROP;
  }

  STDMETHODIMP GiveFeedback(DWORD dwEffect) override {
    return DRAGDROP_S_USEDEFAULTCURSORS;
  }

 private:
  ULONG ref_count_;
  bool button_down_seen_;
};

class SimpleEnumFORMATETC : public IEnumFORMATETC {
 public:
  explicit SimpleEnumFORMATETC(const std::vector<FORMATETC>& formats)
      : ref_count_(1), index_(0), formats_(formats) {}
  virtual ~SimpleEnumFORMATETC() = default;

  STDMETHODIMP QueryInterface(REFIID riid, void** ppvObject) override {
    if (!ppvObject) return E_POINTER;
    if (riid == IID_IUnknown || riid == IID_IEnumFORMATETC) {
      *ppvObject = static_cast<IEnumFORMATETC*>(this);
      AddRef();
      return S_OK;
    }
    *ppvObject = nullptr;
    return E_NOINTERFACE;
  }

  STDMETHODIMP_(ULONG) AddRef() override {
    return InterlockedIncrement(&ref_count_);
  }

  STDMETHODIMP_(ULONG) Release() override {
    ULONG count = InterlockedDecrement(&ref_count_);
    if (count == 0) {
      delete this;
      return 0;
    }
    return count;
  }

  STDMETHODIMP Next(ULONG celt, FORMATETC* rgelt, ULONG* pceltFetched) override {
    if (!rgelt) return E_POINTER;
    ULONG fetched = 0;
    while (index_ < formats_.size() && fetched < celt) {
      rgelt[fetched] = formats_[index_++];
      fetched++;
    }
    if (pceltFetched) *pceltFetched = fetched;
    return (fetched == celt) ? S_OK : S_FALSE;
  }

  STDMETHODIMP Skip(ULONG celt) override {
    index_ += celt;
    if (index_ > formats_.size()) {
      index_ = formats_.size();
      return S_FALSE;
    }
    return S_OK;
  }

  STDMETHODIMP Reset() override {
    index_ = 0;
    return S_OK;
  }

  STDMETHODIMP Clone(IEnumFORMATETC** ppenum) override {
    if (!ppenum) return E_POINTER;
    SimpleEnumFORMATETC* clone = new SimpleEnumFORMATETC(formats_);
    clone->index_ = index_;
    *ppenum = clone;
    return S_OK;
  }

 private:
  ULONG ref_count_;
  size_t index_;
  std::vector<FORMATETC> formats_;
};

class SimpleDataObject : public IDataObject {
 public:
  explicit SimpleDataObject(const std::wstring& text) : ref_count_(1), text_(text) {}
  virtual ~SimpleDataObject() = default;

  // IUnknown
  STDMETHODIMP QueryInterface(REFIID riid, void** ppvObject) override {
    if (!ppvObject) return E_POINTER;
    if (riid == IID_IUnknown || riid == IID_IDataObject) {
      *ppvObject = static_cast<IDataObject*>(this);
      AddRef();
      return S_OK;
    }
    *ppvObject = nullptr;
    return E_NOINTERFACE;
  }

  STDMETHODIMP_(ULONG) AddRef() override {
    return InterlockedIncrement(&ref_count_);
  }

  STDMETHODIMP_(ULONG) Release() override {
    ULONG count = InterlockedDecrement(&ref_count_);
    if (count == 0) {
      delete this;
      return 0;
    }
    return count;
  }

  // IDataObject
  STDMETHODIMP GetData(FORMATETC* pformatetcIn, STGMEDIUM* pmedium) override {
    if (!pformatetcIn || !pmedium) return E_POINTER;
    if (!(pformatetcIn->tymed & TYMED_HGLOBAL)) return DV_E_TYMED;

    if (pformatetcIn->cfFormat == CF_UNICODETEXT) {
      size_t byte_count = (text_.length() + 1) * sizeof(wchar_t);
      HGLOBAL hGlobal = GlobalAlloc(GMEM_MOVEABLE | GMEM_SHARE, byte_count);
      if (!hGlobal) return E_OUTOFMEMORY;

      void* pData = GlobalLock(hGlobal);
      if (!pData) {
        GlobalFree(hGlobal);
        return E_OUTOFMEMORY;
      }
      memcpy(pData, text_.c_str(), byte_count);
      GlobalUnlock(hGlobal);

      pmedium->tymed = TYMED_HGLOBAL;
      pmedium->hGlobal = hGlobal;
      pmedium->pUnkForRelease = nullptr;
      return S_OK;
    }

    if (pformatetcIn->cfFormat == CF_TEXT) {
      int len = WideCharToMultiByte(CP_ACP, 0, text_.c_str(), -1, nullptr, 0, nullptr, nullptr);
      if (len <= 0) return E_FAIL;

      HGLOBAL hGlobal = GlobalAlloc(GMEM_MOVEABLE | GMEM_SHARE, len);
      if (!hGlobal) return E_OUTOFMEMORY;

      char* pData = static_cast<char*>(GlobalLock(hGlobal));
      if (!pData) {
        GlobalFree(hGlobal);
        return E_OUTOFMEMORY;
      }
      WideCharToMultiByte(CP_ACP, 0, text_.c_str(), -1, pData, len, nullptr, nullptr);
      GlobalUnlock(hGlobal);

      pmedium->tymed = TYMED_HGLOBAL;
      pmedium->hGlobal = hGlobal;
      pmedium->pUnkForRelease = nullptr;
      return S_OK;
    }

    return DV_E_FORMATETC;
  }

  STDMETHODIMP GetDataHere(FORMATETC* pformatetc, STGMEDIUM* pmedium) override {
    return DATA_E_FORMATETC;
  }

  STDMETHODIMP QueryGetData(FORMATETC* pformatetc) override {
    if (!pformatetc) return E_POINTER;
    if (!(pformatetc->tymed & TYMED_HGLOBAL)) return DV_E_TYMED;
    if (pformatetc->cfFormat == CF_UNICODETEXT || pformatetc->cfFormat == CF_TEXT) {
      return S_OK;
    }
    return DV_E_FORMATETC;
  }

  STDMETHODIMP GetCanonicalFormatEtc(FORMATETC* pformatectIn, FORMATETC* pformatetcOut) override {
    if (!pformatetcOut) return E_POINTER;
    pformatetcOut->ptd = nullptr;
    return E_NOTIMPL;
  }

  STDMETHODIMP SetData(FORMATETC* pformatetc, STGMEDIUM* pmedium, BOOL fRelease) override {
    return E_NOTIMPL;
  }

  STDMETHODIMP EnumFormatEtc(DWORD dwDirection, IEnumFORMATETC** ppenumFormatEtc) override {
    if (dwDirection != DATADIR_GET) return E_NOTIMPL;
    if (!ppenumFormatEtc) return E_POINTER;

    std::vector<FORMATETC> formats = {
      { CF_UNICODETEXT, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL },
      { CF_TEXT, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL }
    };
    *ppenumFormatEtc = new SimpleEnumFORMATETC(formats);
    return S_OK;
  }

  STDMETHODIMP DAdvise(FORMATETC* pformatetc, DWORD advf, IAdviseSink* pAdvSink, DWORD* pdwConnection) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }

  STDMETHODIMP DUnadvise(DWORD dwConnection) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }

  STDMETHODIMP EnumDAdvise(IEnumSTATDATA** ppenumAdvise) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }

 private:
  ULONG ref_count_;
  std::wstring text_;
};

inline void PerformTextDragDrop(const std::wstring& text) {
  HRESULT hr = ::OleInitialize(nullptr);

  // 1. Ensure clipboard has the dragged text
  if (OpenClipboard(nullptr)) {
    EmptyClipboard();
    size_t byte_count = (text.length() + 1) * sizeof(wchar_t);
    HGLOBAL hGlobal = GlobalAlloc(GMEM_MOVEABLE, byte_count);
    if (hGlobal) {
      void* pData = GlobalLock(hGlobal);
      if (pData) {
        memcpy(pData, text.c_str(), byte_count);
        GlobalUnlock(hGlobal);
        SetClipboardData(CF_UNICODETEXT, hGlobal);
      }
    }
    CloseClipboard();
  }

  // 2. Perform native OLE Drag-and-Drop
  SimpleDataObject* data_obj = new SimpleDataObject(text);
  SimpleDropSource* drop_src = new SimpleDropSource();
  DWORD dwEffect = 0;
  ::DoDragDrop(data_obj, drop_src, DROPEFFECT_COPY | DROPEFFECT_MOVE | DROPEFFECT_LINK, &dwEffect);
  drop_src->Release();
  data_obj->Release();

  // 3. If target did not accept OLE drop (e.g. standard browser inputs, web forms, chat inputs),
  // detect the window under cursor and paste directly into it
  if (dwEffect == DROPEFFECT_NONE) {
    POINT pt;
    if (GetCursorPos(&pt)) {
      HWND target_hwnd = WindowFromPoint(pt);
      if (target_hwnd != nullptr) {
        HWND root_target = GetAncestor(target_hwnd, GA_ROOT);
        if (root_target != nullptr) {
          SetForegroundWindow(root_target);
          BringWindowToTop(root_target);
        }
        // Send mouse click to focus target input field
        SendMessage(target_hwnd, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(pt.x, pt.y));
        Sleep(25);
        SendMessage(target_hwnd, WM_LBUTTONUP, 0, MAKELPARAM(pt.x, pt.y));
        Sleep(35);

        // Synthesize Ctrl+V keystrokes to paste
        INPUT inputs[4] = {};
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].ki.wVk = VK_CONTROL;
        inputs[1].type = INPUT_KEYBOARD;
        inputs[1].ki.wVk = 'V';
        inputs[2].type = INPUT_KEYBOARD;
        inputs[2].ki.wVk = 'V';
        inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
        inputs[3].type = INPUT_KEYBOARD;
        inputs[3].ki.wVk = VK_CONTROL;
        inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;
        SendInput(4, inputs, sizeof(INPUT));
      }
    }
  }

  if (hr == S_OK || hr == S_FALSE) {
    ::OleUninitialize();
  }
}

}  // namespace clipdock
