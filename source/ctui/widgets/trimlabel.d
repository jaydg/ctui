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

module ctui.widgets.trimlabel;

import std.utf : count;

import ctui.utils;
import ctui.widgets.label;
import ctui.widgets.widget;

/// A label that can be trimmed to a given position
///
/// Just like a label, but it can be trimmed to a given
/// position if the text being displayed overflows the
/// specified width.
public class TrimLabel : Label
{
    string original;

    /// Public constructor.
    public this(int x, int y, int w, string s)
    {
        super(x, y, s);
        original = s;

        SetString(w, s);
    }

    void SetString(int w, string s)
    {
        if ((fill & Fill.Horizontal) != 0)
            w = container.w - container.Border * 2 - x;

        this.w = w;
        if (s.count > w) {
            if (w < 5)
                text = s.substring(0, w);
            else {
                text = s.substring(0, w/2-2) ~ "..." ~ s.substring(s.count - w/2+1);
            }
        } else
            text = s;
    }

    public override void DoSizeChanged()
    {
        if ((fill & Fill.Horizontal) != 0)
            SetString(0, original);
    }

    /// The text displayed by this widget.
    public override @property string Text()
    {
        return original;
    }

    public override @property string Text(string value)
    {
        super.Text = value;
        SetString(w, value);

        return super.Text;
    }
}
