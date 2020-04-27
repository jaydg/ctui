//
// Simple curses-based GUI toolkit, container widget
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

module ctui.widgets.container;

import core.stdc.stddef;
import std.algorithm : remove;
import std.algorithm.iteration : filter;
import std.range : retro;
import deimos.ncurses;

import ctui.application;
import ctui.widgets.widget;

/// Container widget, can host other widgets.
///
/// This implements the foundation for other containers (like Dialogs and
/// Frames) that can host other widgets inside their boundaries. It provides
/// focus handling and event routing.
public class Container : Widget
{
    private Widget[] widgets;

    ///
    public bool running;

    ///
    public int containerColorNormal;

    ///
    public int containerColorFocus;

    ///
    public int containerColorHotNormal;

    ///
    public int containerColorHotFocus;

    ///
    public int border;

    /// Array Indexing: access the container's children by index
    public ref Widget opIndex(size_t index)
    {
        return widgets[index];
    }

    /// Public constructor.
    public this(int x, int y, int w, int h)
    {
        super(x, y, w, h);
        containerColorNormal = Application.colorNormal;
        containerColorFocus = Application.colorFocus;
        containerColorHotNormal = Application.colorHotNormal;
        containerColorHotFocus = Application.colorHotFocus;
    }

    /// Called on top-level container before starting up.
    public void prepare()
    {
    }

    /// Used to redraw all the children in this container.
    public void redrawChildren()
    {
        foreach (w; widgets) {
            // Poor man's clipping.
            if (w.x >= this.width - border * 2)
                continue;
            if (w.y >= this.height - border * 2)
                continue;

            w.redraw();
        }

        // Return the cursor to its expected position
        positionCursor();
    }

    public override void redraw()
    {
        redrawChildren();
    }

    public override void positionCursor()
    {
        if (focused !is null)
            focused.positionCursor();
    }

    private Widget _focused = null;

    /// Get the currently focused widget
    public @property Widget focused()
    {
        return _focused;
    }

    /// Focuses the specified widget in this container.
    ///
    /// Focuses the specified widge, taking the focus away from any previously
    /// focused widgets. This method only works if the widget specified
    /// supports being focused.
    public @property void focused(Widget w)
    {
        if (w !is null && !w.canFocus)
            return;

        if (focused == w)
            return;

        if (focused !is null)
            focused.hasFocus = false;

        _focused = w;

        if (focused is null)
            return;

        focused.hasFocus = true;

        if (Container c = cast(Container)w) {
            c.ensureFocus();
        }

        focused.positionCursor();
    }

    /// Focuses the first possible focusable widget in the contained widgets.
    public void ensureFocus()
    {
        if (focused is null)
            focusFirst();
    }

    /// Focuses the first widget in the contained widgets.
    public void focusFirst()
    {
        foreach (w; widgets.filter!(w => w.canFocus)) {
            focused = w;
            return;
        }
    }

    /// Focuses the last widget in the contained widgets.
    public void focusLast()
    {
        foreach (w; retro(widgets).filter!(w => w.canFocus)) {
            focused = w;
            return;
        }
    }

    /// Focuses the previous widget.
    public bool focusPrev()
    {
        if (focused is null) {
            focusLast();
            return true;
        }

        if (Container c = cast(Container)focused) {
            if (c.focusPrev())
                return true;
        }

        bool found_current;
        foreach (w; retro(widgets).filter!(w => w.canFocus))
        {
            if (w.hasFocus) {
                found_current = true;
                continue;
            }

            if (found_current) {
                focused = w;

                if (Container c = cast(Container)w) {
                    c.focusLast();
                }

                return true;
            }
        }

        if (focused !is null) {
            focused = null;
        }

        return false;
    }

    /// Focuses the next widget.
    public bool focusNext()
    {
        if (focused is null) {
            focusFirst();
            return focused !is null;
        }

        if (Container c = cast(Container)focused) {
            if (c.focusNext())
                return true;
        }

        bool found_current;
        foreach (w; widgets.filter!(w => w.canFocus)) {
            if (w.hasFocus) {
                found_current = true;
                continue;
            }

            if (found_current) {
                focused = w;

                if (Container c = cast(Container)w) {
                    c.focusFirst();
                }

                return true;
            }
        }

        if (focused !is null) {
            focused = null;
        }

        return false;
    }

    /// Returns the base position for child widgets to paint on.
    ///
    /// This method is typically overwritten by containers that want to have
    /// some padding (like Frames or Dialogs).
    public void getBase(out int row, out int col)
    {
        row = 0;
        col = 0;
    }

    ///
    public void containerMove(int row, int col)
    {
        if (container != Application.emptyContainer && container !is null)
            container.containerMove(row + y, col + x);
        else
            deimos.ncurses.move(row + y, col + x);
    }

    ///
    public void containerBaseMove(int row, int col)
    {
        if (container != Application.emptyContainer && container !is null)
            container.containerBaseMove(row + y, col + x);
        else
            deimos.ncurses.move(row + y, col + x);
    }

    /// Adds a widget to this container.
    public void add(Widget w)
    {
        widgets ~= w;
        w.container = this;
        if (w.canFocus)
            this.canFocus = true;
    }

    /// Removes all the widgets from this container.
    public void removeAll()
    {
        Widget[] tmp = widgets.dup;

        foreach (w; tmp)
            remove(w);
    }

    /// Removes a widget from this container.
    public void remove(Widget w)
    {
        if (w is null)
            return;

        if (focused == w)
            focused = null;

        widgets = widgets.remove!(widget => widget == w);
        w.container = null;

        if (widgets.length < 1)
            this.canFocus = false;
    }

    public override bool processKey(wchar_t key)
    {
        if (focused !is null) {
            if (focused.processKey(key))
                return true;
        }

        return false;
    }

    public override bool processHotKey(wchar_t key)
    {
        if (focused !is null)
            if (focused.processHotKey(key))
                return true;

        foreach (w; widgets) {
            if (w == focused)
                continue;

            if (w.processHotKey(key))
                return true;
        }

        return false;
    }

    public override bool processColdKey(wchar_t key)
    {
        if (focused !is null)
            if (focused.processColdKey(key))
                return true;

        foreach (w; widgets) {
            if (w == focused)
                continue;

            if (w.processColdKey(key))
                return true;
        }

        return false;
    }

    public override void processMouse(MEVENT* ev)
    {
        int bx, by;

        getBase(bx, by);
        ev.x -= x;
        ev.y -= y;

        // Iterate over the widgets backwards to ensure we
        // get widgets higher on the stack first.
        foreach (w; retro(widgets)) {
            immutable wx = w.x + bx;
            immutable wy = w.y + by;

            if ((ev.x < wx) || (ev.x > (wx + w.width - 1)))
                continue;

            if ((ev.y < wy) || (ev.y > (wy + w.height - 1)))
                continue;

            ev.x -= bx;
            ev.y -= by;

            w.processMouse(ev);
            return;
        }
    }

    public override void doSizeChanged()
    {
        foreach (widget; widgets) {
            widget.doSizeChanged();

            if ((widget.fill & Fill.Horizontal) != 0) {
                widget.width = width - (border * 2) - widget.x;
            }

            if ((widget.fill & Fill.Vertical) != 0)
                widget.height = height - (border * 2) - widget.y;
        }
    }

    private void delegate() _sizeChanged;

    /// This method is invoked when the size of this container changes.
    public void sizeChanged()
    {
        if (_sizeChanged)
            _sizeChanged();

        doSizeChanged();
    }

    /// Raised when the size of this container changes.
    public void sizeChanged(void delegate() action)
    {
        _sizeChanged = action;
    }
}
