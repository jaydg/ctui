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

module ctui.widgets.listview;

import core.stdc.stddef;
import deimos.ncurses;

import ctui.keys;
import ctui.widgets.widget;

/// Model for the ListView widget.
///
/// Consumers of the ListView widget should implement this interface
public interface IListProvider {
    /// Number of items in the model.
    ///
    /// This should return the number of items in the model.
    @property int Items();

    /// Whether the ListView should allow items to be marked.
    @property bool AllowMark();

    /// Whether the given item is marked.
    bool IsMarked(int item);

    /// This should render the item at the given line,
    /// col with the specified width.
    void Render(int line, int col, int width, int item);

    /// Callback: this is the way that the model is
    /// hooked up to its actual view.
    void SetListView(ListView target);

    /// Allows the model to process the given keystroke.
    ///
    /// The model should return true if the key was
    /// processed, false otherwise.
    bool ProcessKey(wchar_t ch);

    /// Callback: invoked when the selected item has changed.
    void SelectedChanged();
}

/// A Listview widget.
///
/// This widget renders a list of data. The actual rendering is implemented
/// by an instance of the class IListProvider that must be supplied at
/// construction time.
public class ListView : Widget {
    private int top;
    private int selected;
    private bool allow_mark;
    private IListProvider provider;

    /// Public constructor.
    public this(int x, int y, int w, int h, IListProvider provider)
    {
        super(x, y, w, h);
        CanFocus = true;

        this.provider = provider;
        provider.SetListView(this);
        allow_mark = provider.AllowMark;
    }

    /// This method can be invoked by the model to notify the view that the
    /// contents of the model have changed.
    ///
    /// Invoke this method to invalidate the contents of the ListView and
    /// force the ListView to repaint the contents displayed.
    public void ProviderChanged()
    {
        if (top > provider.Items) {
            if (provider.Items > 1)
                top = provider.Items -1;
            else
                top = 0;
        }
        if (selected > provider.Items) {
            if (provider.Items > 1)
                selected = provider.Items - 1;
            else
                selected = 0;
        }
        Redraw();
    }

    private void SelectedChanged()
    {
        provider.SelectedChanged();
    }

    public override bool ProcessKey(wchar_t c)
    {
        int n;

        switch (c) {
        case Keys.CtrlP:
        case KEY_UP:
            if (selected > 0) {
                selected--;
                if (selected < top)
                    top = selected;
                SelectedChanged();
                Redraw();
                return true;
            } else
                return false;

        case Keys.CtrlN:
        case KEY_DOWN:
            if (selected + 1 < provider.Items) {
                selected++;
                if (selected >= top + height) {
                    top++;
                }
                SelectedChanged();
                Redraw();
                return true;
            } else
                return false;

        case Keys.CtrlV:
        case KEY_NPAGE:
            n = (selected + height);
            if (n > provider.Items)
                n = provider.Items - 1;
            if (n != selected) {
                selected = n;
                if (provider.Items >= height)
                    top = selected;
                else
                    top = 0;
                SelectedChanged();
                Redraw();
            }
            return true;

        case KEY_PPAGE:
            n = (selected - height);
            if (n < 0)
                n = 0;
            if (n != selected) {
                selected = n;
                top = selected;
                SelectedChanged();
                Redraw();
            }
            return true;

        default:
            return provider.ProcessKey(c);
        }
    }

    public override void PositionCursor()
    {
        Move(y + (selected - top), x);
    }

    public override void Redraw()
    {
        for (int l = 0; l < height; l++) {
            Move(y + l, x);
            int item = l + top;

            if (item >= provider.Items) {
                attrset(ColorNormal);
                for (int c = 0; c < width; c++)
                    addch(' ');
                continue;
            }

            bool marked = allow_mark ? provider.IsMarked(item) : false;

            if (item == selected) {
                if (marked)
                    attrset(ColorHotNormal);
                else
                    attrset(ColorFocus);
            } else {
                if (marked)
                    attrset(ColorHotFocus);
                else
                    attrset(ColorNormal);
            }

            provider.Render(y + l, x, width, item);
        }
        PositionCursor();
        refresh();
    }

    /// Gets / sets the index of the currently selected item.
    public @property int Selected()
    {
        if (provider.Items == 0)
            return -1;
        return selected;
    }

    /// ditto
    public @property int Selected(int value)
    {
        if (value >= provider.Items)
            throw new Exception("Invalid argument for value");

        selected = value;
        SelectedChanged();

        Redraw();

        return value;
    }

    public override void ProcessMouse(MEVENT* ev)
    {
        if (ev.bstate & BUTTON1_CLICKED || ev.bstate & BUTTON1_RELEASED)
            return;

        ev.x -= x;
        ev.y -= y;

        if (ev.y < 0)
            return;

        if (ev.y + top >= provider.Items)
            return;

        selected = ev.y - top;
        SelectedChanged();

        Redraw();
    }
}
