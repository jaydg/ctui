//
// Simple curses-based GUI toolkit, application driver
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

module ctui.application;

import core.stdc.locale;
import core.sys.posix.signal;

import std.algorithm : map, max, remove;
import std.algorithm.searching : maxElement;
import std.encoding : index;
import std.string : splitLines;
import std.utf : count;
import deimos.ncurses;

import ctui.keys;
import ctui.mainloop;
import ctui.utils;
import ctui.widgets.button;
import ctui.widgets.container;
import ctui.widgets.dialog;
import ctui.widgets.label;

/// ctui Application driver.
///
/// Before using ctui, you must call Application.init, then you would create
/// your toplevel container (typically by calling:
/// `new Container(0, 0, Application.cols, Application.lines)`, adding widgets
/// to it and finally calling `Application.run()` on the toplevel container).
public class Application {
    /// Color used for unfocused widgets.
    public static int colorNormal;

    /// Color used for focused widgets.
    public static int colorFocus;

    /// Color used for hotkeys in unfocused widgets.
    public static int colorHotNormal;

    /// Color used for hotkeys in focused widgets.
    public static int colorHotFocus;

    /// Color used for marked entries.
    public static int colorMarked;

    /// Color used for marked entries that are currently
    /// selected with the cursor.
    public static int colorMarkedSelected;

    /// Color for unfocused widgets on a dialog.
    public static int colorDialogNormal;

    /// Color for focused widgets on a dialog.
    public static int colorDialogFocus;

    /// Color for hotkeys in an unfocused widget on a dialog.
    public static int colorDialogHotNormal;

    /// Color for a hotkey in a focused widget on a dialog.
    public static int colorDialogHotFocus;

    /// Color used for error text.
    public static int colorError;

    /// Color used for focused widgets on an error dialog.
    public static int colorErrorFocus;

    /// Color used for hotkeys in error dialogs
    public static int colorErrorHot;

    /// Color used for hotkeys in a focused widget in an error dialog
    public static int colorErrorHotFocus;

    /// The basic color of the terminal.
    public static int colorBasic;

    /// The regular color for a selected item on a menu
    public static int colorMenuSelected;

    /// The hot color for a selected item on a menu
    public static int colorMenuHotSelected;

    /// The regular color for a menu entry
    public static int colorMenu;

    /// The hot color for a menu entry
    public static int colorMenuHot;

    /// This delegate is called on each iteration of the main loop.
    ///
    /// See also Timeout
    public static void delegate() iteration;

    // Private variables
    private static Container[] toplevels;
    private static short last_color_pair;
    private static bool inited;
    private static Container empty_container;

    /// Creates a new Curses color to be used by Gui.cs apps
    public static int makeColor(short f, short b)
    {
        init_pair(++last_color_pair, f, b);
        return cast(int)COLOR_PAIR(last_color_pair);
    }

    /// The singleton emptyContainer that covers the entire screen.
    static public @property Container emptyContainer()
    {
        return empty_container;
    }

    private static WINDOW* main_window;
    private static bool using_color;
    private static int _cols, _lines;

    /// The applications MainLoop.
    static MainLoop mainLoop;

    /// Determine of the application is using colors.
    ///
    /// During the initialisation of the terminal, this is set according to the
    /// capabilities of the terminal.
    public static @property bool usingColor()
    {
        return using_color;
    }

