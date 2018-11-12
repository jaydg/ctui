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

module ctui.widgets.widget;

import core.stdc.stddef;
import deimos.ncurses;

import ctui.application;
import ctui.widgets.container;

/// The fill values apply from the given x, y values, they will not do
/// a full fill, you must compute x, y yourself.
public enum Fill {
    None = 0,
    Horizontal = 1,
    Vertical = 2
}

///   Base class for creating curses widgets
public abstract class Widget
{
    /// Points to the container of this widget
    public Container container;

    /// The x position of this widget
    public int x;

    /// The y position of this widget
    public int y;

    /// The width of this widget, it is the area that receives mouse events and that must be repainted.
    public int w;

    /// The height of this widget, it is the area that receives mouse events and that must be repainted.
    public int h;

    bool can_focus;
    bool has_focus;
    public Fill fill;

    /// Public constructor for widgets
    ///
    /// Constructs a widget that starts at position (x,y) and has width w and height h.
    /// These parameters are used by the methods <see cref="Clear"/> and <see cref="Redraw"/>
    public this(int x, int y, int w, int h)
    {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
        container = Application.EmptyContainer;
    }

    /// Focus status of this widget
    ///
    /// This is used typically by derived classes to flag whether
    /// this widget can receive focus or not.    Focus is activated
    /// by either clicking with the mouse on that widget or by using
    /// the tab key.
    public @property bool CanFocus()
    {
        return can_focus;
    }

    public @property bool CanFocus(bool value)
    {
        return can_focus = value;
    }

    /// Gets or sets the current focus status.
    ///
    /// A widget can grab the focus by setting this value to true and
    /// the current focus status can be inquired by using this property.
    public @property bool HasFocus()
    {
        return has_focus;
    }

    public @property bool HasFocus(bool value)
    {
        has_focus = value;
        Redraw();

        return has_focus;
    }

    /// Moves inside the first location inside the container
    ///
    /// This moves the current cursor position to the specified
    /// line and column relative to the container
    /// client area where this widget is located.
    ///
    /// The difference between this
    /// method and <see cref="BaseMove"/> is that this
    /// method goes to the beginning of the client area
    /// inside the container while <see cref="BaseMove"/> goes to the first
    /// position that container uses.
    ///
    /// For example, a Frame usually takes up a couple
    /// of characters for padding.   This method would
    /// position the cursor inside the client area,
    /// while <see cref="BaseMove"/> would position
    /// the cursor at the top of the frame.
    public void Move(int line, int col)
    {
        container.ContainerMove(line, col);
    }


    /// Move relative to the top of the container
    ///
    /// This moves the current cursor position to the specified
    /// line and column relative to the start of the container
    /// where this widget is located.
    ///
    /// The difference between this
    /// method and <see cref="Move"/> is that this
    /// method goes to the beginning of the container,
    /// while <see cref="Move"/> goes to the first
    /// position that widgets should use.
    ///
    /// For example, a Frame usually takes up a couple
    /// of characters for padding.   This method would
    /// position the cursor at the beginning of the
    /// frame, while <see cref="Move"/> would position
    /// the cursor within the frame.
    public void BaseMove(int line, int col)
    {
        container.ContainerBaseMove(line, col);
    }

    /// Clears the widget region withthe current color.
    ///
    /// This clears the entire region used by this widget.
    public void Clear()
    {
        for (int line = 0; line < h; line++) {
            BaseMove(y + line, x);
            for (int col = 0; col < w; col++) {
                addch(' ');
            }
        }
    }

    /// Redraws the current widget, must be overwritten.
    ///
    /// This method should be overwritten by classes
    /// that derive from Widget.   The default
    /// implementation of this method just fills out
    /// the region with the character 'x'.
    ///
    /// Widgets are responsible for painting the
    /// entire region that they have been allocated.
    public void Redraw()
    {
        for (int line = 0; line < h; line++) {
            Move(y + line, x);
            for (int col = 0; col < w; col++) {
                addch('x');
            }
        }
    }

    /// If the widget is focused, gives the widget a
    /// chance to process the keystroke.
    ///
    /// Widgets can override this method if they are
    /// interested in processing the given keystroke.
    /// If they consume the keystroke, they must
    /// return true to stop the keystroke from being
    /// processed by other widgets or consumed by the
    /// widget engine.    If they return false, the
    /// keystroke will be passed out to other widgets
    /// for processing.
    public bool ProcessKey(wchar_t key)
    {
        return false;
    }

    /// Gives widgets a chance to process the given mouse event.
    ///
    /// Widgets can inspect the value of
    /// ev.ButtonState to determine if this is a
    /// message they are interested in (typically
    /// ev.bstate &amp; BUTTON1_CLICKED).
    public void ProcessMouse(MEVENT* ev)
    {
    }

