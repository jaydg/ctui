import core.time : dur;
import core.stdc.stddef;

import std.conv : to, ConvException;
import std.datetime : Clock;
import std.file : exists, getcwd, isDir, isFile;
import std.path : expandTilde;
import std.string : format, toStringz;
import std.utf : count;

import ctui;
import ctui.utils;

private static void optionsDialog()
{
    Dialog d = new Dialog(62, 18, "Options");

    d.Add(new Label(1, 1, "  Download Directory:"));
    d.Add(new Label(1, 3, "         Listen Port:"));
    d.Add(new Label(1, 5, "  Upload Speed Limit:"));
    d.Add(new Label(35,5, "kB/s"));
    d.Add(new Label(1, 7, "Download Speed Limit:"));
    d.Add(new Label(35,7, "kB/s"));
    d.Add(new Label(1, 9, "        Stealth Mode:"));

    Entry download_dir = new Entry(24, 1, 30, "~/Download");
    d.Add(download_dir);

    Entry listen_port = new Entry(24, 3, 6, "34");
    d.Add(listen_port);

    Entry upload_limit = new Entry(24, 5, 10, "1024");
    d.Add(upload_limit);

    Entry download_limit = new Entry(24, 7, 10, "1024");
    d.Add(download_limit);

    RadioGroup stealthMode = new RadioGroup(24, 9, ["Off", "Partial", "Full"]);
    d.Add(stealthMode);

    bool ok;

    Button b = new Button("Ok", true);
    b.clicked = { ok = true; b.container.running = false; };
    d.AddButton(b);

    b = new Button("Cancel");
    b.clicked = { b.container.running = false; };
    d.AddButton(b);

    Application.Run(d);

    if (ok) {
        try {
            to!int(listen_port.Text);
        } catch (ConvException) {
            Application.Error("Error", format!"The value `%s' is not a valid port number"(listen_port.Text));
            return;
        }

        auto fullPath = expandTilde(download_dir.Text);
        if (!exists(fullPath) || !isDir(fullPath)) {
            Application.Error("Error", format!"The directory\n%s\ndoes not exist"(download_dir.Text));
            return;
        }
    }
}

private static void addDialog()
{
    int cols = cast(int)(Application.Cols * 0.7);
    Dialog d = new Dialog(cols, 8, "Add");
    string name;

    d.Add(new Label(1, 0, "Torrent file:"));
    Entry e = new Entry(1, 1, cols - 6, getcwd);
    d.Add(e);

    // buttons
    Button b = new Button("Ok", true);
    b.clicked = {
        b.container.running = false;
        name = e.Text;
    };
    d.AddButton(b);

    b = new Button("Cancel");
    b.clicked = { b.container.running = false; };
    d.AddButton(b);

    Application.Run(d);

    if (name !is null) {
        if (!exists(name) || !isFile(name)) {
            Application.Error("Missing File", format!"Torrent file:\n%s\ndoes not exist"(name));
            return;
        }
    }
}

private class TorrentDetailsList : IListProvider {
    public ListView view;

    void SetListView(ListView v)
    {
        view = v;
    }

    @property int Items() {
        return 5;
    }

    @property bool AllowMark() {
        return false;
    }

    bool IsMarked(int n)
    {
        return false;
    }

    void Render(int line, int col, int width, int item)
    {
        string s = format!"%d This is item %d"(item, item);
        if (s.count > width) {
            s = s.substring(0, width);
            addstr(s.toStringz);
        } else {
            addstr(s.toStringz);
            for (size_t i = s.count; i < width; i++)
                addch(' ');
        }
    }

    bool processKey(wchar_t ch)
    {
        return false;
    }

    void SelectedChanged()
    {
    }
}

private class LogWidget : Widget {
    private string[80] messages;
    private size_t head, tail;
    private int count;

    public this(int x, int y)
    {
        super(x, y, 0, 0);
        fill = Fill.Horizontal | Fill.Vertical;
        AddText("Started");
    }

    public void AddText(string s)
    {
        messages[head] = s;
        head++;

        if (head == messages.length)
            head = 0;
        if (head == tail)
            tail = (tail + 1) % messages.length;
    }

    public override void redraw()
    {
        attrset(ColorNormal);

        int i, l;
        size_t n = head > tail
            ? head - tail
            : (head + messages.length) - tail;

        for (l = height - 1; l >= 0 && n-- > 0; l--) {
            long item = head - 1 - i;
            if (item < 0)
                item = messages.length + item;

            Move(y + l, x);

            immutable sl = messages[item].count;
            if (sl < width) {
                addstr(messages[item].toStringz);
                for (int fi; fi < width - sl; fi++)
                    addch (' ');
            } else {
                addstr(messages[item].substring (0, width).toStringz);
            }
            i++;
        }

        for (; l >= 0; l--) {
            Move (y + l, x);
            for (i = 0; i < width; i++)
                addch(' ');
        }
    }
}