    /// Initializes the runtime.
    public static void init()
    {
        if (inited)
            return;
        inited = true;

        empty_container = new Container(0, 0, Application.cols, Application.lines);

        // Install SIGWINCH handler
        sigaction_t action = {
            sa_sigaction: &sigHandler,
            sa_flags: SA_SIGINFO
        };
        // FIXME: SIGWINCH is currently not defined anywhere
        sigaction(28, &action, null);

        // Use user's locale
        setlocale(LC_ALL, "");

        main_window = initscr();
        if (main_window is null) {
            import std.stdio : writeln;
            writeln("Curses failed to initialize.");
            throw new Exception("Application.init failed");
        }

        // get initial column and line count from curses
        _cols = COLS;
        _lines = LINES;

        raw();
        noecho();
        curs_set(0);
        set_escdelay(0);
        main_window.keypad(true);
        mousemask(ALL_MOUSE_EVENTS, null);

        using_color = has_colors();
        start_color();
        use_default_colors();

        if (usingColor)
        {
            colorNormal = makeColor(COLOR_WHITE, COLOR_BLUE);
            colorFocus = makeColor(COLOR_BLACK, COLOR_CYAN);
            colorHotNormal = A_BOLD | makeColor(COLOR_YELLOW, COLOR_BLUE);
            colorHotFocus = A_BOLD | makeColor(COLOR_YELLOW, COLOR_CYAN);

            colorMenu = A_BOLD | makeColor(COLOR_WHITE, COLOR_CYAN);
            colorMenuHot = A_BOLD | makeColor(COLOR_YELLOW, COLOR_CYAN);
            colorMenuSelected = A_BOLD | makeColor(COLOR_WHITE, COLOR_BLACK);
            colorMenuHotSelected = A_BOLD | makeColor(COLOR_YELLOW, COLOR_BLACK);

            colorMarked = colorHotNormal;
            colorMarkedSelected = colorHotFocus;

            colorDialogNormal    = makeColor(COLOR_BLACK, COLOR_WHITE);
            colorDialogFocus     = makeColor(COLOR_BLACK, COLOR_CYAN);
            colorDialogHotNormal = makeColor(COLOR_BLUE,  COLOR_WHITE);
            colorDialogHotFocus  = makeColor(COLOR_BLUE,  COLOR_CYAN);

            colorError = A_BOLD | makeColor(COLOR_WHITE, COLOR_RED);
            colorErrorFocus = makeColor(COLOR_BLACK, COLOR_WHITE);
            colorErrorHot = A_BOLD | makeColor(COLOR_YELLOW, COLOR_RED);
            colorErrorHotFocus = colorErrorHot;
        } else {
            colorNormal = A_NORMAL;
            colorFocus = A_REVERSE;
            colorHotNormal = A_BOLD;
            colorHotFocus = A_REVERSE | A_BOLD;

            colorMenu = A_REVERSE;
            colorMenuHot = A_NORMAL;
            colorMenuSelected = A_BOLD;
            colorMenuHotSelected = A_NORMAL;

            colorMarked = A_BOLD;
            colorMarkedSelected = A_REVERSE | A_BOLD;

            colorDialogNormal = A_REVERSE;
            colorDialogFocus = A_NORMAL;
            colorDialogHotNormal = A_BOLD;
            colorDialogHotFocus = A_NORMAL;

            colorError = A_BOLD;
        }

        colorBasic = makeColor(-1, -1);

        mainLoop = new MainLoop();
        mainLoop.addWatch(0, MainLoop.Condition.PollIn, {
            Container top = toplevels.length > 0
                ? toplevels[cast(int)toplevels.length - 1]
                : null;
            if (top !is null)
                processChar(top);

            return true;
        });
    }

    /// The number of lines on the screen
    static public @property int lines()
    {
        return _lines;
    }

    /// The number of columns on the screen
    static public @property int cols()
    {
        return _cols;
    }

    /// Displays a message on a modal dialog box.
    ///
    /// The error boolean indicates whether this is an error message box or
    /// not.
    static public void msg(bool error, string caption, string t)
    {
        string[] text = splitLines(t);
        size_t max_w = text.map!(s => s.count).maxElement;

        Dialog d = new Dialog(cast(int)max(caption.count + 8, max_w + 8), cast(int)text.length + 7, caption);

        if (error) {
            d.errorColors();
        }

        foreach (int i, line; text) {
            d.add(new Label(1, i + 1, line));
        }

        Button b = new Button(0, 0, "Ok", true);
        d.addButton(b);
        b.clicked = { b.container.running = false; };

        Application.run(d);
    }

    /// Displays an error message.
    static public void error(string caption, string text)
    {
        msg(true, caption, text);
    }

    /// Displays an error message.
    ///
    /// Overload that allows for `std.format` parameters.
    static public void error(string caption, string format, A...)(A args)
    {
        string t = format(format, args);

        msg(true, caption, t);
    }

    /// Displays an informational message.
    static public void info(string caption, string text)
    {
        msg(false, caption, text);
    }

    /// Displays an informational message.
    ///
    /// Overload that allows for `std.format` parameters.
    static public void info(string caption, string format, A...)(A args)
    {
        string t = format(format, args);

        Msg(false, caption, t);
    }

    private static void shutdown()
    {
        endwin();
    }

    private static void redraw(Container container)
    {
        container.redraw();
        deimos.ncurses.refresh();
    }

    /// Forces a repaint of the screen.
    public static void refresh()
    {
        Container last = null;

        redrawwin(main_window);
        foreach (c; toplevels)
        {
            c.redraw();
            last = c;
        }

        deimos.ncurses.refresh();
        if (last !is null)
            last.positionCursor();
    }

