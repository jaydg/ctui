//
// Simple curses-based GUI toolkit, core
//
// Copyright 2007-2011 Novell Inc
// Copyright 2017 Microsoft Corp
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
import std.algorithm : countUntil, max;
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
        /// The title for this item.
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

        public int width()
        {
            return _width;
        }
    }

    private int calculateWidth()
    {
        return cast(int)title.count + cast(int)help.count + 1;
    }
}

/// A menu bar item contains other menu items.
public class MenuBarItem
{
    private string _title;
    private int _width;

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

            return title;
        }

        public int width()
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
        CanFocus = true;

        super(x, y, width + 4, cast(int)barItems.children.length + 2);
    }

    public override void Redraw()
    {
        attron(Application.ColorMenu);

        DrawFrame(x, y, width + 4, cast(int)barItems.children.length + 2, true);

        foreach (int i, item; barItems.children) {
            Move(i + 2, x + 1);

            attron(item is null
                ? Application.ColorMenuSelected
                : i == current
                    ? Application.ColorMenuSelected
                    : Application.ColorMenu);

            for (int p; p < Container.w - 2; p++)
                if (item is null)
                    printw("─");
                else
                    addch(' ');

            if (item is null)
                continue;

            Move(i + 2, x + 2);
            DrawHotString(item.title,
                i == current ? Application.ColorMenuHotSelected : Application.ColorMenuHot,
                i == current ? Application.ColorMenuSelected : Application.ColorMenu);

            // The help string
            int l = cast(int)item.help.count;
            Move(i + 2, Container.w - l - 2);
            printw("%s", item.help.toStringz);
        }

        PositionCursor();
        refresh();
    }

    public override void PositionCursor()
    {
        Move(2 + current, x + 2);
    }

    private void run(Action action)
    {
        host.CloseMenu();

        if (action)
            action();
    }

    public override bool ProcessKey(wchar_t key)
    {
        switch (key) {
        case KEY_UP:
            current--;
            if (current < 0)
                current = cast(int)barItems.children.length - 1;
            Redraw();
            break;
        case KEY_DOWN:
            current++;
            if (current == barItems.children.length)
                current = 0;
            Redraw();
            break;
        case KEY_LEFT:
            host.PreviousMenu();
            break;
        case KEY_RIGHT:
            host.NextMenu();
            break;
        case Keys.Esc:
            host.CloseMenu();
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

    public override void ProcessMouse(MEVENT* ev)
    {
        if ((ev.bstate & BUTTON1_CLICKED) == 0 || (ev.bstate & BUTTON1_RELEASED) == 0) {
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

    private int selected;
    private Action action;

    /// Initializes a new instance of the MenuBar class with the specified set
    /// of toplevel menu items.
    ///
    /// Params:
    ///     menus = The toplevel menu bar items.
    public this(MenuBarItem[] menus)
    {
        super(0, 0, Application.Cols, 1);
        this.menus = menus;
        CanFocus = false;
        selected = -1;
    }

    public override void Redraw()
    {
        Move(0, 0);
        attron(Application.ColorFocus);
        for (int i; i < Container.w; i++)
            addch(' ');

        int pos = 1;

        foreach (int i, menu; menus) {
            Move(0, pos);

            int hotColor, normalColor;
            if (i == selected) {
                hotColor = Application.ColorMenuHotSelected;
                normalColor = Application.ColorMenuSelected;
            } else {
                hotColor = Application.ColorMenuHot;
                normalColor = Application.ColorMenu;
            }

            DrawHotString(menu.title, hotColor, normalColor);
            pos += menu.width + 3;
        }

        PositionCursor();
    }

    public override void PositionCursor()
    {
        int pos;
        foreach (int i, menu; menus) {
            if (i == selected) {
                pos++;
                Move(0, pos);
                return;
            } else {
                pos += menu.width + 4;
            }
        }

        Move(0, 0);
    }

    void Selected(MenuItem item)
    {
        running = false;
        action = item.action;
    }

    private Menu openMenu;
    private Widget previousFocused;

    package void OpenMenu(int index)
    {
        if (openMenu !is null) {
            container.Remove(openMenu);
            container.Redraw();
        }

        int col;
        foreach (menu; menus[0 .. index])
            col += menu.width + 3;

        openMenu = new Menu(this, col, 1, menus[index]);

        container.Add(openMenu);
        container.SetFocus(openMenu);
    }

    // Starts the menu from a hotkey
    package void StartMenu()
    {
        if (openMenu !is null)
            return;

        selected = 0;
        previousFocused = container.focused;
        OpenMenu(selected);
    }

    // Activates the menu, handles either first focus, or activating an entry
    // when it was already active. For mouse events.
    void Activate(int idx)
    {
        selected = idx;
        if (openMenu is null) {
            previousFocused = container.focused;
        }

        OpenMenu(idx);
    }

    package void CloseMenu()
    {
        selected = -1;
        container.Remove(openMenu);

        if (previousFocused && previousFocused.container) {
            previousFocused.container.SetFocus(previousFocused);
        }

        openMenu = null;
        container.Redraw();
        refresh();
    }

    package void PreviousMenu()
    {
        if (selected <= 0)
            selected = cast(int)menus.length - 1;
        else
            selected--;

        OpenMenu(selected);
    }

    package void NextMenu()
    {
        if (selected == -1)
            selected = 0;
        else if (selected + 1 == cast(int)menus.length)
            selected = 0;
        else
            selected++;

        OpenMenu(selected);
    }

    public override bool ProcessHotKey(wchar_t key)
    {
        if (key == KEY_F(9)) {
            StartMenu();
            return true;
        }

        return super.ProcessHotKey(key);
    }

    public override bool ProcessKey(wchar_t key)
    {
        switch (key) {
        case KEY_LEFT:
            selected--;
            if (selected < 0)
                selected = cast(int)menus.length - 1;
            break;
        case KEY_RIGHT:
            selected = (selected + 1) % cast(int)menus.length;
            break;

        case Keys.Esc:
        case Keys.CtrlC:
            running = false;
            break;

        default:
            if ((key >= 'a' && key <= 'z') || (key >= 'A' && key <= 'Z') || (key >= '0' && key <= '9')) {
                immutable wchar_t c = toUpper(key);

                if (menus[selected].children == null)
                    return false;

                foreach (mi; menus[selected].children) {
                    size_t p = mi.title.countUntil('_');
                    if (p != -1 && p + 1 < mi.title.count) {
                        if (mi.title[p + 1] == c) {
                            Selected(mi);
                            return true;
                        }
                    }
                }
            }

            return false;
        }

        return true;
    }

    public override void ProcessMouse(MEVENT* ev)
    {
        if (ev.bstate == BUTTON1_CLICKED) {
            int pos = 1;

            foreach (int i, menu; menus) {
                if (ev.x > pos && ev.x < pos + 1 + menu.width) {
                    Activate(i);
                }

                pos += 2 + menu.width + 1;
            }
        }
    }
}
