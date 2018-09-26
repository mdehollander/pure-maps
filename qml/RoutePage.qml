/* -*- coding: utf-8-unix -*-
 *
 * Copyright (C) 2014 Osmo Salomaa
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import "."

Page {
    id: page
    allowedOrientations: app.defaultAllowedOrientations
    canNavigateForward: page.from && page.to &&
        (page.fromText !== app.tr("Current position") || gps.ready) &&
        (page.toText   !== app.tr("Current position") || gps.ready)

    property var    from: null
    property string fromText: ""
    property var    params: {}
    property var    to: null
    property string toText: ""

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: parent.width

        Column {
            id: column
            anchors.fill: parent

            property var  settings: null
            property bool settingsChecked: false

            PageHeader {
                title: app.tr("Navigation")
            }

            ValueButton {
                id: usingButton
                label: app.tr("Using")
                height: Theme.itemSizeSmall
                value: py.evaluate("poor.app.router.name")
                width: parent.width
                onClicked: {
                    var dialog = app.push("RouterPage.qml");
                    dialog.accepted.connect(function() {
                        column.settingsChecked = false;
                        usingButton.value = py.evaluate("poor.app.router.name");
                        column.addSettings();
                    });
                }
            }

            ValueButton {
                id: fromButton
                label: app.tr("From")
                height: Theme.itemSizeSmall
                value: page.fromText
                // Avoid putting label and value on different lines.
                width: 3 * parent.width

                BusyIndicator {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin + (parent.width - page.width)
                    anchors.verticalCenter: parent.verticalCenter
                    running: page.fromText === app.tr("Current position") && !gps.ready
                    size: BusyIndicatorSize.Small
                    z: parent.z + 1
                }

                onClicked: {
                    var dialog = app.push("RoutePointPage.qml");
                    dialog.accepted.connect(function() {
                        if (dialog.selectedPoi && dialog.selectedPoi.coordinate) {
                            page.from = [dialog.selectedPoi.coordinate.longitude, dialog.selectedPoi.coordinate.latitude];
                            page.fromText = dialog.selectedPoi.title || app.tr("Unnamed point");
                        } else if (dialog.query === app.tr("Current position")) {
                            page.from = map.getPosition();
                            page.fromText = dialog.query;
                        } else {
                            page.from = dialog.query;
                            page.fromText = dialog.query;
                            py.call_sync("poor.app.history.add_place", [dialog.query]);
                        }
                    });
                }

            }

            ValueButton {
                id: toButton
                label: app.tr("To")
                height: Theme.itemSizeSmall
                value: page.toText
                // Avoid putting label and value on different lines.
                width: 3 * parent.width

                BusyIndicator {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin + (parent.width - page.width)
                    anchors.verticalCenter: parent.verticalCenter
                    running: page.toText === app.tr("Current position") && !gps.ready
                    size: BusyIndicatorSize.Small
                    z: parent.z + 1
                }

                onClicked: {
                    var dialog = app.push("RoutePointPage.qml");
                    dialog.accepted.connect(function() {
                        if (dialog.selectedPoi && dialog.selectedPoi.coordinate) {
                            page.to = [dialog.selectedPoi.coordinate.longitude, dialog.selectedPoi.coordinate.latitude];
                            page.toText = dialog.selectedPoi.title || app.tr("Unnamed point");
                        } else if (dialog.query === app.tr("Current position")) {
                            page.to = map.getPosition();
                            page.toText = dialog.query;
                        } else {
                            page.to = dialog.query;
                            page.toText = dialog.query;
                            py.call_sync("poor.app.history.add_place", [dialog.query]);
                        }
                    });
                }

            }

            TextSwitch {
                id: followMe
                checked: false
                description: app.tr("Follow the movement and show just in time information")
                text: app.tr("Follow me")
                Component.onCompleted: {
                    checked = (app.mode === modes.followMe);
                }
            }

            ToolItem {
                id: beginFollowMeItem
                icon: app.mode === modes.followMe ? "image://theme/icon-m-clear" : "image://theme/icon-m-play"
                text: app.mode === modes.followMe ? app.tr("Stop") : app.tr("Begin")
                visible: followMe.checked
                width: column.width
                onClicked: {
                    if (app.mode === modes.followMe) {
                        app.setModeExplore();
                        app.showMap();
                    } else {
                        app.setModeFollowMe();
                        app.hideMenu();
                    }
                }
            }

            ComboBox {
                id: mapmatchingComboBox
                description: app.tr("Select mode of transportation. Only applies when Pure Maps is in follow me mode.")
                label: app.tr("Mode of transportation")
                menu: ContextMenu {
                    MenuItem { text: app.tr("Car") }
                    MenuItem { text: app.tr("Bicycle") }
                    MenuItem { text: app.tr("Foot") }
                }
                visible: app.hasMapMatching && followMe.checked
                property var values: ["car", "bicycle", "foot"]
                Component.onCompleted: {
                    var value = app.conf.mapMatchingWhenFollowing;
                    mapmatchingComboBox.currentIndex = Math.max(0, mapmatchingComboBox.values.indexOf(value));
                }
                onCurrentIndexChanged: {
                    var index = mapmatchingComboBox.currentIndex;
                    app.conf.set("map_matching_when_following", mapmatchingComboBox.values[index]);
                }
            }

            Connections {
                target: page
                onFromChanged: column.addSettings();
                onToChanged: column.addSettings();
            }

            Connections {
                target: followMe
                onCheckedChanged: column.addSettings();
            }

            Component.onCompleted: column.addSettings();

            function addSettings() {
                if (column.settingsChecked || page.from==null || page.to==null || followMe.checked) return;
                // Add router-specific settings from router's own QML file.
                followMe.visible = false;
                page.params = {};
                column.settings && column.settings.destroy();
                var uri = py.evaluate("poor.app.router.settings_qml_uri");
                if (!uri) return;
                var component = Qt.createComponent(uri);
                column.settings = component.createObject(column);
                column.settings.anchors.left = column.left;
                column.settings.anchors.right = column.right;
                column.settings.width = column.width;
                column.settingsChecked = true;
            }

        }

        PullDownMenu {
            MenuItem {
                text: app.tr("Follow me")
                onClicked: {
                    followMe.checked = true;
                    followMe.visible = true;
                    column.settingsChecked = false;
                    page.params = {};
                    column.settings && column.settings.destroy();
                    column.settings = null;
                }
            }
            MenuItem {
                text: app.tr("Reverse endpoints")
                onClicked: {
                    var from = page.from;
                    var fromText = page.fromText;
                    page.from = page.to;
                    page.fromText = page.toText;
                    page.to = from;
                    page.toText = fromText;
                }
            }
        }

        VerticalScrollDecorator {}

    }

    Component.onCompleted: {
        if (!page.from) {
            page.from = map.getPosition();
            page.fromText = app.tr("Current position");
        }
    }

    onStatusChanged: {
        if (page.status === PageStatus.Active) {
            if (page.fromText === app.tr("Current position"))
                page.from = map.getPosition();
            if (page.toText === app.tr("Current position"))
                page.to = map.getPosition();
            var uri = py.evaluate("poor.app.router.results_qml_uri");
            app.pushAttached(uri);
        }
    }

}
