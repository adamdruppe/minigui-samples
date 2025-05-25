import arsd.minigui;

// FIXME: keyboard scrolling too
// FIXME: put formula, original string value, and formatting string in the status bar.
// FIXME: row numbers and column letters display
// FIXME: filtering/searching, copy+paste, some basic formulas maybe if we allow editing
// want copy as: text, csv, tsv, html. but even just the one cell at a time as text is better than none.

// FIXME: right click on a cell should let you filter to this cell contents


// View: grid coordinates vs csv headers.

/++
	The simplest way to load a CSV into a table view is to
	set the get data delegate directly, as demonstrated here.

	Later in this program, we'll also add support for filtering,
	column reordering, and sorting, so we'll make a bit more involved
	of a data model for that later.

	We won't actually use this function here, but it shows what can be done
	at minimum.
+/
void loadCsvSimple(TableView lv, string filename) {
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

	// note that you can also set a lv.getCellStyle to do per-cell coloring 

	lv.autoSizeColumnsToContent();
}

/++
	Since we want to be able to do column reordering, filtering, and sorting on the
	display without affecting the underlying data, we're going to make a TableModel
	instead of using the delegates directly.
+/
class TableModel {
	private(this) int[] columnReMapping;
	private(this) int[] rowReMapping;
	private(this) TableView.ColumnInfo[] ci;
	private(this) TableView lv;
	private(this) int itemCount;

	this(TableView lv) {
		this.lv = lv;
		lv.getData = &getDataRemapped;
		lv.getCellStyle = &getCellStyleRemapped;
	}

	final void getDataRemapped(int row, int column, scope void delegate(in char[]) sink) {
		return getData(rowReMapping[row], columnReMapping[column], sink);
	}

	final TableView.CellStyle getCellStyleRemapped(int row, int column) {
		return getCellStyle(rowReMapping[row], columnReMapping[column]);
	}
	final string[] columnNames() {
		string[] ret;
		foreach(c; ci)
			ret ~= c.name.idup;
		return ret;
	}

	void delegate(int row, int column, scope void delegate(in char[] sink)) getData;
	TableView.CellStyle delegate(int row, int column) getCellStyle;

	/++
		Resets the special mappings, going back to viewing the source data.
	+/
	void resetMappings() {
		columnReMapping.length = ci.length;
		foreach(int idx, ref item; columnReMapping)
			item = idx;

		rowReMapping.length = itemCount;
		foreach(int idx, ref item; rowReMapping)
			item = idx;

		resyncView();
	}

	protected void resyncView() {
		TableView.ColumnInfo[] ci;
		ci.length = columnReMapping.length;
		foreach(idx, cm; columnReMapping)
			ci[idx] = this.ci[cm];
		lv.setColumnInfo(ci);

		lv.setItemCount(cast(int) rowReMapping.length);

		lv.autoSizeColumnsToContent();
	}

	/++
		Applies a data filter based on what is visible to the user.
	+/
	public void applyFilter(int remappedColumnIndex, in char[] visibleTextMatch) {
		sdpyPrintDebugString("applying filter ", remappedColumnIndex, " == ", visibleTextMatch);
		int[] newMapping;
		foreach(rowIndex; 0 .. rowReMapping.length) {
			getData(rowReMapping[rowIndex], remappedColumnIndex, (text) {
				if(text == visibleTextMatch)
					newMapping ~= rowReMapping[rowIndex];
			});
		}

		rowReMapping = newMapping;
		lv.setItemCount(cast(int) rowReMapping.length);
		lv.redraw;
	}

	/++
		Applies a sort based on what is visible to the user.
	+/
	public void sortBy(int remappedColumnIndex) {
		sdpyPrintDebugString("sorting by ", remappedColumnIndex);

		import std.algorithm;
		import std.algorithm.sorting;

		int[] rowReMapping = this.rowReMapping.dup;

		bool comparator(int rowIndex1, int rowIndex2) {
			bool result;
			getData(rowIndex1, remappedColumnIndex, (text1) {
				getData(rowIndex2, remappedColumnIndex, (text2) {
					// FIXME: do natural sort for numbers
					import std.conv;
					try {
						double d1 = to!double(text1);
						double d2 = to!double(text2);
						result = d1 < d2;
					} catch(ConvException e) {
						result = text1 < text2;
					}
				});
			});
			return result;
		}

		rowReMapping.sort!(comparator, SwapStrategy.stable);

		this.rowReMapping = rowReMapping;

		lv.redraw;
	}

