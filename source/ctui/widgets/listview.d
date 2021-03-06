//
// Simple curses-based GUI toolkit, listview widget
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
    @property size_t length();

    /// Whether the ListView should allow items to be marked.
    @property bool allowMark();

    /// Whether the given item is marked.
    bool isMarked(int item);

    /// This should render the item at the given line,
    /// col with the specified width.
    void render(int line, int col, int width, int item);

    /// Callback: this is the way that the model is
    /// hooked up to its actual view.
    void setListView(ListView target);

    /// Allows the model to process the given keystroke.
    ///
    /// The model should return true if the key was
    /// processed, false otherwise.
    bool processKey(wchar_t ch);

    /// Callback: invoked when the selected item has changed.
    void selectedChanged();
}

/// A Listview widget.
///
/// This widget renders a list of data. The actual rendering is implemented
/// by an instance of the class IListProvider that must be supplied at
/// construction time.
public class ListView : Widget {
    private int top;
    private int _selected;
    private IListProvider provider;

    /// Public constructor.
    public this(int x, int y, int w, int h, IListProvider provider)
    {
        super(x, y, w, h);
        canFocus = true;

        this.provider = provider;
        provider.setListView(this);
    }

    /// This method can be invoked by the model to notify the view that the
    /// contents of the model have changed.
    ///
    /// Invoke this method to invalidate the contents of the ListView and
    /// force the ListView to repaint the contents displayed.
    public void providerChanged()
    {
        if (top > provider.length) {
            if (provider.length > 1)
                top = cast(int)provider.length - 1;
            else
                top = 0;
        }
        if (selected > provider.length) {
            if (provider.length > 1)
                selected = cast(int)provider.length - 1;
            else
                selected = 0;
        }
        redraw();
    }

    private void selectedChanged()
    {
        provider.selectedChanged();
    }

    public override bool processKey(wchar_t c)
    {
        int n;

        switch (c) {
        case Keys.CtrlP:
        case KEY_UP:
            if (selected > 0) {
                _selected--;
                if (selected < top)
                    top = selected;
                selectedChanged();
                redraw();
                return true;
            } else
                return false;

        case Keys.CtrlN:
        case KEY_DOWN:
            if (selected + 1 < provider.length) {
                _selected++;
                if (selected >= top + height) {
                    top++;
                }
                selectedChanged();
                redraw();
                return true;
            } else
                return false;

        case Keys.CtrlV:
        case KEY_NPAGE:
            n = (selected + height);
            if (n > provider.length)
                n = cast(int)provider.length - 1;
            if (n != selected) {
                selected = n;
                if (provider.length >= height)
                    top = selected;
                else
                    top = 0;
                redraw();
            }
            return true;

        case KEY_PPAGE:
            n = (selected - height);
            if (n < 0)
                n = 0;
            if (n != selected) {
                selected = n;
                top = selected;
                redraw();
            }
            return true;

        default:
            return provider.processKey(c);
        }
    }

    public override void positionCursor()
    {
        this.move(y + (selected - top), x);
    }

    public override void redraw()
    {
        for (int l = 0; l < height; l++) {
            this.move(y + l, x);
            immutable item = l + top;

            if (item >= provider.length) {
                attrset(colorNormal);
                for (int c = 0; c < width; c++)
                    addch(' ');
                continue;
            }

            immutable bool marked = provider.allowMark ? provider.isMarked(item) : false;

            if (item == selected) {
                if (marked)
                    attrset(colorHotNormal);
                else
                    attrset(colorFocus);
            } else {
                if (marked)
                    attrset(colorHotFocus);
                else
                    attrset(colorNormal);
            }

            provider.render(y + l, x, width, item);
        }
        positionCursor();
        refresh();
    }

    /// Gets the index of the currently selected item.
    public @property int selected()
    {
        if (provider.length == 0)
            return -1;

        return _selected;
    }

    /// Sets the index of the currently selected item.
    public @property int selected(int value)
    {
        if (value >= provider.length)
            throw new Exception("Invalid argument for value");

        _selected = value;
        selectedChanged();

        redraw();

        return value;
    }

    public override void processMouse(MEVENT* ev)
    {
        if (ev.bstate & BUTTON1_CLICKED || ev.bstate & BUTTON1_RELEASED)
            return;

        ev.x -= x;
        ev.y -= y;

        if (ev.y < 0)
            return;

        if (ev.y + top >= provider.length)
            return;

        selected = ev.y - top;
        selectedChanged();

        redraw();
    }
}
