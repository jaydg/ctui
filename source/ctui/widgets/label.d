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

module ctui.widgets.label;

import std.string : toStringz;
import std.utf : count;
import deimos.ncurses;

import ctui.widgets.widget;

/// Label widget, displays a string at a given position.
public class Label : Widget
{
    protected string text;
    public int Color = -1;

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

    public override void Redraw()
    {
        if (Color != -1)
            attrset(Color);
        else
            attrset(ColorNormal);

        Move(y, x);
        addstr(text.toStringz);
    }

    /// The text displayed by this widget.
    public @property string Text()
    {
        return text;
    }

    /// ditto
    public @property string Text(string value)
    {
        attrset(ColorNormal);
        Move(y, x);
        for (int i = 0; i < text.count; i++)
            addch(' ');
        text = value;
        Redraw();

        return text;
    }
}