	/++
		Completely clears the model, making the data an empty table again.
	+/
	void clear() {
		auto preservedlv = this.lv;
		this.tupleof = this.tupleof.init;
		this.lv = preservedlv;
	}

	/++
		Replaces the content of model with the content of a .csv file
	+/
	void loadCsv(string filename) {
		clear();

		import arsd.csv;
		import std.file;

		auto data = readCsv(readText(filename));

		if(data.length == 0) {
			throw new Exception("There was no data in that file.");
		}

		TableView.ColumnInfo[] ci;
		foreach(col; data[0]) {
			ci ~= TableView.ColumnInfo(col, 80);
		}
		this.ci = ci;

		itemCount = cast(int) data.length - 1; // no header here

		this.getData = delegate(int row, int column, scope void delegate(in char[]) sink) {
			auto r = data[row + 1];
			sink(column < r.length ? r[column] : "");
		};

		this.getCellStyle = delegate(int row, int column) {
			return TableView.CellStyle.init;
		};

		resetMappings();
		resyncView();
	}

	/++
		Replaces the content of model with the content of a .xlsx file.
	+/
	void loadXlsx(string filename) {
		clear();

		import arsd.csv;
		import arsd.xlsx;
		import std.file;
		import ac = arsd.core;

		auto data = new XlsxFile(ac.FilePath(filename)).getSheet(0).toGrid();

		if(data.length == 0) {
			throw new Exception("There was no data in that file.");
		}

		TableView.ColumnInfo[] ci;
		foreach(colIdx, col; data[0]) {
			TextAlignment alignment = TextAlignment.Left;

			// oh no, TableView can't do per-cell alignment!
			// so we will scan the column and if any are right aligned,
			// go ahead and right align them all, since that's probably
			// close enough for most tables
			if(!lv.supportsPerCellAlignment)
			foreach(row; data) {
				if(row[colIdx].displayableResult.alignment == 1) {
					alignment = TextAlignment.Right;
					break;
				}
			}

			ci ~= TableView.ColumnInfo(col.toString(), 80, alignment);
		}
		this.ci = ci;
		this.itemCount = cast(int) data.length - 1; // no header here
		this.getData = delegate(int row, int column, scope void delegate(in char[]) sink) {
			auto r = data[row + 1];
			// content and formula and originalFormatString can all be useful here
			sink(column < r.length ? r[column].toString() : "");
		};

		// but it can do per-cell coloring
		this.getCellStyle = delegate(int row, int column) {
			auto c = data[row + 1][column];
			auto dr = c.displayableResult();

			TextAlignment alignment = TextAlignment.Left;
			if(dr.alignment == 1)
				alignment = TextAlignment.Right;

			if(dr.color.length == 0)
				return TableView.CellStyle(alignment);
			else
				// FIXME: we can also set a background color here once we get it from the xlsx file
				return TableView.CellStyle(alignment, excelColorToArsdColor(dr.color));
		};

		resetMappings();
		resyncView();
	}
}

void loadFile(Window window, TableModel tm, string filename) {
	try {
		import std.algorithm;

		if(filename.endsWith(".xlsx"))
			tm.loadXlsx(filename);
		else
			tm.loadCsv(filename);

		import arsd.core;
		window.title = "MG CSV Viewer - " ~ FilePath(filename).filename;
	} catch (Exception e) {
		window.messageBox(e.msg);
	}
}


Color excelColorToArsdColor(string c) {
	switch(c) {
		case "Black": return Color.black;
		case "Green": return Color.green;
		case "White": return Color.white;
		case "Blue": return Color.blue;
		case "Magenta": return Color.magenta;
		case "Yellow": return Color.yellow;
		case "Cyan": return Color.teal; // is that the same as cyan?
		case "Red": return Color.red;
		default:
			static bool[string] warnings;
			if(c !in warnings) {
				warnings[c] = true;
				sdpyPrintDebugString(c);
			}
			return Color.black;
	}
}

