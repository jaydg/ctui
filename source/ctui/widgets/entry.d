//
// Simple curses-based GUI toolkit, entry widget
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

module ctui.widgets.entry;

import core.stdc.stddef;
import std.algorithm : min;
import std.conv : text;
import std.encoding : index;
import std.string : leftJustify, toStringz;
import std.uni;
import std.utf : count;

alias toText = std.conv.text;

import deimos.ncurses;

import ctui.application;
import ctui.keys;
import ctui.utils;
import ctui.widgets.widget;

/// Text data entry widget
///
/// The Entry widget provides Emacs-like editing
/// functionality, and mouse support.
public class Entry : Widget
{
    private string _text, kill;
    private size_t first, point;
    private int _color;
    private bool used;
    private bool _secret;

    /// Changed event, raised when the text has clicked.
    ///
    /// Client code can hook up to this event, it is
    /// raised when the text in the entry changes.
    public void delegate() changed;

    /// Public constructor.
    public this(int x, int y, int w, string s)
    {
        super(x, y, w, 1);
        if (s == null)
            s = "";

        text = s;
        point = s.count;
        first = point > w ? point - w : 0;
        canFocus = true;
        color = Application.colorDialogFocus;
    }

    public @property
    {
        override bool hasFocus(bool value)
        {
            curs_set(value);
            return super.hasFocus(value);
        }

        /// Gets the text in the entry.
        string text()
        {
            return _text;
        }

        /// Sets the text in the entry.
        string text(string value)
        {
            _text = value;
            if (point > text.count) {
                point = text.count;
            }

            first = point > width ? point - width : 0;
            redraw();

            return text;
        }

        /// Gets the secret property.
        bool secret()
        {
            return _secret;
        }

        /// Sets the secret property.
        ///
        /// This makes the text entry suitable for entering passwords.
        bool secret(bool value)
        {
            return _secret = value;
        }

        /// The color used to display the text.
        int color()
        {
            return _color;
        }

        /// ditto
        int color(int value)
        {
            _color = value;
            container.redraw();
            return _color;
        }

        /// The current cursor position.
        int cursorPosition()
        {
            return cast(int)point;
        }
    }

    /// Sets the cursor position.
    public override void positionCursor()
    {
        this.move(y, cast(int)(x + point - first));
    }

    public override void redraw()
    {
        attrset(color);
        this.move(y, x);

        if (secret) {
            int vislength = min(text.count, width);
            char[] asterixes = new char[vislength + 1];
            asterixes[] = '*';
            asterixes[vislength] = 0;
            printw("%-*s", width, asterixes.ptr);
        } else {
            size_t l = min(text.count - first, width);
            string vis = text.substring(first, l).leftJustify(width);
            printw("%-*s", width, vis.toStringz);
        }

        positionCursor();
    }

    private void adjust()
    {
        if (point < first) {
            first = point;
        } else if (first + point >= width) {
            first = point - (width / 3);
        }

        redraw();
        refresh();
    }

    private void setText(string new_text)
    {
        if (new_text != text) {
            text = new_text;

            // call callback
            if (changed)
                changed();
        }
    }

    public override bool processKey(wchar_t key)
    {
        switch (key) {
        case 127:
        case KEY_BACKSPACE:
            if (point == 0)
                return true;

            setText(text.substring(0, point - 1) ~ text.substring(point));
            point--;
            adjust();
            break;

        case KEY_HOME:
        case Keys.CtrlA: // Home
            point = 0;
            adjust();
            break;

        case KEY_LEFT:
        case Keys.CtrlB: // back character
            if (point > 0) {
                point--;
                adjust();
            }
            break;

        case KEY_DC:
        case Keys.CtrlD: // Delete
            if (point == text.count) {
                break;
            }

            setText(text.substring(0, point) ~ text.substring(point + 1));
            adjust();
            break;

        case KEY_END:
        case Keys.CtrlE: // End
            point = text.count;
            adjust();
            break;

        case KEY_RIGHT:
        case Keys.CtrlF: // Control-f, forward char
            if (point == text.count) {
                break;
            }
            point++;
            adjust();
            break;

        case Keys.CtrlK: // kill-to-end
            kill = text.substring(point);
            setText(text.substring(0, point));
            adjust();
            break;

        case Keys.CtrlY: // Control-y, yank
            if (kill == null)
                return true;

            if (point == text.count) {
                setText(text ~ kill);
                point = text.count;
            } else {
                setText(text.substring(0, point) ~ kill ~ text.substring(point));
                point += kill.count;
            }

            adjust();
            break;

        case 'b' + Keys.Alt:
            immutable bw = wordBackward(point);
            if (bw != -1) {
                point = bw;
            }

            adjust();
            break;

        case 'f' + Keys.Alt:
            immutable fw = wordForward(point);
            if (fw != -1) {
                point = fw;
            }

            adjust();
            break;

        default:
            // Ignore other control characters.
            if (key < 32 || key > 255)
                return false;

            if (used) {
                if (point == text.count) {
                    setText(text ~ toText(key));
                } else {
                    setText(text.substring(0, point) ~ toText(key) ~ text.substring(point));
                }
                point++;
            } else {
                setText("" ~ toText(key));
                first = 0;
                point = 1;
            }
            used = true;
            adjust();
            return true;
        }
        used = true;
        return true;
    }

    private size_t wordForward(size_t p)
    {
        if (p >= text.count) {
            return -1;
        }

        int i = cast(int)p;
        if (text[text.index(i)].isPunctuation || text[text.index(i)].isWhite) {
            for (; i < text.count; i++) {
                if (text[text.index(i)].isAlphaNum)
                    break;
            }
            for (; i < text.count; i++) {
                if (!text[text.index(i)].isAlphaNum)
                    break;
            }
        } else {
            for (; i < text.count; i++) {
                if (!text[text.index(i)].isAlphaNum)
                    break;
            }
        }

        if (i != p) {
            return i;
        }

        return -1;
    }

    private size_t wordBackward(size_t p)
    {
        if (p == 0)
            return -1;

        int i = cast(int)p - 1;
        if (i == 0)
            return 0;

        if (isPunctuation(text[text.index(i)])
                || isSymbol(text[text.index(i)])
                || isWhite(text[text.index(i)]))
        {
            for (; i >= 0; i--) {
                if (isAlphaNum(text[text.index(i)]))
                    break;
            }
            for (; i >= 0; i--) {
                if (!isAlphaNum(text[text.index(i)]))
                    break;
            }
        } else {
            for (; i >= 0; i--) {
                if (!isAlphaNum(text[text.index(i)]))
                    break;
            }
        }
        i++;

        if (i != p)
            return i;

        return -1;
    }

    public override void processMouse(MEVENT* ev)
    {
        if (ev.bstate & BUTTON1_CLICKED || ev.bstate & BUTTON1_RELEASED)
            return;

        container.focused = this;

        // We could also set the cursor position.
        point = first + (ev.x - x);
        if (point > text.count)
            point = text.count;
        if (point < first)
            point = 0;

        container.redraw();
        container.positionCursor();
    }
}
