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

module ctui.application;

import core.stdc.locale;
import core.sys.posix.signal;

import std.algorithm : max, remove;
import std.encoding : index;
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
/// Before using ctui, you must call Application.Init, then you would create
/// your toplevel container (typically by calling:
/// `new Container(0, 0, Application.Cols, Application.Lines)`, adding widgets
/// to it and finally calling `Application.Run()` on the toplevel container).
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
    public static int MakeColor(short f, short b)
    {
        init_pair(++last_color_pair, f, b);
        return cast(int)COLOR_PAIR(last_color_pair);
    }

    /// The singleton EmptyContainer that covers the entire screen.
    static public @property Container EmptyContainer()
    {
        return empty_container;
    }

    private static WINDOW* main_window;
    private static bool using_color;
    private static int cols, lines;

    /// The applications MainLoop.
    static MainLoop mainLoop;

    /// Determine of the application is using colors.
    ///
    /// During the initialisation of the terminal, this is set according to the
    /// capabilities of the terminal.
    public static @property bool UsingColor()
    {
        return using_color;
    }

    /// Initializes the runtime.
    public static void Init()
    {
        if (inited)
            return;
        inited = true;

        empty_container = new Container(0, 0, Application.Cols, Application.Lines);

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
            throw new Exception("Application.Init failed");
        }

        // get initial column and line count from curses
        cols = COLS;
        lines = LINES;

        raw();
        noecho();
        curs_set(0);
        set_escdelay(0);
        main_window.keypad(true);
        mousemask(ALL_MOUSE_EVENTS, null);

        using_color = has_colors();
        start_color();
        use_default_colors();

        if (UsingColor)
        {
            colorNormal = MakeColor(COLOR_WHITE, COLOR_BLUE);
            colorFocus = MakeColor(COLOR_BLACK, COLOR_CYAN);
            colorHotNormal = A_BOLD | MakeColor(COLOR_YELLOW, COLOR_BLUE);
            colorHotFocus = A_BOLD | MakeColor(COLOR_YELLOW, COLOR_CYAN);

            colorMenu = A_BOLD | MakeColor(COLOR_WHITE, COLOR_CYAN);
            colorMenuHot = A_BOLD | MakeColor(COLOR_YELLOW, COLOR_CYAN);
            colorMenuSelected = A_BOLD | MakeColor(COLOR_WHITE, COLOR_BLACK);
            colorMenuHotSelected = A_BOLD | MakeColor(COLOR_YELLOW, COLOR_BLACK);

            colorMarked = colorHotNormal;
            colorMarkedSelected = colorHotFocus;

            colorDialogNormal    = MakeColor(COLOR_BLACK, COLOR_WHITE);
            colorDialogFocus     = MakeColor(COLOR_BLACK, COLOR_CYAN);
            colorDialogHotNormal = MakeColor(COLOR_BLUE,  COLOR_WHITE);
            colorDialogHotFocus  = MakeColor(COLOR_BLUE,  COLOR_CYAN);

            colorError = A_BOLD | MakeColor(COLOR_WHITE, COLOR_RED);
            colorErrorFocus = MakeColor(COLOR_BLACK, COLOR_WHITE);
            colorErrorHot = A_BOLD | MakeColor(COLOR_YELLOW, COLOR_RED);
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

        colorBasic = MakeColor(-1, -1);

        mainLoop = new MainLoop();
        mainLoop.addWatch(0, MainLoop.Condition.PollIn, {
            Container top = toplevels.length > 0
                ? toplevels[toplevels.length - 1]
                : null;
            if (top !is null)
                ProcessChar(top);

            return true;
        });
    }

    /// The number of lines on the screen
    static public @property int Lines()
    {
        return lines;
    }

    /// The number of columns on the screen
    static public @property int Cols()
    {
        return cols;
    }

    /// Displays a message on a modal dialog box.
    ///
    /// The error boolean indicates whether this is an error message box or
    /// not.
    static public void Msg(bool error, string caption, string t)
    {
        string[] lines;
        int last;
        size_t max_w;
        string x;
        for (int i; i < t.count; i++)
        {
            if (t[t.index(i)] == '\n') {
                x = t.substring(last, i - last);
                lines ~= x;
                last = i + 1;
                if (x.count > max_w)
                    max_w = x.count;
            }
        }
        x = t.substring(last);
        if (x.count > max_w)
            max_w = x.count;
        lines ~= x;

        Dialog d = new Dialog(cast(int)max(caption.count + 8, max_w + 8), cast(int)lines.length + 7, caption);
        if (error)
            d.errorColors();

        for (int i = 0; i < lines.length; i++)
            d.add(new Label(1, i + 1, lines[i]));

        Button b = new Button(0, 0, "Ok", true);
        d.addButton(b);
        b.clicked = { b.container.running = false; };

        Application.Run(d);
    }

    /// Displays an error message.
    static public void Error(string caption, string text)
    {
        Msg(true, caption, text);
    }

    /// Displays an error message.
    ///
    /// Overload that allows for `std.format` parameters.
    static public void Error(string caption, string format, A...)(A args)
    {
        string t = format(format, args);

        Msg(true, caption, t);
    }

    /// Displays an informational message.
    static public void Info(string caption, string text)
    {
        Msg(false, caption, text);
    }

    /// Displays an informational message.
    ///
    /// Overload that allows for `std.format` parameters.
    static public void Info(string caption, string format, A...)(A args)
    {
        string t = format(format, args);

        Msg(false, caption, t);
    }

    private static void Shutdown()
    {
        endwin();
    }

    private static void redraw(Container container)
    {
        container.redraw();
        refresh();
    }

    /// Forces a repaint of the screen.
    public static void Refresh()
    {
        Container last = null;

        redrawwin(main_window);
        foreach (c; toplevels)
        {
            c.redraw();
            last = c;
        }

        refresh();
        if (last !is null)
            last.positionCursor();
    }

    /// Starts running a new container or dialog box.
    ///
    /// Use this method if you want to start the dialog, but you want to
    /// control the main loop execution manually by calling the RunLoop method
    /// (for example, to start the dialog, but continuing to process events).
    ///
    /// Use the returned value as the argument to RunLoop and later to the End
    /// method to remove the container from the screen.
    static public RunState Begin(Container container)
    {
        if (container is null)
            throw new Exception("container cannot be null");

        RunState rs = new RunState(container);

        Init();

        timeout(-1);

        toplevels ~= container;

        container.prepare();
        container.sizeChanged();
        container.focusFirst();
        redraw(container);
        container.positionCursor();
        Refresh();

        return rs;
    }

    /// Runs the main loop for the created dialog
    ///
    /// Calling this method will block until the dialog has completed execution.
    public static void RunLoop(RunState state)
    {
        RunLoop(state, true);
    }

    /// Runs the main loop for the created dialog
    ///
    /// Use the wait parameter to control whether this is a blocking or
    /// non-blocking call.
    public static void RunLoop(RunState state, bool wait)
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

    /// Stop the main loop.
    public static void Stop()
    {
        if (toplevels.length == 0)
            return;

        toplevels[toplevels.length - 1].running = false;
        mainLoop.stop();
    }

    /// Runs the main loop on the given container.
    ///
    /// This method is used to start processing events for the main
    /// application, but it is also used to run modal dialog boxes.
    static public void Run(Container container)
    {
        auto runToken = Begin(container);
        RunLoop(runToken);
        End(runToken);
    }

    /// Use this method to complete an execution started with Begin
    static public void End(RunState state)
    {
        if (state is null)
            throw new Exception("state cannot be null");

        state.dispose();
    }

    // Called by the Dispose handler.
    package static void End(Container container)
    {
        toplevels = toplevels.remove!(c => c == container);

        if (toplevels.length == 0)
            Shutdown();
        else
            Refresh();
    }

    private static void ProcessChar(Container container)
    {
        wchar_t ch;
        get_wch(&ch);

        if ((ch == -1) || (ch == KEY_RESIZE))
        {
            Resize();
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
            int k = getch();
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
            Suspend();
            redrawwin(stdscr);
            refresh();
        }

        //
        // Focus handling
        //
        if (ch == Keys.Tab) {
            if (!container.focusNext())
                container.focusNext();
            refresh();
        } else if (ch == Keys.ShiftTab) {
            if (!container.focusPrev())
                container.focusPrev();
            refresh();
        }
    }

    /// Suspends the process by sending SIGTSTP to itself
    private static void Suspend()
    {
        killpg(0, SIGTSTP);
    }

    private static void Resize()
    {
        EmptyContainer.clear();
        foreach (c; toplevels) {
            c.sizeChanged();
        }
        Refresh();
    }

    // SIGWINCH terminal window resize handler
    extern(C)
    private static void sigHandler(int signo, siginfo_t* info, void* ctx) nothrow
    {
        import core.sys.posix.sys.ioctl;

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
        Application.lines = size.ws_row;
        Application.cols = size.ws_col;

        // resize underlying ncurses data structures
        resize_term(Application.lines, Application.cols);

        // resize the application itself
        try {
            Application.Resize();
        } catch (Exception e) {
            // This is fine.
        }
    }
}
