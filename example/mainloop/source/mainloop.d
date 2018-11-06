import core.time : dur;
import std.datetime : Clock;
import std.stdio;

import ctui.mainloop;

void main()
{
    MainLoop ml = new MainLoop();

    Stamp("Start");
    ml.AddTimeout(dur!"seconds"(1), {
        Stamp("second");
        return true;
    });

    int i = 0;
    ml.AddTimeout(dur!"seconds"(3), {
        Stamp("three");
        if (++i >= 3)
            return false;
        return true;
    });

    ml.AddTimeout(dur!"seconds"(15), {
        Stamp("That's all, folks!");
        ml.Stop();
        return false;
    });

    ml.Run();
}

static void Stamp(string txt)
{
    writefln("%s - %s", Clock.currTime, txt);
}
