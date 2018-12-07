import ctui;

void main()
{
	Application.Init();
	auto d = new Container(0, 0, Application.Cols, Application.Lines);

	d.add(new Label (10, 10, "Text"));
	d.add(new Entry (16, 10, 20, "Edit me"));
	Application.Run(d);
}

