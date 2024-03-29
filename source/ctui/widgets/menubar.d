//
// Simple curses-based GUI toolkit, menu bar widget
//
// Copyright (C) 2007-2011 Novell Inc
// Copyright (C) 2017 Microsoft Corp
// Copyright (C) 2018 Joachim de Groot
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

module ctui.widgets.menubar;

import core.stdc.stddef;
import std.algorithm : max;
import std.conv : to;
import std.string : toStringz;
import std.uni : isAlphaNum, toUpper;
import std.utf : count;

import deimos.ncurses;

import ctui.application;
import ctui.keys;
import ctui.widgets.container;
import ctui.widgets.widget;

public alias Action = void delegate();

/// A menu item has a title, an associated help text, and an action to execute
/// on activation.
public class MenuItem
{
    private string _title;
    private int _width;

    /// The help text for the item.
    public string help;

    /// The action to be invoked when this menu item is triggered.
    public Action action;

    /// The hotkey is used when the menu is active, the shortcut can be
    /// triggered when the menu is not active. For example HotKey would be "N"
    /// when the File Menu is open (assuming there is a "_New" entry if the
    /// ShortCut is set to "Control-N", this would be a global hotkey that
    /// would trigger as well).
    public wchar_t hotKey;

    /// This is the global setting that can be used as a global shortcut to
    /// invoke the action on the menu.
    public wchar_t shortCut;

    ///
    /// Initializes a new MenuItem.
    ///
    /// Params:
    ///     title  = Title for the menu item.
    ///     help   = Help text to display.
    ///     action = Action to invoke when the menu item is activated.
    public this(string title, string help, Action action)
    {
        this.title = title;
        this.help = help;
        this.action = action;
    }

    @property {
        /// Get the title for this item.
        public string title()
        {
            return _title;
        }

        /// Set the title for this item.
        public string title(string title)
        {
            this._title = title;
            this._width = cast(int)title.count + cast(int)help.count + 1;

            bool nextIsHot;

            foreach (x; title) {
                if (x == '_')
                    nextIsHot = true;
                else {
                    if (nextIsHot) {
                        hotKey = toUpper(x);
                        break;
                    }
                    nextIsHot = false;
                }
            }

            return title;
        }

        package int width()
        {
            return _width;
        }
    }
}

/// A menu bar item contains other menu items.
public class MenuBarItem
{
    private string _title;
    private int _width;
    package wchar_t hotKey;

    /// The children for this MenuBarItem.
    public MenuItem[] children;

    /// Constructor
    public this(string title, MenuItem[] children)
    {
        this.title = title;
        this.children = children;
    }

    @property {
        /// The title of this MenuBarItem.
        public string title()
        {
            return _title;
        }

        /// ditto
        public string title(string title)
        {
            this._title = title;
            this._width = calculateWidth();

            bool nextIsHot;

            foreach (wchar_t x; title) {
                if (x == '_')
                    nextIsHot = true;
                else {
                    if (nextIsHot) {
                        hotKey = toUpper(x);
                        break;
                    }
                    nextIsHot = false;
                }
            }

            return title;
        }

        package int width()
        {
            return _width;
        }
    }

    private int calculateWidth()
    {
        int len;
        foreach (ch; title) {
            if (ch == '_')
                continue;
            len++;
        }

        return len;
    }
}

package class Menu : Container {
    private MenuBarItem barItems;
    private MenuBar host;
    private int current;

    public this(MenuBar host, int x, int y, MenuBarItem barItems)
    {
        this.barItems = barItems;
        this.host = host;
        canFocus = true;

        super(x, y, width + 4, cast(int)barItems.children.length + 2);
    }

    public override void redraw()
    {
        attron(Application.colorMenu);

        drawFrame(x, y, width + 4, cast(int)barItems.children.length + 2, true);

        foreach (size_t i, item; barItems.children) {
            this.move(to!int(i) + 2, x + 1);

            attron(item is null
                ? Application.colorMenuSelected
                : i == current
                    ? Application.colorMenuSelected
                    : Application.colorMenu);

            for (int p; p < Container.width - 2; p++)
                if (item is null)
                    printw("─");
                else
                    addch(' ');

            if (item is null)
                continue;

            this.move(to!int(i) + 2, x + 2);
            drawHotString(item.title,
                i == current ? Application.colorMenuHotSelected : Application.colorMenuHot,
                i == current ? Application.colorMenuSelected : Application.colorMenu);

            // The help string
            int l = cast(int)item.help.count;
            this.move(to!int(i) + 2, Container.width - l - 2);
            printw("%s", item.help.toStringz);
        }

        positionCursor();
        refresh();
    }

    public override void positionCursor()
    {
        this.move(2 + current, x + 2);
    }

    private void run(Action action)
    {
        host.closeMenu();

        if (action)
            action();
    }

    public override bool processKey(wchar_t key)
    {
        switch (key) {
        case KEY_UP:
            current--;
            if (current < 0)
                current = cast(int)barItems.children.length - 1;
            redraw();
            break;
        case KEY_DOWN:
            current++;
            if (current == barItems.children.length)
                current = 0;
            redraw();
            break;
        case KEY_LEFT:
            host.previousMenu();
            break;
        case KEY_RIGHT:
            host.nextMenu();
            break;
        case Keys.Esc:
            host.closeMenu();
            break;
        case Keys.Enter:
            run(barItems.children[current].action);
            break;
        default:
            if (isAlphaNum(key)) {
                immutable wchar_t x = toUpper(key);

                foreach (item; barItems.children) {
                    if (item.hotKey == x) {
                        run(item.action);
                        return true;
                    }
                }
            }
            break;
        }

        return true;
    }

    public override void processMouse(MEVENT* ev)
    {
        if (ev.bstate & BUTTON1_CLICKED || ev.bstate & BUTTON1_RELEASED) {
            if (ev.y < 1)
                return;

            immutable int item = ev.y - 1;

            if (item >= barItems.children.length)
                return;

            run(barItems.children[item].action);
        }

        if ((ev.bstate & BUTTON1_PRESSED) == 0) {
            if (ev.y < 1)
                return;
            if (ev.y - 1 >= barItems.children.length)
                return;

            current = ev.y - 1;
        }
    }

    package int width()
    {
        int maxW;

        foreach (item; barItems.children) {
            if (item is null)
                continue;

            maxW = max(item.width, maxW);
        }

        return maxW;
    }
}

