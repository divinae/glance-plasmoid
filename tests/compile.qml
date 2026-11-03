// Compiles every QML file of the package (run by tests/compile.sh): each must come up Ready
import QtQuick

QtObject {
    Component.onCompleted: {
        const base = Qt.application.arguments[Qt.application.arguments.length - 1];
        const files = Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1, -1);
        let failed = 0;
        for (const f of files) {
            const c = Qt.createComponent(base + f, Component.PreferSynchronous);
            if (c.status !== Component.Ready) {
                console.error("FAIL", f, c.errorString());
                ++failed;
            }
        }
        console.info(files.length - failed, "of", files.length, "compiled");
        Qt.exit(failed > 0 ? 1 : 0);
    }
}
