(function () {
  const endpoint = "http://127.0.0.1:37717/snapshot";
  const consoleMessages = [];

  window.addEventListener("message", (event) => {
    if (event.source !== window || event.data?.source !== "vibereview-console") return;
    consoleMessages.push({
      level: event.data.level || "log",
      message: String(event.data.message || "").slice(0, 2000),
      timestamp: event.data.timestamp || new Date().toISOString()
    });
    while (consoleMessages.length > 100) consoleMessages.shift();
  });

  function safeStorage(storage) {
    const values = {};
    try {
      for (let index = 0; index < storage.length; index += 1) {
        const key = storage.key(index);
        if (!key) continue;
        values[key] = String(storage.getItem(key) || "").slice(0, 4000);
      }
    } catch (_) {}
    return values;
  }

  function textOf(elements) {
    return Array.from(elements)
      .map((element) => (element.innerText || element.textContent || "").trim())
      .filter(Boolean)
      .slice(0, 12);
  }

  function focusedElementLabel() {
    const element = document.activeElement;
    if (!element) return null;
    const parts = [element.tagName?.toLowerCase()];
    if (element.id) parts.push("#" + element.id);
    if (element.getAttribute("aria-label")) parts.push(element.getAttribute("aria-label"));
    if (element.getAttribute("name")) parts.push("name=" + element.getAttribute("name"));
    return parts.filter(Boolean).join(" ");
  }

  function snapshot() {
    const canvases = Array.from(document.querySelectorAll("canvas")).map((canvas) => ({
      width: canvas.width,
      height: canvas.height,
      label: canvas.getAttribute("aria-label") || canvas.id || null
    }));

    return {
      capturedAt: new Date().toISOString(),
      url: location.href,
      title: document.title,
      viewport: {
        width: window.innerWidth,
        height: window.innerHeight,
        devicePixelRatio: window.devicePixelRatio || 1
      },
      scroll: {
        x: window.scrollX,
        y: window.scrollY
      },
      selectedText: String(window.getSelection?.() || "").slice(0, 2000),
      focusedElement: focusedElementLabel(),
      domSummary: {
        bodyTextSample: (document.body?.innerText || "").replace(/\s+/g, " ").trim().slice(0, 4000),
        interactiveElementCount: document.querySelectorAll("button,a,input,textarea,select,[role=button],[tabindex]").length,
        headings: textOf(document.querySelectorAll("h1,h2,h3")),
        buttons: textOf(document.querySelectorAll("button,[role=button]"))
      },
      storage: {
        localStorage: safeStorage(window.localStorage),
        sessionStorage: safeStorage(window.sessionStorage)
      },
      canvases,
      consoleMessages: consoleMessages.slice(-50)
    };
  }

  async function sendSnapshot() {
    try {
      await fetch(endpoint, {
        method: "POST",
        mode: "cors",
        headers: { "Content-Type": "text/plain" },
        body: JSON.stringify(snapshot())
      });
    } catch (_) {}
  }

  sendSnapshot();
  setInterval(sendSnapshot, 1000);
})();
