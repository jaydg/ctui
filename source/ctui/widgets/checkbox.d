//
// Simple curses-based GUI toolkit, checkbox widget
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

module ctui.widgets.checkbox;

import core.stdc.stddef;
import std.string : toStringz;
import std.uni : isUpper;
import std.utf : count;
import deimos.ncurses;

import ctui.widgets.widget;

/// CheckBox widget
///
/// Provides an on/off toggle that the user can set.
public class CheckBox : Widget {
    private string _text;
    private int hot_pos = -1;
    private char hot_key;
    private bool _checked;

    /// Toggled event, raised when the CheckButton is toggled.
    ///
    /// Client code can hook up to this event, it is raised when the
    /// checkbutton is activated either with the mouse or the keyboard.
    public void delegate() toggled;

    /// Public constructor, creates a CheckButton based on
    /// the given text at the given position.
    ///
    /// The size of CheckButton is computed based on the
    /// text length. This CheckButton is not toggled.
    public this(int x, int y, string s)
    {
        this(x, y, s, false);
    }

    /// Public constructor, creates a CheckButton based on
    /// the given text at the given position and a state.
    ///
    /// The size of CheckButton is computed based on the text length.
    public this(int x, int y, string s, bool is_checked)
    {
        super(x, y, cast(int)s.count + 4, 1);
        checked = is_checked;
        text = s;

        canFocus = true;
    }

    public @property
    {
        /// Get the state of the checkbox.
        bool checked()
        {
            return _checked;
        }

        /// Set the state of the checkbox.
        bool checked(bool value)
        {
            return _checked = value;
        }

        /// Get the text displayed by this widget.
        string text()
        {
            return _text;
        }

        /// Get the text displayed by this widget.
        string text(string value)
        {
            _text = value;

            int i = 0;
            hot_pos = -1;
            hot_key = 0;

            foreach (c; text) {
                if (isUpper(c)) {
                    hot_key = c;
                    hot_pos = i;
                    break;
                }
                i++;
            }

            return _text;
        }
    }

    public override void redraw()
    {
        attrset(colorNormal);
        Move(y, x);
        addstr(checked ? "[X] ".toStringz : "[ ]".toStringz);
        attrset(hasFocus ? colorFocus : colorNormal);
        Move(y, x + 3);
        addstr(text.toStringz);
        if (hot_pos != -1) {
            Move(y, x + 3 + hot_pos);
            attrset(hasFocus ? colorHotFocus : colorHotNormal);
            addch(hot_key);
        }
        positionCursor();
    }

    public override void positionCursor()
    {
        Move(y, x + 1);
    }

    public override bool processKey(wchar_t c)
    {
        if (c == ' ') {
            checked = !checked;
            if (toggled)
                toggled();

            redraw();
            return true;
        }
        return false;
    }

    public override void processMouse(MEVENT* ev)
    {
        if (ev.bstate & BUTTON1_CLICKED || ev.bstate & BUTTON1_RELEASED) {
            container.focused = this;
            container.redraw();

            checked = !checked;
            if (toggled)
                toggled();

            redraw();
        }
    }
}
