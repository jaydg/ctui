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

module ctui.widgets.messagebox;

import std.utf : count;

import ctui.application;
import ctui.widgets.button;
import ctui.widgets.dialog;
import ctui.widgets.label;

public class MessageBox
{
    public static int Query(int width, int height, string title, string message, string[] buttons)
    {
        auto d = new Dialog(width, height, title);
        int clicked = -1, count = 0;

        foreach (s; buttons)
        {
            int n = count++;
            Button b = new Button(s);
            b.clicked = {
                clicked = n;
                d.running = false;
            };
            d.AddButton(b);
        }
        if (message !is null) {
            Label l = new Label((width - 4 - cast(int)message.count) / 2, 0, message);
            d.Add(l);
        }

        Application.Run(d);
        return clicked;
    }
}
