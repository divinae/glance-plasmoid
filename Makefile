PLUGIN_ID = com.dv.glance
PREFIX ?= $(HOME)/.local
BUILD_DIR ?= build

QMLLINT ?= /usr/lib/qt6/bin/qmllint
QMLTESTRUNNER ?= /usr/lib/qt6/bin/qmltestrunner
# plasmoid.configuration and Plasma attached properties are not resolvable outside plasmashell
QMLLINT_FLAGS = --unqualified disable --missing-property disable \
	-I $(BUILD_DIR)/bin -I $(PREFIX)/lib/qml

QML_SOURCES = $(wildcard package/contents/ui/*.qml package/contents/ui/tabs/*.qml package/contents/ui/tiles/*.qml package/contents/ui/drawer/*.qml package/contents/ui/stand/*.qml package/contents/ui/stand/lib/*.qml)

DOMAIN = plasma_applet_$(PLUGIN_ID)
PO_FILES = $(wildcard po/*.po)
MO_FILES = $(patsubst po/%.po,package/contents/locale/%/LC_MESSAGES/$(DOMAIN).mo,$(PO_FILES))

.PHONY: all configure build install uninstall lint test restart run package clean messages translations

all: build

configure:
	cmake -B $(BUILD_DIR) -DCMAKE_INSTALL_PREFIX=$(PREFIX) -DCMAKE_BUILD_TYPE=Release

build: configure translations
	cmake --build $(BUILD_DIR) -j

# The translations, compiled into the package (and so into the .plasmoid); po/ holds the sources
translations: $(MO_FILES)

package/contents/locale/%/LC_MESSAGES/$(DOMAIN).mo: po/%.po
	@mkdir -p $(dir $@)
	msgfmt --check -o $@ $<

# Collect the strings again and update po/*.po
messages:
	tools/extract-messages.sh

install: build
	cmake --install $(BUILD_DIR)

uninstall:
	kpackagetool6 -t Plasma/Applet -r $(PLUGIN_ID) || true
	rm -rf $(PREFIX)/lib/qml/com/dv/glance

lint: build
	$(QMLLINT) $(QMLLINT_FLAGS) $(QML_SOURCES)

# The pure JS (drawer geometry, formatting) under node, then every QML file compiled offscreen,
# and the translations checked
test: build
	node --test tests/
	QT_QPA_PLATFORM=offscreen $(QMLTESTRUNNER) -input tests/stand
	tests/compile.sh
	for po in $(PO_FILES); do msgfmt --check -o /dev/null $$po || exit 1; done

restart:
	systemctl --user restart plasma-plasmashell

# Standalone window for quick iteration
run:
	QML_IMPORT_PATH=$(PREFIX)/lib/qml plasmawindowed $(PLUGIN_ID)

package: translations
	cmake -B $(BUILD_DIR) -DPACKAGE_PLASMOID=ON -DCMAKE_INSTALL_PREFIX=$(PREFIX)
	cmake --build $(BUILD_DIR) --target plasmoid

clean:
	rm -rf $(BUILD_DIR) *.plasmoid package/contents/locale
