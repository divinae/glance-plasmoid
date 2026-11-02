PLUGIN_ID = com.dv.island
PREFIX ?= $(HOME)/.local
BUILD_DIR ?= build

QMLLINT ?= /usr/lib/qt6/bin/qmllint
# plasmoid.configuration and Plasma attached properties are not resolvable outside plasmashell
QMLLINT_FLAGS = --unqualified disable --missing-property disable \
	-I $(BUILD_DIR)/bin -I $(PREFIX)/lib/qml

QML_SOURCES = $(wildcard package/contents/ui/*.qml package/contents/ui/tabs/*.qml package/contents/ui/tiles/*.qml package/contents/ui/drawer/*.qml)

.PHONY: all configure build install uninstall lint restart run package clean

all: build

configure:
	cmake -B $(BUILD_DIR) -DCMAKE_INSTALL_PREFIX=$(PREFIX) -DCMAKE_BUILD_TYPE=Release

build: configure
	cmake --build $(BUILD_DIR) -j

install: build
	cmake --install $(BUILD_DIR)

uninstall:
	kpackagetool6 -t Plasma/Applet -r $(PLUGIN_ID) || true
	rm -rf $(PREFIX)/lib/qml/com/dv/island

lint: build
	$(QMLLINT) $(QMLLINT_FLAGS) $(QML_SOURCES)

restart:
	systemctl --user restart plasma-plasmashell

# Standalone window for quick iteration
run:
	QML_IMPORT_PATH=$(PREFIX)/lib/qml plasmawindowed $(PLUGIN_ID)

package:
	cmake -B $(BUILD_DIR) -DPACKAGE_PLASMOID=ON -DCMAKE_INSTALL_PREFIX=$(PREFIX)
	cmake --build $(BUILD_DIR) --target plasmoid

clean:
	rm -rf $(BUILD_DIR) *.plasmoid
