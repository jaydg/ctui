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

module ctui.widgets.entry;

import core.stdc.stddef;
import std.conv : to;
import std.uni;

import deimos.ncurses;

import ctui.application;
import ctui.keys;
import ctui.utils;
import ctui.widgets.widget;

/// Text data entry widget
///
/// The Entry widget provides Emacs-like editing
/// functionality,  and mouse support.
public class Entry : Widget
{
    string text, kill;
    int first, point;
    int color;
    bool used;
    bool secret;

    /// Changed event, raised when the text has clicked.
    ///
    /// Client code can hook up to this event, it is
    /// raised when the text in the entry changes.
    public void delegate() changed;

    ///   Public constructor.
    public this(int x, int y, int w, string s)
    {
        super(x, y, w, 1);
        if (s == null)
            s = "";

        text = s;
        point = cast(int)s.length;
        first = point > w ? point - w : 0;
        CanFocus = true;
        Color = Application.ColorDialogFocus;
    }

    public @property
    {
        /// Sets or gets the text in the entry.
        string Text()
        {
            return text;
        }

        string Text(string value)
        {
            text = value;
            if (point > text.length) {
                point = cast(int)text.length;
            }

            first = point > w ? point - w : 0;
            Redraw();

            return text;
        }

        /// Sets the secret property.
        ///
        /// This makes the text entry suitable for entering passwords.
        bool Secret()
        {
            return secret;
        }

        bool Secret(bool value)
        {
            return secret = value;
        }

        /// The color used to display the text
        int Color()
        {
            return color;
        }

        int Color(int value)
        {
            color = value;
            container.Redraw();
            return color;
        }

        /// The current cursor position.
        int CursorPosition()
        {
            return point;
        }
    }
    /// Sets the cursor position.
    public override void PositionCursor()
    {
        Move(y, x + point - first);
    }

    public override void Redraw()
    {
        attrset(Color);
        Move(y, x);

        for (int i = 0; i < w; i++) {
            int p = first + i;

            if (p < text.length) {
                addch(Secret ? '*' : text[p]);
            } else {
                addch(' ' );
            }
        }
        PositionCursor();
    }

    void Adjust()
    {
        if (point < first) {
            first = point;
        } else if (first + point >= w) {
            first = point - (w / 3);
        }

        Redraw();
        refresh();
    }

    void SetText(string new_text)
    {
        if (new_text != text) {
            text = new_text;

            // call callback
            if (changed)
                changed();
        }
    }

    public override bool ProcessKey(wchar_t key)
    {
        switch (key) {
        case 127:
        case KEY_BACKSPACE:
            if (point == 0)
                return true;

            SetText(text.substring(0, point - 1) ~ text.substring(point));
            point--;
            Adjust();
            break;

        case KEY_HOME:
        case Keys.CtrlA: // Home
            point = 0;
            Adjust();
            break;

        case KEY_LEFT:
        case Keys.CtrlB: // back character
            if (point > 0) {
                point--;
                Adjust();
            }
            break;

        case Keys.CtrlD: // Delete
            if (point == text.length) {
                break;
            }

            SetText(text.substring(0, point) ~ text.substring(point+1));
            Adjust();
            break;

        case Keys.CtrlE: // End
            point = cast(int)text.length;
            Adjust();
            break;

        case KEY_RIGHT:
        case Keys.CtrlF: // Control-f, forward char
            if (point == text.length) {
                break;
            }
            point++;
            Adjust();
            break;

        case Keys.CtrlK: // kill-to-end
            kill = text.substring(point);
            SetText(text.substring(0, point));
            Adjust();
            break;

        case Keys.CtrlY: // Control-y, yank
            if (kill == null)
                return true;

            if (point == text.length) {
                SetText(text ~ kill);
                point = cast(int)text.length;
            } else {
                SetText(text.substring(0, point) ~ kill ~ text.substring(point));
                point += kill.length;
            }

            Adjust();
            break;

        case 'b' + Keys.Alt:
            int bw = WordBackward(point);
            if (bw != -1) {
                point = bw;
            }

            Adjust();
            break;

        case 'f' + Keys.Alt:
            int fw = WordForward(point);
            if (fw != -1) {
                point = fw;
            }

            Adjust();
            break;

        default:
            // Ignore other control characters.
            if (key < 32 || key > 255)
                return false;

            if (used) {
                if (point == text.length) {
                    SetText(text ~ to!char(key));
                } else {
                    SetText(text.substring(0, point) ~ to!char(key) ~ text.substring(point));
                }
                point++;
            } else {
                SetText("" ~ to!char(key));
                first = 0;
                point = 1;
            }
            used = true;
            Adjust();
            return true;
        }
        used = true;
        return true;
    }

    int WordForward(int p)
    {
        if (p >= text.length) {
            return -1;
        }

        int i = p;
        if (text[p].isPunctuation || text[p].isWhite) {
            for (; i < text.length; i++) {
                if (text[i].isAlphaNum)
                    break;
            }
            for (; i < text.length; i++) {
                if (!text[i].isAlphaNum)
                    break;
            }
        } else {
            for (; i < text.length; i++) {
                if (!text[i].isAlphaNum)
                    break;
            }
        }

        if (i != p) {
            return i;
        }

        return -1;
    }

    int WordBackward(int p)
    {
        if (p == 0)
            return -1;

        int i = p-1;
        if (i == 0)
            return 0;

        if (isPunctuation(text[i]) || isSymbol(text[i]) || isWhite(text[i])) {
            for (; i >= 0; i--) {
                if (isAlphaNum(text[i]))
                    break;
            }
            for (; i >= 0; i--) {
                if (!isAlphaNum(text[i]))
                    break;
            }
        } else {
            for (; i >= 0; i--) {
                if (!isAlphaNum(text[i]))
                    break;
            }
        }
        i++;

        if (i != p)
            return i;

        return -1;
    }

    public override void ProcessMouse(MEVENT* ev)
    {
        if ((ev.bstate & BUTTON1_CLICKED) == 0)
            return;

        container.SetFocus(this);

        // We could also set the cursor position.
        point = first + (ev.x - x);
        if (point > text.length)
            point = cast(int)text.length;
        if (point < first)
            point = 0;

        container.Redraw();
        container.PositionCursor();
    }
}
