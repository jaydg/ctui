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
import std.utf : count;
import deimos.ncurses;

import ctui.keys;
import ctui.mainloop;
import ctui.utils;
import ctui.widgets.button;
import ctui.widgets.container;
import ctui.widgets.dialog;
import ctui.widgets.label;

///
///   gui.cs Application driver.
///
///
///   Before using gui.cs, you must call Application.Init, then
///   you would create your toplevel container (typically by
///   calling:  new Container(0, 0, Application.Cols,
///   Application.Lines), adding widgets to it and finally
///   calling Application.Run() on the toplevel container).
///
public class Application {
    /// Color used for unfocused widgets.
    public static int ColorNormal;
    /// Color used for focused widgets.
    public static int ColorFocus;
    /// Color used for hotkeys in unfocused widgets.
    public static int ColorHotNormal;
    /// Color used for hotkeys in focused widgets.
    public static int ColorHotFocus;

    /// Color used for marked entries.
    public static int ColorMarked;
    /// Color used for marked entries that are currently
    /// selected with the cursor.
    public static int ColorMarkedSelected;

    /// Color for unfocused widgets on a dialog.
    public static int ColorDialogNormal;
    /// Color for focused widgets on a dialog.
    public static int ColorDialogFocus;
    /// Color for hotkeys in an unfocused widget on a dialog.
    public static int ColorDialogHotNormal;
    /// Color for a hotkey in a focused widget on a dialog.
    public static int ColorDialogHotFocus;

    /// Color used for error text.
    public static int ColorError;

    /// Color used for focused widgets on an error dialog.
    public static int ColorErrorFocus;

    /// Color used for hotkeys in error dialogs
    public static int ColorErrorHot;

    /// Color used for hotkeys in a focused widget in an error dialog
    public static int ColorErrorHotFocus;

    /// The basic color of the terminal.
    public static int ColorBasic;

    /// The regular color for a selected item on a menu
    public static int ColorMenuSelected;

    /// The hot color for a selected item on a menu
    public static int ColorMenuHotSelected;

    /// The regular color for a menu entry
    public static int ColorMenu;

    /// The hot color for a menu entry
    public static int ColorMenuHot;

    /// This event is raised on each iteration of the
    /// main loop.
    ///
    /// See also <see cref="Timeout"/>
    public static void delegate() iteration;

    // Private variables
    static Container[] toplevels;
    static short last_color_pair;
    static bool inited;
    static Container empty_container;

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

    static WINDOW* main_window;
    static MainLoop mainLoop;

    static bool using_color = false;
    static int cols, lines;

    public static @property bool UsingColor()
    {
        return using_color;
    }

    ///
    ///   Initializes the runtime.
    ///
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
            ColorNormal = MakeColor(COLOR_WHITE, COLOR_BLUE);
            ColorFocus = MakeColor(COLOR_BLACK, COLOR_CYAN);
            ColorHotNormal = A_BOLD | MakeColor(COLOR_YELLOW, COLOR_BLUE);
            ColorHotFocus = A_BOLD | MakeColor(COLOR_YELLOW, COLOR_CYAN);

            ColorMenu = A_BOLD | MakeColor(COLOR_WHITE, COLOR_CYAN);
            ColorMenuHot = A_BOLD | MakeColor(COLOR_YELLOW, COLOR_CYAN);
            ColorMenuSelected = A_BOLD | MakeColor(COLOR_WHITE, COLOR_BLACK);
            ColorMenuHotSelected = A_BOLD | MakeColor(COLOR_YELLOW, COLOR_BLACK);

            ColorMarked = ColorHotNormal;
            ColorMarkedSelected = ColorHotFocus;

            ColorDialogNormal    = MakeColor(COLOR_BLACK, COLOR_WHITE);
            ColorDialogFocus     = MakeColor(COLOR_BLACK, COLOR_CYAN);
            ColorDialogHotNormal = MakeColor(COLOR_BLUE,  COLOR_WHITE);
            ColorDialogHotFocus  = MakeColor(COLOR_BLUE,  COLOR_CYAN);

