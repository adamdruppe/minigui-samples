// This is actually a program I wrote many, many years ago for making sprites for my RPG
// now adapted to make little pixel art icons.

// works but isn't ideal code

module minigui_samples.icon_editor;

import arsd.minigui;
import arsd.minigui_addons.color_dialog;

struct Size {
	int width;
	int height;
}

enum ICON_SIZE = 16;

class ColorWidget : Widget {
	size_t idx;
	Color* entry;
	this(Widget parent, size_t idx, Color* entry) {
		super(parent);
		this.idx = idx;
		this.entry = entry;
	}

	override void paint(WidgetPainter painter) {
		painter.outlineColor = Color(64, 64, 64);
		painter.fillColor = *entry;
		painter.drawRectangle(Point(0, 0), width, height);
	}
	override int minWidth() { return 16; }
	override int minHeight() { return 16; }
	override int marginRight() { return 4; }
	override int marginTop() { return 4; }
}

class PaletteWidget : Widget {
	this(Widget parent, ubyte[] activeColors, Color[16]* palette) {
		super(parent);

		auto layout = new InlineBlockLayout(this);

		foreach(idx, ref pItem; (*palette)) {
			auto color = new ColorWidget(layout, idx, &pItem);

			color.addEventListener((ClickEvent ev) {
				auto cw = cast(ColorWidget) ev.srcElement;
				if(cw is null) return;
				if(ev.button == MouseButton.middle) {
					showColorDialog(null, (*palette)[cw.idx], (Color n) {
						(*palette)[cw.idx] = n;
						this.parentWindow.redraw();
					});
				} else {
					activeColors[ev.buttonLinear] = cast(ubyte) cw.idx;
				}
			});
		}

		this.statusTip = "Middle click to edit";
	}

	override int minHeight() { return 20 * 8 + 8; }
	override int minWidth() { return 20*2 + 8; }
	override int maxWidth() { return 20*2 + 8; }
	mixin Padding!q{ 4 };
}

