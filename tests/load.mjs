// Loads a QML ".pragma library" script into a fresh context, for node's test runner
import { readFileSync } from "node:fs";
import vm from "node:vm";

export function load(path) {
    const source = readFileSync(new URL(`../package/contents/ui/${path}`, import.meta.url), "utf8")
        .replace(/^\.pragma library\s*$/m, "")
        .replace(/^\.import .*$/gm, "");
    const context = {};
    vm.createContext(context);
    vm.runInContext(source, context);
    return context;
}