    /// This method can be overwritten by widgets that
    /// want to provide accelerator functionality
    /// (Alt-key for example).
    ///
    /// Before keys are sent to the widgets on the
    /// current Container, all the widgets are
    /// processed and the key is passed to the widgets
    /// to allow some of them to process the keystroke
    /// as a hot-key.
    ///
    /// For example, if you implement a button that
    /// has a hotkey ok "o", you would catch the
    /// combination Alt-o here.  If the event is
    /// caught, you must return true to stop the
    /// keystroke from being dispatched to other
    /// widgets.
    ///
    /// Typically to check if the keystroke is an
    /// Alt-key combination, you would use
    /// isAlt(key) and then Char.ToUpper(key)
    /// to compare with your hotkey.
    public bool ProcessHotKey(wchar_t key)
    {
        return false;
    }

    /// This method can be overwritten by widgets that
    /// want to provide accelerator functionality
    /// (Alt-key for example), but without
    /// interefering with normal ProcessKey behavior.
    ///
    /// After keys are sent to the widgets on the
    /// current Container, all the widgets are
    /// processed and the key is passed to the widgets
    /// to allow some of them to process the keystroke
    /// as a cold-key.
    ///
    /// This functionality is used, for example, by
    /// default buttons to act on the enter key.
    /// Processing this as a hot-key would prevent
    /// non-default buttons from consuming the enter
    /// keypress when they have the focus.
    public bool ProcessColdKey(wchar_t key)
    {
        return false;
    }

    /// Moves inside the first location inside the container
    ///
    /// A helper routine that positions the cursor at
    /// the logical beginning of the widget.   The
    /// default implementation merely puts the cursor at
    /// the beginning, but derived classes should find a
    /// suitable spot for the cursor to be shown.
    ///
    /// This method must be overwritten by most
    /// widgets since screen repaints can happen at
    /// any point and it is important to leave the
    /// cursor in a position that would make sense for
    /// the user (as not all terminals support hiding
    /// the cursor), and give the user an impression of
    /// where the cursor is.   For a button, that
    /// would be the position where the hotkey is, for
    /// an entry the location of the editing cursor
    /// and so on.
    public void PositionCursor()
    {
        Move(y, x);
    }

    /// Method to relayout on size changes.
    ///
    /// This method can be overwritten by widgets that
    /// might be interested in adjusting their
    /// contents or children (if they are
    /// containers).
    public void DoSizeChanged()
    {
    }

    /// Utility function to draw frames
    ///
    /// Draws a frame with the current color in the
    /// specified coordinates.
    static public void DrawFrame(int col, int line, int width, int height)
    {
        DrawFrame(col, line, width, height, false);
    }

    /// Utility function to draw strings that contain a hotkey
    ///
    /// Draws a string with the given color. If a character "_" is
    /// found, then the next character is drawn using the hotcolor.
    static public void DrawHotString(string s, int hotcolor, int color)
    {
        attrset(color);
        foreach (char c;  s) {
            if (c == '_') {
                attrset(hotcolor);
                continue;
            }
            addch(c);
            attrset(color);
        }
    }

    /// Utility function to draw frames
    ///
    /// Draws a frame with the current color in the specified coordinates.
    static public void DrawFrame(int col, int line, int width, int height, bool fill)
    {
        int b;
        move(line, col);
        addch(ACS_ULCORNER);
        for (b = 0; b < width - 2; b++)
            addch(ACS_HLINE);
        addch(ACS_URCORNER);

        for (b = 1; b < height - 1; b++) {
            move(line+b, col);
            addch(ACS_VLINE);
            if (fill) {
                for (int x = 1; x < width - 1; x++)
                    addch(' ');
            } else {
                move(line+b, col + width - 1);
            }
            addch(ACS_VLINE);
        }

        move(line + height - 1, col);
        addch(ACS_LLCORNER);
        for (b = 0; b < width - 2; b++)
            addch(ACS_HLINE);
        addch(ACS_LRCORNER);
    }

    /// The color used for rendering an unfocused widget.
    public @property int ColorNormal()
    {
        return container.ContainerColorNormal;
    }

    /// The color used for rendering a focused widget.
    public @property int ColorFocus()
    {
        return container.ContainerColorFocus;
    }

    /// The color used for rendering the hotkey on an unfocused widget.
    public @property int ColorHotNormal()
    {
        return container.ContainerColorHotNormal;
    }

    /// The color used to render a hotkey in a focused widget.
    public @property int ColorHotFocus()
    {
        return container.ContainerColorHotFocus;
    }
}
