import core.time : dur;
import std.datetime : Clock;
import std.stdio;

import ctui.mainloop;

void main()
{
    MainLoop ml = new MainLoop();

    stamp("Start");
    ml.addTimeout(dur!"seconds"(1), {
        stamp("second");
        return true;
    });

    int i = 0;
    ml.addTimeout(dur!"seconds"(3), {
        stamp("three");
        if (++i >= 3)
            return false;
        return true;
    });

    ml.addTimeout(dur!"seconds"(15), {
        stamp("That's all, folks!");
        ml.stop();
        return false;
    });

    ml.run();
}

private static void stamp(string txt)
{
    writefln("%s - %s", Clock.currTime, txt);
}
