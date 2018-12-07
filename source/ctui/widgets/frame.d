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

module ctui.widgets.frame;

import std.string : toStringz;

import deimos.ncurses;

import ctui.application;
import ctui.widgets.container;
import ctui.widgets.widget;

/// Framed-container widget.
///
/// A container that provides a frame around its children,
/// and an optional title.
public class Frame : Container
{
    public string Title;

    /// Creates an empty frame, with the given title
    public this(string title)
    {
        this(0, 0, 0, 0, title);
    }

    /// Public constructor, a frame, with the given title.
    public this(int x, int y, int w, int h, string title)
    {
        super(x, y, w, h);
        Title = title;
        Border++;
    }

    public override void GetBase(out int row, out int col)
    {
        row = 1;
        col = 1;
    }

    public override void ContainerMove(int row, int col)
    {
        super.ContainerMove(row + 1, col + 1);
    }

    public override void Redraw()
    {
        attrset(ContainerColorNormal);
        Clear();

        Widget.DrawFrame(x, y, width, height);
        attrset(Container.ContainerColorNormal);
        move(y, x + 1);
        if (HasFocus)
            attrset(Application.ColorDialogNormal);
        if (Title != null) {
            addch(' ');
            addstr(Title.toStringz);
            addch(' ');
        }
        RedrawChildren();
    }

    public override void Add(Widget w)
    {
        super.Add(w);
    }
}
