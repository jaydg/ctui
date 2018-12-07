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
    /// no fill
    None = 0,
    /// horizontal fill
    Horizontal = 1,
    /// vertical fill
    Vertical = 2
}

/// Base class for creating curses widgets
public abstract class Widget
{
    /// Points to the container of this widget
    public Container container;

    /// The x position of this widget
    public int x;

    /// The y position of this widget
    public int y;

    /// The width of this widget, it is the area that receives mouse events
    ///  and that must be repainted.
    public int width;

    /// The height of this widget, it is the area that receives mouse events
    /// and that must be repainted.
    public int height;

    package bool can_focus;
    package bool has_focus;

    /// Fill setting
    ///
    /// To fill both horizonally and vertically, combine the values:
    /// `Fill.Horizontal | Fill.Vertical`
    public Fill fill;

    /// Public constructor for widgets
    ///
    /// Constructs a widget that starts at position (x,y) and has width w and
    /// height h. These parameters are used by the methods clear and redraw.
    public this(int x, int y, int w, int h)
    {
        this.x = x;
        this.y = y;
        this.width = w;
        this.height = h;
        container = Application.EmptyContainer;
    }

    /// Focus status of this widget
    ///
    /// This is used typically by derived classes to flag whether this widget
    /// can receive focus or not. Focus is activated by either clicking with
    /// the mouse on that widget or by using the tab key.
    public @property bool canFocus()
    {
        return can_focus;
    }

    public @property bool canFocus(bool value)
    {
        return can_focus = value;
    }

    /// Gets or sets the current focus status.
    ///
    /// A widget can grab the focus by setting this value to true and
    /// the current focus status can be inquired by using this property.
    public @property bool hasFocus()
    {
        return has_focus;
    }

    /// ditto
    public @property bool hasFocus(bool value)
    {
        has_focus = value;
        redraw();

        return has_focus;
    }

    /// Moves inside the first location inside the container
    ///
    /// This moves the current cursor position to the specified line and col
    /// relative to the container client area where this widget is located.
    ///
    /// The difference between this method and baseMove is that this method
    /// goes to the beginning of the client area inside the container while
    /// baseMove goes to the first position that container uses.
    ///
    /// For example, a Frame usually takes up a couple of characters for
    /// padding. This method would position the cursor inside the client area,
    /// while baseMove would position  the cursor at the top of the frame.
    public void Move(int line, int col)
    {
        container.ContainerMove(line, col);
    }


    /// Move relative to the top of the container
    ///
    /// This moves the current cursor position to the specified line and col
    /// relative to the start of the container where this widget is located.
    ///
    /// The difference between this method and Move is that this method goes
    /// to the beginning of the container, while Move goes to the first
    /// position that widgets should use.
    ///
    /// For example, a Frame usually takes up a couple of characters for
    /// padding. This method would position the cursor at the beginning of the
    /// frame, while Move would position the cursor within the frame.
    public void baseMove(int line, int col)
    {
        container.containerBaseMove(line, col);
    }

    /// Clears the widget region withthe current color.
    ///
    /// This clears the entire region used by this widget.
    public void clear()
    {
        for (int line = 0; line < height; line++) {
            baseMove(y + line, x);
            for (int col = 0; col < width; col++) {
                addch(' ');
            }
        }
    }

    /// Redraws the current widget, must be overwritten.
    ///
    /// This method should be overwritten by classes that derive from Widget.
    /// The default implementation of this method just fills out the region
    /// with the character 'x'.
    ///
    /// Widgets are responsible for painting the entire region that they have
    /// been allocated.
    public void redraw()
    {
        for (int line; line < height; line++) {
            Move(y + line, x);
            for (int col; col < width; col++) {
                addch('x');
            }
        }
    }

    /// If the widget is focused, gives the widget a chance to process the
    /// keystroke.
    ///
    /// Widgets can override this method if they are interested in processing
    /// the given keystroke. If they consume the keystroke, they must return
    /// true to stop the keystroke from being processed by other widgets or
    /// consumed by the widget engine. If they return false, the keystroke will
    /// be passed out to other widgets for processing.
    public bool ProcessKey(wchar_t key)
    {
        return false;
    }

