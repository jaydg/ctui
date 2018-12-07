//
// Simple curses-based GUI toolkit, button widget
//
// Copyright (C) 2007-2011 Novell (http://www.novell.com)
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

module ctui.widgets.button;

import core.stdc.stddef;
import std.string : toStringz;
import std.uni;
import std.utf : count;

import deimos.ncurses;

import ctui.keys;
import ctui.widgets.widget;

/// Button widget
///
/// Provides a button that can be clicked, or pressed with the enter key and
/// processes hotkeys (the first uppercase letter in the button becomes the
/// hotkey).
public class Button : Widget {
    private string _text;
    private string shown_text;
    private char hot_key;
    private int  hot_pos = -1;
    private bool is_default;

    /// Clicked event, raised when the button is clicked.
    ///
    /// Client code can hook up to this event, it is raised when the button is
    /// activated either with the mouse or the keyboard.
    public void delegate() clicked;

    /// Public constructor, creates a button based on
    /// the given text at position 0,0
    ///
    /// The size of the button is computed based on the
    /// text length. This button is not a default button.
    public this(string s)
    {
        this(0, 0, s);
    }

    /// Public constructor, creates a button based on the given text.
    ///
    /// If the value for is_default is true, a special decoration is used, and
    /// the enter key on a dialog would implicitly activate this button.
    public this(string s, bool is_default)
    {
        this(0, 0, s, is_default);
    }

    /// Public constructor, creates a button based on
    /// the given text at the given position.
    ///
    /// The size of the button is computed based on the
    /// text length. This button is not a default button.
    public this(int x, int y, string s)
    {
        this(x, y, s, false);
    }

    /// Get the text displayed by this widget.
    public @property string text()
    {
        return _text;
    }

    /// Set the text displayed by this widget.
    public @property string text(string value)
    {
        _text = value;
        if (is_default)
            shown_text = "[< " ~ value ~ " >]";
        else
            shown_text = "[ " ~ value ~ " ]";

        hot_pos = -1;
        hot_key = 0;
        int i = 0;
        foreach (c; shown_text)
        {
            if (isUpper(c))
            {
                hot_key = c;
                hot_pos = i;
                break;
            }
            i++;
        }

        return text;
    }

    /// Public constructor, creates a button based on
    /// the given text at the given position.
    ///
    /// If the value for is_default is true, a special decoration is used, and
    /// the enter key on a dialog would implicitly activate this button.
    public this(int x, int y, string s, bool is_default)
    {
       super(x, y, cast(int)s.count + 4 + (is_default ? 2 : 0), 1);
       canFocus = true;

       this.is_default = is_default;
       text = s;
    }

    public override void redraw()
    {
        attrset(hasFocus ? colorFocus : colorNormal);
        Move(y, x);
        addstr(shown_text.toStringz);

        if (hot_pos != -1) {
            Move(y, x + hot_pos);
            attrset(hasFocus ? colorHotFocus : colorHotNormal);
            addch(hot_key);
        }
    }

    public override void positionCursor()
    {
        Move(y, x + hot_pos);
    }

    private bool checkKey(int key)
    {
        if (toUpper(key) == hot_key) {
            container.setFocus(this);
            if (clicked)
                clicked();

            return true;
        }
        return false;
    }

    public override bool processHotKey(wchar_t key)
    {
        immutable k = isAlt(key);
        if (k != 0)
            return checkKey(k);

        return false;
    }

    public override bool processColdKey(wchar_t key)
    {
        if (is_default && key == '\n') {
            if (clicked)
                clicked();

            return true;
        }

        return checkKey(key);
    }

    public override bool processKey(wchar_t c)
    {
        if (c == '\n' || c == ' ' || toUpper(c) == hot_key) {
            if (clicked)
                clicked();

            return true;
        }
        return false;
    }

    public override void processMouse(MEVENT* ev)
    {
        if (ev.bstate & BUTTON1_CLICKED || ev.bstate & BUTTON1_RELEASED) {
            container.setFocus(this);
            container.redraw();

            if (clicked)
                clicked();
        }
    }
}