private static ProgressBar status_progress;
private static Label status_state, status_peers,
    status_tracker, status_up, status_up_speed, status_down,
    status_down_speed, status_warnings, status_failures, iteration;

private static Frame setupStatus()
{
    Frame fstatus = new Frame("Status");
    int y;
    int x = 13;
    string init = "<init>";

    fstatus.Add(status_progress = new ProgressBar(x, y, 24));
    fstatus.Add(new Label(1, y++, "Progress:"));

    fstatus.Add(status_state = new Label(x, y, init));
    fstatus.Add(new Label(1, y++, "State:"));

    fstatus.Add(status_peers = new Label(x, y, init));
    fstatus.Add(new Label(1, y++, "Peers:"));

    fstatus.Add(status_tracker = new Label(x, y, init));
    fstatus.Add(new Label(1, y++, "Tracker: "));
    y++;

    fstatus.Add(new Label(1, y++, "Upload:"));
    fstatus.Add(new Label(16, y, "KB   Speed: "));
    fstatus.Add(status_up = new Label(1, y, init));
    fstatus.Add(status_up_speed = new Label(28, y, init));
    y++;
    fstatus.Add(new Label (1, y++, "Download:"));
    fstatus.Add(new Label (16, y, "KB   Speed: "));
    fstatus.Add(status_down = new Label(1, y, init));
    fstatus.Add(status_down_speed = new Label(28, y, init));
    y += 2;
    fstatus.Add(status_warnings = new Label(11, y, init));
    fstatus.Add(new Label (1, y++, "Warnings: "));
    fstatus.Add(status_failures = new Label(11, y, init));
    fstatus.Add(new Label (1, y++, "Failures: "));
    y += 2;

    return fstatus;
}

//
// We split this, so if the terminal resizes, we resize accordingly
//
private static void layoutDialogs(Frame ftorrents, Frame fstatus, Frame fdetails, Frame fprogress)
{
    immutable cols = Application.Cols;
    immutable midx = Application.Cols / 2;
    immutable midy = Application.Lines / 2;

    // Torrents
    ftorrents.x = 0;
    ftorrents.y = 0;
    ftorrents.width = cols - 40;
    ftorrents.height = midy;

    // Status: Always 40x12
    fstatus.x = cols - 40;
    fstatus.y = 0;
    fstatus.width = 40;
    fstatus.height = midy;

    // Details
    fdetails.x = 0;
    fdetails.y = midy;
    fdetails.width = midx;
    fdetails.height = midy;

    // fprogress
    fprogress.x = midx;
    fprogress.y = midy;
    fprogress.width = midx + cols % 2;
    fprogress.height = midy;
}

private static void updateStatus(int iteration)
{
    immutable ct = Clock.currTime.toString.substring(0, 20);
    status_progress.fraction = (iteration % 100) / 100.0;
    status_state.Text = ct;
    status_peers.Text = ct;
    status_up.Text = "1000";
    status_up_speed.Text = "Lots";
}

void main()
{
    Application.Init();

    auto top = new Container(0, 0, Application.Cols, Application.Lines);
    auto frame = new Frame(0, 0, Application.Cols, Application.Lines, "List");
    top.Add(frame);

    // Add
    Button badd = new Button(1, 1, "Add");
    badd.clicked = { addDialog(); };
    frame.Add(badd);

    // Options
    Button boptions = new Button(9, 1, "Options");
    boptions.clicked = { optionsDialog(); };
    frame.Add(boptions);

    // Quit
    Button bquit = new Button(21, 1, "Quit");
    bquit.clicked = { top.running = false; };
    frame.Add(bquit);

    ListView list = new ListView(1, 5, 0, 0, new TorrentDetailsList());
    list.fill = Fill.Horizontal | Fill.Vertical;
    frame.Add(list);

    Frame fprogress = new Frame("Messages");
    LogWidget log_widget = new LogWidget(0, 0);
    fprogress.Add(log_widget);
    top.Add(fprogress);

    // Details
    Frame fdetails = new Frame("Details");
    fdetails.Add(new Label(1, 1, "Files for: "));
    TrimLabel torrent_name = new TrimLabel(12, 1, 10, "");
    torrent_name.fill = Fill.Horizontal;
    fdetails.Add(torrent_name);

    auto details_list = new TorrentDetailsList();
    auto list_details = new ListView(1, 3, 0, 0, details_list);
    list_details.fill = Fill.Horizontal | Fill.Vertical;
    fdetails.Add(list_details);

    top.Add(fdetails);

    // Status
    Frame fstatus = setupStatus();
    top.Add(fstatus);

    int it;
    Application.mainLoop.AddTimeout(dur!"seconds"(1), {
        updateStatus(it++);
        log_widget.AddText(format!"Iteration %d"(it));
        Application.Refresh();
        return true;
    });

    layoutDialogs(frame, fstatus, fdetails, fprogress);
    top.sizeChanged = {
        layoutDialogs(frame, fstatus, fdetails, fprogress);
    };

    updateStatus(it);

    Application.Run(top);
}
