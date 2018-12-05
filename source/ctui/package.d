//
// Simple curses-based GUI toolkit
//
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

module ctui;

public {
    import ctui.application;
    import ctui.mainloop;
    import ctui.keys;

    import ctui.widgets.button;
    import ctui.widgets.checkbox;
    import ctui.widgets.container;
    import ctui.widgets.dialog;
    import ctui.widgets.entry;
    import ctui.widgets.frame;
    import ctui.widgets.label;
    import ctui.widgets.listview;
    import ctui.widgets.menubar;
    import ctui.widgets.messagebox;
    import ctui.widgets.progressbar;
    import ctui.widgets.radiogroup;
    import ctui.widgets.trimlabel;
    import ctui.widgets.widget;

    import deimos.ncurses;
}
