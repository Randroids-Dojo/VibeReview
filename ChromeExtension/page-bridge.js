(function () {
  const levels = ["log", "info", "warn", "error", "debug"];

  for (const level of levels) {
    const original = console[level];
    console[level] = function (...args) {
      try {
        window.postMessage({
          source: "vibereview-console",
          level,
          message: args.map((arg) => {
            if (typeof arg === "string") return arg;
            try {
              return JSON.stringify(arg);
            } catch (_) {
              return String(arg);
            }
          }).join(" "),
          timestamp: new Date().toISOString()
        }, "*");
      } catch (_) {}
      return original.apply(this, args);
    };
  }
})();
