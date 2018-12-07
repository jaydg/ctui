//
// Simple curses-based GUI toolkit: radio group widget
//
// Copyright 2017 Microsoft Corp
// Copyright 2018 Joachim de Groot
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

module ctui.widgets.radiogroup;

import core.stdc.stddef;
import std.algorithm : max;
import std.uni : isAlphaNum, toUpper;
import std.utf : count;
import deimos.ncurses;

import ctui.widgets.widget;

/// Radio group shows a group of labels, only one of those can be selected at a given time
public class RadioGroup : Widget {
    private int _selected, cursor;

    /// Initializes a new instance of the RadioGroup class, setting up the
    /// initial set of radio labels and the item that should be selected and
    /// uses an absolute layout for the result.
    ///
    /// Params:
    ///     x           = x position of the widget
    ///     y           = y position of the widget
    ///     radioLabels = radio labels. The strings can contain hotkeys using
    ///                   an undermine ("__") before the desired hotkey.
    ///     selected    = The item to be selected, the value is clamped to the
    ///                   number of items.
    public this(int x, int y, string[] radioLabels, int selected = 0)
    {
        int maxW;
        foreach (label; radioLabels) {
            maxW = max(maxW, cast(int)label.count);
        }

        super(x, y, 4 + maxW, cast(int)radioLabels.length);

        this.selected = selected;
        this.radioLabels = radioLabels;
        canFocus = true;
    }

    private string[] _radioLabels;

    @property {
        public override bool hasFocus(bool value)
        {
            curs_set(value);
            return super.hasFocus(value);
        }

        /// Get the radio labels
        public string[] radioLabels() {
            return _radioLabels;
        }

        /// Set the radio labels
        public void radioLabels(string[] labels) {
            _radioLabels = labels;
            selected = 0;
            cursor = 0;
            redraw();
        }

        /// Get the index of currently selected item
        public int selected() {
            return _selected;
        }

        /// Set the currently selected item
        public void selected(int idx) {
            _selected = idx;
            if (changed)
                changed(idx);

            redraw();
            refresh();
        }
    }

    public override void redraw()
    {
        foreach (int i, label; radioLabels) {
            Move(y + i, x);
            attron(container.ContainerColorNormal);
            printw(i == selected ? "(o) " : "( ) ");

            int hotColor, normalColor;
            if (i == selected) {
                hotColor = container.ContainerColorHotFocus;
                normalColor = container.ContainerColorFocus;
            } else {
                hotColor = container.ContainerColorHotNormal;
                normalColor = container.ContainerColorNormal;
            }

            DrawHotString(label, hotColor, normalColor);
        }

        positionCursor();
    }

    public override void positionCursor()
    {
        Move(y + cursor, x + 1);
    }

    /// Changed event, raised when the selected item is changed.
    public void delegate(int selection) changed;

    public override bool ProcessColdKey(wchar_t key)
    {
        if (key.isAlphaNum()) {
            key = key.toUpper();
            foreach (int i, label; radioLabels) {
                bool nextIsHot;
                foreach (dchar c; label) {
                    if (c == '_')
                        nextIsHot = true;
                    else {
                        if (nextIsHot && c == key) {
                            selected = i;
                            cursor = i;
                            if (!super.hasFocus()) {
                                container.setFocus(this);
                            }

                            return true;
                        }
                        nextIsHot = false;
                    }
                } // foreach c
            } // foreach label
        }

        return false;
    }

    public override bool ProcessKey(wchar_t key)
    {
        switch (key) {
            case KEY_UP:
                if (cursor > 0) {
                    cursor--;
                    redraw();
                    refresh();
                    return true;
                }
                break;
            case KEY_DOWN:
                if (cursor + 1 < radioLabels.length) {
                    cursor++;
                    redraw();
                    refresh();
                    return true;
                }
                break;
            case ' ':
                selected = cursor;
                return true;
            default:
                break;
        }

        return false;
    }

    public override void ProcessMouse(MEVENT *ev)
    {
        if (!(ev.bstate & BUTTON1_CLICKED || ev.bstate & BUTTON1_RELEASED)) {
            return;
        }

        container.setFocus(this);

        ev.y -= y;

        if (ev.y < radioLabels.length) {
            cursor = _selected = ev.y;
            redraw();
            refresh();
        }
    }
}