void main() {
	auto window = new MainWindow("MG Icon Editor");

	window.statusBar.parts ~= new StatusBar.Part(100);
	window.statusBar.parts ~= new StatusBar.Part(100);


	int imageWidth = 16;
	int imageHeight = 16;

	ubyte[] colors = new ubyte[](imageWidth * imageHeight);
	Color[16] palette;

	ubyte[16] activeColors;
	uint buttonMask;

	auto layout = new HorizontalLayout(window.clientArea);

	auto paletteWidget = new PaletteWidget(layout, activeColors[], &palette);

	int zoomFactor = 16;

	ubyte[][] undoStack;

	void newFile(int width, int height) {
		undoStack = null;
		imageWidth = width;
		imageHeight = height;
		colors = new ubyte[](width * height);
		palette = [
			Color.transparent,
			Color.black,
			Color.red,
			Color.green,
			Color.blue,
			Color.yellow,
			Color.purple,
			Color.white,
			Color(64, 64, 64),
			Color(128, 128, 128),
			Color(192, 192, 192),
			Color(128, 64, 0),
			Color(0, 0, 128),
			Color(0, 128, 0),
			Color(0, 64, 0),
			Color(0, 0, 192),
		];
	}

	newFile(16, 16);

	auto widget = new class Widget {
		this() {
			super(layout);
		}

		override void paint(WidgetPainter painter) {
			painter.clear();

			int idx;
			foreach(y; 0 .. imageHeight)
			foreach(x; 0 .. imageWidth) {
				auto c = palette[colors[idx]];
				if(c.a == 255) {
					painter.outlineColor = c;
					painter.fillColor = c;
					painter.drawRectangle(Point(x*zoomFactor, y*zoomFactor), zoomFactor, zoomFactor);
				} else {
					auto c1 = alphaBlend(c, Color(230, 230, 230));
					auto c2 = alphaBlend(c, Color(192, 192, 192));

					painter.outlineColor = c1;
					painter.fillColor = c1;
					Point start = Point(x*zoomFactor, y*zoomFactor);
					painter.drawRectangle(start, zoomFactor / 2, zoomFactor / 2);
					painter.drawRectangle(start + Point(zoomFactor / 2, zoomFactor / 2), zoomFactor / 2, zoomFactor / 2);

					painter.outlineColor = c2;
					painter.fillColor = c2;
					painter.drawRectangle(start + Point(zoomFactor / 2, 0), zoomFactor / 2, zoomFactor / 2);
					painter.drawRectangle(start + Point(0, zoomFactor / 2), zoomFactor / 2, zoomFactor / 2);
				}
				idx++;
			}

			// drawing the grid. A solid white first, then a dotted black ensures it is
			// visible regardless of what colors are drawn under it
			painter.pen = Pen(Color.white);
			foreach(y; 1 .. imageHeight + 1) painter.drawLine(Point(0 , y * zoomFactor), Point(imageWidth * zoomFactor, y * zoomFactor));
			foreach(x; 1 .. imageWidth + 1) painter.drawLine(Point(x * zoomFactor, 0), Point(x * zoomFactor, imageHeight * zoomFactor));
			painter.pen = Pen(Color.black, 1, Pen.Style.Dotted);
			foreach(y; 1 .. imageHeight + 1) painter.drawLine(Point(0 , y * zoomFactor), Point(imageWidth * zoomFactor, y * zoomFactor));
			foreach(x; 1 .. imageWidth + 1) painter.drawLine(Point(x * zoomFactor, 0), Point(x * zoomFactor, imageHeight * zoomFactor));

			// draw it on a couple backgrounds (maybe scaled a bit too) for easier looking
			foreach(int i, bg; [Color.white, Color.black]) {
				idx = 0;
				foreach(y; 0 .. ICON_SIZE)
				foreach(x; 0 .. ICON_SIZE) {
					if(palette[colors[idx]].a == 0)
						painter.outlineColor = bg;
					else
						painter.outlineColor = palette[colors[idx]];
					painter.drawPixel(Point(x + (imageWidth + 2 + i) * zoomFactor, y + (0 + 2 + 0) * zoomFactor));
					idx++;
				}
			}

		}
	};

	void undo() {
		if(undoStack.length) {
			colors[] = undoStack[$-1];
			undoStack = undoStack[0 .. $ - 1];
			undoStack.assumeSafeAppend();
			window.redraw();
		}
	}

	widget.addEventListener((MouseDownEvent ev) {
		auto x = ev.clientX / zoomFactor;
		auto y = ev.clientY / zoomFactor;

		undoStack ~= colors.dup;

		if(x >= 0 && x < imageWidth && y >= 0 && y < imageHeight) {
			window.win.grabInput();
			if(ev.button == MouseButton.middle) {
				floodFill(
					colors[], imageWidth, imageHeight,
					colors[y * imageWidth + x], activeColors[1],
					x, y, null);
			} else {
				colors[y * imageWidth + x] = activeColors[ev.buttonLinear];
				buttonMask |= cast(uint) ev.button;
			}
			window.redraw();
		}
	});

	widget.addEventListener((MouseUpEvent ev) {
		window.win.releaseInputGrab();
		buttonMask &= ~ cast(uint) ev.button;
	});

	widget.addEventListener((MouseMoveEvent ev) {
		auto x = ev.clientX / zoomFactor;
		auto y = ev.clientY / zoomFactor;
		auto idx = y * imageWidth + x;

		if(x >= 0 && x < imageWidth && y >= 0 && y < imageHeight) {
			import core.bitop;
			if(buttonMask) {
				auto btn = bsf(buttonMask) + 1;
				colors[idx] = activeColors[btn];
				window.redraw();
			}

			import std.conv;
			window.statusBar.parts[0].content = text("(", x, ", ", y, ")");
			window.statusBar.parts[1].content = text(colors[idx]);
		} else {
			window.statusBar.parts[0].content = "";
			window.statusBar.parts[1].content = "";
		}
	});

	string currentFileName;

	struct Commands {
		@menu("File") {
			void New() @accelerator("Ctrl+N") {
				window.dialog((Size s) {
					newFile(s.width, s.height);
					window.redraw();
				});
			}
			void Open(string name) @accelerator("Ctrl+O") {
				window.getOpenFileName((string name) {
					import arsd.png;
					auto img = cast(IndexedImage) readPng(name);
					if(img is null)
						return;
					imageWidth = img.width;
					imageHeight = img.height;
					colors.length = imageWidth * imageHeight;
					colors[] = img.data[];
					palette = img.palette.dup;

					currentFileName = name;
					window.redraw();
				});
			}
			//@toolbar("") @icon(GenericIcons.Save)
			void Save() @accelerator("Ctrl+S") {
				if(currentFileName.length == 0)
					Save_As();
				else {
					auto img = new IndexedImage(imageWidth, imageHeight);
					img.data[] = colors[];
					img.palette = palette.dup;
					img.hasAlpha = true;
					import arsd.png;
					writePng(currentFileName, img);
				}
			}
			void Save_As() {
				window.getSaveFileName((string name) {
					currentFileName = name;
					Save();
				});
			}

			@separator

			void Quit() @accelerator("Ctrl+W") {
				Exit();
			}

			void Exit() @accelerator("Alt+F4") {
				window.close();
			}
		}

		@menu("Edit") {
			void Undo() @accelerator("Ctrl+Z") {
				undo();
			}
			@separator
			void Cut() {}
			void Copy() {}
			void Paste() {}
		}

		@menu("Help") {
			void About() {
				window.messageBox("About", "Minigui Sample Icon Editor, compiled " ~ __TIMESTAMP__);
			}
		}
	}

	Commands commands;

	window.setMenuAndToolbarFromAnnotatedCode(commands);

	window.loop();
}

