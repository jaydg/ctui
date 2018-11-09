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

module ctui.widgets.dialog;

import std.string : toStringz;

import deimos.ncurses;

import ctui.application;
import ctui.keys;
import ctui.widgets.button;
import ctui.widgets.frame;
import ctui.widgets.widget;

/// A Dialog is a container that can also have a number of
/// buttons at the bottom
///
/// Dialogs are containers that can have a set of buttons at
/// the bottom.   Dialogs are automatically centered on the
/// screen, and on screen changes the buttons are
/// relaid out.
///
/// To make the dialog box run until an option has been
/// executed, you would typically create the dialog box and
/// then call Application.Run on the Dialog instance.
public class Dialog : Frame
{
    int button_len;
    Button[] buttons;

    const int button_space = 3;

    /// Public constructor.
    public this(int w, int h, string title)
    {
        super((Application.Cols - w) / 2, (Application.Lines - h) / 3, w, h, title);
        ContainerColorNormal = Application.ColorDialogNormal;
        ContainerColorFocus = Application.ColorDialogFocus;
        ContainerColorHotNormal = Application.ColorDialogHotNormal;
        ContainerColorHotFocus = Application.ColorDialogHotFocus;

        Border++;
    }

    /// Makes the default style for the dialog use the error colors.
    public void ErrorColors()
    {
        ContainerColorNormal = Application.ColorError;
        ContainerColorFocus = Application.ColorErrorFocus;
        ContainerColorHotFocus = Application.ColorErrorHotFocus;
        ContainerColorHotNormal = Application.ColorErrorHot;
    }

    public override void Prepare()
    {
        LayoutButtons();
    }

    void LayoutButtons()
    {
        if (buttons == null)
            return;

        int p = (w - button_len) / 2;

        foreach (b; buttons) {
            b.x = p;
            b.y = h - 5;

            p += b.w + button_space;
        }
    }

    /// Adds a button to the dialog
    public void AddButton(Button b)
    {
        buttons ~= b;
        button_len += b.w + button_space;

        Add(b);
    }

    public override void GetBase(out int row, out int col)
    {
        super.GetBase(row, col);
        row++;
        col++;
    }

    public override void ContainerMove(int row, int col)
    {
        super.ContainerMove(row + 1, col + 1);
    }

    public override void Redraw()
    {
        attrset(ContainerColorNormal);
        Clear();

        Widget.DrawFrame(x + 1, y + 1, w - 2, h - 2);
        move(y + 1, x + (w - cast(int)Title.length) / 2);
        addch(' ');
        attrset(Application.ColorDialogHotNormal);
        addstr(Title.toStringz);
        addch(' ');
        RedrawChildren();
    }

    public override bool ProcessKey(int key)
    {
        if (key == Keys.Esc) {
            running = false;
            return true;
        }

        return super.ProcessKey(key);
    }

    public override void DoSizeChanged()
    {
        super.DoSizeChanged();

        x = (Application.Cols - w) / 2;
        y = (Application.Lines - h) / 3;

        LayoutButtons();
    }
}


