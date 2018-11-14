//
// Simple curses-based GUI toolkit, core
//
// Authors:
//   Miguel de Icaza (miguel.de.icaza@gmail.com)
//
// Copyright (C) 2007-2011 Novell (http://www.novell.com)
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
import std.algorithm : countUntil;
import std.string : toStringz;
import std.uni : toUpper;
import std.utf : count;

import deimos.ncurses;

import ctui.application;
import ctui.keys;
import ctui.widgets.container;

public alias Action = void delegate();

public class MenuItem
{
    public string Title;
    public string Help;
    public Action action;
    public int Width;

    public this(string title, string help, Action action)
    {
        Title = title;
        Help = help;
        action = action;
        Width = cast(int)Title.count + cast(int)Help.count + 1;
    }
}

public class MenuBarItem
{
    public string Title;
    public MenuItem[] Children;
    public int Current;

    public this(string title, MenuItem[] children)
    {
        Title = title;
        Children = children;
    }
}

public class MenuBar : Container
{
    public MenuBarItem[] Menus;
    int selected;
    Action action;

    public this(MenuBarItem[] menus)
    {
        super(0, 0, Application.Cols, 1);
        Menus = menus;
        CanFocus = false;
        selected = -1;
    }

    /// Activates the menubar
    public void Activate(int idx)
    {
        if (idx < 0 || idx > Menus.length)
            throw new Exception("idx");

        action = null;
        selected = idx;

        foreach (m; Menus)
            m.Current = 0;

        Application.Run(this);
        selected = -1;
        Container.Redraw();

        if (action !is null)
            action();
    }

    void DrawMenu(int idx, int col, int line)
    {
        int max = 0;
        auto menu = Menus[idx];

        if (menu.Children == null)
            return;

        foreach (m; menu.Children) {
            if (m is null)
                continue;

            if (m.Width > max)
                max = m.Width;
        }

        max += 4;
        DrawFrame(col + x, line, max, cast(int)menu.Children.length + 2, true);

        for (int i = 0; i < menu.Children.length; i++) {
            auto item = menu.Children[i];

            Move(line + 1 + i, col + 1);
            attrset(item is null
                    ? Application.ColorFocus
                    : i == menu.Current
                        ? Application.ColorMenuSelected
                        : Application.ColorMenu);
            for (int p = 0; p < max - 2; p++)
                addch(item is null ? ACS_HLINE : ' ');

            if (item is null)
                continue;

            Move(line + 1 + i, col + 2);
            DrawHotString(item.Title,
                       i == menu.Current ? Application.ColorMenuHotSelected : Application.ColorMenuHot,
                       i == menu.Current ? Application.ColorMenuSelected : Application.ColorMenu);

            // The help string
            int l = cast(int)item.Help.count;
            Move(line + 1 + i, col + x + max - l - 2);
            addstr(item.Help.toStringz);
        }
    }

    public override void Redraw()
    {
        Move(y, 0);
        attrset(Application.ColorFocus);
        for (int i = 0; i < Application.Cols; i++)
            addch(' ');

        Move(y, 1);
        int pos = 0;
        for (int i = 0; i < Menus.length; i++) {
            auto menu = Menus[i];
            if (i == selected) {
                DrawMenu(i, pos, y+1);
                attrset(Application.ColorMenuSelected);
            } else
                attrset(Application.ColorFocus);

            Move(y, pos);
            addch(' ');
            addstr(menu.Title.toStringz);
            addch(' ');
            if (HasFocus && i == selected)
                attrset(Application.ColorMenuSelected);
            else
                attrset(Application.ColorFocus);
            addstr("  ".toStringz);

            pos += menu.Title.count + 4;
        }
        PositionCursor();
    }

    public override void PositionCursor()
    {
        int pos = 0;
        for (int i = 0; i < Menus.length; i++) {
            if (i == selected) {
                pos++;
                Move(y, pos);
                return;
            } else {
                pos += Menus[i].Title.count + 4;
            }
        }
        Move(y, 0);
    }

    void Selected(MenuItem item)
    {
        running = false;
        action = item.action;
    }

    public override bool ProcessKey(wchar_t key)
    {
        switch(key) {
        case KEY_UP:
            if (Menus[selected].Children == null)
                return false;

            int current = Menus[selected].Current;
            do {
                current--;
                if (current < 0)
                    current = cast(int)Menus[selected].Children.length - 1;
            } while (Menus[selected].Children[current] is null);

            Menus[selected].Current = current;
            Redraw();
            refresh();

            return true;

        case KEY_DOWN:
            if (Menus[selected].Children == null)
                return false;

            do {
                Menus[selected].Current = (Menus[selected].Current + 1)
                    % cast(int)Menus[selected].Children.length;
            } while (Menus[selected].Children[Menus[selected].Current] is null);

            Redraw();
            refresh();
            break;

        case KEY_LEFT:
            selected--;
            if (selected < 0)
                selected = cast(int)Menus.length - 1;
            break;
        case KEY_RIGHT:
            selected = (selected + 1) % cast(int)Menus.length;
            break;

        case Keys.Enter:
            if (Menus[selected].Children is null)
                return false;

            Selected(Menus[selected].Children[Menus[selected].Current]);
            break;

        case Keys.Esc:
        case Keys.CtrlC:
            running = false;
            break;

        default:
            if ((key >= 'a' && key <= 'z') || (key >= 'A' && key <= 'Z') || (key >= '0' && key <= '9'))
            {
                wchar_t c = key.toUpper;

                if (Menus[selected].Children == null)
                    return false;

                foreach (mi; Menus[selected].Children)
                {
                    auto p = mi.Title.countUntil('_');
                    if (p != -1 && p + 1 < mi.Title.count) {
                        if (mi.Title[p + 1] == c) {
                            Selected(mi);
                            return true;
                        }
                    }
                }
            }

            return false;
        }
        Container.Redraw();
        refresh();
        return true;
    }
}