            ColorError = A_BOLD | MakeColor(COLOR_WHITE, COLOR_RED);
            ColorErrorFocus = MakeColor(COLOR_BLACK, COLOR_WHITE);
            ColorErrorHot = A_BOLD | MakeColor(COLOR_YELLOW, COLOR_RED);
            ColorErrorHotFocus = ColorErrorHot;
        } else {
            ColorNormal = A_NORMAL;
            ColorFocus = A_REVERSE;
            ColorHotNormal = A_BOLD;
            ColorHotFocus = A_REVERSE | A_BOLD;

            ColorMenu = A_REVERSE;
            ColorMenuHot = A_NORMAL;
            ColorMenuSelected = A_BOLD;
            ColorMenuHotSelected = A_NORMAL;

            ColorMarked = A_BOLD;
            ColorMarkedSelected = A_REVERSE | A_BOLD;

            ColorDialogNormal = A_REVERSE;
            ColorDialogFocus = A_NORMAL;
            ColorDialogHotNormal = A_BOLD;
            ColorDialogHotFocus = A_NORMAL;

            ColorError = A_BOLD;
        }

        ColorBasic = MakeColor(-1, -1);

        mainLoop = new MainLoop();
        mainLoop.AddWatch(0, MainLoop.Condition.PollIn, {
            Container top = toplevels.length > 0
                ? toplevels[toplevels.length - 1]
                : null;
            if (top !is null)
                ProcessChar(top);

            return true;
        });
    }

    ///   The number of lines on the screen
    static public @property int Lines()
    {
        return lines;
    }

    ///   The number of columns on the screen
    static public @property int Cols()
    {
        return cols;
    }

    ///   Displays a message on a modal dialog box.
    ///
    ///   The error boolean indicates whether this is an
    ///   error message box or not.
    static public void Msg(bool error, string caption, string t)
    {
        string[] lines;
        int last = 0;
        size_t max_w = 0;
        string x;
        for (int i = 0; i < t.count; i++)
        {
            if (t[i] == '\n') {
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
            d.ErrorColors();

        for (int i = 0; i < lines.length; i++)
            d.Add(new Label(1, i + 1, lines[i]));

        Button b = new Button(0, 0, "Ok", true);
        d.AddButton(b);
        b.clicked = { b.container.running = false; };

        Application.Run(d);
    }

    ///   Displays an error message.
    static public void Error(string caption, string text)
    {
        Msg(true, caption, text);
    }

    ///   Displays an error message.
    ///
    ///   Overload that allows for String.Format parameters.
    static public void Error(string caption, string format, A...)(A args)
    {
        string t = format(format, args);

        Msg(true, caption, t);
    }

    ///   Displays an informational message.
    static public void Info(string caption, string text)
    {
        Msg(false, caption, text);
    }

    ///   Displays an informational message.
    ///
    ///   Overload that allows for String.Format parameters.
    static public void Info(string caption, string format, A...)(A args)
    {
        string t = format(format, args);

        Msg(false, caption, t);
    }

    static void Shutdown()
    {
        endwin();
    }

    static void Redraw(Container container)
    {
        container.Redraw();
        refresh();
    }

    ///   Forces a repaint of the screen.
    public static void Refresh()
    {
        Container last = null;

        redrawwin(main_window);
        foreach (c; toplevels)
        {
            c.Redraw();
            last = c;
        }

        refresh();
        if (last !is null)
            last.PositionCursor();
    }

    /// Starts running a new container or dialog box.
    ///
    /// Use this method if you want to start the dialog, but
    /// you want to control the main loop execution manually
    /// by calling the RunLoop method (for example, to start
    /// the dialog, but continuing to process events).
    ///
    /// Use the returned value as the argument to RunLoop
    /// and later to the End method to remove the container
    /// from the screen.
    static public RunState Begin(Container container)
    {
        if (container is null)
            throw new Exception("container cannot be null");

        RunState rs = new RunState(container);

        Init();

        timeout(-1);

        toplevels ~= container;

        container.Prepare();
        container.SizeChanged();
        container.FocusFirst();
        Redraw(container);
        container.PositionCursor();
        Refresh();

        return rs;
    }

    /// Runs the main loop for the created dialog
    ///
    /// Calling this method will block until the
    /// dialog has completed execution.
    public static void RunLoop(RunState state)
    {
        RunLoop(state, true);
    }

    /// Runs the main loop for the created dialog
    ///
    /// Use the wait parameter to control whether this is a
    /// blocking or non-blocking call.
    public static void RunLoop(RunState state, bool wait)
    {
        if (state is null)
            throw new Exception("state cannot be null");
        if (state.container is null)
            throw new Exception("Object is disposed");

        for (state.container.running = true; state.container.running;) {
            if (mainLoop.EventsPending(wait)) {
                mainLoop.MainIteration();
                // per-iteration callback
                if (iteration)
                    iteration();
            } else if (wait == false)
                return;
        }
    }

    public static void Stop()
    {
        if (toplevels.length == 0)
            return;

        toplevels[toplevels.length - 1].running = false;
        mainLoop.Stop();
    }

    /// Runs the main loop on the given container.
    ///
    /// This method is used to start processing events
    /// for the main application, but it is also used to
    /// run modal dialog boxes.
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

        state.Dispose();
    }

    // Called by the Dispose handler.
    static void End(Container container)
    {
        toplevels = toplevels.remove!(c => c == container);

        if (toplevels.length == 0)
            Shutdown();
        else
            Refresh();
    }

    static void ProcessChar(Container container)
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
                container.ProcessMouse(&ev);
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

        if (container.ProcessHotKey(ch))
            return;

        if (container.ProcessKey(ch))
            return;

        if (container.ProcessColdKey(ch))
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
            if (!container.FocusNext())
                container.FocusNext();
            refresh();
        } else if (ch == Keys.ShiftTab) {
            if (!container.FocusPrev())
                container.FocusPrev();
            refresh();
        }
    }

    /// Suspends the process by sending SIGTSTP to itself
    /// <returns>The suspend.</returns>
    static bool Suspend()
    {
        killpg(0, SIGTSTP);
        return true;
    }

    static void Resize()
    {
        EmptyContainer.Clear();
        foreach (c; toplevels) {
            c.SizeChanged();
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
