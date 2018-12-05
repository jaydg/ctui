//
// Simple curses-based GUI toolkit: progress bar
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

module ctui.widgets.progressbar;

import std.conv : to;
import deimos.ncurses;

import ctui.widgets.widget;

/// Progress bar can indicate progress of an activity visually.
///
/// The progressbar can operate in two modes, percentage mode, or activity
/// mode. The progress bar starts in percentage mode and setting the fraction
/// property will reflect on the UI the progress  made so far. Activity mode
/// is used when the application has no  way of knowing how much time is left,
/// and is started when you invoke the pulse() method. You should call the
/// pulse method repeatedly as your application makes progress.
public class ProgressBar : Widget {
    private bool isActivity;
    private int activityPos, delta;

    /// Initializes a new instance of the ProgressBar class, starts in
    /// percentage mode.
    public this(int x, int y, int w)
    {
        super(x, y, w, 1);
        CanFocus = false;
        fraction = 0;
    }

    private float _fraction;

    @property {
        /// Gets or sets the progress indicator fraction to display, must be a
        /// value between 0 and 1.
        public float fraction() {
            return _fraction;
        }

        /// ditto
        public void fraction(float value) {
            _fraction = value;
            isActivity = false;
            Redraw();
        }
    }

    /// Notifies the progress bar that some progress has taken place.
    ///
    /// If the ProgressBar is is percentage mode, it switches to activity
    /// mode. If is in activity mode, the marker is moved.
    public void pulse()
    {
        if (!isActivity) {
            isActivity = true;
            activityPos = 0;
            delta = 1;
        } else {
            activityPos += delta;

            if (activityPos < 0) {
                activityPos = 1;
                delta = 1;
            } else if (activityPos >= w) {
                activityPos = w - 2;
                delta = -1;
            }
        }

        Redraw();
    }

    public override void Redraw()
    {
        attrset(container.ContainerColorHotFocus);

        Move (y, x);

        if (isActivity) {
            foreach (i; 0 .. w)
                if (i == activityPos) {
                    printw("▒");
                } else {
                    addch(' ');
                }
        } else {
            immutable mid = to!int(fraction * w);

            int i;
            for (; i < mid; i++) {
                    printw("▒");
            }
            for (; i < w; i++) {
                addch(' ');
            }
        }

    }
}
