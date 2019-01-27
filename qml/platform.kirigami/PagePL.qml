/* -*- coding: utf-8-unix -*-
 *
 * Copyright (C) 2018 Rinigus
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

import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2
import org.kde.kirigami 2.5 as Kirigami
import "."

Kirigami.ScrollablePage {
    id: page

    property alias         acceptText: mainAction.text
    property var           acceptCallback
    property bool          canNavigateForward: true
    property bool          currentPage: app.pages.currentItem === page
    readonly property bool empty: false
    property var           pageMenu

    signal pageStatusActivating
    signal pageStatusActive
    signal pageStatusInactive

    actions {
        main: Kirigami.Action {
            id: mainAction
            enabled: page.canNavigateForward === true
            icon.source: app.styler.iconForward
            visible: !page.hideAcceptButton && (page.isDialog || app.pages.hasAttached(page))
            text: app.tr("Accept")
            onTriggered: {
                if (acceptCallback) acceptCallback();
                else app.pages.navigateForward();
            }
        }

        contextualActions: page.pageMenu ? page.pageMenu.items : []
    }

    onCurrentPageChanged: {
        if (page.currentPage) {
            pageStatusActivating();
            pageStatusActive();
        } else pageStatusInactive();
    }
}