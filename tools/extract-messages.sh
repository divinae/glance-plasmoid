#!/bin/bash
# Collects the translatable strings into po/plasma_applet_com.dv.glance.pot and updates the
# translations in po/ with them. The catalog must be named plasma_applet_<widget id>: that is the
# domain Plasma binds a widget's i18n() to.
set -e
cd "$(dirname "$0")/.."
domain=plasma_applet_com.dv.glance
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# QML is close enough to JavaScript for xgettext
xgettext --from-code=UTF-8 --language=JavaScript --add-comments=i18n: --sort-by-file \
    --keyword= --keyword=i18n:1 --keyword=i18nc:1c,2 --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
    --package-name=glance --msgid-bugs-address=https://gitlab.com/divinae/glance-plasmoid/-/issues \
    --output="$tmp/messages.pot" $(find package -name '*.qml' -o -name '*.js' | sort)
# the date changes on every run
sed -e '/^"POT-Creation-Date:/d' "$tmp/messages.pot" > "po/$domain.pot"
shopt -s nullglob
for po in po/*.po; do
    msgmerge --quiet --update --backup=none --no-fuzzy-matching "$po" "po/$domain.pot"
done