    /// Starts running a new container or dialog box.
    ///
    /// Use this method if you want to start the dialog, but you want to
    /// control the main loop execution manually by calling the runLoop method
    /// (for example, to start the dialog, but continuing to process events).
    ///
    /// Use the returned value as the argument to runLoop and later to the end
    /// method to remove the container from the screen.
    static public RunState begin(Container container)
    {
        if (container is null)
            throw new Exception("container cannot be null");

        RunState rs = new RunState(container);

        init();

        timeout(-1);

        toplevels ~= container;

        container.prepare();
        container.sizeChanged();
        container.focusFirst();
        redraw(container);
        container.positionCursor();
        Application.refresh();

        return rs;
    }

    /// Runs the main loop for the created dialog
    ///
    /// Calling this method will block until the dialog has completed execution.
    public static void runLoop(RunState state)
    {
        runLoop(state, true);
    }

    /// Runs the main loop for the created dialog
    ///
    /// Use the wait parameter to control whether this is a blocking or
    /// non-blocking call.
    public static void runLoop(RunState state, bool wait)
    {
        if (state is null)
            throw new Exception("state cannot be null");
        if (state.container is null)
            throw new Exception("Object is disposed");

        for (state.container.running = true; state.container.running;) {
            if (mainLoop.eventsPending(wait)) {
                mainLoop.mainIteration();
                // per-iteration callback
                if (iteration)
                    iteration();
            } else if (wait == false)
                return;
        }
    }

    /// stop the main loop.
    public static void stop()
    {
        if (toplevels.length == 0)
            return;

        toplevels[cast(int)toplevels.length - 1].running = false;
        mainLoop.stop();
    }

    /// Runs the main loop on the given container.
    ///
    /// This method is used to start processing events for the main
    /// application, but it is also used to run modal dialog boxes.
    static public void run(Container container)
    {
        auto runToken = begin(container);
        runLoop(runToken);
        end(runToken);
    }

    /// Use this method to complete an execution started with begin
    static public void end(RunState state)
    {
        if (state is null)
            throw new Exception("state cannot be null");

        state.dispose();
    }

    // Called by the Dispose handler.
    package static void end(Container container)
    {
        toplevels = toplevels.remove!(c => c == container);

        if (toplevels.length == 0)
            shutdown();
        else
            Application.refresh();
    }

    private static void processChar(Container container)
    {
        wchar_t ch;
        get_wch(&ch);

        if ((ch == -1) || (ch == KEY_RESIZE))
        {
            resize();
            return;
        }

        if (ch == KEY_MOUSE)
        {
            MEVENT ev;

            if (OK == getmouse(&ev)) {
                container.processMouse(&ev);
            }

            return;
        }

        if (ch == Keys.Esc)
        {
            timeout(100);
            immutable k = getch();
            if (k != ERR && k != Keys.Esc)
                ch = Keys.Alt | k;
            timeout(-1);
        }

        if (container.processHotKey(ch))
            return;

        if (container.processKey(ch))
            return;

        if (container.processColdKey(ch))
            return;

        // Control-c, quit the current operation.
        if (ch == Keys.CtrlC)
        {
            container.running = false;
            return;
        }

        // Control-z, suspend execution, then repaint.
        if (ch == Keys.CtrlZ)
        {
            suspend();
            redrawwin(stdscr);
            deimos.ncurses.refresh();
        }

        //
        // Focus handling
        //
        if (ch == Keys.Tab) {
            if (!container.focusNext())
                container.focusNext();
            deimos.ncurses.refresh();
        } else if (ch == Keys.ShiftTab) {
            if (!container.focusPrev())
                container.focusPrev();
            deimos.ncurses.refresh();
        }
    }

    /// Suspends the process by sending SIGTSTP to itself
    private static void suspend()
    {
        killpg(0, SIGTSTP);
    }

    private static void resize()
    {
        emptyContainer.clear();
        foreach (c; toplevels) {
            c.sizeChanged();
        }

        Application.refresh();
    }

    // SIGWINCH terminal window resize handler
    extern(C)
    private static void sigHandler(int signo, siginfo_t* info, void* ctx) nothrow
    {
        import core.sys.posix.sys.ioctl : TIOCGWINSZ, ioctl, winsize;

        winsize size;
        if (ioctl(0, TIOCGWINSZ, &size) != 0) {
            // no success in getting the new window size
            return;
        }

        if (!is_term_resized(size.ws_row, size.ws_col)) {
            // ncurses doesn't think anything was modified
            return;
        }

        // update Application state
        Application._lines = size.ws_row;
        Application._cols = size.ws_col;

        // resize underlying ncurses data structures
        resize_term(Application._lines, Application._cols);

        // resize the application itself
        try {
            Application.resize();
        } catch (Exception e) {
            // This is fine.
        }
    }
}
