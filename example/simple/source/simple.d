import ctui;

void main()
{
	Application.init();
	auto d = new Container(0, 0, Application.cols, Application.lines);

	d.add(new Label (10, 10, "Text"));
	d.add(new Entry (16, 10, 20, "Edit me"));
	Application.run(d);
}

