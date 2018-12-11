//
// mainloop.cs: Simple managed mainloop implementation.
//
// Copyright (C) 2011 Novell (http://www.novell.com)
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

module ctui.mainloop;

import core.sys.posix.poll;
import core.sys.posix.unistd;
import core.time : Duration, MonoTime;

import std.algorithm : minElement, remove;

import ctui.application;
import ctui.widgets.container;

/// A delegate that is used by addWatch and addTimeout.
public alias Callback = bool delegate();

/// A delegate used by AddIdle.
public alias Handler = bool delegate();

package class RunState {
    package Container container;

    package this(Container c)
    {
        container = c;
    }

    package void dispose()
    {
        if (container !is null) {
            Application.end(container);
            container = null;
        }
    }
}

/// Simple main loop implementation that can be used to monitor file
/// descriptor, run timers and idle handlers.
public class MainLoop {
    /// Conditions of file descriptors that can be monitored.
    enum Condition {
        /// There is data to read
        PollIn = POLLIN,
        /// Writing to the specified descriptor will not block
        PollOut = POLLOUT,
        /// There is urgent data to read
        PollPri = POLLPRI,
        ///  Error condition on output
        PollErr = POLLERR,
        /// Hang-up on output
        PollHup = POLLHUP,
        /// File descriptor is not open.
        PollNval = POLLNVAL,
    }

    private class Watch {
        public Condition condition;
        public Callback callback;
        public int fd;

        public this(Condition condition, Callback callback, int fd)
        {
            this.condition = condition;
            this.callback = callback;
            this.fd = fd;
        }
    }

    private class Timeout {
        public Duration span;
        public Callback callback;

        public this(Duration span, Callback callback)
        {
            this.span = span;
            this.callback = callback;
        }
    }

    private Watch[int] descriptorWatchers;
    private Timeout[long] timeouts;
    private Handler[] idleHandlers;

    private pollfd[] pollmap;
    private bool poll_dirty = true;
    private int[2] wakeupPipes;
    private static int ignore;

    /// Default constructor
    public this()
    {
        pipe(wakeupPipes);

        this.addWatch(wakeupPipes[0], Condition.PollIn, {
            read(wakeupPipes[0], &ignore, 1);
            return true;
        });
    }

    private void wakeup()
    {
        write(wakeupPipes[1], &ignore, 1);
    }

    /// Executes the specified idleHandler on the idle loop.
    /// The return value is a token to remove it.
    public Handler addIdle(Handler idleHandler)
    {
        synchronized idleHandlers ~= idleHandler;
        return idleHandler;
    }

    /// Removes the specified idleHandler from processing.
    public void removeIdle(Handler idleHandler)
    {
        synchronized idleHandlers = idleHandlers.remove!(h => h == idleHandler);
    }

    /// Watches a file descriptor for activity.
    ///
    /// When the condition is met, the provided callback is invoked. If
    /// callback returns false, the watch is automatically removed.
    ///
    /// The return value is a token that represents this watch, you can use
    /// this token to remove the watch by calling removeWatch.
    public Watch addWatch(int fileDescriptor, Condition condition, Callback callback)
    {
        if (callback is null)
        {
            throw new Exception("callback must not be null");
        }

        Watch watch = new Watch(condition, callback, fileDescriptor);
        descriptorWatchers[fileDescriptor] = watch;
        poll_dirty = true;

        return watch;
    }

    /// Removes an active watch from the mainloop.
    ///
    /// The watch parameter is the value returned from addWatch
    public void removeWatch(Watch watch)
    {
        if (watch is null)
        {
            return;
        }

        descriptorWatchers.remove(watch.fd);
    }

    private long addTimeout(Duration time, Timeout timeout)
    {
        long key = (MonoTime.currTime + time).ticks;
        timeouts[key] = timeout;

        return key;
    }

    /// Adds a timeout to the mainloop.
    ///
    /// When time time specified passes, the callback will be invoked. If
    /// callback returns true, the timeout will be reset, repeating the
    /// invocation. If it returns false, the timeout will stop.
    ///
    /// The returned value is a token that can be used to stop the timeout
    /// by calling RemoveTimeout.
    public long addTimeout(Duration time, Callback callback)
    {
        if (callback is null)
        {
            throw new Exception("callback must not be null");
        }

        Timeout timeout = new Timeout(time, callback);
        return addTimeout(time, timeout);
    }

    /// Removes a previously scheduled timeout
    ///
    /// The token parameter is the value returned by addTimeout.
    public void removeTimeout(long timeout)
    {
        timeouts.remove(timeout);
    }

    private void updatePollMap()
    {
        if (!poll_dirty)
        {
            return;
        }
        poll_dirty = false;

        pollmap = new pollfd[descriptorWatchers.length];
        int i = 0;
        foreach (fd; descriptorWatchers.keys) {
            pollmap[i].fd = fd;
            pollmap[i].events = cast(short)descriptorWatchers[fd].condition;
            i++;
        }
    }

    private void runTimers()
    {
        immutable now = MonoTime.currTime.ticks;
        auto copy = timeouts.dup;

        timeouts.clear;
        foreach (key, timeout; copy)
        {
            if (key < now)
            {
                if (timeout.callback())
                    addTimeout(timeout.span, timeout);
            }
            else
            {
                timeouts[key] = timeout;
            }
        }
    }

    private void runIdle()
    {
        Handler[] iterate;
        synchronized
        {
            iterate = idleHandlers;
            idleHandlers.length = 0;
        }

        foreach (idle; iterate)
        {
            if (idle()) {
                synchronized idleHandlers ~= (idle);
            }
        }
    }

    private bool running;

    /// Stops the mainloop.
    public void stop()
    {
        running = false;
        wakeup();
    }

    /// Determines whether there are pending events to be processed.
    ///
    /// You can use this method if you want to probe if events are pending.
    /// Typically used if you need to flush the input queue while still
    /// running some of your own code in your main thread.
    public bool eventsPending(bool wait=false)
    {
        int pollTimeout;

        if (timeouts.length > 0)
        {
            immutable now = MonoTime.currTime.ticks;
            immutable next_timeout = timeouts.keys.minElement;

            pollTimeout = ((next_timeout - now) / (MonoTime.ticksPerSecond / 1000));

            if (pollTimeout < 0)
            {
                return true;
            }
        }
        else
        {
            pollTimeout = -1;
        }

        if (!wait)
        {
            pollTimeout = 0;
        }

        updatePollMap();

        int n = poll(pollmap.ptr, cast(nfds_t)pollmap.length, pollTimeout);

        return n > 0
            || timeouts.length > 0
            && ((timeouts.keys[0] - MonoTime.currTime.ticks) < 0)
            || idleHandlers.length > 0;
    }

    /// Runs one iteration of timers and file watches
    ///
    /// You use this to process all pending events (timers, idle handlers
    /// and file watches).
    ///
    /// Example:
    /// ---
    /// while (main.eventsPending()) mainIteration();
    /// ---
    public void mainIteration()
    {
        if (timeouts.length > 0)
            runTimers();

        foreach (p; pollmap) {
            if (p.revents == 0) {
                continue;
            }

            if (p.fd !in descriptorWatchers) {
                continue;
            }

            if (!descriptorWatchers[p.fd].callback()) {
                descriptorWatchers.remove(p.fd);
            }
        }

        if (idleHandlers.length > 0)
        {
            runIdle();
        }
    }

    /// Runs the mainloop.
    public void run()
    {
        immutable prev = running;
        running = true;

        while (running) {
            eventsPending(true);
            mainIteration();
        }

        running = prev;
    }
}