void main(string[] args) {
	string preloadFile = (args.length > 1) ? args[1] : null;

	auto window = new MainWindow("MG CSV Viewer");
	import arsd.png;
	window.icon = readPngFromBytes(import("icons/spreadsheet.png"));

	// double click opens the whole thing
	// right click should be able to copy to clipboard

	// prolly need to handle selection of cells too.

	/+
	window.statusBar.parts ~= new StatusBar.Part(50); // last click coordinates
	window.statusBar.parts ~= new StatusBar.Part(50); // size of table
	window.statusBar.parts ~= new StatusBar.Part(50); // last click format string (or average if column)
	window.statusBar.parts ~= new StatusBar.Part(50); // last click raw value (or sum if column)
	window.statusBar.parts ~= new StatusBar.Part(50); // last click formula (or min/max if column)
	+/

	auto lv = new TableView(window);

	static TableModel dm; // so i can access it from the Commands udas
	dm = new TableModel(lv);

	struct Commands {
		@menu("&File") {
			void Open(FileName!() fn) @accelerator("Ctrl+O") {
				window.loadFile(dm, fn);
			}

			@separator

			void Reload() @accelerator("Ctrl+F5") {
				window.loadFile(dm, previousFileReferenced);
			}

			@separator

			void Exit() @accelerator("Ctrl+W") {
				window.close();
			}
		}

		@menu("&Data") {
			void Reset_View() @accelerator("F5") {
				dm.resetMappings();
			}

			@separator

			void Find(string what) @accelerator("Ctrl+F") {
				// FIXME
				window.messageBox("Not implemented");
			}

			void Find_Next() @accelerator("F3") {
				// FIXME
				window.messageBox("Not implemented");
			}

			void Goto(string cell) @accelerator("Ctrl+G") {
				// FIXME: need a Scroll Into View method
				import arsd.xlsx;
				auto cr = CellReference(cell);
				import arsd.core;
				writeln(cr.toRowIndex, " ", cr.toColumnIndex); // FIXME

			}

			@separator

			void Filter(@choices(() => dm.columnNames) int column, string value) {
				window.messageBox("Not Implemented - try right clicking cells instead");
				// FIXME
			}

			void Sort(@choices(() => dm.columnNames) int[] columns) {
				window.messageBox("Not Implemented - try clicking headers instead");
				// FIXME
			}

			void Select_Columns(@choices(() => dm.columnNames, allowDuplicates: true) int[] columns) {
				window.messageBox("Not Implemented");
				// FIXME
			}
		}
	}
	Commands commands;
	window.setMenuAndToolbarFromAnnotatedCode(commands);

	if(preloadFile.length)
		commands.Open(preloadFile);

	class CellContextCommands {
		this(int columnIndex, int rowIndex) {
			this.columnIndex = columnIndex;
			this.rowIndex = rowIndex;
		}

		int rowIndex;
		int columnIndex;

		@context_menu {
			void Copy() {
				dm.getDataRemapped(rowIndex, columnIndex, (text) {
					window.win.setClipboardText(text.idup);
				});
			}

			@separator

			void Filter_View_To() {
				dm.getDataRemapped(rowIndex, columnIndex, (text) {
					dm.applyFilter(columnIndex, text);
				});
			}
		}
	}

	lv.addEventListener((scope CellClickedEvent event) {
		//import std.stdio; with(event) std.stdio.writeln(rowIndex, "x", columnIndex, " @ ", clientX, ",", clientY, " ", button);
		if(event.button == MouseButton.right) {
			lv.showContextMenu(event.clientX, event.clientY, lv.createContextMenuFromAnnotatedCode(new CellContextCommands(event.columnIndex, event.rowIndex)));
		}
	});

	lv.addEventListener(delegate(scope HeaderClickedEvent event) {
		// FIXME: button?
		dm.sortBy(event.columnIndex);
	});

	window.loop();
}
