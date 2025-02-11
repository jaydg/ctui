//
// Simple curses-based GUI toolkit, label widget
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

module ctui.widgets.label;

import std.string : toStringz;
import std.utf : count;
import deimos.ncurses;

import ctui.widgets.widget;

/// Label widget, displays a string at a given position.
public class Label : Widget
{
    protected string _text;
    /// Curses color pair that allows replacing the default color.
    /// When set to the default, -1, `colorNormal` is used.
    public int color = -1;

    /// Public constructor: creates a label at the given
    /// coordinate with the given string.
    public this(int x, int y, string s)
    {
        super(x, y, cast(int)s.count, 1);
        text = s;
    }

    /// Public constructor
    ///
    /// Ths variant accepts `std.format` format strings and arguments.
    public this(int x, int y, string s, Args...)(Args args)
    {
        text = format(s, args);
        super(x, y, cast(int)s.count, 1);
    }

    public override void redraw()
    {
        if (color != -1)
            attrset(color);
        else
            attrset(colorNormal);

        this.move(y, x);
        addstr(text.toStringz);
    }

    /// The text displayed by this widget.
    public @property string text()
    {
        return _text;
    }

    /// ditto
    public @property string text(string value)
    {
        attrset(colorNormal);
        this.move(y, x);
        for (int i = 0; i < _text.count; i++)
            addch(' ');
        _text = value;
        redraw();

        return text;
    }
}
