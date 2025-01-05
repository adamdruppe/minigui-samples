import arsd.minigui;

void loadFile(TableView lv, string filename) {
	import arsd.csv;
	import std.file;

	auto csv = readCsv(readText(filename));

	if(csv.length == 0) {
		lv.parentWindow.messageBox("There was no data in that file.");
		return;
	}

	TableView.ColumnInfo[] ci;
	foreach(col; csv[0]) {
		ci ~= TableView.ColumnInfo(col, 80);
	}
	lv.setColumnInfo(ci);
	lv.setItemCount(cast(int) csv.length - 1); // no header here
	lv.getData = delegate(int row, int column, scope void delegate(in char[]) sink) {
		auto r = csv[row + 1];
		sink(column < r.length ? r[column] : "");
	};

	// can also set a getCellStyle if we want
}

void main(string[] args) {
	string preloadFile = (args.length > 1) ? args[1] : null;

	auto window = new MainWindow("MG CSV Viewer");
	auto lv = new TableView(window);

	if(preloadFile.length)
		lv.loadFile(preloadFile);

	struct Commands {
		@menu("&File") {
			void Open(FileName!() fn) @accelerator("Ctrl+O") {
				lv.loadFile(fn);
			}

			@separator

			void Exit() @accelerator("Ctrl+W") {
				window.close();
			}
		}
	}
	Commands commands;
	window.setMenuAndToolbarFromAnnotatedCode(commands);

	window.loop();
}
