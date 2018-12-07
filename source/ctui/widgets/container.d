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

module ctui.widgets.container;

import core.stdc.stddef;
import std.algorithm : remove;
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
    Widget[] widgets;
    Widget focused = null;
    public bool running;

    public int ContainerColorNormal;
    public int ContainerColorFocus;
    public int ContainerColorHotNormal;
    public int ContainerColorHotFocus;

    public int Border;

    static this();

    public ref Widget opIndex(size_t index)
    {
        return widgets[index];
    }

    /// Public constructor.
    public this(int x, int y, int w, int h)
    {
        super(x, y, w, h);
        ContainerColorNormal = Application.ColorNormal;
        ContainerColorFocus = Application.ColorFocus;
        ContainerColorHotNormal = Application.ColorHotNormal;
        ContainerColorHotFocus = Application.ColorHotFocus;
    }

    /// Called on top-level container before starting up.
    public void Prepare ()
    {
    }

    /// Used to redraw all the children in this container.
    public void RedrawChildren()
    {
        foreach (w; widgets) {
            // Poor man's clipping.
            if (w.x >= this.width - Border * 2)
                continue;
            if (w.y >= this.height - Border * 2)
                continue;

            w.Redraw();
        }

        // Return the cursor to its expected position
        PositionCursor();
    }

    public override void Redraw()
    {
        RedrawChildren();
    }

    public override void PositionCursor()
    {
        if (focused !is null)
            focused.PositionCursor();
    }

    /// Focuses the specified widget in this container.
    ///
    /// Focuses the specified widge, taking the focus away from any previously
    /// focused widgets. This method only works if the widget specified
    /// supports being focused.
    public void setFocus(Widget w)
    {
        if (!w.canFocus)
            return;
        if (focused == w)
            return;
        if (focused !is null)
            focused.hasFocus = false;
        focused = w;
        focused.hasFocus = true;
        if (Container wc = cast(Container)w)
            wc.EnsureFocus();
        focused.PositionCursor();
    }

    /// Focuses the first possible focusable widget in the contained widgets.
    public void EnsureFocus()
    {
        if (focused is null)
            FocusFirst();
    }

    /// Focuses the first widget in the contained widgets.
    public void FocusFirst()
    {
        foreach (w; widgets) {
            if (w.canFocus) {
                setFocus(w);
                return;
            }
        }
    }

    /// Focuses the last widget in the contained widgets.
    public void FocusLast()
    {
        for (ulong i = widgets.length; i > 0; ) {
            i--;

            Widget w = widgets[i];
            if (w.canFocus) {
                setFocus(w);
                return;
            }
        }
    }

    /// Focuses the previous widget.
    public bool FocusPrev()
    {
        if (focused is null) {
            FocusLast();
            return true;
        }
        ulong focused_idx = -1;
        for (ulong i = widgets.length; i > 0; )
        {
            i--;
            Widget w = widgets[i];

            if (w.hasFocus) {
                if (Container c = cast(Container)w) {
                    if (c.FocusPrev())
                        return true;
                }
                focused_idx = i;
                continue;
            }
            if (w.canFocus && focused_idx != -1) {
                focused.hasFocus = false;

                Container c = cast(Container)w;
                if (c !is null && c.canFocus)
                {
                    c.FocusLast();
                }
                setFocus(w);
                return true;
            }
        }

        if (focused !is null) {
            focused.hasFocus = false;
            focused = null;
        }

        return false;
    }

    /// Focuses the next widget.
    public bool FocusNext()
    {
        if (focused is null) {
            FocusFirst();
            return focused !is null;
        }

        ulong n = widgets.length;
        int focused_idx = -1;
        for (int i = 0; i < n; i++) {
            Widget w = widgets[i];

            if (w.hasFocus) {
                Container c = cast(Container)w;
                if (c !is null) {
                    if (c.FocusNext())
                        return true;
                }
                focused_idx = i;
                continue;
            }
            if (w.canFocus && focused_idx != -1) {
                focused.hasFocus = false;

                Container c = cast(Container)w;
                if (c !is null && c.canFocus) {
                    c.FocusFirst();
                }
                setFocus (w);
                return true;
            }
        }
        if (focused !is null) {
            focused.hasFocus = false;
            focused = null;
        }
        return false;
    }

    /// Returns the base position for child widgets to paint on.
    ///
    /// This method is typically overwritten by containers that want to have
    /// some padding (like Frames or Dialogs).
    public void GetBase(out int row, out int col)
    {
        row = 0;
        col = 0;
    }

    public void ContainerMove(int row, int col)
    {
        if (container != Application.EmptyContainer && container !is null)
            container.ContainerMove(row + y, col + x);
        else
            move(row + y, col + x);
    }

    public void ContainerBaseMove(int row, int col)
    {
        if (container != Application.EmptyContainer && container !is null)
            container.ContainerBaseMove(row + y, col + x);
        else
            move(row + y, col + x);
    }

    /// Adds a widget to this container.
    public void Add(Widget w)
    {
        widgets ~= w;
        w.container = this;
        if (w.canFocus)
            this.canFocus = true;
    }

    /// Removes all the widgets from this container.
    public void RemoveAll()
    {
        Widget[] tmp;

        foreach (w; widgets)
            tmp ~= w;
        foreach (w; tmp)
            Remove(w);
    }

    /// Removes a widget from this container.
    public void Remove(Widget w)
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

    public override bool ProcessKey(wchar_t key)
    {
        if (focused !is null) {
            if (focused.ProcessKey(key))
                return true;
        }
        return false;
    }

    public override bool ProcessHotKey(wchar_t key)
    {
        if (focused !is null)
            if (focused.ProcessHotKey(key))
                return true;

        foreach (w; widgets) {
            if (w == focused)
                continue;

            if (w.ProcessHotKey(key))
                return true;
        }
        return false;
    }

    public override bool ProcessColdKey(wchar_t key)
    {
        if (focused !is null)
            if (focused.ProcessColdKey(key))
                return true;

        foreach (w; widgets) {
            if (w == focused)
                continue;

            if (w.ProcessColdKey(key))
                return true;
        }
        return false;
    }

    public override void ProcessMouse(MEVENT* ev)
    {
        int bx, by;

        GetBase(bx, by);
        ev.x -= x;
        ev.y -= y;

        // Iterate over the widgets backwards to ensure we
        // get widgets higher on the stack first.
        foreach (w; retro(widgets)) {
            int wx = w.x + bx;
            int wy = w.y + by;

            if ((ev.x < wx) || (ev.x > (wx + w.width - 1)))
                continue;

            if ((ev.y < wy) || (ev.y > (wy + w.height - 1)))
                continue;

            ev.x -= bx;
            ev.y -= by;

            w.ProcessMouse(ev);
            return;
        }
    }

    public override void DoSizeChanged()
    {
        foreach (widget; widgets) {
            widget.DoSizeChanged();

            if ((widget.fill & Fill.Horizontal) != 0) {
                widget.width = width - (Border * 2) - widget.x;
            }

            if ((widget.fill & Fill.Vertical) != 0)
                widget.height = height - (Border * 2) - widget.y;
        }
    }

    /// Raised when the size of this container changes.
    public void delegate() sizeChanged;

    /// This method is invoked when the size of this container changes.
    public void SizeChanged()
    {
        if (sizeChanged)
            sizeChanged();

        DoSizeChanged();
    }
}