    /// Gives widgets a chance to process the given mouse event.
    ///
    /// Widgets can inspect the value of ev.ButtonState to determine if
    /// this is a message they are interested in (typically
    /// `ev.bstate & BUTTON1_CLICKED || ev.bstate & BUTTON1_RELEASED`).
    public void ProcessMouse(MEVENT* ev)
    {
    }

    /// This method can be overwritten by widgets that want to provide
    /// accelerator functionality (Alt-_key for example).
    ///
    /// Before keys are sent to the widgets on the current Container, all the
    /// widgets are processed and key is passed to the widgets to allow some
    /// of them to process the keystroke as a hot-_key.
    ///
    /// For example, if you implement a button that has a hotkey ok "o", you
    /// would catch the combination Alt-o here. If the event is caught, you
    /// must return true to stop the keystroke from being dispatched to other
    /// widgets.
    ///
    /// Typically to check if the keystroke is an Alt-_key combination, you
    /// would use `isAlt(key)` and then `std.uni.toUpper(key)` to compare
    /// with your hotkey.
    public bool ProcessHotKey(wchar_t key)
    {
        return false;
    }

    /// This method can be overwritten by widgets that want to provide
    /// accelerator functionality (Alt-_key for example), but without
    /// interfering with normal ProcessKey behavior.
    ///
    /// After keys are sent to the widgets on the current Container, all the
    /// widgets are processed and key is passed to the widgets to allow
    /// some of them to process the keystroke as a cold-_key.
    ///
    /// This functionality is used, for example, by default buttons to act on
    /// the enter _key. Processing this as a hot-_key would prevent non-default
    /// buttons from consuming the enter keypress when they have the focus.
    public bool ProcessColdKey(wchar_t key)
    {
        return false;
    }

    /// Moves inside the first location inside the container
    ///
    /// A helper routine that positions the cursor at the logical beginning of
    /// the widget. The default implementation merely puts the cursor at the
    /// beginning, but derived classes should find a suitable spot for the
    /// cursor to be shown.
    ///
    /// This method must be overwritten by most widgets since screen repaints
    /// can happen at any point and it is important to leave the cursor in a
    /// position that would make sense for the user (as not all terminals
    /// support hiding the cursor), and give the user an impression of where
    /// the cursor is. For a button, that would be the position where the
    /// hotkey is, for an entry the location of the editing cursor and so on.
    public void positionCursor()
    {
        Move(y, x);
    }

    /// Method to relayout on size changes.
    ///
    /// This method can be overwritten by widgets that might be interested in
    /// adjusting their contents or children (if they are containers).
    public void DoSizeChanged()
    {
    }

    /// Utility function to draw frames
    ///
    /// Draws a frame with the current color in the specified coordinates.
    static public void DrawFrame(int col, int line, int width, int height)
    {
        DrawFrame(col, line, width, height, false);
    }

    /// Utility function to draw strings that contain a hotkey
    ///
    /// Draws the string s with the given color. If the character "__" is
    /// found in s, the next character is drawn using hotcolor.
    static public void DrawHotString(string s, int hotcolor, int color)
    {
        int attr = color;

        foreach (dchar c; s) {
            if (c == '_') {
                attr = hotcolor;
                continue;
            }

            attron(attr);
            printw("%lc", c);
            attroff(attr = color);
        }
    }

    /// Utility function to draw frames
    ///
    /// Draws a frame with the current color in the specified coordinates.
    static public void DrawFrame(int col, int line, int width, int height, bool fill)
    {
        move(line, col);
        printw("┌");

        for (int b = 0; b < width - 2; b++)
            printw("─");

        printw("┐");

        for (int b = 1; b < height - 1; b++) {
            move(line+b, col);
            printw("│");
            if (fill) {
                for (int x = 1; x < width - 1; x++)
                    addch(' ');
            } else {
                move(line+b, col + width - 1);
            }
            printw("│");
        }

        move(line + height - 1, col);
        printw("└");

        for (int b = 0; b < width - 2; b++)
            printw("─");

        printw("┘");
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