/// A menu bar for your application.
public class MenuBar : Container
{
    /// The menus that were defined when the menubar was created.
    /// This can be updated if the menu is not currently visible.
    public MenuBarItem[] menus;

    /// Initializes a new instance of the MenuBar class with the specified set
    /// of toplevel menu items.
    ///
    /// Params:
    ///     menus = The toplevel menu bar items.
    public this(MenuBarItem[] menus)
    {
        super(0, 0, Application.cols, 1);
        this.menus = menus;
        canFocus = false;
        selected = -1;
    }

    public override void redraw()
    {
        this.move(0, 0);
        attron(Application.colorFocus);
        for (int i; i < Container.width; i++)
            addch(' ');

        int pos = 1;

        foreach (size_t i, menu; menus) {
            this.move(0, pos);

            int hotColor, normalColor;
            if (i == selected) {
                hotColor = Application.colorMenuHotSelected;
                normalColor = Application.colorMenuSelected;
            } else {
                hotColor = Application.colorMenuHot;
                normalColor = Application.colorMenu;
            }

            drawHotString(menu.title, hotColor, normalColor);
            pos += menu.width + 3;
        }

        positionCursor();
    }

    public override void positionCursor()
    {
        int pos;
        foreach (size_t i, menu; menus) {
            if (i == selected) {
                pos++;
                this.move(0, pos);
                return;
            } else {
                pos += menu.width + 4;
            }
        }

        this.move(0, 0);
    }

    // The index of the currently selected MenuBarItem
    private int selected;

    // The currently opened Menu (or null)
    private Menu _openMenu;

    // The Widget that was focused before the MenuBar was activated
    private Widget previousFocused;

    package void openMenu(int index)
    {
        if (_openMenu !is null) {
            container.remove(_openMenu);
            container.redraw();
        }

        int col;
        foreach (menu; menus[0 .. index])
            col += menu.width + 3;

        _openMenu = new Menu(this, col, 1, menus[index]);

        container.add(_openMenu);
        container.focused = _openMenu;
    }

    // Starts the menu from a hotkey
    package void startMenu()
    {
        if (_openMenu !is null)
            return;

        selected = 0;
        previousFocused = container.focused;
        openMenu(selected);
    }

    // activates the menu, handles either first focus, or activating an entry
    // when it was already active. For mouse events.
    private void activate(int idx)
    {
        selected = idx;
        if (_openMenu is null) {
            previousFocused = container.focused;
        }

        openMenu(idx);
    }

    package void closeMenu()
    {
        selected = -1;
        container.remove(_openMenu);

        if (previousFocused && previousFocused.container) {
            previousFocused.container.focused = previousFocused;
        }

        _openMenu = null;
        container.redraw();
        refresh();
    }

    package void previousMenu()
    {
        if (selected <= 0)
            selected = cast(int)menus.length - 1;
        else
            selected--;

        openMenu(selected);
    }

    package void nextMenu()
    {
        if (selected == -1)
            selected = 0;
        else if (selected + 1 == cast(int)menus.length)
            selected = 0;
        else
            selected++;

        openMenu(selected);
    }

    public override bool processHotKey(wchar_t key)
    {
        if (key == KEY_F(9)) {
            startMenu();
            return true;
        }

        if (wchar_t hotKey = isAlt(key)) {
            hotKey = toUpper(hotKey);

            foreach (size_t i, menu; menus) {
                if (menu.hotKey == hotKey) {
                    activate(to!int(i));
                    return true;
                }
            }
        }

        return false;
    }

    public override void processMouse(MEVENT* ev)
    {
        if (ev.bstate & BUTTON1_CLICKED || ev.bstate & BUTTON1_RELEASED) {
            int pos = 1;

            foreach (size_t i, menu; menus) {
                if (ev.x >= pos && ev.x < pos + menu.width) {
                    activate(to!int(i));
                }

                pos += 2 + menu.width + 1;
            }
        }
    }
}
